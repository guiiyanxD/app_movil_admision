import 'package:app_movil/core/voz/numero_es_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = NumeroEsParser();

  group('NumeroEsParser — forma en palabras', () {
    test('resuelve el cero', () {
      expect(parser.parsear('cero'), 0);
    });

    test('resuelve las tres formas de uno', () {
      expect(parser.parsear('uno'), 1);
      expect(parser.parsear('un'), 1);
      expect(parser.parsear('una'), 1);
    });

    test('resuelve los tokens indivisibles de 10 a 29', () {
      expect(parser.parsear('diez'), 10);
      expect(parser.parsear('quince'), 15);
      expect(parser.parsear('dieciséis'), 16);
      expect(parser.parsear('diecinueve'), 19);
      expect(parser.parsear('veinte'), 20);
      expect(parser.parsear('veintiuno'), 21);
      expect(parser.parsear('veintidós'), 22);
      expect(parser.parsear('veintinueve'), 29);
    });

    test('resuelve compuestos con "y"', () {
      expect(parser.parsear('treinta y cuatro'), 34);
      expect(parser.parsear('cuarenta y uno'), 41);
      expect(parser.parsear('noventa y nueve'), 99);
    });

    test('resuelve decenas redondas', () {
      expect(parser.parsear('treinta'), 30);
      expect(parser.parsear('noventa'), 90);
    });

    test('resuelve centenas', () {
      expect(parser.parsear('cien'), 100);
      expect(parser.parsear('ciento uno'), 101);
      expect(parser.parsear('doscientos treinta y cuatro'), 234);
      expect(parser.parsear('novecientos noventa y nueve'), 999);
    });
  });

  group('NumeroEsParser — tolerancia de entrada', () {
    test('ignora tildes ausentes', () {
      expect(parser.parsear('dieciseis'), 16);
      expect(parser.parsear('veintidos'), 22);
    });

    test('ignora mayúsculas, puntuación y espacios sobrantes', () {
      expect(parser.parsear('  Treinta Y Cuatro. '), 34);
      expect(parser.parsear('CIENTO UNO'), 101);
    });

    test('acepta la forma en dígitos que devuelven algunos motores STT', () {
      expect(parser.parsear('34'), 34);
      expect(parser.parsear('0'), 0);
      expect(parser.parsear('999'), 999);
    });
  });

  group('NumeroEsParser — rechazos', () {
    test('devuelve null ante texto que no es número', () {
      expect(parser.parsear('ingresos'), isNull);
      expect(parser.parsear(''), isNull);
      expect(parser.parsear('   '), isNull);
    });

    test('rechaza unidades repetidas', () {
      expect(parser.parsear('cuatro cuatro'), isNull);
      expect(parser.parsear('treinta treinta'), isNull);
    });

    test('rechaza una "y" suelta o a medias', () {
      expect(parser.parsear('treinta y'), isNull);
      expect(parser.parsear('y cuatro'), isNull);
    });

    test('rechaza una decena redonda seguida de un token 10–29', () {
      // "treinta quince" no significa nada en español.
      expect(parser.parsear('treinta quince'), isNull);
    });

    test('rechaza la centena en segunda posición', () {
      expect(parser.parsear('treinta cien'), isNull);
    });

    test('nunca lanza ante entrada arbitraria', () {
      for (final basura in ['%%%', 'abc def', '1000', '12345', 'ñ']) {
        expect(() => parser.parsear(basura), returnsNormally);
      }
    });
  });

  group('NumeroEsParser.esTokenNumerico', () {
    test('reconoce palabras de número y dígitos', () {
      for (final token in ['cero', 'treinta', 'y', 'cien', 'veintiuno', '7']) {
        expect(NumeroEsParser.esTokenNumerico(token), isTrue, reason: token);
      }
    });

    test('rechaza etiquetas de campo', () {
      for (final token in ['ingresos', 'egresos', 'obitos', 'libres']) {
        expect(NumeroEsParser.esTokenNumerico(token), isFalse, reason: token);
      }
    });
  });

  group('NumeroEsParser — valores reales del EST-1 fotografiado', () {
    test('reproduce las cifras del censo del 16 de julio', () {
      // Medicina Interna, piso 1°: 33 + 4 − 3 − 0 = 34.
      expect(parser.parsear('treinta y tres'), 33);
      expect(parser.parsear('cuatro'), 4);
      expect(parser.parsear('tres'), 3);
      expect(parser.parsear('cero'), 0);
      expect(parser.parsear('treinta y cuatro'), 34);
    });
  });
}
