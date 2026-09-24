import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/domain/repositories/camas_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inyección del repositorio de camas (se satisface en `bootstrap.dart`).
final Provider<CamasRepository> camasRepositoryProvider =
    Provider<CamasRepository>((ref) {
  throw UnimplementedError(
    'camasRepositoryProvider no fue sobreescrito.\n'
    'Se inyecta en el ProviderScope de lib/app/bootstrap.dart.',
  );
});

/// Consulta remota del tablero de camas.
final AutoDisposeFutureProvider<List<CamaTablero>> tableroCamasProvider =
    FutureProvider.autoDispose<List<CamaTablero>>((ref) async {
  final repo = ref.watch(camasRepositoryProvider);
  final resultado = await repo.obtenerTablero();

  return resultado.fold(
    (falla) => throw Exception(falla.mensaje),
    (camas) => camas,
  );
});

/// Filtro por ID de servicio seleccionado (`null` = todos los servicios).
final AutoDisposeStateProvider<String?> filtroServicioIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Filtro por texto ingresado en el buscador (código de cama, paciente o matrícula).
final AutoDisposeStateProvider<String> filtroBusquedaProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Catálogo de servicios presentes en el tablero con conteo de ocupación.
typedef ResumenServicioTablero = ({
  String id,
  String nombre,
  int total,
  int ocupadas,
});

final AutoDisposeProvider<List<ResumenServicioTablero>>
    serviciosTableroProvider =
    Provider.autoDispose<List<ResumenServicioTablero>>((ref) {
  final asyncCamas = ref.watch(tableroCamasProvider);
  final camas = asyncCamas.valueOrNull ?? const [];

  final mapa = <String, ({String nombre, int total, int ocupadas})>{};

  for (final cama in camas) {
    final actual = mapa[cama.servicioId] ??
        (nombre: cama.servicioNombre, total: 0, ocupadas: 0);

    mapa[cama.servicioId] = (
      nombre: actual.nombre,
      total: actual.total + 1,
      ocupadas: actual.ocupadas + (cama.esOcupada ? 1 : 0),
    );
  }

  return mapa.entries
      .map(
        (e) => (
          id: e.key,
          nombre: e.value.nombre,
          total: e.value.total,
          ocupadas: e.value.ocupadas,
        ),
      )
      .toList()
    ..sort((a, b) => a.nombre.compareTo(b.nombre));
});

/// Camas que coinciden con el filtro de servicio y el término de búsqueda.
final AutoDisposeProvider<List<CamaTablero>> camasFiltradasProvider =
    Provider.autoDispose<List<CamaTablero>>((ref) {
  final asyncCamas = ref.watch(tableroCamasProvider);
  final camas = asyncCamas.valueOrNull ?? const [];

  final servicioId = ref.watch(filtroServicioIdProvider);
  final busqueda = ref.watch(filtroBusquedaProvider).trim().toLowerCase();

  return camas.where((cama) {
    if (servicioId != null &&
        servicioId.isNotEmpty &&
        cama.servicioId != servicioId) {
      return false;
    }

    if (busqueda.isNotEmpty) {
      final coincideCodigo = cama.codigo.toLowerCase().contains(busqueda);
      final coincidePaciente =
          cama.pacienteNombre?.toLowerCase().contains(busqueda) ?? false;
      final coincideMatricula =
          cama.matricula?.toLowerCase().contains(busqueda) ?? false;
      final coincideEspecialidad =
          cama.especialidadNombre.toLowerCase().contains(busqueda);

      if (!coincideCodigo &&
          !coincidePaciente &&
          !coincideMatricula &&
          !coincideEspecialidad) {
        return false;
      }
    }

    return true;
  }).toList();
});

/// Métricas generales de ocupación para el encabezado del tablero.
typedef EstadisticasTablero = ({
  int total,
  int ocupadas,
  int disponibles,
  int prestadas,
  int criticas,
  int aislamiento,
  int fueraDeServicio,
  double porcentajeOcupacion,
});

final AutoDisposeProvider<EstadisticasTablero> estadisticasTableroProvider =
    Provider.autoDispose<EstadisticasTablero>((ref) {
  final asyncCamas = ref.watch(tableroCamasProvider);
  final camas = asyncCamas.valueOrNull ?? const [];

  var ocupadas = 0;
  var disponibles = 0;
  var prestadas = 0;
  var criticas = 0;
  var aislamiento = 0;
  var fueraDeServicio = 0;

  for (final cama in camas) {
    switch (cama.estadoVisual) {
      case EstadoCamaVisual.ocupada:
        ocupadas++;
      case EstadoCamaVisual.prestada:
        ocupadas++;
        prestadas++;
      case EstadoCamaVisual.critica:
        ocupadas++;
        criticas++;
      case EstadoCamaVisual.disponible:
        disponibles++;
      case EstadoCamaVisual.aislamiento:
        aislamiento++;
        if (cama.esOcupada) ocupadas++;
      case EstadoCamaVisual.fueraDeServicio:
        fueraDeServicio++;
    }
  }

  final total = camas.length;
  final porcentaje = total > 0 ? (ocupadas / total) * 100 : 0.0;

  return (
    total: total,
    ocupadas: ocupadas,
    disponibles: disponibles,
    prestadas: prestadas,
    criticas: criticas,
    aislamiento: aislamiento,
    fueraDeServicio: fueraDeServicio,
    porcentajeOcupacion: porcentaje,
  );
});
