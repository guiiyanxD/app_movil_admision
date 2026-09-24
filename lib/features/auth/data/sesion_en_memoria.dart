import 'package:app_movil/features/auth/domain/entities/sesion.dart';

/// La sesión vigente, en memoria.
///
/// Se extrajo de `AuthRepository`, que guardaba este `Sesion?` mutable además
/// de hacer red y persistencia (SPEC-005, H-5). Un almacén de estado viviendo
/// dentro de un repositorio es difícil de ver y fácil de compartir por
/// accidente: cualquiera con el repositorio podía leer y escribir la sesión.
///
/// Existe **además** del almacenamiento cifrado y no en su lugar. El
/// interceptor consulta el token en cada petición, y bajar al Keystore en el
/// camino caliente costaría milisegundos por request para releer algo que ya
/// se tiene.
class SesionEnMemoria {
  Sesion? _sesion;

  Sesion? get actual => _sesion;

  String? get accessToken => _sesion?.accessToken;

  // `guardar` / `limpiar` en vez de un setter: el par nombrado dice qué pasa
  // con la sesión, y `memoria.actual = null` para cerrar sesión se lee mucho
  // peor que `memoria.limpiar()`.
  // ignore: use_setters_to_change_properties
  void guardar(Sesion sesion) => _sesion = sesion;

  void limpiar() => _sesion = null;
}
