import 'package:app_movil/features/historiales_clinicos/domain/models/solicitud_historial_model.dart';
import 'package:app_movil/features/historiales_clinicos/domain/repositories/historiales_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// Inyección del repositorio (se sobreescribe en bootstrap.dart).
final historialesRepositoryProvider = Provider<HistorialesRepository>((ref) {
  throw UnimplementedError('historialesRepositoryProvider no sobreescrito.');
});

/// Rango de fechas seleccionado en los Dashboards (por defecto nulo = últimos 10 lotes).
final rangoFechasLotesProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Lista de lotes
final lotesDelDiaProvider = AutoDisposeFutureProvider<List<LoteSolicitudModel>>((ref) async {
  final repo = ref.watch(historialesRepositoryProvider);
  final rango = ref.watch(rangoFechasLotesProvider);

  String? startDate;
  String? endDate;

  if (rango != null) {
    startDate = rango.start.toIso8601String().split('T').first;
    endDate = rango.end.toIso8601String().split('T').first;
  }

  final resultado = await repo.obtenerLotes(startDate: startDate, endDate: endDate);
  return resultado.fold(
    (falla) => throw Exception(falla.mensaje),
    (lotes) => lotes,
  );
});

/// Proveedor para manejar acciones mutables en Historiales (Admisión y Archivo).
final historialesControllerProvider =
    StateNotifierProvider.autoDispose<HistorialesController, AsyncValue<void>>((ref) {
  return HistorialesController(ref.watch(historialesRepositoryProvider), ref);
});

class HistorialesController extends StateNotifier<AsyncValue<void>> {
  HistorialesController(this._repo, this._ref) : super(const AsyncData(null));

  final HistorialesRepository _repo;
  final Ref _ref;

  Future<void> crearLote(List<String> internacionIds) async {
    state = const AsyncLoading();
    final res = await _repo.crearLote(internacionIds);
    if (!mounted) return;
    state = res.fold(
      (falla) => AsyncError(falla.mensaje, StackTrace.current),
      (lote) {
        _ref.invalidate(lotesDelDiaProvider); // Refrescar listas
        return const AsyncData(null);
      },
    );
  }

  Future<void> actualizarEstadoArchivo(
    String solicitudId,
    String estado, {
    String? notasArchivo,
  }) async {
    state = const AsyncLoading();
    final res = await _repo.actualizarEstadoArchivo(
      solicitudId,
      estado,
      notasArchivo: notasArchivo,
    );
    if (!mounted) return;
    state = res.fold(
      (falla) => AsyncError(falla.mensaje, StackTrace.current),
      (_) {
        _ref.invalidate(lotesDelDiaProvider);
        return const AsyncData(null);
      },
    );
  }

  Future<void> notificarLote(String loteId) async {
    state = const AsyncLoading();
    final res = await _repo.notificarLote(loteId);
    if (!mounted) return;
    state = res.fold(
      (falla) => AsyncError(falla.mensaje, StackTrace.current),
      (_) {
        _ref.invalidate(lotesDelDiaProvider);
        return const AsyncData(null);
      },
    );
  }

  Future<void> actualizarRecepcion(String solicitudId, String estado) async {
    state = const AsyncLoading();
    final res = await _repo.actualizarRecepcion(solicitudId, estado);
    if (!mounted) return;
    state = res.fold(
      (falla) => AsyncError(falla.mensaje, StackTrace.current),
      (_) {
        _ref.invalidate(lotesDelDiaProvider);
        return const AsyncData(null);
      },
    );
  }
}
