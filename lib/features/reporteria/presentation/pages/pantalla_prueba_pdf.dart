import 'dart:typed_data';

import 'package:app_movil/app/tema.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Verificación del toolchain de PDF — T-1 de SPEC-004.
///
/// No es un reporte: es la prueba de humo que decide si vale la pena escribir
/// uno. Se corre **antes** de invertir en el reporte real, porque los dos
/// riesgos que puede destapar invalidan trabajo hecho:
///
/// 1. **Que `printing` no compile.** Trae código nativo Android e iOS y puede
///    chocar con AGP 8.11.1 igual que `permission_handler` 13.x. Descubrirlo con
///    una pantalla de prueba cuesta minutos; descubrirlo con el reporte entero
///    escrito cuesta un día.
/// 2. **Que los caracteres no rendericen.** Las fuentes base del paquete `pdf`
///    cubren Latin-1. Los nombres de servicio llevan tilde y el resto de la app
///    usa el signo menos tipográfico `−` (U+2212), que **no** está en Latin-1.
///    Si sale como cuadrito, hay que empaquetar una fuente y eso cambia el peso
///    del APK y el tiempo de generación.
///
/// Por eso la muestra no dice "hola": trae exactamente los caracteres, los
/// colores y la forma de tabla que el reporte va a necesitar.
class PantallaPruebaPdf extends StatefulWidget {
  const PantallaPruebaPdf({super.key});

  @override
  State<PantallaPruebaPdf> createState() => _PantallaPruebaPdfState();
}

class _PantallaPruebaPdfState extends State<PantallaPruebaPdf> {
  String? _error;
  bool _ocupado = false;

  /// Mismo azul de marca que usa el PDF de la web (`COLOR_ENCABEZADO`, RGB
  /// 10/74/92). Si el impreso del móvil y el de la web se ven distintos, es acá.
  static const _azulMarca = PdfColor.fromInt(0xFF0A4A5C);
  static const _filaAlterna = PdfColor.fromInt(0xFFE7F3F5);

  /// Muestra con los caracteres que de verdad aparecen en el reporte.
  ///
  /// Los nombres van con tilde a propósito: son los del catálogo propio, no los
  /// de vaciado-admisión. Y el `−` de la última fila es el signo menos
  /// tipográfico que ya usa `PanelSaldoEsperado`.
  static const _encabezados = [
    'Período',
    'Medicina Interna',
    'Pediatría',
    'Neonatología',
    'Ginecología',
    'Total',
  ];

  static const _filas = [
    ['2026-07-16', '4', '2', '1', '3', '10'],
    ['2026-07-17', '5', '0', '2', '1', '8'],
    ['2026-07-18', '3', '1', '0', '2', '6'],
  ];

  Future<Uint8List> _construirPdf() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (contexto) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Sistema de Censo Hospitalario',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _azulMarca,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Prueba de toolchain · Ingresos por servicio',
              style: const pw.TextStyle(fontSize: 11, color: _azulMarca),
            ),
            pw.SizedBox(height: 12),
            _tabla(),
            pw.SizedBox(height: 16),
            // Estos son los caracteres que hay que mirar con lupa en el PDF.
            pw.Text(
              'Control de caracteres: á é í ó ú ñ Ñ ¿ ¡ Óbito · '
              'Aritmética 33 + 4 − 3 = 34',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'RESULTADO CONOCIDO (2026-08-04): las tildes, la ñ y el punto '
              'medio se imprimen. El signo menos «−» (U+2212) NO: las fuentes '
              'base cubren Latin-1 y ese carácter queda fuera. Se omite en '
              'silencio, sin cuadro. Por eso el reporte no lo usa.',
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _tabla() {
    pw.Widget celda(String texto, {required bool esEncabezado}) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            texto,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: esEncabezado ? pw.FontWeight.bold : null,
              color: esEncabezado ? PdfColors.white : null,
            ),
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _azulMarca),
          children: [
            for (final e in _encabezados) celda(e, esEncabezado: true),
          ],
        ),
        for (var i = 0; i < _filas.length; i++)
          pw.TableRow(
            decoration:
                i.isOdd ? const pw.BoxDecoration(color: _filaAlterna) : null,
            children: [
              for (final valor in _filas[i]) celda(valor, esEncabezado: false),
            ],
          ),
      ],
    );
  }

  Future<void> _ejecutar(Future<void> Function(Uint8List) accion) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });

    try {
      await accion(await _construirPdf());
    } on Object catch (e) {
      // Se atrapa todo a propósito: esta pantalla existe para ver el fallo, no
      // para ocultarlo. Un crash acá no diría qué salió mal.
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de PDF — T-1')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Qué hay que verificar',
            style: tema.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const _Punto(
            'La app compila con `pdf` y `printing`. Si llegaste a esta '
            'pantalla, eso ya está.',
          ),
          const _Punto(
            'La vista previa muestra la tabla con los colores de marca.',
          ),
          const _Punto(
            'Las tildes, la ñ y el signo menos «−» se ven bien, no como '
            'cuadros.',
          ),
          const _Punto(
            'Imprimir abre el diálogo del sistema y compartir abre la hoja de '
            'compartir.',
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Card(
              color: TemaApp.error.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: TemaApp.error),
                        const SizedBox(width: 10),
                        Text(
                          'Falló la generación',
                          style: tema.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: TemaApp.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _error!,
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _ocupado
                ? null
                : () => _ejecutar(
                      (bytes) =>
                          Printing.layoutPdf(onLayout: (_) async => bytes),
                    ),
            icon: const Icon(Icons.print),
            label: const Text('Vista previa e imprimir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _ocupado
                ? null
                : () => _ejecutar(
                      (bytes) => Printing.sharePdf(
                        bytes: bytes,
                        filename: 'prueba_censo.pdf',
                      ),
                    ),
            icon: const Icon(Icons.share),
            label: const Text('Compartir o guardar'),
          ),
          const SizedBox(height: 24),
          Text(
            'Esta pantalla es temporal: se elimina al cerrar T-5, cuando el '
            'reporte real la reemplace.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· '),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
