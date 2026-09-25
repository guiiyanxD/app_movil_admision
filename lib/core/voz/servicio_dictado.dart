import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Estado del motor de dictado.
enum EstadoDictado {
  noInicializado,
  noDisponible,
  sinPermiso,
  sinLocaleEspanol,
  listo,
  escuchando;

  String get descripcion => switch (this) {
        noInicializado => 'Sin inicializar',
        noDisponible => 'El dispositivo no ofrece reconocimiento de voz',
        sinPermiso => 'Falta permiso de micrófono',
        sinLocaleEspanol => 'No hay reconocimiento en español instalado',
        listo => 'Listo para dictar',
        escuchando => 'Escuchando',
      };
}

class ResultadoDictado {
  const ResultadoDictado({
    required this.transcripcion,
    required this.confianza,
    required this.esFinal,
  });

  final String transcripcion;
  final double confianza;
  final bool esFinal;
}

/// Evento del motor: cambio de estado o error.
///
/// Existe porque `speech_to_text` reporta por callbacks lo único que sirve para
/// diagnosticar por qué un dictado no funcionó. Tragarse esos callbacks deja al
/// operador —y al desarrollador— mirando una pantalla que no hace nada.
class EventoDictado {
  const EventoDictado({
    required this.mensaje,
    required this.esError,
    required this.momento,
  });

  final String mensaje;
  final bool esError;
  final DateTime momento;
}

/// Abstracción del motor de voz.
///
/// El controlador del formulario depende de esta interfaz y no de
/// `speech_to_text`, así que se puede testear sin micrófono ni plugin.
abstract interface class ServicioDictado {
  Future<EstadoDictado> inicializar();

  /// [alDetenerse] avisa que el motor cerró la sesión por su cuenta, sin
  /// resultado final. Sin esto la UI queda mostrando "escuchando" para siempre.
  Future<void> escuchar({
    required void Function(ResultadoDictado) alResultado,
    required void Function(String) alError,
    void Function()? alDetenerse,
    Duration? silencioMaximo,
    Duration? duracionMaxima,
  });

  Future<void> detener();

  Future<void> cancelar();

  EstadoDictado get estado;

  /// Locale efectivamente seleccionada.
  String? get localeSeleccionada;

  /// Todas las locales que ofrece el dispositivo. Para diagnóstico: saber que
  /// hay `es_419` pero no `es_BO` explica mucho de la precisión que se mida.
  List<String> get localesDisponibles;

  /// Amplitud del micrófono, 0.0–1.0 aproximado. Sin esto el operador no tiene
  /// forma de saber si lo están escuchando.
  Stream<double> get nivelDeSonido;

  /// Estados y errores del motor.
  Stream<EventoDictado> get eventos;

  /// Instante en que arrancó la sesión en curso. `null` si no está escuchando.
  DateTime? get inicioEscucha;

  void dispose();
}

/// Implementación sobre `speech_to_text`.
class ServicioDictadoSpeechToText implements ServicioDictado {
  ServicioDictadoSpeechToText([SpeechToText? motor])
      : _motor = motor ?? SpeechToText();

  final SpeechToText _motor;

  final _nivel = StreamController<double>.broadcast();
  final _eventos = StreamController<EventoDictado>.broadcast();

  String? _localeSeleccionada;
  List<String> _localesDisponibles = const [];
  EstadoDictado _estado = EstadoDictado.noInicializado;

  /// Aviso de que la sesión terminó sin resultado final.
  void Function()? _alDetenerse;
  void Function(ResultadoDictado)? _alResultado;
  bool _entregoResultadoFinal = false;

  /// Último parcial recibido. Es lo que se entrega si el operador toca
  /// "Listo" antes de que el motor cierre por su cuenta.
  String _ultimoParcial = '';
  double _ultimaConfianza = 0;
  DateTime? _inicioEscucha;

  /// Cuándo arrancó la sesión en curso, para el contador de la UI.
  @override
  DateTime? get inicioEscucha => _inicioEscucha;

  /// Silencio por defecto antes de cerrar.
  ///
  /// **Es una intención, no una garantía.** El `SpeechRecognizer` de Android
  /// tiene su propia detección de silencio —del orden de uno o dos segundos— y
  /// el motor de Google habitualmente ignora los extras que piden alargarla.
  /// En la práctica la sesión suele cerrarse mucho antes de este valor.
  static const Duration silencioPorDefecto = Duration(seconds: 8);

  /// Tope duro de la sesión, este sí lo controla el plugin.
  ///
  /// 45 s cubre con margen el dictado del censo completo (nueve campos), que
  /// es el enunciado más largo de la batería.
  static const Duration duracionPorDefecto = Duration(seconds: 45);

  /// Margen que se le da al motor tras `stop()` para que entregue su resultado
  /// final antes de que usemos el último parcial.
  static const Duration margenTrasDetener = Duration(milliseconds: 400);

  @override
  String? get localeSeleccionada => _localeSeleccionada;

  @override
  List<String> get localesDisponibles => _localesDisponibles;

  @override
  EstadoDictado get estado => _estado;

  @override
  Stream<double> get nivelDeSonido => _nivel.stream;

  @override
  Stream<EventoDictado> get eventos => _eventos.stream;

  void _emitir(String mensaje, {bool esError = false}) {
    if (_eventos.isClosed) return;
    _eventos.add(
      EventoDictado(
        mensaje: mensaje,
        esError: esError,
        momento: DateTime.now(),
      ),
    );
  }

  /// Orden de preferencia de locale.
  ///
  /// `es_BO` rara vez está instalada; el motor de Android suele traer `es_419`
  /// (español latinoamericano) o `es_US`. **Nunca se cae a inglés en
  /// silencio**: si no hay ninguna locale española, el dictado se deshabilita
  /// con un mensaje explícito, porque un motor en inglés interpretando números
  /// en español produce basura plausible, que es peor que no funcionar.
  static const List<String> preferenciaLocales = [
    'es_BO',
    'es_419',
    'es_MX',
    'es_AR',
    'es_US',
    'es_ES',
  ];

  @override
  Future<EstadoDictado> inicializar() async {
    // Reinicializar en cada intento re-consulta locales sin aportar nada.
    if (_estado == EstadoDictado.listo) return _estado;

    final disponible = await _motor.initialize(
      onError: (error) => _emitir(
        '${error.errorMsg}${error.permanent ? ' (permanente)' : ''}',
        esError: true,
      ),
      onStatus: (estado) {
        _emitir(estado);

        // "done" y "notListening" son la única señal de que el motor cerró la
        // sesión por su cuenta: por silencio detectado por Android, por el tope
        // de duración, o porque el reconocedor decidió que ya escuchó bastante.
        // Sin esto la UI se queda mostrando "escuchando" para siempre y el
        // operador cree que la app se colgó.
        final termino = estado == 'done' || estado == 'notListening';
        if (termino && _estado == EstadoDictado.escuchando) {
          _estado = EstadoDictado.listo;
          if (!_entregoResultadoFinal) _alDetenerse?.call();
        }
      },
    );

    if (!disponible) {
      final tienePermiso = await _motor.hasPermission;
      _estado =
          tienePermiso ? EstadoDictado.noDisponible : EstadoDictado.sinPermiso;
      _emitir(_estado.descripcion, esError: true);
      return _estado;
    }

    final locales = await _motor.locales();
    _localesDisponibles = locales.map((l) => l.localeId).toList()..sort();
    _localeSeleccionada = _elegirLocale(_localesDisponibles);

    _estado = _localeSeleccionada == null
        ? EstadoDictado.sinLocaleEspanol
        : EstadoDictado.listo;

    _emitir(
      _localeSeleccionada == null
          ? 'Sin locale española entre ${_localesDisponibles.length} disponibles'
          : 'Locale seleccionada: $_localeSeleccionada',
      esError: _localeSeleccionada == null,
    );

    return _estado;
  }

  /// Expuesto para poder testear la selección sin plugin.
  static String? elegirLocaleEntre(List<String> disponibles) =>
      _elegirLocale(disponibles);

  static String? _elegirLocale(List<String> disponibles) {
    String normalizar(String id) => id.replaceAll('-', '_');
    final normalizadas = {
      for (final id in disponibles) normalizar(id): id,
    };

    for (final preferida in preferenciaLocales) {
      final encontrada = normalizadas[preferida];
      if (encontrada != null) return encontrada;
    }

    // Cualquier otra variante de español sirve antes que rendirse.
    for (final entrada in normalizadas.entries) {
      if (entrada.key.toLowerCase().startsWith('es')) return entrada.value;
    }

    return null;
  }

  @override
  Future<void> escuchar({
    required void Function(ResultadoDictado) alResultado,
    required void Function(String) alError,
    void Function()? alDetenerse,
    Duration? silencioMaximo,
    Duration? duracionMaxima,
  }) async {
    if (_estado != EstadoDictado.listo) {
      alError('El dictado no está disponible en este dispositivo.');
      return;
    }

    _estado = EstadoDictado.escuchando;
    _entregoResultadoFinal = false;
    _alDetenerse = alDetenerse;
    _alResultado = alResultado;
    _ultimoParcial = '';
    _ultimaConfianza = 0;
    _inicioEscucha = DateTime.now();

    await _motor.listen(
      localeId: _localeSeleccionada,
      onResult: (resultado) {
        // Los parciales se retienen: son lo que se entrega si el operador
        // corta la escucha antes de que el motor decida cerrarla.
        if (resultado.recognizedWords.trim().isNotEmpty) {
          _ultimoParcial = resultado.recognizedWords;
          _ultimaConfianza = resultado.confidence;
        }

        if (resultado.finalResult) {
          _estado = EstadoDictado.listo;
          _entregoResultadoFinal = true;
        }

        alResultado(
          ResultadoDictado(
            transcripcion: resultado.recognizedWords,
            confianza: resultado.confidence,
            esFinal: resultado.finalResult,
          ),
        );
      },
      onSoundLevelChange: (nivel) {
        if (_nivel.isClosed) return;
        // Android entrega decibeles en un rango aproximado de -2 a 10.
        // Se normaliza a 0–1 para que la UI no tenga que saber eso.
        _nivel.add(((nivel + 2) / 12).clamp(0.0, 1.0));
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        // Dictado de cifras: enunciados cortos, uno detrás de otro.
        listenMode: ListenMode.dictation,
      ),
      pauseFor: silencioMaximo ?? silencioPorDefecto,
      listenFor: duracionMaxima ?? duracionPorDefecto,
    );
  }

  /// Cierra la escucha **conservando lo dictado**.
  ///
  /// Para el operador, tocar "Listo" significa "terminé de hablar", no "tirá lo
  /// que dije". Antes esto descartaba la sesión entera: se perdía un enunciado
  /// completo por adelantarse medio segundo al motor.
  ///
  /// El orden importa. `stop()` suele provocar que el reconocedor entregue su
  /// resultado final poco después, y ese es mejor que cualquier parcial. Se le
  /// da un margen breve; solo si no llega, se usa el último parcial retenido.
  @override
  Future<void> detener() async {
    final estabaEscuchando = _estado == EstadoDictado.escuchando;
    await _motor.stop();

    if (!estabaEscuchando) {
      _estado = EstadoDictado.listo;
      return;
    }

    await Future<void>.delayed(margenTrasDetener);

    if (!_entregoResultadoFinal && _ultimoParcial.trim().isNotEmpty) {
      _entregoResultadoFinal = true;
      _alResultado?.call(
        ResultadoDictado(
          transcripcion: _ultimoParcial,
          confianza: _ultimaConfianza,
          esFinal: true,
        ),
      );
    }

    _estado = EstadoDictado.listo;
    _inicioEscucha = null;
  }

  /// Descarta la sesión sin entregar nada. Es lo que corresponde cuando el
  /// operador se arrepiente, no cuando termina de hablar.
  @override
  Future<void> cancelar() async {
    _entregoResultadoFinal = true; // impide que un parcial tardío se cuele
    _ultimoParcial = '';
    await _motor.cancel();
    _estado = EstadoDictado.listo;
    _inicioEscucha = null;
  }

  @override
  void dispose() {
    _nivel.close();
    _eventos.close();
  }
}
