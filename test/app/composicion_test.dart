import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/core/red/red_providers.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/auth/presentation/login_page.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:app_movil/features/reporteria/presentation/providers/reporteria_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConfigDePrueba implements ConfiguracionApp {
  const _ConfigDePrueba();

  @override
  String get urlBaseApi => 'http://ejemplo.local:3001';

  @override
  String get nombreDestino => 'Ambiente de prueba';

  @override
  Duration get timeoutConexion => const Duration(seconds: 1);

  @override
  Duration get timeoutRespuesta => const Duration(seconds: 2);
}

class _AuthFalso implements AuthRepository {
  @override
  Future<Resultado<Sesion>> iniciarSesion({
    required String email,
    required String password,
  }) async =>
      const Fallo(FallaRed());

  @override
  Future<Sesion?> restaurar() async => null;

  @override
  Future<bool> refrescar() async => false;

  @override
  Future<void> cerrarSesion({bool avisarAlServidor = true}) async {}
}

void main() {
  group('Los contratos de infraestructura no traen implementación (H-6)', () {
    // Cada uno de estos providers se declara donde se consume y lo satisface
    // `bootstrap()`. Que lancen es deliberado: un valor por defecto convierte
    // un error de cableado en un fallo tardío y difuso.
    final contratos = <String, ProviderListenable<Object?>>{
      'configuracionProvider': configuracionProvider,
      'proveedorDeSesionProvider': proveedorDeSesionProvider,
      'authRepositoryProvider': authRepositoryProvider,
      'censoRepositoryProvider': censoRepositoryProvider,
      'reporteriaRepositoryProvider': reporteriaRepositoryProvider,
      'puedeEscribirProvider': puedeEscribirProvider,
    };

    for (final entrada in contratos.entries) {
      test('${entrada.key} lanza sin override', () {
        final contenedor = ProviderContainer();
        addTearDown(contenedor.dispose);

        expect(
          () => contenedor.read(entrada.value),
          throwsA(isA<UnimplementedError>()),
          reason: '${entrada.key} debería exigir inyección',
        );
      });

      test('${entrada.key} dice dónde se cablea', () {
        final contenedor = ProviderContainer();
        addTearDown(contenedor.dispose);

        expect(
          () => contenedor.read(entrada.value),
          throwsA(
            isA<UnimplementedError>().having(
              (e) => e.message,
              'message',
              contains('bootstrap.dart'),
            ),
          ),
        );
      });
    }
  });

  group('Montar una pantalla sin red ni almacenamiento (CA-09)', () {
    testWidgets('el login se dibuja solo con overrides', (tester) async {
      // Esto era imposible antes de T-5: la pantalla terminaba construyendo su
      // propio Dio contra la URL compilada y el Keystore del dispositivo. Ahora
      // se sustituye la infraestructura entera desde afuera.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configuracionProvider.overrideWithValue(const _ConfigDePrueba()),
            authRepositoryProvider.overrideWithValue(_AuthFalso()),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Servicio de Admisión'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('y muestra contra qué servidor está corriendo', (tester) async {
      // Con el backend moviéndose entre la red del hospital y la de oficinas,
      // "no conecta" tiene dos causas parecidas y diagnósticos distintos.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configuracionProvider.overrideWithValue(const _ConfigDePrueba()),
            authRepositoryProvider.overrideWithValue(_AuthFalso()),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Ambiente de prueba'),
        findsOneWidget,
      );
      expect(
        find.textContaining('http://ejemplo.local:3001'),
        findsOneWidget,
      );
    });
  });
}
