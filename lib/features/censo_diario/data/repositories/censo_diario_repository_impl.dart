import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/censo_diario/data/datasources/censo_diario_remote_datasource.dart';
import 'package:app_movil/features/censo_diario/data/models/carga_manual_dtos.dart';
import 'package:app_movil/features/censo_diario/data/models/catalogo_dtos.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:dio/dio.dart';

class CensoDiarioRepositoryImpl implements CensoDiarioRepository {
  const CensoDiarioRepositoryImpl(
    this._remoto, {
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  }) : _mapeador = mapeador;

  final CensoDiarioRemoteDataSource _remoto;
  final MapeadorDeFallas _mapeador;

  /// Envuelve cada llamada para que ninguna excepción de infraestructura
  /// escape hacia el dominio. Es el único `try/catch` del feature.
  Future<Resultado<T>> _ejecutar<T>(Future<T> Function() accion) async {
    try {
      return Exito(await accion());
    } on DioException catch (e) {
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
      // Un campo que llega con otro tipo del esperado revienta como TypeError
      // en el cast del DTO. Es un cambio de contrato del backend, no un error
      // del operador: se atrapa a propósito para poder nombrarlo así en la UI
      // en vez de mostrar un crash.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      return Fallo(
        FallaFormatoInesperado('Un campo llegó con un tipo inesperado: $e'),
      );
    }
  }

  @override
  Future<Resultado<List<Servicio>>> obtenerServiciosActivos() {
    return _ejecutar(() async {
      // Las dos llamadas son independientes: se piden en paralelo para no
      // encadenar dos viajes de red en el arranque de la app.
      //
      // Se usa `Future.wait` y NO el `.wait` de records: ese último envuelve
      // el error en `ParallelWaitError`, con lo cual el `catch (DioException)`
      // de _ejecutar no lo vería y la excepción se escaparía al dominio.
      // `Future.wait` propaga la excepción original y además atiende el error
      // de la otra rama, así que no quedan errores asíncronos sin manejar.
      final resultados = await Future.wait<Object>([
        _remoto.obtenerServicios(),
        _remoto.obtenerMapeoServicios(),
      ]);

      final servicios = resultados[0] as List<ServicioDto>;
      final mapeos = resultados[1] as List<MapeoServicioDto>;

      final porServicio = <String, String>{
        for (final m in mapeos) m.servicioId: m.nombreVaciado,
      };

      return servicios
          .where((s) => s.activo)
          .map((s) => s.toDomain(nombreVaciado: porServicio[s.id]))
          .toList();
    });
  }

  @override
  Future<Resultado<List<MapeoVaciado>>> obtenerMapeoEspecialidades() {
    return _ejecutar(() async {
      final mapeos = await _remoto.obtenerMapeoEspecialidades();
      return mapeos.map((m) => m.toDomain()).toList();
    });
  }

  @override
  Future<Resultado<int>> obtenerCapacidadServicio(String servicioId) {
    return _ejecutar(() => _remoto.obtenerCapacidadServicio(servicioId));
  }

  @override
  Future<Resultado<int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  }) {
    return _ejecutar(() async {
      final anterior = fecha.subtract(const Duration(days: 1));
      final filas = await _remoto.obtenerHistorico(anterior);

      // El endpoint devuelve todos los servicios de esa fecha; el filtro es
      // del lado del cliente y usa el nombre de VACIADO, no el local.
      for (final fila in filas) {
        if (fila.servicio == nombreVaciado) return fila.total;
      }

      // Que no haya fila es normal durante el backfill: puede ser el primer
      // día que se carga. No es un error, es un estado vacío.
      return null;
    });
  }

  @override
  Future<Resultado<CierreCenso?>> obtenerCierre(DateTime fecha) {
    return _ejecutar(() async {
      final dto = await _remoto.obtenerCierre(fecha);
      return dto?.toDomain();
    });
  }

  @override
  Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(
    DateTime fecha, {
    String? servicioId,
  }) {
    return _ejecutar(() async {
      final dtos = await _remoto.obtenerCargas(fecha, servicioId: servicioId);
      // La procedencia se arma acá y no en el DTO: `toDomain` devuelve el
      // censo, que es lo único que el resto del feature sabe manipular.
      return dtos
          .map(
            (d) => CargaGuardada(
              censo: d.toDomain(),
              servicioNombre: d.servicioNombre,
              actualizadoEn: d.actualizadoEn,
              creadoPorNombre: d.creadoPorNombre,
            ),
          )
          .toList();
    });
  }

  @override
  Future<Resultado<CensoServicio>> guardarCensoServicio(CensoServicio censo) {
    return _ejecutar(() async {
      final guardada = await _remoto.guardarCargaManual(
        GuardarCargaManualDto.fromDomain(censo),
      );
      // La respuesta del backend no trae las camas prestadas, pero acaba de
      // reemplazarlas con exactamente las que se enviaron.
      return guardada.toDomain(camasPrestadas: censo.camasPrestadas);
    });
  }

  @override
  Future<Resultado<ProgresoDia>> obtenerProgresoDia(DateTime fecha) {
    return _ejecutar(() async {
      final estados = await _remoto.obtenerEstado(fecha);
      return ProgresoDia(
        fecha: fecha,
        servicios: estados.map((e) => e.toDomain()).toList(),
      );
    });
  }

  @override
  Future<Resultado<ConfirmacionDia>> confirmarDia(DateTime fecha) {
    return _ejecutar(() async {
      final dto = await _remoto.confirmarDia(fecha);
      return dto.toDomain();
    });
  }
}
