import 'package:app_movil/core/red/proveedor_de_sesion.dart';
import 'package:dio/dio.dart';

/// Agrega el bearer a cada petición y renueva la sesión ante un 401.
///
/// Tres detalles que parecen menores y no lo son:
///
/// 1. **No se renueva sobre las rutas de `/auth`.** Un 401 del login son
///    credenciales incorrectas y un 401 del refresh es una sesión muerta: en
///    ambos casos renovar entraría en bucle.
/// 2. **Una petición se reintenta una sola vez.** La marca viaja en
///    `options.extra`, así que un 401 persistente falla en vez de girar.
/// 3. **La renovación es de un solo vuelo.** Lo garantiza el repositorio: si
///    varias peticiones fallan a la vez, todas esperan la misma renovación.
class InterceptorSesion extends Interceptor {
  InterceptorSesion({
    required ProveedorDeSesion sesion,
    required Dio dio,
  })  : _sesion = sesion,
        _dio = dio;

  /// Contrato del núcleo, no la feature de autenticación (ADR-0006, D-3).
  ///
  /// Reemplaza a los tres callbacks sueltos que recibía antes: eran la misma
  /// dependencia partida en tres, sin nombre y sin forma de sustituirla entera
  /// en un test.
  final ProveedorDeSesion _sesion;

  final Dio _dio;

  static const String _marcaReintento = 'sesion_reintentada';

  static bool esRutaDeAuth(String ruta) => ruta.contains('/auth/');

  @override
  void onRequest(
    RequestOptions opciones,
    RequestInterceptorHandler manejador,
  ) {
    if (!esRutaDeAuth(opciones.path)) {
      final token = _sesion.accessToken;
      if (token != null && token.isNotEmpty) {
        opciones.headers['Authorization'] = 'Bearer $token';
      }
    }
    manejador.next(opciones);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler manejador,
  ) async {
    final opciones = error.requestOptions;
    final esNoAutorizado = error.response?.statusCode == 401;
    final yaReintentada = opciones.extra[_marcaReintento] == true;

    if (!esNoAutorizado || yaReintentada || esRutaDeAuth(opciones.path)) {
      manejador.next(error);
      return;
    }

    final renovo = await _sesion.refrescar();
    if (!renovo) {
      _sesion.alPerderSesion();
      manejador.next(error);
      return;
    }

    try {
      final respuesta = await _dio.fetch<Object?>(
        opciones
          ..extra[_marcaReintento] = true
          ..headers['Authorization'] = 'Bearer ${_sesion.accessToken}',
      );
      manejador.resolve(respuesta);
    } on DioException catch (e) {
      manejador.next(e);
    }
  }
}
