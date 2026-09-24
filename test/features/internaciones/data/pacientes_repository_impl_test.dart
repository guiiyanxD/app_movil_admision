import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/internaciones/data/datasources/pacientes_remote_datasource.dart';
import 'package:app_movil/features/internaciones/data/repositories/pacientes_repository_impl.dart';
import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';
import 'package:app_movil/features/internaciones/domain/repositories/pacientes_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _PacientesRemoteDataSourceFalso implements PacientesRemoteDataSource {
  Paciente? pacienteABuscar;
  Paciente? pacienteACrear;
  DioException? excepcionDio;

  @override
  Future<Paciente?> buscarPorMatricula(String matricula) async {
    if (excepcionDio != null) throw excepcionDio!;
    return pacienteABuscar;
  }

  @override
  Future<Paciente> crearPaciente(CrearPacienteParams params) async {
    if (excepcionDio != null) throw excepcionDio!;
    return pacienteACrear ??
        Paciente(
          id: 'p-new',
          nombres: params.nombres,
          apellidoPaterno: params.apellidoPaterno,
          apellidoMaterno: params.apellidoMaterno,
          matricula: '19525414DSE',
          fechaNacimiento: params.fechaNacimiento,
          sexo: params.sexo,

          tipoPaciente: params.tipoPaciente,
          empresaAseguradora: params.empresaAseguradora,
          regional: params.regional,
        );
  }
}

void main() {
  late _PacientesRemoteDataSourceFalso fakeDs;
  late PacientesRepositoryImpl repo;

  setUp(() {
    fakeDs = _PacientesRemoteDataSourceFalso();
    repo = PacientesRepositoryImpl(fakeDs);
  });

  group('PacientesRepositoryImpl', () {
    test('buscarPorMatricula retorna Exito con paciente cuando existe', () async {
      final paciente = Paciente(
        id: 'p-1',
        nombres: 'ELIZABETH',
        apellidoPaterno: 'DAVILA',
        apellidoMaterno: 'SUSANO',
        matricula: '19525414DSE',
        fechaNacimiento: DateTime.utc(1952, 4, 14),
        sexo: 'femenino',
      );
      fakeDs.pacienteABuscar = paciente;

      final res = await repo.buscarPorMatricula('19525414DSE');

      expect(res, isA<Exito<Paciente?>>());
      expect(res.valorONulo, equals(paciente));
    });

    test('buscarPorMatricula retorna Exito(null) si no existe', () async {
      fakeDs.pacienteABuscar = null;

      final res = await repo.buscarPorMatricula('NOEXISTE');

      expect(res, isA<Exito<Paciente?>>());
      expect(res.valorONulo, isNull);
    });

    test('crearPaciente retorna Exito con el paciente creado', () async {
      final params = CrearPacienteParams(
        nombres: 'HUGO',
        apellidoPaterno: 'ZABALA',
        apellidoMaterno: 'BURGOS',
        fechaNacimiento: DateTime.utc(1950, 5, 4),
        sexo: 'masculino',
        empresaAseguradora: 'GESTORA PUBLICA',
      );

      final res = await repo.crearPaciente(params);

      expect(res, isA<Exito<Paciente>>());
      expect(res.valorONulo?.nombres, equals('HUGO'));
      expect(res.valorONulo?.apellidoPaterno, equals('ZABALA'));
    });

    test('retorna Fallo ante DioException', () async {
      fakeDs.excepcionDio = DioException(
        requestOptions: RequestOptions(path: '/pacientes/buscar'),
        type: DioExceptionType.connectionTimeout,
      );

      final res = await repo.buscarPorMatricula('123');

      expect(res, isA<Fallo<Paciente?>>());
      expect(res.fallaONula, isA<FallaRed>());
    });
  });
}
