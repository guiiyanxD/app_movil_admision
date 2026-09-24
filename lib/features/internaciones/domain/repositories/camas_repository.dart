import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';

class CambiarEstadoCamaParams {
  const CambiarEstadoCamaParams({
    required this.camaId,
    required this.estado,
    this.motivo,
    this.fechaInicio,
    this.fechaFin,
  });

  final String camaId;
  final String estado;
  final String? motivo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  Map<String, dynamic> toJson() => {
        'estado': estado,
        if (motivo != null && motivo!.isNotEmpty) 'motivo': motivo,
        if (fechaInicio != null) 'fechaInicio': fechaInicio!.toIso8601String(),
        if (fechaFin != null) 'fechaFin': fechaFin!.toIso8601String(),
      };
}

/// Contrato del repositorio de camas para consulta e internaciones.
abstract interface class CamasRepository {
  /// Obtiene el estado actual de todas las camas del hospital en el tablero.
  ///
  /// Opcionalmente filtra por [servicioId] en el servidor.
  Future<Resultado<List<CamaTablero>>> obtenerTablero({String? servicioId});

  /// Cambia el estado base de una cama (ej: aislamiento, fuera_servicio, disponible)
  Future<Resultado<void>> cambiarEstado(CambiarEstadoCamaParams params);
}
