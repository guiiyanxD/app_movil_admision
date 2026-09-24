import 'package:app_movil/features/censo_diario/domain/value_objects/fecha_censo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 31-jul-2026, 14:00 UTC = 10:00 en Bolivia. Día en Bolivia: 31.
  final medioDiaBolivia = DateTime.utc(2026, 7, 31, 14);

  group('FechaCenso.esCargable', () {
    test('rechaza el día en curso', () {
      expect(
        FechaCenso.esCargable(DateTime(2026, 7, 31), ahora: medioDiaBolivia),
        isFalse,
      );
    });

    test('rechaza fechas futuras', () {
      expect(
        FechaCenso.esCargable(DateTime(2026, 8, 1), ahora: medioDiaBolivia),
        isFalse,
      );
    });

    test('acepta ayer', () {
      expect(
        FechaCenso.esCargable(DateTime(2026, 7, 30), ahora: medioDiaBolivia),
        isTrue,
      );
    });

    test('acepta fechas de varios meses atrás, sin ventana de mes', () {
      expect(
        FechaCenso.esCargable(DateTime(2026, 1, 10), ahora: medioDiaBolivia),
        isTrue,
      );
    });

    test('ignora el componente horario de la fecha evaluada', () {
      expect(
        FechaCenso.esCargable(
          DateTime(2026, 7, 30, 23, 59, 59),
          ahora: medioDiaBolivia,
        ),
        isTrue,
      );
    });
  });

  group('FechaCenso — el hueco de UTC (R-02 / ADR-0005 D-9)', () {
    // 31-jul 01:00 UTC = 30-jul 21:00 en Bolivia.
    // El backend, que compara en UTC, creería que "hoy" es el 31 y aceptaría
    // cargar el 30. El cliente debe seguir considerando el 30 como día en
    // curso y rechazarlo.
    final nueveDeLaNocheEnBolivia = DateTime.utc(2026, 7, 31, 1);

    test('a las 21:00 hora Bolivia, el día en curso sigue sin ser cargable', () {
      expect(
        FechaCenso.esCargable(
          DateTime(2026, 7, 30),
          ahora: nueveDeLaNocheEnBolivia,
        ),
        isFalse,
        reason: 'el cliente nunca debe ser más permisivo que el backend',
      );
    });

    test('a las 21:00 hora Bolivia, el día previo sí es cargable', () {
      expect(
        FechaCenso.esCargable(
          DateTime(2026, 7, 29),
          ahora: nueveDeLaNocheEnBolivia,
        ),
        isTrue,
      );
    });

    test('hoyEnBolivia devuelve el 30 cuando en UTC ya es 31', () {
      expect(
        FechaCenso.hoyEnBolivia(ahora: nueveDeLaNocheEnBolivia),
        DateTime(2026, 7, 30),
      );
    });
  });

  group('FechaCenso — serialización', () {
    test('produce YYYY-MM-DD plano, con ceros a la izquierda', () {
      final fecha = FechaCenso(DateTime(2026, 6, 1), ahora: medioDiaBolivia);
      expect(fecha.comoParametroApi, '2026-06-01');
    });

    test('no arrastra offset ni componente horario', () {
      final fecha = FechaCenso(
        DateTime(2026, 6, 1, 23, 45),
        ahora: medioDiaBolivia,
      );
      expect(fecha.comoParametroApi, '2026-06-01');
      expect(fecha.comoParametroApi.contains('T'), isFalse);
      expect(fecha.comoParametroApi.contains('+'), isFalse);
      expect(fecha.comoParametroApi.length, 10);
    });

    test('diaAnterior retrocede un día calendario', () {
      final fecha = FechaCenso(DateTime(2026, 3, 1), ahora: medioDiaBolivia);
      expect(fecha.diaAnterior, DateTime(2026, 2, 28));
    });
  });

  group('FechaCenso — construcción', () {
    test('lanza FechaCensoInvalida ante el día en curso', () {
      expect(
        () => FechaCenso(DateTime(2026, 7, 31), ahora: medioDiaBolivia),
        throwsA(isA<FechaCensoInvalida>()),
      );
    });

    test('dos fechas del mismo día son iguales aunque difiera la hora', () {
      final a = FechaCenso(DateTime(2026, 6, 1, 8), ahora: medioDiaBolivia);
      final b = FechaCenso(DateTime(2026, 6, 1, 20), ahora: medioDiaBolivia);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
