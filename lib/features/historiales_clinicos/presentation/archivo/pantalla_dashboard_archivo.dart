import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/archivo/pantalla_lotes_archivo.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/providers/historiales_providers.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/utils/traductor_estados.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PantallaDashboardArchivo extends ConsumerWidget {
  const PantallaDashboardArchivo({super.key});

  String _obtenerFechaFormateada() {
    final ahora = DateTime.now();
    try {
      final formato = DateFormat("EEEE, d 'de' MMMM 'de' y", 'es');
      final texto = formato.format(ahora);
      return texto[0].toUpperCase() + texto.substring(1);
    } catch (_) {
      const meses = [
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
      return '${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final sesion = ref.watch(sesionActivaProvider);
    final nombreUsuario = sesion?.usuario.nombreCompleto ?? 'Operador';

    ref.listen<AsyncValue<void>>(
      historialesControllerProvider,
      (previous, next) {
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${next.error}'),
                backgroundColor: Colors.red),
          );
        } else if (!next.isLoading && previous?.isLoading == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Operación exitosa'),
                backgroundColor: Colors.green),
          );
        }
      },
    );

    final lotesAsync = ref.watch(lotesDelDiaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo Clínico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(lotesDelDiaProvider),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: lotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (lotes) {
          final solicitudesPendientes = lotes
              .expand((lote) => lote.solicitudes)
              .where((sol) => sol.estado == 'REQUESTED')
              .toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tarjeta Hero (Resumen) ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.deepOrange.shade600,
                              Colors.deepOrange.shade900,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.folder_shared_outlined,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Archivo Central',
                                        style: tema.textTheme.labelSmall
                                            ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Hola, $nombreUsuario',
                              style: tema.textTheme.titleMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${solicitudesPendientes.length} Historias\nPendientes',
                              style: tema.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.8)),
                                const SizedBox(width: 6),
                                Text(
                                  _obtenerFechaFormateada(),
                                  style: tema.textTheme.bodySmall?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Acceso Directo a Lotes ──────────────────────────
                      Text(
                        'Gestión',
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: esquema.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: esquema.outlineVariant
                                  .withValues(alpha: 0.6)),
                        ),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => const PantallaLotesArchivo()));
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.history_edu_outlined,
                                      color: Colors.blue, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lotes y Recepciones',
                                        style:
                                            tema.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: esquema.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ver el historial completo de solicitudes y notificar a Admisión.',
                                        style: tema.textTheme.bodySmall
                                            ?.copyWith(
                                                color:
                                                    esquema.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: esquema.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Título Lista de Pendientes ──────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tareas Pendientes',
                            style: tema.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: esquema.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: solicitudesPendientes.isEmpty
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              solicitudesPendientes.isEmpty
                                  ? 'Al día'
                                  : '${solicitudesPendientes.length} por procesar',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: solicitudesPendientes.isEmpty
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── Lista de Historias Pendientes ──────────────────────────
              if (solicitudesPendientes.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green.shade300),
                          const SizedBox(height: 16),
                          Text(
                            '¡Excelente trabajo!',
                            style: tema.textTheme.titleMedium
                                ?.copyWith(color: esquema.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No hay historias pendientes en este momento.',
                            style: tema.textTheme.bodyMedium
                                ?.copyWith(color: esquema.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sol = solicitudesPendientes[index];
                      final paciente = sol.paciente;
                      final iniciales = (paciente != null &&
                              paciente.nombres.isNotEmpty)
                          ? '${paciente.nombres[0]}${paciente.apellidoPaterno.isNotEmpty ? paciente.apellidoPaterno[0] : ''}'
                          : '?';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: esquema.outlineVariant
                                    .withValues(alpha: 0.6)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: esquema.primaryContainer,
                                      foregroundColor:
                                          esquema.onPrimaryContainer,
                                      child: Text(iniciales.toUpperCase(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            paciente?.nombreCompleto ??
                                                'Desconocido',
                                            style: tema.textTheme.titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Icon(Icons.badge_outlined,
                                                  size: 14,
                                                  color:
                                                      esquema.onSurfaceVariant),
                                              const SizedBox(width: 4),
                                              Text(
                                                paciente?.matricula ?? 'S/N',
                                                style: tema.textTheme.bodySmall
                                                    ?.copyWith(
                                                        color: esquema
                                                            .onSurfaceVariant),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(Icons.bed_outlined,
                                                  size: 14,
                                                  color:
                                                      esquema.onSurfaceVariant),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Cama: ${sol.camaCodigo ?? 'S/N'}',
                                                style: tema.textTheme.bodySmall
                                                    ?.copyWith(
                                                        color: esquema
                                                            .onSurfaceVariant),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        TraductorEstados.traducir(sol.estado),
                                        style: tema.textTheme.labelSmall
                                            ?.copyWith(
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () async {
                                          HapticFeedback.lightImpact();
                                          await ref
                                              .read(
                                                  historialesControllerProvider
                                                      .notifier)
                                              .actualizarEstadoArchivo(
                                                  sol.id, 'READY');
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.green
                                              .withValues(alpha: 0.15),
                                          foregroundColor:
                                              Colors.green.shade800,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Listo',
                                            style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () async {
                                          HapticFeedback.lightImpact();
                                          await _mostrarDialogoPrestado(
                                              context, ref, sol.id);
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.orange
                                              .withValues(alpha: 0.15),
                                          foregroundColor:
                                              Colors.orange.shade800,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                        icon: const Icon(
                                            Icons.handshake_outlined,
                                            size: 18),
                                        label: const Text('Prestar',
                                            style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () async {
                                          HapticFeedback.lightImpact();
                                          await ref
                                              .read(
                                                  historialesControllerProvider
                                                      .notifier)
                                              .actualizarEstadoArchivo(
                                                  sol.id, 'NOT_FOUND');
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red
                                              .withValues(alpha: 0.15),
                                          foregroundColor: Colors.red.shade800,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text('No Enc.',
                                            style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: solicitudesPendientes.length,
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogoPrestado(
      BuildContext context, WidgetRef ref, String solicitudId) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como prestado'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'Nota (A quién se prestó, etc.)',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(historialesControllerProvider.notifier)
                  .actualizarEstadoArchivo(
                    solicitudId,
                    'LENT',
                    notasArchivo: controller.text,
                  );
              if (context.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
