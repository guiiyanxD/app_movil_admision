import 'package:app_movil/features/reporteria/data/models/fila_reporte_censo_dto.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:dio/dio.dart';

/// Acceso HTTP al módulo de reportería.
///
/// No captura errores: deja pasar la `DioException` para que el repositorio la
/// traduzca a una `Failure` en un solo lugar.
class ReporteriaRemoteDataSource {
  const ReporteriaRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<FilaReporteCensoDto>> obtenerCensoMensual({
    required RangoFechas rango,
    required AgrupacionReporte agrupacion,
  }) async {
    final respuesta = await _dio.get<Object?>(
      '/reporteria/censo-mensual',
      queryParameters: {
        'fechaInicio': rango.inicioComoParametro,
        'fechaFin': rango.finComoParametro,
        // El backend lo lee como string y compara contra `'false'`, así que se
        // manda el literal y no un bool que Dio serializaría a su manera.
        'detalle': agrupacion.comoParametroDetalle ? 'true' : 'false',
      },
    );

    final data = respuesta.data;
    if (data is! List) {
      throw FormatException(
        'Se esperaba una lista de filas y llegó ${data.runtimeType}',
      );
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(FilaReporteCensoDto.fromJson)
        .toList();
  }
}
