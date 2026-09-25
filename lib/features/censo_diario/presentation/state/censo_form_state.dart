import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/validar_censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';

/// De dónde salió el valor de un campo. Determina si necesita confirmación y
/// si la UI lo marca para revisión visual antes de guardar.
enum OrigenDato { manual, voz, calculado }

class CensoFormState {
  const CensoFormState({
    required this.fase,
    required this.servicio,
    required this.censo,
    this.origenes = const {},
    this.capacidad,
    this.totalDiaAnterior,
    this.validaciones = const [],
    this.propuestaPendiente,
    this.falla,
    this.censoPersistido,
    this.cargaPrevia,
    this.falloLecturaPrevia = false,
    this.transcripcionParcial = '',
  });

  factory CensoFormState.inicial({
    required Servicio servicio,
    required DateTime fecha,
  }) =>
      CensoFormState(
        fase: FaseFormulario.inicial,
        servicio: servicio,
        censo: CensoServicio(fecha: fecha, servicioId: servicio.id),
      );

  final FaseFormulario fase;
  final Servicio servicio;
  final CensoServicio censo;

  /// Procedencia por campo. Un campo ausente del mapa es manual.
  final Map<CampoCenso, OrigenDato> origenes;

  /// Capacidad de camas del servicio. `null` si no se pudo consultar.
  final int? capacidad;

  /// Saldo de cierre del día anterior. `null` si esa fecha no tiene fila, que
  /// durante el backfill es normal.
  final int? totalDiaAnterior;

  final List<ValidacionCenso> validaciones;

  /// Propuesta de voz esperando decisión. No-null implica que hay datos sin
  /// confirmar y que **nada se puede guardar** todavía.
  final PropuestaVoz? propuestaPendiente;

  final Failure? falla;

  /// Lo último que el servidor confirmó tener: la carga precargada al abrir o
  /// lo que devolvió el último guardado.
  ///
  /// Es la referencia contra la que se miden los cambios sin guardar. Queda en
  /// `null` solo si el servicio no tenía carga previa y todavía no se guardó
  /// nada en esta sesión.
  final CensoServicio? censoPersistido;

  /// La carga que el servidor ya tenía y con la que se precargó el formulario.
  /// `null` si este servicio no tenía nada guardado para esta fecha.
  ///
  /// Los valores ya están aplicados en [censo]: esto conserva la
  /// **procedencia** —quién cargó y cuándo— para poder mostrarla antes de que
  /// alguien reemplace el trabajo de otro (SPEC-003, D-5).
  final CargaGuardada? cargaPrevia;

  /// No se pudo leer lo guardado, así que el formulario abrió en cero aunque
  /// el servicio pudiera tener carga previa.
  ///
  /// Se expone para poder avisarlo: es peor que precargar, pero preferible a
  /// presentar ceros como si fueran el estado real del servidor (SPEC-003, D-3
  /// y CA-07).
  final bool falloLecturaPrevia;

  /// Lo que el motor va entendiendo mientras se habla. Se muestra en vivo y no
  /// toca ningún campo del censo: es solo retroalimentación.
  final String transcripcionParcial;

  bool get tieneVozPendiente => propuestaPendiente != null;

  /// Hay trabajo en pantalla que no llegó al servidor.
  ///
  /// Un formulario vacío que nunca se guardó no cuenta como cambio: navegar
  /// entre servicios sin tocar nada no debería preguntar nada.
  bool get hayCambiosSinGuardar {
    if (censoPersistido == null) return !censo.estaVacio;
    return !censo.mismosValoresQue(censoPersistido);
  }

  bool get cargando =>
      fase == FaseFormulario.cargandoReferencias ||
      fase == FaseFormulario.guardando;

  OrigenDato origenDe(CampoCenso campo) => origenes[campo] ?? OrigenDato.manual;

  bool get tieneCamposDeVozSinRevisar =>
      origenes.values.any((o) => o == OrigenDato.voz);

  /// Candado de guardado.
  ///
  /// Las tres condiciones son independientes y ninguna es redundante:
  /// - solo se guarda desde [FaseFormulario.edicion];
  /// - nunca con una propuesta de voz sin resolver;
  /// - nunca con una validación bloqueante pendiente.
  bool get puedeGuardar =>
      fase == FaseFormulario.edicion &&
      !tieneVozPendiente &&
      !validaciones.hayBloqueantes;

  bool get cuadra => capacidad != null && censo.cuadraCon(capacidad!);

  /// Diferencia entre la suma de estados de cama y la capacidad. `null` si no
  /// se conoce la capacidad.
  int? get desvioDeCuadre =>
      capacidad == null ? null : censo.sumaEstadosCama - capacidad!;

  int? get saldoEsperado =>
      totalDiaAnterior == null ? null : censo.saldoEsperado(totalDiaAnterior!);

  /// Camas libres deducidas de la capacidad, o `null` si no corresponde
  /// ofrecerlas.
  ///
  /// Se calla en cuatro situaciones, y cada una por su motivo:
  /// - sin capacidad conocida, no hay de dónde deducirla;
  /// - con el formulario intacto, sugeriría la capacidad entera como ruido de
  ///   apertura;
  /// - si el cálculo da negativo, el problema está en los otros campos y de eso
  ///   ya se ocupa V-05 con números concretos;
  /// - si coincide con lo tipeado, no hay nada que sugerir.
  int? get camasLibresSugeridas {
    if (capacidad == null || censo.estaVacio) return null;

    final sugerida = censo.camasLibresSegunCapacidad(capacidad);
    if (sugerida == null || sugerida < 0) return null;
    if (sugerida == censo.libre) return null;

    return sugerida;
  }

  CensoFormState copyWith({
    FaseFormulario? fase,
    Servicio? servicio,
    CensoServicio? censo,
    Map<CampoCenso, OrigenDato>? origenes,
    int? capacidad,
    int? totalDiaAnterior,
    List<ValidacionCenso>? validaciones,
    PropuestaVoz? propuestaPendiente,
    Failure? falla,
    CensoServicio? censoPersistido,
    CargaGuardada? cargaPrevia,
    bool? falloLecturaPrevia,
    String? transcripcionParcial,
    bool limpiarPropuesta = false,
    bool limpiarFalla = false,
  }) {
    return CensoFormState(
      fase: fase ?? this.fase,
      servicio: servicio ?? this.servicio,
      censo: censo ?? this.censo,
      origenes: origenes ?? this.origenes,
      capacidad: capacidad ?? this.capacidad,
      totalDiaAnterior: totalDiaAnterior ?? this.totalDiaAnterior,
      validaciones: validaciones ?? this.validaciones,
      propuestaPendiente: limpiarPropuesta
          ? null
          : propuestaPendiente ?? this.propuestaPendiente,
      falla: limpiarFalla ? null : falla ?? this.falla,
      censoPersistido: censoPersistido ?? this.censoPersistido,
      cargaPrevia: cargaPrevia ?? this.cargaPrevia,
      falloLecturaPrevia: falloLecturaPrevia ?? this.falloLecturaPrevia,
      transcripcionParcial: transcripcionParcial ?? this.transcripcionParcial,
    );
  }
}
