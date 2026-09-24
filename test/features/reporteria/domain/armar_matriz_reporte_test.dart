import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';
import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';
import 'package:app_movil/features/reporteria/domain/usecases/armar_matriz_reporte.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const armar = ArmarMatrizReporte();

  /// Orden institucional: no es alfabético, sale del `indice` del catálogo.
  const ordenCatalogo = ['Pabellon Quirurgico', 'Medicina Interna', 'Pediatria'];

  List<FilaReporteCenso> muestra() => const [
        FilaReporteCenso(
          periodo: '2026-07-16',
          servicio: 'Medicina Interna',
          ingreso: 4,
          egreso: 3,
        ),
        FilaReporteCenso(
          periodo: '2026-07-16',
          servicio: 'Pediatria',
          ingreso: 2,
          egreso: 1,
        ),
        FilaReporteCenso(
          periodo: '2026-07-17',
          servicio: 'Medicina Interna',
          ingreso: 5,
          egreso: 2,
        ),
      ];

  group('Orden de las columnas (CA-03)', () {
    test('respeta el orden del catálogo, no el alfabético', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      // Alfabéticamente sería Medicina Interna, Pediatria. El catálogo manda.
      expect(matriz.servicios, ['Medicina Interna', 'Pediatria']);
    });

    test('un servicio del catálogo sin datos no ocupa columna', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      expect(matriz.servicios, isNot(contains('Pabellon Quirurgico')));
    });

    test('un servicio con datos pero fuera del catálogo va al final (CA-04)',
        () {
      final filas = [
        ...muestra(),
        const FilaReporteCenso(
          periodo: '2026-07-16',
          servicio: 'Servicio Renombrado',
          ingreso: 9,
        ),
      ];

      final matriz = armar.ejecutar(
        filas: filas,
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      // No se descarta: ocultarlo sería perder datos del reporte por un
      // problema de catálogo, y en silencio.
      expect(matriz.servicios.last, 'Servicio Renombrado');
      expect(matriz.totalGeneral, 4 + 2 + 5 + 9);
    });

    test('sin catálogo conocido, todo va alfabético', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
      );

      expect(matriz.servicios, ['Medicina Interna', 'Pediatria']);
    });

    test('varios huérfanos quedan ordenados entre sí', () {
      expect(
        ArmarMatrizReporte.ordenarServicios(
          ['Zeta', 'Alfa', 'Medicina Interna'],
          const ['Medicina Interna'],
        ),
        ['Medicina Interna', 'Alfa', 'Zeta'],
      );
    });
  });

  group('Períodos', () {
    test('quedan ordenados y sin repetir', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      expect(
        matriz.filas.map((f) => f.periodo).toList(),
        ['2026-07-16', '2026-07-17'],
      );
    });

    test('el formato mensual ordena igual de bien', () {
      final matriz = armar.ejecutar(
        filas: const [
          FilaReporteCenso(periodo: '2026-08', servicio: 'A', ingreso: 1),
          FilaReporteCenso(periodo: '2026-07', servicio: 'A', ingreso: 2),
          FilaReporteCenso(periodo: '2025-12', servicio: 'A', ingreso: 3),
        ],
        movimiento: MovimientoReporte.ingreso,
      );

      // `YYYY-MM` ordena bien como texto, que es justo el motivo de ese formato.
      expect(
        matriz.filas.map((f) => f.periodo).toList(),
        ['2025-12', '2026-07', '2026-08'],
      );
    });
  });

  group('Celdas y totales (CA-06)', () {
    test('una celda sin fila vale cero, no queda vacía', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      // Pediatría no cargó el 17: es un cero legítimo.
      final segundoDia = matriz.filas[1];
      expect(segundoDia.valores, [5, 0]);
    });

    test('el total de cada fila es la suma de sus valores', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      expect(matriz.filas[0].total, 6);
      expect(matriz.filas[1].total, 5);
    });

    test('los totales por columna suman todos los períodos', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      expect(matriz.totalesPorServicio, [9, 2]);
    });

    test('el total general coincide sumado por filas y por columnas', () {
      final matriz = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      final porFilas = matriz.filas.fold(0, (s, f) => s + f.total);
      final porColumnas = matriz.totalesPorServicio.fold(0, (s, v) => s + v);

      // Que las dos sumas coincidan es lo que hace confiable el pie del reporte.
      expect(matriz.totalGeneral, porFilas);
      expect(matriz.totalGeneral, porColumnas);
      expect(matriz.totalGeneral, 11);
    });

    test('cada movimiento lee su propio campo', () {
      final ingresos = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );
      final egresos = armar.ejecutar(
        filas: muestra(),
        movimiento: MovimientoReporte.egreso,
        ordenConocido: ordenCatalogo,
      );

      expect(ingresos.totalGeneral, 11);
      expect(egresos.totalGeneral, 6);
    });
  });

  group('Los ocho movimientos de una vez (CA-08)', () {
    test('devuelve una matriz por movimiento, en el orden del EST-1', () {
      final matrices = armar.todos(
        filas: muestra(),
        ordenConocido: ordenCatalogo,
      );

      // Ocho páginas del PDF, una por matriz.
      expect(matrices, hasLength(MovimientoReporte.values.length));
      expect(
        matrices.map((m) => m.movimiento).toList(),
        MovimientoReporte.values,
      );
    });

    test('cada matriz coincide con calcularla por separado', () {
      final matrices = armar.todos(
        filas: muestra(),
        ordenConocido: ordenCatalogo,
      );

      for (final movimiento in MovimientoReporte.values) {
        final suelta = armar.ejecutar(
          filas: muestra(),
          movimiento: movimiento,
          ordenConocido: ordenCatalogo,
        );

        // Lo que se ve en pantalla sale de este mismo cálculo, así que no puede
        // discrepar de lo que se imprime.
        expect(
          matrices[movimiento.index].totalGeneral,
          suelta.totalGeneral,
          reason: movimiento.name,
        );
        expect(
          matrices[movimiento.index].servicios,
          suelta.servicios,
          reason: movimiento.name,
        );
      }
    });

    test('sin filas devuelve igual las ocho matrices, todas vacías', () {
      final matrices = armar.todos(filas: const []);

      expect(matrices, hasLength(8));
      expect(matrices.every((m) => m.estaVacia), isTrue);
    });
  });

  group('Casos límite', () {
    test('sin filas, la matriz queda vacía sin romper', () {
      final matriz = armar.ejecutar(
        filas: const [],
        movimiento: MovimientoReporte.ingreso,
        ordenConocido: ordenCatalogo,
      );

      expect(matriz.estaVacia, isTrue);
      expect(matriz.servicios, isEmpty);
      expect(matriz.totalGeneral, 0);
    });

    test('un solo período y un solo servicio', () {
      final matriz = armar.ejecutar(
        filas: const [
          FilaReporteCenso(periodo: '2026-07', servicio: 'A', ingreso: 7),
        ],
        movimiento: MovimientoReporte.ingreso,
      );

      expect(matriz.filas.single.valores, [7]);
      expect(matriz.totalGeneral, 7);
    });

    test('todos los movimientos producen una matriz consistente', () {
      for (final movimiento in MovimientoReporte.values) {
        final matriz = armar.ejecutar(
          filas: muestra(),
          movimiento: movimiento,
          ordenConocido: ordenCatalogo,
        );

        expect(
          matriz.filas.every((f) => f.valores.length == matriz.servicios.length),
          isTrue,
          reason: '${movimiento.name}: filas y columnas deben coincidir',
        );
        expect(
          matriz.totalesPorServicio.length,
          matriz.servicios.length,
          reason: movimiento.name,
        );
      }
    });
  });
}
