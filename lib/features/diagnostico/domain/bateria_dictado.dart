import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';

/// Una frase a dictar y lo que debería producir.
class ItemBateria {
  const ItemBateria({
    required this.id,
    required this.frase,
    required this.esperado,
    required this.prueba,
  });

  final String id;

  /// Lo que el operador tiene que decir, textual.
  final String frase;

  /// Campos y valores que el intérprete debería extraer.
  final Map<CampoCenso, int> esperado;

  /// Qué está midiendo este ítem. Sirve para leer el resultado después.
  final String prueba;
}

/// Batería de prueba del riesgo R-05: precisión del dictado de cifras en
/// español boliviano.
///
/// Está ordenada de lo más simple a lo más exigente, para que si la precisión
/// se derrumba se vea **dónde** se derrumba y no solo que bajó. Un motor puede
/// resolver "cuatro" y fallar sistemáticamente "treinta y cuatro"; esas dos
/// situaciones piden decisiones de producto distintas.
abstract final class BateriaDictado {
  static const List<ItemBateria> items = [
    ItemBateria(
      id: 'B-01',
      frase: 'ingresos cuatro',
      esperado: {CampoCenso.ingreso: 4},
      prueba: 'Un campo, unidad simple. El caso base.',
    ),
    ItemBateria(
      id: 'B-02',
      frase: 'óbitos cero',
      esperado: {CampoCenso.obito: 0},
      prueba: 'El cero, que algunos motores omiten o transcriben como "0".',
    ),
    ItemBateria(
      id: 'B-03',
      frase: 'camas libres dos',
      esperado: {CampoCenso.libre: 2},
      prueba: 'Alias de dos palabras: no debe partirse.',
    ),
    ItemBateria(
      id: 'B-04',
      frase: 'saldo treinta y cuatro',
      esperado: {CampoCenso.total: 34},
      prueba: 'Número compuesto con "y". El más frecuente en el EST-1.',
    ),
    ItemBateria(
      id: 'B-05',
      frase: 'bloqueadas dieciséis',
      esperado: {CampoCenso.bloqueada: 16},
      prueba: 'Token indivisible de la decena irregular (16-19).',
    ),
    ItemBateria(
      id: 'B-06',
      frase: 'aislamiento veintiuno',
      esperado: {CampoCenso.aislamiento: 21},
      prueba: 'Token indivisible de los veinte.',
    ),
    ItemBateria(
      id: 'B-07',
      frase: 'ingreso por traslado uno',
      esperado: {CampoCenso.ingresoTraslado: 1},
      prueba: 'Alias largo: no debe ganarle el alias corto "ingreso".',
    ),
    ItemBateria(
      id: 'B-08',
      frase: 'egreso por traslado cero',
      esperado: {CampoCenso.egresoTraslado: 0},
      prueba: 'Alias largo con cero.',
    ),
    ItemBateria(
      id: 'B-09',
      frase: 'ingresos cuatro, egresos tres, óbitos cero',
      esperado: {
        CampoCenso.ingreso: 4,
        CampoCenso.egreso: 3,
        CampoCenso.obito: 0,
      },
      prueba: 'Tres campos encadenados. El uso real esperado.',
    ),
    ItemBateria(
      id: 'B-10',
      frase: 'camas libres dos, bloqueadas una, aislamiento uno',
      esperado: {
        CampoCenso.libre: 2,
        CampoCenso.bloqueada: 1,
        CampoCenso.aislamiento: 1,
      },
      prueba: 'Bloque de camas completo, con femenino "una".',
    ),
    ItemBateria(
      id: 'B-11',
      frase: 'ingresos cuatro, ingreso por traslado cero, '
          'egresos tres, egreso por traslado cero, óbitos cero, '
          'aislamiento uno, bloqueadas una, libres dos, '
          'saldo treinta y cuatro',
      esperado: {
        CampoCenso.ingreso: 4,
        CampoCenso.ingresoTraslado: 0,
        CampoCenso.egreso: 3,
        CampoCenso.egresoTraslado: 0,
        CampoCenso.obito: 0,
        CampoCenso.aislamiento: 1,
        CampoCenso.bloqueada: 1,
        CampoCenso.libre: 2,
        CampoCenso.total: 34,
      },
      prueba: 'Censo completo del EST-1 del 16 de julio, en una sola pasada.',
    ),
  ];

  static ItemBateria porId(String id) =>
      items.firstWhere((i) => i.id == id);
}

/// Un intento de dictado sobre un ítem, con lo que devolvió el motor.
class IntentoDictado {
  const IntentoDictado({
    required this.item,
    required this.transcripcion,
    required this.confianza,
    required this.propuesta,
    required this.momento,
  });

  final ItemBateria item;

  /// Lo que entendió el motor, literal.
  final String transcripcion;

  final double confianza;

  /// Lo que el intérprete sacó de esa transcripción.
  final PropuestaVoz propuesta;

  final DateTime momento;

  int? _valorInterpretado(CampoCenso campo) {
    for (final c in propuesta.campos) {
      if (c.campo == campo) return c.valorPropuesto;
    }
    return null;
  }

  Map<CampoCenso, int?> get interpretado => {
        for (final campo in item.esperado.keys)
          campo: _valorInterpretado(campo),
      };

  int get camposEsperados => item.esperado.length;

  int get camposCorrectos {
    var correctos = 0;
    for (final entrada in item.esperado.entries) {
      if (_valorInterpretado(entrada.key) == entrada.value) correctos++;
    }
    return correctos;
  }

  /// Campos que el intérprete inventó: no estaban en lo esperado.
  ///
  /// Se cuentan aparte porque un falso positivo es **peor** que un campo que
  /// falta: el operador ve un número plausible en un campo que nunca dictó.
  int get camposDeMas =>
      propuesta.campos.where((c) => !item.esperado.containsKey(c.campo)).length;

  /// La frase se resolvió entera y sin agregados.
  bool get exacto => camposCorrectos == camposEsperados && camposDeMas == 0;

  bool get huboTranscripcion => transcripcion.trim().isNotEmpty;
}

/// Resultado agregado de una corrida.
class ResumenBateria {
  const ResumenBateria(this.intentos);

  final List<IntentoDictado> intentos;

  bool get estaVacio => intentos.isEmpty;

  int get totalCamposEsperados =>
      intentos.fold(0, (s, i) => s + i.camposEsperados);

  int get totalCamposCorrectos =>
      intentos.fold(0, (s, i) => s + i.camposCorrectos);

  int get totalCamposDeMas => intentos.fold(0, (s, i) => s + i.camposDeMas);

  int get frasesExactas => intentos.where((i) => i.exacto).length;

  /// Porcentaje de campos que cayeron con el valor correcto.
  double get precisionPorCampo => totalCamposEsperados == 0
      ? 0
      : totalCamposCorrectos / totalCamposEsperados;

  /// Porcentaje de frases resueltas enteras. Es la métrica más honesta: al
  /// operador no le sirve que 8 de 9 campos estén bien.
  double get precisionPorFrase =>
      intentos.isEmpty ? 0 : frasesExactas / intentos.length;

  double get confianzaPromedio => intentos.isEmpty
      ? 0
      : intentos.fold<double>(0, (s, i) => s + i.confianza) / intentos.length;

  /// Informe en texto plano, para pegar en el ADR o pasarle al cliente.
  String comoTexto({String? locale, String? dispositivo}) {
    final b = StringBuffer()
      ..writeln('SPIKE R-05 — Precisión del dictado de cifras')
      ..writeln('Fecha: ${DateTime.now().toIso8601String()}')
      ..writeln('Dispositivo: ${dispositivo ?? "sin especificar"}')
      ..writeln('Locale: ${locale ?? "desconocida"}')
      ..writeln('')
      ..writeln('RESUMEN')
      ..writeln('  Intentos: ${intentos.length}')
      ..writeln(
        '  Frases exactas: $frasesExactas/${intentos.length} '
        '(${_pct(precisionPorFrase)})',
      )
      ..writeln(
        '  Campos correctos: $totalCamposCorrectos/$totalCamposEsperados '
        '(${_pct(precisionPorCampo)})',
      )
      ..writeln('  Campos inventados: $totalCamposDeMas')
      ..writeln('  Confianza promedio: ${_pct(confianzaPromedio)}')
      ..writeln('')
      ..writeln('DETALLE');

    for (final intento in intentos) {
      b
        ..writeln('  [${intento.item.id}] ${intento.exacto ? "OK" : "FALLA"}')
        ..writeln('    Se dijo:    ${intento.item.frase}')
        ..writeln('    Se entendió: ${intento.transcripcion}')
        ..writeln('    Confianza:  ${_pct(intento.confianza)}');

      for (final entrada in intento.item.esperado.entries) {
        final obtenido = intento.interpretado[entrada.key];
        final marca = obtenido == entrada.value ? 'ok  ' : 'MAL ';
        b.writeln(
          '    $marca ${entrada.key.name}: esperado ${entrada.value}, '
          'obtenido ${obtenido ?? "nada"}',
        );
      }

      if (intento.camposDeMas > 0) {
        b.writeln('    ATENCIÓN: ${intento.camposDeMas} campo(s) inventado(s)');
      }
      b.writeln('');
    }

    return b.toString();
  }

  static String _pct(double valor) => '${(valor * 100).toStringAsFixed(1)}%';
}
