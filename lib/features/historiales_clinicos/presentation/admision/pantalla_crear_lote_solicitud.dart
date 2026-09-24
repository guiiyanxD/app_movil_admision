import 'package:app_movil/features/historiales_clinicos/presentation/providers/historiales_providers.dart';
import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PantallaCrearLoteSolicitud extends ConsumerStatefulWidget {
  const PantallaCrearLoteSolicitud({super.key});

  @override
  ConsumerState<PantallaCrearLoteSolicitud> createState() => _PantallaCrearLoteSolicitudState();
}

class _PantallaCrearLoteSolicitudState extends ConsumerState<PantallaCrearLoteSolicitud> {
  final Set<String> _seleccionadas = {};

  @override
  Widget build(BuildContext context) {
    final tableroAsync = ref.watch(tableroCamasProvider);
    final lotesAsync = ref.watch(lotesDelDiaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Historiales'),
        actions: [
          if (_seleccionadas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _crearLote(context),
            ),
        ],
      ),
      body: tableroAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (camas) {
          // Filtrar camas ocupadas
          final ocupadas = camas.where((c) => c.esOcupada && c.internacionId != null).toList();

          return lotesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (lotes) {
              // Obtener set de internaciones que YA fueron solicitadas hoy
              final yaSolicitadas = <String>{};
              for (final lote in lotes) {
                for (final sol in lote.solicitudes) {
                  yaSolicitadas.add(sol.internacionId);
                }
              }

              // Filtrar ocupadas quitando las ya solicitadas
              final disponibles = ocupadas.where((c) => !yaSolicitadas.contains(c.internacionId!)).toList();

              if (disponibles.isEmpty) {
                return const Center(
                  child: Text('No hay nuevos ingresos sin historial solicitado.'),
                );
              }

              return ListView.builder(
                itemCount: disponibles.length,
                itemBuilder: (context, index) {
                  final cama = disponibles[index];
                  final pacienteNombre = cama.pacienteNombre ?? 'Desconocido';
                  final internacionId = cama.internacionId!;
                  final isSelected = _seleccionadas.contains(internacionId);
                  
                  final iniciales = pacienteNombre.isNotEmpty
                      ? pacienteNombre[0].toUpperCase()
                      : '?';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(iniciales),
                    ),
                    title: Text(pacienteNombre),
                    subtitle: Text('Cama: ${cama.codigo} • Matrícula: ${cama.matricula ?? 'S/N'}'),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _seleccionadas.add(internacionId);
                          } else {
                            _seleccionadas.remove(internacionId);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _seleccionadas.remove(internacionId);
                        } else {
                          _seleccionadas.add(internacionId);
                        }
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _seleccionadas.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _crearLote(context),
              icon: const Icon(Icons.send),
              label: Text('Solicitar (${_seleccionadas.length})'),
            )
          : null,
    );
  }

  Future<void> _crearLote(BuildContext context) async {
    if (_seleccionadas.isEmpty) return;

    final controller = ref.read(historialesControllerProvider.notifier);
    await controller.crearLote(_seleccionadas.toList());

    if (mounted) {
      final state = ref.read(historialesControllerProvider);
      if (!context.mounted) return;
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.error}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud generada con éxito.')),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
