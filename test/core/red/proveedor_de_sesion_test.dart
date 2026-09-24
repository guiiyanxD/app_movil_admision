import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:app_movil/core/red/interceptor_sesion.dart';
import 'package:app_movil/core/red/proveedor_de_sesion.dart';
import 'package:app_movil/core/red/red_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble del contrato. Que se pueda escribir en veinte líneas, sin repositorio
/// ni almacenamiento cifrado, es justamente lo que buscaba la inversión de
/// dependencia de ADR-0006 D-3.
class _SesionFalsa implements ProveedorDeSesion {
  @override
  String? accessToken = 'token-1';

  bool renovacionExitosa = true;

  int refrescos = 0;
  int avisosDePerdida = 0;

  @override
  Future<bool> refrescar() async {
    refrescos++;
    if (renovacionExitosa) accessToken = 'token-2';
    return renovacionExitosa;
  }

  @override
  void alPerderSesion() => avisosDePerdida++;
}

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
  group('proveedorDeSesionProvider', () {
    test('lanza si nadie lo sobreescribió', () {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);

      // Un doble silencioso convertiría "ninguna petición lleva token" en un
      // 401 inexplicable a mitad de una carga.
      expect(
        () => contenedor.read(proveedorDeSesionProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('el mensaje dice dónde se cablea', () {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);

      expect(
        () => contenedor.read(proveedorDeSesionProvider),
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('bootstrap.dart'),
          ),
        ),
      );
    });
  });

  group('InterceptorSesion contra el contrato', () {
    late _SesionFalsa sesion;
    late Dio dio;

    setUp(() {
      sesion = _SesionFalsa();
      dio = Dio(BaseOptions(baseUrl: 'http://prueba.local/api/v1'));
      dio.interceptors.add(InterceptorSesion(sesion: sesion, dio: dio));
    });

    RequestOptions pedido(String ruta) =>
        RequestOptions(path: ruta, baseUrl: dio.options.baseUrl);

    test('agrega el bearer a una ruta común', () {
      final opciones = pedido('/servicios');
      dio.interceptors
          .whereType<InterceptorSesion>()
          .first
          .onRequest(opciones, RequestInterceptorHandler());

      expect(opciones.headers['Authorization'], 'Bearer token-1');
    });

    test('no toca las rutas de /auth', () {
      // Un 401 del login son credenciales incorrectas y uno del refresh es una
      // sesión muerta: en ambos casos renovar entraría en bucle.
      final opciones = pedido('/auth/login');
      dio.interceptors
          .whereType<InterceptorSesion>()
          .first
          .onRequest(opciones, RequestInterceptorHandler());

      expect(opciones.headers.containsKey('Authorization'), isFalse);
    });

    test('sin token no inventa un header vacío', () {
      sesion.accessToken = null;
      final opciones = pedido('/servicios');
      dio.interceptors
          .whereType<InterceptorSesion>()
          .first
          .onRequest(opciones, RequestInterceptorHandler());

      expect(opciones.headers.containsKey('Authorization'), isFalse);
    });

    test('las rutas exentas siguen siendo las de /auth', () {
      expect(InterceptorSesion.esRutaDeAuth('/auth/login'), isTrue);
      expect(InterceptorSesion.esRutaDeAuth('/auth/refresh'), isTrue);
      expect(InterceptorSesion.esRutaDeAuth('/censo-diario/estado'), isFalse);
      expect(InterceptorSesion.esRutaDeAuth('/reporteria/censo-mensual'), isFalse);
    });
  });

  group('dioProvider', () {
    test('se arma sin que ninguna feature participe', () {
      // Se sobreescriben los dos contratos del núcleo y el cliente HTTP queda
      // listo: ni `auth` ni ninguna otra feature entra en juego. Antes esto era
      // imposible — el Dio se construía dentro de `auth/presentation/`.
      final contenedor = ProviderContainer(
        overrides: [
          proveedorDeSesionProvider.overrideWithValue(_SesionFalsa()),
          configuracionProvider.overrideWithValue(const _ConfigDePrueba()),
        ],
      );
      addTearDown(contenedor.dispose);

      final dio = contenedor.read(dioProvider);
      expect(dio.options.baseUrl, 'http://ejemplo.local:3001/api/v1');
      expect(dio.interceptors.whereType<InterceptorSesion>(), hasLength(1));
    });
  });
}
