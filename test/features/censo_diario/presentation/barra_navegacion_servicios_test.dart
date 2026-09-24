import 'package:app_movil/features/censo_diario/presentation/widgets/barra_navegacion_servicios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Hoy a las 18:14 en hora local, expresado en UTC como llega del servidor.
  // Se construye desde el día en curso porque la barra usa el reloj real: así
  // el caso "guardado hoy" se rinde como `HH:mm` pelado, sin depender de la
  // zona horaria de la máquina que corra la suite.
  final hoy = DateTime.now();
  final guardadoEn = DateTime(hoy.year, hoy.month, hoy.day, 18, 14).toUtc();

  Future<void> montar(
    WidgetTester tester, {
    required bool hayCambiosSinGuardar,
    DateTime? cuando,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraNavegacionServicios(
            indice: 2,
            total: 13,
            guardando: false,
            hayCambiosSinGuardar: hayCambiosSinGuardar,
            guardadoEn: cuando,
            alAnterior: () {},
            alSiguiente: () {},
            alGuardar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CA-09 — estado de guardado junto al contador', () {
    testWidgets('con trabajo pendiente dice "Sin guardar"', (tester) async {
      await montar(tester, hayCambiosSinGuardar: true);

      expect(find.text('Servicio 3 de 13'), findsOneWidget);
      expect(find.text('Sin guardar'), findsOneWidget);
      expect(find.textContaining('Guardado'), findsNothing);
      // Ícono además del texto: ningún estado se comunica solo por color.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('sin pendientes muestra la hora local del último guardado',
        (tester) async {
      await montar(tester, hayCambiosSinGuardar: false, cuando: guardadoEn);

      expect(find.text('Servicio 3 de 13'), findsOneWidget);
      expect(find.text('Guardado 18:14'), findsOneWidget);
      expect(find.text('Sin guardar'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // El instante llega en UTC. Mostrarlo sin convertir haría dudar al
      // operador de un dato correcto (D-5). El guardia existe porque en una
      // máquina en UTC ambos casos son indistinguibles.
      if (guardadoEn.hour != 18) {
        final horaUtc = guardadoEn.hour.toString().padLeft(2, '0');
        expect(find.textContaining('$horaUtc:14'), findsNothing);
      }
    });

    testWidgets('un guardado previo no tapa el trabajo sin guardar',
        (tester) async {
      await montar(tester, hayCambiosSinGuardar: true, cuando: guardadoEn);

      // Lo urgente es que hay algo que se puede perder, no que alguna vez se
      // guardó.
      expect(find.text('Sin guardar'), findsOneWidget);
      expect(find.text('Guardado 18:14'), findsNothing);
    });

    testWidgets('un formulario intacto y nunca guardado no dice nada',
        (tester) async {
      await montar(tester, hayCambiosSinGuardar: false);

      // No hay trabajo que pueda perderse: avisar acá sería gritar sin motivo.
      expect(find.text('Servicio 3 de 13'), findsOneWidget);
      expect(find.text('Sin guardar'), findsNothing);
      expect(find.textContaining('Guardado'), findsNothing);
    });
  });
}
