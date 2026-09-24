import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/auth/data/proveedor_de_sesion_auth.dart';
import 'package:app_movil/features/auth/data/sesion_en_memoria.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio falso. Cuenta renovaciones y tarda a propósito, para que el
/// test de un-solo-vuelo tenga ventana real de solape.
class _RepositorioFalso implements AuthRepository {
  _RepositorioFalso(this.memoria);

  final SesionEnMemoria memoria;

  int llamadasRefresh = 0;
  bool renovacionExitosa = true;

  @override
  Future<bool> refrescar() async {
    llamadasRefresh++;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    if (!renovacionExitosa) {
      memoria.limpiar();
      return false;
    }

    memoria.guardar(_sesionCon('access-$llamadasRefresh'));
    return true;
  }

  @override
  Future<Resultado<Sesion>> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final sesion = _sesionCon('access-0');
    memoria.guardar(sesion);
    return Exito(sesion);
  }

  @override
  Future<Sesion?> restaurar() async => memoria.actual;

  @override
  Future<void> cerrarSesion({bool avisarAlServidor = true}) async =>
      memoria.limpiar();

  static Sesion _sesionCon(String access) => Sesion(
        accessToken: access,
        refreshToken: 'refresh',
        usuario: const UsuarioSesion(
          id: 'usr-1',
          nombreCompleto: 'Ana Rojas',
          email: 'ana@cps.bo',
          rol: RolUsuario.operador,
        ),
      );
}

void main() {
  late SesionEnMemoria memoria;
  late _RepositorioFalso repositorio;
  late ProveedorDeSesionAuth proveedor;
  var avisosDePerdida = 0;

  setUp(() {
    avisosDePerdida = 0;
    memoria = SesionEnMemoria();
    repositorio = _RepositorioFalso(memoria);
    proveedor = ProveedorDeSesionAuth(
      repositorio: repositorio,
      memoria: memoria,
      alPerder: () => avisosDePerdida++,
    );
  });

  group('Token', () {
    test('sin sesión no hay token', () {
      expect(proveedor.accessToken, isNull);
    });

    test('lee el token de la sesión en memoria', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');

      expect(proveedor.accessToken, 'access-0');
    });

    test('refleja la renovación sin que nadie lo refresque', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      await proveedor.refrescar();

      // El adaptador no cachea el token: lo lee de la misma memoria que el
      // repositorio acaba de escribir. Si lo copiara, el reintento del
      // interceptor viajaría con el token viejo.
      expect(proveedor.accessToken, 'access-1');
    });
  });

  group('Un solo vuelo', () {
    test('cinco renovaciones simultáneas disparan una sola', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');

      final resultados = await Future.wait([
        proveedor.refrescar(),
        proveedor.refrescar(),
        proveedor.refrescar(),
        proveedor.refrescar(),
        proveedor.refrescar(),
      ]);

      // Sin esto, cinco 401 simultáneos rotarían el token cinco veces y
      // dejarían inválidos los cuatro últimos: el servidor descarta el
      // anterior en cada rotación.
      expect(repositorio.llamadasRefresh, 1);
      expect(resultados, everyElement(isTrue));
    });

    test('tras terminar, una renovación nueva vuelve a salir', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');

      await proveedor.refrescar();
      await proveedor.refrescar();

      // El vuelo se cierra al completarse: si el futuro quedara cacheado, la
      // sesión no se podría renovar nunca más.
      expect(repositorio.llamadasRefresh, 2);
    });

    test('una renovación fallida tampoco deja el vuelo abierto', () async {
      await repositorio.iniciarSesion(email: 'a@b.c', password: 'secreto123');
      repositorio.renovacionExitosa = false;

      expect(await proveedor.refrescar(), isFalse);

      repositorio.renovacionExitosa = true;
      expect(await proveedor.refrescar(), isTrue);
      expect(repositorio.llamadasRefresh, 2);
    });
  });

  group('Sesión perdida', () {
    test('avisa una sola vez por invocación', () {
      proveedor
        ..alPerderSesion()
        ..alPerderSesion();

      expect(avisosDePerdida, 2);
    });
  });
}
