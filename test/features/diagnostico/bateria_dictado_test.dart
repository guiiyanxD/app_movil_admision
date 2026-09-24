import 'package:app_movil/features/diagnostico/domain/bateria_dictado.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/interpretar_dictado_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const interpretar = InterpretarDictadoCenso();
  final momento = DateTime(2026, 8, 1);

  IntentoDictado intentar(ItemBateria item, String transcripcion) =>
      IntentoDictado(
        item: item,
        transcripcion: transcripcion,
        confianza: 0.9,
        propuesta: interpretar.interpretar(transcripcion, ahora: momento),
        momento: momento,
      );

  group('La batería es consistente con el intérprete', () {
    test('cada frase, transcrita perfecta, produce lo esperado', () {
      // Si esto falla, el problema es del parser o de la batería, no del
      // motor de voz. Sirve para no salir a medir con una regla torcida.
      for (final item in BateriaDictado.items) {
        final intento = intentar(item, item.frase);

        expect(
          intento.exacto,
          isTrue,
          reason: '${item.id}: "${item.frase}" → '
              '${intento.interpretado}, esperado ${item.esperado}',
        );
      }
    });

    test('los identificadores son únicos', () {
      final ids = BateriaDictado.items.map((i) => i.id).toSet();
      expect(ids.length, BateriaDictado.items.length);
    });

    test('la batería cubre los 9 campos del EST-1', () {
      final cubiertos = <CampoCenso>{
        for (final item in BateriaDictado.items) ...item.esperado.keys,
      };
      expect(cubiertos.length, CampoCenso.values.length);
    });

    test('incluye el caso completo del censo fotografiado', () {
      final completo = BateriaDictado.porId('B-11');
      expect(completo.esperado[CampoCenso.total], 34);
      expect(completo.esperado.length, CampoCenso.values.length);
    });
  });

  group('Puntaje de un intento', () {
    final item = BateriaDictado.porId('B-09'); // 3 campos

    test('una transcripción perfecta puntúa exacto', () {
      final intento = intentar(item, item.frase);

      expect(intento.camposCorrectos, 3);
      expect(intento.camposDeMas, 0);
      expect(intento.exacto, isTrue);
    });

    test('un campo mal transcrito baja el puntaje sin anular el resto', () {
      final intento = intentar(
        item,
        'ingresos cuatro, egresos ocho, óbitos cero',
      );

      expect(intento.camposCorrectos, 2);
      expect(intento.exacto, isFalse);
    });

    test('un campo que no se reconoció cuenta como incorrecto', () {
      final intento = intentar(item, 'ingresos cuatro');

      expect(intento.camposCorrectos, 1);
      expect(intento.interpretado[CampoCenso.egreso], isNull);
      expect(intento.exacto, isFalse);
    });

    test('los campos inventados se cuentan aparte', () {
      final intento = intentar(
        item,
        'ingresos cuatro, egresos tres, óbitos cero, libres nueve',
      );

      // Un falso positivo es peor que un campo faltante: el operador ve un
      // número plausible en un campo que nunca dictó.
      expect(intento.camposCorrectos, 3);
      expect(intento.camposDeMas, 1);
      expect(intento.exacto, isFalse);
    });

    test('una transcripción vacía se registra como tal', () {
      final intento = intentar(item, '');

      expect(intento.huboTranscripcion, isFalse);
      expect(intento.camposCorrectos, 0);
    });
  });

  group('Resumen agregado', () {
    test('distingue precisión por campo de precisión por frase', () {
      final item = BateriaDictado.porId('B-09');
      final resumen = ResumenBateria([
        intentar(item, item.frase),
        intentar(item, 'ingresos cuatro, egresos ocho, óbitos cero'),
      ]);

      // 5 de 6 campos, pero solo 1 de 2 frases enteras. Al operador le importa
      // la segunda: no le sirve que 5 de 6 estén bien.
      expect(resumen.totalCamposCorrectos, 5);
      expect(resumen.totalCamposEsperados, 6);
      expect(resumen.precisionPorCampo, closeTo(0.833, 0.001));
      expect(resumen.precisionPorFrase, 0.5);
    });

    test('un resumen vacío no divide por cero', () {
      const resumen = ResumenBateria([]);

      expect(resumen.estaVacio, isTrue);
      expect(resumen.precisionPorCampo, 0);
      expect(resumen.precisionPorFrase, 0);
      expect(resumen.confianzaPromedio, 0);
    });

    test('el informe incluye lo dicho, lo entendido y el veredicto', () {
      final item = BateriaDictado.porId('B-04');
      final resumen = ResumenBateria([
        intentar(item, 'saldo treinta y cuatro'),
      ]);

      final texto = resumen.comoTexto(locale: 'es_419', dispositivo: 'Moto G');

      expect(texto, contains('es_419'));
      expect(texto, contains('Moto G'));
      expect(texto, contains('saldo treinta y cuatro'));
      expect(texto, contains('B-04'));
      expect(texto, contains('100.0%'));
    });

    test('el informe marca los campos inventados', () {
      final item = BateriaDictado.porId('B-01');
      final resumen = ResumenBateria([
        intentar(item, 'ingresos cuatro, libres nueve'),
      ]);

      expect(resumen.comoTexto(), contains('inventado'));
    });
  });
}
