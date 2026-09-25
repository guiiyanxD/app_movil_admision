/// Convierte números dictados en español a enteros.
///
/// Alcance: 0–999, suficiente con margen para cualquier valor del EST-1
/// (el servicio más grande no llega a 100 camas).
///
/// Acepta **las dos formas** en que puede llegar la transcripción, porque el
/// motor de reconocimiento no es determinista: devuelve palabra ("treinta y
/// cuatro") o dígito ("34") según el motor del dispositivo y la locale.
///
/// El parser es tolerante a la ausencia de tildes: el texto se normaliza antes
/// de buscar, así que "dieciséis" y "dieciseis" son el mismo token.
///
/// En español, los números de 0 a 999 son puramente **aditivos** — no hay
/// estructura multiplicativa por debajo de mil ("doscientos" es un token
/// propio, no "dos" × "cientos"). Por eso el algoritmo suma por ranuras
/// (centena + decena + unidad) en lugar de multiplicar.
library;

class NumeroEsParser {
  const NumeroEsParser();

  static const Map<String, int> _centenas = {
    'cien': 100,
    'ciento': 100,
    'doscientos': 200,
    'doscientas': 200,
    'trescientos': 300,
    'trescientas': 300,
    'cuatrocientos': 400,
    'cuatrocientas': 400,
    'quinientos': 500,
    'quinientas': 500,
    'seiscientos': 600,
    'seiscientas': 600,
    'setecientos': 700,
    'setecientas': 700,
    'ochocientos': 800,
    'ochocientas': 800,
    'novecientos': 900,
    'novecientas': 900,
  };

  /// Decenas redondas que admiten una unidad detrás, unida por "y".
  static const Map<String, int> _decenas = {
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
  };

  /// 0–29: en español son tokens indivisibles ("veintiuno" no es "veinte uno").
  static const Map<String, int> _hastaVeintinueve = {
    'cero': 0,
    'uno': 1,
    'un': 1,
    'una': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintiun': 21,
    'veintiuna': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
  };

  /// Unidades 1–9, las únicas que pueden ir detrás de una decena redonda.
  static const Set<String> _unidadesTrasDecena = {
    'uno',
    'un',
    'una',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
  };

  /// `true` si el token puede formar parte de un número.
  static bool esTokenNumerico(String token) {
    final t = normalizar(token);
    return t == 'y' ||
        _centenas.containsKey(t) ||
        _decenas.containsKey(t) ||
        _hastaVeintinueve.containsKey(t) ||
        RegExp(r'^\d{1,3}$').hasMatch(t);
  }

  /// Minúsculas, sin tildes ni diéresis, sin puntuación, espacios colapsados.
  static String normalizar(String texto) {
    const conAcento = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sinAcento = 'aaaaeeeeiiiioooouuuun';

    final buffer = StringBuffer();
    for (final rune in texto.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final indice = conAcento.indexOf(char);
      buffer.write(indice >= 0 ? sinAcento[indice] : char);
    }

    return buffer
        .toString()
        .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Parsea el texto completo como un único número.
  ///
  /// Devuelve `null` si el texto no es un número válido de 0 a 999. Nunca
  /// lanza: un dictado incomprensible es un caso esperado, no un error.
  int? parsear(String texto) {
    final tokens = normalizar(texto).split(' ').where((t) => t.isNotEmpty);
    return parsearTokens(tokens.toList());
  }

  /// Igual que [parsear], pero sobre tokens ya normalizados.
  int? parsearTokens(List<String> tokens) {
    if (tokens.isEmpty) return null;

    // Forma en dígitos: un token numérico suelto.
    if (tokens.length == 1 && RegExp(r'^\d{1,3}$').hasMatch(tokens.first)) {
      return int.parse(tokens.first);
    }

    int? centena;
    int? decena;
    int? unidad;
    int? especial;
    var esperandoUnidadTrasY = false;

    for (final token in tokens) {
      if (token == 'y') {
        // La "y" solo es legítima entre decena redonda y unidad: "treinta y cuatro".
        if (decena == null || unidad != null) return null;
        esperandoUnidadTrasY = true;
        continue;
      }

      final valorCentena = _centenas[token];
      if (valorCentena != null) {
        // La centena va primero y una sola vez.
        if (centena != null || decena != null || especial != null) return null;
        if (esperandoUnidadTrasY) return null;
        centena = valorCentena;
        continue;
      }

      final valorDecena = _decenas[token];
      if (valorDecena != null) {
        if (decena != null || especial != null || unidad != null) return null;
        if (esperandoUnidadTrasY) return null;
        decena = valorDecena;
        continue;
      }

      final valorEspecial = _hastaVeintinueve[token];
      if (valorEspecial != null) {
        if (decena != null) {
          // Detrás de una decena redonda solo cabe una unidad 1–9.
          if (unidad != null) return null;
          if (!_unidadesTrasDecena.contains(token)) return null;
          unidad = valorEspecial;
          esperandoUnidadTrasY = false;
          continue;
        }
        if (especial != null) return null;
        if (esperandoUnidadTrasY) return null;
        especial = valorEspecial;
        continue;
      }

      // Token que no pertenece a ningún número.
      return null;
    }

    // "treinta y" quedó a medias.
    if (esperandoUnidadTrasY && unidad == null) return null;

    if (centena == null && decena == null && especial == null) return null;

    // Nota: "cien uno" no es español correcto ("ciento uno" sí), pero se acepta
    // igual. La intención es inequívoca y el operador confirma el resultado en
    // pantalla antes de que se guarde nada: acá conviene entender, no corregir.
    return (centena ?? 0) + (decena ?? 0) + (especial ?? 0) + (unidad ?? 0);
  }
}
