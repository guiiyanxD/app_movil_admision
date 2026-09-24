import 'package:app_movil/core/voz/servicio_dictado.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Motor de dictado del dispositivo.
///
/// Vivía en los providers del censo diario, así que la pantalla de diagnóstico
/// —que solo mide el motor de voz y no toca el censo— tenía que importar la
/// capa de presentación de esa feature (SPEC-005, H-8).
///
/// El servicio siempre estuvo en `core/voz/`; lo único fuera de lugar era su
/// provider.
final servicioDictadoProvider = Provider<ServicioDictado>((ref) {
  final servicio = ServicioDictadoSpeechToText();
  // Cierra los streams de nivel y eventos al desmontar el scope.
  ref.onDispose(servicio.dispose);
  return servicio;
});
