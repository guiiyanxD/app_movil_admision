import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/censo_diario/data/datasources/censo_diario_remote_datasource.dart';
import 'package:app_movil/features/censo_diario/data/models/carga_manual_dtos.dart';
import 'package:app_movil/features/censo_diario/data/models/catalogo_dtos.dart';
import 'package:app_movil/features/censo_diario/data/repositories/censo_diario_repository_impl.dart';
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble manual del datasource. Se escribe a mano en vez de usar mocktail:
/// son diez métodos con formas fijas, y así el test no depende de configurar
/// stubs ni de registrar fallbacks.
class _DataSourceFalso implements CensoDiarioRemoteDataSource {
  List<ServicioDto> servicios = [];
  List<MapeoServicioDto> mapeoServicios = [];
  List<MapeoEspecialidadDto> mapeoEspecialidades = [];
  List<HistoricoCensoDto> historico = [];
  List<CargaGuardadaDto> cargas = [];
  CierreCensoDto? cierre;
  int capacidad = 0;

  /// Tipada como Exception (no Object) para no violar `only_throw_errors`.
  Exception? excepcionAlLlamar;

  /// Fechas con las que se llamó a [obtenerHistorico]. Sirve para verificar
  /// que se consulta el día ANTERIOR, no el seleccionado.
  final List<DateTime> fechasHistoricoPedidas = [];

  void _quizasFallar() {
    final e = excepcionAlLlamar;
    if (e != null) throw e;
  }

  @override
  Future<List<ServicioDto>> obtenerServicios() async {
    _quizasFallar();
    return servicios;
  }

  @override
  Future<List<MapeoServicioDto>> obtenerMapeoServicios() async {
    _quizasFallar();
    return mapeoServicios;
  }

  @override
  Future<List<MapeoEspecialidadDto>> obtenerMapeoEspecialidades() async {
    _quizasFallar();
    return mapeoEspecialidades;
  }

  @override
  Future<int> obtenerCapacidadServicio(String servicioId) async {
    _quizasFallar();
    return capacidad;
  }

  @override
  Future<List<HistoricoCensoDto>> obtenerHistorico(DateTime fecha) async {
    fechasHistoricoPedidas.add(fecha);
    _quizasFallar();
    return historico;
  }

  @override
  Future<CierreCensoDto?> obtenerCierre(DateTime fecha) async {
    _quizasFallar();
    return cierre;
  }

  @override
  Future<CargaManualGuardadaDto> guardarCargaManual(
    GuardarCargaManualDto dto,
  ) async {
    _quizasFallar();
    return CargaManualGuardadaDto(
      id: 'carga-1',
      fecha: dto.fecha,
      servicioId: dto.servicioId,
      ingreso: dto.ingreso,
      ingresoTraslado: dto.ingresoTraslado,
      egreso: dto.egreso,
      egresoTraslado: dto.egresoTraslado,
      obito: dto.obito,
      bloqueada: dto.bloqueada,
      aislamiento: dto.aislamiento,
      libre: dto.libre,
      total: dto.total,
      dotacion: dto.total + dto.libre,
    );
  }

  @override
  Future<List<CargaGuardadaDto>> obtenerCargas(
    DateTime fecha, {
    String? servicioId,
  }) async {
    _quizasFallar();
    return cargas;
  }

  @override
  Future<List<EstadoCargaManualDto>> obtenerEstado(DateTime fecha) async {
    _quizasFallar();
    return const [];
  }

  @override
  Future<ConfirmacionDiaDto> confirmarDia(DateTime fecha) async {
    _quizasFallar();
    return const ConfirmacionDiaDto(fecha: '2026-06-01', servicios: 2);
  }
}

void main() {
  late _DataSourceFalso falso;
  late CensoDiarioRepositoryImpl repositorio;

  setUp(() {
    falso = _DataSourceFalso();
    repositorio = CensoDiarioRepositoryImpl(falso);
  });

  DioException dioConCodigo(int codigo, Object? cuerpo) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: codigo,
          data: cuerpo,
        ),
      );

  group('obtenerServiciosActivos', () {
    setUp(() {
      falso.servicios = const [
        ServicioDto(id: 'a', nombre: 'Medicina Interna', activo: true),
        ServicioDto(id: 'b', nombre: 'UCIM', activo: true),
        ServicioDto(id: 'c', nombre: 'Servicio cerrado', activo: false),
      ];
      falso.mapeoServicios = const [
        MapeoServicioDto(servicioId: 'a', nombreVaciado: 'Medicina Interna'),
      ];
    });

    test('cruza servicios con su mapeo a vaciado', () async {
      final resultado = await repositorio.obtenerServiciosActivos();
      final lista = resultado.valorONulo!;

      expect(lista, hasLength(2), reason: 'el inactivo se excluye');
      expect(lista.first.nombreVaciado, 'Medicina Interna');
    });

    test('marca el servicio sin fila de mapeo (V-06)', () async {
      final lista = (await repositorio.obtenerServiciosActivos()).valorONulo!;
      final ucim = lista.firstWhere((s) => s.nombre == 'UCIM');

      // Se puede cargar, pero el día no se podrá confirmar hasta que el
      // equipo de datos complete el mapeo. Hay que avisarlo desde el inicio.
      expect(ucim.tieneMapeo, isFalse);
    });

    test('no filtra por cantidad ni asume 13 servicios (CA-15)', () async {
      falso.servicios = List.generate(
        20,
        (i) => ServicioDto(id: '$i', nombre: 'S$i', activo: true),
      );

      final lista = (await repositorio.obtenerServiciosActivos()).valorONulo!;
      expect(lista, hasLength(20));
    });
  });

  group('obtenerTotalDiaAnterior', () {
    test('consulta el día ANTERIOR al seleccionado', () async {
      await repositorio.obtenerTotalDiaAnterior(
        fecha: DateTime(2026, 6, 1),
        nombreVaciado: 'Medicina Interna',
      );

      expect(falso.fechasHistoricoPedidas.single, DateTime(2026, 5, 31));
    });

    test('filtra por nombre de vaciado, no por nombre local', () async {
      falso.historico = const [
        HistoricoCensoDto(
          servicio: 'Pediatria',
          total: 5,
          libre: 1,
          dotacion: 6,
        ),
        HistoricoCensoDto(
          servicio: 'Medicina Interna',
          total: 33,
          libre: 2,
          dotacion: 35,
        ),
      ];

      final resultado = await repositorio.obtenerTotalDiaAnterior(
        fecha: DateTime(2026, 7, 16),
        nombreVaciado: 'Medicina Interna',
      );

      expect(resultado.valorONulo, 33);
    });

    test('devuelve null si no hay fila, sin tratarlo como error', () async {
      falso.historico = const [
        HistoricoCensoDto(
          servicio: 'Pediatria',
          total: 5,
          libre: 1,
          dotacion: 6,
        ),
      ];

      final resultado = await repositorio.obtenerTotalDiaAnterior(
        fecha: DateTime(2026, 6, 1),
        nombreVaciado: 'Medicina Interna',
      );

      // Durante el backfill es normal que falte el día previo: es un estado
      // vacío de la UI, no una falla.
      expect(resultado.esExito, isTrue);
      expect(resultado.valorONulo, isNull);
    });
  });

  group('obtenerCargasDelDia', () {
    test('arma la entidad con el censo y su procedencia', () async {
      falso.cargas = [
        CargaGuardadaDto(
          servicioId: 'a',
          servicioNombre: 'Medicina Interna',
          fecha: '2026-07-16',
          ingreso: 4,
          ingresoTraslado: 0,
          egreso: 3,
          egresoTraslado: 0,
          obito: 0,
          aislamiento: 1,
          bloqueada: 1,
          libre: 2,
          total: 34,
          dotacion: 36,
          actualizadoEn: DateTime.utc(2026, 8, 1, 22, 14, 3),
          creadoPorNombre: 'Ana Rojas',
        ),
      ];

      final resultado =
          await repositorio.obtenerCargasDelDia(DateTime(2026, 7, 16));
      final carga = resultado.valorONulo!.single;

      expect(carga.servicioNombre, 'Medicina Interna');
      expect(carga.creadoPorNombre, 'Ana Rojas');
      expect(carga.actualizadoEn, DateTime.utc(2026, 8, 1, 22, 14, 3));
      expect(carga.censo.total, 34);
      expect(carga.censo.dotacion, 36, reason: 'total 34 + libre 2');
    });

    test('una fecha sin cargas devuelve lista vacía, no una falla', () async {
      final resultado =
          await repositorio.obtenerCargasDelDia(DateTime(2026, 7, 16));

      // Nadie cargó nada todavía: el formulario abre en cero, sin error.
      expect(resultado.esExito, isTrue);
      expect(resultado.valorONulo, isEmpty);
    });

    test('un DioException se traduce a Failure en vez de escapar', () async {
      falso.excepcionAlLlamar = dioConCodigo(500, null);

      final resultado =
          await repositorio.obtenerCargasDelDia(DateTime(2026, 7, 16));

      // La precarga que falla se degrada a un aviso y el formulario abre en
      // cero (CA-07). Para eso la excepción tiene que llegar como Fallo, no
      // reventar el provider que la pide.
      expect(resultado.esFallo, isTrue);
      expect(resultado.fallaONula, isA<FallaServidor>());
    });
  });

  group('guardarCensoServicio', () {
    final censo = CensoServicio(
      fecha: DateTime(2026, 6, 1),
      servicioId: 'a',
      ingreso: 3,
      egreso: 2,
      aislamiento: 1,
      libre: 2,
      total: 8,
      camasPrestadas: const [
        CamaPrestada(
          especialidadId: 'esp-1',
          cantidad: 1,
          tipoIngreso: TipoIngresoCamaPrestada.directo,
        ),
      ],
    );

    test('devuelve el censo con la dotación calculada por el servidor',
        () async {
      final resultado = await repositorio.guardarCensoServicio(censo);

      expect(resultado.esExito, isTrue);
      expect(resultado.valorONulo!.dotacion, 10);
    });

    test('conserva las camas prestadas que el backend no devuelve', () async {
      final guardado = (await repositorio.guardarCensoServicio(censo))
          .valorONulo!;

      // La respuesta de staging no trae las camas prestadas, pero el backend
      // acaba de reemplazarlas por exactamente las que se enviaron.
      expect(guardado.camasPrestadas, hasLength(1));
      expect(guardado.camasPrestadasDirectas, 1);
    });
  });

  group('Traducción de errores', () {
    test('un 400 con texto se convierte en regla de negocio', () async {
      falso.excepcionAlLlamar = dioConCodigo(400, {
        'message': 'El censo no cuadra para: Medicina Interna',
      });

      final resultado = await repositorio.obtenerProgresoDia(DateTime(2026, 6, 1));

      expect(resultado.esFallo, isTrue);
      expect(resultado.fallaONula, isA<FallaReglaDeNegocio>());
    });

    test('un 403 se convierte en falla de autorización', () async {
      falso.excepcionAlLlamar = dioConCodigo(403, {
        'message': 'Esta fecha ya tiene un cierre automático real',
      });

      final resultado = await repositorio.confirmarDia(DateTime(2026, 6, 1));

      expect(resultado.fallaONula, isA<FallaAutorizacion>());
    });

    test('sin conexión se convierte en falla de red', () async {
      falso.excepcionAlLlamar = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

      final resultado = await repositorio.obtenerServiciosActivos();

      expect(resultado.fallaONula, isA<FallaRed>());
    });

    test('una respuesta con forma inesperada no se confunde con red',
        () async {
      falso.excepcionAlLlamar = const FormatException('Se esperaba una lista');

      final resultado = await repositorio.obtenerServiciosActivos();

      expect(resultado.fallaONula, isA<FallaFormatoInesperado>());
    });

    test('ninguna excepción de infraestructura escapa al dominio', () async {
      falso.excepcionAlLlamar = dioConCodigo(500, null);

      // El repositorio es la frontera: arriba de él solo hay Resultado.
      await expectLater(
        repositorio.obtenerCapacidadServicio('a'),
        completes,
      );
    });
  });

  group('Resultado', () {
    test('fold ejecuta la rama correcta', () {
      const exito = Exito<int>(5);
      const fallo = Fallo<int>(FallaRed());

      expect(exito.fold((f) => 'fallo', (v) => 'valor $v'), 'valor 5');
      expect(fallo.fold((f) => 'fallo', (v) => 'valor $v'), 'fallo');
    });

    test('map transforma solo el éxito', () {
      const exito = Exito<int>(5);
      const fallo = Fallo<int>(FallaRed());

      expect(exito.map((v) => v * 2).valorONulo, 10);
      expect(fallo.map((v) => v * 2).esFallo, isTrue);
    });
  });
}
