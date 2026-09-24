import 'package:app_movil/features/censo_diario/data/models/carga_manual_dtos.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:flutter_test/flutter_test.dart';

/// El JSON de este archivo es el literal de §2 de
/// `docs/specs/lectura_edicion_carga_manual_spec.md`, copiado sin retocar. Si
/// el backend cambia el contrato del `GET`, estos tests son los primeros en
/// avisar.
Map<String, dynamic> jsonDelContrato() => {
      'servicioId': '3fa1-uuid',
      'servicioNombre': 'Medicina Interna',
      'fecha': '2026-07-16',
      'ingreso': 4,
      'ingresoTraslado': 0,
      'egreso': 3,
      'egresoTraslado': 0,
      'obito': 0,
      'aislamiento': 1,
      'bloqueada': 1,
      'libre': 2,
      'total': 34,
      'dotacion': 36,
      'camasPrestadas': [
        {
          'especialidadId': 'esp-uuid',
          'especialidadNombre': 'Cirugía',
          'cantidad': 1,
          'tipoIngreso': 'DIRECTO',
        },
      ],
      'actualizadoEn': '2026-08-01T22:14:03.000Z',
      'creadoPorNombre': 'Ana Rojas',
    };

void main() {
  group('CargaGuardadaDto — GET /carga-manual, camelCase', () {
    test('lee el ejemplo del contrato campo por campo', () {
      final dto = CargaGuardadaDto.fromJson(jsonDelContrato());

      expect(dto.servicioId, '3fa1-uuid');
      expect(dto.servicioNombre, 'Medicina Interna');
      expect(dto.fecha, '2026-07-16');
      expect(dto.ingreso, 4);
      expect(dto.ingresoTraslado, 0);
      expect(dto.egreso, 3);
      expect(dto.egresoTraslado, 0);
      expect(dto.obito, 0);
      expect(dto.aislamiento, 1);
      expect(dto.bloqueada, 1);
      expect(dto.libre, 2);
      expect(dto.total, 34);
      expect(dto.dotacion, 36);
      expect(dto.creadoPorNombre, 'Ana Rojas');
    });

    test('conserva actualizadoEn como el instante UTC que manda el servidor',
        () {
      final dto = CargaGuardadaDto.fromJson(jsonDelContrato());

      // Se compara en UTC a propósito: la hora local depende de la máquina que
      // corre la suite, y convertir para mostrar es tarea de la presentación.
      expect(dto.actualizadoEn, DateTime.utc(2026, 8, 1, 22, 14, 3));
    });

    test('resuelve las camas prestadas anidadas, con nombre y enum', () {
      final dto = CargaGuardadaDto.fromJson(jsonDelContrato());
      final cama = dto.camasPrestadas.single;

      expect(cama.especialidadId, 'esp-uuid');
      expect(cama.especialidadNombre, 'Cirugía');
      expect(cama.cantidad, 1);
      expect(cama.tipoIngreso, TipoIngresoCamaPrestada.directo);
    });

    test('sin actualizadoEn ni creadoPorNombre no lanza: quedan en null', () {
      final json = jsonDelContrato()
        ..remove('actualizadoEn')
        ..remove('creadoPorNombre');

      final dto = CargaGuardadaDto.fromJson(json);

      // Son metadatos de presentación: que el backend deje de enviarlos hace
      // perder el "quién y cuándo", no la posibilidad de editar el censo.
      expect(dto.actualizadoEn, isNull);
      expect(dto.creadoPorNombre, isNull);
      expect(dto.total, 34, reason: 'el resto de la carga se lee igual');
    });

    test('un actualizadoEn ilegible tampoco impide leer la carga', () {
      final json = jsonDelContrato()..['actualizadoEn'] = 'ayer a la tarde';

      final dto = CargaGuardadaDto.fromJson(json);

      expect(dto.actualizadoEn, isNull);
      expect(dto.total, 34);
    });

    test('camasPrestadas ausente se lee como lista vacía', () {
      final json = jsonDelContrato()..remove('camasPrestadas');

      expect(CargaGuardadaDto.fromJson(json).camasPrestadas, isEmpty);
    });

    test('camasPrestadas vacía se lee como lista vacía', () {
      final json = jsonDelContrato()..['camasPrestadas'] = <dynamic>[];

      expect(CargaGuardadaDto.fromJson(json).camasPrestadas, isEmpty);
    });
  });

  group('CargaGuardadaDto.toDomain', () {
    test('el censo cuadra con capacidad 38 y su dotación da 36', () {
      final censo = CargaGuardadaDto.fromJson(jsonDelContrato()).toDomain();

      // 34 + 2 + 1 + 1 = 38 y 34 + 2 = 36. Si algún contador hubiera caído en
      // el campo equivocado, una de las dos cuentas no daría.
      expect(censo.cuadraCon(38), isTrue);
      expect(censo.dotacion, 36);
    });

    test('cada contador cae en su propio campo, sin cruces', () {
      // Valores todos distintos: con los del contrato, `aislamiento` y
      // `bloqueada` valen 1 los dos y un intercambio pasaría inadvertido.
      final json = jsonDelContrato()
        ..['ingreso'] = 1
        ..['ingresoTraslado'] = 2
        ..['egreso'] = 3
        ..['egresoTraslado'] = 4
        ..['obito'] = 5
        ..['aislamiento'] = 6
        ..['bloqueada'] = 7
        ..['libre'] = 8
        ..['total'] = 9;

      final censo = CargaGuardadaDto.fromJson(json).toDomain();

      expect(censo.valorDe(CampoCenso.ingreso), 1);
      expect(censo.valorDe(CampoCenso.ingresoTraslado), 2);
      expect(censo.valorDe(CampoCenso.egreso), 3);
      expect(censo.valorDe(CampoCenso.egresoTraslado), 4);
      expect(censo.valorDe(CampoCenso.obito), 5);
      expect(censo.valorDe(CampoCenso.aislamiento), 6);
      expect(censo.valorDe(CampoCenso.bloqueada), 7);
      expect(censo.valorDe(CampoCenso.libre), 8);
      expect(censo.valorDe(CampoCenso.total), 9);
    });

    test('la fecha queda sin componente horario', () {
      final censo = CargaGuardadaDto.fromJson(jsonDelContrato()).toDomain();

      // El formulario usa la fecha como clave; una hora colada la haría dejar
      // de coincidir con la que eligió el operador.
      expect(censo.fecha, DateTime(2026, 7, 16));
    });

    test('lleva las camas prestadas al dominio', () {
      final censo = CargaGuardadaDto.fromJson(jsonDelContrato()).toDomain();

      expect(censo.camasPrestadas.single.especialidadId, 'esp-uuid');
      expect(censo.camasPrestadasDirectas, 1);
    });

    test('el censo del contrato no se confunde con uno vacío', () {
      final censo = CargaGuardadaDto.fromJson(jsonDelContrato()).toDomain();

      // Es la diferencia entre precargar el formulario y abrirlo en cero.
      expect(censo.estaVacio, isFalse);
    });
  });
}
