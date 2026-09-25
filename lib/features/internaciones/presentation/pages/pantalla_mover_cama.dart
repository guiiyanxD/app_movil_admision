import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:app_movil/features/internaciones/presentation/providers/operaciones_internacion_providers.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PantallaMoverCama extends ConsumerStatefulWidget {
  const PantallaMoverCama({
    required this.internacionId,
    required this.servicioActualId,
    required this.esTrasladoInterno,
    super.key,
  });

  final String internacionId;
  final String servicioActualId;
  final bool esTrasladoInterno;

  @override
  ConsumerState<PantallaMoverCama> createState() => _PantallaMoverCamaState();
}

class _PantallaMoverCamaState extends ConsumerState<PantallaMoverCama> {
  String? _servicioSeleccionadoId;
  CamaTablero? _camaSeleccionada;
  String? _especialidadTratanteId;

  @override
  void initState() {
    super.initState();
    if (widget.esTrasladoInterno) {
      _servicioSeleccionadoId = widget.servicioActualId;
    }
  }

  void _confirmarTraslado() {
    if (_camaSeleccionada == null) return;

    final params = MoverCamaParams(
      internacionId: widget.internacionId,
      camaId: _camaSeleccionada!.id,
      especialidadId:
          _especialidadTratanteId ?? _camaSeleccionada!.especialidadNativaId,
    );

    if (widget.esTrasladoInterno) {
      ref
          .read(operacionesInternacionProvider.notifier)
          .trasladarInterno(params);
    } else {
      ref
          .read(operacionesInternacionProvider.notifier)
          .trasladarServicio(params);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoOp = ref.watch(operacionesInternacionProvider);

    ref.listen<AsyncValue<void>>(operacionesInternacionProvider,
        (previo, actual) {
      actual.whenOrNull(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Traslado registrado exitosamente')),
          );
          // Volver a la pantalla anterior
          Navigator.of(context).pop();
        },
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
          );
        },
      );
    });

    final camasDisponiblesAsync = ref.watch(tableroCamasProvider);
    final servicios = ref.watch(serviciosTableroProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esTrasladoInterno
            ? 'Traslado Interno'
            : 'Traslado de Servicio'),
      ),
      body: camasDisponiblesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error al cargar camas: $err')),
        data: (todasLasCamas) {
          // Filtrar camas por el servicio seleccionado y que no estén ocupadas
          final camasFiltradas = todasLasCamas
              .where((c) =>
                  c.servicioId == _servicioSeleccionadoId && !c.esOcupada)
              .toList();

          // Extraer especialidades únicas de todas las camas del tablero
          final especialidadesUnicas = <String, String>{};
          for (final c in todasLasCamas) {
            especialidadesUnicas[c.especialidadNativaId] = c.especialidadNombre;
          }
          final listaEspecialidades = especialidadesUnicas.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Seleccione el destino del paciente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              if (!widget.esTrasladoInterno) ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Servicio Destino',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _servicioSeleccionadoId,
                  items: servicios
                      .where((s) =>
                          s.id !=
                          widget
                              .servicioActualId) // No puede trasladarse al mismo servicio
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _servicioSeleccionadoId = val;
                      _camaSeleccionada =
                          null; // Reiniciar cama al cambiar de servicio
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],
              DropdownButtonFormField<CamaTablero>(
                decoration: const InputDecoration(
                  labelText: 'Cama Destino',
                  border: OutlineInputBorder(),
                ),
                initialValue: _camaSeleccionada,
                items: camasFiltradas
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.codigo} - ${c.especialidadNombre}'),
                      ),
                    )
                    .toList(),
                onChanged: _servicioSeleccionadoId == null
                    ? null
                    : (val) {
                        setState(() {
                          _camaSeleccionada = val;
                          _especialidadTratanteId = val?.especialidadNativaId;
                        });
                      },
                disabledHint: const Text('Seleccione un servicio primero'),
              ),
              const SizedBox(height: 24),
              if (_camaSeleccionada != null) ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Especialidad Tratante',
                    helperText:
                        'Modifique solo si ingresará como cama prestada.',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _especialidadTratanteId,
                  items: listaEspecialidades
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _especialidadTratanteId = val;
                    });
                  },
                ),
                const SizedBox(height: 32),
              ],
              FilledButton.icon(
                onPressed: _camaSeleccionada == null || estadoOp.isLoading
                    ? null
                    : _confirmarTraslado,
                icon: estadoOp.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.transfer_within_a_station),
                label: Text(estadoOp.isLoading
                    ? 'Procesando...'
                    : 'Confirmar Traslado'),
              ),
            ],
          );
        },
      ),
    );
  }
}
