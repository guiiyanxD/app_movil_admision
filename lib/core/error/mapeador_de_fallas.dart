import 'package:app_movil/core/error/failure.dart';
import 'package:dio/dio.dart';

/// Traduce lo que devuelve Dio a una [Failure] del dominio.
///
/// Todo el conocimiento del formato de error de NestJS vive acá y en ningún
/// otro lado. Si el backend cambia la forma de sus errores, se toca un archivo.
class MapeadorDeFallas {
  const MapeadorDeFallas();

  Failure desdeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const FallaRed(
          'Tiempo de espera agotado (45s). Señal débil o mala cobertura de red. '
          'Por favor verifique su conexión e intente nuevamente.',
        );
      case DioExceptionType.connectionError:
        return const FallaRed();
      case DioExceptionType.cancel:
        return const FallaDesconocida('La solicitud fue cancelada.');
      case DioExceptionType.badCertificate:
        return const FallaRed('El certificado del servidor no es válido.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final respuesta = e.response;
    if (respuesta == null) return const FallaRed();

    return desdeRespuesta(
      codigo: respuesta.statusCode ?? 0,
      cuerpo: respuesta.data,
    );
  }

  /// Expuesto aparte para poder testear el mapeo sin construir una
  /// `DioException` completa.
  Failure desdeRespuesta({required int codigo, required Object? cuerpo}) {
    final mensaje = _extraerMensaje(cuerpo);

    return switch (codigo) {
      400 => mensaje is List<String>
          ? FallaValidacion(mensaje)
          : FallaReglaDeNegocio(
              mensaje as String? ?? 'La solicitud fue rechazada.',
            ),
      401 => const FallaAutenticacion(),
      403 => FallaAutorizacion(
          mensaje is String
              ? mensaje
              : 'No tenés permiso para realizar esta acción.',
        ),
      404 => const FallaDesconocida('El recurso solicitado no existe.'),
      >= 500 => const FallaServidor(),
      _ => FallaDesconocida(
          mensaje is String ? mensaje : 'Error $codigo del servidor.',
        ),
    };
  }

  /// Devuelve `String`, `List<String>` o `null`.
  ///
  /// NestJS manda `message` como string cuando la rechaza una regla de negocio
  /// y como array cuando falla `class-validator` campo por campo.
  Object? _extraerMensaje(Object? cuerpo) {
    if (cuerpo is! Map) return null;

    final mensaje = cuerpo['message'];
    if (mensaje is String) return mensaje;
    if (mensaje is List) {
      final textos = mensaje.map((e) => e.toString()).toList();
      // Un array de un solo elemento se trata como texto simple: mostrar una
      // lista de un ítem es ruido visual sin información adicional.
      return textos.length == 1 ? textos.first : textos;
    }
    return null;
  }
}
