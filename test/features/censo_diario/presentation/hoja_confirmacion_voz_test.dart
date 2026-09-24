import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/widgets/hoja_confirmacion_voz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PropuestaVoz propuesta({
    List<CampoPropuesto>? campos,
    List<String> noReconocidos = const [],
    String transcripcion = 'ingresos cuatro, egresos tres',
  }) =>
      PropuestaVoz(
        transcripcion: transcripcion,
        capturadaEn: DateTime(2026, 7, 31),
        fragmentosNoReconocidos: noReconocidos,
        campos: campos ??
            const [
              CampoPropuesto(
                campo: CampoCenso.ingreso,
                valorAnterior: 0,
                valorPropuesto: 4,
                textoOrigen: 'ingresos cuatro',
              ),
              CampoPropuesto(
                campo: CampoCenso.egreso,
                valorAnterior: 0,
                valorPropuesto: 3,
                textoOrigen: 'egresos tres',
              ),
            ],
      );

  Future<void> montar(
    WidgetTester tester,
    PropuestaVoz p, {
    VoidCallback? alAplicar,
    VoidCallback? alDescartar,
    void Function(CampoCenso, {required bool aceptado})? alAlternar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HojaConfirmacionVoz(
            propuesta: p,
            alAlternar: alAlternar ?? (_, {required aceptado}) {},
            alAplicar: alAplicar ?? () {},
            alDescartar: alDescartar ?? () {},
            alRepetir: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra siempre la transcripción literal', (tester) async {
    await montar(tester, propuesta());

    // El operador debe poder ver qué entendió el motor, no solo el resultado.
    expect(find.textContaining('ingresos cuatro, egresos tres'), findsWidgets);
  });

  testWidgets('deja claro que todavía no se guarda nada', (tester) async {
    await montar(tester, propuesta());

    expect(find.textContaining('Nada se guarda todavía'), findsOneWidget);
  });

  testWidgets('muestra el diff de cada campo', (tester) async {
    await montar(tester, propuesta());

    expect(find.text('Ingresos por admisión'), findsOneWidget);
    expect(find.text('Egresos por salida'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('destaca la sobrescritura de un valor ya cargado',
      (tester) async {
    await montar(
      tester,
      propuesta(
        campos: const [
          CampoPropuesto(
            campo: CampoCenso.ingreso,
            valorAnterior: 7,
            valorPropuesto: 4,
            textoOrigen: 'ingresos cuatro',
          ),
        ],
      ),
    );

    expect(
      find.textContaining('Reemplaza un valor que ya habías cargado'),
      findsOneWidget,
    );
  });

  testWidgets('la confianza baja llega desmarcada y avisa', (tester) async {
    await montar(
      tester,
      propuesta(
        campos: const [
          CampoPropuesto(
            campo: CampoCenso.ingreso,
            valorAnterior: 0,
            valorPropuesto: 4,
            confianza: 0.3,
            aceptado: false,
            textoOrigen: 'ingresos cuatro',
          ),
        ],
      ),
    );

    final casilla = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(casilla.value, isFalse);
    expect(find.textContaining('poco confiable'), findsOneWidget);
  });

  testWidgets('sin campos aceptados, aplicar está deshabilitado',
      (tester) async {
    await montar(
      tester,
      propuesta(
        campos: const [
          CampoPropuesto(
            campo: CampoCenso.ingreso,
            valorAnterior: 0,
            valorPropuesto: 4,
            aceptado: false,
            textoOrigen: 'ingresos cuatro',
          ),
        ],
      ),
    );

    expect(find.text('No hay campos seleccionados'), findsOneWidget);
    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'No hay campos seleccionados'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('lista los fragmentos que no reconoció', (tester) async {
    await montar(
      tester,
      propuesta(noReconocidos: const ['blabla', 'que dije']),
    );

    // Un dictado entendido a medias nunca se presenta como éxito total.
    expect(find.text('Esto no se pudo interpretar'), findsOneWidget);
    expect(find.textContaining('blabla'), findsOneWidget);
  });

  testWidgets('aplicar y descartar disparan sus acciones', (tester) async {
    var aplico = false;
    var descarto = false;

    await montar(
      tester,
      propuesta(),
      alAplicar: () => aplico = true,
      alDescartar: () => descarto = true,
    );

    await tester.tap(find.textContaining('Aplicar 2'));
    await tester.pump();
    expect(aplico, isTrue);

    await tester.tap(find.text('Descartar'));
    await tester.pump();
    expect(descarto, isTrue);
  });

  testWidgets('desmarcar un campo notifica hacia arriba', (tester) async {
    CampoCenso? alternado;
    bool? nuevoValor;

    await montar(
      tester,
      propuesta(),
      alAlternar: (campo, {required aceptado}) {
        alternado = campo;
        nuevoValor = aceptado;
      },
    );

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();

    expect(alternado, CampoCenso.ingreso);
    expect(nuevoValor, isFalse);
  });
}
