import 'package:meta/meta.dart';

/// Roles del sistema.
///
/// `lectura` no puede escribir carga manual. La app lo detecta al iniciar
/// sesión y abre en modo consulta, en vez de dejar que el operador complete
/// nueve campos para recibir un 403 al guardar (ADR-0005, D-8).
enum RolUsuario {
  admin('admin'),
  operador('operador'),
  lectura('lectura');

  const RolUsuario(this.valorApi);

  final String valorApi;

  /// Ante un rol desconocido se asume el más restrictivo. Si el backend
  /// agrega un rol nuevo, la app lo trata como solo lectura hasta que se la
  /// actualice — nunca al revés.
  static RolUsuario desdeApi(String? valor) => values.firstWhere(
        (r) => r.valorApi == valor,
        orElse: () => RolUsuario.lectura,
      );

  /// Puede guardar y confirmar carga manual.
  bool get puedeEscribirCargaManual =>
      this == RolUsuario.admin || this == RolUsuario.operador;

  String get etiqueta => switch (this) {
        RolUsuario.admin => 'Administrador',
        RolUsuario.operador => 'Operador',
        RolUsuario.lectura => 'Consulta',
      };
}

@immutable
class UsuarioSesion {
  const UsuarioSesion({
    required this.id,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
  });

  final String id;
  final String nombreCompleto;
  final String email;
  final RolUsuario rol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsuarioSesion &&
          other.id == id &&
          other.nombreCompleto == nombreCompleto &&
          other.email == email &&
          other.rol == rol;

  @override
  int get hashCode => Object.hash(id, nombreCompleto, email, rol);
}

/// Sesión activa: tokens + usuario.
///
/// El `accessToken` vive un día y el `refreshToken` siete. Renovar **rota** el
/// refresh token en el servidor, así que el nuevo hay que persistirlo o la
/// siguiente renovación falla con "Sesión inválida".
class Sesion {
  const Sesion({
    required this.accessToken,
    required this.refreshToken,
    required this.usuario,
  });

  final String accessToken;
  final String refreshToken;
  final UsuarioSesion usuario;

  RolUsuario get rol => usuario.rol;

  bool get puedeEscribir => usuario.rol.puedeEscribirCargaManual;

  Sesion conTokens({
    required String accessToken,
    required String refreshToken,
  }) =>
      Sesion(
        accessToken: accessToken,
        refreshToken: refreshToken,
        usuario: usuario,
      );
}
