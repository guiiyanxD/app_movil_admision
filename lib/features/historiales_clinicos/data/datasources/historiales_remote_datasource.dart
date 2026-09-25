import 'package:app_movil/features/historiales_clinicos/domain/models/solicitud_historial_model.dart';
import 'package:dio/dio.dart';

class HistorialesRemoteDataSource {
  const HistorialesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<LoteSolicitudModel> crearLote(List<String> internacionIds) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/historiales/solicitudes',
      data: {'internacionIds': internacionIds},
    );
    return LoteSolicitudModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<LoteSolicitudModel>> obtenerLotes({
    String? startDate,
    String? endDate,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/historiales/solicitudes',
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
    final data = response.data as List;
    return data
        .map((e) => LoteSolicitudModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SolicitudHistorialModel> actualizarEstadoArchivo(
    String id,
    String estado, {
    String? notasArchivo,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/historiales/solicitudes/$id/estado',
      data: {
        'estado': estado,
        if (notasArchivo != null) 'notas_archivo': notasArchivo,
      },
    );
    return SolicitudHistorialModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<void> notificarLote(String loteId) async {
    await _dio.post<dynamic>('/historiales/solicitudes/lote/$loteId/notificar');
  }

  Future<SolicitudHistorialModel> actualizarRecepcion(
      String id, String estado) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/historiales/solicitudes/$id/recepcion',
      data: {'estado': estado},
    );
    return SolicitudHistorialModel.fromJson(
        response.data as Map<String, dynamic>);
  }
}
