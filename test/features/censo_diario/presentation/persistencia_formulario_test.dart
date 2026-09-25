import 'dart:async';

import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_controller.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble que se comporta como el servidor real en lo único que importa acá:
/// `POST /carga-manual` es un **upsert**, así que lo que se guarda es
/// exactamente lo que la próxima lectura del día tiene que devolver.
class _RepositorioFalso implements CensoDiarioRepository {
  /// Staging del servidor: fecha → `servicioId` → carga.
  final Map<DateTime, Map<String, CargaGuardada>> staging = {};

  final List<CensoServicio> guardados = [];

  /// Cuántas veces se leyó la fecha. Es lo que mide CA-05: recorrer los
  /// servicios con las flechas no debe multiplicar las peticiones.
  int lecturasDelDia = 0;

  /// Con qué `servicioId` se pidió cada lectura. D-1 exige que sea siempre
  /// `null`: se trae la fecha entera, no servicio por servicio.
  final List<String?> servicioIdsPedidos = [];

  bool fallaLaLectura = false;

  /// Si está puesto, la lectura del día no responde hasta completarlo. Sirve
  /// para dejar una carga en vuelo mientras el formulario se descarta.
  Completer<void>? lecturaEnVuelo;

  @override
  Future<Resultado<int>> obtenerCapacidadServicio(String servicioId) async =>
      const Exito(38);

  @override
  Future<Resultado<int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  }) async =>
      const Exito(33);

  @override
  Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(
    DateTime fecha, {
    String? servicioId,
  }) async {
    lecturasDelDia++;
    servicioIdsPedidos.add(servicioId);
    await lecturaEnVuelo?.future;

    if (fallaLaLectura) return const Fallo(FallaRed());
    return Exito(staging[fecha]?.values.toList() ?? const <CargaGuardada>[]);
  }

  @override
  Future<Resultado<CensoServicio>> guardarCensoServicio(
    CensoServicio censo,
  ) async {
    guardados.add(censo);

    final delDia =
        staging.putIfAbsent(censo.fecha, () => <String, CargaGuardada>{});
    delDia[censo.servicioId] = CargaGuardada(
      censo: censo,
      servicioNombre: censo.servicioId,
      actualizadoEn: DateTime.utc(2026, 8, 1, 22, 14),
      creadoPorNombre: 'Ana Rojas',
    );

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
  final fecha = DateTime(2026, 7, 16);

  const medicinaInterna = Servicio(
    id: 'srv-1',
    nombre: 'Medicina Interna',
    activo: true,
    nombreVaciado: 'Medicina Interna',
  );
  const pediatria = Servicio(
    id: 'srv-2',
    nombre: 'Pediatría',
    activo: true,
    nombreVaciado: 'Pediatria',
  );
  const cirugia = Servicio(
    id: 'srv-3',
    nombre: 'Cirugía',
    activo: true,
    nombreVaciado: 'Cirugia',
  );

  final argsUno = (fecha: fecha, servicio: medicinaInterna);
  final argsDos = (fecha: fecha, servicio: pediatria);
  final argsTres = (fecha: fecha, servicio: cirugia);

  late _RepositorioFalso repositorio;
  late ProviderContainer container;

  /// La suscripción de la pantalla al formulario que tiene abierto.
  ProviderSubscription<CensoFormState>? abierto;

  setUp(() {
    repositorio = _RepositorioFalso();
    container = ProviderContainer(
      overrides: [censoRepositoryProvider.overrideWithValue(repositorio)],
    );
  });

  tearDown(() {
    abierto?.close();
    abierto = null;
    container.dispose();
  });

  /// Deja correr las microtareas pendientes: la lectura del día,
  /// `cargarReferencias` y la recolección de providers sin observadores.
  Future<void> asentar() => Future<void>.delayed(Duration.zero);

  /// Abre un servicio como lo hace la pantalla real.
  ///
  /// La barra de navegación no apila rutas: al pasar al siguiente, el
  /// formulario anterior deja de ser observado, que es lo que dispara el
  /// `autoDispose`. Sin esta suscripción los tests no reproducirían el
  /// escenario del cliente, porque nada llegaría a descartarse.
  Future<CensoFormNotifier> abrir(ArgsFormulario args) async {
    abierto?.close();
    abierto = container.listen(censoFormProvider(args), (_, __) {});
    final notifier = container.read(censoFormProvider(args).notifier);
    await asentar();
    return notifier;
  }

  CensoFormState estadoDe(ArgsFormulario args) =>
      container.read(censoFormProvider(args));

  /// Una carga tal como la devolvería el servidor.
  ///
  /// Los nueve contadores cuadran contra la capacidad 38 del doble y contra el
  /// saldo del día anterior, para que ninguna validación bloqueante tape lo que
  /// estos tests quieren observar.
  CargaGuardada cargaGuardada(Servicio servicio, {int ingreso = 4}) =>
      CargaGuardada(
        censo: CensoServicio(
          fecha: fecha,
          servicioId: servicio.id,
          ingreso: ingreso,
          egreso: 3,
          aislamiento: 1,
          bloqueada: 1,
          libre: 2,
          total: 34,
        ),
        servicioNombre: servicio.nombre,
        actualizadoEn: DateTime.utc(2026, 8, 1, 22, 14),
        creadoPorNombre: 'Ana Rojas',
      );

  void sembrar(CargaGuardada carga) {
    repositorio.staging.putIfAbsent(
      carga.censo.fecha,
      () => <String, CargaGuardada>{},
    )[carga.censo.servicioId] = carga;
  }

  /// Deja el formulario cuadrando contra la capacidad 38, como el EST-1 real.
  void llenarCensoValido(CensoFormLogica logica) {
    logica
      ..cambiarCampo(CampoCenso.ingreso, 4)
      ..cambiarCampo(CampoCenso.egreso, 3)
      ..cambiarCampo(CampoCenso.total, 34)
      ..cambiarCampo(CampoCenso.libre, 2)
      ..cambiarCampo(CampoCenso.bloqueada, 1)
      ..cambiarCampo(CampoCenso.aislamiento, 1);
  }

  group('CA-03 — el bug del cliente del 2026-08-02 no se reproduce', () {
    test('cargar el servicio 1, avanzar al 2 y al 3, y volver al 1', () async {
      // El escenario exacto del reporte. Las flechas guardan solas cuando el
      // censo cuadra, así que al avanzar el servicio 1 queda persistido: lo que
      // fallaba era volver, no guardar.
      final uno = await abrir(argsUno);
      llenarCensoValido(uno.logica);
      expect(await uno.logica.guardar(), isTrue);

      await abrir(argsDos);
      await abrir(argsTres);

      // Vuelve con la flecha izquierda, dos servicios atrás.
      await abrir(argsUno);
      final recuperado = estadoDe(argsUno);

      expect(recuperado.censo.ingreso, 4);
      expect(recuperado.censo.egreso, 3);
      expect(recuperado.censo.total, 34);
      expect(recuperado.censo.libre, 2);
      expect(recuperado.fase, FaseFormulario.edicion);
      // Y no queda como trabajo pendiente: lo que se ve es lo que hay guardado.
      expect(recuperado.hayCambiosSinGuardar, isFalse);
      // Con la procedencia a mano, la barra puede decir "Guardado HH:mm" en
      // vez de dejar al operador adivinando (D-6).
      expect(recuperado.cargaPrevia?.actualizadoEn, isNotNull);
    });

    test('los valores vuelven del servidor, no de la memoria del proceso',
        () async {
      final uno = await abrir(argsUno);
      llenarCensoValido(uno.logica);
      await uno.logica.guardar();

      await abrir(argsDos);

      // El formulario anterior se descartó de verdad: si la caché del día se
      // vaciara, al volver no habría nada que mostrar. Es lo que hace que el
      // servidor sea la única fuente de verdad (D-3).
      expect(container.exists(censoFormProvider(argsUno)), isFalse);
      repositorio.staging.clear();
      container.invalidate(cargasDelDiaProvider(fecha));

      await abrir(argsUno);

      expect(estadoDe(argsUno).censo.estaVacio, isTrue);
    });
  });

  group('CA-05 — la fecha se pide una sola vez', () {
    test('recorrer varios servicios no genera peticiones nuevas', () async {
      await abrir(argsUno);
      await abrir(argsDos);
      await abrir(argsTres);
      await abrir(argsUno);

      expect(repositorio.lecturasDelDia, 1);
    });

    test('la lectura no filtra por servicio', () async {
      // D-1: pedir servicio por servicio costaría trece peticiones para
      // recorrer un día, sobre la red de un hospital y de noche.
      await abrir(argsUno);
      await abrir(argsDos);

      expect(repositorio.servicioIdsPedidos, [null]);
    });
  });

  group('CA-06 — guardar invalida la caché de la fecha', () {
    test('volver al servicio recién guardado muestra los valores nuevos',
        () async {
      sembrar(cargaGuardada(medicinaInterna));

      final uno = await abrir(argsUno);
      expect(estadoDe(argsUno).censo.ingreso, 4);

      uno.logica.cambiarCampo(CampoCenso.ingreso, 9);
      expect(await uno.logica.guardar(), isTrue);

      await abrir(argsDos);
      await abrir(argsUno);

      // Sin invalidar, la caché repoblaría el formulario con los valores
      // anteriores a la edición.
      expect(estadoDe(argsUno).censo.ingreso, 9);
      expect(
        repositorio.lecturasDelDia,
        2,
        reason: 'guardar tira la caché; recorrer servicios no',
      );
    });

    test('un guardado no afecta la precarga de los otros servicios', () async {
      sembrar(cargaGuardada(pediatria, ingreso: 7));

      final uno = await abrir(argsUno);
      llenarCensoValido(uno.logica);
      await uno.logica.guardar();

      await abrir(argsDos);

      expect(estadoDe(argsDos).censo.ingreso, 7);
    });
  });

  group('Precarga desde la caché', () {
    test('cada servicio recibe su propia carga, no la del vecino', () async {
      sembrar(cargaGuardada(medicinaInterna));
      sembrar(cargaGuardada(pediatria, ingreso: 9));

      await abrir(argsUno);
      expect(estadoDe(argsUno).censo.ingreso, 4);

      await abrir(argsDos);
      expect(estadoDe(argsDos).censo.ingreso, 9);
    });

    test('CA-04 — un servicio sin carga previa abre en cero y sin error',
        () async {
      // Hay carga en la fecha, pero de otro servicio: el que no aparece en la
      // respuesta simplemente no tiene nada guardado.
      sembrar(cargaGuardada(pediatria));

      await abrir(argsUno);
      final estado = estadoDe(argsUno);

      expect(estado.fase, FaseFormulario.edicion);
      expect(estado.censo.estaVacio, isTrue);
      expect(estado.cargaPrevia, isNull);
      expect(estado.falla, isNull);
      expect(estado.falloLecturaPrevia, isFalse);
      expect(estado.hayCambiosSinGuardar, isFalse);
    });

    test('CA-07 — si la lectura falla, abre en cero y lo declara', () async {
      repositorio.fallaLaLectura = true;

      await abrir(argsUno);
      final estado = estadoDe(argsUno);

      // El fallo no puede tumbar la pantalla: bloquear el formulario dejaría al
      // operador sin poder trabajar por una lectura auxiliar. Tampoco se callan
      // los ceros como si fueran el estado real del servidor.
      expect(estado.fase, FaseFormulario.edicion);
      expect(estado.censo.estaVacio, isTrue);
      expect(estado.falloLecturaPrevia, isTrue);
      expect(estado.falla, isNull);

      container
          .read(censoFormProvider(argsUno).notifier)
          .logica
          .cambiarCampo(CampoCenso.total, 34);
      expect(estadoDe(argsUno).censo.total, 34, reason: 'se sigue trabajando');
    });

    test('la caché es por fecha: otro día no hereda valores', () async {
      sembrar(cargaGuardada(medicinaInterna));
      final otroDia = (fecha: DateTime(2026, 7, 15), servicio: medicinaInterna);

      await abrir(otroDia);

      expect(estadoDe(otroDia).censo.estaVacio, isTrue);
      expect(estadoDe(otroDia).cargaPrevia, isNull);
    });
  });

  group('D-3 — el formulario ya no se retiene en memoria', () {
    test('un formulario abierto y no tocado se descarta', () async {
      container.read(censoFormProvider(argsUno));
      await asentar();

      expect(container.exists(censoFormProvider(argsUno)), isFalse);
    });

    test('un formulario con datos también se descarta', () async {
      // Antes se lo retenía con `keepAlive`. Retenerlo ahora crearía dos
      // fuentes de verdad: memoria del proceso contra servidor, y la memoria
      // ganaría por estar primero aunque otro operador hubiera editado la
      // misma fecha desde otro dispositivo.
      final uno = await abrir(argsUno);
      llenarCensoValido(uno.logica);

      abierto?.close();
      abierto = null;
      await asentar();

      expect(container.exists(censoFormProvider(argsUno)), isFalse);
    });

    test('descartarlo con la lectura en vuelo no revienta', () async {
      // El operador abre un servicio y navega antes de que responda el
      // servidor. La respuesta llega a un notifier ya muerto: escribir `state`
      // ahí reventaría, así que el guard de descarte la ignora.
      final enVuelo = Completer<void>();
      repositorio.lecturaEnVuelo = enVuelo;

      container.read(censoFormProvider(argsUno));
      await asentar();
      expect(container.exists(censoFormProvider(argsUno)), isFalse);

      enVuelo.complete();
      await asentar();

      // Y la pantalla sigue usable: reabrir el servicio funciona.
      await abrir(argsUno);
      expect(estadoDe(argsUno).fase, FaseFormulario.edicion);
    });
  });
}
