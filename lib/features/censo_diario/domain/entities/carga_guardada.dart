import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';

/// Una carga de staging leída del servidor: el [CensoServicio] más su
/// procedencia.
///
/// Existe para precargar el formulario con lo que ya está guardado, en lugar de
/// abrirlo en cero y arriesgar que el upsert pise una carga que nadie vio.
///
/// **Por qué los metadatos no van dentro de [CensoServicio]:** esa entidad
/// representa lo que se *envía* al servidor. Sumarle campos que nunca viajan la
/// convertiría en un contenedor mixto y volvería ambigua `mismosValoresQue`,
/// que hoy decide si hay cambios sin guardar: dos censos con los mismos nueve
/// contadores pero distinta hora de actualización dejarían de ser "iguales" sin
/// que el operador haya tocado nada (SPEC-003, §4.2).
class CargaGuardada {
  const CargaGuardada({
    required this.censo,
    required this.servicioNombre,
    this.actualizadoEn,
    this.creadoPorNombre,
  });

  final CensoServicio censo;

  /// Nombre del servicio resuelto por el servidor. Evita cruzar contra el
  /// catálogo solo para poder nombrar lo que se está mostrando.
  final String servicioNombre;

  /// Cuándo y quién (D-5). `null` si el backend no los envía: se pierde la
  /// línea de procedencia, no la posibilidad de editar el censo.
  final DateTime? actualizadoEn;
  final String? creadoPorNombre;
}
