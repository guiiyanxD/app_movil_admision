import 'package:app_movil/core/voz/numero_es_parser.dart';
import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';

/// Convierte una transcripción de voz en una propuesta de valores.
///
/// Función pura: sin I/O, sin plugins, sin Flutter. Es el corazón del flujo de
/// voz y el más barato de testear.
///
/// Alcance cerrado: **solo cifras del resumen** (ADR-0005, D-6). No interpreta
/// nombres de paciente, H.C. ni códigos de pieza.
///
/// El resultado **nunca se aplica solo**. Alimenta la hoja de confirmación,
/// donde el operador decide campo por campo.
class InterpretarDictadoCenso {
  const InterpretarDictadoCenso({
    this.parser = const NumeroEsParser(),
  });

  final NumeroEsParser parser;

  /// Alias reconocidos por campo, ya normalizados (minúsculas, sin tildes).
  ///
  /// Se ordenan por cantidad de palabras descendente al buscar, para que
  /// "ingreso por traslado" gane sobre "ingreso".
  static const Map<CampoCenso, List<String>> alias = {
    CampoCenso.ingresoTraslado: [
      'ingresos por traslado',
      'ingreso por traslado',
      'traslado de entrada',
      'entra por traslado',
      'entradas por traslado',
    ],
    CampoCenso.egresoTraslado: [
      'egresos por traslado',
      'egreso por traslado',
      'traslado de salida',
      'sale por traslado',
      'salidas por traslado',
    ],
    CampoCenso.ingreso: [
      'ingresos por admision',
      'ingreso por admision',
      'ingreso directo',
      'ingresos directos',
      'admisiones',
      'ingresos',
      'ingreso',
    ],
    CampoCenso.egreso: [
      'egreso directo',
      'egresos directos',
      'egresos',
      'egreso',
      'altas',
      'salidas',
    ],
    CampoCenso.obito: [
      'obitos',
      'obito',
      'fallecidos',
      'fallecido',
      'defunciones',
      'muertes',
      'muerte',
    ],
    CampoCenso.aislamiento: [
      'camas en aislamiento',
      'aislamiento',
      'aisladas',
    ],
    CampoCenso.bloqueada: [
      'camas bloqueadas',
      'bloqueadas',
      'bloqueada',
    ],
    CampoCenso.libre: [
      'camas libres',
      'disponibles',
      'libres',
      'libre',
    ],
    CampoCenso.total: [
      'saldo a las veinticuatro horas',
      'saldo de pacientes',
      'pacientes al cierre',
      'saldo',
      'total',
    ],
  };

  /// Todos los alias aplanados y ordenados de más largo a más corto.
  static List<({CampoCenso campo, List<String> tokens})> get _aliasOrdenados {
    final lista = <({CampoCenso campo, List<String> tokens})>[];
    for (final entrada in alias.entries) {
      for (final texto in entrada.value) {
        lista.add((campo: entrada.key, tokens: texto.split(' ')));
      }
    }
    lista.sort((a, b) => b.tokens.length.compareTo(a.tokens.length));
    return lista;
  }

  /// Interpreta [transcripcion] contra los [valoresActuales] del formulario.
  PropuestaVoz interpretar(
    String transcripcion, {
    Map<CampoCenso, int> valoresActuales = const {},
    double confianza = 1,
    DateTime? ahora,
  }) {
    final capturadaEn = ahora ?? DateTime.now();
    final normalizada = NumeroEsParser.normalizar(transcripcion);

    if (normalizada.isEmpty) {
      return PropuestaVoz(
        transcripcion: transcripcion,
        capturadaEn: capturadaEn,
      );
    }

    final comando = _detectarComando(normalizada);
    if (comando != null) {
      return PropuestaVoz(
        transcripcion: transcripcion,
        capturadaEn: capturadaEn,
        comando: comando,
      );
    }

    final tokens = normalizada.split(' ');
    final aliasOrdenados = _aliasOrdenados;

    final campos = <CampoPropuesto>[];
    final noReconocidos = <String>[];
    final yaPropuestos = <CampoCenso>{};

    var i = 0;
    while (i < tokens.length) {
      final coincidencia = _buscarAlias(tokens, i, aliasOrdenados);

      if (coincidencia == null) {
        // Token suelto que no abre ningún campo.
        if (!NumeroEsParser.esTokenNumerico(tokens[i])) {
          noReconocidos.add(tokens[i]);
        }
        i++;
        continue;
      }

      final inicioNumero = i + coincidencia.longitud;
      final tokensNumero = <String>[];
      var j = inicioNumero;

      // El número va SIEMPRE después de la etiqueta. Se consume mientras los
      // tokens sean numéricos y no arranquen otro campo.
      while (j < tokens.length &&
          NumeroEsParser.esTokenNumerico(tokens[j]) &&
          _buscarAlias(tokens, j, aliasOrdenados) == null) {
        tokensNumero.add(tokens[j]);
        j++;
      }

      // El barrido puede haber arrastrado tokens numéricos que no forman parte
      // del número: la conjunción de "egresos tres y óbitos cero" queda pegada
      // al tres. Se prueba el fragmento completo y se va recortando por la
      // derecha hasta que parsee, en vez de descartar todo el campo.
      var usados = tokensNumero.length;
      int? valor;
      while (usados > 0) {
        valor = parser.parsearTokens(tokensNumero.sublist(0, usados));
        if (valor != null) break;
        usados--;
      }

      if (valor == null) {
        // Etiqueta sin número utilizable: "un ingreso" o "ingresos" a secas.
        noReconocidos.add(
          tokens.sublist(i, inicioNumero).join(' '),
        );
        i = inicioNumero;
        continue;
      }

      // Solo se consumen los tokens que efectivamente formaron el número.
      j = inicioNumero + usados;

      // Una etiqueta repetida en el mismo dictado: gana la última mención,
      // pero se avisa.
      if (yaPropuestos.contains(coincidencia.campo)) {
        campos.removeWhere((c) => c.campo == coincidencia.campo);
      }
      yaPropuestos.add(coincidencia.campo);

      campos.add(
        CampoPropuesto(
          campo: coincidencia.campo,
          valorAnterior: valoresActuales[coincidencia.campo],
          valorPropuesto: valor,
          confianza: confianza,
          textoOrigen: tokens.sublist(i, j).join(' '),
          // Un valor de confianza baja llega desmarcado: el operador tiene que
          // aceptarlo a propósito.
          aceptado: confianza >= CampoPropuesto.umbralConfianzaBaja,
        ),
      );

      i = j;
    }

    return PropuestaVoz(
      transcripcion: transcripcion,
      capturadaEn: capturadaEn,
      campos: campos,
      fragmentosNoReconocidos: noReconocidos,
    );
  }

  ComandoVoz? _detectarComando(String normalizada) {
    for (final comando in ComandoVoz.values) {
      for (final alias in comando.alias) {
        if (normalizada == alias) return comando;
      }
    }
    return null;
  }

  ({CampoCenso campo, int longitud})? _buscarAlias(
    List<String> tokens,
    int desde,
    List<({CampoCenso campo, List<String> tokens})> aliasOrdenados,
  ) {
    for (final candidato in aliasOrdenados) {
      final largo = candidato.tokens.length;
      if (desde + largo > tokens.length) continue;

      var coincide = true;
      for (var k = 0; k < largo; k++) {
        if (tokens[desde + k] != candidato.tokens[k]) {
          coincide = false;
          break;
        }
      }
      if (coincide) return (campo: candidato.campo, longitud: largo);
    }
    return null;
  }
}
