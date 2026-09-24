import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/interpretar_dictado_censo.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/validar_censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Lógica del formulario de censo, sin depender de Flutter ni de Riverpod.
///
/// Se aísla así para que la máquina de estados y el candado de la voz se
/// puedan testear como código puro. El `Notifier` de Riverpod solo delega acá.
class CensoFormLogica {
  CensoFormLogica({
    required this.repositorio,
    required CensoFormState estadoInicial,
    this.validar = const ValidarCensoServicio(),
    this.interpretar = const InterpretarDictadoCenso(),
    this.ahora,
  }) : _estado = estadoInicial;

  final CensoDiarioRepository repositorio;
  final ValidarCensoServicio validar;
  final InterpretarDictadoCenso interpretar;

  /// Inyectable para que los tests no dependan del reloj.
  final DateTime? ahora;

  CensoFormState _estado;
  CensoFormState get estado => _estado;

  /// Notifica cada cambio. Lo conecta el `Notifier` de Riverpod.
  void Function(CensoFormState)? alCambiar;

  // ── Transiciones ────────────────────────────────────────────────────────

  /// Aplica un cambio de estado validando la transición contra el grafo.
  ///
  /// Una transición ilegal es un error de programación y revienta acá, en vez
  /// de dejar el formulario en un estado imposible que después nadie explica.
  void _transicionar(FaseFormulario hacia, CensoFormState Function() construir) {
    if (_estado.fase != hacia && !puedeTransicionar(_estado.fase, hacia)) {
      throw TransicionInvalida(_estado.fase, hacia);
    }
    _estado = construir();
    alCambiar?.call(_estado);
  }

  void _actualizarEnEdicion(CensoFormState nuevo) {
    _estado = nuevo;
    alCambiar?.call(_estado);
  }

  // ── Carga de referencias ────────────────────────────────────────────────

  /// Trae capacidad y total del día anterior, aplica [cargaPrevia] si la hay y
  /// recién entonces habilita la edición.
  ///
  /// [cargaPrevia] es lo que el servicio ya tenía guardado en staging, o `null`
  /// si no tenía nada. [falloLectura] indica que esa lectura no se pudo hacer:
  /// quien llama es el que consulta, así que es el único que sabe distinguir
  /// "no había carga" de "no pude leer". Con `true` el formulario abre en cero
  /// igual —nunca queda bloqueado— y lo declara en
  /// [CensoFormState.falloLecturaPrevia] (SPEC-003, D-3 y CA-07).
  Future<void> cargarReferencias({
    CargaGuardada? cargaPrevia,
    bool falloLectura = false,
  }) async {
    _transicionar(
      FaseFormulario.cargandoReferencias,
      () => _estado.copyWith(
        fase: FaseFormulario.cargandoReferencias,
        limpiarFalla: true,
      ),
    );

    final capacidad = await repositorio.obtenerCapacidadServicio(
      _estado.servicio.id,
    );

    int? totalAnterior;
    final nombreVaciado = _estado.servicio.nombreVaciado;
    if (nombreVaciado != null) {
      final resultado = await repositorio.obtenerTotalDiaAnterior(
        fecha: _estado.censo.fecha,
        nombreVaciado: nombreVaciado,
      );
      totalAnterior = resultado.valorONulo;
    }

    // Que falle la capacidad no impide editar: V-05 degrada a advertencia y el
    // backend rechazará si de verdad no cuadra.
    _transicionar(
      FaseFormulario.edicion,
      () => _revalidar(
        _conCargaPrevia(cargaPrevia).copyWith(
          fase: FaseFormulario.edicion,
          capacidad: capacidad.valorONulo,
          totalDiaAnterior: totalAnterior,
          falloLecturaPrevia: falloLectura,
        ),
      ),
    );
  }

  /// Vuelca lo ya guardado sobre el formulario, todavía en
  /// [FaseFormulario.cargandoReferencias].
  ///
  /// La precarga entra dentro de la ventana donde `cambiarCampo` ignora la
  /// entrada. Así la carrera entre lo que el operador tipea y lo que responde
  /// el servidor no hay que resolverla: no puede ocurrir (SPEC-003, D-2).
  CensoFormState _conCargaPrevia(CargaGuardada? cargaPrevia) {
    if (cargaPrevia == null) return _estado;

    // La fecha y el servicio los manda el formulario, no la respuesta: son el
    // servicio y el día que el operador abrió. Tomarlos del servidor dejaría
    // que un desajuste de la caché guardara lo editado contra otra fila.
    final precargado = cargaPrevia.censo.copyWith(
      fecha: _estado.censo.fecha,
      servicioId: _estado.censo.servicioId,
    );

    // `origenes` queda intacto —todos manuales—: lo precargado se transcribió
    // del papel en su momento, no salió de un dictado sin revisar, y marcarlo
    // como voz pediría confirmar de nuevo algo que ya está persistido.
    return _estado.copyWith(
      censo: precargado,
      // La referencia contra la que se detectan cambios es lo precargado: al
      // abrir no hay nada sin guardar y el primer tecleo lo marca (CA-11).
      censoPersistido: precargado,
      cargaPrevia: cargaPrevia,
    );
  }

  // ── Edición manual ──────────────────────────────────────────────────────

  void cambiarCampo(CampoCenso campo, int valor) {
    if (_estado.fase != FaseFormulario.edicion) return;

    _actualizarEnEdicion(
      _revalidar(
        _estado.copyWith(
          censo: _estado.censo.conCampo(campo, valor),
          origenes: {..._estado.origenes, campo: OrigenDato.manual},
        ),
      ),
    );
  }

  void reemplazarCamasPrestadas(List<CamaPrestada> camas) {
    if (_estado.fase != FaseFormulario.edicion) return;

    _actualizarEnEdicion(
      _revalidar(
        _estado.copyWith(censo: _estado.censo.copyWith(camasPrestadas: camas)),
      ),
    );
  }

  CensoFormState _revalidar(CensoFormState estado) => estado.copyWith(
        validaciones: validar.ejecutar(
          censo: estado.censo,
          capacidad: estado.capacidad,
          totalDiaAnterior: estado.totalDiaAnterior,
          servicioTieneMapeo: estado.servicio.tieneMapeo,
          ahora: ahora,
        ),
      );

  // ── Dictado ─────────────────────────────────────────────────────────────

  void empezarEscucha() {
    _transicionar(
      FaseFormulario.escuchandoVoz,
      () => _estado.copyWith(
        fase: FaseFormulario.escuchandoVoz,
        transcripcionParcial: '',
        limpiarFalla: true,
      ),
    );
  }

  /// Refleja en pantalla lo que el motor va entendiendo.
  ///
  /// **No toca ningún campo del censo.** Es retroalimentación: el valor solo
  /// llega al formulario si el operador confirma la propuesta.
  void actualizarTranscripcionParcial(String texto) {
    if (_estado.fase != FaseFormulario.escuchandoVoz) return;
    _estado = _estado.copyWith(transcripcionParcial: texto);
    alCambiar?.call(_estado);
  }

  void cancelarEscucha() {
    _transicionar(
      FaseFormulario.edicion,
      () => _estado.copyWith(
        fase: FaseFormulario.edicion,
        transcripcionParcial: '',
        limpiarPropuesta: true,
      ),
    );
  }

  /// Procesa la transcripción final del motor de voz.
  ///
  /// **No aplica nada al formulario.** Construye la propuesta y pasa a
  /// [FaseFormulario.confirmandoVoz], que espera decisión del usuario.
  void procesarTranscripcion(String transcripcion, {double confianza = 1}) {
    _transicionar(
      FaseFormulario.procesandoVoz,
      () => _estado.copyWith(fase: FaseFormulario.procesandoVoz),
    );

    final propuesta = interpretar.interpretar(
      transcripcion,
      valoresActuales: {
        for (final campo in CampoCenso.values)
          campo: _estado.censo.valorDe(campo),
      },
      confianza: confianza,
      ahora: ahora,
    );

    // Un comando o un dictado sin nada reconocible vuelve a edición sin
    // molestar al operador con una hoja vacía.
    if (propuesta.estaVacia) {
      _transicionar(
        FaseFormulario.edicion,
        () => _estado.copyWith(
          fase: FaseFormulario.edicion,
          limpiarPropuesta: true,
        ),
      );
      return;
    }

    _transicionar(
      FaseFormulario.confirmandoVoz,
      () => _estado.copyWith(
        fase: FaseFormulario.confirmandoVoz,
        propuestaPendiente: propuesta,
      ),
    );
  }

  /// Marca o desmarca un campo dentro de la propuesta, sin aplicarlo.
  void alternarCampoPropuesto(CampoCenso campo, {required bool aceptado}) {
    final propuesta = _estado.propuestaPendiente;
    if (propuesta == null) return;

    final campos = propuesta.campos
        .map((c) => c.campo == campo ? c.copyWith(aceptado: aceptado) : c)
        .toList();

    _estado = _estado.copyWith(
      propuestaPendiente: PropuestaVoz(
        transcripcion: propuesta.transcripcion,
        capturadaEn: propuesta.capturadaEn,
        campos: campos,
        fragmentosNoReconocidos: propuesta.fragmentosNoReconocidos,
        comando: propuesta.comando,
      ),
    );
    alCambiar?.call(_estado);
  }

  /// Aplica al formulario **en memoria** los campos aceptados. No persiste.
  void confirmarPropuesta() {
    final propuesta = _estado.propuestaPendiente;
    if (propuesta == null) return;

    var censo = _estado.censo;
    final origenes = {..._estado.origenes};

    for (final campo in propuesta.aceptados) {
      censo = censo.conCampo(campo.campo, campo.valorPropuesto);
      origenes[campo.campo] = OrigenDato.voz;
    }

    _transicionar(
      FaseFormulario.edicion,
      () => _revalidar(
        _estado.copyWith(
          fase: FaseFormulario.edicion,
          censo: censo,
          origenes: origenes,
          limpiarPropuesta: true,
        ),
      ),
    );
  }

  /// Descarta la propuesta. El formulario queda exactamente como estaba.
  void descartarPropuesta() {
    _transicionar(
      FaseFormulario.edicion,
      () => _estado.copyWith(
        fase: FaseFormulario.edicion,
        limpiarPropuesta: true,
      ),
    );
  }

  // ── Persistencia ────────────────────────────────────────────────────────

  /// Guarda en el backend. Devuelve `true` si se guardó.
  ///
  /// El candado está en [CensoFormState.puedeGuardar]: si hay una propuesta de
  /// voz sin resolver o una validación bloqueante, no sale ni la petición.
  Future<bool> guardar() async {
    if (!_estado.puedeGuardar) return false;

    _transicionar(
      FaseFormulario.guardando,
      () => _estado.copyWith(
        fase: FaseFormulario.guardando,
        limpiarFalla: true,
      ),
    );

    final resultado = await repositorio.guardarCensoServicio(_estado.censo);

    return resultado.fold(
      (falla) {
        _transicionar(
          FaseFormulario.error,
          () => _estado.copyWith(fase: FaseFormulario.error, falla: falla),
        );
        return false;
      },
      (guardado) {
        _transicionar(
          FaseFormulario.guardado,
          () => _estado.copyWith(
            fase: FaseFormulario.guardado,
            censo: guardado,
            // Nueva referencia contra la que se detectan los cambios que
            // vengan: a partir de acá lo que hay en el servidor es exactamente
            // lo que se ve en pantalla.
            censoPersistido: guardado,
          ),
        );

        // Volver a edición de inmediato. Desde que el formulario tiene flechas
        // de navegación, el operador se queda en la pantalla después de
        // guardar: si la fase quedara en `guardado`, `cambiarCampo` ignoraría
        // sus correcciones y el formulario parecería congelado. La
        // confirmación de guardado la da el snackbar, no la fase.
        _transicionar(
          FaseFormulario.edicion,
          () => _estado.copyWith(fase: FaseFormulario.edicion),
        );
        return true;
      },
    );
  }

  /// Vuelve a edición tras un error, conservando lo tipeado.
  void reintentar() {
    _transicionar(
      FaseFormulario.edicion,
      () => _estado.copyWith(fase: FaseFormulario.edicion, limpiarFalla: true),
    );
  }

  void registrarFalla(Failure falla) {
    _transicionar(
      FaseFormulario.error,
      () => _estado.copyWith(fase: FaseFormulario.error, falla: falla),
    );
  }

  /// Solo para tests: intenta `edicion → guardado`, que el grafo no permite.
  ///
  /// Existe para comprobar que la máquina rechaza una transición ilegal en vez
  /// de aceptarla en silencio. Ninguna ruta de producción la invoca.
  @visibleForTesting
  void registrarTransicionInvalidaParaTest() {
    _transicionar(
      FaseFormulario.guardado,
      () => _estado.copyWith(fase: FaseFormulario.guardado),
    );
  }
}
