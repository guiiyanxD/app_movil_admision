import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controles de configuración del reporte de censo: rango de fechas,
/// agrupación (diaria/mensual) y movimiento en pantalla.
class ControlesReporte extends StatelessWidget {
  const ControlesReporte({
    required this.rango,
    required this.agrupacion,
    required this.movimiento,
    required this.alCambiarRango,
    required this.alCambiarAgrupacion,
    required this.alCambiarMovimiento,
    super.key,
  });

  final RangoFechas rango;
  final AgrupacionReporte agrupacion;
  final MovimientoReporte movimiento;

  final ValueChanged<RangoFechas> alCambiarRango;
  final ValueChanged<AgrupacionReporte> alCambiarAgrupacion;
  final ValueChanged<MovimientoReporte> alCambiarMovimiento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));

    final rangoEsteMes = RangoFechas(
      inicio: DateTime(ayer.year, ayer.month),
      fin: ayer,
    );
    final primerDiaMesActual = DateTime(ayer.year, ayer.month);
    final ultimoDiaMesPasado =
        primerDiaMesActual.subtract(const Duration(days: 1));
    final rangoMesAnterior = RangoFechas(
      inicio: DateTime(ultimoDiaMesPasado.year, ultimoDiaMesPasado.month),
      fin: ultimoDiaMesPasado,
    );

    final esEsteMes = rango.inicio.year == rangoEsteMes.inicio.year &&
        rango.inicio.month == rangoEsteMes.inicio.month &&
        rango.inicio.day == rangoEsteMes.inicio.day &&
        rango.fin.year == rangoEsteMes.fin.year &&
        rango.fin.month == rangoEsteMes.fin.month &&
        rango.fin.day == rangoEsteMes.fin.day;

    final esMesAnterior = rango.inicio.year == rangoMesAnterior.inicio.year &&
        rango.inicio.month == rangoMesAnterior.inicio.month &&
        rango.inicio.day == rangoMesAnterior.inicio.day &&
        rango.fin.year == rangoMesAnterior.fin.year &&
        rango.fin.month == rangoMesAnterior.fin.month &&
        rango.fin.day == rangoMesAnterior.fin.day;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Título y Período Actual ──────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: tema.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.date_range,
                    size: 18,
                    color: tema.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Período del Reporte',
                        style: tema.textTheme.labelMedium?.copyWith(
                          color: tema.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_formatear(rango.inicio)} — ${_formatear(rango.fin)} (${rango.dias} días)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Abrir calendario',
                  icon: const Icon(Icons.edit_calendar, size: 20),
                  onPressed: () => _elegirRango(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Presets Rápidos de Rango ────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Este mes'),
                    selected: esEsteMes,
                    onSelected: (seleccionado) {
                      if (seleccionado) {
                        HapticFeedback.selectionClick();
                        alCambiarRango(rangoEsteMes);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Mes anterior'),
                    selected: esMesAnterior,
                    onSelected: (seleccionado) {
                      if (seleccionado) {
                        HapticFeedback.selectionClick();
                        alCambiarRango(rangoMesAnterior);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Rango personalizado...'),
                    onPressed: () => _elegirRango(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Agrupación (Diaria / Mensual) ───────────────────────────
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AgrupacionReporte>(
                segments: [
                  for (final opcion in AgrupacionReporte.values)
                    ButtonSegment(
                      value: opcion,
                      label: Text(opcion.etiqueta),
                      icon: Icon(
                        opcion == AgrupacionReporte.diaria
                            ? Icons.view_day_outlined
                            : Icons.calendar_view_month_outlined,
                      ),
                    ),
                ],
                selected: {agrupacion},
                onSelectionChanged: (seleccion) {
                  HapticFeedback.selectionClick();
                  alCambiarAgrupacion(seleccion.first);
                },
              ),
            ),

            if (agrupacion == AgrupacionReporte.mensual &&
                !rango.abarcaVariosMeses)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'El período abarca un solo mes: el resumen mostrará una única fila con el total consolidado.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ── Selector de Movimiento en Pantalla ───────────────────────
            DropdownButtonFormField<MovimientoReporte>(
              initialValue: movimiento,
              decoration: const InputDecoration(
                labelText: 'Movimiento visible en pantalla',
                helperText:
                    'El archivo PDF exportado incluye los ocho movimientos.',
                prefixIcon: Icon(Icons.filter_list),
              ),
              items: [
                for (final opcion in MovimientoReporte.values)
                  DropdownMenuItem(
                    value: opcion,
                    child: Text(opcion.etiqueta),
                  ),
              ],
              onChanged: (elegido) {
                if (elegido != null) {
                  HapticFeedback.selectionClick();
                  alCambiarMovimiento(elegido);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirRango(BuildContext context) async {
    HapticFeedback.selectionClick();
    final elegido = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: rango.inicio, end: rango.fin),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Período del reporte',
      saveText: 'Aplicar',
    );

    if (elegido == null) return;
    alCambiarRango(RangoFechas(inicio: elegido.start, fin: elegido.end));
  }

  static String _formatear(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}
