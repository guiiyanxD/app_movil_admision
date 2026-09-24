import 'package:app_movil/core/config/ambiente_servidor.dart';
import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:app_movil/core/config/configuracion_dart_define.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Resultado del diagnóstico de prueba de conexión con el backend.
class ResultadoPruebaConexion {
  const ResultadoPruebaConexion({
    required this.exitoso,
    required this.mensaje,
    this.latenciaMs,
  });

  final bool exitoso;
  final String mensaje;
  final int? latenciaMs;
}

/// Estado del gestor de configuración del servidor.
class GestorServidorState {
  const GestorServidorState({
    required this.config,
    this.probandoConexion = false,
    this.resultadoPrueba,
  });

  final ConfiguracionApp config;
  final bool probandoConexion;
  final ResultadoPruebaConexion? resultadoPrueba;

  GestorServidorState copyWith({
    ConfiguracionApp? config,
    bool? probandoConexion,
    ResultadoPruebaConexion? resultadoPrueba,
    bool limpiarResultado = false,
  }) {
    return GestorServidorState(
      config: config ?? this.config,
      probandoConexion: probandoConexion ?? this.probandoConexion,
      resultadoPrueba: limpiarResultado
          ? null
          : (resultadoPrueba ?? this.resultadoPrueba),
    );
  }
}

/// Notifier que administra el ambiente activo, permite cambiarlo en runtime
/// y valida la conectividad en vivo.
class GestorServidorNotifier extends StateNotifier<GestorServidorState> {
  GestorServidorNotifier(ConfiguracionApp configInicial)
      : super(GestorServidorState(config: configInicial)) {
    _cargarGuardado();
  }

  static const _claveUrl = 'config_api_url_activa';
  static const _claveDestino = 'config_api_destino_activo';
  final _almacen = const FlutterSecureStorage();

  Future<void> _cargarGuardado() async {
    try {
      final urlGuardada = await _almacen.read(key: _claveUrl);
      final destinoGuardado = await _almacen.read(key: _claveDestino);
      if (urlGuardada != null && urlGuardada.trim().isNotEmpty) {
        final ambiente = AmbienteServidor.desdeUrl(urlGuardada);
        final nuevaConfig = ConfiguracionDartDefine(
          urlBaseApi: urlGuardada.trim(),
          nombreDestino: (destinoGuardado != null && destinoGuardado.isNotEmpty)
              ? destinoGuardado
              : ambiente.nombre,
          ambiente: ambiente,
        );
        state = state.copyWith(config: nuevaConfig);
      }
    } catch (_) {
      // Si falla la lectura del almacenamiento seguro, se conserva la config inicial.
    }
  }

  /// Cambia el servidor activo y persiste la elección en el almacenamiento local.
  Future<void> cambiarServidor({
    required AmbienteServidor ambiente,
    String? urlPersonalizada,
  }) async {
    String url = ambiente.url;
    String nombre = ambiente.nombre;

    if (ambiente == AmbienteServidor.personalizado && urlPersonalizada != null) {
      url = urlPersonalizada.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      nombre = 'Personalizado ($url)';
    }

    final nuevaConfig = ConfiguracionDartDefine(
      urlBaseApi: url,
      nombreDestino: nombre,
      ambiente: ambiente,
    );

    state = state.copyWith(
      config: nuevaConfig,
      limpiarResultado: true,
    );

    try {
      await _almacen.write(key: _claveUrl, value: url);
      await _almacen.write(key: _claveDestino, value: nombre);
    } catch (_) {}
  }

  /// Diagnostica conectividad en tiempo real contra una URL específica.
  Future<ResultadoPruebaConexion> probarConexion(String urlAProbar) async {
    var url = urlAProbar.trim();
    if (url.isEmpty) {
      return const ResultadoPruebaConexion(
        exitoso: false,
        mensaje: 'La URL no puede estar vacía',
      );
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    state = state.copyWith(
      probandoConexion: true,
      limpiarResultado: true,
    );

    final stopwatch = Stopwatch()..start();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    try {
      final urlCompleta = url.endsWith('/') ? '${url}api/v1' : '$url/api/v1';
      final respuesta = await dio.get(urlCompleta);
      stopwatch.stop();

      final resultado = ResultadoPruebaConexion(
        exitoso: respuesta.statusCode != null && respuesta.statusCode! < 500,
        mensaje: 'Servidor respondió con código ${respuesta.statusCode}',
        latenciaMs: stopwatch.elapsedMilliseconds,
      );

      state = state.copyWith(
        probandoConexion: false,
        resultadoPrueba: resultado,
      );
      return resultado;
    } on DioException catch (e) {
      stopwatch.stop();
      String mensajeError = 'Error de conexión';
      if (e.type == DioExceptionType.connectionTimeout) {
        mensajeError = 'Tiempo de espera agotado (¿Firewall o IP incorrecta?)';
      } else if (e.type == DioExceptionType.connectionError) {
        mensajeError = 'No se pudo conectar al host (¿Backend no iniciado o IP inalcanzable?)';
      } else if (e.response != null) {
        mensajeError = 'Respuesta del servidor: ${e.response?.statusCode}';
      }

      final resultado = ResultadoPruebaConexion(
        exitoso: false,
        mensaje: mensajeError,
        latenciaMs: stopwatch.elapsedMilliseconds,
      );

      state = state.copyWith(
        probandoConexion: false,
        resultadoPrueba: resultado,
      );
      return resultado;
    } catch (e) {
      stopwatch.stop();
      final resultado = ResultadoPruebaConexion(
        exitoso: false,
        mensaje: 'Fallo inesperado: $e',
      );
      state = state.copyWith(
        probandoConexion: false,
        resultadoPrueba: resultado,
      );
      return resultado;
    }
  }
}

/// Provider principal para gestionar el servidor activo.
final gestorServidorProvider =
    StateNotifierProvider<GestorServidorNotifier, GestorServidorState>((ref) {
  return GestorServidorNotifier(ConfiguracionDartDefine.desdeEntorno());
});
