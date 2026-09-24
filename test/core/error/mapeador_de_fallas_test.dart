import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/mapeador_de_fallas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapeador = MapeadorDeFallas();

  DioException conRespuesta(int codigo, Object? cuerpo) => DioException(
        requestOptions: RequestOptions(path: '/censo-diario/carga-manual'),
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/censo-diario/carga-manual'),
          statusCode: codigo,
          data: cuerpo,
        ),
      );

  group('400 — regla de negocio vs validación de campos', () {
    test('message como string es una regla de negocio', () {
      final falla = mapeador.desdeRespuesta(
        codigo: 400,
        cuerpo: {
          'statusCode': 400,
          'message': 'El censo no cuadra: total + libre + bloqueada + '
              'aislamiento (38) debe ser igual a la capacidad del servicio (40).',
          'error': 'Bad Request',
        },
      );

      expect(falla, isA<FallaReglaDeNegocio>());
      expect(falla.mensaje, contains('no cuadra'));
    });

    test('message como array es una falla de validación (CA-10)', () {
      final falla = mapeador.desdeRespuesta(
        codigo: 400,
        cuerpo: {
          'statusCode': 400,
          'message': [
            'ingreso must not be less than 0',
            'servicioId must be a UUID',
          ],
          'error': 'Bad Request',
        },
      );

      expect(falla, isA<FallaValidacion>());
      expect((falla as FallaValidacion).errores, hasLength(2));
      expect(falla.errores.first, contains('ingreso'));
    });

    test('un array de un solo elemento se trata como texto simple', () {
      final falla = mapeador.desdeRespuesta(
        codigo: 400,
        cuerpo: {
          'message': ['servicioId must be a UUID'],
        },
      );

      // Mostrar una lista con un solo ítem es ruido visual sin información.
      expect(falla, isA<FallaReglaDeNegocio>());
      expect(falla.mensaje, 'servicioId must be a UUID');
    });

    test('mensajes reales de confirmar el día', () {
      for (final texto in [
        'Faltan servicios por cargar: Pediatría, UCIM',
        'El censo no cuadra para: Medicina Interna',
        'Falta el mapeo hacia vaciado para el servicio "Cirugía"',
        'Hay especialidades de camas prestadas repetidas para el mismo tipo '
            'de ingreso — cada combinación especialidad+tipo debe aparecer '
            'una sola vez.',
      ]) {
        final falla =
            mapeador.desdeRespuesta(codigo: 400, cuerpo: {'message': texto});
        expect(falla, isA<FallaReglaDeNegocio>(), reason: texto);
        expect(falla.mensaje, texto);
      }
    });
  });

  group('Otros códigos', () {
    test('401 es falla de autenticación', () {
      final falla = mapeador.desdeRespuesta(codigo: 401, cuerpo: null);
      expect(falla, isA<FallaAutenticacion>());
      expect(falla.sugerencia, contains('Iniciá sesión'));
    });

    test('403 conserva el mensaje del backend', () {
      final falla = mapeador.desdeRespuesta(
        codigo: 403,
        cuerpo: {
          'message': 'Esta fecha ya tiene un cierre automático real — no se '
              'puede pisar con carga manual.',
        },
      );
      expect(falla, isA<FallaAutorizacion>());
      expect(falla.mensaje, contains('cierre automático'));
    });

    test('403 sin cuerpo usa un mensaje por defecto', () {
      final falla = mapeador.desdeRespuesta(codigo: 403, cuerpo: null);
      expect(falla, isA<FallaAutorizacion>());
      expect(falla.mensaje, isNotEmpty);
    });

    test('500 y 503 son falla de servidor', () {
      expect(
        mapeador.desdeRespuesta(codigo: 500, cuerpo: null),
        isA<FallaServidor>(),
      );
      expect(
        mapeador.desdeRespuesta(codigo: 503, cuerpo: null),
        isA<FallaServidor>(),
      );
    });
  });

  group('Errores de transporte', () {
    test('timeouts son falla de red', () {
      for (final tipo in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final falla = mapeador.desdeDio(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: tipo,
          ),
        );
        expect(falla, isA<FallaRed>(), reason: tipo.name);
      }
    });

    test('sin conexión es falla de red y tranquiliza sobre lo tipeado', () {
      final falla = mapeador.desdeDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(falla, isA<FallaRed>());
      expect(falla.sugerencia, contains('no se perdió'));
    });

    test('desdeDio delega en el mapeo por código cuando hay respuesta', () {
      final falla = mapeador.desdeDio(
        conRespuesta(400, {'message': 'El censo no cuadra para: Pediatría'}),
      );
      expect(falla, isA<FallaReglaDeNegocio>());
    });
  });

  group('Robustez del mapeo', () {
    test('cuerpos con forma inesperada no rompen el mapeo', () {
      for (final cuerpo in <Object?>[
        null,
        'texto plano',
        <String, dynamic>{},
        {'message': 42},
        {'message': null},
        <Object?>[],
      ]) {
        expect(
          () => mapeador.desdeRespuesta(codigo: 400, cuerpo: cuerpo),
          returnsNormally,
          reason: '$cuerpo',
        );
      }
    });

    test('toda falla ofrece mensaje y sugerencia no vacíos', () {
      final fallas = <Failure>[
        const FallaRed(),
        const FallaValidacion(['x']),
        const FallaReglaDeNegocio('x'),
        const FallaAutenticacion(),
        const FallaAutorizacion('x'),
        const FallaServidor(),
        const FallaFormatoInesperado('x'),
        const FallaDesconocida(),
      ];

      for (final falla in fallas) {
        expect(falla.mensaje, isNotEmpty, reason: '${falla.runtimeType}');
        expect(falla.sugerencia, isNotEmpty, reason: '${falla.runtimeType}');
      }
    });
  });
}
