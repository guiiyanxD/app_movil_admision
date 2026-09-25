import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/validar_censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_controller.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioFalso implements CensoDiarioRepository {
  int capacidad = 38;
  int? totalDiaAnterior = 33;
  Failure? fallaAlGuardar;

  /// Censos que efectivamente llegaron al backend. Es la evidencia de que la
  /// voz no persiste sola.
  final List<CensoServicio> guardados = [];

  @override
  Future<Resultado<int>> obtenerCapacidadServicio(String servicioId) async =>
      Exito(capacidad);

  @override
  Future<Resultado<int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  }) async =>
      Exito(totalDiaAnterior);

  @override
  Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(
    DateTime fecha, {
    String? servicioId,
  }) async =>
      const Exito([]);

  @override
  Future<Resultado<CensoServicio>> guardarCensoServicio(
    CensoServicio censo,
  ) async {
    final falla = fallaAlGuardar;
    if (falla != null) return Fallo(falla);
    guardados.add(censo);
    return Exito(censo);
  }

  @override
  Future<Resultado<List<Servicio>>> obtenerServiciosActivos() async =>
      const Exito([]);

  @override
  Future<Resultado<List<MapeoVaciado>>> obtenerMapeoEspecialidades() async =>
      const Exito([]);

  @override
  Future<Resultado<CierreCenso?>> obtenerCierre(DateTime fecha) async =>
      const Exito(null);

  @override
  Future<Resultado<ProgresoDia>> obtenerProgresoDia(DateTime fecha) async =>
      Exito(ProgresoDia(fecha: fecha, servicios: const []));

  @override
  Future<Resultado<ConfirmacionDia>> confirmarDia(DateTime fecha) async =>
      const Exito(ConfirmacionDia(fecha: '2026-07-16', servicios: 0));
}

void main() {
  final ahora = DateTime.utc(2026, 7, 31, 14); // 10:00 en Bolivia
  final fecha = DateTime(2026, 7, 16);

  const servicio = Servicio(
    id: 'srv-1',
    nombre: 'Medicina Interna',
    activo: true,
    nombreVaciado: 'Medicina Interna',
  );

  late _RepositorioFalso repositorio;
  late CensoFormLogica logica;

  CensoFormLogica crear() => CensoFormLogica(
        repositorio: repositorio,
        estadoInicial: CensoFormState.inicial(
          servicio: servicio,
          fecha: fecha,
        ),
        ahora: ahora,
      );

  setUp(() {
    repositorio = _RepositorioFalso();
    logica = crear();
  });

  /// Deja el formulario cuadrando contra capacidad 38, como el EST-1 real.
  Future<void> prepararFormularioValido() async {
    await logica.cargarReferencias();
    logica
      ..cambiarCampo(CampoCenso.ingreso, 4)
      ..cambiarCampo(CampoCenso.egreso, 3)
      ..cambiarCampo(CampoCenso.total, 34)
      ..cambiarCampo(CampoCenso.libre, 2)
      ..cambiarCampo(CampoCenso.bloqueada, 1)
      ..cambiarCampo(CampoCenso.aislamiento, 1);
  }

  group('Carga de referencias', () {
    test('pasa de inicial a edición con capacidad y día anterior', () async {
      await logica.cargarReferencias();

      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.capacidad, 38);
      expect(logica.estado.totalDiaAnterior, 33);
    });
  });

  group('SPEC-003 — precarga de lo ya guardado', () {
    const camas = [
      CamaPrestada(
        especialidadId: 'esp-cirugia',
        cantidad: 1,
        tipoIngreso: TipoIngresoCamaPrestada.directo,
      ),
    ];

    /// Lo que el servidor devuelve para un servicio ya cargado.
    ///
    /// Los nueve contadores cuadran contra la capacidad 38 y contra el saldo
    /// del día anterior, como el EST-1 real: así ninguna validación tapa lo
    /// que estos tests quieren observar.
    CargaGuardada cargaGuardada({
      DateTime? fechaDelServidor,
      String servicioIdDelServidor = 'srv-1',
    }) =>
        CargaGuardada(
          censo: CensoServicio(
            fecha: fechaDelServidor ?? fecha,
            servicioId: servicioIdDelServidor,
            ingreso: 4,
            ingresoTraslado: 2,
            egreso: 3,
            egresoTraslado: 1,
            obito: 1,
            aislamiento: 1,
            bloqueada: 1,
            libre: 2,
            total: 34,
            camasPrestadas: camas,
          ),
          servicioNombre: 'Medicina Interna',
          actualizadoEn: DateTime.utc(2026, 8, 1, 22, 14, 3),
          creadoPorNombre: 'Ana Rojas',
        );

    test('los nueve campos y las camas prestadas quedan en el formulario',
        () async {
      final carga = cargaGuardada();

      await logica.cargarReferencias(cargaPrevia: carga);

      expect(logica.estado.fase, FaseFormulario.edicion);
      for (final campo in CampoCenso.values) {
        expect(
          logica.estado.censo.valorDe(campo),
          carga.censo.valorDe(campo),
          reason: campo.name,
        );
      }
      expect(logica.estado.censo.camasPrestadas, camas);
      expect(logica.estado.falloLecturaPrevia, isFalse);
      // La procedencia queda a mano para mostrar quién cargó y cuándo.
      expect(logica.estado.cargaPrevia, same(carga));
    });

    test('abrir un servicio precargado no cuenta como cambio sin guardar',
        () async {
      await logica.cargarReferencias(cargaPrevia: cargaGuardada());

      // Navegar sin tocar nada no debe preguntar por trabajo pendiente.
      expect(logica.estado.hayCambiosSinGuardar, isFalse);
      expect(logica.estado.censoPersistido, isNotNull);
    });

    test('lo precargado no llega marcado como voz', () async {
      await logica.cargarReferencias(cargaPrevia: cargaGuardada());

      // Pedir confirmación por valores que ya están persistidos sería pedir
      // revisar algo que nadie dictó.
      expect(logica.estado.tieneCamposDeVozSinRevisar, isFalse);
      for (final campo in CampoCenso.values) {
        expect(logica.estado.origenDe(campo), OrigenDato.manual);
      }
    });

    test('CA-11 — editar marca cambios y volver al valor original los limpia',
        () async {
      await logica.cargarReferencias(cargaPrevia: cargaGuardada());

      logica.cambiarCampo(CampoCenso.obito, 5);
      expect(logica.estado.hayCambiosSinGuardar, isTrue);

      logica.cambiarCampo(CampoCenso.obito, 1); // el valor precargado
      expect(logica.estado.hayCambiosSinGuardar, isFalse);
    });

    test('CA-04 — sin carga previa el formulario abre en cero y sin error',
        () async {
      await logica.cargarReferencias();

      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.censo.estaVacio, isTrue);
      expect(logica.estado.cargaPrevia, isNull);
      expect(logica.estado.censoPersistido, isNull);
      expect(logica.estado.falla, isNull);
      expect(logica.estado.falloLecturaPrevia, isFalse);
      expect(logica.estado.hayCambiosSinGuardar, isFalse);
    });

    test('CA-07 — si la lectura falló se llega a edición igual, en cero',
        () async {
      await logica.cargarReferencias(falloLectura: true);

      // Bloquear el formulario dejaría al operador sin poder trabajar por una
      // consulta auxiliar. Lo honesto es abrir en cero y decir que no se pudo
      // leer, no presentar los ceros como si fueran el estado del servidor.
      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.censo.estaVacio, isTrue);
      expect(logica.estado.falla, isNull);
      expect(logica.estado.falloLecturaPrevia, isTrue);

      logica.cambiarCampo(CampoCenso.total, 34);
      expect(logica.estado.censo.total, 34, reason: 'se puede seguir cargando');
    });

    test('tras precargar no queda sobrescritura ciega que advertir', () async {
      await logica.cargarReferencias(cargaPrevia: cargaGuardada());

      // `censoPersistido` apunta a lo precargado, así que lo que se ve en
      // pantalla es lo que hay en el servidor: no hay nada que se pueda pisar
      // sin haberlo visto, y por eso el aviso ya no existe (D-5).
      expect(logica.estado.censoPersistido, isNotNull);
      expect(
        logica.estado.censo.mismosValoresQue(logica.estado.censoPersistido),
        isTrue,
      );
    });

    test('la precarga no mueve la fecha ni el servicio del formulario',
        () async {
      // El servidor podría devolver otra fila por un desajuste de la caché:
      // lo que se guarde tiene que ir contra el día y el servicio abiertos.
      await logica.cargarReferencias(
        cargaPrevia: cargaGuardada(
          fechaDelServidor: DateTime(2026, 7, 15),
          servicioIdDelServidor: 'srv-9',
        ),
      );

      expect(logica.estado.censo.fecha, fecha);
      expect(logica.estado.censo.servicioId, servicio.id);
      expect(logica.estado.censo.total, 34, reason: 'los valores sí se toman');

      expect(await logica.guardar(), isTrue);
      expect(repositorio.guardados.single.servicioId, 'srv-1');
      expect(repositorio.guardados.single.fecha, fecha);
    });

    test('lo que se tipee mientras carga se ignora: no hay carrera', () async {
      // D-2: la precarga entra dentro de la ventana donde `cambiarCampo` no
      // hace nada. Por eso la carrera con el servidor no hay que resolverla.
      final enVuelo = logica.cargarReferencias(cargaPrevia: cargaGuardada());
      expect(logica.estado.fase, FaseFormulario.cargandoReferencias);
      logica.cambiarCampo(CampoCenso.total, 99);

      await enVuelo;

      expect(logica.estado.censo.total, 34);
      expect(logica.estado.hayCambiosSinGuardar, isFalse);
    });
  });

  group('CA-02 y CA-03 — la voz no toca el formulario sin confirmar', () {
    test('procesar una transcripción NO cambia ningún valor', () async {
      await prepararFormularioValido();
      final censoAntes = logica.estado.censo;

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos nueve, egresos ocho');

      expect(logica.estado.fase, FaseFormulario.confirmandoVoz);
      expect(logica.estado.censo.ingreso, censoAntes.ingreso);
      expect(logica.estado.censo.egreso, censoAntes.egreso);
      expect(logica.estado.propuestaPendiente!.campos, hasLength(2));
    });

    test('confirmar aplica los valores al formulario en memoria', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos nueve')
        ..confirmarPropuesta();

      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.censo.ingreso, 9);
      expect(logica.estado.origenDe(CampoCenso.ingreso), OrigenDato.voz);
      expect(logica.estado.tieneVozPendiente, isFalse);
    });

    test('descartar deja el formulario byte a byte como estaba (CA-03)',
        () async {
      await prepararFormularioValido();
      final antes = logica.estado.censo;

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos nueve, egresos ocho, óbitos siete')
        ..descartarPropuesta();

      final despues = logica.estado.censo;
      for (final campo in CampoCenso.values) {
        expect(despues.valorDe(campo), antes.valorDe(campo),
            reason: campo.name);
      }
      expect(logica.estado.tieneVozPendiente, isFalse);
    });

    test('se puede aceptar solo parte de la propuesta', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos nueve, egresos ocho')
        ..alternarCampoPropuesto(CampoCenso.egreso, aceptado: false)
        ..confirmarPropuesta();

      expect(logica.estado.censo.ingreso, 9);
      expect(logica.estado.censo.egreso, 3, reason: 'el egreso se rechazó');
    });

    test('la confianza baja llega desmarcada y no se aplica sola', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos nueve', confianza: 0.4)
        ..confirmarPropuesta();

      expect(logica.estado.censo.ingreso, 4, reason: 'no se aceptó nada');
    });

    test('un dictado sin nada reconocible vuelve a edición sin hoja', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('bla bla bla');

      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.tieneVozPendiente, isFalse);
    });

    test('cancelar la escucha no deja propuesta pendiente', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..cancelarEscucha();

      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.tieneVozPendiente, isFalse);
    });
  });

  group('CA-04 — el candado de persistencia', () {
    test('con propuesta pendiente, guardar no envía nada al backend', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos nueve');

      final guardo = await logica.guardar();

      expect(guardo, isFalse);
      expect(repositorio.guardados, isEmpty);
      expect(logica.estado.fase, FaseFormulario.confirmandoVoz);
    });

    test('desde una fase de voz, guardar es siempre un no-op', () async {
      await prepararFormularioValido();

      logica.empezarEscucha();
      expect(await logica.guardar(), isFalse);

      logica.procesarTranscripcion('ingresos nueve');
      expect(await logica.guardar(), isFalse);

      expect(repositorio.guardados, isEmpty);
    });

    test('tras confirmar la voz, recién ahí se puede guardar', () async {
      await prepararFormularioValido();

      logica
        ..empezarEscucha()
        ..procesarTranscripcion('ingresos cuatro')
        ..confirmarPropuesta();

      expect(await logica.guardar(), isTrue);
      expect(repositorio.guardados, hasLength(1));
    });
  });

  group('CA-05 — validación bloqueante impide guardar', () {
    test('un censo que no cuadra no llega al backend', () async {
      await logica.cargarReferencias();
      logica.cambiarCampo(CampoCenso.total, 1); // no cuadra contra 38

      final guardo = await logica.guardar();

      expect(guardo, isFalse);
      expect(repositorio.guardados, isEmpty);
      expect(
          logica.estado.validaciones.primeraDe('V-05')!.esBloqueante, isTrue);
    });

    test('el saldo que no cierra advierte pero deja guardar', () async {
      repositorio.totalDiaAnterior = 99; // esperado 100, se cargarán 34
      logica = crear();
      await prepararFormularioValido();

      expect(logica.estado.validaciones.primeraDe('V-07'), isNotNull);
      expect(logica.estado.validaciones.hayBloqueantes, isFalse);
      expect(await logica.guardar(), isTrue);
    });
  });

  group('Errores y reintento', () {
    test('un fallo al guardar pasa a error y conserva lo tipeado', () async {
      await prepararFormularioValido();
      repositorio.fallaAlGuardar = const FallaRed();

      final guardo = await logica.guardar();

      expect(guardo, isFalse);
      expect(logica.estado.fase, FaseFormulario.error);
      expect(logica.estado.falla, isA<FallaRed>());
      expect(logica.estado.censo.total, 34, reason: 'no se perdió nada');
    });

    test('reintentar vuelve a edición y limpia la falla', () async {
      await prepararFormularioValido();
      repositorio.fallaAlGuardar = const FallaRed();
      await logica.guardar();

      logica.reintentar();

      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.falla, isNull);
      expect(logica.estado.censo.total, 34);
    });
  });

  group('Integridad de la máquina de estados', () {
    test('una transición ilegal revienta en vez de dejar estado imposible',
        () async {
      await prepararFormularioValido();

      // `edicion → guardado` no existe: solo se llega pasando por `guardando`.
      expect(
        () => logica.registrarTransicionInvalidaParaTest(),
        throwsA(isA<TransicionInvalida>()),
      );
    });

    test('tras guardar queda en edición, listo para seguir corrigiendo',
        () async {
      await prepararFormularioValido();
      await logica.guardar();

      // Con la barra de navegación el operador se queda en la pantalla: la
      // fase debe permitir editar, no quedar congelada en `guardado`.
      expect(logica.estado.fase, FaseFormulario.edicion);
      expect(logica.estado.hayCambiosSinGuardar, isFalse);
    });

    test('editar fuera de la fase de edición se ignora', () async {
      await prepararFormularioValido();
      final antes = logica.estado.censo.ingreso;

      logica
        ..empezarEscucha()
        ..cambiarCampo(CampoCenso.ingreso, 99);

      expect(logica.estado.censo.ingreso, antes);
    });

    test('un fallo del motor de voz durante la escucha es transición legal',
        () async {
      await prepararFormularioValido();
      logica
        ..empezarEscucha()
        ..registrarFalla(const FallaDesconocida('El micrófono no respondió.'));

      expect(logica.estado.fase, FaseFormulario.error);
    });
  });
}
