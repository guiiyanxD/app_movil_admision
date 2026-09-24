import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` si el usuario de la sesión puede guardar y confirmar.
///
/// **Lo inyecta la raíz de composición.** Es una pregunta transversal: la hace
/// el censo diario para habilitar el botón de guardar y la haría cualquier
/// módulo con escritura. Vivía en los providers de autenticación, así que el
/// censo importaba la capa de presentación de otra feature para saber si el
/// operador podía escribir (SPEC-005, H-8).
///
/// Expone un `bool` y no la sesión: el núcleo no puede conocer `Sesion`, que es
/// una entidad de `auth`. Quien necesita el usuario y su rol —el menú de
/// cuenta— vive en `app/`, que sí puede.
///
/// El rol `lectura` abre la app en modo consulta: las pantallas funcionan, los
/// formularios se ven, y los botones de escritura están deshabilitados con la
/// razón explícita. Nunca se deja completar nueve campos para recibir un 403.
final puedeEscribirProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'puedeEscribirProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});
