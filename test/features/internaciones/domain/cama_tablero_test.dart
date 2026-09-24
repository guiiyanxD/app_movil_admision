import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CamaTablero - Lógica de Estados Visuales', () {
    test('cama sin estancia está disponible', () {
      const cama = CamaTablero(
        id: 'c-1',
        codigo: '101-A',
        estadoBase: 'disponible',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
      );

      expect(cama.esOcupada, isFalse);
      expect(cama.diasInternado, equals(0));
      expect(cama.esCritica, isFalse);
      expect(cama.esPrestada, isFalse);
      expect(cama.estadoVisual, equals(EstadoCamaVisual.disponible));
    });

    test('cama ocupada con estancia activa', () {
      final cama = CamaTablero(
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
        pacienteNombre: 'Flores, Ana',
        matricula: '88-1234-A',
        fechaIngreso: DateTime.now().subtract(const Duration(days: 5)),
      );

      expect(cama.esOcupada, isTrue);
      expect(cama.diasInternado, equals(5));
      expect(cama.esCritica, isFalse);
      expect(cama.esPrestada, isFalse);
      expect(cama.estadoVisual, equals(EstadoCamaVisual.ocupada));
    });

    test('cama prestada cuando la especialidad de la estancia difiere de la nativa',
        () {
      final cama = CamaTablero(
        id: 'c-3',
        codigo: '103-C',
        estadoBase: 'disponible',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
        bedStayId: 'bs-2',
        bedStayEspecialidadId: 'e-2', // Especialidad distinta (préstamo)
        internacionId: 'i-2',
        pacienteNombre: 'Torrez, Carlos',
        fechaIngreso: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(cama.esOcupada, isTrue);
      expect(cama.esPrestada, isTrue);
      expect(cama.estadoVisual, equals(EstadoCamaVisual.prestada));
    });

    test('cama crítica cuando la internación supera los 30 días', () {
      final cama = CamaTablero(
        id: 'c-4',
        codigo: '104-D',
        estadoBase: 'disponible',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
        bedStayId: 'bs-3',
        bedStayEspecialidadId: 'e-1',
        internacionId: 'i-3',
        pacienteNombre: 'Gomez, Roberto',
        fechaIngreso: DateTime.now().subtract(const Duration(days: 35)),
      );

      expect(cama.esOcupada, isTrue);
      expect(cama.diasInternado, equals(35));
      expect(cama.esCritica, isTrue);
      expect(cama.estadoVisual, equals(EstadoCamaVisual.critica));
    });

    test('prioridad: fuera de servicio y aislamiento prevalecen sobre ocupada',
        () {
      const camaFueraServicio = CamaTablero(
        id: 'c-5',
        codigo: '105-E',
        estadoBase: 'fuera_servicio',
        motivoEstado: 'En mantenimiento',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
      );
      expect(
        camaFueraServicio.estadoVisual,
        equals(EstadoCamaVisual.fueraDeServicio),
      );

      const camaAislamiento = CamaTablero(
        id: 'c-6',
        codigo: '106-F',
        estadoBase: 'aislamiento',
        servicioId: 's-1',
        servicioNombre: 'Medicina Mujeres',
        especialidadNativaId: 'e-1',
        especialidadNombre: 'Medicina Interna',
      );
      expect(camaAislamiento.estadoVisual, equals(EstadoCamaVisual.aislamiento));
    });
  });
}
