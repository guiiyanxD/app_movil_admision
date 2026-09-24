import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/features/auth/data/almacen_sesion_seguro.dart';
import 'package:app_movil/features/auth/data/auth_remote_datasource.dart';
import 'package:app_movil/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app_movil/features/auth/data/sesion_en_memoria.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _DataSourceFalso implements AuthRemoteDataSource {
  Exception? excepcionLogin;
  Exception? excepcionRefresh;

  int llamadasRefresh = 0;
  int llamadasLogout = 0;

  /// Simula la rotación del servidor: cada refresh devuelve tokens nuevos.
  int _generacion = 0;

  @override
  Future<SesionDto> login({
    required String email,
    required String password,
  }) async {
    final e = excepcionLogin;
    if (e != null) throw e;

    return const SesionDto(
      accessToken: 'access-0',
      refreshToken: 'refresh-0',
      id: 'usr-1',
      nombreCompleto: 'Ana Rojas',
      email: 'ana@cps.bo',
      rol: 'operador',
    );
  }

  @override
  Future<TokensDto> refrescar(String refreshToken) async {
    llamadasRefresh++;
    final e = excepcionRefresh;
    if (e != null) throw e;

    // Retardo real para que el test de un-solo-vuelo tenga ventana de solape.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    _generacion++;
    return TokensDto(
      accessToken: 'access-$_generacion',
      refreshToken: 'refresh-$_generacion',
    );
  }

  @override
  Future<void> logout(String accessToken) async => llamadasLogout++;
}

void main() {
  late _DataSourceFalso remoto;
  late AlmacenSesionEnMemoria almacen;
  late SesionEnMemoria memoria;
  late AuthRepository repositorio;

  setUp(() {
    remoto = _DataSourceFalso();
    almacen = AlmacenSesionEnMemoria();
    memoria = SesionEnMemoria();
    repositorio = AuthRepositoryImpl(
      remoto: remoto,
      almacen: almacen,
      memoria: memoria,
    );
  });

  DioException dioConCodigo(int codigo) => DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: codigo,
        ),
      );

  group('Login', () {
    test('guarda la sesión y expone el rol del usuario', () async {
      final resultado = await repositorio.iniciarSesion(
        email: 'ana@cps.bo',
        password: 'secreto123',
      );

      final sesion = resultado.valorONulo!;
      expect(sesion.usuario.nombreCompleto, 'Ana Rojas');
      expect(sesion.rol, RolUsuario.operador);
      expect(sesion.puedeEscribir, isTrue);
      expect(await almacen.leer(), isNotNull);
      expect(memoria.actual, isNotNull);
    });

    test('un 401 en login son credenciales, no sesión vencida', () async {
      remoto.excepcionLogin = dioConCodigo(401);

      final resultado = await repositorio.iniciarSesion(
        email: 'ana@cps.bo',
        password: 'mala',
      );

      // Decir "tu sesión expiró" en la pantalla de login sería absurdo.
      final falla = resultado.fallaONula!;
      expect(falla, isA<FallaAutenticacion>());
      expect(falla.mensaje, contains('incorrectos'));
    });

    test('sin conexión no se guarda ninguna sesión', () async {
      remoto.excepcionLogin = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );

      final resultado = await repositorio.iniciarSesion(
        email: 'ana@cps.bo',
        password: 'secreto123',
      );

      expect(resultado.fallaONula, isA<FallaRed>());
      expect(await almacen.leer(), isNull);
    });
  });

  group('Rotación del refresh token', () {
    test('persiste el token rotado, no el anterior', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      expect(memoria.actual!.refreshToken, 'refresh-0');

      final renovo = await repositorio.refrescar();

      // El servidor ya descartó refresh-0: si guardáramos el viejo, la
      // siguiente renovación fallaría con "Sesión inválida".
      expect(renovo, isTrue);
      expect(memoria.actual!.accessToken, 'access-1');
      expect(memoria.actual!.refreshToken, 'refresh-1');
      expect((await almacen.leer())!.refreshToken, 'refresh-1');
    });

    test('conserva el usuario, que el refresh no devuelve', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      await repositorio.refrescar();

      expect(memoria.actual!.usuario.nombreCompleto, 'Ana Rojas');
      expect(memoria.actual!.rol, RolUsuario.operador);
    });

    test('dos renovaciones seguidas encadenan tokens', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      await repositorio.refrescar();
      await repositorio.refrescar();

      expect(memoria.actual!.refreshToken, 'refresh-2');
      expect(remoto.llamadasRefresh, 2);
    });
  });

  // El "un solo vuelo" se mudó a `proveedor_de_sesion_auth_test.dart`: dejó de
  // ser responsabilidad del repositorio y pasó a serlo del adaptador, que es
  // quien promete esa garantía en el contrato `ProveedorDeSesion` (SPEC-005,
  // H-5). Acá quedó la prueba de que el repositorio renueva **sin** coordinar.
  group('Renovación sin coordinación', () {
    test('cada llamada golpea el servidor: el repositorio no agrupa', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');

      await Future.wait([repositorio.refrescar(), repositorio.refrescar()]);

      expect(remoto.llamadasRefresh, 2);
    });
  });

  group('Sesión perdida', () {
    test('un refresh rechazado cierra la sesión local', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      remoto.excepcionRefresh = dioConCodigo(401);

      final renovo = await repositorio.refrescar();

      expect(renovo, isFalse);
      expect(memoria.actual, isNull);
      expect(await almacen.leer(), isNull);
    });

    test('no avisa al servidor cuando el refresh ya falló', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      remoto.excepcionRefresh = dioConCodigo(401);

      await repositorio.refrescar();

      // Llamar a /auth/logout con un token muerto solo agrega otro 401.
      expect(remoto.llamadasLogout, 0);
    });

    test('sin sesión previa, refrescar devuelve false sin llamar al API',
        () async {
      final renovo = await repositorio.refrescar();

      expect(renovo, isFalse);
      expect(remoto.llamadasRefresh, 0);
    });
  });

  group('Cierre de sesión', () {
    test('borra los tokens locales aunque el servidor falle', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');

      await repositorio.cerrarSesion();

      expect(memoria.actual, isNull);
      expect(await almacen.leer(), isNull);
      expect(remoto.llamadasLogout, 1);
    });
  });

  group('Restauración al abrir la app', () {
    test('recupera la sesión guardada', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');

      final otro = AuthRepositoryImpl(
        remoto: remoto,
        almacen: almacen,
        memoria: SesionEnMemoria(),
      );
      final restaurada = await otro.restaurar();

      expect(restaurada, isNotNull);
      expect(restaurada!.usuario.email, 'ana@cps.bo');
      expect(restaurada.rol, RolUsuario.operador);
    });

    test('sin nada guardado devuelve null', () async {
      expect(await repositorio.restaurar(), isNull);
    });
  });
}
