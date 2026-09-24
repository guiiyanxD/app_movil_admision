import 'package:app_movil/features/censo_diario/data/models/carga_manual_dtos.dart';
import 'package:app_movil/features/censo_diario/data/models/catalogo_dtos.dart';
import 'package:dio/dio.dart';

/// Acceso HTTP al módulo de censo diario.
///
/// Única capa que conoce rutas, query params y forma del JSON. No captura
/// errores: deja pasar la `DioException` para que el repositorio la traduzca a
/// una [Failure] en un solo lugar.
class CensoDiarioRemoteDataSource {
  const CensoDiarioRemoteDataSource(this._dio);

  final Dio _dio;

  /// Formatea a `YYYY-MM-DD` plano. Nunca ISO con offset.
  static String formatearFecha(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  List<Map<String, dynamic>> _comoLista(Object? data) {
    if (data is! List) {
      throw FormatException(
        'Se esperaba una lista y llegó ${data.runtimeType}',
      );
    }
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<ServicioDto>> obtenerServicios() async {
    final respuesta = await _dio.get<Object?>(
      '/servicios',
      queryParameters: {'soloActivos': 'true'},
    );
    return _comoLista(respuesta.data).map(ServicioDto.fromJson).toList();
  }

  Future<List<MapeoServicioDto>> obtenerMapeoServicios() async {
    final respuesta = await _dio.get<Object?>('/censo-diario/mapeo/servicios');
    return _comoLista(respuesta.data).map(MapeoServicioDto.fromJson).toList();
  }

  Future<List<MapeoEspecialidadDto>> obtenerMapeoEspecialidades() async {
    final respuesta =
        await _dio.get<Object?>('/censo-diario/mapeo/especialidades');
    return _comoLista(respuesta.data)
        .map(MapeoEspecialidadDto.fromJson)
        .toList();
  }

  /// Capacidad del servicio = cantidad de camas activas.
  ///
  /// La guía de integración dice que este endpoint está fuera de alcance, pero
  /// existe y no tiene restricción de rol. `camas.service.listar` filtra por
  /// `activa: true`, el mismo criterio que usa el backend para calcular la
  /// capacidad contra la que evalúa el cuadre.
  Future<int> obtenerCapacidadServicio(String servicioId) async {
    final respuesta = await _dio.get<Object?>(
      '/camas',
      queryParameters: {'servicioId': servicioId, 'soloActivas': 'true'},
    );
    return _comoLista(respuesta.data).length;
  }

  Future<List<HistoricoCensoDto>> obtenerHistorico(DateTime fecha) async {
    final respuesta = await _dio.get<Object?>(
      '/censo-diario/historico',
      queryParameters: {'fecha': formatearFecha(fecha)},
    );
    return _comoLista(respuesta.data).map(HistoricoCensoDto.fromJson).toList();
  }

  /// `null` cuando la fecha no tiene cierre. El endpoint devuelve el `null` de
  /// Prisma, que Dio entrega como cuerpo vacío o literal nulo.
  Future<CierreCensoDto?> obtenerCierre(DateTime fecha) async {
    final respuesta = await _dio.get<Object?>(
      '/censo-diario/cierre/${formatearFecha(fecha)}',
    );
    final data = respuesta.data;
    if (data is! Map<String, dynamic> || data.isEmpty) return null;
    return CierreCensoDto.fromJson(data);
  }

  Future<CargaManualGuardadaDto> guardarCargaManual(
    GuardarCargaManualDto dto,
  ) async {
    final respuesta = await _dio.post<Object?>(
      '/censo-diario/carga-manual',
      data: dto.toJson(),
    );
    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Se esperaba el objeto de la carga guardada',
      );
    }
    return CargaManualGuardadaDto.fromJson(data);
  }

  /// Cargas de staging ya guardadas para una fecha.
  ///
  /// Un servicio sin fila no aparece en la lista y una fecha sin cargas
  /// devuelve `[]`: la ausencia es un estado vacío, no un 404.
  ///
  /// [servicioId] está en el contrato pero el flujo normal no lo usa: se pide
  /// la fecha completa de una sola vez y se cachea, porque recorrer los
  /// servicios con las flechas costaría una petición por servicio (D-1).
  Future<List<CargaGuardadaDto>> obtenerCargas(
    DateTime fecha, {
    String? servicioId,
  }) async {
    final respuesta = await _dio.get<Object?>(
      '/censo-diario/carga-manual',
      queryParameters: {
        'fecha': formatearFecha(fecha),
        if (servicioId != null) 'servicioId': servicioId,
      },
    );
    return _comoLista(respuesta.data).map(CargaGuardadaDto.fromJson).toList();
  }

  Future<List<EstadoCargaManualDto>> obtenerEstado(DateTime fecha) async {
    final respuesta = await _dio.get<Object?>(
      '/censo-diario/carga-manual/estado',
      queryParameters: {'fecha': formatearFecha(fecha)},
    );
    return _comoLista(respuesta.data)
        .map(EstadoCargaManualDto.fromJson)
        .toList();
  }

  Future<ConfirmacionDiaDto> confirmarDia(DateTime fecha) async {
    final respuesta = await _dio.post<Object?>(
      '/censo-diario/carga-manual/confirmar',
      data: {'fecha': formatearFecha(fecha)},
    );
    final data = respuesta.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Se esperaba el resumen de confirmación');
    }
    return ConfirmacionDiaDto.fromJson(data);
  }
}
