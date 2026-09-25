import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';

/// Comandos de control del dictado. No son datos: se interceptan antes del
/// parseo de campos y nunca generan una propuesta de valores.
enum ComandoVoz {
  borrar(['borrar', 'limpiar', 'borra todo']),
  cancelar(['cancelar', 'cancela', 'olvida']),
  repetir(['repetir', 'repite', 'de nuevo', 'otra vez']),
  listo(['listo', 'terminar', 'termine']);

  const ComandoVoz(this.alias);

  final List<String> alias;
}

/// Resultado de interpretar una transcripción. **Nunca se aplica solo**: el
/// usuario confirma en pantalla y recién ahí impacta el formulario en memoria
/// (ADR-0005, D-6).
class PropuestaVoz {
  const PropuestaVoz({
    required this.transcripcion,
    required this.capturadaEn,
    this.campos = const [],
    this.fragmentosNoReconocidos = const [],
    this.comando,
  });

  /// Transcripción literal. Se muestra siempre, arriba del diff: el operador
  /// debe poder ver qué entendió el motor, no solo el resultado.
  final String transcripcion;

  final DateTime capturadaEn;

  final List<CampoPropuesto> campos;

  /// Fragmentos que no se pudieron interpretar. Se listan de forma explícita:
  /// un dictado entendido a medias nunca se presenta como éxito total.
  final List<String> fragmentosNoReconocidos;

  /// Comando de control detectado, si lo hubo.
  final ComandoVoz? comando;

  bool get estaVacia => campos.isEmpty;

  bool get esComando => comando != null;

  bool get tieneDudas =>
      fragmentosNoReconocidos.isNotEmpty || campos.any((c) => c.confianzaBaja);

  /// Solo los campos que el usuario dejó marcados.
  List<CampoPropuesto> get aceptados =>
      campos.where((c) => c.aceptado).toList();
}

/// Un campo individual dentro de una propuesta, con su diff y su procedencia.
class CampoPropuesto {
  const CampoPropuesto({
    required this.campo,
    required this.valorPropuesto,
    required this.textoOrigen,
    this.valorAnterior,
    this.confianza = 1,
    this.aceptado = true,
  });

  final CampoCenso campo;

  final int? valorAnterior;
  final int valorPropuesto;

  /// Confianza del motor STT, 0.0–1.0.
  final double confianza;

  /// Fragmento exacto de la transcripción que originó este valor.
  final String textoOrigen;

  /// Marcado por el usuario en la hoja de confirmación. Los campos con
  /// [confianzaBaja] llegan desmarcados.
  final bool aceptado;

  static const double umbralConfianzaBaja = 0.70;

  bool get confianzaBaja => confianza < umbralConfianzaBaja;

  /// Pisa un valor que el operador ya había tipeado. Es el caso de mayor
  /// riesgo de pérdida de dato: la UI lo destaca.
  bool get esSobrescritura => valorAnterior != null && valorAnterior != 0;

  bool get sinCambio => valorAnterior == valorPropuesto;

  CampoPropuesto copyWith({bool? aceptado}) => CampoPropuesto(
        campo: campo,
        valorPropuesto: valorPropuesto,
        textoOrigen: textoOrigen,
        valorAnterior: valorAnterior,
        confianza: confianza,
        aceptado: aceptado ?? this.aceptado,
      );

  @override
  String toString() =>
      'CampoPropuesto(${campo.name}: $valorAnterior → $valorPropuesto)';
}
