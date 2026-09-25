import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/data/datasources/internaciones_remote_datasource.dart';
import 'package:app_movil/features/internaciones/domain/entities/internacion_detalle.dart';
import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:dio/dio.dart';

class InternacionesRepositoryImpl implements InternacionesRepository {
  const InternacionesRepositoryImpl(
    this._remoto, {
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  }) : _mapeador = mapeador;

  final InternacionesRemoteDataSource _remoto;
  final MapeadorDeFallas _mapeador;

  @override
  Future<Resultado<ResultadoIngresoHospitalario>> registrarIngreso(
    RegistrarIngresoParams params,
  ) async {
    try {
      final resultado = await _remoto.registrarIngreso(params);
      return Exito(resultado);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // ignore: avoid_catching_errors, error runtime
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado('Campo con tipo inesperado: $e'),
      );
    }
  }

  @override
  Future<Resultado<InternacionDetalle>> obtenerDetalle(
    String internacionId,
  ) async {
    try {
      final json = await _remoto.obtenerDetalle(internacionId);
      final detalle = InternacionDetalle.fromJson(json);
      return Exito(detalle);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // ignore: avoid_catching_errors, error runtime
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado(
            'Campo con tipo inesperado al parsear detalle: $e'),
      );
    }
  }

  @override
  Future<Resultado<void>> trasladarInterno(MoverCamaParams params) async {
    try {
      await _remoto.trasladarInterno(params);
      return const Exito(null);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    }
  }

  @override
  Future<Resultado<void>> trasladarServicio(MoverCamaParams params) async {
    try {
      await _remoto.trasladarServicio(params);
      return const Exito(null);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    }
  }

  @override
  Future<Resultado<void>> registrarEgreso(RegistrarEgresoParams params) async {
    try {
      await _remoto.registrarEgreso(params);
      return const Exito(null);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    }
  }
}
