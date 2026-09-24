import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';

abstract interface class ReporteriaRepository {
  /// Movimientos por servicio en un rango, agrupados por día o por mes.
  ///
  /// Lee `public.censo`, así que **solo devuelve fechas ya confirmadas**. Una
  /// carga manual sin confirmar no aparece: es la semántica correcta para un
  /// reporte estadístico, pero la pantalla tiene que decirlo (SPEC-004, D-4).
  Future<Resultado<List<FilaReporteCenso>>> obtenerCensoMensual({
    required RangoFechas rango,
    required AgrupacionReporte agrupacion,
  });
}
