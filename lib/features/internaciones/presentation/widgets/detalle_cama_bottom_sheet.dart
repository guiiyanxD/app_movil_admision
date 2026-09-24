import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/presentation/pages/pantalla_detalle_internacion.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/estilos_cama.dart';
import 'package:app_movil/features/internaciones/presentation/pages/pantalla_mover_cama.dart';
import 'package:app_movil/features/internaciones/presentation/pages/revision_ingreso_hc2_page.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/bottom_sheet_cambiar_estado.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Hoja modal inferior para consultar los detalles completos de una cama e internación.
class DetalleCamaBottomSheet extends StatelessWidget {
  const DetalleCamaBottomSheet({
    required this.cama,
    super.key,
  });

  final CamaTablero cama;

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No registrada';
    try {
      final formato = DateFormat("d 'de' MMMM 'de' y, HH:mm", 'es');
      return formato.format(fecha);
    } on Object catch (_) {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estilo = EstiloCamaVisual.para(cama.estadoVisual);
    final dias = cama.diasInternado;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra de título de la cama ────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: estilo.colorPrincipal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bed,
                    color: estilo.colorPrincipal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cama ${cama.codigo}',
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cama.servicioNombre,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: estilo.colorPrincipal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estilo.icono,
                          size: 13, color: estilo.colorPrincipal,),
                      const SizedBox(width: 4),
                      Text(
                        estilo.etiqueta,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: estilo.colorPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Datos de la Especialidad ──────────────────────────────────
            _FilaDetalle(
              icono: Icons.medical_services_outlined,
              titulo: 'Especialidad nativa',
              valor: cama.especialidadNombre,
            ),

            // ── Datos de Internación (si está ocupada) ────────────────────
            if (cama.esOcupada) ...[
              const SizedBox(height: 12),
              _FilaDetalle(
                icono: Icons.person_outline,
                titulo: 'Paciente internado',
                valor: cama.pacienteNombre ?? 'Sin nombre registrado',
                resaltado: true,
              ),
              const SizedBox(height: 12),
              _FilaDetalle(
                icono: Icons.badge_outlined,
                titulo: 'Matrícula de asegurado',
                valor: (cama.matricula != null && cama.matricula!.isNotEmpty)
                    ? cama.matricula!
                    : 'No informada',
              ),
              const SizedBox(height: 12),
              _FilaDetalle(
                icono: Icons.calendar_today_outlined,
                titulo: 'Fecha de ingreso',
                valor: _formatearFecha(cama.fechaIngreso),
              ),
              const SizedBox(height: 12),
              _FilaDetalle(
                icono: Icons.schedule_outlined,
                titulo: 'Tiempo de internación',
                valor: dias == 0
                    ? 'Ingresó el día de hoy'
                    : '$dias día${dias == 1 ? '' : 's'} transcurridos',
              ),
              if (cama.esPrestada) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA21CAF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFA21CAF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 18,
                        color: Color(0xFFA21CAF),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cama prestada a otra especialidad de servicio.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFA21CAF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (cama.esCritica) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0392B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFC0392B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFC0392B),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Atención: Paciente crítico con $dias días de internación.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC0392B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              _FilaDetalle(
                icono: Icons.info_outline,
                titulo: 'Estado de la cama',
                valor: cama.motivoEstado != null && cama.motivoEstado!.isNotEmpty
                    ? cama.motivoEstado!
                    : (cama.estadoBase == 'disponible' 
                        ? 'Cama lista y disponible para ingreso.' 
                        : 'Cama ${cama.estadoBase}'),
              ),
            ],

            const SizedBox(height: 24),

            // ── Botones de Acción ─────────────────────────────────────────
            if (cama.esOcupada && cama.internacionId != null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PantallaMoverCama(
                          internacionId: cama.internacionId!,
                          servicioActualId: cama.servicioId,
                          esTrasladoInterno: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.transfer_within_a_station),
                  label: const Text('Traslado Interno'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PantallaMoverCama(
                          internacionId: cama.internacionId!,
                          servicioActualId: cama.servicioId,
                          esTrasladoInterno: false,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.move_up),
                  label: const Text('Traslado a otro Servicio'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar el bottom sheet
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PantallaDetalleInternacion(
                          internacionId: cama.internacionId!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver Detalle Completo'),
                ),
              ),
            ],
            if (!cama.esOcupada) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => BottomSheetCambiarEstadoCama(cama: cama),
                    );
                  },
                  icon: const Icon(Icons.build_circle),
                  label: const Text('Cambiar Estado (Bloqueos)'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  const _FilaDetalle({
    required this.icono,
    required this.titulo,
    required this.valor,
    this.resaltado = false,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icono,
          size: 18,
          color: esquema.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: tema.textTheme.labelSmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: resaltado ? FontWeight.bold : FontWeight.w500,
                  color: esquema.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
