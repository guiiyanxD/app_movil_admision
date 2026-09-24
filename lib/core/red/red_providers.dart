import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/core/red/api_client.dart';
import 'package:app_movil/core/red/interceptor_sesion.dart';
import 'package:app_movil/core/red/proveedor_de_sesion.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quién resuelve el token. **Lo inyecta la raíz de composición.**
///
/// Se declara acá sin implementación y `auth` lo satisface desde
/// `bootstrap()`. Es la inversión de dependencia de ADR-0006 D-3: el núcleo
/// enuncia lo que necesita y la feature lo provee, no al revés.
///
/// Lanza si nadie lo sobreescribió, por el mismo motivo que
/// `configuracionProvider`: un doble silencioso convertiría "la app no
/// autentica ninguna petición" en un 401 inexplicable a mitad de una carga.
final proveedorDeSesionProvider = Provider<ProveedorDeSesion>((ref) {
  throw UnimplementedError(
    'proveedorDeSesionProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});

/// Cliente HTTP de la aplicación: bearer y renovación automática ante un 401.
///
/// Vivía en `features/auth/presentation/auth_providers.dart`, así que
/// `censo_diario` y `reporteria` tenían que importar la capa de presentación
/// de otra feature para poder hablar con el API — una dependencia que no tiene
/// nada que ver con autenticarse (SPEC-005, H-3).
///
/// `bootstrap()` arma aparte un Dio propio para `/auth`, **sin** interceptor:
/// si las rutas de autenticación pasaran por acá, un 401 del refresh
/// dispararía otro refresh y entraría en bucle.
final dioProvider = Provider<Dio>((ref) {
  final dio = ApiClient.crear(ref.watch(configuracionProvider));

  dio.interceptors.add(
    InterceptorSesion(sesion: ref.watch(proveedorDeSesionProvider), dio: dio),
  );

  return dio;
});
