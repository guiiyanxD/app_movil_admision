import 'package:app_movil/app/rutas.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardPage', () {
    const sesionMock = Sesion(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      usuario: UsuarioSesion(
        id: 'usr-1',
        nombreCompleto: 'Dra. María Gonzales',
        email: 'maria@censo.local',
        rol: RolUsuario.admin,
      ),
    );

    testWidgets('muestra el saludo con el nombre y rol del operador',
        (tester) async {
      var fueACenso = false;
      var fueAReportes = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sesionActivaProvider.overrideWithValue(sesionMock),
          ],
          child: MaterialApp(
            home: DashboardPage(
              onNavegarACenso: () => fueACenso = true,
              onNavegarAReportes: () => fueAReportes = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verifica saludo con el nombre y el rol
      expect(find.text('Dra. María Gonzales'), findsOneWidget);
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Caja Petrolera de Salud'), findsOneWidget);

      // Verifica las tarjetas principales
      expect(find.text('Censo Diario — EST-1'), findsOneWidget);
      expect(find.text('Internaciones y Tablero de Camas'), findsOneWidget);
      expect(find.text('Reportes y Estadísticas'), findsOneWidget);

      // Tocar en la tarjeta de Censo Diario dispara la navegación
      await tester.tap(find.text('Censo Diario — EST-1'));
      await tester.pump();
      expect(fueACenso, isTrue);

      // Tocar en la tarjeta de Reportes dispara la navegación
      await tester.tap(find.text('Reportes y Estadísticas'));
      await tester.pump();
      expect(fueAReportes, isTrue);
    });

    testWidgets('tocar la tarjeta de internaciones navega a la ruta de tablero',
        (tester) async {
      var fueATablero = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sesionActivaProvider.overrideWithValue(sesionMock),
          ],
          child: MaterialApp(
            routes: {
              Rutas.tableroCamas: (_) {
                fueATablero = true;
                return const Scaffold(body: Text('Pantalla Tablero'));
              },
            },
            home: DashboardPage(
              onNavegarACenso: () {},
              onNavegarAReportes: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Internaciones y Tablero de Camas'));
      await tester.pumpAndSettle();

      expect(fueATablero, isTrue);
      expect(find.text('Pantalla Tablero'), findsOneWidget);
    });
  });
}
