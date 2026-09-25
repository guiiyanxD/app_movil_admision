import 'package:meta/meta.dart';

/// Servicio hospitalario del catálogo.
///
/// La app **nunca** fija la cantidad de servicios: renderiza los que devuelva
/// `GET /servicios?soloActivos=true`. Un servicio que se abre físicamente se
/// crea en el sistema web y aparece acá sin necesidad de release
/// (ADR-0005, D-7).
@immutable
class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    required this.activo,
    this.codigo,
    this.nombreVaciado,
  });

  final String id;
  final String nombre;
  final String? codigo;
  final bool activo;

  /// Nombre equivalente en vaciado-admisión. `null` cuando el equipo de datos
  /// todavía no completó el mapeo, que es un paso manual con revisión humana.
  ///
  /// Sin este valor el servicio se puede cargar, pero **el día no se podrá
  /// confirmar**: el backend rechaza con 400. Por eso se detecta al cargar
  /// referencias y se avisa desde el inicio (validación V-06), no al confirmar.
  final String? nombreVaciado;

  bool get tieneMapeo => nombreVaciado != null && nombreVaciado!.isNotEmpty;

  Servicio conMapeo(String? nombre) => Servicio(
        id: id,
        nombre: this.nombre,
        activo: activo,
        codigo: codigo,
        nombreVaciado: nombre,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Servicio &&
          other.id == id &&
          other.nombre == nombre &&
          other.codigo == codigo &&
          other.activo == activo &&
          other.nombreVaciado == nombreVaciado;

  @override
  int get hashCode => Object.hash(id, nombre, codigo, activo, nombreVaciado);

  @override
  String toString() => 'Servicio($id, $nombre, mapeo: $nombreVaciado)';
}

/// Traducción `entidadId → nombre en vaciado-admisión`, para servicios y para
/// especialidades.
@immutable
class MapeoVaciado {
  const MapeoVaciado({required this.entidadId, required this.nombreVaciado});

  final String entidadId;
  final String nombreVaciado;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapeoVaciado &&
          other.entidadId == entidadId &&
          other.nombreVaciado == nombreVaciado;

  @override
  int get hashCode => Object.hash(entidadId, nombreVaciado);
}

/// Cierre de una fecha. Se consulta **antes** de dejar cargar, no al confirmar.
class CierreCenso {
  const CierreCenso({required this.fecha, required this.origen});

  final DateTime fecha;
  final OrigenCierre origen;

  /// Una fecha cerrada por el cálculo automático real no se puede pisar con
  /// carga manual: el backend responde 403. Detectarlo en el calendario evita
  /// que el operador digite todos los servicios para nada (validación V-09).
  bool get bloqueaCargaManual => origen == OrigenCierre.automatico;
}

enum OrigenCierre {
  automatico('automatico'),
  manual('manual');

  const OrigenCierre(this.valorApi);

  final String valorApi;

  static OrigenCierre desdeApi(String? valor) => values.firstWhere(
        (o) => o.valorApi == valor,
        // Ante un valor desconocido se asume el caso restrictivo: es preferible
        // bloquear una fecha de más que corromper un cierre automático real.
        orElse: () => OrigenCierre.automatico,
      );
}
