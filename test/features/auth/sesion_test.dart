import 'package:app_movil/core/red/api_client.dart';
import 'package:app_movil/core/red/interceptor_sesion.dart';
import 'package:app_movil/features/auth/data/auth_remote_datasource.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RolUsuario', () {
    test('admin y operador pueden escribir carga manual', () {
      expect(RolUsuario.admin.puedeEscribirCargaManual, isTrue);
      expect(RolUsuario.operador.puedeEscribirCargaManual, isTrue);
    });

    test('lectura no puede escribir', () {
      expect(RolUsuario.lectura.puedeEscribirCargaManual, isFalse);
    });

    test('un rol desconocido cae en el más restrictivo', () {
      // Si el backend agrega un rol nuevo, la app lo trata como consulta hasta
      // que se la actualice. Nunca al revés.
      expect(RolUsuario.desdeApi('supervisor'), RolUsuario.lectura);
      expect(RolUsuario.desdeApi(null), RolUsuario.lectura);
      expect(RolUsuario.desdeApi(''), RolUsuario.lectura);
    });

    test('mapea los valores reales del backend', () {
      expect(RolUsuario.desdeApi('admin'), RolUsuario.admin);
      expect(RolUsuario.desdeApi('operador'), RolUsuario.operador);
      expect(RolUsuario.desdeApi('lectura'), RolUsuario.lectura);
    });
  });

  group('SesionDto — contrato real de /auth/login', () {
    test('lee tokens y usuario anidado', () {
      final dto = SesionDto.fromJson(const {
        'accessToken': 'eyJhbG...',
        'refreshToken': 'eyJyZW...',
        'usuario': {
          'id': 'usr-uuid',
          'nombreCompleto': 'Ana Rojas',
          'email': 'ana@cps.bo',
          'rol': 'operador',
        },
      });

      final sesion = dto.toDomain();
      expect(sesion.accessToken, 'eyJhbG...');
      expect(sesion.usuario.nombreCompleto, 'Ana Rojas');
      expect(sesion.rol, RolUsuario.operador);
    });

    test('falla explícitamente si no viene el usuario', () {
      // Sin el usuario no sabemos el rol, y sin el rol no podemos decidir si
      // habilitar la escritura. Entrar a ciegas sería peor que no entrar.
      expect(
        () => SesionDto.fromJson(const {
          'accessToken': 'a',
          'refreshToken': 'b',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TokensDto — /auth/refresh no devuelve usuario', () {
    test('lee solo el par de tokens', () {
      final dto = TokensDto.fromJson(const {
        'accessToken': 'nuevo-access',
        'refreshToken': 'nuevo-refresh',
      });

      expect(dto.accessToken, 'nuevo-access');
      expect(dto.refreshToken, 'nuevo-refresh');
    });
  });

  group('Sesion.conTokens', () {
    test('renueva los tokens conservando el usuario', () {
      const original = Sesion(
        accessToken: 'a0',
        refreshToken: 'r0',
        usuario: UsuarioSesion(
          id: 'usr-1',
          nombreCompleto: 'Ana Rojas',
          email: 'ana@cps.bo',
          rol: RolUsuario.admin,
        ),
      );

      final renovada = original.conTokens(
        accessToken: 'a1',
        refreshToken: 'r1',
      );

      expect(renovada.accessToken, 'a1');
      expect(renovada.refreshToken, 'r1');
      expect(renovada.usuario, original.usuario);
    });
  });

  group('InterceptorSesion — rutas exentas', () {
    test('reconoce las rutas de autenticación', () {
      // Un 401 del login son credenciales y uno del refresh es sesión muerta:
      // renovar en cualquiera de los dos entraría en bucle.
      expect(InterceptorSesion.esRutaDeAuth('/auth/login'), isTrue);
      expect(InterceptorSesion.esRutaDeAuth('/auth/refresh'), isTrue);
      expect(InterceptorSesion.esRutaDeAuth('/auth/logout'), isTrue);
    });

    test('no confunde rutas del censo con rutas de auth', () {
      expect(
        InterceptorSesion.esRutaDeAuth('/censo-diario/carga-manual'),
        isFalse,
      );
      expect(InterceptorSesion.esRutaDeAuth('/servicios'), isFalse);
      expect(InterceptorSesion.esRutaDeAuth('/camas'), isFalse);
    });
  });

  group('ApiClient.normalizar', () {
    test('agrega el prefijo cuando falta', () {
      expect(
        ApiClient.normalizar('http://10.0.2.2:3001'),
        'http://10.0.2.2:3001/api/v1',
      );
    });

    test('no lo duplica cuando ya está', () {
      expect(
        ApiClient.normalizar('http://10.0.2.2:3001/api/v1'),
        'http://10.0.2.2:3001/api/v1',
      );
    });

    test('tolera barras finales y espacios', () {
      expect(
        ApiClient.normalizar('  http://10.0.2.2:3001///  '),
        'http://10.0.2.2:3001/api/v1',
      );
    });
  });
}
