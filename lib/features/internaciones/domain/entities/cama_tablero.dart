import 'package:flutter/foundation.dart';

/// Estados visuales posibles de una cama en el tablero hospitalario.
///
/// Sigue la misma jerarquía y diferenciación de estados de la aplicación web:
/// 1. Fuera de servicio
/// 2. Aislamiento
/// 3. Crítico (+30 días internado)
/// 4. Cama prestada (otra especialidad)
/// 5. Ocupada
/// 6. Disponible
enum EstadoCamaVisual {
  disponible('Disponible'),
  ocupada('Ocupada'),
  prestada('Cama prestada'),
  critica('Crítico (+30 días)'),
  aislamiento('Aislamiento'),
  fueraDeServicio('Fuera de servicio');

  const EstadoCamaVisual(this.etiqueta);

  final String etiqueta;
}

/// Entidad de dominio que representa una cama y su estado de ocupación actual.
@immutable
class CamaTablero {
  const CamaTablero({
    required this.id,
    required this.codigo,
    required this.estadoBase,
    required this.servicioId,
    required this.servicioNombre,
    required this.especialidadNativaId,
    required this.especialidadNombre,
    this.motivoEstado,
    this.bedStayId,
    this.bedStayEspecialidadId,
    this.internacionId,
    this.pacienteNombre,
    this.matricula,
    this.fechaIngreso,
  });

  final String id;
  final String codigo;
  final String estadoBase; // 'disponible' | 'aislamiento' | 'fuera_servicio'
  final String? motivoEstado;
  final String servicioId;
  final String servicioNombre;
  final String especialidadNativaId;
  final String especialidadNombre;
  final String? bedStayId;
  final String? bedStayEspecialidadId;
  final String? internacionId;
  final String? pacienteNombre;
  final String? matricula;
  final DateTime? fechaIngreso;

  bool get esOcupada => bedStayId != null;

  int get diasInternado {
    if (fechaIngreso == null || !esOcupada) return 0;
    final ahora = DateTime.now();
    final fecha = fechaIngreso!;
    final diff = DateTime(ahora.year, ahora.month, ahora.day)
        .difference(DateTime(fecha.year, fecha.month, fecha.day))
        .inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get esCritica => esOcupada && diasInternado > 30;

  bool get esPrestada =>
      esOcupada &&
      bedStayEspecialidadId != null &&
      bedStayEspecialidadId != especialidadNativaId;

  EstadoCamaVisual get estadoVisual {
    if (estadoBase == 'fuera_servicio') {
      return EstadoCamaVisual.fueraDeServicio;
    }
    if (estadoBase == 'aislamiento') {
      return EstadoCamaVisual.aislamiento;
    }
    if (esCritica) {
      return EstadoCamaVisual.critica;
    }
    if (esPrestada) {
      return EstadoCamaVisual.prestada;
    }
    if (esOcupada) {
      return EstadoCamaVisual.ocupada;
    }
    return EstadoCamaVisual.disponible;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CamaTablero &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          codigo == other.codigo &&
          estadoBase == other.estadoBase &&
          motivoEstado == other.motivoEstado &&
          servicioId == other.servicioId &&
          servicioNombre == other.servicioNombre &&
          especialidadNativaId == other.especialidadNativaId &&
          especialidadNombre == other.especialidadNombre &&
          bedStayId == other.bedStayId &&
          bedStayEspecialidadId == other.bedStayEspecialidadId &&
          internacionId == other.internacionId &&
          pacienteNombre == other.pacienteNombre &&
          matricula == other.matricula &&
          fechaIngreso == other.fechaIngreso;

  @override
  int get hashCode => Object.hash(
        id,
        codigo,
        estadoBase,
        motivoEstado,
        servicioId,
        servicioNombre,
        especialidadNativaId,
        especialidadNombre,
        bedStayId,
        bedStayEspecialidadId,
        internacionId,
        pacienteNombre,
        matricula,
        fechaIngreso,
      );
}
