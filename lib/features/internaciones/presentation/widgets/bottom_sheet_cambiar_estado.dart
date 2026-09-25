import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/domain/repositories/camas_repository.dart';
import 'package:app_movil/features/internaciones/presentation/providers/operaciones_internacion_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BottomSheetCambiarEstadoCama extends ConsumerStatefulWidget {
  const BottomSheetCambiarEstadoCama({
    required this.cama,
    super.key,
  });

  final CamaTablero cama;

  @override
  ConsumerState<BottomSheetCambiarEstadoCama> createState() =>
      _BottomSheetCambiarEstadoCamaState();
}

class _BottomSheetCambiarEstadoCamaState
    extends ConsumerState<BottomSheetCambiarEstadoCama> {
  final _formKey = GlobalKey<FormState>();

  late String _estadoSeleccionado;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  final _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _estadoSeleccionado = widget.cama.estadoBase == 'disponible'
        ? 'fuera_servicio'
        : widget.cama.estadoBase;
    _fechaInicio = DateTime.now();
    _motivoController.text = widget.cama.motivoEstado ?? '';
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(
    BuildContext context,
    bool esInicio,
  ) async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _fechaInicio : _fechaFin) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (seleccion == null) return;

    if (!context.mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (hora == null) return;

    final fechaHora = DateTime(
      seleccion.year,
      seleccion.month,
      seleccion.day,
      hora.hour,
      hora.minute,
    );

    setState(() {
      if (esInicio) {
        _fechaInicio = fechaHora;
      } else {
        _fechaFin = fechaHora;
      }
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaFin != null && _fechaInicio != null) {
      if (_fechaFin!.isBefore(_fechaInicio!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha de fin debe ser posterior a la de inicio'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final params = CambiarEstadoCamaParams(
      camaId: widget.cama.id,
      estado: _estadoSeleccionado,
      motivo: _estadoSeleccionado != 'disponible'
          ? _motivoController.text.trim()
          : null,
      fechaInicio: _estadoSeleccionado != 'disponible' ? _fechaInicio : null,
      fechaFin: _estadoSeleccionado != 'disponible' ? _fechaFin : null,
    );

    await ref.read(operacionesInternacionProvider.notifier).cambiarEstadoCama(params);
  }

  @override
  Widget build(BuildContext context) {
    final estadoOp = ref.watch(operacionesInternacionProvider);

    ref.listen<AsyncValue<void>>(operacionesInternacionProvider,
        (previo, actual) {
      actual.whenOrNull(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado actualizado exitosamente')),
          );
          Navigator.of(context).pop();
        },
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
          );
        },
      );
    });

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cambiar Estado - ${widget.cama.codigo}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Nuevo Estado',
                  border: OutlineInputBorder(),
                ),
                initialValue: _estadoSeleccionado,
                items: const [
                  DropdownMenuItem(
                    value: 'disponible',
                    child: Text('Disponible'),
                  ),
                  DropdownMenuItem(
                    value: 'fuera_servicio',
                    child: Text('Fuera de Servicio / Bloqueada'),
                  ),
                  DropdownMenuItem(
                    value: 'aislamiento',
                    child: Text('En Aislamiento'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _estadoSeleccionado = val!;
                  });
                },
              ),
              if (_estadoSeleccionado != 'disponible') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFecha(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha Inicio',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _fechaInicio != null
                                ? dateFormat.format(_fechaInicio!)
                                : 'Seleccione...',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFecha(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fecha Fin (Opcional)',
                            border: const OutlineInputBorder(),
                            suffixIcon: _fechaFin != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _fechaFin = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          child: Text(
                            _fechaFin != null
                                ? dateFormat.format(_fechaFin!)
                                : 'No definida',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones / Motivo',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'El motivo es requerido';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: estadoOp.isLoading ? null : _guardar,
                icon: estadoOp.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(estadoOp.isLoading ? 'Guardando...' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
