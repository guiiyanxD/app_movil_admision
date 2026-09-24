import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';
import 'package:app_movil/features/internaciones/domain/repositories/pacientes_repository.dart';
import 'package:dio/dio.dart';

/// Acceso HTTP para consultar y registrar pacientes en el backend.
class PacientesRemoteDataSource {
  const PacientesRemoteDataSource(this._dio);

  final Dio _dio;

  /// Busca pacientes por texto (matrícula) y retorna coincidencia exacta si existe.
  Future<Paciente?> buscarPorMatricula(String matricula) async {
    final respuesta = await _dio.get<Object?>(
      '/pacientes/buscar',
      queryParameters: {'q': matricula.trim()},
    );

    final data = respuesta.data;
    if (data is! List) return null;

    final clean = matricula.trim().toUpperCase();
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final mat = (item['matricula'] as String?)?.toUpperCase();
        if (mat == clean) {
          return Paciente.fromJson(item);
        }
      }
    }

    // Si la lista tiene elementos pero ninguno con match exacto de mayúsculas
    if (data.isNotEmpty && data.first is Map<String, dynamic>) {
      final primer = data.first as Map<String, dynamic>;
      final mat = (primer['matricula'] as String?)?.toUpperCase();
      if (mat != null && mat.contains(clean)) {
        return Paciente.fromJson(primer);
      }
    }

    return null;
  }

  /// Registra un nuevo paciente en la base de datos institucional.
  Future<Paciente> crearPaciente(CrearPacienteParams params) async {
    final respuesta = await _dio.post<Object?>(
      '/pacientes',
      data: params.toJson(),
    );

    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        'Se esperaba un mapa de paciente y llegó ${data.runtimeType}',
      );
    }

    return Paciente.fromJson(data);
  }
}
