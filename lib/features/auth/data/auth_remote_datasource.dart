import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:dio/dio.dart';

/// Par de tokens devuelto por `/auth/refresh`.
///
/// El endpoint **no devuelve el usuario**: solo rota los tokens. Por eso el
/// repositorio conserva el usuario de la sesión previa en lugar de esperarlo.
class TokensDto {
  const TokensDto({required this.accessToken, required this.refreshToken});

  factory TokensDto.fromJson(Map<String, dynamic> json) => TokensDto(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final String accessToken;
  final String refreshToken;
}

/// Respuesta de `/auth/login`: tokens **más** el usuario con su rol.
class SesionDto {
  const SesionDto({
    required this.accessToken,
    required this.refreshToken,
    required this.id,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
  });

  factory SesionDto.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    if (usuario is! Map<String, dynamic>) {
      throw const FormatException(
        'La respuesta de login no trae el objeto usuario',
      );
    }

    return SesionDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      id: usuario['id'] as String,
      nombreCompleto: usuario['nombreCompleto'] as String,
      email: usuario['email'] as String,
      rol: usuario['rol'] as String?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String id;
  final String nombreCompleto;
  final String email;
  final String? rol;

  Sesion toDomain() => Sesion(
        accessToken: accessToken,
        refreshToken: refreshToken,
        usuario: UsuarioSesion(
          id: id,
          nombreCompleto: nombreCompleto,
          email: email,
          rol: RolUsuario.desdeApi(rol),
        ),
      );
}

/// Llamadas de autenticación.
///
/// Usa un [Dio] **propio, sin el interceptor de sesión**. Si compartiera el
/// cliente principal, un 401 del refresh dispararía otro refresh y entraría en
/// bucle.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<SesionDto> login({
    required String email,
    required String password,
  }) async {
    final respuesta = await _dio.post<Object?>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de login inesperada');
    }
    return SesionDto.fromJson(data);
  }

  /// El refresh token viaja **en el cuerpo**, no en el header: la estrategia
  /// del backend lo extrae con `ExtractJwt.fromBodyField('refreshToken')`.
  Future<TokensDto> refrescar(String refreshToken) async {
    final respuesta = await _dio.post<Object?>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de refresh inesperada');
    }
    return TokensDto.fromJson(data);
  }

  Future<void> logout(String accessToken) async {
    await _dio.post<Object?>(
      '/auth/logout',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}
