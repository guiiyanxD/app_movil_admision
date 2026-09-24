import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/validar_censo_servicio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validar = ValidarCensoServicio();
  final ahora = DateTime.utc(2026, 7, 31, 14); // 10:00 en Bolivia

  /// Censo del EST-1 fotografiado: cuadra contra capacidad 38.
  CensoServicio censoValido() => CensoServicio(
        fecha: DateTime(2026, 7, 16),
        servicioId: 'srv-1',
        ingreso: 4,
        egreso: 3,
        total: 34,
        libre: 2,
        bloqueada: 1,
        aislamiento: 1,
      );

  group('Camino limpio', () {
    test('un censo correcto no produce ninguna validación bloqueante', () {
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        capacidad: 38,
        totalDiaAnterior: 33,
        ahora: ahora,
      );

      expect(validaciones.hayBloqueantes, isFalse);
      expect(validaciones.deSeveridad(SeveridadValidacion.advertencia), isEmpty);
    });
  });

  group('V-05 — cuadre contra la capacidad', () {
    test('bloquea y dice cuántas camas sobran', () {
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        capacidad: 36,
        ahora: ahora,
      );

      final v = validaciones.primeraDe('V-05')!;
      expect(v.esBloqueante, isTrue);
      expect(v.mensaje, contains('38'));
      expect(v.mensaje, contains('36'));
      expect(v.mensaje, contains('sobran 2'));
    });

    test('dice cuántas faltan cuando la suma queda corta', () {
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        capacidad: 40,
        ahora: ahora,
      );

      expect(validaciones.primeraDe('V-05')!.mensaje, contains('faltan 2'));
    });

    test('degrada a advertencia si no se pudo obtener la capacidad', () {
      // Una falla de red en una consulta auxiliar no debe bloquear al operador.
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        ahora: ahora,
      );

      final v = validaciones.primeraDe('V-05')!;
      expect(v.severidad, SeveridadValidacion.advertencia);
      expect(validaciones.hayBloqueantes, isFalse);
    });
  });

  group('V-07 — saldo esperado', () {
    test('nunca bloquea, aunque el saldo no cierre', () {
      final censo = censoValido().copyWith(total: 99);
      final validaciones = validar.ejecutar(
        censo: censo,
        capacidad: censo.sumaEstadosCama,
        totalDiaAnterior: 33,
        ahora: ahora,
      );

      final v = validaciones.primeraDe('V-07')!;
      expect(v.severidad, SeveridadValidacion.advertencia);
      expect(validaciones.hayBloqueantes, isFalse);
    });

    test('muestra la aritmética completa, no solo el número esperado', () {
      final censo = censoValido().copyWith(total: 99);
      final validaciones = validar.ejecutar(
        censo: censo,
        capacidad: censo.sumaEstadosCama,
        totalDiaAnterior: 33,
        ahora: ahora,
      );

      final mensaje = validaciones.primeraDe('V-07')!.mensaje;
      expect(mensaje, contains('33'));
      expect(mensaje, contains('4 ingresos'));
      expect(mensaje, contains('3 egresos'));
      expect(mensaje, contains('99'));
    });

    test('no se dispara cuando el saldo cierra', () {
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        capacidad: 38,
        totalDiaAnterior: 33,
        ahora: ahora,
      );

      expect(validaciones.primeraDe('V-07'), isNull);
    });

    test('el óbito resta aparte del egreso en la aritmética mostrada', () {
      // 33 + 4 − 3 − 1 óbito = 33, no 32.
      final censo = censoValido().copyWith(obito: 1, total: 33);
      final validaciones = validar.ejecutar(
        censo: censo,
        capacidad: censo.sumaEstadosCama,
        totalDiaAnterior: 33,
        ahora: ahora,
      );

      expect(validaciones.primeraDe('V-07'), isNull);
    });
  });

  group('V-08 — sin día anterior', () {
    test('es informativa: durante el backfill es lo normal', () {
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        capacidad: 38,
        ahora: ahora,
      );

      final v = validaciones.primeraDe('V-08')!;
      expect(v.severidad, SeveridadValidacion.informativa);
      expect(validaciones.primeraDe('V-07'), isNull);
    });
  });

  group('V-03 — fecha', () {
    test('bloquea el día en curso', () {
      final censo = censoValido().copyWith(fecha: DateTime(2026, 7, 31));
      final validaciones = validar.ejecutar(
        censo: censo,
        capacidad: 38,
        ahora: ahora,
      );

      expect(validaciones.primeraDe('V-03')!.esBloqueante, isTrue);
    });
  });

  group('V-06 — servicio sin mapeo', () {
    test('advierte pero deja guardar', () {
      final validaciones = validar.ejecutar(
        censo: censoValido(),
        capacidad: 38,
        totalDiaAnterior: 33,
        servicioTieneMapeo: false,
        ahora: ahora,
      );

      final v = validaciones.primeraDe('V-06')!;
      expect(v.severidad, SeveridadValidacion.advertencia);
      expect(validaciones.hayBloqueantes, isFalse);
      expect(v.mensaje, contains('no podrá confirmarse'));
    });
  });

  group('Camas prestadas', () {
    test('V-04 bloquea la combinación repetida', () {
      final censo = censoValido().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 2,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );

      final validaciones =
          validar.ejecutar(censo: censo, capacidad: 38, ahora: ahora);

      expect(validaciones.primeraDe('V-04')!.esBloqueante, isTrue);
    });

    test('la misma especialidad con distinto tipo no dispara V-04', () {
      final censo = censoValido().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.traslado,
          ),
        ],
      );

      final validaciones =
          validar.ejecutar(censo: censo, capacidad: 38, ahora: ahora);

      expect(validaciones.primeraDe('V-04'), isNull);
    });

    test('V-10 avisa si las directas exceden los ingresos, sin bloquear', () {
      final censo = censoValido().copyWith(
        ingreso: 1,
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 3,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );

      final validaciones =
          validar.ejecutar(censo: censo, capacidad: 38, ahora: ahora);

      final v = validaciones.primeraDe('V-10')!;
      expect(v.severidad, SeveridadValidacion.informativa);
      expect(validaciones.hayBloqueantes, isFalse);
    });

    test('V-10 no aplica al tipo TRASLADO', () {
      // TRASLADO incluye movimientos internos dentro del mismo servicio, que
      // no son ingresos por traslado: comparar daría falsos positivos.
      final censo = censoValido().copyWith(
        ingresoTraslado: 0,
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 5,
            tipoIngreso: TipoIngresoCamaPrestada.traslado,
          ),
        ],
      );

      final validaciones =
          validar.ejecutar(censo: censo, capacidad: 38, ahora: ahora);

      expect(validaciones.primeraDe('V-10'), isNull);
    });

    test('el caso real "Cir = 1" no dispara ninguna validación', () {
      final censo = censoValido().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );

      final validaciones = validar.ejecutar(
        censo: censo,
        capacidad: 38,
        totalDiaAnterior: 33,
        ahora: ahora,
      );

      expect(validaciones.hayBloqueantes, isFalse);
      expect(validaciones.primeraDe('V-10'), isNull);
    });
  });

  group('V-01 — negativos', () {
    test('bloquea y señala el campo', () {
      final censo = censoValido().copyWith(obito: -1);
      final validaciones =
          validar.ejecutar(censo: censo, capacidad: 38, ahora: ahora);

      final v = validaciones.primeraDe('V-01')!;
      expect(v.esBloqueante, isTrue);
      expect(v.campo?.name, 'obito');
    });
  });
}
