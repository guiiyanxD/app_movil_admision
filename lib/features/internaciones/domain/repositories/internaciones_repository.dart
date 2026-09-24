import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/domain/entities/internacion_detalle.dart';

/// Parámetros para registrar el ingreso hospitalario de un paciente en una cama.
class RegistrarIngresoParams {
  const RegistrarIngresoParams({
    required this.pacienteId,
    required this.camaId,
    required this.especialidadId,
    required this.medicoTratante,
    required this.diagnosticoInicial,
    this.viaIngreso = 'programado',
    this.hospitalizadoPor = 'enfermedad',
    this.responsablePago = 'CPS',
    this.familiarReferenciaNombre,
    this.familiarReferenciaTelefono,
    this.familiarReferenciaDireccion,
    this.solicitarHistoriaAmarilla = false,
  });

  final String pacienteId;
  final String camaId;
  final String especialidadId;
  final String viaIngreso;
  final String hospitalizadoPor;
  final String responsablePago;
  final String medicoTratante;
  final String diagnosticoInicial;
  final String? familiarReferenciaNombre;
  final String? familiarReferenciaTelefono;
  final String? familiarReferenciaDireccion;

  /// Flag preparatorio para la futura integración con el módulo de Archivo Central.
  final bool solicitarHistoriaAmarilla;

  Map<String, dynamic> toJson() => {
        'pacienteId': pacienteId,
        'camaId': camaId,
        'especialidadId': especialidadId,
        'viaIngreso': viaIngreso,
        'hospitalizadoPor': hospitalizadoPor,
        'responsablePago': responsablePago,
        'medicoTratante': medicoTratante,
        'diagnosticoInicial': diagnosticoInicial,
        if (familiarReferenciaNombre != null &&
            familiarReferenciaNombre!.isNotEmpty)
          'familiarReferenciaNombre': familiarReferenciaNombre,
        if (familiarReferenciaTelefono != null &&
            familiarReferenciaTelefono!.isNotEmpty)
          'familiarReferenciaTelefono': familiarReferenciaTelefono,
        if (familiarReferenciaDireccion != null &&
            familiarReferenciaDireccion!.isNotEmpty)
          'familiarReferenciaDireccion': familiarReferenciaDireccion,
        'solicitarHistoriaAmarilla': solicitarHistoriaAmarilla,
      };
}

/// Resultado de la operación de ingreso hospitalario.
class ResultadoIngresoHospitalario {
  const ResultadoIngresoHospitalario({
    required this.internacionId,
    required this.pacienteId,
    required this.bedStayId,
    this.numeroHc2,
  });

  factory ResultadoIngresoHospitalario.fromJson(Map<String, dynamic> json) {
    final internacion = json['internacion'] as Map<String, dynamic>? ?? json;
    final paciente = json['paciente'] as Map<String, dynamic>?;

    return ResultadoIngresoHospitalario(
      internacionId: (internacion['id'] ?? '') as String,
      pacienteId:
          (paciente?['id'] ?? internacion['paciente_id'] ?? '') as String,
      bedStayId: (json['bedStayId'] ?? '') as String,
      numeroHc2: internacion['numero_hc2'] as int?,
    );
  }

  final String internacionId;
  final String pacienteId;
  final String bedStayId;
  final int? numeroHc2;
}

class MoverCamaParams {
  const MoverCamaParams({
    required this.internacionId,
    required this.camaId,
    required this.especialidadId,
  });

  final String internacionId;
  final String camaId;
  final String especialidadId;

  Map<String, dynamic> toJson() => {
        'internacionId': internacionId,
        'camaId': camaId,
        'especialidadId': especialidadId,
      };
}

class RegistrarEgresoParams {
  const RegistrarEgresoParams({
    required this.internacionId,
    required this.motivoEgreso,
  });

  final String internacionId;
  final String motivoEgreso;

  Map<String, dynamic> toJson() => {
        'internacionId': internacionId,
        'motivoEgreso': motivoEgreso,
      };
}

/// Contrato del repositorio de internaciones para operaciones de ingreso hospitalario.
// ignore: one_member_abstracts
abstract class InternacionesRepository {
  /// Registra el ingreso hospitalario de un paciente, vinculándolo a la cama indicada.
  Future<Resultado<ResultadoIngresoHospitalario>> registrarIngreso(
    RegistrarIngresoParams params,
  );

  /// Obtiene los detalles completos de una internación (incluyendo sus traslados de camas).
  Future<Resultado<InternacionDetalle>> obtenerDetalle(String internacionId);

  /// Traslada a un paciente de cama dentro del mismo servicio
  Future<Resultado<void>> trasladarInterno(MoverCamaParams params);

  /// Traslada a un paciente de cama hacia un servicio diferente
  Future<Resultado<void>> trasladarServicio(MoverCamaParams params);

  /// Registra el egreso (alta médica, fallecimiento, etc.) de una internación activa
  Future<Resultado<void>> registrarEgreso(RegistrarEgresoParams params);
}
