import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fecha = DateTime(2026, 7, 16);

  const servicio = Servicio(
    id: 'srv-1',
    nombre: 'Medicina Interna',
    activo: true,
    nombreVaciado: 'Medicina Interna',
  );

  /// Censo del EST-1 fotografiado. Capacidad 38: 34 + 2 + 1 + 1.
  CensoServicio muestra({int libre = 2}) => CensoServicio(
        fecha: fecha,
        servicioId: servicio.id,
        ingreso: 4,
        egreso: 3,
        total: 34,
        libre: libre,
        bloqueada: 1,
        aislamiento: 1,
      );

  CensoFormState estadoCon({
    required CensoServicio censo,
    int? capacidad = 38,
  }) =>
      CensoFormState(
        fase: FaseFormulario.edicion,
        servicio: servicio,
        censo: censo,
        capacidad: capacidad,
      );

  group('CensoServicio.camasLibresSegunCapacidad', () {
    test('es la regla de cuadre del backend despejada', () {
      final censo = muestra(libre: 0);

      // total 34 + bloqueada 1 + aislamiento 1 = 36; capacidad 38 → 2 libres.
      expect(censo.camasLibresSegunCapacidad(38), 2);
    });

    test('el valor deducido hace cuadrar el censo', () {
      final censo = muestra(libre: 0);
      final deducida = censo.camasLibresSegunCapacidad(38)!;

      expect(censo.copyWith(libre: deducida).cuadraCon(38), isTrue);
    });

    test('devuelve null sin capacidad conocida', () {
      expect(muestra().camasLibresSegunCapacidad(null), isNull);
    });

    test('puede dar negativo, y eso significa que los otros campos no entran',
        () {
      // No son "camas libres negativas": es que 34+1+1 no cabe en 30.
      expect(muestra(libre: 0).camasLibresSegunCapacidad(30), -6);
    });
  });

  group('Cuándo se ofrece la sugerencia', () {
    test('se ofrece cuando difiere de lo tipeado', () {
      final estado = estadoCon(censo: muestra(libre: 0));

      expect(estado.camasLibresSugeridas, 2);
    });

    test('se calla si coincide con lo tipeado', () {
      // Sugerir lo mismo que ya está cargado es ruido.
      final estado = estadoCon(censo: muestra());

      expect(estado.camasLibresSugeridas, isNull);
    });

    test('se calla con el formulario intacto', () {
      // Al abrir, todo en cero: sugeriría la capacidad entera como ruido.
      final estado = estadoCon(
        censo: CensoServicio(fecha: fecha, servicioId: servicio.id),
      );

      expect(estado.camasLibresSugeridas, isNull);
    });

    test('se calla sin capacidad conocida', () {
      final estado = estadoCon(censo: muestra(libre: 0), capacidad: null);

      expect(estado.camasLibresSugeridas, isNull);
    });

    test('se calla cuando el cálculo da negativo', () {
      // De eso ya se ocupa V-05, que explica cuántas camas sobran.
      final estado = estadoCon(censo: muestra(libre: 0), capacidad: 30);

      expect(estado.camasLibresSugeridas, isNull);
    });
  });

  group('La sugerencia no reemplaza el control cruzado', () {
    test('un error de tipeo en el saldo se delata como discrepancia', () {
      // El operador tipea 43 en vez de 34, y del papel copia libre = 2.
      final conError = muestra().copyWith(total: 43);
      final estado = estadoCon(censo: conError);

      // La sugerencia difiere de lo transcrito: ahí está la señal. Si el campo
      // se calculara en vez de sugerirse, la ecuación cuadraría siempre y el
      // error entraría al histórico sin que nadie lo notara.
      expect(estado.camasLibresSugeridas, isNot(conError.libre));
      expect(conError.cuadraCon(38), isFalse);
    });

    test('aceptar la sugerencia deja el censo cuadrando', () {
      final estado = estadoCon(censo: muestra(libre: 0));
      final aplicada =
          estado.censo.copyWith(libre: estado.camasLibresSugeridas);

      expect(aplicada.cuadraCon(38), isTrue);
      expect(aplicada.libre, 2);
    });

    test('el campo sigue siendo del papel: aceptar es opcional', () {
      // Con un valor distinto al sugerido, el estado no lo corrige solo.
      final estado = estadoCon(censo: muestra(libre: 5));

      expect(estado.censo.libre, 5);
      expect(estado.camasLibresSugeridas, 2);
    });
  });
}
