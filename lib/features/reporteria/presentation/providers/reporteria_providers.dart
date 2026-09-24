import 'package:app_movil/features/reporteria/domain/repositories/reporteria_repository.dart';
import 'package:app_movil/features/reporteria/domain/usecases/armar_matriz_reporte.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Acceso al módulo de reportería. **Lo inyecta la raíz de composición.**
///
/// Mismo criterio que `censoRepositoryProvider`: el tipo es la interfaz y la
/// implementación la elige `bootstrap()` (SPEC-005, H-6 y H-7).
final reporteriaRepositoryProvider = Provider<ReporteriaRepository>((ref) {
  throw UnimplementedError(
    'reporteriaRepositoryProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});

final armarMatrizProvider = Provider<ArmarMatrizReporte>((ref) {
  return const ArmarMatrizReporte();
});

/// Orden institucional de las columnas, en nomenclatura de vaciado.
///
/// Es el orden que Admisión configuró en `Servicio.indice`, cruzado con el
/// mapeo a vaciado (SPEC-004, D-2). **Lo inyecta la raíz de composición.**
///
/// El catálogo lo publica el censo diario, y leerlo desde acá obligaba a esta
/// feature a importar la presentación de aquella (SPEC-005, H-8). Reportería
/// declara *qué* necesita —una lista de nombres ordenada— y `bootstrap()`
/// decide de dónde sale. Si mañana el orden viene del backend, cambia el
/// override y no esta feature.
///
/// **Nunca debe fallar.** Quien lo satisfaga tiene que devolver lista vacía si
/// el catálogo no se pudo leer: el reporte se arma igual, alfabéticamente, y la
/// pantalla lo declara. Que el orden de las columnas impida ver las cifras
/// sería desproporcionado.
final ordenServiciosProvider = FutureProvider<List<String>>((ref) async {
  throw UnimplementedError(
    'ordenServiciosProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});

/// Lo que identifica un reporte: el rango y cómo se agrupan los períodos.
///
/// Es un record, así que dos consultas iguales comparten el mismo estado del
/// provider —y la misma respuesta— sin trabajo extra.
typedef ConsultaReporte = ({RangoFechas rango, AgrupacionReporte agrupacion});

/// El reporte completo: las ocho matrices, más si el orden es el institucional.
typedef ReporteArmado = ({
  List<MatrizReporte> matrices,
  bool ordenInstitucional,
});

/// Trae las filas del período y arma los ocho movimientos de una sola vez.
///
/// `autoDispose`: un rango consultado no tiene por qué sobrevivir a la
/// pantalla, y el censo confirmado de un período puede crecer mientras la app
/// está abierta.
///
/// Lanza la `Failure` tal cual para que la pantalla la muestre con su
/// sugerencia y un botón de reintento (CA-12).
final reporteProvider = FutureProvider.autoDispose
    .family<ReporteArmado, ConsultaReporte>((ref, consulta) async {
  // Las dependencias se leen antes de cualquier `await`: después del primero el
  // provider puede haber sido descartado y `ref` deja de ser seguro.
  final repositorio = ref.watch(reporteriaRepositoryProvider);
  final armar = ref.watch(armarMatrizProvider);
  final orden = ref.watch(ordenServiciosProvider.future);

  final resultado = await repositorio.obtenerCensoMensual(
    rango: consulta.rango,
    agrupacion: consulta.agrupacion,
  );

  final filas = resultado.fold(
    (falla) => throw falla,
    (filas) => filas,
  );

  final ordenConocido = await orden;

  return (
    matrices: armar.todos(filas: filas, ordenConocido: ordenConocido),
    ordenInstitucional: ordenConocido.isNotEmpty,
  );
});
