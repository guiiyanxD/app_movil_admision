import 'package:app_movil/features/auth/domain/entities/sesion.dart';

/// Persistencia de la sesión entre arranques de la app.
///
/// Estaba en `core/almacenamiento/`, y era la única infracción de la regla
/// "el núcleo no importa features": su firma habla de `Sesion`, una entidad de
/// esta feature (SPEC-005, H-10).
///
/// La solución no fue subir `Sesion` al núcleo sino bajar el almacén acá.
/// `AlmacenSesion` no lo usa nadie más en la aplicación —se verificó— y guardar
/// la sesión es asunto de autenticación, no del núcleo. Poner en `core/` lo
/// que solo sirve a una feature es cómo un núcleo se convierte en un cajón.
///
/// Sigue siendo interfaz para que el repositorio y los tests no dependan del
/// almacenamiento cifrado del dispositivo.
abstract interface class AlmacenSesion {
  Future<Sesion?> leer();
  Future<void> guardar(Sesion sesion);
  Future<void> borrar();
}
