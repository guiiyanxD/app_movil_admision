import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';

/// `GET /reporteria/censo-mensual` — camelCase, ya presentado por el backend.
class FilaReporteCensoDto {
  const FilaReporteCensoDto({
    required this.periodo,
    required this.servicio,
    required this.ingreso,
    required this.ingresoTraslado,
    required this.egreso,
    required this.egresoTraslado,
    required this.obito,
    required this.aislamiento,
    required this.bloqueada,
    required this.total,
  });

  factory FilaReporteCensoDto.fromJson(Map<String, dynamic> json) {
    // Los agregados salen de un `SUM(...)::int` de Postgres. Se leen como `num`
    // y se convierten, porque un JSON puede traer el entero como double sin que
    // eso signifique nada.
    int entero(String clave) => (json[clave] as num?)?.toInt() ?? 0;

    return FilaReporteCensoDto(
      periodo: json['periodo'] as String,
      servicio: json['servicio'] as String,
      ingreso: entero('ingreso'),
      ingresoTraslado: entero('ingresoTraslado'),
      egreso: entero('egreso'),
      egresoTraslado: entero('egresoTraslado'),
      obito: entero('obito'),
      aislamiento: entero('aislamiento'),
      bloqueada: entero('bloqueada'),
      total: entero('total'),
    );
  }

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

  FilaReporteCenso toDomain() => FilaReporteCenso(
        periodo: periodo,
        servicio: servicio,
        ingreso: ingreso,
        ingresoTraslado: ingresoTraslado,
        egreso: egreso,
        egresoTraslado: egresoTraslado,
        obito: obito,
        aislamiento: aislamiento,
        bloqueada: bloqueada,
        total: total,
      );
}
