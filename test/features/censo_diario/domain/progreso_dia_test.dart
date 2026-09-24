import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fecha = DateTime(2026, 6, 1);

  ProgresoServicio servicio(
    String nombre, {
    required bool cargado,
    bool? cuadra,
  }) =>
      ProgresoServicio(
        servicioId: nombre.toLowerCase(),
        servicioNombre: nombre,
        cargado: cargado,
        cuadra: cuadra,
      );

  group('ProgresoDia.puedeConfirmar (CA-08)', () {
    test('habilita solo cuando todos están cargados y cuadran', () {
      final progreso = ProgresoDia(
        fecha: fecha,
        servicios: [
          servicio('Medicina Interna', cargado: true, cuadra: true),
          servicio('Pediatría', cargado: true, cuadra: true),
        ],
      );

      expect(progreso.puedeConfirmar, isTrue);
    });

    test('no habilita si falta un servicio por cargar', () {
      final progreso = ProgresoDia(
        fecha: fecha,
        servicios: [
          servicio('Medicina Interna', cargado: true, cuadra: true),
          servicio('Pediatría', cargado: false),
        ],
      );

      expect(progreso.puedeConfirmar, isFalse);
      expect(progreso.pendientes.single.servicioNombre, 'Pediatría');
    });

    test('no habilita si un servicio cargado no cuadra', () {
      final progreso = ProgresoDia(
        fecha: fecha,
        servicios: [
          servicio('Medicina Interna', cargado: true, cuadra: false),
          servicio('Pediatría', cargado: true, cuadra: true),
        ],
      );

      expect(progreso.puedeConfirmar, isFalse);
      expect(progreso.desbalanceados.single.servicioNombre, 'Medicina Interna');
    });

    test('una lista vacía nunca habilita', () {
      // Sin servicios no hay nada que confirmar. Dejar pasar este caso sería
      // habilitar el botón porque el catálogo no cargó.
      final progreso = ProgresoDia(fecha: fecha, servicios: const []);

      expect(progreso.puedeConfirmar, isFalse);
    });
  });

  group('ProgresoDia — conteos', () {
    test('distingue cargados de listos', () {
      final progreso = ProgresoDia(
        fecha: fecha,
        servicios: [
          servicio('A', cargado: true, cuadra: true),
          servicio('B', cargado: true, cuadra: false),
          servicio('C', cargado: false),
        ],
      );

      expect(progreso.total, 3);
      expect(progreso.cargados, 2);
      expect(progreso.listos, 1);
      expect(progreso.resumen, '2 de 3 servicios cargados');
    });

    test('el conteo no depende de ninguna constante del código (CA-15)', () {
      // Un servicio nuevo abierto en el hospital aparece solo, sin release.
      final trece = ProgresoDia(
        fecha: fecha,
        servicios: List.generate(
          13,
          (i) => servicio('S$i', cargado: true, cuadra: true),
        ),
      );
      final catorce = ProgresoDia(
        fecha: fecha,
        servicios: List.generate(
          14,
          (i) => servicio('S$i', cargado: true, cuadra: true),
        ),
      );

      expect(trece.puedeConfirmar, isTrue);
      expect(catorce.puedeConfirmar, isTrue);
      expect(catorce.total, 14);
    });
  });

  group('ProgresoServicio', () {
    test('cargado sin cuadrar se distingue de no cargado', () {
      expect(
        servicio('A', cargado: true, cuadra: false).cargadoPeroDesbalanceado,
        isTrue,
      );
      expect(
        servicio('B', cargado: false).cargadoPeroDesbalanceado,
        isFalse,
      );
    });

    test('cuadra en null nunca cuenta como listo', () {
      expect(servicio('A', cargado: true).listo, isFalse);
    });
  });
}
