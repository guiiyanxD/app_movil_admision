import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';

/// Una fila de `GET /reporteria/censo-mensual`: un período y un servicio.
///
/// `servicio` es el nombre de **vaciado-admisión**, no el del catálogo propio.
/// Vienen sin tildes (`Pediatria`, `Neonatologia`) porque así están en
/// `public.censo`. Cruzarlos con el catálogo local exige pasar por el mapeo.
class FilaReporteCenso {
  const FilaReporteCenso({
    required this.periodo,
    required this.servicio,
    this.ingreso = 0,
    this.ingresoTraslado = 0,
    this.egreso = 0,
    this.egresoTraslado = 0,
    this.obito = 0,
    this.aislamiento = 0,
    this.bloqueada = 0,
    this.total = 0,
  });

  /// `YYYY-MM-DD` con detalle diario, `YYYY-MM` con resumen mensual.
  final String periodo;

  final String servicio;

  final int ingreso;
  final int ingresoTraslado;
  final int egreso;
  final int egresoTraslado;
  final int obito;
  final int aislamiento;
  final int bloqueada;
  final int total;

  int valorDe(MovimientoReporte movimiento) => switch (movimiento) {
        MovimientoReporte.ingreso => ingreso,
        MovimientoReporte.ingresoTraslado => ingresoTraslado,
        MovimientoReporte.egreso => egreso,
        MovimientoReporte.egresoTraslado => egresoTraslado,
        MovimientoReporte.obito => obito,
        MovimientoReporte.aislamiento => aislamiento,
        MovimientoReporte.bloqueada => bloqueada,
        MovimientoReporte.total => total,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilaReporteCenso &&
          other.periodo == periodo &&
          other.servicio == servicio &&
          MovimientoReporte.values
              .every((m) => other.valorDe(m) == valorDe(m));

  @override
  int get hashCode => Object.hash(
        periodo,
        servicio,
        Object.hashAll(MovimientoReporte.values.map(valorDe)),
      );

  @override
  String toString() => 'FilaReporteCenso($periodo, $servicio)';
}
