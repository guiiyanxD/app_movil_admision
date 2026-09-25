import 'package:app_movil/features/historiales_clinicos/presentation/providers/historiales_providers.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/utils/traductor_estados.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class PantallaGestionLote extends ConsumerWidget {
  const PantallaGestionLote({required this.loteId, super.key});

  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text('Gestión de Lote'),
      ),
      body: lotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (lotes) {
          final lote = lotes.firstWhere((l) => l.id == loteId);
          final pendientes =
              lote.solicitudes.where((s) => s.estado == 'REQUESTED').length;
          final puedeNotificar = pendientes == 0 && lote.estado != 'NOTIFIED';

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: lote.solicitudes.length,
                  itemBuilder: (context, index) {
                    final sol = lote.solicitudes[index];
                    final paciente = sol.paciente;
                    final iniciales = (paciente != null &&
                            paciente.nombres.isNotEmpty)
                        ? '${paciente.nombres[0]}${paciente.apellidoPaterno.isNotEmpty ? paciente.apellidoPaterno[0] : ''}'
                        : '?';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Text(iniciales.toUpperCase()),
                              ),
                              title: Text(
                                  paciente?.nombreCompleto ?? 'Desconocido'),
                              subtitle: Text(
                                  'Cama: ${sol.camaCodigo ?? 'S/N'} • Matrícula: ${paciente?.matricula ?? 'S/N'}\nEstado: ${TraductorEstados.traducir(sol.estado)}'),
                            ),
                            if (sol.estado == 'REQUESTED' ||
                                sol.estado == 'NOT_FOUND' ||
                                sol.estado == 'LENT' ||
                                sol.estado == 'READY') ...[
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
                                      onPressed: sol.estado == 'READY'
                                          ? null
                                          : () async {
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
                                        foregroundColor: Colors.green.shade800,
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
                                      onPressed: sol.estado == 'LENT'
                                          ? null
                                          : () async {
                                              await _mostrarDialogoPrestado(
                                                  context, ref, sol.id);
                                            },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.orange
                                            .withValues(alpha: 0.15),
                                        foregroundColor: Colors.orange.shade800,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      icon: const Icon(Icons.handshake_outlined,
                                          size: 18),
                                      label: const Text('Prestar',
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: sol.estado == 'NOT_FOUND'
                                          ? null
                                          : () async {
                                              await ref
                                                  .read(
                                                      historialesControllerProvider
                                                          .notifier)
                                                  .actualizarEstadoArchivo(
                                                      sol.id, 'NOT_FOUND');
                                            },
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Colors.red.withValues(alpha: 0.15),
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (lote.estado != 'NOTIFIED')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: FilledButton(
                    onPressed: puedeNotificar
                        ? () async {
                            await ref
                                .read(historialesControllerProvider.notifier)
                                .notificarLote(lote.id);
                            if (context.mounted) {
                              final texto =
                                  'Tus historias clinicas solicitadas en el lote ${lote.id.substring(0, 5).toUpperCase()} estan listas para ser recogidas';
                              final uri = Uri.parse(
                                  'whatsapp://send?text=${Uri.encodeComponent(texto)}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('No se pudo abrir WhatsApp.')),
                                  );
                                }
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          }
                        : null,
                    child: const Text('Notificar a Admisión'),
                  ),
                ),
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
              labelText: 'Nota (A quién se prestó, etc.)'),
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
