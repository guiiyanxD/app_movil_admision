import 'package:app_movil/features/historiales_clinicos/presentation/providers/historiales_providers.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/utils/traductor_estados.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PantallaRecepcionHistoriales extends ConsumerWidget {
  const PantallaRecepcionHistoriales({super.key, required this.loteId});

  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = ref.watch(lotesDelDiaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recepción de Lote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(lotesDelDiaProvider),
          )
        ],
      ),
      body: lotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (lotes) {
          // Filtrar los lotes que Archivo ya gestionó (NOTIFIED) o que tienen solicitudes en estado READY o DISCREPANCY, etc.
          // Para esta pantalla, nos interesan las solicitudes que Archivo marcó como READY, NOT_FOUND, LENT
          // que necesitan ser recepcionadas o validadas.
          final lote = lotes.firstWhere((l) => l.id == loteId, orElse: () => throw Exception('Lote no encontrado'));
          
          final solicitudesParaRecibir = lote.solicitudes
              .where((sol) => sol.estado == 'READY' || sol.estado == 'RECEIVED' || sol.estado == 'DISCREPANCY' || sol.estado == 'NOT_FOUND' || sol.estado == 'LENT')
              .toList();

          if (solicitudesParaRecibir.isEmpty) {
            return const Center(
              child: Text('No hay historiales listos para recepcionar hoy.'),
            );
          }

          return ListView.builder(
            itemCount: solicitudesParaRecibir.length,
            itemBuilder: (context, index) {
              final sol = solicitudesParaRecibir[index];
              final paciente = sol.paciente;
              final iniciales = (paciente != null && paciente.nombres.isNotEmpty)
                  ? '${paciente.nombres[0]}${paciente.apellidoPaterno.isNotEmpty ? paciente.apellidoPaterno[0] : ''}'
                  : '?';

              // Icono / Color de estado actual
              IconData icono = Icons.help_outline;
              Color color = Colors.grey;
              
              if (sol.estado == 'READY') {
                icono = Icons.check_circle_outline;
                color = Colors.orange;
              } else if (sol.estado == 'RECEIVED') {
                icono = Icons.task_alt;
                color = Colors.green;
              } else if (sol.estado == 'DISCREPANCY') {
                icono = Icons.error_outline;
                color = Colors.red;
              } else if (sol.estado == 'NOT_FOUND' || sol.estado == 'LENT') {
                icono = Icons.cancel_outlined;
                color = Colors.grey;
              }

              return Dismissible(
                key: Key(sol.id),
                direction: sol.estado == 'READY' 
                    ? DismissDirection.horizontal 
                    : DismissDirection.none,
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Swipe Izquierda (Rojo) - Discrepancia
                    await ref.read(historialesControllerProvider.notifier)
                        .actualizarRecepcion(sol.id, 'DISCREPANCY');
                  } else if (direction == DismissDirection.startToEnd) {
                    // Swipe Derecha (Verde) - Recibido
                    await ref.read(historialesControllerProvider.notifier)
                        .actualizarRecepcion(sol.id, 'RECEIVED');
                  }
                  return false; // El provider refrescará la lista automáticamente
                },
                background: Container(
                  color: Colors.green,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.warning, color: Colors.white),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(iniciales.toUpperCase()),
                  ),
                  title: Text(paciente?.nombreCompleto ?? 'Desconocido'),
                  subtitle: Text('Cama: ${sol.camaCodigo ?? 'S/N'} • Estado: ${TraductorEstados.traducir(sol.estado)}'),
                  trailing: Icon(icono, color: color),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
