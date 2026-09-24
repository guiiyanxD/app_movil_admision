/// Lo mínimo que la capa de red necesita saber de la sesión.
///
/// Existe para **invertir la dependencia** entre el núcleo y la feature de
/// autenticación (ADR-0006, D-3). Antes el cliente HTTP de toda la aplicación
/// se construía dentro de `features/auth/presentation/`, así que cualquier
/// feature que quisiera hablar con el API tenía que importar la capa de
/// presentación de otra.
///
/// Ahora es al revés: `core/red/` declara qué necesita —un token, una forma de
/// renovarlo y un aviso cuando ya no se puede— y `auth` lo satisface. El
/// núcleo no sabe que existe una feature de autenticación, ni cómo guarda sus
/// tokens, ni qué pantalla muestra cuando la sesión muere.
///
/// Son tres miembros y no el repositorio entero a propósito: el interceptor no
/// tiene por qué poder iniciar sesión ni cerrarla.
abstract interface class ProveedorDeSesion {
  /// Token vigente, o `null` si no hay sesión.
  ///
  /// Se lee en cada petición, así que la implementación debería tenerlo en
  /// memoria y no ir al almacenamiento cifrado en el camino caliente.
  String? get accessToken;

  /// Renueva el token. `false` si la sesión ya no se puede recuperar.
  ///
  /// La implementación es responsable de que la renovación sea **de un solo
  /// vuelo**: si cinco peticiones reciben 401 a la vez, debe dispararse una y
  /// las demás esperar su resultado.
  Future<bool> refrescar();

  /// Se invoca cuando la renovación falló y no hay nada que reintentar.
  void alPerderSesion();
}
