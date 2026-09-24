import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/data/datasources/pacientes_remote_datasource.dart';
import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';
import 'package:app_movil/features/internaciones/domain/repositories/pacientes_repository.dart';
import 'package:dio/dio.dart';

class PacientesRepositoryImpl implements PacientesRepository {
  const PacientesRepositoryImpl(
    this._remoto, {
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  }) : _mapeador = mapeador;

  final PacientesRemoteDataSource _remoto;
  final MapeadorDeFallas _mapeador;

  @override
  Future<Resultado<Paciente?>> buscarPorMatricula(String matricula) async {
    try {
      final paciente = await _remoto.buscarPorMatricula(matricula);
      return Exito(paciente);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // ignore: avoid_catching_errors, error de casteo runtime
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado('Campo con tipo inesperado: $e'),
      );
    }
  }

  @override
  Future<Resultado<Paciente>> crearPaciente(CrearPacienteParams params) async {
    try {
      final paciente = await _remoto.crearPaciente(params);
      return Exito(paciente);
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // ignore: avoid_catching_errors, error de casteo runtime
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado('Campo con tipo inesperado: $e'),
      );
    }
  }
}
