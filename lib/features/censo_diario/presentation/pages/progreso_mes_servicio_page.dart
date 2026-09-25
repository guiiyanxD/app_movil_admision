import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/censo_servicio_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vista mensual de un servicio: permite recorrer y cargar los 30 o 31 días
/// del mes día por día para ese único servicio físico.
class ProgresoMesServicioPage extends ConsumerStatefulWidget {
  const ProgresoMesServicioPage({
    required this.servicio,
    required this.anho,
    required this.mes,
    super.key,
  });

  final Servicio servicio;
  final int anho;
  final int mes;

  @override
  ConsumerState<ProgresoMesServicioPage> createState() =>
      _ProgresoMesServicioPageState();
}

class _ProgresoMesServicioPageState
    extends ConsumerState<ProgresoMesServicioPage> {
  static const _nombresMeses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const _nombresDiasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  late final List<DateTime> _todosLosDias;
  late final List<DateTime> _diasCargables;

  @override
  void initState() {
    super.initState();
    final totalDias = DateUtils.getDaysInMonth(widget.anho, widget.mes);
    _todosLosDias = List.generate(
      totalDias,
      (i) => DateTime.utc(widget.anho, widget.mes, i + 1),
    );

    final ahora = DateTime.now();
    final hoyUtc = DateTime.utc(ahora.year, ahora.month, ahora.day);

    // Solo se permite cargar días pasados (no hoy ni futuros por regla V-01)
    _diasCargables = _todosLosDias.where((d) => d.isBefore(hoyUtc)).toList();
  }

  void _abrirDia(int indiceEnCargables) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CensoServicioFormPage.porDias(
          servicio: widget.servicio,
          fechas: _diasCargables.isNotEmpty ? _diasCargables : _todosLosDias,
          indiceInicial: indiceEnCargables,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombreMes = _nombresMeses[widget.mes - 1];
    final ahora = DateTime.now();
    final hoyUtc = DateTime.utc(ahora.year, ahora.month, ahora.day);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.servicio.nombre),
            Text(
              '$nombreMes de ${widget.anho}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // Hero Card: Resumen del Servicio y Planilla Mensual
          Card(
            elevation: 0,
            color: tema.colorScheme.primaryContainer.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: tema.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PLANILLA MENSUAL',
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: tema.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_todosLosDias.length} días en el mes',
                        style: tema.textTheme.labelMedium?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.servicio.nombre,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transcribí la hoja física de este servicio renglón por renglón. '
                    'Las flechas y el swipe horizontal avanzan automáticamente de día en día.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        _diasCargables.isNotEmpty ? () => _abrirDia(0) : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _diasCargables.isNotEmpty
                          ? 'Comenzar Carga desde Día 1 (1 Tap)'
                          : 'Mes en curso: sin días cerrados todavía',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'DÍAS DEL MES (${_todosLosDias.length})',
            style: tema.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: tema.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Lista de Días del Mes
          ..._todosLosDias.map((fecha) {
            final esFuturo = !fecha.isBefore(hoyUtc);
            final indiceEnCargables = _diasCargables.indexOf(fecha);
            final diaSemana = _nombresDiasSemana[fecha.weekday - 1];
            final diaStr = fecha.day.toString().padLeft(2, '0');
            final mesStr = fecha.month.toString().padLeft(2, '0');

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 0,
                color: esFuturo
                    ? tema.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3)
                    : tema.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: esFuturo
                          ? tema.colorScheme.surfaceContainerHighest
                          : tema.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${fecha.day}',
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: esFuturo
                            ? tema.colorScheme.onSurfaceVariant
                            : tema.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    '$diaSemana $diaStr/$mesStr',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: esFuturo
                          ? tema.colorScheme.onSurfaceVariant
                          : tema.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    esFuturo
                        ? 'Día en curso / futuro (bloqueado)'
                        : 'Tocar para editar censo de este día',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: esFuturo
                          ? tema.colorScheme.outline
                          : tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: esFuturo
                      ? Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: tema.colorScheme.outline,
                        )
                      : Icon(
                          Icons.chevron_right,
                          color: tema.colorScheme.primary,
                        ),
                  onTap: esFuturo || indiceEnCargables == -1
                      ? null
                      : () => _abrirDia(indiceEnCargables),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
