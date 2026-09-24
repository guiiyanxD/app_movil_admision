import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/data/datasources/internaciones_remote_datasource.dart';
import 'package:app_movil/features/internaciones/data/repositories/internaciones_repository_impl.dart';
import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _InternacionesRemoteDataSourceFalso
    implements InternacionesRemoteDataSource {
  ResultadoIngresoHospitalario? resultadoARetornar;
  DioException? excepcionDio;

  @override
  Future<ResultadoIngresoHospitalario> registrarIngreso(
    RegistrarIngresoParams params,
  ) async {
    if (excepcionDio != null) throw excepcionDio!;
    return resultadoARetornar ??
        ResultadoIngresoHospitalario(
          internacionId: 'int-123',
          pacienteId: params.pacienteId,
          bedStayId: 'bs-456',
          numeroHc2: 4285,
        );
  }

  @override
  Future<Map<String, dynamic>> obtenerDetalle(String id) async {
    if (excepcionDio != null) throw excepcionDio!;
    return {'id': id, 'detalle': 'mock'};
  }

  @override
  Future<void> trasladarInterno(MoverCamaParams params) async {
    if (excepcionDio != null) throw excepcionDio!;
  }

  @override
  Future<void> trasladarServicio(MoverCamaParams params) async {
    if (excepcionDio != null) throw excepcionDio!;
  }

  @override
  Future<void> registrarEgreso(RegistrarEgresoParams params) async {
    if (excepcionDio != null) throw excepcionDio!;
  }
}

void main() {
  late _InternacionesRemoteDataSourceFalso fakeDs;
  late InternacionesRepositoryImpl repo;

  setUp(() {
    fakeDs = _InternacionesRemoteDataSourceFalso();
    repo = InternacionesRepositoryImpl(fakeDs);
  });

  group('InternacionesRepositoryImpl', () {
    test('registrarIngreso retorna Exito con identificadores del ingreso',
        () async {
      const params = RegistrarIngresoParams(
        pacienteId: 'pac-1',
        camaId: 'cama-1',
        especialidadId: 'esp-1',
        medicoTratante: 'DR. QUISPE',
        diagnosticoInicial: 'ICTERICIA',
      );

      final res = await repo.registrarIngreso(params);

      expect(res, isA<Exito<ResultadoIngresoHospitalario>>());
      expect(res.valorONulo?.internacionId, equals('int-123'));
      expect(res.valorONulo?.numeroHc2, equals(4285));
    });

    test('retorna Fallo ante DioException con código 400', () async {
      fakeDs.excepcionDio = DioException(
        requestOptions: RequestOptions(path: '/internaciones/ingreso'),
        response: Response(
          requestOptions: RequestOptions(path: '/internaciones/ingreso'),
          statusCode: 400,
          data: {'message': 'La cama seleccionada ya se encuentra ocupada'},
        ),
        type: DioExceptionType.badResponse,
      );

      const params = RegistrarIngresoParams(
        pacienteId: 'pac-1',
        camaId: 'cama-1',
        especialidadId: 'esp-1',
        medicoTratante: 'DR. QUISPE',
        diagnosticoInicial: 'ICTERICIA',
      );

      final res = await repo.registrarIngreso(params);

      expect(res, isA<Fallo<ResultadoIngresoHospitalario>>());
      expect(
        res.fallaONula?.mensaje,
        contains('La cama seleccionada ya se encuentra ocupada'),
      );
    });
  });
}
