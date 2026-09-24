/// Modelo de dominio que representa los datos extraídos de un Formulario HC-2
/// de la Caja Petrolera de Salud para el ingreso hospitalario de un paciente.
class DatosIngresoHC2 {
  const DatosIngresoHC2({
    required this.apellidoPaterno,
    required this.nombres,
    required this.matricula,
    required this.sexo,
    this.apellidoMaterno,
    this.fechaNacimiento,
    this.edadAprox,
    this.tipoPaciente = 'asegurado',
    this.regional = 'SANTA CRUZ',
    this.empresaAseguradora,
    this.carnetIdentidad,
    this.matriculaTitular,
    this.nombreTitular,
    this.apellidoPaternoTitular,
    this.apellidoMaternoTitular,
    this.nombresTitular,
    this.fechaNacimientoTitular,
    this.sexoTitular,
    this.empresaTitular,
    this.fechaIngreso,
    this.servicio,
    this.camaCodigo,
    this.servicioQuienAtendera,
    this.hospitalizadoPor = 'enfermedad',
    this.medicoTratante,
    this.diagnosticoInicial,
    this.tipoIngreso = 'programado',
    this.responsablePago = 'CPS',
    this.contactoEmergenciaNombre,
    this.contactoEmergenciaTelefono,
    this.contactoEmergenciaDireccion,
  });

  // ── Paciente ──────────────────────────────────────────────────────────────
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String nombres;
  final String matricula;
  final DateTime? fechaNacimiento;
  final String sexo; // 'masculino' | 'femenino'
  final int? edadAprox;
  final String tipoPaciente; // 'asegurado' | 'beneficiario' | 'particular'
  final String regional;
  final String? empresaAseguradora;
  final String? carnetIdentidad;

  // ── Titular (aplica si tipoPaciente == 'beneficiario') ─────────────────────
  final String? matriculaTitular;
  final String? nombreTitular;
  final String? apellidoPaternoTitular;
  final String? apellidoMaternoTitular;
  final String? nombresTitular;
  final DateTime? fechaNacimientoTitular;
  final String? sexoTitular;
  final String? empresaTitular;

  // ── Internación ───────────────────────────────────────────────────────────
  final DateTime? fechaIngreso;
  final String? servicio;
  final String? camaCodigo;
  final String? servicioQuienAtendera;
  final String hospitalizadoPor;
  final String? medicoTratante;
  final String? diagnosticoInicial;
  final String tipoIngreso;
  final String responsablePago;

  // ── Contacto Emergencia / Familiar ────────────────────────────────────────
  final String? contactoEmergenciaNombre;
  final String? contactoEmergenciaTelefono;
  final String? contactoEmergenciaDireccion;

  bool get esBeneficiario =>
      tipoPaciente.toLowerCase().contains('beneficiario');

  String get nombreCompletoPaciente {
    final buffer = StringBuffer(apellidoPaterno);
    if (apellidoMaterno != null && apellidoMaterno!.isNotEmpty) {
      buffer.write(' $apellidoMaterno');
    }
    buffer.write(' $nombres');
    return buffer.toString().trim();
  }

  String get nombreCompletoTitular {
    if (nombreTitular != null && nombreTitular!.isNotEmpty) {
      return nombreTitular!;
    }
    final buffer = StringBuffer();
    if (apellidoPaternoTitular != null) buffer.write(apellidoPaternoTitular);
    if (apellidoMaternoTitular != null && apellidoMaternoTitular!.isNotEmpty) {
      buffer.write(' $apellidoMaternoTitular');
    }
    if (nombresTitular != null && nombresTitular!.isNotEmpty) {
      buffer.write(' $nombresTitular');
    }
    return buffer.toString().trim();
  }

  DatosIngresoHC2 copyWith({
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? nombres,
    String? matricula,
    DateTime? fechaNacimiento,
    String? sexo,
    int? edadAprox,
    String? tipoPaciente,
    String? regional,
    String? empresaAseguradora,
    String? carnetIdentidad,
    String? matriculaTitular,
    String? nombreTitular,
    String? apellidoPaternoTitular,
    String? apellidoMaternoTitular,
    String? nombresTitular,
    DateTime? fechaNacimientoTitular,
    String? sexoTitular,
    String? empresaTitular,
    DateTime? fechaIngreso,
    String? servicio,
    String? camaCodigo,
    String? servicioQuienAtendera,
    String? hospitalizadoPor,
    String? medicoTratante,
    String? diagnosticoInicial,
    String? tipoIngreso,
    String? responsablePago,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
    String? contactoEmergenciaDireccion,
  }) {
    return DatosIngresoHC2(
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      nombres: nombres ?? this.nombres,
      matricula: matricula ?? this.matricula,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      sexo: sexo ?? this.sexo,
      edadAprox: edadAprox ?? this.edadAprox,
      tipoPaciente: tipoPaciente ?? this.tipoPaciente,
      regional: regional ?? this.regional,
      empresaAseguradora: empresaAseguradora ?? this.empresaAseguradora,
      carnetIdentidad: carnetIdentidad ?? this.carnetIdentidad,
      matriculaTitular: matriculaTitular ?? this.matriculaTitular,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      apellidoPaternoTitular:
          apellidoPaternoTitular ?? this.apellidoPaternoTitular,
      apellidoMaternoTitular:
          apellidoMaternoTitular ?? this.apellidoMaternoTitular,
      nombresTitular: nombresTitular ?? this.nombresTitular,
      fechaNacimientoTitular:
          fechaNacimientoTitular ?? this.fechaNacimientoTitular,
      sexoTitular: sexoTitular ?? this.sexoTitular,
      empresaTitular: empresaTitular ?? this.empresaTitular,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      servicio: servicio ?? this.servicio,
      camaCodigo: camaCodigo ?? this.camaCodigo,
      servicioQuienAtendera:
          servicioQuienAtendera ?? this.servicioQuienAtendera,
      hospitalizadoPor: hospitalizadoPor ?? this.hospitalizadoPor,
      medicoTratante: medicoTratante ?? this.medicoTratante,
      diagnosticoInicial: diagnosticoInicial ?? this.diagnosticoInicial,
      tipoIngreso: tipoIngreso ?? this.tipoIngreso,
      responsablePago: responsablePago ?? this.responsablePago,
      contactoEmergenciaNombre:
          contactoEmergenciaNombre ?? this.contactoEmergenciaNombre,
      contactoEmergenciaTelefono:
          contactoEmergenciaTelefono ?? this.contactoEmergenciaTelefono,
      contactoEmergenciaDireccion:
          contactoEmergenciaDireccion ?? this.contactoEmergenciaDireccion,
    );
  }
}
