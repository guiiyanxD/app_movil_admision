import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';

/// Modelo de datos para serializar/deserializar una fila del tablero de camas.
class CamaTableroModel extends CamaTablero {
  const CamaTableroModel({
    required super.id,
    required super.codigo,
    required super.estadoBase,
    required super.servicioId,
    required super.servicioNombre,
    required super.especialidadNativaId,
    required super.especialidadNombre,
    super.motivoEstado,
    super.bedStayId,
    super.bedStayEspecialidadId,
    super.internacionId,
    super.pacienteNombre,
    super.matricula,
    super.fechaIngreso,
  });

  factory CamaTableroModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsearFecha(dynamic valor) {
      if (valor == null) return null;
      if (valor is DateTime) return valor;
      if (valor is String) return DateTime.tryParse(valor);
      return null;
    }

    return CamaTableroModel(
      id: json['id'] as String? ?? '',
      codigo: json['codigo'] as String? ?? '',
      estadoBase: json['estado'] as String? ?? 'disponible',
      motivoEstado: json['motivo_estado'] as String?,
      servicioId: json['servicio_id'] as String? ?? '',
      servicioNombre: json['servicio_nombre'] as String? ?? '',
      especialidadNativaId: json['especialidad_nativa_id'] as String? ?? '',
      especialidadNombre: json['especialidad_nombre'] as String? ?? '',
      bedStayId: json['bed_stay_id'] as String?,
      bedStayEspecialidadId: json['bed_stay_especialidad_id'] as String?,
      internacionId: json['internacion_id'] as String?,
      pacienteNombre: json['paciente_nombre'] as String?,
      matricula: json['matricula'] as String?,
      fechaIngreso: parsearFecha(json['fecha_ingreso']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'estado': estadoBase,
        'motivo_estado': motivoEstado,
        'servicio_id': servicioId,
        'servicio_nombre': servicioNombre,
        'especialidad_nativa_id': especialidadNativaId,
        'especialidad_nombre': especialidadNombre,
        'bed_stay_id': bedStayId,
        'bed_stay_especialidad_id': bedStayEspecialidadId,
        'internacion_id': internacionId,
        'paciente_nombre': pacienteNombre,
        'matricula': matricula,
        'fecha_ingreso': fechaIngreso?.toIso8601String(),
      };
}
