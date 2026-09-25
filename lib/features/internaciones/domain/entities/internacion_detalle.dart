import 'package:flutter/foundation.dart';

@immutable
class PacienteDetalle {
  const PacienteDetalle({
    required this.id,
    required this.nombres,
    this.apellidoPaterno,
    this.apellidoMaterno,
    this.sexo,
    this.fechaNacimiento,
    this.matricula,
    this.documentoNumero,
    this.documentoTipo,
  });

  factory PacienteDetalle.fromJson(Map<String, dynamic> json) {
    return PacienteDetalle(
      id: json['id'] as String,
      nombres: json['nombres'] as String,
      apellidoPaterno: json['apellido_paterno'] as String?,
      apellidoMaterno: json['apellido_materno'] as String?,
      sexo: json['sexo'] as String?,
      fechaNacimiento: json['fecha_nacimiento'] != null
          ? DateTime.tryParse(json['fecha_nacimiento'] as String)
          : null,
      matricula: json['matricula'] as String?,
      documentoNumero: json['documento_numero'] as String?,
      documentoTipo: json['documento_tipo'] as String?,
    );
  }

  final String id;
  final String nombres;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String? sexo; // 'masculino', 'femenino'
  final DateTime? fechaNacimiento;
  final String? matricula;
  final String? documentoNumero;
  final String? documentoTipo;

  String get nombreCompleto {
    final partes = [nombres];
    if (apellidoPaterno != null && apellidoPaterno!.isNotEmpty) {
      partes.add(apellidoPaterno!);
    }
    if (apellidoMaterno != null && apellidoMaterno!.isNotEmpty) {
      partes.add(apellidoMaterno!);
    }
    return partes.join(' ');
  }

  int? get edad {
    if (fechaNacimiento == null) return null;
    final hoy = DateTime.now();
    var age = hoy.year - fechaNacimiento!.year;
    if (hoy.month < fechaNacimiento!.month ||
        (hoy.month == fechaNacimiento!.month &&
            hoy.day < fechaNacimiento!.day)) {
      age--;
    }
    return age;
  }
}

@immutable
class BedStayDetalle {
  const BedStayDetalle({
    required this.id,
    required this.creadoEn,
    required this.camaCodigo,
    required this.servicioNombre,
    required this.especialidadNombre,
    this.motivoCambio,
  });

  factory BedStayDetalle.fromJson(Map<String, dynamic> json) {
    final cama = json['cama'] as Map<String, dynamic>? ?? {};
    final servicio = cama['servicio'] as Map<String, dynamic>? ?? {};
    final especialidad = json['especialidad'] as Map<String, dynamic>? ?? {};

    return BedStayDetalle(
      id: json['id'] as String,
      creadoEn: DateTime.parse(json['creado_en'] as String),
      camaCodigo: cama['codigo'] as String? ?? 'Desconocida',
      servicioNombre: servicio['nombre'] as String? ?? 'Desconocido',
      especialidadNombre: especialidad['nombre'] as String? ?? 'Desconocida',
      motivoCambio: json['motivo_cambio'] as String?,
    );
  }

  final String id;
  final DateTime creadoEn;
  final String camaCodigo;
  final String servicioNombre;
  final String especialidadNombre;
  final String? motivoCambio;
}

@immutable
class InternacionDetalle {
  const InternacionDetalle({
    required this.id,
    required this.fechaIngreso,
    required this.viaIngreso,
    required this.estadoHc,
    required this.medicoTratante,
    required this.diagnosticoInicial,
    required this.paciente,
    required this.bedStays,
    this.numeroHc2,
    this.responsablePago,
    this.familiarReferenciaNombre,
    this.familiarReferenciaTelefono,
    this.familiarReferenciaDireccion,
  });

  factory InternacionDetalle.fromJson(Map<String, dynamic> json) {
    return InternacionDetalle(
      id: json['id'] as String,
      numeroHc2: json['numero_hc2'] as int?,
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      viaIngreso: json['via_ingreso'] as String? ?? 'Desconocida',
      estadoHc: json['estado_hc'] as String? ?? 'Desconocido',
      medicoTratante: json['medico_tratante'] as String? ?? 'No especificado',
      diagnosticoInicial:
          json['diagnostico_inicial'] as String? ?? 'No especificado',
      responsablePago: json['responsable_pago'] as String?,
      familiarReferenciaNombre: json['familiar_referencia_nombre'] as String?,
      familiarReferenciaTelefono:
          json['familiar_referencia_telefono'] as String?,
      familiarReferenciaDireccion:
          json['familiar_referencia_direccion'] as String?,
      paciente:
          PacienteDetalle.fromJson(json['paciente'] as Map<String, dynamic>),
      bedStays: (json['bedStays'] as List<dynamic>?)
              ?.map((e) => BedStayDetalle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  final String id;
  final int? numeroHc2;
  final DateTime fechaIngreso;
  final String viaIngreso;
  final String estadoHc;
  final String medicoTratante;
  final String diagnosticoInicial;
  final String? responsablePago;
  final String? familiarReferenciaNombre;
  final String? familiarReferenciaTelefono;
  final String? familiarReferenciaDireccion;

  final PacienteDetalle paciente;
  final List<BedStayDetalle> bedStays;
}
