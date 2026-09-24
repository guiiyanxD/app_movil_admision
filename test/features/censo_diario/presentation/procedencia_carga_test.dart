import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/presentation/widgets/procedencia_carga.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fecha = DateTime(2026, 7, 16);

  // El instante literal del contrato (SPEC-003 §2): en Bolivia son las 18:14.
  final enUtc = DateTime.utc(2026, 8, 1, 22, 14, 3);

  CargaGuardada carga({
    String? creadoPor = 'Ana Rojas',
    DateTime? actualizadoEn,
  }) =>
      CargaGuardada(
        censo: CensoServicio(fecha: fecha, servicioId: 'srv-1', total: 34),
        servicioNombre: 'Medicina Interna',
        actualizadoEn: actualizadoEn,
        creadoPorNombre: creadoPor,
      );

  // `HH:mm` del instante en hora local, calculado sin pasar por el código bajo
  // prueba, para que la aserción no se valide contra sí misma.
  String hhmm(DateTime instante) {
    final local = instante.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> montar(WidgetTester tester, Widget hijo) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: hijo)));
    await tester.pumpAndSettle();
  }

  group('CA-08 — línea de procedencia', () {
    testWidgets('muestra quién cargó y la hora local, no la del servidor',
        (tester) async {
      await montar(
        tester,
        LineaProcedencia(
          carga: carga(actualizadoEn: enUtc),
          // Mismo día que la carga: así el texto no depende de cuándo corra
          // la suite.
          ahora: enUtc.toLocal(),
        ),
      );

      expect(
        find.text('Cargado por Ana Rojas · ${hhmm(enUtc)}'),
        findsOneWidget,
      );

      // Mostrar la hora del servidor como si fuera la del hospital haría dudar
      // al operador de un dato que está bien. El guardia existe porque en una
      // máquina configurada en UTC ambos casos son indistinguibles: ahí esta
      // aserción no probaría nada y sería ruido.
      if (enUtc.toLocal().hour != enUtc.hour) {
        expect(find.textContaining('22:14'), findsNothing);
      }
    });

    testWidgets('la carga de ayer se nombra en vez de fecharse',
        (tester) async {
      await montar(
        tester,
        LineaProcedencia(
          carga: carga(actualizadoEn: enUtc),
          ahora: enUtc.toLocal().add(const Duration(days: 1)),
        ),
      );

      expect(
        find.text('Cargado por Ana Rojas · ayer ${hhmm(enUtc)}'),
        findsOneWidget,
      );
    });

    testWidgets('una carga de otro día muestra también la fecha',
        (tester) async {
      await montar(
        tester,
        LineaProcedencia(
          carga: carga(actualizadoEn: enUtc),
          ahora: enUtc.toLocal().add(const Duration(days: 7)),
        ),
      );

      // Un "18:14" a secas sobre algo cargado la semana pasada se leería como
      // si hubiera pasado hace un rato.
      final local = enUtc.toLocal();
      final dia = local.day.toString().padLeft(2, '0');
      final mes = local.month.toString().padLeft(2, '0');
      expect(
        find.text('Cargado por Ana Rojas · $dia/$mes ${hhmm(enUtc)}'),
        findsOneWidget,
      );
    });
  });

  group('Metadatos ausentes', () {
    testWidgets('sin quién cargó, muestra igual el cuándo', (tester) async {
      await montar(
        tester,
        LineaProcedencia(
          carga: carga(creadoPor: null, actualizadoEn: enUtc),
          ahora: enUtc.toLocal(),
        ),
      );

      expect(find.text('Cargado ${hhmm(enUtc)}'), findsOneWidget);
    });

    testWidgets('sin cuándo, muestra igual quién cargó', (tester) async {
      await montar(tester, LineaProcedencia(carga: carga()));

      expect(find.text('Cargado por Ana Rojas'), findsOneWidget);
    });

    testWidgets('sin ninguno de los dos, no revienta y dice lo que sabe',
        (tester) async {
      // Son opcionales en el contrato a propósito: que el backend deje de
      // mandarlos no puede impedir editar el censo ni tapar que el servicio
      // ya venía cargado.
      await montar(tester, LineaProcedencia(carga: carga(creadoPor: null)));

      expect(find.text('Estos valores ya estaban guardados'), findsOneWidget);
    });
  });

  group('CA-07 — aviso de lectura fallida', () {
    testWidgets('dice que abrió en cero y que guardar reemplazaría',
        (tester) async {
      await montar(tester, const AvisoLecturaFallida());

      expect(find.text('No se pudo leer lo guardado'), findsOneWidget);
      expect(find.textContaining('abrió en cero'), findsOneWidget);
      expect(find.textContaining('reemplazaría'), findsOneWidget);
      // Ícono además del texto: ningún estado se comunica solo por color.
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
