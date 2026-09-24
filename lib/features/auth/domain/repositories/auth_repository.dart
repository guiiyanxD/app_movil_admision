import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';

/// Operaciones de sesión contra el servidor y el almacenamiento local.
///
/// Es contrato y no clase concreta porque `auth` era la **única** feature sin
/// abstracción: `censo_diario` y `reporteria` ya declaraban su repositorio en
/// `domain/` y la presentación consumía la interfaz. Que el defecto de la URL
/// apareciera justo en la feature sin contrato no fue casualidad (SPEC-005,
/// H-4).
///
/// **No expone la sesión actual.** Eso es estado, vive en `SesionEnMemoria`
/// —en `data/`— y se lee de ahí. Antes el repositorio guardaba el `Sesion?`
/// mutable, el
/// control de concurrencia del refresco, la red y la persistencia: cuatro
/// responsabilidades en una clase (H-5).
abstract interface class AuthRepository {
  /// Credenciales contra el servidor. Persiste la sesión si son válidas.
  Future<Resultado<Sesion>> iniciarSesion({
    required String email,
    required String password,
  });

  /// Recupera la sesión guardada al abrir la app. `null` si no hay ninguna.
  Future<Sesion?> restaurar();

  /// Renueva el access token. `false` si la sesión ya no sirve.
  ///
  /// **No es de un solo vuelo.** Quien necesite esa garantía la agrega: la
  /// coordinación entre peticiones simultáneas es del que las emite, no de
  /// esta operación. Lo hace `ProveedorDeSesionAuth`, que es el único que la
  /// llama desde el interceptor.
  Future<bool> refrescar();

  Future<void> cerrarSesion({bool avisarAlServidor});
}
