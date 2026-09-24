import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:dio/dio.dart';

/// Acceso HTTP para registrar ingresos hospitalarios.
class InternacionesRemoteDataSource {
  const InternacionesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ResultadoIngresoHospitalario> registrarIngreso(
    RegistrarIngresoParams params,
  ) async {
    final respuesta = await _dio.post<Object?>(
      '/internaciones/ingreso',
      data: params.toJson(),
    );

    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        'Se esperaba un mapa como respuesta de ingreso y llegó ${data.runtimeType}',
      );
    }

    return ResultadoIngresoHospitalario.fromJson(data);
  }

  Future<Map<String, dynamic>> obtenerDetalle(String id) async {
    final respuesta = await _dio.get<Object?>('/internaciones/$id');

    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        'Se esperaba un mapa como respuesta y llegó ${data.runtimeType}',
      );
    }

    return data;
  }

  Future<void> trasladarInterno(MoverCamaParams params) async {
    await _dio.post<Object?>(
      '/internaciones/traslado-interno',
      data: params.toJson(),
    );
  }

  Future<void> trasladarServicio(MoverCamaParams params) async {
    await _dio.post<Object?>(
      '/internaciones/traslado-servicio',
      data: params.toJson(),
    );
  }

  Future<void> registrarEgreso(RegistrarEgresoParams params) async {
    await _dio.post<Object?>(
      '/internaciones/egreso',
      data: params.toJson(),
    );
  }
}
