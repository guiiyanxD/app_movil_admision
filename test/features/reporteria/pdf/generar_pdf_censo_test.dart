import 'dart:convert';
import 'dart:io';

import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';
import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';
import 'package:app_movil/features/reporteria/domain/usecases/armar_matriz_reporte.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:app_movil/features/reporteria/presentation/pdf/generar_pdf_censo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const armar = ArmarMatrizReporte();

  final rango = RangoFechas(
    inicio: DateTime(2026, 7),
    fin: DateTime(2026, 7, 31),
  );

  List<FilaReporteCenso> filas() => const [
        FilaReporteCenso(
          periodo: '2026-07-16',
          servicio: 'Medicina Interna',
          ingreso: 4,
          egreso: 3,
          total: 34,
        ),
        FilaReporteCenso(
          periodo: '2026-07-17',
          servicio: 'Pediatria',
          ingreso: 2,
          obito: 1,
          total: 12,
        ),
      ];

  Future<List<int>> generar({List<FilaReporteCenso>? datos}) {
    return GeneradorPdfCenso.construir(
      matrices: armar.todos(filas: datos ?? filas()),
      rango: rango,
      agrupacion: AgrupacionReporte.diaria,
      generadoEn: DateTime(2026, 8, 3, 9, 30),
    );
  }

  test('produce un PDF válido', () async {
    final bytes = await generar();

    expect(bytes.length, greaterThan(1000));
    expect(
      latin1.decode(bytes.sublist(0, 5)),
      '%PDF-',
      reason: 'debe empezar con la firma del formato',
    );
  });

  test('emite al menos una página por movimiento (CA-08)', () async {
    final bytes = await generar();
    final crudo = latin1.decode(bytes, allowInvalid: true);

    // `/Type /Page` (sin la `s` de `/Pages`) aparece una vez por hoja. Son ocho
    // movimientos, y pueden ser más hojas si una tabla se parte: lo que se
    // verifica es que ninguno se haya quedado afuera.
    final hojas = RegExp(r'/Type\s*/Page[^s]').allMatches(crudo).length;

    expect(hojas, greaterThanOrEqualTo(MovimientoReporte.values.length));
  });

  test('un período sin datos genera igual el documento completo', () async {
    // El PDF de un rango vacío no debería reventar: dice que no hay datos y
    // conserva sus ocho secciones, para que quede claro que se consultó.
    final bytes = await generar(datos: const []);

    expect(bytes.length, greaterThan(1000));
  });

  test('el nombre del archivo lleva el período consultado', () {
    expect(
      GeneradorPdfCenso.nombreArchivo(rango),
      'reporte_censo_2026-07-01_2026-07-31.pdf',
    );
  });

  test('ningún texto del PDF sale de Latin-1', () {
    // Las fuentes base del paquete `pdf` cubren Latin-1 y nada más. Un carácter
    // fuera de ese rango no revienta: el paquete lo avisa por consola —donde
    // nadie mira— y **lo omite del documento**. Así se fue una raya «—»
    // (U+2014) al encabezado del reporte, que salió con un hueco.
    //
    // Se revisa el código fuente y no el PDF generado porque el defecto está en
    // el literal, y acá el mensaje dice exactamente qué línea corregir. Las
    // tildes y la ñ sí entran en Latin-1: el problema son las comillas
    // tipográficas, las rayas largas y el signo menos «−» (U+2212).
    final fuente = File(
      'lib/features/reporteria/presentation/pdf/generar_pdf_censo.dart',
    );
    expect(fuente.existsSync(), isTrue, reason: 'correr desde la raíz');

    final culpables = <String>[];
    final lineas = fuente.readAsLinesSync();

    for (var i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      // Los comentarios no llegan al documento.
      if (linea.trimLeft().startsWith('//')) continue;

      final fuera = linea.runes.where((r) => r > 0xFF).toSet();
      if (fuera.isEmpty) continue;

      final simbolos = fuera
          .map((r) => '${String.fromCharCode(r)} (U+${r.toRadixString(16)})')
          .join(', ');
      culpables.add('  línea ${i + 1}: $simbolos');
    }

    expect(
      culpables,
      isEmpty,
      reason: 'Estos caracteres no se van a imprimir:\n${culpables.join('\n')}',
    );
  });

  group('Tamaño real — reproducción del cuelgue reportado', () {
    // Los tests de arriba usan dos filas y dos servicios, que es exactamente
    // por qué no detectaron nada: el documento real son 31 períodos × 12
    // servicios × 8 movimientos. Catorce columnas por hoja, ocho secciones.
    //
    // Los nombres son los de vaciado que devuelve el endpoint, con su largo
    // verdadero: el ancho de columna sale de repartir la hoja entre catorce, y
    // si un encabezado no entra el problema aparece acá y no en el dispositivo.
    const serviciosReales = [
      'Pabellon Quirurgico', 'Neonatologia', 'UCIM', 'UTI Adultos',
      'UTI Pediatria', 'Medicina Interna', 'Neuro Trauma', 'Pediatria',
      'Medicina Cirugia', 'Infectologia', 'Ginecologia', 'Onco Pediatria',
    ];

    List<FilaReporteCenso> mesCompleto() => [
          for (var dia = 1; dia <= 31; dia++)
            for (var i = 0; i < serviciosReales.length; i++)
              FilaReporteCenso(
                periodo: '2026-07-${dia.toString().padLeft(2, '0')}',
                servicio: serviciosReales[i],
                ingreso: (dia + i) % 7,
                ingresoTraslado: i % 3,
                egreso: (dia + i) % 5,
                egresoTraslado: i % 2,
                obito: dia % 11 == 0 ? 1 : 0,
                aislamiento: i % 4,
                bloqueada: i % 5,
                total: 20 + ((dia * (i + 1)) % 25),
              ),
        ];

    test(
      'un mes con detalle diario y doce servicios termina de generarse',
      () async {
        final bytes = await GeneradorPdfCenso.construir(
          matrices: armar.todos(
            filas: mesCompleto(),
            ordenConocido: serviciosReales,
          ),
          rango: rango,
          agrupacion: AgrupacionReporte.diaria,
          generadoEn: DateTime(2026, 8, 3, 9, 30),
        );

        expect(bytes.length, greaterThan(5000));
      },
      // Sin `timeout`, un `MultiPage` que no logra encajar una fila entra en un
      // ciclo de "agrego hoja, sigue sin entrar, agrego hoja" y el test se
      // cuelga igual que la app, sin decir por qué. Con esto falla y lo dice.
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'el resumen mensual de un año también termina',
      () async {
        final filas = [
          for (var mes = 1; mes <= 12; mes++)
            for (final servicio in serviciosReales)
              FilaReporteCenso(
                periodo: '2026-${mes.toString().padLeft(2, '0')}',
                servicio: servicio,
                ingreso: mes * 3,
                total: 600 + mes,
              ),
        ];

        final bytes = await GeneradorPdfCenso.construir(
          matrices: armar.todos(filas: filas, ordenConocido: serviciosReales),
          rango: RangoFechas(
            inicio: DateTime(2026),
            fin: DateTime(2026, 12, 31),
          ),
          agrupacion: AgrupacionReporte.mensual,
          generadoEn: DateTime(2026, 8, 3, 9, 30),
        );

        expect(bytes.length, greaterThan(5000));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
