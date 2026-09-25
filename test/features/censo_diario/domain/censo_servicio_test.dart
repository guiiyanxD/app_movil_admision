import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fecha = DateTime(2026, 7, 16);

  /// Censo del EST-1 fotografiado: Medicina Interna, piso 1°, 16-jul-2026.
  /// Día anterior 33, ingresados 4, egresos 3, fallecidos 0, saldo 34.
  CensoServicio muestraDelDieciseisDeJulio() => CensoServicio(
        fecha: fecha,
        servicioId: 'srv-medicina-interna',
        ingreso: 4,
        egreso: 3,
        total: 34,
        libre: 2,
        bloqueada: 1,
        aislamiento: 1,
      );

  group('CensoServicio — saldo de las 24 horas', () {
    test('reproduce la aritmética del formulario fotografiado', () {
      final censo = muestraDelDieciseisDeJulio();
      expect(censo.saldoEsperado(33), 34);
      expect(censo.saldoEsperado(33), censo.total);
    });

    test('el óbito resta de forma independiente del egreso', () {
      // 33 + 4 − 3 − 1 óbito = 33. El fallecido NO se cuenta también como
      // egreso: si lo hiciera, el resultado sería 32.
      final censo = muestraDelDieciseisDeJulio().copyWith(obito: 1);
      expect(censo.saldoEsperado(33), 33);
    });

    test('los ingresos por traslado suman al saldo', () {
      final censo = muestraDelDieciseisDeJulio().copyWith(ingresoTraslado: 2);
      expect(censo.saldoEsperado(33), 36);
    });

    test('los egresos por traslado restan del saldo', () {
      final censo = muestraDelDieciseisDeJulio().copyWith(egresoTraslado: 2);
      expect(censo.saldoEsperado(33), 32);
    });

    test('recorrer los movimientos da el mismo resultado que la fórmula', () {
      final censo = muestraDelDieciseisDeJulio().copyWith(
        ingresoTraslado: 2,
        egresoTraslado: 1,
        obito: 1,
      );
      expect(
        censo.saldoEsperadoPorMovimiento(33),
        censo.saldoEsperado(33),
      );
    });

    test('cada tipo de movimiento tiene el signo correcto', () {
      expect(TipoMovimientoCenso.ingresoDirecto.signoEnSaldo, 1);
      expect(TipoMovimientoCenso.ingresoPorTraslado.signoEnSaldo, 1);
      expect(TipoMovimientoCenso.egresoDirecto.signoEnSaldo, -1);
      expect(TipoMovimientoCenso.egresoPorTraslado.signoEnSaldo, -1);
      expect(TipoMovimientoCenso.obito.signoEnSaldo, -1);
    });
  });

  group('CensoServicio — cuadre contra la capacidad', () {
    test('cuadra cuando la suma de estados iguala la capacidad', () {
      final censo = muestraDelDieciseisDeJulio();
      // 34 total + 2 libres + 1 bloqueada + 1 aislamiento = 38
      expect(censo.sumaEstadosCama, 38);
      expect(censo.cuadraCon(38), isTrue);
    });

    test('no cuadra si la suma queda por debajo de la capacidad', () {
      expect(muestraDelDieciseisDeJulio().cuadraCon(40), isFalse);
    });

    test('no cuadra si la suma excede la capacidad', () {
      expect(muestraDelDieciseisDeJulio().cuadraCon(36), isFalse);
    });

    test('las camas prestadas no alteran el cuadre', () {
      final sinPrestadas = muestraDelDieciseisDeJulio();
      final conPrestadas = sinPrestadas.copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );
      expect(conPrestadas.sumaEstadosCama, sinPrestadas.sumaEstadosCama);
      expect(conPrestadas.cuadraCon(38), isTrue);
    });
  });

  group('CensoServicio — dotación', () {
    test('es total + libre', () {
      expect(muestraDelDieciseisDeJulio().dotacion, 36);
    });

    test('no coincide con la capacidad cuando hay camas fuera de servicio', () {
      final censo = muestraDelDieciseisDeJulio();
      expect(censo.dotacion, isNot(censo.sumaEstadosCama));
    });
  });

  group('CensoServicio — camas prestadas', () {
    test('las directas se suman para contrastar contra los ingresos (V-10)',
        () {
      final censo = muestraDelDieciseisDeJulio().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
          CamaPrestada(
            especialidadId: 'esp-pediatria',
            cantidad: 2,
            tipoIngreso: TipoIngresoCamaPrestada.traslado,
          ),
        ],
      );
      expect(censo.camasPrestadasDirectas, 1);
      expect(censo.camasPrestadasDirectas <= censo.ingreso, isTrue);
    });

    test('la muestra fotografiada registra "Cir = 1" como ingreso directo', () {
      final censo = muestraDelDieciseisDeJulio().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );
      // De los 4 ingresos del día, 1 ocupó una cama prestada.
      expect(censo.camasPrestadasDirectas, 1);
      expect(censo.ingreso, 4);
      // Y no altera ninguna cifra del censo.
      expect(censo.saldoEsperado(33), 34);
      expect(censo.cuadraCon(38), isTrue);
    });

    test('detecta combinaciones especialidad+tipo duplicadas', () {
      final censo = muestraDelDieciseisDeJulio().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 2,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );
      expect(censo.clavesDuplicadasCamasPrestadas(), hasLength(1));
    });

    test('la misma especialidad con distinto tipo no es duplicado', () {
      final censo = muestraDelDieciseisDeJulio().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 2,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
          CamaPrestada(
            especialidadId: 'esp-cirugia',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.traslado,
          ),
        ],
      );
      expect(censo.clavesDuplicadasCamasPrestadas(), isEmpty);
    });
  });

  group('CensoServicio — acceso por campo', () {
    test('valorDe y conCampo cubren los 9 campos sin excepción', () {
      var censo = CensoServicio(fecha: fecha, servicioId: 'srv-1');
      for (final campo in CampoCenso.values) {
        censo = censo.conCampo(campo, 7);
        expect(censo.valorDe(campo), 7, reason: campo.name);
      }
    });

    test('modificar un campo no toca los demás', () {
      final original = muestraDelDieciseisDeJulio();
      final modificado = original.conCampo(CampoCenso.obito, 5);
      expect(modificado.obito, 5);
      expect(modificado.ingreso, original.ingreso);
      expect(modificado.total, original.total);
    });
  });

  group('CampoCenso — contrato con el backend', () {
    test('los nombres de campo coinciden con el DTO del API', () {
      expect(
        CampoCenso.values.map((c) => c.campoApi).toList(),
        [
          'ingreso',
          'ingresoTraslado',
          'egreso',
          'egresoTraslado',
          'obito',
          'aislamiento',
          'bloqueada',
          'libre',
          'total',
        ],
      );
    });

    test('el campo de egresos no reproduce la etiqueta impresa obsoleta', () {
      expect(CampoCenso.egreso.etiqueta, 'Egresos por salida');
      expect(
        CampoCenso.egreso.ayudaFormulario,
        contains('Ingresos y egresos del mismo día'),
      );
    });

    test('los literales de tipo de ingreso son los que exige el backend', () {
      expect(TipoIngresoCamaPrestada.directo.valorApi, 'DIRECTO');
      expect(TipoIngresoCamaPrestada.traslado.valorApi, 'TRASLADO');
    });
  });
}
