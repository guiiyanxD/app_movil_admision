/// Cómo se agrupan los períodos del reporte.
///
/// Se traduce al parámetro `detalle` del API, que en el backend decide el
/// `TO_CHAR`: `'YYYY-MM-DD'` o `'YYYY-MM'`.
enum AgrupacionReporte {
  diaria('Detalle diario'),
  mensual('Resumen mensual');

  const AgrupacionReporte(this.etiqueta);

  final String etiqueta;

  /// El API llama `detalle` a lo que acá es "agrupación diaria".
  bool get comoParametroDetalle => this == AgrupacionReporte.diaria;
}

/// Rango de fechas válido para pedir un reporte.
///
/// Se valida antes de salir a la red: un rango invertido o incompleto no es un
/// error del servidor, y hacerle pagar un viaje de red al operador para
/// devolverle una lista vacía sería confundir "no hay datos" con "pediste mal".
class RangoFechas {
  factory RangoFechas({
    required DateTime inicio,
    required DateTime fin,
  }) {
    final desde = truncar(inicio);
    final hasta = truncar(fin);

    if (hasta.isBefore(desde)) {
      throw RangoInvalido.invertido(desde, hasta);
    }

    return RangoFechas._(desde, hasta);
  }

  const RangoFechas._(this.inicio, this.fin);

  final DateTime inicio;
  final DateTime fin;

  static DateTime truncar(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  /// Misma serialización que el resto de la app: `YYYY-MM-DD` plano, sin
  /// offset. El backend interpola la fecha en un cast `::date`.
  static String formatear(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  String get inicioComoParametro => formatear(inicio);
  String get finComoParametro => formatear(fin);

  /// Cantidad de días que abarca, ambos extremos incluidos.
  int get dias => fin.difference(inicio).inDays + 1;

  /// `true` si el rango cruza más de un mes calendario.
  ///
  /// Con un solo mes, el resumen mensual devuelve una única fila y el reporte
  /// pierde sentido; la pantalla lo usa para no ofrecer la opción a ciegas.
  bool get abarcaVariosMeses =>
      inicio.year != fin.year || inicio.month != fin.month;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RangoFechas && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);

  @override
  String toString() => '$inicioComoParametro a $finComoParametro';
}

class RangoInvalido implements Exception {
  const RangoInvalido(this.mensaje);

  factory RangoInvalido.invertido(DateTime inicio, DateTime fin) =>
      RangoInvalido(
        'La fecha final (${RangoFechas.formatear(fin)}) es anterior a la '
        'inicial (${RangoFechas.formatear(inicio)}).',
      );

  final String mensaje;

  @override
  String toString() => 'RangoInvalido: $mensaje';
}
