/// Fallas del dominio. Ninguna capa superior debería ver una `DioException`.
///
/// El backend (NestJS) responde siempre con la misma forma:
/// ```json
/// { "statusCode": 400, "message": "texto o array de textos", "error": "Bad Request" }
/// ```
/// donde `message` puede ser un **string** (regla de negocio rechazada) o un
/// **array de strings** (uno por campo, cuando falla la validación del DTO).
/// Esa distinción importa para la UI y por eso vive en el tipo, no en el texto.
sealed class Failure implements Exception {
  const Failure(this.mensaje);

  /// Mensaje listo para mostrar. Nunca es la excepción cruda.
  final String mensaje;

  /// Qué puede hacer el usuario al respecto.
  String get sugerencia;

  @override
  String toString() => mensaje;
}

/// Sin conexión, DNS caído, timeout. El servidor nunca contestó.
final class FallaRed extends Failure {
  const FallaRed([super.mensaje = 'No se pudo conectar con el servidor.']);

  @override
  String get sugerencia =>
      'Revisá la conexión a internet y volvé a intentar. Lo que escribiste no se perdió.';
}

/// 400 con `message` como **array**: falló la validación del DTO, campo por campo.
final class FallaValidacion extends Failure {
  const FallaValidacion(this.errores)
      : super('La información enviada tiene errores.');

  final List<String> errores;

  @override
  String get sugerencia => 'Corregí los campos señalados y volvé a guardar.';
}

/// 400 con `message` como **string**: una regla de negocio rechazó la operación.
/// Cuadre que no da, mapeo faltante, servicios sin cargar, duplicados.
final class FallaReglaDeNegocio extends Failure {
  const FallaReglaDeNegocio(super.mensaje);

  @override
  String get sugerencia => 'Revisá los datos cargados antes de reintentar.';
}

/// 401: sin token, o token inválido o vencido.
final class FallaAutenticacion extends Failure {
  const FallaAutenticacion([
    super.mensaje = 'Tu sesión expiró.',
  ]);

  @override
  String get sugerencia => 'Iniciá sesión de nuevo para continuar.';
}

/// 403: rol insuficiente, o regla de fecha violada (hoy/futuro, o pisar un
/// cierre automático real).
final class FallaAutorizacion extends Failure {
  const FallaAutorizacion(super.mensaje);

  @override
  String get sugerencia =>
      'Si creés que deberías tener acceso, consultá con el administrador del sistema.';
}

/// 5xx. El problema es del servidor, no del operador.
final class FallaServidor extends Failure {
  const FallaServidor([
    super.mensaje = 'El servidor tuvo un problema al procesar la solicitud.',
  ]);

  @override
  String get sugerencia =>
      'Volvé a intentar en unos minutos. Si sigue igual, avisá al equipo de sistemas.';
}

/// Respuesta con una forma que no esperábamos. Suele indicar un cambio de
/// contrato del backend, no un error del usuario.
final class FallaFormatoInesperado extends Failure {
  const FallaFormatoInesperado(super.mensaje);

  @override
  String get sugerencia =>
      'Avisá al equipo de sistemas: la respuesta del servidor no tiene el formato esperado.';
}

final class FallaDesconocida extends Failure {
  const FallaDesconocida([super.mensaje = 'Ocurrió un error inesperado.']);

  @override
  String get sugerencia => 'Volvé a intentar. Si persiste, avisá a sistemas.';
}
