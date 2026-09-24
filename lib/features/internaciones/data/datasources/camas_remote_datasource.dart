import 'package:app_movil/features/internaciones/data/models/cama_tablero_model.dart';
import 'package:app_movil/features/internaciones/domain/repositories/camas_repository.dart';
import 'package:dio/dio.dart';

/// Acceso HTTP al módulo de camas e internaciones.
///
/// Deja pasar las excepciones de red para que el repositorio las capture y
/// mapee a tipos `Failure` del dominio.
class CamasRemoteDataSource {
  const CamasRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CamaTableroModel>> obtenerTablero({String? servicioId}) async {
    final respuesta = await _dio.get<Object?>(
      '/camas/tablero',
      queryParameters: {
        if (servicioId != null && servicioId.isNotEmpty)
          'servicioId': servicioId,
      },
    );

    final data = respuesta.data;
    if (data is! List) {
      throw FormatException(
        'Se esperaba una lista de camas en el tablero y llegó ${data.runtimeType}',
      );
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(CamaTableroModel.fromJson)
        .toList();
  }

  Future<void> cambiarEstado(CambiarEstadoCamaParams params) async {
    await _dio.patch<Object?>(
      '/camas/${params.camaId}/estado',
      data: params.toJson(),
    );
  }
}
