import 'package:app_movil/app/tema.dart';
import 'package:app_movil/app/widgets/panel_escucha_activa.dart';
import 'package:app_movil/core/voz/servicio_dictado.dart';
import 'package:app_movil/core/voz/voz_providers.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/interpretar_dictado_censo.dart';
import 'package:app_movil/features/diagnostico/domain/bateria_dictado.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medición del riesgo R-05: precisión del dictado de cifras en `es-BO`.
///
/// Existe porque probar el micrófono en el formulario real dice si funciona,
/// pero no cuánto. Para decidir si la voz sigue siendo un requisito o pasa a
/// opcional hace falta un número, y un número que se pueda mostrar.
///
/// Se corre en un dispositivo físico: el emulador no expone micrófono real.
class PantallaDiagnosticoDictado extends ConsumerStatefulWidget {
  const PantallaDiagnosticoDictado({super.key});

  @override
  ConsumerState<PantallaDiagnosticoDictado> createState() =>
      _PantallaDiagnosticoDictadoState();
}

class _PantallaDiagnosticoDictadoState
    extends ConsumerState<PantallaDiagnosticoDictado> {
  static const _interpretar = InterpretarDictadoCenso();

  final _intentos = <String, IntentoDictado>{};
  final _eventos = <EventoDictado>[];
  final _dispositivo = TextEditingController();

  EstadoDictado _estado = EstadoDictado.noInicializado;
  String? _escuchandoId;
  double _nivel = 0;
  String _parcial = '';
  DateTime? _inicioEscucha;

  ServicioDictado get _servicio => ref.read(servicioDictadoProvider);

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void dispose() {
    _dispositivo.dispose();
    super.dispose();
  }

  Future<void> _preparar() async {
    _servicio.eventos.listen((evento) {
      if (!mounted) return;
      setState(() {
        _eventos.insert(0, evento);
        if (_eventos.length > 30) _eventos.removeLast();
      });
    });

    _servicio.nivelDeSonido.listen((nivel) {
      if (mounted) setState(() => _nivel = nivel);
    });

    final estado = await _servicio.inicializar();
    if (mounted) setState(() => _estado = estado);
  }

  Future<void> _dictar(ItemBateria item) async {
    if (_escuchandoId != null) {
      // Detener conserva lo dictado: el resultado llega por `alResultado` y se
      // registra como cualquier otro intento.
      await _servicio.detener();
      return;
    }

    final estado = await _servicio.inicializar();
    if (!mounted) return;
    setState(() => _estado = estado);

    if (estado != EstadoDictado.listo) return;

    setState(() {
      _escuchandoId = item.id;
      _parcial = '';
      _inicioEscucha = DateTime.now();
    });

    await _servicio.escuchar(
      alResultado: (resultado) {
        if (!mounted) return;

        if (!resultado.esFinal) {
          setState(() => _parcial = resultado.transcripcion);
          return;
        }

        setState(() {
          _escuchandoId = null;
          _inicioEscucha = null;
          _nivel = 0;
          _parcial = '';
          _intentos[item.id] = IntentoDictado(
            item: item,
            transcripcion: resultado.transcripcion,
            confianza: resultado.confianza,
            propuesta: _interpretar.interpretar(resultado.transcripcion),
            momento: DateTime.now(),
          );
        });
      },
      alError: (mensaje) {
        if (!mounted) return;
        setState(() => _escuchandoId = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensaje)));
      },
      // El motor cerró por su cuenta sin entregar nada: casi siempre porque
      // Android detectó silencio antes que nuestro `pauseFor`. Sin resetear
      // acá, la fila queda con el botón en "Parar" y el ítem parece un fallo
      // del reconocimiento cuando en realidad nunca llegó a escuchar.
      alDetenerse: () {
        if (!mounted) return;
        setState(() {
          _escuchandoId = null;
          _inicioEscucha = null;
          _nivel = 0;
          _parcial = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El motor cerró la escucha sin captar nada. Probá de nuevo '
              'empezando a hablar apenas toques Dictar.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      },
    );
  }

  ResumenBateria get _resumen => ResumenBateria(_intentos.values.toList());

  Future<void> _copiar() async {
    final texto = _resumen.comoTexto(
      locale: _servicio.localeSeleccionada,
      dispositivo:
          _dispositivo.text.trim().isEmpty ? null : _dispositivo.text.trim(),
    );

    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Informe copiado al portapapeles.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike R-05 —” Dictado'),
        actions: [
          IconButton(
            onPressed: _intentos.isEmpty ? null : _copiar,
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copiar informe',
          ),
          IconButton(
            onPressed:
                _intentos.isEmpty ? null : () => setState(_intentos.clear),
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reiniciar corrida',
          ),
        ],
      ),
      bottomNavigationBar: _escuchandoId == null
          ? null
          : PanelEscuchaActiva(
              transcripcionParcial: _parcial,
              nivel: _nivel,
              inicio: _inicioEscucha ?? DateTime.now(),
              duracionMaxima: ServicioDictadoSpeechToText.duracionPorDefecto,
              alConfirmar: _servicio.detener,
              alCancelar: () async {
                await _servicio.cancelar();
                if (!mounted) return;
                setState(() {
                  _escuchandoId = null;
                  _inicioEscucha = null;
                  _parcial = '';
                  _nivel = 0;
                });
              },
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _TarjetaMotor(
            estado: _estado,
            locale: _servicio.localeSeleccionada,
            disponibles: _servicio.localesDisponibles,
            nivel: _nivel,
            escuchando: _escuchandoId != null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _dispositivo,
              decoration: const InputDecoration(
                labelText: 'Dispositivo (para el informe)',
                hintText: 'Ej: Moto G54, Android 14',
                prefixIcon: Icon(Icons.smartphone),
              ),
            ),
          ),
          if (!resumen.estaVacio) _TarjetaResumen(resumen: resumen),
          const _Encabezado('Batería de prueba'),
          for (final item in BateriaDictado.items)
            _FilaItem(
              item: item,
              intento: _intentos[item.id],
              escuchando: _escuchandoId == item.id,
              habilitado: _estado == EstadoDictado.listo ||
                  _estado == EstadoDictado.noInicializado,
              alDictar: () => _dictar(item),
            ),
          if (_eventos.isNotEmpty) ...[
            const _Encabezado('Eventos del motor'),
            for (final evento in _eventos)
              ListTile(
                dense: true,
                leading: Icon(
                  evento.esError ? Icons.error_outline : Icons.info_outline,
                  size: 18,
                  color: evento.esError ? TemaApp.error : null,
                ),
                title: Text(
                  evento.mensaje,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaMotor extends StatelessWidget {
  const _TarjetaMotor({
    required this.estado,
    required this.locale,
    required this.disponibles,
    required this.nivel,
    required this.escuchando,
  });

  final EstadoDictado estado;
  final String? locale;
  final List<String> disponibles;
  final double nivel;
  final bool escuchando;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final listo = estado == EstadoDictado.listo;
    final espanolas =
        disponibles.where((l) => l.toLowerCase().startsWith('es')).toList();

    return Card(
      color: (listo ? TemaApp.exito : TemaApp.error).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  listo ? Icons.mic : Icons.mic_off,
                  color: listo ? TemaApp.exito : TemaApp.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    estado.descripcion,
                    style: tema.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Locale en uso: ${locale ?? "ninguna"}'),
            Text(
              espanolas.isEmpty
                  ? 'Sin locales españolas instaladas'
                  : 'Españolas disponibles: ${espanolas.join(", ")}',
              style: tema.textTheme.bodySmall,
            ),
            Text(
              'Total de locales del dispositivo: ${disponibles.length}',
              style: tema.textTheme.bodySmall,
            ),
            if (escuchando) ...[
              const SizedBox(height: 12),
              // Sin señal de amplitud no hay forma de saber si el micrófono
              // está captando o si el problema es otro.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: nivel, minHeight: 8),
              ),
              const SizedBox(height: 4),
              Text('Escuchando—¦', style: tema.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.resumen});

  final ResumenBateria resumen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resultado', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metrica(
                  valor: pct(resumen.precisionPorFrase),
                  etiqueta: 'Frases enteras',
                  destacada: true,
                ),
                _Metrica(
                  valor: pct(resumen.precisionPorCampo),
                  etiqueta: 'Campos sueltos',
                ),
                _Metrica(
                  valor: '${resumen.totalCamposDeMas}',
                  etiqueta: 'Inventados',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'La métrica que decide es "frases enteras": al operador no le '
              'sirve que 8 de 9 campos estén bien, porque igual tiene que '
              'revisar los 9.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Confianza promedio del motor: '
              '${pct(resumen.confianzaPromedio)} Â· '
              '${resumen.intentos.length} de ${BateriaDictado.items.length} '
              'ítems corridos',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.valor,
    required this.etiqueta,
    this.destacada = false,
  });

  final String valor;
  final String etiqueta;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: (destacada
                    ? tema.textTheme.headlineMedium
                    : tema.textTheme.headlineSmall)
                ?.copyWith(
              fontWeight: destacada ? FontWeight.w700 : null,
              color: destacada ? tema.colorScheme.primary : null,
            ),
          ),
          Text(
            etiqueta,
            style: tema.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({
    required this.item,
    required this.intento,
    required this.escuchando,
    required this.habilitado,
    required this.alDictar,
  });

  final ItemBateria item;
  final IntentoDictado? intento;
  final bool escuchando;
  final bool habilitado;
  final VoidCallback alDictar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resultado = intento;

    final (icono, color) = switch (resultado) {
      null => (Icons.radio_button_unchecked, tema.colorScheme.onSurfaceVariant),
      _ when resultado.exacto => (Icons.check_circle, TemaApp.exito),
      _ => (Icons.cancel_outlined, TemaApp.error),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.id} Â· decí: Â«${item.frase}Â»',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(item.prueba, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: habilitado || escuchando ? alDictar : null,
                  icon: Icon(escuchando ? Icons.stop : Icons.mic, size: 18),
                  label: Text(escuchando ? 'Parar' : 'Dictar'),
                ),
              ],
            ),
            if (resultado != null) ...[
              const Divider(height: 20),
              Text(
                'Se entendió: Â«${resultado.transcripcion}Â»',
                style: tema.textTheme.bodyMedium,
              ),
              Text(
                'Confianza del motor: '
                '${(resultado.confianza * 100).toStringAsFixed(0)}%',
                style: tema.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              for (final entrada in item.esperado.entries)
                _FilaCampo(
                  nombre: entrada.key.etiqueta,
                  esperado: entrada.value,
                  obtenido: resultado.interpretado[entrada.key],
                ),
              if (resultado.camposDeMas > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${resultado.camposDeMas} campo(s) que no se dictaron '
                    'aparecieron igual.',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: TemaApp.error),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaCampo extends StatelessWidget {
  const _FilaCampo({
    required this.nombre,
    required this.esperado,
    required this.obtenido,
  });

  final String nombre;
  final int esperado;
  final int? obtenido;

  @override
  Widget build(BuildContext context) {
    final acerto = obtenido == esperado;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            acerto ? Icons.check : Icons.close,
            size: 16,
            color: acerto ? TemaApp.exito : TemaApp.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(nombre, style: const TextStyle(fontSize: 13))),
          Text(
            acerto ? '$esperado' : '$esperado → ${obtenido ?? "nada"}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: acerto ? TemaApp.exito : TemaApp.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
