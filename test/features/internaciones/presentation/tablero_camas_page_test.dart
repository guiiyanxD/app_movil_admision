import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/auth/domain/entities/sesion.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/domain/repositories/camas_repository.dart';
import 'package:app_movil/features/internaciones/presentation/pages/tablero_camas_page.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCamasRepository extends Mock implements CamasRepository {}

void main() {
  group('TableroCamasPage Widget Test', () {
    const sesionMock = Sesion(
      accessToken: 'token',
      refreshToken: 'refresh',
      usuario: UsuarioSesion(
        id: 'usr-1',
        nombreCompleto: 'Dr. Alejandro Vaca',
        email: 'alejandro@censo.local',
        rol: RolUsuario.admin,
      ),
    );

    final listaCamasPrueba = <CamaTablero>[
      const CamaTablero(
        id: 'c-1',
        codigo: '101-A',
        estadoBase: 'disponible',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
      ),
      CamaTablero(
        id: 'c-2',
        codigo: '102-B',
        estadoBase: 'disponible',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
        bedStayId: 'bs-1',
        bedStayEspecialidadId: 'e-1',
        internacionId: 'i-1',
        pacienteNombre: 'Mamani Ramos, Elena',
        matricula: '76-5432-EMR',
        fechaIngreso: DateTime.now().subtract(const Duration(days: 3)),
      ),
      CamaTablero(
        id: 'c-3',
        codigo: '201-A',
        estadoBase: 'disponible',
        servicioId: 's-2',
        servicioNombre: 'Cirugía Varones',
        especialidadNativaId: 'e-2',
        especialidadNombre: 'Cirugía General',
        bedStayId: 'bs-2',
        bedStayEspecialidadId: 'e-3', // Prestada
        internacionId: 'i-2',
        pacienteNombre: 'Perez Gomez, Jorge',
        matricula: '65-9876-JPG',
        fechaIngreso: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    testWidgets('renderiza camas, métricas en AppBar y leyenda',
        (tester) async {
      final mockRepo = _MockCamasRepository();
      when(mockRepo.obtenerTablero)
          .thenAnswer((_) async => Exito(listaCamasPrueba));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            camasRepositoryProvider.overrideWithValue(mockRepo),
            sesionActivaProvider.overrideWithValue(sesionMock),
          ],
          child: const MaterialApp(home: TableroCamasPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica título y conteo general de camas (2 de 3 ocupadas = 67%)
      expect(find.text('Tablero de Camas'), findsOneWidget);
      expect(find.text('2/3 ocupadas (67%)'), findsOneWidget);

      // Verifica grupos por servicio
      expect(find.text('Medicina Mujeres'), findsOneWidget);
      expect(find.text('Cirugía Varones'), findsOneWidget);

      // Verifica códigos de cama
      expect(find.text('101-A'), findsOneWidget);
      expect(find.text('102-B'), findsOneWidget);
      expect(find.text('201-A'), findsOneWidget);

      // Verifica nombres de pacientes
      expect(find.text('Mamani Ramos, Elena'), findsOneWidget);
      expect(find.text('Perez Gomez, Jorge'), findsOneWidget);
    });

    testWidgets('filtra camas en tiempo real mediante el buscador de texto',
        (tester) async {
      final mockRepo = _MockCamasRepository();
      when(mockRepo.obtenerTablero)
          .thenAnswer((_) async => Exito(listaCamasPrueba));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            camasRepositoryProvider.overrideWithValue(mockRepo),
            sesionActivaProvider.overrideWithValue(sesionMock),
          ],
          child: const MaterialApp(home: TableroCamasPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Buscar por nombre de paciente
      await tester.enterText(
        find.byType(TextField),
        'Elena',
      );
      await tester.pumpAndSettle();

      // Solo debe aparecer la cama de Elena
      expect(find.text('102-B'), findsOneWidget);
      expect(find.text('Mamani Ramos, Elena'), findsOneWidget);
      expect(find.text('101-A'), findsNothing);
      expect(find.text('201-A'), findsNothing);

      // Limpiar búsqueda
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Vuelven a aparecer todas
      expect(find.text('101-A'), findsOneWidget);
      expect(find.text('102-B'), findsOneWidget);
      expect(find.text('201-A'), findsOneWidget);

      // Buscar por código de cama
      await tester.enterText(
        find.byType(TextField),
        '201',
      );
      await tester.pumpAndSettle();
      expect(find.text('201-A'), findsOneWidget);
      expect(find.text('101-A'), findsNothing);
    });

    testWidgets('tocar una cama abre la hoja modal de detalle con sus datos',
        (tester) async {
      final mockRepo = _MockCamasRepository();
      when(mockRepo.obtenerTablero)
          .thenAnswer((_) async => Exito(listaCamasPrueba));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            camasRepositoryProvider.overrideWithValue(mockRepo),
            sesionActivaProvider.overrideWithValue(sesionMock),
          ],
          child: const MaterialApp(home: TableroCamasPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar en la cama 102-B
      await tester.tap(find.text('102-B'));
      await tester.pumpAndSettle();

      // Verifica contenido de la hoja modal
      expect(find.text('Cama 102-B'), findsOneWidget);
      expect(find.text('Paciente internado'), findsOneWidget);
      expect(find.text('Matrícula de asegurado'), findsOneWidget);
      expect(find.text('76-5432-EMR'), findsOneWidget);
      expect(find.text('3 días transcurridos'), findsOneWidget);

      // Cerrar la hoja modal
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Matrícula de asegurado'), findsNothing);
    });
  });
}
