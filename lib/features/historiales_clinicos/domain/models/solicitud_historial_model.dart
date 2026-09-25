import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';

class SolicitudHistorialModel {
  const SolicitudHistorialModel({
    required this.id,
    required this.internacionId,
    required this.pacienteId,
    required this.estado,
    required this.fechaSolicitud,
    this.loteId,
    this.notasArchivo,
    this.fechaGestionArchivo,
    this.fechaRecepcionAdmision,
    this.paciente,
    this.camaCodigo,
  });

  factory SolicitudHistorialModel.fromJson(Map<String, dynamic> json) {
    // Extraer camaCodigo si viene anidado en internacion -> bedStays
    String? cama;
    final internacion = json['internacion'] as Map<String, dynamic>?;
    if (internacion != null && internacion['bedStays'] != null) {
      final bedStays = internacion['bedStays'] as List<dynamic>;
      if (bedStays.isNotEmpty) {
        final primeraEstancia = bedStays.first as Map<String, dynamic>;
        if (primeraEstancia['cama'] != null) {
          final camaMap = primeraEstancia['cama'] as Map<String, dynamic>;
          cama = camaMap['codigo'] as String?;
        }
      }
    }

    return SolicitudHistorialModel(
      id: json['id'] as String,
      internacionId: json['internacion_id'] as String,
      pacienteId: json['paciente_id'] as String,
      estado: json['estado'] as String,
      fechaSolicitud: DateTime.parse(json['fecha_solicitud'] as String),
      loteId: json['lote_id'] as String?,
      notasArchivo: json['notas_archivo'] as String?,
      fechaGestionArchivo: json['fecha_gestion_archivo'] != null
          ? DateTime.parse(json['fecha_gestion_archivo'] as String)
          : null,
      fechaRecepcionAdmision: json['fecha_recepcion_admision'] != null
          ? DateTime.parse(json['fecha_recepcion_admision'] as String)
          : null,
      paciente: json['paciente'] != null
          ? Paciente.fromJson(json['paciente'] as Map<String, dynamic>)
          : null,
      camaCodigo: cama,
    );
  }

  final String id;
  final String internacionId;
  final String pacienteId;
  final String estado;
  final DateTime fechaSolicitud;
  final String? loteId;
  final String? notasArchivo;
  final DateTime? fechaGestionArchivo;
  final DateTime? fechaRecepcionAdmision;

  // Relaciones cargadas opcionalmente
  final Paciente? paciente;
  final String? camaCodigo;

  SolicitudHistorialModel copyWith({
    String? estado,
    String? notasArchivo,
  }) {
    return SolicitudHistorialModel(
      id: id,
      internacionId: internacionId,
      pacienteId: pacienteId,
      estado: estado ?? this.estado,
      fechaSolicitud: fechaSolicitud,
      loteId: loteId,
      notasArchivo: notasArchivo ?? this.notasArchivo,
      fechaGestionArchivo: fechaGestionArchivo,
      fechaRecepcionAdmision: fechaRecepcionAdmision,
      paciente: paciente,
      camaCodigo: camaCodigo,
    );
  }
}

class LoteSolicitudModel {
  const LoteSolicitudModel({
    required this.id,
    required this.fechaCreacion,
    required this.estado,
    required this.solicitudes,
    this.creadoPorNombre,
  });

  factory LoteSolicitudModel.fromJson(Map<String, dynamic> json) {
    return LoteSolicitudModel(
      id: json['id'] as String,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      estado: json['estado'] as String,
      solicitudes: (json['solicitudes'] as List<dynamic>?)
              ?.map((e) =>
                  SolicitudHistorialModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      creadoPorNombre: json['creadoPor'] != null
          ? (json['creadoPor'] as Map<String, dynamic>)['nombre_completo']
              as String?
          : null,
    );
  }

  final String id;
  final DateTime fechaCreacion;
  final String estado;
  final List<SolicitudHistorialModel> solicitudes;
  final String? creadoPorNombre;
}
