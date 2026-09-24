import 'dart:convert';

import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/almacen_sesion.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Implementación sobre el almacenamiento cifrado del sistema
/// (Keystore en Android, Keychain en iOS).
///
/// Los tokens no van a `SharedPreferences`: en un dispositivo con root serían
/// legibles en texto plano, y estos dan acceso al censo de un hospital.
class AlmacenSesionSeguro implements AlmacenSesion {
  AlmacenSesionSeguro([FlutterSecureStorage? almacen])
      : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  static const String _clave = 'sesion_admision';

  @override
  Future<Sesion?> leer() async {
    final crudo = await _almacen.read(key: _clave);
    if (crudo == null || crudo.isEmpty) return null;

    try {
      final json = jsonDecode(crudo) as Map<String, dynamic>;
      return Sesion(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        usuario: UsuarioSesion(
          id: json['id'] as String,
          nombreCompleto: json['nombreCompleto'] as String,
          email: json['email'] as String,
          rol: RolUsuario.desdeApi(json['rol'] as String?),
        ),
      );
    } on Object {
      // Un payload corrupto o de una versión anterior del formato no debe
      // dejar la app inutilizable: se descarta y se pide login de nuevo.
      await borrar();
      return null;
    }
  }

  @override
  Future<void> guardar(Sesion sesion) async {
    await _almacen.write(
      key: _clave,
      value: jsonEncode({
        'accessToken': sesion.accessToken,
        'refreshToken': sesion.refreshToken,
        'id': sesion.usuario.id,
        'nombreCompleto': sesion.usuario.nombreCompleto,
        'email': sesion.usuario.email,
        'rol': sesion.usuario.rol.valorApi,
      }),
    );
  }

  @override
  Future<void> borrar() => _almacen.delete(key: _clave);
}

/// Almacén en memoria. Para tests y para el modo de desarrollo.
class AlmacenSesionEnMemoria implements AlmacenSesion {
  Sesion? _sesion;

  @override
  Future<Sesion?> leer() async => _sesion;

  @override
  Future<void> guardar(Sesion sesion) async => _sesion = sesion;

  @override
  Future<void> borrar() async => _sesion = null;
}
