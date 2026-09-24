import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/data/datasources/camas_remote_datasource.dart';
import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/domain/repositories/camas_repository.dart';
import 'package:dio/dio.dart';

class CamasRepositoryImpl implements CamasRepository {
  const CamasRepositoryImpl(
    this._remoto, {
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  }) : _mapeador = mapeador;

  final CamasRemoteDataSource _remoto;
  final MapeadorDeFallas _mapeador;

  @override
  Future<Resultado<List<CamaTablero>>> obtenerTablero({
    String? servicioId,
  }) async {
    try {
      final modelos = await _remoto.obtenerTablero(servicioId: servicioId);
      return Exito(modelos);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // ignore: avoid_catching_errors, error de contrato en tiempo de ejecución del cast.
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado('Un campo llegó con un tipo inesperado: $e'),
      );
    }
  }

  @override
  Future<Resultado<void>> cambiarEstado(CambiarEstadoCamaParams params) async {
    try {
      await _remoto.cambiarEstado(params);
      return const Exito(null);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    }
  }
}
