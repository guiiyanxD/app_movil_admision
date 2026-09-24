import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/features/reporteria/data/datasources/reporteria_remote_datasource.dart';
import 'package:app_movil/features/reporteria/data/models/fila_reporte_censo_dto.dart';
import 'package:app_movil/features/reporteria/data/repositories/reporteria_repository_impl.dart';
import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';
import 'package:app_movil/features/reporteria/domain/value_objects/rango_fechas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble del datasource. Registra los parámetros con los que se lo llamó para
/// poder verificar la serialización sin levantar un servidor.
class _DataSourceFalso implements ReporteriaRemoteDataSource {
  List<FilaReporteCensoDto> filas = [];
  Exception? excepcion;

  RangoFechas? rangoPedido;
  AgrupacionReporte? agrupacionPedida;

  @override
  Future<List<FilaReporteCensoDto>> obtenerCensoMensual({
    required RangoFechas rango,
    required AgrupacionReporte agrupacion,
  }) async {
    rangoPedido = rango;
    agrupacionPedida = agrupacion;

    final e = excepcion;
    if (e != null) throw e;
    return filas;
  }
}

void main() {
  group('FilaReporteCensoDto', () {
    test('lee el JSON del contrato campo por campo', () {
      final dto = FilaReporteCensoDto.fromJson(const {
        'periodo': '2026-07-16',
        'servicio': 'Medicina Interna',
        'ingreso': 4,
        'ingresoTraslado': 0,
        'egreso': 3,
        'egresoTraslado': 0,
        'obito': 0,
        'aislamiento': 1,
        'bloqueada': 1,
        'total': 34,
      });

      final fila = dto.toDomain();
      expect(fila.periodo, '2026-07-16');
      expect(fila.servicio, 'Medicina Interna');
      expect(fila.valorDe(MovimientoReporte.ingreso), 4);
      expect(fila.valorDe(MovimientoReporte.egreso), 3);
      expect(fila.valorDe(MovimientoReporte.aislamiento), 1);
      expect(fila.valorDe(MovimientoReporte.total), 34);
    });

    test('ningún movimiento queda mapeado en el lugar equivocado', () {
      // Cada campo con un valor distinto: si dos estuvieran cruzados, el test
      // lo detecta. Con ceros o valores repetidos pasaría inadvertido.
      final fila = FilaReporteCensoDto.fromJson(const {
        'periodo': '2026-07',
        'servicio': 'X',
        'ingreso': 1,
        'ingresoTraslado': 2,
        'egreso': 3,
        'egresoTraslado': 4,
        'obito': 5,
        'aislamiento': 6,
        'bloqueada': 7,
        'total': 8,
      }).toDomain();

      expect(
        MovimientoReporte.values.map(fila.valorDe).toList(),
        [1, 2, 3, 4, 5, 6, 7, 8],
      );
    });

    test('un campo ausente vale cero en vez de romper', () {
      final fila = FilaReporteCensoDto.fromJson(const {
        'periodo': '2026-07',
        'servicio': 'X',
      }).toDomain();

      expect(MovimientoReporte.values.map(fila.valorDe), everyElement(0));
    });

    test('acepta el entero llegando como double', () {
      final fila = FilaReporteCensoDto.fromJson(const {
        'periodo': '2026-07',
        'servicio': 'X',
        'total': 34.0,
      }).toDomain();

      expect(fila.total, 34);
    });
  });

  group('RangoFechas', () {
    test('serializa a YYYY-MM-DD plano', () {
      final rango = RangoFechas(
        inicio: DateTime(2026, 7, 1, 23, 40),
        fin: DateTime(2026, 7, 31),
      );

      expect(rango.inicioComoParametro, '2026-07-01');
      expect(rango.finComoParametro, '2026-07-31');
      expect(rango.inicioComoParametro.length, 10);
    });

    test('rechaza un rango invertido antes de salir a la red', () {
      expect(
        () => RangoFechas(
          inicio: DateTime(2026, 7, 31),
          fin: DateTime(2026, 7, 1),
        ),
        throwsA(isA<RangoInvalido>()),
      );
    });

    test('acepta un rango de un solo día', () {
      final rango = RangoFechas(
        inicio: DateTime(2026, 7, 16),
        fin: DateTime(2026, 7, 16),
      );

      expect(rango.dias, 1);
    });

    test('cuenta los días con ambos extremos incluidos', () {
      final rango = RangoFechas(
        inicio: DateTime(2026, 7, 1),
        fin: DateTime(2026, 7, 31),
      );

      expect(rango.dias, 31);
    });

    test('detecta si abarca más de un mes', () {
      expect(
        RangoFechas(inicio: DateTime(2026, 7, 1), fin: DateTime(2026, 7, 31))
            .abarcaVariosMeses,
        isFalse,
      );
      expect(
        RangoFechas(inicio: DateTime(2026, 7, 30), fin: DateTime(2026, 8, 2))
            .abarcaVariosMeses,
        isTrue,
      );
      expect(
        RangoFechas(inicio: DateTime(2025, 12, 30), fin: DateTime(2026, 1, 2))
            .abarcaVariosMeses,
        isTrue,
        reason: 'cruzar de año también es cruzar de mes',
      );
    });
  });

  group('AgrupacionReporte', () {
    test('la agrupación diaria es lo que el API llama detalle', () {
      expect(AgrupacionReporte.diaria.comoParametroDetalle, isTrue);
      expect(AgrupacionReporte.mensual.comoParametroDetalle, isFalse);
    });
  });

  group('ReporteriaRepositoryImpl', () {
    late _DataSourceFalso falso;
    late ReporteriaRepositoryImpl repositorio;

    setUp(() {
      falso = _DataSourceFalso();
      repositorio = ReporteriaRepositoryImpl(falso);
    });

    final rango = RangoFechas(
      inicio: DateTime(2026, 7, 1),
      fin: DateTime(2026, 7, 31),
    );

    test('pasa el rango y la agrupación al datasource', () async {
      await repositorio.obtenerCensoMensual(
        rango: rango,
        agrupacion: AgrupacionReporte.mensual,
      );

      expect(falso.rangoPedido, rango);
      expect(falso.agrupacionPedida, AgrupacionReporte.mensual);
    });

    test('un rango sin datos devuelve lista vacía, no un error', () async {
      final resultado = await repositorio.obtenerCensoMensual(
        rango: rango,
        agrupacion: AgrupacionReporte.diaria,
      );

      // Que no haya filas es un estado vacío legítimo: puede que esas fechas
      // todavía no estén confirmadas.
      expect(resultado.esExito, isTrue);
      expect(resultado.valorONulo, isEmpty);
    });

    test('traduce un fallo de red a Failure', () async {
      falso.excepcion = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

      final resultado = await repositorio.obtenerCensoMensual(
        rango: rango,
        agrupacion: AgrupacionReporte.diaria,
      );

      expect(resultado.fallaONula, isA<FallaRed>());
    });

    test('traduce una respuesta con forma inesperada', () async {
      falso.excepcion = const FormatException('Se esperaba una lista');

      final resultado = await repositorio.obtenerCensoMensual(
        rango: rango,
        agrupacion: AgrupacionReporte.diaria,
      );

      expect(resultado.fallaONula, isA<FallaFormatoInesperado>());
    });
  });
}
