import 'dart:async';

import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/core/voz/servicio_dictado.dart';
import 'package:app_movil/core/voz/voz_providers.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/censo_servicio_form_page.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioFalso implements CensoDiarioRepository {
  /// Lo que el servidor tiene en staging para la fecha del test.
  final List<CargaGuardada> staging = [];

  bool fallaLaLectura = false;

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
    if (fallaLaLectura) return const Fallo(FallaRed());
    return Exito(staging);
  }

  @override
  Future<Resultado<CensoServicio>> guardarCensoServicio(
    CensoServicio censo,
  ) async =>
      Exito(censo);

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

/// Motor de voz inerte: la pantalla se suscribe al nivel de sonido en
/// `initState` y sin esto el test tocaría el plugin real.
class _DictadoFalso implements ServicioDictado {
  final _nivel = StreamController<double>.broadcast();
  final _eventos = StreamController<EventoDictado>.broadcast();

  @override
  Future<EstadoDictado> inicializar() async => EstadoDictado.noDisponible;

  @override
  Future<void> escuchar({
    required void Function(ResultadoDictado) alResultado,
    required void Function(String) alError,
    void Function()? alDetenerse,
    Duration? silencioMaximo,
    Duration? duracionMaxima,
  }) async {}

  @override
  Future<void> detener() async {}

  @override
  Future<void> cancelar() async {}

  @override
  EstadoDictado get estado => EstadoDictado.noInicializado;

  @override
  String? get localeSeleccionada => null;

  @override
  List<String> get localesDisponibles => const [];

  @override
  Stream<double> get nivelDeSonido => _nivel.stream;

  @override
  Stream<EventoDictado> get eventos => _eventos.stream;

  @override
  DateTime? get inicioEscucha => null;

  @override
  void dispose() {
    _nivel.close();
    _eventos.close();
  }
}

void main() {
  final fecha = DateTime(2026, 7, 16);

  const medicinaInterna = Servicio(
    id: 'srv-1',
    nombre: 'Medicina Interna',
    activo: true,
    nombreVaciado: 'Medicina Interna',
  );

  // Hoy a las 18:14 locales, en UTC como lo manda el servidor. Se ancla al día
  // en curso para que la línea de procedencia se rinda como `HH:mm` pelado sin
  // tener que inyectarle el reloj a toda la pantalla.
  final hoy = DateTime.now();
  final actualizadoEn = DateTime(hoy.year, hoy.month, hoy.day, 18, 14).toUtc();

  // Carga que cuadra contra la capacidad 38 y contra el saldo del día anterior:
  // así ninguna validación bloqueante tapa lo que se quiere mirar.
  final cargaPrevia = CargaGuardada(
    censo: CensoServicio(
      fecha: fecha,
      servicioId: medicinaInterna.id,
      ingreso: 4,
      egreso: 3,
      aislamiento: 1,
      bloqueada: 1,
      libre: 2,
      total: 34,
    ),
    servicioNombre: medicinaInterna.nombre,
    actualizadoEn: actualizadoEn,
    creadoPorNombre: 'Ana Rojas',
  );

  Sesion sesionCon(RolUsuario rol) => Sesion(
        accessToken: 'a',
        refreshToken: 'r',
        usuario: UsuarioSesion(
          id: 'u-1',
          nombreCompleto: 'Quien mira',
          email: 'mira@cps.bo',
          rol: rol,
        ),
      );

  late _RepositorioFalso repositorio;

  setUp(() => repositorio = _RepositorioFalso());

  Future<void> montar(
    WidgetTester tester, {
    RolUsuario rol = RolUsuario.operador,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          censoRepositoryProvider.overrideWithValue(repositorio),
          servicioDictadoProvider.overrideWithValue(_DictadoFalso()),
          // El formulario ya no pregunta por la sesión: pregunta si se puede
          // escribir. La respuesta la arma `bootstrap()` a partir del rol
          // (SPEC-005, H-8).
          puedeEscribirProvider.overrideWithValue(
            sesionCon(rol).puedeEscribir,
          ),
        ],
        child: MaterialApp(
          home: CensoServicioFormPage(
            fecha: fecha,
            servicios: const [medicinaInterna],
            indiceInicial: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton botonGuardar(WidgetTester tester) => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar servicio'),
      );

  testWidgets('CA-08 — un servicio con carga previa muestra quién y cuándo',
      (tester) async {
    repositorio.staging.add(cargaPrevia);

    await montar(tester);

    expect(find.text('Cargado por Ana Rojas · 18:14'), findsOneWidget);
  });

  testWidgets('CA-09 — sin cambios pendientes la barra dice cuándo se guardó',
      (tester) async {
    repositorio.staging.add(cargaPrevia);

    await montar(tester);

    // Es la respuesta al reporte del cliente: las flechas guardan solas y él no
    // lo percibía. Ahora el estado está a la vista mientras dura la pantalla.
    expect(find.text('Guardado 18:14'), findsOneWidget);
    expect(find.text('Sin guardar'), findsNothing);
  });

  testWidgets('CA-07 — si la lectura falla, la pantalla lo declara',
      (tester) async {
    repositorio.fallaLaLectura = true;

    await montar(tester);

    // Contrapartida de haber retirado el `keepAlive`: se prefiere un fallo
    // explícito a presentar ceros como si fueran el estado del servidor.
    expect(find.text('No se pudo leer lo guardado'), findsOneWidget);
    expect(find.textContaining('Cargado por'), findsNothing);
  });

  testWidgets('sin carga previa no hay procedencia ni aviso', (tester) async {
    await montar(tester);

    expect(find.textContaining('Cargado por'), findsNothing);
    expect(find.text('No se pudo leer lo guardado'), findsNothing);
  });

  testWidgets('CA-12 — con rol lectura no se puede guardar, pero se ve todo',
      (tester) async {
    repositorio.staging.add(cargaPrevia);

    await montar(tester, rol: RolUsuario.lectura);

    // La precarga y su procedencia son consulta: no dependen del permiso de
    // escritura.
    expect(find.text('Cargado por Ana Rojas · 18:14'), findsOneWidget);
    // El indicador de cuadre solo puede decir esto si los nueve valores
    // llegaron: con el formulario en cero la suma no daría la capacidad.
    expect(find.text('El censo cuadra'), findsOneWidget);

    expect(botonGuardar(tester).onPressed, isNull);
    expect(
      find.textContaining('Tu cuenta es de consulta'),
      findsOneWidget,
    );
  });

  testWidgets('con rol operador el mismo formulario sí se puede guardar',
      (tester) async {
    repositorio.staging.add(cargaPrevia);

    await montar(tester);

    // Contraprueba de CA-12: el botón deshabilitado viene del rol, no de una
    // validación que estuviera bloqueando de todos modos.
    expect(botonGuardar(tester).onPressed, isNotNull);
  });
}
