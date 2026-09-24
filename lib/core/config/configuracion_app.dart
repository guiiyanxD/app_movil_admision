import 'package:app_movil/core/config/ambiente_servidor.dart';

/// Configuración de ejecución de la app.
abstract interface class ConfiguracionApp {
  /// URL raíz del API, sin el prefijo `/api/v1`, que agrega `ApiClient`.
  String get urlBaseApi;

  /// Nombre legible del destino, para mostrar en pantalla y en diagnósticos.
  String get nombreDestino;

  Duration get timeoutConexion;

  Duration get timeoutRespuesta;
}

/// Extensiones de utilidad para trabajar con [AmbienteServidor].
extension ConfiguracionAppExt on ConfiguracionApp {
  AmbienteServidor get ambiente => AmbienteServidor.desdeUrl(urlBaseApi);
}
