import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/reporteria/data/datasources/reporteria_remote_datasource.dart';
import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';
import 'package:app_movil/features/reporteria/domain/repositories/reporteria_repository.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:dio/dio.dart';

class ReporteriaRepositoryImpl implements ReporteriaRepository {
  const ReporteriaRepositoryImpl(
    this._remoto, {
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  }) : _mapeador = mapeador;

  final ReporteriaRemoteDataSource _remoto;
  final MapeadorDeFallas _mapeador;

  @override
  Future<Resultado<List<FilaReporteCenso>>> obtenerCensoMensual({
    required RangoFechas rango,
    required AgrupacionReporte agrupacion,
  }) async {
    // Mismo patrón que `CensoDiarioRepositoryImpl`: ninguna excepción de
    // infraestructura escapa hacia el dominio.
    try {
      final dtos = await _remoto.obtenerCensoMensual(
        rango: rango,
        agrupacion: agrupacion,
      );
      return Exito(dtos.map((d) => d.toDomain()).toList());
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // Un campo con otro tipo del esperado revienta como TypeError en el cast
      // del DTO: es un cambio de contrato del backend, no un error del usuario.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado('Un campo llegó con un tipo inesperado: $e'),
      );
    }
  }
}
