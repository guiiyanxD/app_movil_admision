/// Estado de carga de un servicio dentro de una fecha.
class ProgresoServicio {
  const ProgresoServicio({
    required this.servicioId,
    required this.servicioNombre,
    required this.cargado,
    this.cuadra,
  });

  final String servicioId;
  final String servicioNombre;
  final bool cargado;

  /// `null` cuando [cargado] es `false`: no hay datos que evaluar todavía.
  ///
  /// El backend lo recalcula contra la capacidad de camas **actual** en cada
  /// llamada. Si el catálogo de camas cambió, este valor puede cambiar sin que
  /// nadie haya tocado el servicio (riesgo R-03).
  final bool? cuadra;

  bool get listo => cargado && cuadra == true;

  bool get cargadoPeroDesbalanceado => cargado && cuadra == false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgresoServicio &&
          other.servicioId == servicioId &&
          other.servicioNombre == servicioNombre &&
          other.cargado == cargado &&
          other.cuadra == cuadra;

  @override
  int get hashCode =>
      Object.hash(servicioId, servicioNombre, cargado, cuadra);
}

/// Progreso completo de una fecha.
class ProgresoDia {
  const ProgresoDia({required this.fecha, required this.servicios});

  final DateTime fecha;

  /// Un elemento por cada servicio activo del catálogo, no solo los cargados.
  final List<ProgresoServicio> servicios;

  int get total => servicios.length;

  int get cargados => servicios.where((s) => s.cargado).length;

  int get listos => servicios.where((s) => s.listo).length;

  List<ProgresoServicio> get pendientes =>
      servicios.where((s) => !s.cargado).toList();

  List<ProgresoServicio> get desbalanceados =>
      servicios.where((s) => s.cargadoPeroDesbalanceado).toList();

  /// "Confirmar día" solo se habilita cuando **todos** están cargados y cuadran.
  ///
  /// Una lista vacía nunca habilita: sin servicios no hay nada que confirmar, y
  /// dejar pasar ese caso sería habilitar el botón por un catálogo que no cargó.
  bool get puedeConfirmar =>
      servicios.isNotEmpty && servicios.every((s) => s.listo);

  /// Texto de progreso para la pantalla de resumen.
  String get resumen => '$cargados de $total servicios cargados';
}

/// Respuesta de `POST /carga-manual/confirmar`.
class ConfirmacionDia {
  const ConfirmacionDia({required this.fecha, required this.servicios});

  final String fecha;
  final int servicios;
}
