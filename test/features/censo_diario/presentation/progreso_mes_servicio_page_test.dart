import 'dart:async';

import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/core/voz/servicio_dictado.dart';
import 'package:app_movil/core/voz/voz_providers.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/censo_servicio_form_page.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/progreso_mes_servicio_page.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoFalso implements CensoDiarioRepository {
  @override
  Future<Resultado<int>> obtenerCapacidadServicio(String servicioId) async =>
      const Exito(40);

  @override
  Future<Resultado<int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  }) async =>
      const Exito(35);

  @override
  Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(
    DateTime fecha, {
    String? servicioId,
  }) async =>
      const Exito([]);

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
      throw UnimplementedError();
}

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

const _servicioTest = Servicio(
  id: 'srv-1',
  nombre: 'Medicina Interna',
  nombreVaciado: 'Medicina',
  activo: true,
);

void main() {
  testWidgets('ProgresoMesServicioPage renderiza días y servicio',
      (tester) async {
    final repo = _RepoFalso();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          censoRepositoryProvider.overrideWithValue(repo),
          puedeEscribirProvider.overrideWithValue(true),
          servicioDictadoProvider.overrideWithValue(_DictadoFalso()),
        ],
        child: const MaterialApp(
          home: ProgresoMesServicioPage(
            servicio: _servicioTest,
            anho: 2026,
            mes: 7, // Julio tiene 31 días y en 2026-09 ya pasó
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Medicina Interna'), findsWidgets);
    expect(find.text('Julio de 2026'), findsOneWidget);
    expect(find.text('31 días en el mes'), findsOneWidget);
    expect(find.text('Comenzar Carga desde Día 1 (1 Tap)'), findsOneWidget);

    // Debe mostrar la lista de días
    expect(find.text('DÍAS DEL MES (31)'), findsOneWidget);
  });

  testWidgets('CensoServicioFormPage.porDias abre en modo mensual por días',
      (tester) async {
    final repo = _RepoFalso();
    final fechas = [
      DateTime.utc(2026, 7, 1),
      DateTime.utc(2026, 7, 2),
      DateTime.utc(2026, 7, 3),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          censoRepositoryProvider.overrideWithValue(repo),
          puedeEscribirProvider.overrideWithValue(true),
          servicioDictadoProvider.overrideWithValue(_DictadoFalso()),
        ],
        child: MaterialApp(
          home: CensoServicioFormPage.porDias(
            servicio: _servicioTest,
            fechas: fechas,
            indiceInicial: 0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Medicina Interna'), findsOneWidget);
    expect(find.text('Día 1 (1 de 3)'), findsOneWidget);
    expect(find.text('Guardar día 1'), findsOneWidget);
  });
}
