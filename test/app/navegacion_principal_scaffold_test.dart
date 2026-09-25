import 'package:app_movil/app/widgets/navegacion_principal_scaffold.dart';
import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';
import 'package:app_movil/features/reporteria/domain/repositories/reporteria_repository.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:app_movil/features/reporteria/presentation/providers/reporteria_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockCensoRepository extends Mock implements CensoDiarioRepository {}

class _MockReporteriaRepository extends Mock implements ReporteriaRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(
      RangoFechas(
        inicio: DateTime(2026),
        fin: DateTime(2026, 1, 31),
      ),
    );
    registerFallbackValue(AgrupacionReporte.diaria);
  });

  group('NavegacionPrincipalScaffold', () {
    const sesionMock = Sesion(
      accessToken: 'token',
      refreshToken: 'refresh',
      usuario: UsuarioSesion(
        id: 'usr-1',
        nombreCompleto: 'Lic. Carla Ramos',
        email: 'carla@censo.local',
        rol: RolUsuario.operador,
      ),
    );

    testWidgets('inicia en Inicio (Dashboard) y navega a Censo',
        (tester) async {
      final mockAuth = _MockAuthRepository();
      final mockCenso = _MockCensoRepository();
      final mockReporteria = _MockReporteriaRepository();

      when(mockCenso.obtenerServiciosActivos)
          .thenAnswer((_) async => const Exito(<Servicio>[]));
      when(() => mockCenso.obtenerProgresoDia(any())).thenAnswer(
        (_) async => Exito(
          ProgresoDia(
            fecha: DateTime(2026, 9, 15),
            servicios: const [],
          ),
        ),
      );
      when(
        () => mockReporteria.obtenerCensoMensual(
          rango: any(named: 'rango'),
          agrupacion: any(named: 'agrupacion'),
        ),
      ).thenAnswer((_) async => const Exito(<FilaReporteCenso>[]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configuracionProvider.overrideWithValue(const _ConfigDePrueba()),
            authRepositoryProvider.overrideWithValue(mockAuth),
            censoRepositoryProvider.overrideWithValue(mockCenso),
            reporteriaRepositoryProvider.overrideWithValue(mockReporteria),
            sesionActivaProvider.overrideWithValue(sesionMock),
            puedeEscribirProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: NavegacionPrincipalScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe estar visible el saludo en Inicio
      expect(find.text('Lic. Carla Ramos'), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Censo'), findsOneWidget);
      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Cuenta'), findsOneWidget);

      // Cambiar a la pestaña Censo mediante la barra inferior
      await tester.tap(find.text('Censo'));
      await tester.pumpAndSettle();

      // Debe verse el Censo Diario EST-1
      expect(find.text('Censo Diario — EST-1'), findsOneWidget);

      // Regresar a Inicio
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Lic. Carla Ramos'), findsOneWidget);

      // Probar navegación mediante la tarjeta de Censo en el Dashboard
      await tester.tap(find.text('Censo Diario — EST-1'));
      await tester.pumpAndSettle();
      expect(find.text('Censo Diario — EST-1'), findsOneWidget);
    });
  });
}
