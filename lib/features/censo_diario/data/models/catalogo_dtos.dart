
library;
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';

/// DTOs de catálogo.
///
/// **Ojo con la convención de nombres**: estos endpoints devuelven filas crudas
/// de Postgres en `snake_case`, mientras que `/carga-manual/estado` e
/// `/historico` devuelven `camelCase`. No existe una convención global en el
/// API — no asumirla es lo que evita un bug silencioso de campos en `null`.

/// `GET /servicios?soloActivos=true` — fila cruda, snake_case.
class ServicioDto {
  const ServicioDto({
    required this.id,
    required this.nombre,
    required this.activo,
    this.codigo,
  });

  factory ServicioDto.fromJson(Map<String, dynamic> json) => ServicioDto(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        activo: json['activo'] as bool? ?? true,
        codigo: json['codigo'] as String?,
      );

  final String id;
  final String nombre;
  final String? codigo;
  final bool activo;

  Servicio toDomain({String? nombreVaciado}) => Servicio(
        id: id,
        nombre: nombre,
        codigo: codigo,
        activo: activo,
        nombreVaciado: nombreVaciado,
      );
}

/// `GET /censo-diario/mapeo/servicios` — snake_case con relación anidada.
class MapeoServicioDto {
  const MapeoServicioDto({
    required this.servicioId,
    required this.nombreVaciado,
  });

  factory MapeoServicioDto.fromJson(Map<String, dynamic> json) =>
      MapeoServicioDto(
        servicioId: json['servicio_id'] as String,
        nombreVaciado: json['nombre_vaciado'] as String,
      );

  final String servicioId;
  final String nombreVaciado;

  MapeoVaciado toDomain() =>
      MapeoVaciado(entidadId: servicioId, nombreVaciado: nombreVaciado);
}

/// `GET /censo-diario/mapeo/especialidades` — mismo patrón que el de servicios.
class MapeoEspecialidadDto {
  const MapeoEspecialidadDto({
    required this.especialidadId,
    required this.nombreVaciado,
    this.especialidadNombre,
  });

  factory MapeoEspecialidadDto.fromJson(Map<String, dynamic> json) {
    final anidada = json['especialidad'];
    return MapeoEspecialidadDto(
      especialidadId: json['especialidad_id'] as String,
      nombreVaciado: json['nombre_vaciado'] as String,
      especialidadNombre:
          anidada is Map ? anidada['nombre'] as String? : null,
    );
  }

  final String especialidadId;
  final String nombreVaciado;

  /// Nombre local de la especialidad, para mostrar en el selector. Se prefiere
  /// sobre `nombreVaciado`, que es el nombre del otro sistema.
  final String? especialidadNombre;

  MapeoVaciado toDomain() => MapeoVaciado(
        entidadId: especialidadId,
        nombreVaciado: especialidadNombre ?? nombreVaciado,
      );
}

/// `GET /censo-diario/cierre/:fecha` — fila cruda de `cierres_censo`, o `null`.
class CierreCensoDto {
  const CierreCensoDto({required this.fechaCenso, required this.origen});

  factory CierreCensoDto.fromJson(Map<String, dynamic> json) => CierreCensoDto(
        fechaCenso: DateTime.parse(json['fecha_censo'] as String),
        origen: json['origen'] as String?,
      );

  final DateTime fechaCenso;
  final String? origen;

  CierreCenso toDomain() => CierreCenso(
        fecha: fechaCenso,
        origen: OrigenCierre.desdeApi(origen),
      );
}

/// `GET /censo-diario/historico?fecha=` — **camelCase**, ya presentado.
class HistoricoCensoDto {
  const HistoricoCensoDto({
    required this.servicio,
    required this.total,
    required this.libre,
    required this.dotacion,
  });

  factory HistoricoCensoDto.fromJson(Map<String, dynamic> json) =>
      HistoricoCensoDto(
        // Este `servicio` es el nombre de VACIADO, no el nombre local: por eso
        // hace falta el mapeo para filtrar esta lista.
        servicio: json['servicio'] as String,
        total: (json['total'] as num?)?.toInt() ?? 0,
        libre: (json['libre'] as num?)?.toInt() ?? 0,
        dotacion: (json['dotacion'] as num?)?.toInt() ?? 0,
      );

  final String servicio;
  final int total;
  final int libre;
  final int dotacion;
}
