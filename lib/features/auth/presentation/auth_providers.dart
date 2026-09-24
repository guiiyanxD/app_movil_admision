import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Operaciones de sesión. **Lo inyecta la raíz de composición.**
///
/// El tipo declarado es la **interfaz**, no la implementación (CA-08). Este
/// archivo ya no construye el datasource, el almacén cifrado ni el cliente
/// HTTP: eso es infraestructura y se arma en `bootstrap()`. Un test monta el
/// login con un doble del contrato, sin red y sin Keystore (SPEC-005, H-6 y
/// H-7).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
    'authRepositoryProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});

/// Estado de la sesión.
sealed class EstadoSesion {
  const EstadoSesion();
}

/// Todavía no se sabe: se está leyendo el almacenamiento.
final class SesionCargando extends EstadoSesion {
  const SesionCargando();
}

final class SinSesion extends EstadoSesion {
  const SinSesion({this.motivo, this.falla});

  /// Mensaje a mostrar en el login. Distingue "cerraste sesión" de "tu sesión
  /// venció mientras trabajabas", que para el operador no es lo mismo.
  final String? motivo;
  final Failure? falla;
}

final class ConSesion extends EstadoSesion {
  const ConSesion(this.sesion);

  final Sesion sesion;
}

final sesionProvider =
    NotifierProvider<SesionNotifier, EstadoSesion>(SesionNotifier.new);

class SesionNotifier extends Notifier<EstadoSesion> {
  @override
  EstadoSesion build() {
    Future.microtask(restaurar);
    return const SesionCargando();
  }

  AuthRepository get _repositorio => ref.read(authRepositoryProvider);

  Future<void> restaurar() async {
    final sesion = await _repositorio.restaurar();
    state = sesion == null ? const SinSesion() : ConSesion(sesion);
  }

  /// Devuelve la falla si no se pudo iniciar sesión.
  Future<Failure?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    state = const SesionCargando();

    final resultado = await _repositorio.iniciarSesion(
      email: email,
      password: password,
    );

    return resultado.fold(
      (falla) {
        state = SinSesion(falla: falla);
        return falla;
      },
      (sesion) {
        state = ConSesion(sesion);
        return null;
      },
    );
  }

  Future<void> cerrarSesion() async {
    await _repositorio.cerrarSesion();
    state = const SinSesion(motivo: 'Cerraste la sesión.');
  }

  /// La invoca el interceptor cuando la renovación falla.
  void marcarSesionPerdida() {
    state = const SinSesion(
      motivo: 'Tu sesión venció. Iniciá sesión de nuevo para continuar.',
    );
  }
}

/// Sesión activa, o `null`. Atajo para las pantallas.
final sesionActivaProvider = Provider<Sesion?>((ref) {
  final estado = ref.watch(sesionProvider);
  return estado is ConSesion ? estado.sesion : null;
});

/// `true` si el usuario puede guardar y confirmar.
///
/// El rol `lectura` abre la app en modo consulta: las pantallas funcionan, los
/// formularios se ven, y los botones de escritura están deshabilitados con la
/// razón explícita. Nunca se deja completar nueve campos para recibir un 403.
// `puedeEscribirProvider` se mudó a `core/sesion/`: es una pregunta
// transversal —la hace el censo diario, no la autenticación— y tenerla acá
// obligaba a que otra feature importara esta capa de presentación para saber
// si el operador puede escribir (SPEC-005, H-8). `bootstrap()` lo satisface
// leyendo `sesionActivaProvider`.
