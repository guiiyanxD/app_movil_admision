import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/historiales_clinicos/data/datasources/historiales_remote_datasource.dart';
import 'package:app_movil/features/historiales_clinicos/domain/models/solicitud_historial_model.dart';
import 'package:app_movil/features/historiales_clinicos/domain/repositories/historiales_repository.dart';
import 'package:dio/dio.dart';

class HistorialesRepositoryImpl implements HistorialesRepository {
  const HistorialesRepositoryImpl(
    this._remoto, {
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  }) : _mapeador = mapeador;

  final HistorialesRemoteDataSource _remoto;
  final MapeadorDeFallas _mapeador;

  @override
  Future<Resultado<LoteSolicitudModel>> crearLote(List<String> internacionIds) async {
    try {
      final resultado = await _remoto.crearLote(internacionIds);
      return Exito(resultado);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
    } on TypeError catch (e) {
      return Fallo(FallaFormatoInesperado('Campo con tipo inesperado: $e'));
    }
  }

  @override
  Future<Resultado<List<LoteSolicitudModel>>> obtenerLotes({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final resultado = await _remoto.obtenerLotes(
        startDate: startDate,
        endDate: endDate,
      );
      return Exito(resultado);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
    } on TypeError catch (e) {
      return Fallo(FallaFormatoInesperado('Campo con tipo inesperado: $e'));
    }
  }

  @override
  Future<Resultado<SolicitudHistorialModel>> actualizarEstadoArchivo(
    String id,
    String estado, {
    String? notasArchivo,
  }) async {
    try {
      final resultado = await _remoto.actualizarEstadoArchivo(
        id,
        estado,
        notasArchivo: notasArchivo,
      );
      return Exito(resultado);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
    } on TypeError catch (e) {
      return Fallo(FallaFormatoInesperado('Campo con tipo inesperado: $e'));
    }
  }

  @override
  Future<Resultado<void>> notificarLote(String loteId) async {
    try {
      await _remoto.notificarLote(loteId);
      return const Exito(null);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    }
  }

  @override
  Future<Resultado<SolicitudHistorialModel>> actualizarRecepcion(String id, String estado) async {
    try {
      final resultado = await _remoto.actualizarRecepcion(id, estado);
      return Exito(resultado);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
    } on TypeError catch (e) {
      return Fallo(FallaFormatoInesperado('Campo con tipo inesperado: $e'));
    }
  }
}
