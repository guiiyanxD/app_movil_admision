import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';

/// Parámetros para registrar un nuevo paciente o titular en el sistema.
class CrearPacienteParams {
  const CrearPacienteParams({
    required this.nombres,
    required this.apellidoPaterno,
    required this.fechaNacimiento,
    required this.sexo,
    this.apellidoMaterno,

    this.tipoPaciente = 'asegurado',
    this.documentoTipo,
    this.documentoNumero,
    this.empresaAseguradora,
    this.regional = 'SANTA CRUZ',
    this.estadoVigencia = 'VIGENTE',
    this.edadAprox,
    this.telefono,
    this.direccion,
  });

  final String nombres;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final DateTime fechaNacimiento;
  final String sexo;

  final String tipoPaciente;
  final String? documentoTipo;
  final String? documentoNumero;
  final String? empresaAseguradora;
  final String regional;
  final String estadoVigencia;
  final int? edadAprox;
  final String? telefono;
  final String? direccion;

  Map<String, dynamic> toJson() => {
        'nombres': nombres,
        'apellidoPaterno': apellidoPaterno,
        if (apellidoMaterno != null && apellidoMaterno!.isNotEmpty)
          'apellidoMaterno': apellidoMaterno,
        'fechaNacimiento': fechaNacimiento.toIso8601String().split('T').first,
        'sexo': sexo,

        'tipoPaciente': tipoPaciente,
        if (documentoTipo != null && documentoTipo!.isNotEmpty)
          'documentoTipo': documentoTipo,
        if (documentoNumero != null && documentoNumero!.isNotEmpty)
          'documentoNumero': documentoNumero,
        if (empresaAseguradora != null && empresaAseguradora!.isNotEmpty)
          'empresaAseguradora': empresaAseguradora,
        'regional': regional,
        'estadoVigencia': estadoVigencia,
        if (edadAprox != null) 'edadAprox': edadAprox,
        if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
        if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
      };
}

/// Contrato del repositorio de pacientes en la capa de internaciones.
abstract class PacientesRepository {
  /// Busca un paciente por su matrícula institucional. Retorna null si no existe.
  Future<Resultado<Paciente?>> buscarPorMatricula(String matricula);

  /// Registra un nuevo paciente en la base de datos institucional.
  Future<Resultado<Paciente>> crearPaciente(CrearPacienteParams params);
}
