import 'package:app_movil/features/historiales_clinicos/presentation/archivo/pantalla_gestion_lote.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/providers/historiales_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PantallaLotesArchivo extends ConsumerWidget {
  const PantallaLotesArchivo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangoFiltro = ref.watch(rangoFechasLotesProvider);
    final lotesAsync = ref.watch(lotesDelDiaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo Clínico - Lotes'),
        actions: [
          if (rangoFiltro != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                ref.read(rangoFechasLotesProvider.notifier).state = null;
              },
              tooltip: 'Limpiar filtro',
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                initialDateRange: rangoFiltro,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (range != null) {
                ref.read(rangoFechasLotesProvider.notifier).state = range;
              }
            },
            tooltip: 'Filtrar por rango de fechas',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(lotesDelDiaProvider),
          ),
        ],
      ),
      body: lotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (lotes) {
          if (lotes.isEmpty) {
            return const Center(child: Text('No hay solicitudes para esta fecha.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final lote = lotes[index];
              final total = lote.solicitudes.length;
              final pendientes = lote.solicitudes.where((s) => s.estado == 'REQUESTED').length;

              IconData iconoEstado = Icons.pending_actions;
              Color colorEstado = Colors.orange;

              if (lote.estado == 'NOTIFIED') {
                iconoEstado = Icons.notifications_active;
                colorEstado = Colors.green;
              } else if (pendientes == 0) {
                iconoEstado = Icons.done_all;
                colorEstado = Colors.blue;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorEstado.withOpacity(0.2),
                    child: Icon(iconoEstado, color: colorEstado),
                  ),
                  title: Text('Lote creado: ${lote.fechaCreacion.toLocal().toString().split('.')[0]}'),
                  subtitle: Text(
                    pendientes > 0
                        ? '$pendientes de $total historiales pendientes'
                        : 'Lote completamente gestionado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PantallaGestionLote(loteId: lote.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
