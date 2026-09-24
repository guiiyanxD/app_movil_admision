import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_controller.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Acceso al censo diario. **Lo inyecta la raíz de composición.**
///
/// El tipo es la interfaz de `domain/`; quién la implementa lo decide
/// `bootstrap()`. Antes este archivo construía el datasource y el repositorio
/// concretos, así que la capa de presentación elegía contra qué
/// infraestructura corría y no había forma de montar una pantalla sin red
/// (SPEC-005, H-6 y H-7).
///
/// Sustituirlo en un test es un `overrideWithValue` con un doble del contrato.
final censoRepositoryProvider = Provider<CensoDiarioRepository>((ref) {
  throw UnimplementedError(
    'censoRepositoryProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});

// `servicioDictadoProvider` se mudó a `core/voz/voz_providers.dart`. El motor
// de dictado ya vivía en `core/voz/`; tenerlo declarado acá obligaba a la
// pantalla de diagnóstico —que solo mide el micrófono— a importar la
// presentación del censo diario (SPEC-005, H-8).

/// Catálogo de servicios activos, ya cruzado con su mapeo a vaciado.
///
/// Se cachea por sesión: es un catálogo que cambia poco y pedirlo en cada
/// pantalla sería castigar una conexión de hospital por nada.
final serviciosProvider = FutureProvider<List<Servicio>>((ref) async {
  final resultado = await ref.watch(censoRepositoryProvider)
      .obtenerServiciosActivos();

  return resultado.fold(
    (falla) => throw falla,
    (servicios) => servicios,
  );
});

/// Especialidades disponibles para camas prestadas.
///
/// Devuelve **solo las que tienen mapeo hacia vaciado**, porque el endpoint las
/// lee de la tabla de mapeo. Eso es exactamente lo que queremos: elegir una
/// especialidad sin mapeo garantizaría un 400 al confirmar el día, así que no
/// debería ni aparecer en el selector.
final especialidadesProvider = FutureProvider<List<MapeoVaciado>>((ref) async {
  final resultado =
      await ref.watch(censoRepositoryProvider).obtenerMapeoEspecialidades();

  return resultado.fold(
    (falla) => throw falla,
    (especialidades) => especialidades
      ..sort((a, b) => a.nombreVaciado.compareTo(b.nombreVaciado)),
  );
});

/// Cierre de una fecha, para bloquear en el calendario las ya cerradas por el
/// cálculo automático (V-09) antes de que el operador empiece a cargar.
final cierreProvider =
    FutureProvider.family<CierreCenso?, DateTime>((ref, fecha) async {
  final resultado = await ref.watch(censoRepositoryProvider).obtenerCierre(fecha);
  return resultado.fold((falla) => throw falla, (cierre) => cierre);
});

/// Progreso del día. `autoDispose` a propósito: debe refrescarse al volver a
/// la pantalla, porque `cuadra` se recalcula contra la capacidad actual.
final progresoDiaProvider =
    FutureProvider.autoDispose.family<ProgresoDia, DateTime>((ref, fecha) async {
  final resultado =
      await ref.watch(censoRepositoryProvider).obtenerProgresoDia(fecha);
  return resultado.fold((falla) => throw falla, (progreso) => progreso);
});

/// Lo que el servidor ya tiene guardado en staging para una fecha, indexado
/// por `servicioId`, más si esa lectura se pudo hacer.
///
/// La bandera existe porque un mapa vacío es ambiguo: puede significar "ningún
/// servicio tiene carga" o "no pude leer". El formulario necesita
/// distinguirlos, porque el segundo caso abre en cero **y lo declara** en vez
/// de presentar los ceros como si fueran el estado real del servidor
/// (SPEC-003, D-3 y CA-07).
typedef CargasDelDia = ({
  Map<String, CargaGuardada> porServicio,
  bool fallo,
});

/// Caché de la carga manual de una fecha completa.
///
/// Pide **toda la fecha en una sola llamada**, sin filtrar por servicio: el
/// formulario navega con flechas sin apilar rutas, así que pedir servicio por
/// servicio costaría trece peticiones para recorrer un día, de noche y sobre
/// la red de un hospital (SPEC-003, D-1 y CA-05).
///
/// No es `autoDispose`, a diferencia de [progresoDiaProvider]: la caché tiene
/// que sobrevivir justo al instante en que el formulario anterior se descarta,
/// que es cuando el operador salta al servicio siguiente. Lo que la mantiene
/// fresca es la invalidación tras cada guardado (D-4), no el ciclo de vida.
///
/// **Nunca lanza.** Un `AsyncError` acá impediría abrir el formulario, y
/// dejaría al operador sin poder trabajar por una lectura que es una mejora,
/// no un requisito: el fallo viaja como valor y lo resuelve quien lo consume.
final cargasDelDiaProvider =
    FutureProvider.family<CargasDelDia, DateTime>((ref, fecha) async {
  final resultado =
      await ref.watch(censoRepositoryProvider).obtenerCargasDelDia(fecha);

  return resultado.fold<CargasDelDia>(
    (falla) => (porServicio: const <String, CargaGuardada>{}, fallo: true),
    (cargas) => (
      porServicio: {
        for (final carga in cargas) carga.censo.servicioId: carga,
      },
      fallo: false,
    ),
  );
});

typedef ArgsFormulario = ({DateTime fecha, Servicio servicio});

/// Formulario de un servicio en una fecha.
///
/// Los argumentos son un record, así que la igualdad estructural hace que dos
/// navegaciones al mismo servicio y fecha compartan estado sin trabajo extra.
final censoFormProvider = NotifierProvider.autoDispose
    .family<CensoFormNotifier, CensoFormState, ArgsFormulario>(
  CensoFormNotifier.new,
);

/// Formulario de un servicio, alimentado por la caché de la fecha.
///
/// **No retiene el estado en memoria.** El `keepAlive` que se agregó el
/// 2026-08-02 fue la curita mientras el API no permitía leer el staging: ahora
/// que se puede, mantener ambos crearía dos fuentes de verdad y un formulario
/// retenido podría mostrar valores más viejos que los del servidor —otro
/// operador editando la misma fecha desde otro dispositivo— ganando por estar
/// primero. Al volver a un servicio, el estado se recupera de
/// [cargasDelDiaProvider] (SPEC-003, D-3).
class CensoFormNotifier
    extends AutoDisposeFamilyNotifier<CensoFormState, ArgsFormulario> {
  late final CensoFormLogica _logica;

  bool _desechado = false;

  @override
  CensoFormState build(ArgsFormulario arg) {
    // La precarga y `cargarReferencias` siguen en vuelo aunque el provider se
    // descarte: si el operador abre un servicio y navega antes de que respondan
    // la caché, la capacidad y el día anterior, el callback llegaría a un
    // notifier muerto. Escribir `state` ahí revienta, así que se corta antes.
    ref.onDispose(() => _desechado = true);

    _logica = CensoFormLogica(
      repositorio: ref.watch(censoRepositoryProvider),
      estadoInicial: CensoFormState.inicial(
        servicio: arg.servicio,
        fecha: arg.fecha,
      ),
    )..alCambiar = (nuevo) {
        if (_desechado) return;
        _invalidarCacheSiGuardo(nuevo);
        state = nuevo;
      };

    // `read` y no `watch`: observar la caché haría que la invalidación de D-4
    // reconstruyera el notifier, y el formulario abierto se reiniciaría solo
    // por haber guardado. Y se toma acá dentro de `build` y no dentro del
    // microtask porque para cuando ese corra el provider puede estar
    // descartado, y `ref` ya no se puede tocar.
    final cache = ref.read(cargasDelDiaProvider(arg.fecha).future);

    // Se dispara sin await: el estado inicial ya es renderizable y la pantalla
    // muestra el formulario mientras llegan la caché, la capacidad y el total
    // del día anterior.
    Future.microtask(() async {
      final cargas = await cache;
      if (_desechado) return;

      // La caché distingue "este servicio no tenía nada" de "no pude leer", que
      // es justo lo que `cargarReferencias` necesita para decidir si abre en
      // cero en silencio o avisando.
      await _logica.cargarReferencias(
        cargaPrevia: cargas.porServicio[arg.servicio.id],
        falloLectura: cargas.fallo,
      );
    });

    return _logica.estado;
  }

  /// Tira la caché de la fecha después de un `POST` exitoso.
  ///
  /// [FaseFormulario.guardado] es la única señal de que el servidor aceptó, y
  /// llega justo antes del regreso inmediato a `edicion`. Engancharse acá cubre
  /// todas las vías de guardado —el botón, las flechas que guardan solas— sin
  /// que cada una tenga que acordarse. Sin esto, volver a un servicio recién
  /// guardado lo repoblaría con los valores anteriores a la edición (SPEC-003,
  /// D-4 y CA-06).
  void _invalidarCacheSiGuardo(CensoFormState nuevo) {
    if (nuevo.fase != FaseFormulario.guardado) return;
    ref.invalidate(cargasDelDiaProvider(arg.fecha));
  }

  CensoFormLogica get logica => _logica;
}
