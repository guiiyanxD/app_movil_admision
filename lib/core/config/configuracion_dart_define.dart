import 'package:app_movil/core/config/ambiente_servidor.dart';
import 'package:app_movil/core/config/configuracion_app.dart';

/// Configuración leída de `--dart-define` con fallback seguro al equipo de desarrollo.
///
/// **Único lugar de la aplicación que lee el entorno** (regla `CONFIG-CENTRAL`, CA-01).
/// Si se pasa `--dart-define=API_URL=...`, se utiliza; si no, toma automáticamente
/// [AmbienteServidor.equipo] (192.168.66.84:3001) para que `flutter run` o F5
/// arranquen de inmediato sin requerir scripts externos de PowerShell.
class ConfiguracionDartDefine implements ConfiguracionApp {
  const ConfiguracionDartDefine({
    required this.urlBaseApi,
    required this.nombreDestino,
    this.ambiente = AmbienteServidor.equipo,
    this.timeoutConexion = const Duration(seconds: 45),
    this.timeoutRespuesta = const Duration(seconds: 45),
  });

  /// Lee el entorno si fue provisto por `--dart-define`.
  ///
  /// Si falta la URL y [obligar] es false, utiliza [AmbienteServidor.equipo]
  /// como valor por defecto seguro. Si [obligar] es true (ej. en tests específicos),
  /// lanza [ConfiguracionInvalida].
  factory ConfiguracionDartDefine.desdeEntorno({bool obligar = false}) {
    const url = String.fromEnvironment('API_URL');
    const destino = String.fromEnvironment(
      'API_DESTINO',
    );

    if (url.trim().isEmpty) {
      if (obligar) {
        throw const ConfiguracionInvalida(
          'Falta API_URL.\n\n'
          'Pasa la URL mediante:\n'
          '  flutter run --dart-define=API_URL=http://IP:PUERTO\n'
          'O utiliza tool/correr.ps1',
        );
      }
      const defecto = AmbienteServidor.equipo;
      return ConfiguracionDartDefine(
        urlBaseApi: defecto.url,
        nombreDestino: destino.isNotEmpty ? destino : defecto.nombre,
      );
    }

    final ambienteDetectado = AmbienteServidor.desdeUrl(url);

    return ConfiguracionDartDefine(
      urlBaseApi: url,
      nombreDestino: destino.isNotEmpty ? destino : ambienteDetectado.nombre,
      ambiente: ambienteDetectado,
    );
  }

  @override
  final String urlBaseApi;

  @override
  final String nombreDestino;

  final AmbienteServidor ambiente;

  @override
  final Duration timeoutConexion;

  @override
  final Duration timeoutRespuesta;

  ConfiguracionDartDefine copiarCon({
    String? urlBaseApi,
    String? nombreDestino,
    AmbienteServidor? ambiente,
    Duration? timeoutConexion,
    Duration? timeoutRespuesta,
  }) {
    return ConfiguracionDartDefine(
      urlBaseApi: urlBaseApi ?? this.urlBaseApi,
      nombreDestino: nombreDestino ?? this.nombreDestino,
      ambiente: ambiente ?? this.ambiente,
      timeoutConexion: timeoutConexion ?? this.timeoutConexion,
      timeoutRespuesta: timeoutRespuesta ?? this.timeoutRespuesta,
    );
  }
}

/// La app no puede arrancar con la configuración recibida.
class ConfiguracionInvalida implements Exception {
  const ConfiguracionInvalida(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'ConfiguracionInvalida: $mensaje';
}
