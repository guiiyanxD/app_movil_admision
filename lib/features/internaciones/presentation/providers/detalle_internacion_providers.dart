import 'package:app_movil/features/internaciones/domain/entities/internacion_detalle.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider que carga los detalles de una internación específica.
///
/// Usa `FutureProvider.family` para aceptar un ID de internación y devolver
/// un `Future<InternacionDetalle>`. Esto permite usarlo con `ref.watch()`
/// pasando el ID como argumento.
///
/// Si la petición falla, lanza una excepción con el mensaje de error,
/// lo cual será manejado por la UI usando `AsyncValue.when` o `AsyncValue.whenData`.
final AutoDisposeFutureProviderFamily<InternacionDetalle, String>
    internacionDetalleProvider = FutureProvider.autoDispose
        .family<InternacionDetalle, String>((ref, id) async {
  final repository = ref.watch(internacionesRepositoryProvider);
  final resultado = await repository.obtenerDetalle(id);

  return resultado.fold(
    (falla) => throw Exception(falla.mensaje),
    (detalle) => detalle,
  );
});
