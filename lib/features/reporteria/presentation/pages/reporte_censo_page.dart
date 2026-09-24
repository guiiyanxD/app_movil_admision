import 'dart:typed_data';

import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/error/banner_falla_api.dart';
import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/fecha_censo.dart';
import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:app_movil/features/reporteria/presentation/pdf/generar_pdf_censo.dart';
import 'package:app_movil/features/reporteria/presentation/providers/reporteria_providers.dart';
import 'package:app_movil/features/reporteria/presentation/widgets/controles_reporte.dart';
import 'package:app_movil/features/reporteria/presentation/widgets/tabla_reporte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Reporte de movimientos por servicio, con impresión y descarga en PDF.
///
/// Es **solo consulta**: no hay una sola acción de escritura acá, así que el rol
/// `lectura` la usa completa, incluido el PDF (CA-11). Por eso no aparece
/// `puedeEscribirProvider` en ningún lado de esta pantalla.
class ReporteCensoPage extends ConsumerStatefulWidget {
  const ReporteCensoPage({super.key});

  @override
  ConsumerState<ReporteCensoPage> createState() => _ReporteCensoPageState();
}

class _ReporteCensoPageState extends ConsumerState<ReporteCensoPage> {
  late RangoFechas _rango = _rangoInicial();
  AgrupacionReporte _agrupacion = AgrupacionReporte.diaria;
  MovimientoReporte _movimiento = MovimientoReporte.ingreso;

  bool _generandoPdf = false;

  /// Del primero del mes hasta ayer.
  ///
  /// Termina ayer y no hoy porque el censo del día en curso no se carga todavía
  /// (V-03), así que hoy siempre sería una fila en cero. Si hoy es día 1, el
  /// rango cae entero en el mes anterior, que es el período que de verdad se
  /// puede reportar.
  ///
  /// Usa `FechaCenso` del censo diario y no `DateTime.now()`: "ayer" tiene que
  /// significar lo mismo acá que en la pantalla de carga, y esa regla está en
  /// hora de Bolivia, no en la del dispositivo. Es una dependencia entre
  /// features y se acepta a conciencia: duplicar una regla de huso horario para
  /// evitarla sería peor negocio. Si aparece un tercer consumidor, el value
  /// object se muda a `core/`.
  static RangoFechas _rangoInicial() {
    final ayer = FechaCenso.hoyEnBolivia().subtract(const Duration(days: 1));
    return RangoFechas(inicio: DateTime(ayer.year, ayer.month), fin: ayer);
  }

  ConsultaReporte get _consulta => (rango: _rango, agrupacion: _agrupacion);

  @override
  Widget build(BuildContext context) {
    final reporteAsync = ref.watch(reporteProvider(_consulta));
    final reporte = reporteAsync.valueOrNull;
    final hayDatos = reporte != null && !reporte.matrices.first.estaVacia;

    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de censo')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reporteProvider(_consulta)),
        child: ListView(
          children: [
            const _NotaSoloConfirmadas(),
            ControlesReporte(
              rango: _rango,
              agrupacion: _agrupacion,
              movimiento: _movimiento,
              alCambiarRango: (nuevo) => setState(() => _rango = nuevo),
              alCambiarAgrupacion: (nueva) =>
                  setState(() => _agrupacion = nueva),
              alCambiarMovimiento: (nuevo) =>
                  setState(() => _movimiento = nuevo),
            ),
            _contenido(reporteAsync),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _BarraPdf(
        habilitado: hayDatos && !_generandoPdf,
        ocupado: _generandoPdf,
        alImprimir: () => _conPdf(
          (bytes) => Printing.layoutPdf(onLayout: (_) async => bytes),
        ),
        alCompartir: () => _conPdf(
          (bytes) => Printing.sharePdf(
            bytes: bytes,
            filename: GeneradorPdfCenso.nombreArchivo(_rango),
          ),
        ),
      ),
    );
  }

  Widget _contenido(AsyncValue<ReporteArmado> asincrono) {
    return switch (asincrono) {
      AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(12),
          child: error is Failure
              // Un fallo de red no deja la pantalla en blanco: dice qué pasó,
              // qué se puede hacer y ofrece reintentar sin volver atrás
              // (CA-12).
              ? BannerFallaApi(
                  falla: error,
                  alReintentar: () =>
                      ref.invalidate(reporteProvider(_consulta)),
                )
              : _ErrorGenerico(
                  error: error,
                  alReintentar: () =>
                      ref.invalidate(reporteProvider(_consulta)),
                ),
        ),
      AsyncData(:final value) when value.matrices.first.estaVacia =>
        const _SinDatos(),
      AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!value.ordenInstitucional) const _AvisoOrdenAlfabetico(),
            TablaReporte(matriz: value.matrices[_movimiento.index]),
          ],
        ),
      _ => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }

  /// Arma el PDF y se lo entrega al diálogo del sistema.
  ///
  /// Toma las matrices **ya calculadas** del provider: no vuelve a pedir nada
  /// ni a sumar por su cuenta, así que lo que se imprime es exactamente lo que
  /// está en pantalla (D-5).
  Future<void> _conPdf(Future<void> Function(Uint8List) accion) async {
    final reporte = ref.read(reporteProvider(_consulta)).valueOrNull;
    if (reporte == null) return;

    setState(() => _generandoPdf = true);

    try {
      final bytes = await GeneradorPdfCenso.construir(
        matrices: reporte.matrices,
        rango: _rango,
        agrupacion: _agrupacion,
      );
      await accion(bytes);
    } on Object catch (e) {
      // Se atrapa todo: el fallo puede venir del armado del documento o del
      // diálogo del sistema, y en ninguno de los dos casos tiene sentido
      // tumbar la pantalla con el reporte ya cargado.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }
}

/// La aclaración de D-4, siempre visible.
///
/// Va fija y no solo cuando el reporte viene vacío: en esta app se carga y se
/// reporta desde el mismo lugar, así que un operador que cargó cinco días sin
/// confirmarlos abriría el reporte esperando verlos. Decirlo solo al fallar
/// llega tarde.
class _NotaSoloConfirmadas extends StatelessWidget {
  const _NotaSoloConfirmadas();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Muestra únicamente las fechas ya confirmadas. Un día cargado '
                'y sin confirmar todavía no aparece acá.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: tema.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No hay fechas confirmadas en este período',
            style: tema.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // El riesgo más probable de este módulo es que el operador lea el
          // vacío como "se perdió mi carga". Se le dice qué falta y se le deja
          // el camino a mano (R-17).
          Text(
            'Si cargaste días de este período y no aparecen, todavía falta '
            'confirmarlos: el reporte lee el censo oficial, no la carga en '
            'curso.',
            style: tema.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.event_available),
            label: const Text('Ir a confirmar un día'),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que las columnas salieron alfabéticas y no en el orden de Admisión.
///
/// Pasa solo si el catálogo no se pudo leer. El reporte igual sirve —las cifras
/// son las mismas— pero comparar columna por columna contra el impreso de la
/// web o contra el formulario en papel daría diferencias, y esa confusión sin
/// explicación es peor que el problema.
class _AvisoOrdenAlfabetico extends StatelessWidget {
  const _AvisoOrdenAlfabetico();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: TemaApp.advertencia.withValues(alpha: 0.10),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.swap_horiz, color: TemaApp.advertencia, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No se pudo leer el catálogo de servicios: las columnas van '
                'en orden alfabético, no en el orden habitual. Las cifras no '
                'cambian.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorGenerico extends StatelessWidget {
  const _ErrorGenerico({required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: TemaApp.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: TemaApp.error),
                const SizedBox(width: 12),
                Expanded(child: Text('$error')),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imprimir y compartir, fijos al pie.
///
/// Van abajo y no en la barra superior porque son el final del recorrido: se
/// elige el período, se mira la tabla y recién entonces se imprime.
class _BarraPdf extends StatelessWidget {
  const _BarraPdf({
    required this.habilitado,
    required this.ocupado,
    required this.alImprimir,
    required this.alCompartir,
  });

  final bool habilitado;
  final bool ocupado;
  final VoidCallback alImprimir;
  final VoidCallback alCompartir;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: habilitado ? alImprimir : null,
                icon: ocupado
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: const Text('Imprimir'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: habilitado ? alCompartir : null,
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
