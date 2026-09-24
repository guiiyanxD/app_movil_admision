/// Fecha de un censo diario, con la regla de negocio que decide si es cargable.
///
/// ## Por qué existe este value object
///
/// El backend evalúa `puedeCargarManual` en **UTC**. Bolivia es UTC−4 sin
/// horario de verano, así que entre las 20:00 y la medianoche hora local el
/// servidor ya considera "ayer" al día en curso y **lo aceptaría**.
///
/// El cliente valida en hora local de Bolivia a propósito: así nunca es más
/// permisivo que el servidor, solo más estricto. No relajar esta regla para
/// "aprovechar" el hueco de UTC (ADR-0005, D-9).
class FechaCenso {
  /// Construye una fecha de censo válida.
  ///
  /// Lanza [FechaCensoInvalida] si la fecha es hoy o futura en hora de Bolivia.
  factory FechaCenso(DateTime fecha, {DateTime? ahora}) {
    final soloFecha = truncar(fecha);
    if (!esCargable(soloFecha, ahora: ahora)) {
      throw FechaCensoInvalida(soloFecha);
    }
    return FechaCenso._(soloFecha);
  }

  const FechaCenso._(this.valor);

  /// Fecha sin componente horario.
  final DateTime valor;

  /// Desfase fijo de Bolivia respecto de UTC. No hay horario de verano.
  static const Duration desfaseBolivia = Duration(hours: -4);

  /// Quita hora, minutos, segundos y milisegundos.
  static DateTime truncar(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  /// "Hoy" en hora de Bolivia, calculado desde un instante dado.
  ///
  /// [ahora] se interpreta como instante absoluto; se convierte a UTC y se le
  /// aplica el desfase. Inyectable para que los tests no dependan del reloj ni
  /// de la zona horaria de la máquina que corre la suite.
  static DateTime hoyEnBolivia({DateTime? ahora}) {
    final instante = (ahora ?? DateTime.now()).toUtc();
    final enBolivia = instante.add(desfaseBolivia);
    return DateTime(enBolivia.year, enBolivia.month, enBolivia.day);
  }

  /// `true` si la fecha es estrictamente anterior a hoy en hora de Bolivia.
  static bool esCargable(DateTime fecha, {DateTime? ahora}) =>
      truncar(fecha).isBefore(hoyEnBolivia(ahora: ahora));

  /// Serialización obligatoria para el API: `'YYYY-MM-DD'` plano.
  ///
  /// **Nunca** enviar ISO-8601 con offset: el backend hace
  /// `new Date(`${fecha}T00:00:00Z`)` y un offset `-04:00` corre el día
  /// completo hacia atrás.
  String get comoParametroApi {
    final mes = valor.month.toString().padLeft(2, '0');
    final dia = valor.day.toString().padLeft(2, '0');
    return '${valor.year}-$mes-$dia';
  }

  /// Día anterior, para consultar el total de cierre de referencia.
  DateTime get diaAnterior => valor.subtract(const Duration(days: 1));

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FechaCenso && other.valor == valor;

  @override
  int get hashCode => valor.hashCode;

  @override
  String toString() => comoParametroApi;
}

class FechaCensoInvalida implements Exception {
  const FechaCensoInvalida(this.fecha);

  final DateTime fecha;

  String get mensaje =>
      'Solo se pueden cargar fechas anteriores a hoy. '
      'No se admite el día en curso ni fechas futuras.';

  @override
  String toString() => 'FechaCensoInvalida($fecha): $mensaje';
}
