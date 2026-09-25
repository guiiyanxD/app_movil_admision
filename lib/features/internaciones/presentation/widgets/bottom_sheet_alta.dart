import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:app_movil/features/internaciones/presentation/providers/operaciones_internacion_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomSheetAltaMedica extends ConsumerStatefulWidget {
  const BottomSheetAltaMedica({required this.internacionId, super.key});

  final String internacionId;

  @override
  ConsumerState<BottomSheetAltaMedica> createState() =>
      _BottomSheetAltaMedicaState();
}

class _BottomSheetAltaMedicaState extends ConsumerState<BottomSheetAltaMedica> {
  String? _motivoSeleccionado;

  final _motivos = const [
    {'value': 'alta_medica', 'label': 'Alta Médica'},
    {'value': 'alta_voluntaria', 'label': 'Alta Voluntaria'},
    {'value': 'traslado_externo', 'label': 'Traslado Externo'},
    {'value': 'obito', 'label': 'Óbito (Fallecimiento)'},
  ];

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(operacionesInternacionProvider);

    ref.listen<AsyncValue<void>>(operacionesInternacionProvider,
        (previo, actual) {
      actual.whenOrNull(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alta registrada exitosamente')),
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

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registrar Egreso',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona el motivo por el cual el paciente dejará la cama actual de forma definitiva.',
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Motivo de Egreso',
              border: OutlineInputBorder(),
            ),
            initialValue: _motivoSeleccionado,
            items: _motivos
                .map(
                  (m) => DropdownMenuItem(
                    value: m['value'],
                    child: Text(m['label']!),
                  ),
                )
                .toList(),
            onChanged: estado.isLoading
                ? null
                : (val) => setState(() => _motivoSeleccionado = val),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_motivoSeleccionado == null || estado.isLoading)
                ? null
                : () async {
                    final params = RegistrarEgresoParams(
                      internacionId: widget.internacionId,
                      motivoEgreso: _motivoSeleccionado!,
                    );
                    await ref
                        .read(operacionesInternacionProvider.notifier)
                        .registrarEgreso(params);
                  },
            icon: estado.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label:
                Text(estado.isLoading ? 'Procesando...' : 'Confirmar Egreso'),
          ),
        ],
      ),
    );
  }
}
