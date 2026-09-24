import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:dio/dio.dart';

/// Construcción de clientes HTTP contra el API de admisión.
///
/// Todas las rutas del contrato cuelgan del prefijo global `/api/v1`.
abstract final class ApiClient {
  static const String prefijo = '/api/v1';

  /// Dio base, **sin interceptores**.
  ///
  /// Es el que usa autenticación: si compartiera el interceptor de sesión, un
  /// 401 del refresh dispararía otro refresh y entraría en bucle.
  ///
  /// Recibe la [ConfiguracionApp] entera y no una URL suelta: los timeouts
  /// también son configuración y estaban fijos en el código. Un hospital con
  /// wifi saturado y una red de oficina no toleran los mismos valores.
  static Dio crear(ConfiguracionApp config) {
    return Dio(
      BaseOptions(
        baseUrl: normalizar(config.urlBaseApi),
        connectTimeout: config.timeoutConexion,
        receiveTimeout: config.timeoutRespuesta,
        sendTimeout: config.timeoutRespuesta,
        headers: const {'Content-Type': 'application/json'},
        // El mapeo de códigos a fallas lo hace MapeadorDeFallas a partir de la
        // DioException, así que se deja que Dio lance como siempre.
        validateStatus: (codigo) => codigo != null && codigo < 400,
      ),
    );
  }

  /// Acepta la URL con o sin `/api/v1`, con o sin barra final.
  ///
  /// Es el tipo de detalle que se configura una vez por ambiente y rompe en
  /// silencio si alguien lo escribe distinto.
  static String normalizar(String urlBase) {
    var url = urlBase.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith(prefijo)) return url;
    return '$url$prefijo';
  }
}
