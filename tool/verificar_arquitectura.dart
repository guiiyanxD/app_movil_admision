// Verificador de límites de capa — T-1 de SPEC-005.
//
// Recorre los `import` de `lib/` y falla si alguno cruza un límite que
// ADR-0006 declara cerrado. Corre sin Flutter y sin que el proyecto compile:
// analiza texto, así que sirve incluso con el árbol en rojo.
//
//   dart run tool/verificar_arquitectura.dart
//   dart run tool/verificar_arquitectura.dart --detalle
//
// Sale con código 1 si hay infracciones. Está pensado para encadenarse en
// `bootstrap.ps1` junto a `flutter analyze`.
//
// Por qué existe: las reglas de arquitectura que solo viven en un documento
// duran hasta el primer apuro. Esta herramienta las vuelve verificables, y por
// eso es la primera tarea del refactor y no la última — es la que mide el
// progreso de todas las demás.

import 'dart:io';

void main(List<String> argumentos) {
  final detalle = argumentos.contains('--detalle');

  final raiz = Directory('lib');
  if (!raiz.existsSync()) {
    stderr.writeln(
      'No se encontró lib/. Ejecutá esto desde la raíz del proyecto.',
    );
    exit(2);
  }

  final archivos = raiz
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map(ArchivoAnalizado.leer)
      .toList()
    ..sort((a, b) => a.ruta.compareTo(b.ruta));

  final reglas = <Regla>[
    ReglaConfiguracionCentralizada(),
    ReglaSinUrlsLiterales(),
    ReglaPresentacionNoImportaData(),
    ReglaNucleoNoImportaFeatures(),
    ReglaDominioPuro(),
    ReglaFeatureSoloHaciaDominio(),
    ReglaSinCiclosEntreFeatures(),
  ];

  final resultados = [
    for (final regla in reglas) regla.evaluar(archivos),
  ];

  _imprimirReporte(resultados, archivos.length, detalle: detalle);

  final infracciones =
      resultados.fold<int>(0, (suma, r) => suma + r.infracciones.length);
  exit(infracciones == 0 ? 0 : 1);
}

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

/// Un archivo de `lib/` con sus imports internos ya extraídos.
class ArchivoAnalizado {
  ArchivoAnalizado({
    required this.ruta,
    required this.lineas,
    required this.importsInternos,
  });

  factory ArchivoAnalizado.leer(File archivo) {
    // Se normaliza a `/` para que el verificador dé el mismo resultado en
    // Windows y en el CI de Linux.
    final ruta = archivo.path.replaceAll(r'\', '/');
    final lineas = archivo.readAsLinesSync();

    final imports = <ImportInterno>[];
    for (var i = 0; i < lineas.length; i++) {
      final coincidencia = _patronImportInterno.firstMatch(lineas[i]);
      if (coincidencia != null) {
        imports.add(
          ImportInterno(destino: coincidencia.group(1)!, linea: i + 1),
        );
      }
    }

    return ArchivoAnalizado(
      ruta: ruta,
      lineas: lineas,
      importsInternos: imports,
    );
  }

  /// Ruta relativa con `/`, por ejemplo `lib/core/red/api_client.dart`.
  final String ruta;
  final List<String> lineas;

  /// Solo los `import`/`export` de `package:app_movil/...`.
  final List<ImportInterno> importsInternos;

  /// `core`, `features` o lo que cuelgue de `lib/`.
  String get raizDeCapa => _segmento(ruta, 1) ?? '';

  /// Nombre de la feature, o `null` si el archivo no vive en una.
  String? get feature =>
      raizDeCapa == 'features' ? _segmento(ruta, 2) : null;

  /// `domain`, `data` o `presentation`. `null` fuera de una feature.
  String? get capa => feature == null ? null : _segmento(ruta, 3);

  bool get esDeConfiguracion => ruta.startsWith('lib/core/config/');
}

class ImportInterno {
  const ImportInterno({required this.destino, required this.linea});

  /// Ruta relativa a `lib/`, por ejemplo `core/red/api_client.dart`.
  final String destino;
  final int linea;

  String? get feature =>
      destino.startsWith('features/') ? _segmento(destino, 1) : null;

  String? get capa => feature == null ? null : _segmento(destino, 2);
}

class Infraccion {
  const Infraccion({
    required this.archivo,
    required this.linea,
    required this.detalle,
  });

  final String archivo;
  final int linea;
  final String detalle;
}

class ResultadoRegla {
  const ResultadoRegla({
    required this.regla,
    required this.infracciones,
  });

  final Regla regla;
  final List<Infraccion> infracciones;

  bool get cumple => infracciones.isEmpty;
}

// ---------------------------------------------------------------------------
// Reglas
// ---------------------------------------------------------------------------

abstract class Regla {
  /// Identificador corto, para citarlo en la spec y en los mensajes.
  String get id;

  String get enunciado;

  /// Qué problema real evita. Se imprime cuando la regla falla: una regla que
  /// no explica su motivo termina desactivada por el primero que la moleste.
  String get porQue;

  /// Criterio de aceptación de SPEC-005 que cubre.
  String get criterio;

  List<Infraccion> revisar(List<ArchivoAnalizado> archivos);

  ResultadoRegla evaluar(List<ArchivoAnalizado> archivos) =>
      ResultadoRegla(regla: this, infracciones: revisar(archivos));
}

/// CA-01 — `String.fromEnvironment` solo en `core/config/`.
class ReglaConfiguracionCentralizada extends Regla {
  @override
  String get id => 'CONFIG-CENTRAL';

  @override
  String get enunciado =>
      'String.fromEnvironment solo puede aparecer en lib/core/config/';

  @override
  String get porQue =>
      'Leer el entorno desde cualquier archivo es cómo la URL base terminó '
      'dentro de un provider de presentación. Con una sola puerta de entrada, '
      'cambiar de servidor no obliga a saber en qué feature buscar.';

  @override
  String get criterio => 'CA-01';

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) => [
        for (final archivo in archivos)
          if (!archivo.esDeConfiguracion)
            for (var i = 0; i < archivo.lineas.length; i++)
              if (archivo.lineas[i].contains('String.fromEnvironment'))
                Infraccion(
                  archivo: archivo.ruta,
                  linea: i + 1,
                  detalle: 'lee el entorno fuera de core/config/',
                ),
      ];
}

/// CA-02 — ninguna URL literal fuera de `core/config/`.
class ReglaSinUrlsLiterales extends Regla {
  @override
  String get id => 'SIN-URLS';

  @override
  String get enunciado =>
      'No puede haber URLs ni IPs literales fuera de lib/core/config/';

  @override
  String get porQue =>
      'El repositorio llegó a tener tres URLs distintas y ninguna coincidía: '
      'el valor real era la IP de la LAN de una laptop. Un literal suelto es '
      'una cuarta verdad esperando.';

  @override
  String get criterio => 'CA-02';

  // Se ignoran los comentarios: un ejemplo de uso en documentación no es una
  // dependencia. Lo que importa es que ningún valor llegue a ejecutarse.
  static final _patronUrl = RegExp(r'''https?://[^\s'"`]+''');
  static final _patronIp = RegExp(r'\b\d{1,3}(\.\d{1,3}){3}\b');
  static final _patronComentario = RegExp(r'^\s*(///?|\*|/\*)');

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) {
    final infracciones = <Infraccion>[];

    for (final archivo in archivos) {
      if (archivo.esDeConfiguracion) continue;

      for (var i = 0; i < archivo.lineas.length; i++) {
        final linea = archivo.lineas[i];
        if (_patronComentario.hasMatch(linea)) continue;

        final url = _patronUrl.firstMatch(linea)?.group(0);
        final ip = _patronIp.firstMatch(linea)?.group(0);
        if (url == null && ip == null) continue;

        infracciones.add(
          Infraccion(
            archivo: archivo.ruta,
            linea: i + 1,
            detalle: 'literal de red en el código: ${url ?? ip}',
          ),
        );
      }
    }

    return infracciones;
  }
}

/// CA-04 — `presentation/` no importa `data/`.
class ReglaPresentacionNoImportaData extends Regla {
  @override
  String get id => 'PRES-NO-DATA';

  @override
  String get enunciado =>
      'presentation/ no puede importar data/, ni de su feature ni de otra';

  @override
  String get porQue =>
      'Si la presentación construye datasources y repositorios concretos, es '
      'ella la que decide contra qué infraestructura corre, y deja de poder '
      'probarse sin red. La construcción va en la raíz de composición.';

  @override
  String get criterio => 'CA-04';

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) => [
        for (final archivo in archivos)
          if (archivo.capa == 'presentation')
            for (final import in archivo.importsInternos)
              if (import.capa == 'data')
                Infraccion(
                  archivo: archivo.ruta,
                  linea: import.linea,
                  detalle: 'importa ${import.destino}',
                ),
      ];
}

/// CA-05 — `core/` no importa `features/`.
class ReglaNucleoNoImportaFeatures extends Regla {
  @override
  String get id => 'CORE-AISLADO';

  @override
  String get enunciado => 'core/ no puede importar nada de features/';

  @override
  String get porQue =>
      'El núcleo es lo que las features comparten. Si depende de una de ellas, '
      'deja de ser núcleo y esa feature se vuelve imposible de quitar.';

  @override
  String get criterio => 'CA-05';

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) => [
        for (final archivo in archivos)
          if (archivo.raizDeCapa == 'core')
            for (final import in archivo.importsInternos)
              if (import.feature != null)
                Infraccion(
                  archivo: archivo.ruta,
                  linea: import.linea,
                  detalle: 'el núcleo depende de ${import.destino}',
                ),
      ];
}

/// CA-07 — `domain/` sin Flutter ni plugins.
class ReglaDominioPuro extends Regla {
  @override
  String get id => 'DOMINIO-PURO';

  @override
  String get enunciado =>
      'domain/ no puede importar Flutter ni paquetes de infraestructura';

  @override
  String get porQue =>
      'Es lo que hace que las reglas del EST-1 se prueben sin emulador. Hoy se '
      'cumple en las cuatro features; esta regla existe para que siga así.';

  @override
  String get criterio => 'CA-07';

  static const _prohibidos = [
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:dio/',
    'package:pdf/',
    'package:printing/',
    'package:speech_to_text/',
    'package:flutter_secure_storage/',
    'package:permission_handler/',
    'package:go_router/',
  ];

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) {
    final infracciones = <Infraccion>[];

    for (final archivo in archivos) {
      if (archivo.capa != 'domain') continue;

      for (var i = 0; i < archivo.lineas.length; i++) {
        final linea = archivo.lineas[i];
        if (!linea.trimLeft().startsWith('import ')) continue;

        for (final prohibido in _prohibidos) {
          if (linea.contains(prohibido)) {
            infracciones.add(
              Infraccion(
                archivo: archivo.ruta,
                linea: i + 1,
                detalle: 'el dominio importa $prohibido',
              ),
            );
          }
        }
      }
    }

    return infracciones;
  }
}

/// Una feature solo puede depender del `domain/` de otra.
class ReglaFeatureSoloHaciaDominio extends Regla {
  @override
  String get id => 'FEATURE-A-DOMINIO';

  @override
  String get enunciado =>
      'Una feature solo puede importar el domain/ de otra feature';

  @override
  String get porQue =>
      'Depender del domain/ ajeno es compartir vocabulario. Depender de su '
      'presentation/ o su data/ es quedar atado a cómo esa feature está '
      'construida por dentro, y es de donde salen los ciclos.';

  @override
  String get criterio => 'CA-06';

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) => [
        for (final archivo in archivos)
          if (archivo.feature != null)
            for (final import in archivo.importsInternos)
              if (import.feature != null &&
                  import.feature != archivo.feature &&
                  import.capa != 'domain')
                Infraccion(
                  archivo: archivo.ruta,
                  linea: import.linea,
                  detalle: '${archivo.feature} → ${import.feature}/'
                      '${import.capa} (${import.destino})',
                ),
      ];
}

/// CA-06 — sin ciclos en el grafo de features.
class ReglaSinCiclosEntreFeatures extends Regla {
  @override
  String get id => 'SIN-CICLOS';

  @override
  String get enunciado => 'El grafo de dependencias entre features es acíclico';

  @override
  String get porQue =>
      'Con un ciclo, ninguna de las features involucradas se puede compilar, '
      'probar ni extraer por separado. Es el hallazgo que impide tratarlas '
      'como módulos independientes.';

  @override
  String get criterio => 'CA-06';

  @override
  List<Infraccion> revisar(List<ArchivoAnalizado> archivos) {
    // Grafo dirigido feature → feature, recordando dónde nace cada arista para
    // poder señalar un archivo concreto y no solo "hay un ciclo".
    final aristas = <String, Map<String, Infraccion>>{};

    for (final archivo in archivos) {
      final origen = archivo.feature;
      if (origen == null) continue;

      for (final import in archivo.importsInternos) {
        final destino = import.feature;
        if (destino == null || destino == origen) continue;

        aristas.putIfAbsent(origen, () => {}).putIfAbsent(
              destino,
              () => Infraccion(
                archivo: archivo.ruta,
                linea: import.linea,
                detalle: '$origen → $destino',
              ),
            );
      }
    }

    final ciclos = _buscarCiclos(aristas);

    return [
      for (final ciclo in ciclos)
        Infraccion(
          archivo: aristas[ciclo.first]![ciclo[1]]!.archivo,
          linea: aristas[ciclo.first]![ciclo[1]]!.linea,
          detalle: 'ciclo: ${[...ciclo, ciclo.first].join(' → ')}',
        ),
    ];
  }

  /// DFS con pila de recorrido. Devuelve cada ciclo una sola vez.
  static List<List<String>> _buscarCiclos(
    Map<String, Map<String, Infraccion>> aristas,
  ) {
    final ciclos = <List<String>>[];
    final vistos = <String>{};
    final enPila = <String>[];
    final firmas = <String>{};

    void visitar(String nodo) {
      final indice = enPila.indexOf(nodo);
      if (indice >= 0) {
        final ciclo = enPila.sublist(indice);
        // Se normaliza rotando al menor elemento: así A→B→A y B→A→B no se
        // reportan como dos hallazgos distintos.
        final menor = (ciclo.toList()..sort()).first;
        final desde = ciclo.indexOf(menor);
        final normalizado = [
          ...ciclo.sublist(desde),
          ...ciclo.sublist(0, desde),
        ];

        if (firmas.add(normalizado.join('>'))) ciclos.add(normalizado);
        return;
      }

      if (!vistos.add(nodo)) return;

      enPila.add(nodo);
      (aristas[nodo]?.keys ?? const <String>[]).forEach(visitar);
      enPila.removeLast();
    }

    (aristas.keys.toList()..sort()).forEach(visitar);

    return ciclos;
  }
}

// ---------------------------------------------------------------------------
// Reporte
// ---------------------------------------------------------------------------

void _imprimirReporte(
  List<ResultadoRegla> resultados,
  int totalArchivos, {
  required bool detalle,
}) {
  stdout
    ..writeln()
    ..writeln('Verificación de arquitectura — SPEC-005 / ADR-0006')
    ..writeln('$totalArchivos archivos analizados en lib/')
    ..writeln('-' * 68);

  for (final resultado in resultados) {
    final marca = resultado.cumple ? 'OK  ' : 'FALLA';
    final cantidad =
        resultado.cumple ? '' : '  (${resultado.infracciones.length})';

    stdout.writeln(
      '$marca ${resultado.regla.id.padRight(18)} '
      '${resultado.regla.criterio}$cantidad',
    );

    if (resultado.cumple) continue;

    stdout
      ..writeln('      ${resultado.regla.enunciado}')
      ..writeln('      ${resultado.regla.porQue}')
      ..writeln();

    // Sin --detalle se muestran cinco por regla: el objetivo es saber qué
    // falta, no llenar la consola con la misma infracción repetida.
    final visibles = detalle
        ? resultado.infracciones
        : resultado.infracciones.take(5).toList();

    for (final infraccion in visibles) {
      stdout.writeln(
        '      ${infraccion.archivo}:${infraccion.linea}  '
        '${infraccion.detalle}',
      );
    }

    final ocultas = resultado.infracciones.length - visibles.length;
    if (ocultas > 0) {
      stdout.writeln('      … y $ocultas más (usá --detalle)');
    }

    stdout.writeln();
  }

  final total =
      resultados.fold<int>(0, (suma, r) => suma + r.infracciones.length);
  final reglasEnFalla = resultados.where((r) => !r.cumple).length;

  stdout.writeln('-' * 68);

  if (total == 0) {
    stdout.writeln('Sin infracciones. Los límites de ADR-0006 se cumplen.');
    return;
  }

  stdout
    ..writeln(
      '$total infracción(es) en $reglasEnFalla de ${resultados.length} reglas.',
    )
    ..writeln(
      'Es el estado esperado antes de T-2: la herramienta mide el punto de '
      'partida del refactor.',
    );
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

/// Captura `import`/`export` de `package:app_movil/<ruta>`.
final _patronImportInterno =
    RegExp(r"""^\s*(?:import|export)\s+'package:app_movil/([^']+)'""");

/// Devuelve el segmento [indice] de una ruta separada por `/`, o `null`.
String? _segmento(String ruta, int indice) {
  final partes = ruta.split('/');
  return indice < partes.length ? partes[indice] : null;
}
