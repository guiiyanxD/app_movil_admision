import 'package:app_movil/core/config/ambiente_servidor.dart';
import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:app_movil/core/config/configuracion_dart_define.dart';
import 'package:app_movil/core/config/gestor_servidor.dart';
import 'package:app_movil/core/red/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConfigDePrueba implements ConfiguracionApp {
  const _ConfigDePrueba();

  @override
  String get urlBaseApi => 'http://ejemplo.local:3001';

  @override
  String get nombreDestino => 'Prueba';

  @override
  Duration get timeoutConexion => const Duration(seconds: 1);

  @override
  Duration get timeoutRespuesta => const Duration(seconds: 2);
}

void main() {
  group('configuracionProvider', () {
    test('lanza si nadie lo sobreescribió', () {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);

      expect(
        () => contenedor.read(configuracionProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('el mensaje dice dónde se arregla', () {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);

      expect(
        () => contenedor.read(configuracionProvider),
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('bootstrap.dart'),
          ),
        ),
      );
    });

    test('con override devuelve la configuración inyectada', () {
      final contenedor = ProviderContainer(
        overrides: [
          configuracionProvider.overrideWithValue(const _ConfigDePrueba()),
        ],
      );
      addTearDown(contenedor.dispose);

      expect(
        contenedor.read(configuracionProvider).urlBaseApi,
        'http://ejemplo.local:3001',
      );
    });
  });

  group('gestorServidorProvider', () {
    test('proporciona configuración por defecto segura', () {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);

      final config = contenedor.read(gestorServidorProvider).config;
      expect(config.urlBaseApi, contains('3001'));
      expect(config.nombreDestino, isNotEmpty);
    });
  });

  group('ConfiguracionDartDefine', () {
    test('sin API_URL y con obligar=true falla explícitamente', () {
      expect(
        () => ConfiguracionDartDefine.desdeEntorno(obligar: true),
        throwsA(isA<ConfiguracionInvalida>()),
      );
    });

    test('sin API_URL por defecto toma equipo local (192.168.66.84)', () {
      final config = ConfiguracionDartDefine.desdeEntorno();
      expect(config.urlBaseApi, 'http://192.168.66.84:3001');
      expect(config.ambiente, AmbienteServidor.equipo);
    });

    test('conserva los valores recibidos', () {
      const config = ConfiguracionDartDefine(
        urlBaseApi: 'http://192.168.1.10:3001',
        nombreDestino: 'Hospital',
      );

      expect(config.urlBaseApi, 'http://192.168.1.10:3001');
      expect(config.nombreDestino, 'Hospital');
      expect(config.timeoutConexion, const Duration(seconds: 15));
      expect(config.timeoutRespuesta, const Duration(seconds: 20));
    });
  });

  group('AmbienteServidor', () {
    test('contiene los servidores necesarios', () {
      expect(AmbienteServidor.equipo.url, 'http://192.168.66.84:3001');
      expect(AmbienteServidor.wifi.url, 'http://192.168.100.104:3001');
      expect(AmbienteServidor.emulador.url, 'http://10.0.2.2:3001');
    });

    test('detecta ambiente por URL', () {
      expect(
        AmbienteServidor.desdeUrl('http://192.168.66.84:3001'),
        AmbienteServidor.equipo,
      );
      expect(
        AmbienteServidor.desdeUrl('http://10.0.2.2:3001'),
        AmbienteServidor.emulador,
      );
      expect(
        AmbienteServidor.desdeUrl('http://otra-ip:9999'),
        AmbienteServidor.personalizado,
      );
    });
  });

  group('ApiClient toma su configuración por inyección', () {
    test('arma la URL base con el prefijo del contrato', () {
      final dio = ApiClient.crear(const _ConfigDePrueba());

      expect(dio.options.baseUrl, 'http://ejemplo.local:3001/api/v1');
    });

    test('los timeouts salen de la configuración, no del código', () {
      final dio = ApiClient.crear(const _ConfigDePrueba());

      expect(dio.options.connectTimeout, const Duration(seconds: 1));
      expect(dio.options.receiveTimeout, const Duration(seconds: 2));
      expect(dio.options.sendTimeout, const Duration(seconds: 2));
    });
  });
}
