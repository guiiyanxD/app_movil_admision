import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';

/// Contrato del repositorio del censo diario.
///
/// Vive en `domain/` y no conoce HTTP, Dio ni JSON: la capa de presentación
/// depende de esta abstracción, no de la implementación.
abstract interface class CensoDiarioRepository {
  /// Servicios activos ya combinados con su mapeo a vaciado-admisión.
  ///
  /// Resuelve dos llamadas (`GET /servicios` y `GET /mapeo/servicios`) porque
  /// separarlas obligaría a cada consumidor a cruzarlas por su cuenta, y el
  /// cruce es justamente donde se detecta el servicio sin mapeo (V-06).
  Future<Resultado<List<Servicio>>> obtenerServiciosActivos();

  /// Mapeo de especialidades. Solo las que tienen fila se ofrecen en el
  /// selector de camas prestadas: elegir una sin mapeo garantiza un 400 al
  /// confirmar el día.
  Future<Resultado<List<MapeoVaciado>>> obtenerMapeoEspecialidades();

  /// Cantidad de camas activas del servicio. Es la capacidad contra la que se
  /// evalúa el cuadre.
  Future<Resultado<int>> obtenerCapacidadServicio(String servicioId);

  /// Total de cierre del día anterior para un servicio, o `null` si esa fecha
  /// no tiene fila. Que no haya es normal durante el backfill, no un error.
  Future<Resultado<int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  });

  /// `null` si la fecha no está cerrada.
  Future<Resultado<CierreCenso?>> obtenerCierre(DateTime fecha);

  /// Lo que ya está guardado en staging para una fecha, con su procedencia.
  ///
  /// Un servicio sin carga previa simplemente no viene en la lista: es un
  /// estado vacío, no un error. Sin esta lectura el formulario abre en cero y
  /// el upsert de [guardarCensoServicio] puede pisar una carga que nadie vio.
  ///
  /// [servicioId] restringe la consulta a un servicio. El flujo normal no lo
  /// usa: pide la fecha completa una sola vez y la cachea (SPEC-003, D-1).
  Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(
    DateTime fecha, {
    String? servicioId,
  });

  /// Guarda (o rectifica) un servicio. Es upsert por `(fecha, servicioId)`.
  Future<Resultado<CensoServicio>> guardarCensoServicio(CensoServicio censo);

  Future<Resultado<ProgresoDia>> obtenerProgresoDia(DateTime fecha);

  /// Confirma el día completo. Revalida todos los servicios del lado del
  /// servidor, así que puede rechazar algo que el progreso daba por listo.
  Future<Resultado<ConfirmacionDia>> confirmarDia(DateTime fecha);
}
