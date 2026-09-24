import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/interpretar_dictado_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const interpretar = InterpretarDictadoCenso();
  final ahora = DateTime(2026, 7, 31, 23, 30);

  int? valorDe(PropuestaVoz propuesta, CampoCenso campo) {
    for (final c in propuesta.campos) {
      if (c.campo == campo) return c.valorPropuesto;
    }
    return null;
  }

  group('Dictado de un solo campo', () {
    test('interpreta "ingresos cuatro"', () {
      final p = interpretar.interpretar('ingresos cuatro', ahora: ahora);
      expect(p.campos, hasLength(1));
      expect(p.campos.single.campo, CampoCenso.ingreso);
      expect(p.campos.single.valorPropuesto, 4);
    });

    test('interpreta el saldo con número compuesto', () {
      final p = interpretar.interpretar('saldo treinta y cuatro', ahora: ahora);
      expect(valorDe(p, CampoCenso.total), 34);
    });

    test('reconoce sinónimos de óbito', () {
      for (final frase in [
        'obitos cero',
        'óbitos cero',
        'fallecidos cero',
        'defunciones cero',
      ]) {
        final p = interpretar.interpretar(frase, ahora: ahora);
        expect(valorDe(p, CampoCenso.obito), 0, reason: frase);
      }
    });
  });

  group('Dictado encadenado', () {
    test('interpreta los tres campos del ejemplo de la spec (CA-02)', () {
      final p = interpretar.interpretar(
        'ingresos cuatro, egresos tres, óbitos cero',
        ahora: ahora,
      );

      expect(p.campos, hasLength(3));
      expect(valorDe(p, CampoCenso.ingreso), 4);
      expect(valorDe(p, CampoCenso.egreso), 3);
      expect(valorDe(p, CampoCenso.obito), 0);
      expect(p.fragmentosNoReconocidos, isEmpty);
    });

    test('interpreta el bloque de camas', () {
      final p = interpretar.interpretar(
        'camas libres dos, bloqueadas una, aislamiento uno',
        ahora: ahora,
      );
      expect(valorDe(p, CampoCenso.libre), 2);
      expect(valorDe(p, CampoCenso.bloqueada), 1);
      expect(valorDe(p, CampoCenso.aislamiento), 1);
    });

    test('la conjunción "y" entre campos no rompe el parseo', () {
      final p = interpretar.interpretar(
        'ingreso por traslado uno y egreso por traslado cero',
        ahora: ahora,
      );
      expect(valorDe(p, CampoCenso.ingresoTraslado), 1);
      expect(valorDe(p, CampoCenso.egresoTraslado), 0);
    });
  });

  group('Alias largo gana sobre alias corto', () {
    test('"ingreso por traslado" no se interpreta como "ingreso"', () {
      final p = interpretar.interpretar(
        'ingreso por traslado dos',
        ahora: ahora,
      );
      expect(valorDe(p, CampoCenso.ingresoTraslado), 2);
      expect(valorDe(p, CampoCenso.ingreso), isNull);
    });

    test('"egresos por traslado" no se interpreta como "egresos"', () {
      final p = interpretar.interpretar(
        'egresos por traslado tres',
        ahora: ahora,
      );
      expect(valorDe(p, CampoCenso.egresoTraslado), 3);
      expect(valorDe(p, CampoCenso.egreso), isNull);
    });

    test('ambos campos en el mismo dictado no se pisan', () {
      final p = interpretar.interpretar(
        'ingresos cuatro ingresos por traslado uno',
        ahora: ahora,
      );
      expect(valorDe(p, CampoCenso.ingreso), 4);
      expect(valorDe(p, CampoCenso.ingresoTraslado), 1);
    });
  });

  group('El número va siempre después de la etiqueta', () {
    test('"un ingreso" no produce propuesta', () {
      final p = interpretar.interpretar('un ingreso', ahora: ahora);
      expect(p.campos, isEmpty);
      expect(p.fragmentosNoReconocidos, isNotEmpty);
    });

    test('"ingreso uno" sí produce propuesta', () {
      final p = interpretar.interpretar('ingreso uno', ahora: ahora);
      expect(valorDe(p, CampoCenso.ingreso), 1);
    });
  });

  group('Diff contra los valores actuales', () {
    test('registra el valor anterior de cada campo', () {
      final p = interpretar.interpretar(
        'egresos tres',
        valoresActuales: const {CampoCenso.egreso: 7},
        ahora: ahora,
      );
      final campo = p.campos.single;
      expect(campo.valorAnterior, 7);
      expect(campo.valorPropuesto, 3);
      expect(campo.esSobrescritura, isTrue);
    });

    test('un campo en cero no cuenta como sobrescritura', () {
      final p = interpretar.interpretar(
        'egresos tres',
        valoresActuales: const {CampoCenso.egreso: 0},
        ahora: ahora,
      );
      expect(p.campos.single.esSobrescritura, isFalse);
    });

    test('conserva el fragmento exacto que originó cada valor', () {
      final p = interpretar.interpretar(
        'saldo treinta y cuatro',
        ahora: ahora,
      );
      expect(p.campos.single.textoOrigen, 'saldo treinta y cuatro');
    });
  });

  group('Confianza baja', () {
    test('los campos llegan desmarcados por debajo del umbral', () {
      final p = interpretar.interpretar(
        'ingresos cuatro',
        confianza: 0.42,
        ahora: ahora,
      );
      expect(p.campos.single.confianzaBaja, isTrue);
      expect(p.campos.single.aceptado, isFalse);
      expect(p.aceptados, isEmpty);
      expect(p.tieneDudas, isTrue);
    });

    test('con confianza alta llegan marcados', () {
      final p = interpretar.interpretar(
        'ingresos cuatro',
        confianza: 0.95,
        ahora: ahora,
      );
      expect(p.campos.single.aceptado, isTrue);
      expect(p.aceptados, hasLength(1));
    });
  });

  group('Comandos de control', () {
    test('no generan valores', () {
      for (final frase in ['cancelar', 'borrar', 'repetir', 'listo']) {
        final p = interpretar.interpretar(frase, ahora: ahora);
        expect(p.esComando, isTrue, reason: frase);
        expect(p.campos, isEmpty, reason: frase);
      }
    });

    test('mapean al comando correcto', () {
      expect(
        interpretar.interpretar('cancelar', ahora: ahora).comando,
        ComandoVoz.cancelar,
      );
      expect(
        interpretar.interpretar('otra vez', ahora: ahora).comando,
        ComandoVoz.repetir,
      );
    });
  });

  group('Dictado parcialmente entendido', () {
    test('lista los fragmentos que no reconoció', () {
      final p = interpretar.interpretar(
        'ingresos cuatro y despues no se que dije',
        ahora: ahora,
      );
      expect(valorDe(p, CampoCenso.ingreso), 4);
      expect(p.fragmentosNoReconocidos, isNotEmpty);
      expect(p.tieneDudas, isTrue);
    });

    test('nunca se presenta como éxito total si hubo fragmentos sueltos', () {
      final p = interpretar.interpretar('ingresos cuatro blabla', ahora: ahora);
      expect(p.estaVacia, isFalse);
      expect(p.tieneDudas, isTrue);
    });
  });

  group('Robustez', () {
    test('transcripción vacía devuelve propuesta vacía, sin lanzar', () {
      for (final entrada in ['', '   ', '...']) {
        final p = interpretar.interpretar(entrada, ahora: ahora);
        expect(p.estaVacia, isTrue, reason: entrada);
        expect(p.esComando, isFalse);
      }
    });

    test('nunca lanza ante entrada arbitraria', () {
      const basura = [
        'aaa bbb ccc',
        '1234567',
        'ingresos ingresos ingresos',
        'y y y',
        'cuatro',
      ];
      for (final entrada in basura) {
        expect(
          () => interpretar.interpretar(entrada, ahora: ahora),
          returnsNormally,
          reason: entrada,
        );
      }
    });

    test('una etiqueta repetida deja una sola propuesta, la última', () {
      final p = interpretar.interpretar(
        'ingresos cuatro ingresos siete',
        ahora: ahora,
      );
      final delCampo =
          p.campos.where((c) => c.campo == CampoCenso.ingreso).toList();
      expect(delCampo, hasLength(1));
      expect(delCampo.single.valorPropuesto, 7);
    });
  });

  group('Dictado completo del censo fotografiado', () {
    test('cubre los 9 campos en una sola pasada', () {
      final p = interpretar.interpretar(
        'ingresos cuatro, ingreso por traslado cero, '
        'egresos tres, egreso por traslado cero, óbitos cero, '
        'aislamiento uno, bloqueadas una, libres dos, '
        'saldo treinta y cuatro',
        ahora: ahora,
      );

      expect(p.campos, hasLength(CampoCenso.values.length));
      expect(valorDe(p, CampoCenso.ingreso), 4);
      expect(valorDe(p, CampoCenso.ingresoTraslado), 0);
      expect(valorDe(p, CampoCenso.egreso), 3);
      expect(valorDe(p, CampoCenso.egresoTraslado), 0);
      expect(valorDe(p, CampoCenso.obito), 0);
      expect(valorDe(p, CampoCenso.aislamiento), 1);
      expect(valorDe(p, CampoCenso.bloqueada), 1);
      expect(valorDe(p, CampoCenso.libre), 2);
      expect(valorDe(p, CampoCenso.total), 34);
      expect(p.fragmentosNoReconocidos, isEmpty);
    });
  });
}
