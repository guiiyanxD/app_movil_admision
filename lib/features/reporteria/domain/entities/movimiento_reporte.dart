/// Los ocho movimientos que reporta el censo.
///
/// Son los mismos y en el mismo orden que `MOVIMIENTOS_CENSO` de la web
/// (`apps/web/src/features/reporteria/constantes.ts`). Esa lista **sí** se
/// replica como constante, a diferencia de la de servicios: los movimientos son
/// las columnas fijas del EST-1, no dependen de ningún catálogo y no cambian
/// salvo que cambie el formulario.
enum MovimientoReporte {
  ingreso('ingreso', 'Ingreso'),
  ingresoTraslado('ingresoTraslado', 'Ingreso por traslado'),
  egreso('egreso', 'Egreso'),
  egresoTraslado('egresoTraslado', 'Egreso por traslado'),
  obito('obito', 'Óbito'),
  aislamiento('aislamiento', 'Aislamiento'),
  bloqueada('bloqueada', 'Bloqueada'),
  total('total', 'Total');

  const MovimientoReporte(this.clave, this.etiqueta);

  /// Nombre del campo en la respuesta del API.
  final String clave;

  /// Título de la página del PDF y del selector en pantalla.
  final String etiqueta;
}
