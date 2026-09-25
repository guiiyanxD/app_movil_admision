/// Fases del formulario de censo y las transiciones legales entre ellas.
///
/// ## El invariante que sostiene todo el módulo
///
/// **No existe ninguna arista desde una fase de voz hacia [guardando].** Es
/// imposible, por construcción, que un valor dictado llegue al API sin pasar
/// por [edicion], y a [edicion] solo se entra desde [confirmandoVoz] mediante
/// una acción explícita del usuario.
///
/// Eso son dos compuertas, no una: confirmar la propuesta de voz la aplica al
/// formulario en memoria, y recién un segundo gesto deliberado —"Guardar
/// servicio"— la persiste (ADR-0005, D-6).
///
/// El invariante se verifica enumerando todas las transiciones en
/// `test/features/censo_diario/presentation/fase_formulario_test.dart`
/// (criterio CA-04 de SPEC-002), no por revisión de código.
library;

enum FaseFormulario {
  inicial,
  cargandoReferencias,
  edicion,
  escuchandoVoz,
  procesandoVoz,

  /// Pre-carga visible: el diff de la propuesta espera decisión del usuario.
  /// Nada se ha aplicado al formulario todavía.
  confirmandoVoz,

  guardando,
  guardado,
  error;

  /// Fases en las que hay datos originados en voz sin confirmar.
  bool get esFaseDeVoz =>
      this == escuchandoVoz || this == procesandoVoz || this == confirmandoVoz;
}

/// Grafo de transiciones permitidas. Única fuente de verdad.
const Map<FaseFormulario, Set<FaseFormulario>> transicionesPermitidas = {
  FaseFormulario.inicial: {
    FaseFormulario.cargandoReferencias,
  },
  FaseFormulario.cargandoReferencias: {
    FaseFormulario.edicion,
    FaseFormulario.error,
  },
  FaseFormulario.edicion: {
    FaseFormulario.escuchandoVoz,
    FaseFormulario.guardando,
    FaseFormulario.error,
  },
  FaseFormulario.escuchandoVoz: {
    FaseFormulario.procesandoVoz,
    // Cancelar el dictado devuelve al formulario intacto.
    FaseFormulario.edicion,
    FaseFormulario.error,
  },
  FaseFormulario.procesandoVoz: {
    FaseFormulario.confirmandoVoz,
    // Dictado sin nada reconocible: se vuelve sin proponer nada.
    FaseFormulario.edicion,
    FaseFormulario.error,
  },
  FaseFormulario.confirmandoVoz: {
    // Única salida: aceptar, aceptar en parte o descartar. Las tres
    // desembocan en edicion, y ninguna persiste nada por sí sola.
    FaseFormulario.edicion,
  },
  FaseFormulario.guardando: {
    FaseFormulario.guardado,
    FaseFormulario.error,
  },
  FaseFormulario.guardado: {
    FaseFormulario.edicion,
  },
  FaseFormulario.error: {
    // Reintentar conserva los valores ya tipeados.
    FaseFormulario.edicion,
    FaseFormulario.cargandoReferencias,
  },
};

bool puedeTransicionar(FaseFormulario desde, FaseFormulario hacia) =>
    transicionesPermitidas[desde]?.contains(hacia) ?? false;

/// Se lanza al intentar una transición ilegal. Es un error de programación,
/// no una condición de negocio: nunca debería alcanzar al usuario.
class TransicionInvalida extends StateError {
  TransicionInvalida(this.desde, this.hacia)
      : super('Transición no permitida: ${desde.name} → ${hacia.name}');

  final FaseFormulario desde;
  final FaseFormulario hacia;
}
