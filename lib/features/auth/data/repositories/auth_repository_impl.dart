import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/auth/data/auth_remote_datasource.dart';
import 'package:app_movil/features/auth/data/sesion_en_memoria.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/almacen_sesion.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';
import 'package:dio/dio.dart';

/// Sesión del usuario: login, restauración, renovación y cierre.
///
/// Es también el único lugar que sabe que **renovar rota el refresh token**:
/// el servidor guarda el hash del nuevo y descarta el anterior, así que si no
/// se persiste el rotado, la siguiente renovación falla con "Sesión inválida"
/// y el operador queda afuera sin motivo aparente.
///
/// Respecto de la versión anterior perdió dos responsabilidades (H-5): el
/// `Sesion?` mutable pasó a [SesionEnMemoria] y el control de concurrencia del
/// refresco a `ProveedorDeSesionAuth`. Lo que queda es orquestar red y
/// persistencia, que es lo que un repositorio hace.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoto,
    required AlmacenSesion almacen,
    required SesionEnMemoria memoria,
    MapeadorDeFallas mapeador = const MapeadorDeFallas(),
  })  : _remoto = remoto,
        _almacen = almacen,
        _memoria = memoria,
        _mapeador = mapeador;

  final AuthRemoteDataSource _remoto;
  final AlmacenSesion _almacen;
  final SesionEnMemoria _memoria;
  final MapeadorDeFallas _mapeador;

  @override
  Future<Resultado<Sesion>> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      final dto = await _remoto.login(email: email, password: password);
      final sesion = dto.toDomain();

      await _almacen.guardar(sesion);
      _memoria.guardar(sesion);

      return Exito(sesion);
    } on DioException catch (e) {
      // Un 401 acá no es "sesión vencida", son credenciales incorrectas. Decir
      // "tu sesión expiró" en la pantalla de login sería absurdo.
      if (e.response?.statusCode == 401) {
        return const Fallo(
          FallaAutenticacion('Correo o contraseña incorrectos.'),
        );
      }
      return Fallo(_mapeador.desdeDio(e));
    } on FormatException catch (e) {
      return Fallo(FallaFormatoInesperado(e.message));
    }
  }

  @override
  Future<Sesion?> restaurar() async {
    final sesion = await _almacen.leer();
    if (sesion != null) _memoria.guardar(sesion);
    return sesion;
  }

  @override
  Future<bool> refrescar() async {
    final actual = _memoria.actual;
    if (actual == null) return false;

    try {
      final tokens = await _remoto.refrescar(actual.refreshToken);

      // Persistir el refresh token ROTADO no es opcional: el servidor ya
      // descartó el anterior.
      final renovada = actual.conTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      await _almacen.guardar(renovada);
      _memoria.guardar(renovada);
      return true;
    } on Object {
      // Refresh vencido o revocado: no hay nada que reintentar, se cierra la
      // sesión para que la app pida credenciales en vez de reintentar en vano.
      await cerrarSesion(avisarAlServidor: false);
      return false;
    }
  }

  @override
  Future<void> cerrarSesion({bool avisarAlServidor = true}) async {
    final actual = _memoria.actual;

    if (avisarAlServidor && actual != null) {
      try {
        await _remoto.logout(actual.accessToken);
      } on Object {
        // Que falle el aviso al servidor no debe impedir cerrar sesión en el
        // dispositivo: lo importante es que los tokens locales desaparezcan.
      }
    }

    _memoria.limpiar();
    await _almacen.borrar();
  }
}
