/// Entidad de dominio que representa a un paciente en el sistema hospitalario.
class Paciente {
  const Paciente({
    required this.id,
    required this.nombres,
    required this.apellidoPaterno,
    required this.matricula,
    required this.fechaNacimiento,
    required this.sexo,
    this.apellidoMaterno,

    this.tipoPaciente = 'asegurado',
    this.documentoTipo,
    this.documentoNumero,
    this.empresaAseguradora,
    this.telefono,
    this.direccion,
    this.estadoVigencia = 'VIGENTE',
    this.regional = 'SANTA CRUZ',
    this.edadAprox,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      id: json['id'] as String,
      nombres: json['nombres'] as String? ?? '',
      apellidoPaterno:
          (json['apellido_paterno'] ?? json['apellidoPaterno'] ?? '') as String,
      apellidoMaterno:
          (json['apellido_materno'] ?? json['apellidoMaterno']) as String?,
      matricula: json['matricula'] as String? ?? '',
      fechaNacimiento: DateTime.parse(
        (json['fecha_nacimiento'] ?? json['fechaNacimiento']) as String,
      ),
      sexo: (json['sexo'] as String? ?? 'masculino').toLowerCase(),

      tipoPaciente: (json['tipo_paciente'] ??
          json['tipoPaciente'] ??
          'asegurado') as String,
      documentoTipo:
          (json['documento_tipo'] ?? json['documentoTipo']) as String?,
      documentoNumero:
          (json['documento_numero'] ?? json['documentoNumero']) as String?,
      empresaAseguradora: (json['empresa_aseguradora'] ??
          json['empresaAseguradora']) as String?,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      estadoVigencia: (json['estado_vigencia'] ??
          json['estadoVigencia'] ??
          'VIGENTE') as String?,
      regional: json['regional'] as String?,
      edadAprox: (json['edad_aprox'] ?? json['edadAprox']) as int?,
    );
  }

  final String id;
  final String nombres;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String matricula;
  final DateTime fechaNacimiento;
  final String sexo;

  final String tipoPaciente;
  final String? documentoTipo;
  final String? documentoNumero;
  final String? empresaAseguradora;
  final String? telefono;
  final String? direccion;
  final String? estadoVigencia;
  final String? regional;
  final int? edadAprox;

  String get nombreCompleto {
    final buffer = StringBuffer(apellidoPaterno);
    if (apellidoMaterno != null && apellidoMaterno!.isNotEmpty) {
      buffer.write(' $apellidoMaterno');
    }
    buffer.write(' $nombres');
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombres': nombres,
        'apellidoPaterno': apellidoPaterno,
        'apellidoMaterno': apellidoMaterno,
        'matricula': matricula,
        'fechaNacimiento': fechaNacimiento.toIso8601String().split('T').first,
        'sexo': sexo,

        'tipoPaciente': tipoPaciente,
        'documentoTipo': documentoTipo,
        'documentoNumero': documentoNumero,
        'empresaAseguradora': empresaAseguradora,
        'telefono': telefono,
        'direccion': direccion,
        'estadoVigencia': estadoVigencia,
        'regional': regional,
        'edadAprox': edadAprox,
      };
}
