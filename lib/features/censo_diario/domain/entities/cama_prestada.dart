import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';

/// Registro de camas prestadas de un servicio en una fecha.
///
/// Semántica fijada en ADR-0005 (D-5), verificada contra la query canónica
/// `construirFilasCamasPrestadas`:
///
/// - El servicio dueño de la cama es el del EST-1 que se está llenando.
/// - [especialidadId] es la especialidad **del paciente**, distinta de la
///   especialidad nativa de la cama. En la anotación "Cir = 1" del formulario:
///   el paciente es de Cirugía y ocupa una cama de Medicina Interna.
/// - Es un **flujo**: cuenta estancias que empiezan ese día, igual que los
///   contadores de ingreso. No es ocupación al cierre.
///
/// **No participa en ninguna fórmula.** No afecta el saldo, la dotación ni el
/// cuadre contra la capacidad. Solo se registra.
class CamaPrestada {
  const CamaPrestada({
    required this.especialidadId,
    required this.cantidad,
    required this.tipoIngreso,
  });

  final String especialidadId;

  /// Cantidad de pacientes con esta combinación. Siempre `>= 1`.
  final int cantidad;

  final TipoIngresoCamaPrestada tipoIngreso;

  /// Clave de unicidad que exige el backend: no puede repetirse la combinación
  /// especialidad + tipo de ingreso, o responde 400.
  String get claveUnicidad => '$especialidadId::${tipoIngreso.valorApi}';

  CamaPrestada copyWith({
    String? especialidadId,
    int? cantidad,
    TipoIngresoCamaPrestada? tipoIngreso,
  }) {
    return CamaPrestada(
      especialidadId: especialidadId ?? this.especialidadId,
      cantidad: cantidad ?? this.cantidad,
      tipoIngreso: tipoIngreso ?? this.tipoIngreso,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CamaPrestada &&
          other.especialidadId == especialidadId &&
          other.cantidad == cantidad &&
          other.tipoIngreso == tipoIngreso;

  @override
  int get hashCode => Object.hash(especialidadId, cantidad, tipoIngreso);

  @override
  String toString() =>
      'CamaPrestada($especialidadId, $cantidad, ${tipoIngreso.valorApi})';
}
