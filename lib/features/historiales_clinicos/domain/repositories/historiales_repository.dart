import 'package:app_movil/core/error/resultado.dart';
import '../models/solicitud_historial_model.dart';

abstract class HistorialesRepository {
  Future<Resultado<LoteSolicitudModel>> crearLote(List<String> internacionIds);
  Future<Resultado<List<LoteSolicitudModel>>> obtenerLotes({
    String? startDate,
    String? endDate,
  });
  Future<Resultado<SolicitudHistorialModel>> actualizarEstadoArchivo(
    String id,
    String estado, {
    String? notasArchivo,
  });
  Future<Resultado<void>> notificarLote(String loteId);
  Future<Resultado<SolicitudHistorialModel>> actualizarRecepcion(String id, String estado);
}
