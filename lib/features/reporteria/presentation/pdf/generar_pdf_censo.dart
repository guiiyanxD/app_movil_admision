import 'dart:typed_data';

import 'package:app_movil/core/formato/momento_local.dart';
import 'package:app_movil/features/reporteria/domain/usecases/armar_matriz_reporte.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Genera el PDF del reporte de censo — T-5 de SPEC-004.
///
/// Réplica del impreso de la web (`apps/web/src/features/reporteria/pdf/
/// generarPdfCensoMensual.ts`): mismos colores, mismo encabezado, misma fila de
/// totales y una sección por movimiento. Lo que **no** se replica es el origen
/// de las columnas: la web las toma de su constante `SERVICIOS_CENSO` y acá
/// salen del catálogo (D-2). Si los dos impresos difieren en el orden, la que
/// está desactualizada es la constante de la web (R-15).
///
/// Recibe las matrices ya calculadas, no las filas crudas: la aritmética la
/// hace `ArmarMatrizReporte` una sola vez y de ahí salen tanto la tabla en
/// pantalla como este documento, así que no pueden discrepar (D-5).
abstract final class GeneradorPdfCenso {
  /// Azul de marca del sistema. Mismos RGB que `COLOR_ENCABEZADO` de la web.
  static const _azulEncabezado = PdfColor.fromInt(0xFF0A4A5C);

  /// `COLOR_TOTALES` de la web: la fila TOTAL va más clara que el encabezado
  /// para que se distinga del título de columnas al hojear la pila impresa.
  static const _azulTotales = PdfColor.fromInt(0xFF0E7490);

  static const _filaAlterna = PdfColor.fromInt(0xFFE7F3F5);
  static const _textoSecundario = PdfColor.fromInt(0xFF587277);

  /// Nombre sugerido al compartir o guardar. Mismo esquema que el de la web.
  static String nombreArchivo(RangoFechas rango) =>
      'reporte_censo_${rango.inicioComoParametro}_'
      '${rango.finComoParametro}.pdf';

  /// Construye el documento completo: una sección por movimiento.
  ///
  /// **Emite las ocho siempre**, sin importar cuál se esté viendo en pantalla.
  /// El PDF va al papel o a una computadora, no al teléfono, así que no hay
  /// motivo para degradarlo; y un reporte que cambia según desde dónde se
  /// generó es un reporte en el que no se puede confiar (D-3, CA-08).
  ///
  /// [generadoEn] es inyectable para que el pie sea reproducible en los tests.
  static Future<Uint8List> construir({
    required List<MatrizReporte> matrices,
    required RangoFechas rango,
    required AgrupacionReporte agrupacion,
    DateTime? generadoEn,
  }) async {
    final documento = pw.Document(
      title: 'Reporte de censo ${rango.inicioComoParametro} a '
          '${rango.finComoParametro}',
    );

    final sello = fechaHoraLocal(generadoEn ?? DateTime.now());

    for (final matriz in matrices) {
      documento.addPage(
        pw.MultiPage(
          // Carta vertical, como el impreso de la web. Los márgenes de 14 mm
          // son los mismos que usa `agregarEncabezado` como origen del texto.
          pageFormat: PdfPageFormat.letter.copyWith(
            marginLeft: 14 * PdfPageFormat.mm,
            marginRight: 14 * PdfPageFormat.mm,
            marginTop: 14 * PdfPageFormat.mm,
            marginBottom: 14 * PdfPageFormat.mm,
          ),
          // El encabezado se repite en cada hoja de la sección. La web no lo
          // hace, pero un mes de detalle diario ocupa más de una hoja y la
          // segunda quedaría sin decir de qué movimiento es.
          header: (contexto) => _encabezado(
            matriz: matriz,
            rango: rango,
            agrupacion: agrupacion,
          ),
          footer: (contexto) => _pie(contexto, sello),
          build: (contexto) => [_tabla(matriz)],
        ),
      );
    }

    return documento.save();
  }

  static pw.Widget _encabezado({
    required MatrizReporte matriz,
    required RangoFechas rango,
    required AgrupacionReporte agrupacion,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Sistema de Censo Hospitalario',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _azulEncabezado,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            // Las fuentes base del paquete `pdf` cubren Latin-1 y nada más.
            // Acá había una raya «—» (U+2014), que no está: el documento salía
            // con un hueco. Se usa el punto medio «·» (U+00B7), que sí está.
            // El test de este archivo impide que vuelva a colarse otro.
            'Reporte de censo · ${matriz.movimiento.etiqueta}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _azulEncabezado,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Período: ${rango.inicioComoParametro} al '
            '${rango.finComoParametro} · ${agrupacion.etiqueta}',
            style: const pw.TextStyle(fontSize: 8, color: _textoSecundario),
          ),
          pw.SizedBox(height: 2),
          // La misma aclaración que la pantalla. En papel importa más: la hoja
          // se archiva y meses después nadie recuerda que faltaba confirmar
          // tres días de ese período (D-4).
          pw.Text(
            'Incluye únicamente las fechas ya confirmadas en el censo oficial.',
            style: const pw.TextStyle(fontSize: 7, color: _textoSecundario),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pie(pw.Context contexto, String sello) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado el $sello',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              color: _textoSecundario,
            ),
          ),
          pw.Text(
            'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _textoSecundario),
          ),
        ],
      ),
    );
  }

  /// Tabla construida a mano y no con `TableHelper.fromTextArray`.
  ///
  /// El ayudante aplica un solo estilo a todo el cuerpo, y acá la última fila
  /// —la de totales— tiene que verse distinta del resto. Escribir las filas
  /// explícitamente cuesta unas líneas más y deja el control del ancho de
  /// columnas, que en catorce columnas sobre carta vertical es lo que decide si
  /// el reporte entra en la hoja o se corta.
  static pw.Widget _tabla(MatrizReporte matriz) {
    if (matriz.estaVacia) {
      return pw.Text(
        'Sin datos confirmados en este período.',
        style: const pw.TextStyle(fontSize: 9, color: _textoSecundario),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      // Anchos proporcionales, no intrínsecos: con doce servicios la tabla
      // tiene que repartirse el ancho disponible. La primera columna lleva una
      // fecha completa, así que pesa más que las de cifras.
      defaultColumnWidth: const pw.FlexColumnWidth(),
      columnWidths: const {0: pw.FlexColumnWidth(2.4)},
      children: [
        pw.TableRow(
          // Se repite al partirse la tabla: en la segunda hoja de un mes con
          // detalle diario, una columna de números sin su nombre de servicio
          // arriba no se puede leer.
          repeat: true,
          decoration: const pw.BoxDecoration(color: _azulEncabezado),
          children: [
            _celda('Período', esEncabezado: true, alaIzquierda: true),
            for (final servicio in matriz.servicios)
              _celda(servicio, esEncabezado: true),
            _celda('Total', esEncabezado: true),
          ],
        ),
        for (var i = 0; i < matriz.filas.length; i++)
          pw.TableRow(
            decoration: i.isOdd
                ? const pw.BoxDecoration(color: _filaAlterna)
                : null,
            children: [
              _celda(matriz.filas[i].periodo, alaIzquierda: true),
              for (final valor in matriz.filas[i].valores) _celda('$valor'),
              _celda('${matriz.filas[i].total}', enNegrita: true),
            ],
          ),
        // La fila de totales va dentro de la tabla y no como pie repetido: en
        // varias hojas, un pie se dibujaría en cada una y el total del período
        // aparecería tres veces, cada una parcial.
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _azulTotales),
          children: [
            _celda('TOTAL', esEncabezado: true, alaIzquierda: true),
            for (final valor in matriz.totalesPorServicio)
              _celda('$valor', esEncabezado: true),
            _celda('${matriz.totalGeneral}', esEncabezado: true),
          ],
        ),
      ],
    );
  }

  /// Celda de la tabla. `esEncabezado` implica fondo de color y texto blanco.
  static pw.Widget _celda(
    String texto, {
    bool esEncabezado = false,
    bool enNegrita = false,
    bool alaIzquierda = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(1.5),
      child: pw.Text(
        texto,
        // Las cifras se alinean a la derecha, que es como se recorre con el
        // dedo una columna de números en la hoja de censo. Los períodos, no.
        textAlign: alaIzquierda ? pw.TextAlign.left : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: esEncabezado || enNegrita ? pw.FontWeight.bold : null,
          color: esEncabezado ? PdfColors.white : null,
        ),
      ),
    );
  }
}
