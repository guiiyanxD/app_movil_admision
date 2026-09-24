import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:app_movil/features/internaciones/presentation/providers/detalle_internacion_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_movil/features/internaciones/domain/repositories/camas_repository.dart';

class OperacionesInternacionNotifier extends StateNotifier<AsyncValue<void>> {
  OperacionesInternacionNotifier(this._repository, this._camasRepository, this._ref) : super(const AsyncValue.data(null));

  final InternacionesRepository _repository;
  final CamasRepository _camasRepository;
  final Ref _ref;

  Future<void> trasladarInterno(MoverCamaParams params) async {
    state = const AsyncValue.loading();
    final resultado = await _repository.trasladarInterno(params);
    
    resultado.fold(
      (falla) => state = AsyncValue.error(falla.mensaje, StackTrace.current),
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(tableroCamasProvider);
        _ref.invalidate(internacionDetalleProvider(params.internacionId));
      },
    );
  }

  Future<void> trasladarServicio(MoverCamaParams params) async {
    state = const AsyncValue.loading();
    final resultado = await _repository.trasladarServicio(params);
    
    resultado.fold(
      (falla) => state = AsyncValue.error(falla.mensaje, StackTrace.current),
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(tableroCamasProvider);
        _ref.invalidate(internacionDetalleProvider(params.internacionId));
      },
    );
  }

  Future<void> registrarEgreso(RegistrarEgresoParams params) async {
    state = const AsyncValue.loading();
    final resultado = await _repository.registrarEgreso(params);
    
    resultado.fold(
      (falla) => state = AsyncValue.error(falla.mensaje, StackTrace.current),
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(tableroCamasProvider);
        _ref.invalidate(internacionDetalleProvider(params.internacionId));
      },
    );
  }

  Future<void> cambiarEstadoCama(CambiarEstadoCamaParams params) async {
    state = const AsyncValue.loading();
    final resultado = await _camasRepository.cambiarEstado(params);
    
    resultado.fold(
      (falla) => state = AsyncValue.error(falla.mensaje, StackTrace.current),
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(tableroCamasProvider);
      },
    );
  }
}

final operacionesInternacionProvider =
    StateNotifierProvider<OperacionesInternacionNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(internacionesRepositoryProvider);
  final camasRepository = ref.watch(camasRepositoryProvider);
  return OperacionesInternacionNotifier(repository, camasRepository, ref);
});
