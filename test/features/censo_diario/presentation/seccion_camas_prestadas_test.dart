import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/widgets/seccion_camas_prestadas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const especialidades = [
    MapeoVaciado(entidadId: 'esp-cir', nombreVaciado: 'Cirugía'),
    MapeoVaciado(entidadId: 'esp-ped', nombreVaciado: 'Pediatría'),
  ];

  const camaCirugia = CamaPrestada(
    especialidadId: 'esp-cir',
    cantidad: 1,
    tipoIngreso: TipoIngresoCamaPrestada.directo,
  );

  Future<List<CamaPrestada>?> montar(
    WidgetTester tester, {
    List<CamaPrestada> camas = const [],
    List<MapeoVaciado> catalogo = especialidades,
    bool habilitado = true,
  }) async {
    List<CamaPrestada>? ultimoCambio;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SeccionCamasPrestadas(
                camas: camas,
                especialidades: catalogo,
                habilitado: habilitado,
                alCambiar: (nuevas) => ultimoCambio = nuevas,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ultimoCambio;
  }

  group('Estado colapsado', () {
    testWidgets('arranca cerrada y resume el contenido', (tester) async {
      await montar(tester, camas: const [camaCirugia]);

      expect(find.text('Camas prestadas'), findsOneWidget);
      expect(find.textContaining('1 cama(s)'), findsOneWidget);
      // Cerrada: el botón de agregar no está a la vista.
      expect(find.text('Agregar cama prestada'), findsNothing);
    });

    testWidgets('sin registros lo dice explícitamente', (tester) async {
      await montar(tester);

      expect(find.text('Sin registrar'), findsOneWidget);
    });

    testWidgets('al expandir aparece el detalle', (tester) async {
      await montar(tester, camas: const [camaCirugia]);

      await tester.tap(find.text('Camas prestadas'));
      await tester.pumpAndSettle();

      expect(find.text('Cirugía'), findsOneWidget);
      expect(find.text('Ingreso directo'), findsOneWidget);
      expect(find.text('Agregar cama prestada'), findsOneWidget);
    });
  });

  group('Sin especialidades mapeadas', () {
    testWidgets('explica por qué no se puede cargar', (tester) async {
      await montar(tester, catalogo: const []);

      await tester.tap(find.text('Camas prestadas'));
      await tester.pumpAndSettle();

      // Elegir una especialidad sin mapeo garantizaría un 400 al confirmar,
      // así que ni se ofrece: se explica el motivo.
      expect(find.textContaining('mapeo hacia el sistema central'),
          findsOneWidget);
      expect(find.text('Agregar cama prestada'), findsNothing);
    });
  });

  group('Alta', () {
    testWidgets('agrega una combinación y la notifica hacia arriba',
        (tester) async {
      List<CamaPrestada>? resultado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                SeccionCamasPrestadas(
                  camas: const [],
                  especialidades: especialidades,
                  alCambiar: (nuevas) => resultado = nuevas,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Camas prestadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar cama prestada'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elegir…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cirugía').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(resultado, hasLength(1));
      expect(resultado!.single.especialidadId, 'esp-cir');
      expect(resultado!.single.cantidad, 1);
      expect(
        resultado!.single.tipoIngreso,
        TipoIngresoCamaPrestada.directo,
      );
    });

    testWidgets('el selector excluye combinaciones ya usadas (V-04)',
        (tester) async {
      await montar(tester, camas: const [camaCirugia]);

      await tester.tap(find.text('Camas prestadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar cama prestada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir…'));
      await tester.pumpAndSettle();

      // Cirugía + DIRECTO ya está: no debe poder elegirse de nuevo, así el
      // duplicado que el backend rechaza ni siquiera se puede construir.
      expect(find.text('Pediatría').last, findsOneWidget);
      expect(
        tester.widgetList(find.text('Cirugía')).length,
        lessThan(2),
        reason: 'Cirugía no debería aparecer entre las opciones del menú',
      );
    });
  });

  group('Modo consulta', () {
    testWidgets('sin permiso de escritura no ofrece agregar ni quitar',
        (tester) async {
      await montar(tester, camas: const [camaCirugia], habilitado: false);

      await tester.tap(find.text('Camas prestadas'));
      await tester.pumpAndSettle();

      final boton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Agregar cama prestada'),
      );
      expect(boton.onPressed, isNull);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('Claves de unicidad en el dominio', () {
    test('la sección se apoya en clavesCamasPrestadasUsadas', () {
      final censo = CensoServicio(
        fecha: DateTime(2026, 7, 16),
        servicioId: 'srv-1',
        camasPrestadas: const [
          camaCirugia,
          CamaPrestada(
            especialidadId: 'esp-cir',
            cantidad: 2,
            tipoIngreso: TipoIngresoCamaPrestada.traslado,
          ),
        ],
      );

      // La misma especialidad con distinto tipo son dos claves distintas.
      expect(censo.clavesCamasPrestadasUsadas, {
        'esp-cir::DIRECTO',
        'esp-cir::TRASLADO',
      });
      expect(censo.clavesDuplicadasCamasPrestadas(), isEmpty);
    });
  });
}
