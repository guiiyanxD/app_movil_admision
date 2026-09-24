/// Formateo de instantes del servidor como reloj de pared del hospital.
///
/// El API manda los timestamps en UTC. Mostrarlos sin convertir haría dudar al
/// operador de un dato que está bien: las 22:14 que informa el servidor son las
/// 18:14 en Bolivia. Por eso la conversión vive acá y ningún widget arma la
/// hora por su cuenta (SPEC-003, D-5).
///
/// Sin `intl`: `padLeft` resuelve dos números y la dependencia arrastraría
/// inicialización de locales para eso.
library;

/// Hora local en `HH:mm`.
String horaLocal(DateTime instante) {
  final local = instante.toLocal();
  return '${_dosDigitos(local.hour)}:${_dosDigitos(local.minute)}';
}

/// Hora local, precedida por el día cuando el instante no cae hoy.
///
/// Un "18:14" a secas sobre algo cargado la semana pasada se lee como si
/// hubiera pasado hace un rato, que es exactamente la confusión que la línea de
/// procedencia viene a evitar.
///
/// [ahora] es inyectable para que los tests no dependan del reloj.
String momentoLocal(DateTime instante, {DateTime? ahora}) {
  final local = instante.toLocal();
  final referencia = (ahora ?? DateTime.now()).toLocal();
  final hora = horaLocal(instante);

  // Bolivia no tiene horario de verano (ver `FechaCenso`), así que restar
  // medianoches locales da días enteros y no hay que corregir nada.
  final dias = DateTime(referencia.year, referencia.month, referencia.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;

  if (dias == 0) return hora;
  if (dias == 1) return 'ayer $hora';
  return '${_dosDigitos(local.day)}/${_dosDigitos(local.month)} $hora';
}

/// Fecha y hora locales completas, `dd/mm/aaaa HH:mm`.
///
/// Es el sello del pie de los reportes impresos. Lleva la fecha entera y no
/// solo la hora porque una hoja impresa se archiva y se vuelve a mirar meses
/// después, cuando "18:14" ya no dice nada.
String fechaHoraLocal(DateTime instante) {
  final local = instante.toLocal();
  return '${_dosDigitos(local.day)}/${_dosDigitos(local.month)}/'
      '${local.year} ${horaLocal(instante)}';
}

String _dosDigitos(int valor) => valor.toString().padLeft(2, '0');
