import 'package:flutter/services.dart';
import 'dart:async';

import 'package:app_movil/app/tema.dart';

import 'package:app_movil/core/sesion/permisos_providers.dart';

import 'package:app_movil/app/widgets/panel_escucha_activa.dart';

import 'package:app_movil/core/voz/servicio_dictado.dart';

import 'package:app_movil/core/voz/voz_providers.dart';

import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';

import 'package:app_movil/features/censo_diario/domain/usecases/validar_censo_servicio.dart';

import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';

import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';

import 'package:app_movil/features/censo_diario/presentation/state/censo_form_controller.dart';

import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';

import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';

import 'package:app_movil/features/censo_diario/presentation/widgets/barra_navegacion_servicios.dart';

import 'package:app_movil/features/censo_diario/presentation/widgets/campo_numerico_censo.dart';

import 'package:app_movil/features/censo_diario/presentation/widgets/hoja_confirmacion_voz.dart';

import 'package:app_movil/features/censo_diario/presentation/widgets/indicadores_censo.dart';

import 'package:app_movil/features/censo_diario/presentation/widgets/procedencia_carga.dart';

import 'package:app_movil/features/censo_diario/presentation/widgets/seccion_camas_prestadas.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Formulario EST-1 de un servicio, con navegación al anterior y al siguiente.

///

/// Recibe la lista completa **en el mismo orden del checklist** y se mueve

/// dentro de ella sin apilar rutas: el operador recorre los servicios de

/// corrido, como recorre las hojas del formulario en papel.

class CensoServicioFormPage extends ConsumerStatefulWidget {
  /// Modo Por Servicios (diario): fecha fija, recorre lista de servicios
  final DateTime? fecha;
  final List<Servicio> servicios;

  /// Modo Por Días (mensual): servicio fijo, recorre lista de días del mes
  final Servicio? servicioFijo;
  final List<DateTime>? fechas;

  final int indiceInicial;

  const CensoServicioFormPage({
    required DateTime fecha,
    required List<Servicio> servicios,
    required int indiceInicial,
    super.key,
  })  : fecha = fecha,
        servicios = servicios,
        servicioFijo = null,
        fechas = null,
        indiceInicial = indiceInicial;

  const CensoServicioFormPage.porDias({
    required Servicio servicio,
    required List<DateTime> fechas,
    int indiceInicial = 0,
    super.key,
  })  : fecha = null,
        servicios = const [],
        servicioFijo = servicio,
        fechas = fechas,
        indiceInicial = indiceInicial;

  @override
  ConsumerState<CensoServicioFormPage> createState() =>
      _CensoServicioFormPageState();
}

class _CensoServicioFormPageState extends ConsumerState<CensoServicioFormPage> {

  late int _indice = widget.indiceInicial;

  bool _hojaAbierta = false;

  EstadoDictado _estadoDictado = EstadoDictado.noInicializado;

  double _nivelSonido = 0;

  DateTime? _inicioEscucha;

  StreamSubscription<double>? _suscripcionNivel;

  /// Cuándo se guardó cada servicio **en esta sesión**, por `servicioId`.

  ///

  /// La barra necesita la hora del último guardado y hay dos fuentes: lo que

  /// trajo la precarga (`cargaPrevia.actualizadoEn`) y lo que se guardó desde

  /// esta pantalla. La segunda solo la conoce la página: el estado del

  /// formulario no la registra, y `cargaPrevia` sigue apuntando a lo que había

  /// antes de editar hasta que se vuelva a entrar. Va por servicio porque las

  /// flechas recorren trece sin cambiar de ruta.

  final Map<String, DateTime> _guardadoEnSesion = {};

  bool get _esModoPorDias =>
      widget.fechas != null && widget.servicioFijo != null;

  Servicio get _servicio =>
      _esModoPorDias ? widget.servicioFijo! : widget.servicios[_indice];

  DateTime get _fecha =>
      _esModoPorDias ? widget.fechas![_indice] : widget.fecha!;

  ArgsFormulario get _args => (fecha: _fecha, servicio: _servicio);

  int get _totalItems =>
      _esModoPorDias ? widget.fechas!.length : widget.servicios.length;

  bool get _hayAnterior => _indice > 0;

  bool get _haySiguiente => _indice < _totalItems - 1;

  String get _claveSesion => _esModoPorDias
      ? '${_fecha.year}-${_fecha.month}-${_fecha.day}'
      : _servicio.id;

  static String _nombreMes(DateTime fecha) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return meses[fecha.month - 1];
  }

  static String _dosDigitos(int n) => n.toString().padLeft(2, '0');

  @override

  void initState() {

    super.initState();

    _suscripcionNivel = ref.read(servicioDictadoProvider).nivelDeSonido.listen(

          (nivel) => mounted ? setState(() => _nivelSonido = nivel) : null,

        );

  }

  @override

  void dispose() {

    _suscripcionNivel?.cancel();

    super.dispose();

  }

  /// "Listo": cierra la escucha conservando lo dictado.

  Future<void> _confirmarEscucha() async {

    await ref.read(servicioDictadoProvider).detener();

  }

  /// "Cancelar": descarta la sesión sin proponer nada.

  Future<void> _cancelarEscucha(CensoFormLogica logica) async {

    await ref.read(servicioDictadoProvider).cancelar();

    if (!mounted) return;

    setState(() => _inicioEscucha = null);

    logica.cancelarEscucha();

  }

  @override

  Widget build(BuildContext context) {

    final estado = ref.watch(censoFormProvider(_args));

    final logica = ref.read(censoFormProvider(_args).notifier).logica;

    final puedeEscribir = ref.watch(puedeEscribirProvider);

    // La hoja de confirmación se abre como efecto de la fase, no desde el

    // callback del motor de voz: así el único camino hacia ella es la máquina

    // de estados.

    ref.listen(censoFormProvider(_args), (_, nuevo) {

      if (nuevo.fase == FaseFormulario.confirmandoVoz && !_hojaAbierta) {

        _abrirHoja();

      } else if (nuevo.fase != FaseFormulario.confirmandoVoz && _hojaAbierta) {

        _cerrarHoja();

      }

    });

    return PopScope(

      canPop: false,

      onPopInvokedWithResult: (yaSalio, _) async {

        if (yaSalio) return;

        if (await _resolverAntesDeNavegar(estado, logica) && mounted) {

          Navigator.of(context).pop();

        }

      },

      child: Scaffold(

        appBar: AppBar(

          title: Text(_servicio.nombre),

          actions: [

            IconButton(

              onPressed: () => showDialog<void>(

                context: context,

                builder: (_) => const GuiaTranscripcionEst1(),

              ),

              icon: const Icon(Icons.help_outline),

              tooltip: 'Cómo se corresponde con el formulario',

            ),

          ],

        ),

        floatingActionButton:

            estado.fase == FaseFormulario.escuchandoVoz

                ? null

                : _botonDictado(estado, logica),

        // Mientras se dicta, el panel de escucha reemplaza la barra de

        // navegación: no tiene sentido ofrecer "servicio siguiente" a alguien

        // que está hablando, y el espacio es el mismo.

        bottomNavigationBar: estado.fase == FaseFormulario.escuchandoVoz

            ? PanelEscuchaActiva(

                transcripcionParcial: estado.transcripcionParcial,

                nivel: _nivelSonido,

                inicio: _inicioEscucha ?? DateTime.now(),

                duracionMaxima:

                    ServicioDictadoSpeechToText.duracionPorDefecto,

                alConfirmar: _confirmarEscucha,

                alCancelar: () => _cancelarEscucha(logica),

              )

            : BarraNavegacionServicios(

                indice: _indice,

                total: _totalItems,

                etiquetaProgreso: _esModoPorDias
                    ? 'Día ${_fecha.day} (${_indice + 1} de $_totalItems)'
                    : null,

                etiquetaBotonGuardar: _esModoPorDias
                    ? 'Guardar día ${_fecha.day}'
                    : null,

                etiquetaAnterior: _esModoPorDias ? 'Día anterior' : null,

                etiquetaSiguiente: _esModoPorDias ? 'Día siguiente' : null,

                guardando: estado.fase == FaseFormulario.guardando,

                hayCambiosSinGuardar: estado.hayCambiosSinGuardar,

                // Lo guardado en esta sesión gana sobre la procedencia: es más

                // nuevo por definición, porque acaba de reemplazarla.

                guardadoEn: _guardadoEnSesion[_claveSesion] ??

                    estado.cargaPrevia?.actualizadoEn,

                mensajeBloqueo: _mensajeBloqueo(estado, puedeEscribir),

                alAnterior: _hayAnterior ? () => _irA(_indice - 1) : null,

                alSiguiente: _haySiguiente ? () => _irA(_indice + 1) : null,

                alGuardar: estado.puedeGuardar && puedeEscribir

                    ? () => _guardar(logica)

                    : null,

              ),

        body: Column(

          children: [

            IndicadorCuadre(estado: estado),

            Expanded(

              child: ListView(

                // Clave por servicio: al navegar, la lista arranca arriba en

                // vez de conservar el desplazamiento del servicio anterior.

                key: ValueKey(_servicio.id),

                padding: const EdgeInsets.only(bottom: 96),

                children: [

                  // Arriba de todo y dentro de la lista: se lee una vez, al

                  // abrir, y después no tiene por qué seguir ocupando alto en

                  // una pantalla donde nueve campos compiten con el teclado.

                  if (estado.cargaPrevia != null)

                    LineaProcedencia(carga: estado.cargaPrevia!),

                  if (estado.falloLecturaPrevia) const AvisoLecturaFallida(),

                  if (estado.falla != null)

                    BannerFallaApi(

                      falla: estado.falla!,

                      alReintentar: logica.reintentar,

                    ),

                  ListaValidaciones(validaciones: estado.validaciones),

                                    _Encabezado(
                    'Movimientos del día',
                    icono: Icons.sync_alt_rounded,
                    badgeTexto: ' ing • egr',
                    accion: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _llenarCerosEnVacios(estado, logica),
                      icon: const Icon(Icons.exposure_zero, size: 16),
                      label: const Text(
                        'Poner 0 en vacíos',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  for (final campo in _movimientos)

                    _campo(estado, logica, campo),

                  const _Encabezado(

                    'Camas',

                    icono: Icons.bed_outlined,

                  ),

                  for (final campo in _camas) _campo(estado, logica, campo),

                  const _Encabezado(

                    'Cierre',

                    icono: Icons.done_all_rounded,

                  ),

                  _campo(estado, logica, CampoCenso.total, ultimo: true),

                  PanelSaldoEsperado(estado: estado),

                  _PanelDotacion(estado: estado),

                  // Al final y colapsada: no participa de ninguna fórmula, y

                  // ponerla en medio cortaría la cadena de nueve campos que se

                  // completa con "siguiente" sin cerrar el teclado.

                  SeccionCamasPrestadas(

                    camas: estado.censo.camasPrestadas,

                    especialidades:

                        ref.watch(especialidadesProvider).valueOrNull ??

                            const [],

                    habilitado: puedeEscribir &&

                        estado.fase == FaseFormulario.edicion,

                    alCambiar: logica.reemplazarCamasPrestadas,

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }

  static const _movimientos = [

    CampoCenso.ingreso,

    CampoCenso.ingresoTraslado,

    CampoCenso.egreso,

    CampoCenso.egresoTraslado,

    CampoCenso.obito,

  ];

  static const _camas = [

    CampoCenso.aislamiento,

    CampoCenso.bloqueada,

    CampoCenso.libre,

  ];

  String? _mensajeBloqueo(CensoFormState estado, bool puedeEscribir) {

    if (!puedeEscribir) {

      return 'Tu cuenta es de consulta: podés revisar el censo pero no '

          'guardarlo.';

    }

    if (estado.tieneVozPendiente) {

      return 'Resolvé el dictado pendiente antes de guardar.';

    }

    if (estado.validaciones.hayBloqueantes) {

      return 'Corregí lo señalado para poder guardar.';

    }

    return null;

  }

  Widget _campo(

    CensoFormState estado,

    CensoFormLogica logica,

    CampoCenso campo, {

    bool ultimo = false,

  }) {

    // Camas libres se sugiere, no se calcula: el valor del papel es el único

    // control cruzado sobre los otros cuatro números (ADR-0005, D-11).

    final sugerido =

        campo == CampoCenso.libre ? estado.camasLibresSugeridas : null;

    return CampoNumericoCenso(

      // Sin key propia, Flutter reutilizaría el State del campo homólogo del

      // servicio anterior y el TextEditingController mostraría su valor.

      key: ValueKey('${_servicio.id}-${campo.name}'),

      campo: campo,

      valor: estado.censo.valorDe(campo),

      origen: estado.origenDe(campo),

      resaltado: estado.validaciones.any((v) => v.campo == campo),

      ultimo: ultimo,

      valorSugerido: sugerido,

      explicacionSugerencia: sugerido == null

          ? null

          : 'Capacidad ${estado.capacidad} âˆ’ saldo ${estado.censo.total} '

              'âˆ’ bloqueadas ${estado.censo.bloqueada} '

              'âˆ’ aislamiento ${estado.censo.aislamiento}',

      alAceptarSugerencia: sugerido == null

          ? null

          : () => logica.cambiarCampo(CampoCenso.libre, sugerido),

      alCambiar: (valor) => logica.cambiarCampo(campo, valor),

    );

  }

  // â”€â”€ Navegación entre servicios â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    void _llenarCerosEnVacios(CensoFormState estado, CensoFormLogica logica) {
    HapticFeedback.lightImpact();
    for (final campo in _movimientos) {
      if (estado.censo.valorDe(campo) == 0) {
        logica.cambiarCampo(campo, 0);
      }
    }
  }

Future<void> _irA(int nuevoIndice) async {

    final estado = ref.read(censoFormProvider(_args));

    final logica = ref.read(censoFormProvider(_args).notifier).logica;

    if (!await _resolverAntesDeNavegar(estado, logica)) return;

    if (!mounted) return;

    FocusScope.of(context).unfocus();

    // El servicio nuevo se precarga solo: `censoFormProvider` lee la caché de

    // la fecha al construirse. Nada que sincronizar desde la lista de progreso.

    setState(() => _indice = nuevoIndice);

  }

  /// Decide qué hacer con el trabajo en pantalla antes de moverse.

  ///

  /// Navegar nunca descarta datos en silencio. El orden es deliberado:

  /// 1. sin cambios → sigue de largo, sin molestar;

  /// 2. con cambios y todo en orden → **guarda solo** y sigue, que es lo que

  ///    el operador iba a hacer de todas formas;

  /// 3. con cambios que no se pueden guardar → pregunta, porque acá sí hay una

  ///    decisión real que tomar.

  Future<bool> _resolverAntesDeNavegar(

    CensoFormState estado,

    CensoFormLogica logica,

  ) async {

    if (!estado.hayCambiosSinGuardar) return true;

    final puedeEscribir = ref.read(puedeEscribirProvider);

    if (estado.puedeGuardar && puedeEscribir) {

      final guardo = await _guardar(logica);

      if (guardo) return true;

      if (!mounted) return false;

      return _preguntarSiDescartar(

        titulo: 'No se pudo guardar',

        cuerpo: 'Los cambios de ${_servicio.nombre} siguen sin enviarse. '

            'Si continuás, se pierden.',

      );

    }

    if (!mounted) return false;

    return _preguntarSiDescartar(

      titulo: 'Cambios sin guardar',

      cuerpo: !puedeEscribir

          ? 'Tu cuenta es de consulta, así que lo que cargaste en '

              '${_servicio.nombre} no se puede guardar.'

          : 'Lo cargado en ${_servicio.nombre} todavía no se puede guardar. '

              'Si continuás, se pierde.',

    );

  }

  /// Pregunta antes de tirar trabajo. `true` significa descartar.

  ///

  /// El énfasis está puesto en quedarse, no en descartar. Antes era al revés,

  /// y era defendible mientras el `keepAlive` sostenía el formulario en

  /// memoria: descartar tenía red y el diálogo exageraba. Desde que se retiró

  /// (SPEC-003, D-3) el trabajo se pierde de verdad, así que el botón

  /// destacado no puede seguir siendo el destructivo.

  Future<bool> _preguntarSiDescartar({

    required String titulo,

    required String cuerpo,

  }) async {

    final descartar = await showDialog<bool>(

      context: context,

      builder: (contexto) => AlertDialog(

        icon: const Icon(Icons.warning_amber, color: TemaApp.advertencia),

        title: Text(titulo),

        content: Text(cuerpo),

        actions: [

          TextButton(

            onPressed: () => Navigator.of(contexto).pop(true),

            child: const Text('Descartar y seguir'),

          ),

          FilledButton(

            onPressed: () => Navigator.of(contexto).pop(false),

            child: const Text('Quedarme acá'),

          ),

        ],

      ),

    );

    return descartar ?? false;

  }

  Future<bool> _guardar(CensoFormLogica logica) async {

    final guardo = await logica.guardar();

    if (!mounted) return guardo;

    if (guardo) {

      // El servicio es el que estaba abierto al llamar: `_irA` resuelve el

      // guardado antes de mover `_indice`, así que la hora queda en la clave

      // correcta.

      setState(() => _guardadoEnSesion[_claveSesion] = DateTime.now());

      ScaffoldMessenger.of(context)

        ..hideCurrentSnackBar()

        ..showSnackBar(

          SnackBar(

            content: Text('${_servicio.nombre}: guardado.'),

            duration: const Duration(seconds: 2),

          ),

        );

    }

    return guardo;

  }

  // â”€â”€ Dictado â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget? _botonDictado(CensoFormState estado, CensoFormLogica logica) {

    // Sin permiso o sin locale española el botón no aparece: el formulario es

    // 100% operable con teclado y un botón roto sería peor que ninguno.

    if (_estadoDictado == EstadoDictado.sinLocaleEspanol ||

        _estadoDictado == EstadoDictado.noDisponible) {

      return null;

    }

    if (estado.fase == FaseFormulario.confirmandoVoz) return null;

    final escuchando = estado.fase == FaseFormulario.escuchandoVoz;

    return FloatingActionButton.extended(

      onPressed: () => _alternarDictado(estado, logica),

      icon: Icon(escuchando ? Icons.stop : Icons.mic),

      label: Text(escuchando ? 'Detener' : 'Dictar cifras'),

    );

  }

  Future<void> _alternarDictado(

    CensoFormState estado,

    CensoFormLogica logica,

  ) async {

    final servicio = ref.read(servicioDictadoProvider);

    if (estado.fase == FaseFormulario.escuchandoVoz) {

      // Detener conserva lo dictado: el resultado llega por `alResultado`.

      await servicio.detener();

      return;

    }

    // El permiso se pide en el primer toque del botón, nunca al abrir la

    // pantalla: pedirlo sin contexto es la forma más rápida de que lo nieguen.

    final resultado = await servicio.inicializar();

    if (!mounted) return;

    setState(() => _estadoDictado = resultado);

    if (resultado != EstadoDictado.listo) {

      _avisarDictadoNoDisponible(resultado);

      return;

    }

    logica.empezarEscucha();

    setState(() {

      _inicioEscucha = DateTime.now();

      _nivelSonido = 0;

    });

    await servicio.escuchar(

      alResultado: (r) {

        // Los parciales alimentan el panel en vivo. Es lo que convierte una

        // pantalla que "no hace nada" en una que responde.

        if (!r.esFinal) {

          logica.actualizarTranscripcionParcial(r.transcripcion);

          return;

        }

        if (mounted) setState(() => _inicioEscucha = null);

        logica.procesarTranscripcion(r.transcripcion, confianza: r.confianza);

      },

      alError: (mensaje) {

        logica.cancelarEscucha();

        if (mounted) {

          ScaffoldMessenger.of(context)

              .showSnackBar(SnackBar(content: Text(mensaje)));

        }

      },

      // Android cierra la escucha por su cuenta cuando detecta silencio, casi

      // siempre antes que nuestro `pauseFor`. Sin este aviso el formulario se

      // quedaría en fase `escuchandoVoz`, con el botón diciendo "Detener" y sin

      // forma de guardar.

      alDetenerse: () {

        if (estado.fase == FaseFormulario.escuchandoVoz) {

          logica.cancelarEscucha();

        }

      },

    );

  }

  void _avisarDictadoNoDisponible(EstadoDictado estado) {

    final mensaje = switch (estado) {

      EstadoDictado.sinPermiso =>

        'Necesitamos permiso para usar el micrófono. Podés activarlo desde '

            'los ajustes del sistema.',

      EstadoDictado.sinLocaleEspanol =>

        'Este dispositivo no tiene reconocimiento de voz en español. Podés '

            'llenar el formulario con el teclado.',

      _ => 'El dictado no está disponible en este dispositivo.',

    };

    ScaffoldMessenger.of(context)

        .showSnackBar(SnackBar(content: Text(mensaje)));

  }

  Future<void> _abrirHoja() async {

    _hojaAbierta = true;

    final logica = ref.read(censoFormProvider(_args).notifier).logica;

    await showModalBottomSheet<void>(

      context: context,

      isScrollControlled: true,

      isDismissible: false,

      enableDrag: false,

      builder: (context) {

        return Consumer(

          builder: (context, ref, _) {

            final estado = ref.watch(censoFormProvider(_args));

            final propuesta = estado.propuestaPendiente;

            if (propuesta == null) return const SizedBox.shrink();

            return HojaConfirmacionVoz(

              propuesta: propuesta,

              alAlternar: (campo, {required aceptado}) =>

                  logica.alternarCampoPropuesto(campo, aceptado: aceptado),

              alAplicar: logica.confirmarPropuesta,

              alDescartar: logica.descartarPropuesta,

              alRepetir: () {

                logica.descartarPropuesta();

                Future.microtask(

                  () => _alternarDictado(

                    ref.read(censoFormProvider(_args)),

                    logica,

                  ),

                );

              },

            );

          },

        );

      },

    );

    _hojaAbierta = false;

  }

  void _cerrarHoja() {

    if (!_hojaAbierta) return;

    _hojaAbierta = false;

    Navigator.of(context).pop();

  }

}

class _Encabezado extends StatelessWidget {
  const _Encabezado(
    this.texto, {
    this.icono,
    this.badgeTexto,
    this.accion,
    super.key,
  });

  final String texto;
  final IconData? icono;
  final String? badgeTexto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Row(
        children: [
          if (icono != null) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: esquema.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icono, size: 15, color: esquema.primary),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              texto.toUpperCase(),
              style: tema.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.1,
                color: esquema.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (badgeTexto != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: esquema.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                badgeTexto!,
                style: tema.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (accion != null) ...[
            const SizedBox(width: 8),
            accion!,
          ],
        ],
      ),
    );
  }
}

class _PanelDotacion extends StatelessWidget {

  const _PanelDotacion({required this.estado});

  final CensoFormState estado;

  @override

  Widget build(BuildContext context) {

    final tema = Theme.of(context);

    final esquema = tema.colorScheme;

    return Card(

      elevation: 0,

      shape: RoundedRectangleBorder(

        borderRadius: BorderRadius.circular(14),

        side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.45)),

      ),

      color: esquema.surfaceContainerLow,

      child: ListTile(

        leading: Container(

          padding: const EdgeInsets.all(8),

          decoration: BoxDecoration(

            color: esquema.primary.withValues(alpha: 0.12),

            shape: BoxShape.circle,

          ),

          child: Icon(Icons.calculate_outlined, color: esquema.primary, size: 22),

        ),

        title: const Text('Dotación', style: TextStyle(fontWeight: FontWeight.w600)),

        subtitle: const Text(

          'Saldo + camas libres. No se envía: el servidor la recalcula.',

        ),

        trailing: Text(

          '',

          style: tema.textTheme.headlineSmall?.copyWith(

            fontWeight: FontWeight.w800,

            color: esquema.primary,

          ),

        ),

      ),

    );

  }

}

class GuiaTranscripcionEst1 extends StatelessWidget {

  const GuiaTranscripcionEst1({super.key});

  @override

  Widget build(BuildContext context) {

    final tema = Theme.of(context);

    return AlertDialog(

      title: const Text('Del papel a la app'),

      content: SizedBox(

        width: double.maxFinite,

        child: ListView(

          shrinkWrap: true,

          children: [

            Text(

              'El formulario impreso quedó desactualizado. Esta es la '

              'correspondencia vigente.',

              style: tema.textTheme.bodySmall,

            ),

            const SizedBox(height: 12),

            for (final campo in CampoCenso.values)

              Padding(

                padding: const EdgeInsets.symmetric(vertical: 6),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      campo.etiqueta,

                      style: const TextStyle(fontWeight: FontWeight.w600),

                    ),

                    Text(

                      campo.ayudaFormulario,

                      style: tema.textTheme.bodySmall,

                    ),

                  ],

                ),

              ),

            const Divider(height: 24),

            Text(

              'Los ingresos y egresos por traslado no tienen fila propia en el '

              'resumen: salen de contar los bloques POR TRASLADO DEL SERVICIO.',

              style: tema.textTheme.bodySmall,

            ),

          ],

        ),

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.of(context).pop(),

          child: const Text('Entendido'),

        ),

      ],

    );

  }

}

