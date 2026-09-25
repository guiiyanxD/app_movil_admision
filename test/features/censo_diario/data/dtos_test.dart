import 'package:app_movil/features/censo_diario/data/models/carga_manual_dtos.dart';
import 'package:app_movil/features/censo_diario/data/models/catalogo_dtos.dart';
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los JSON de este archivo están copiados de los ejemplos de
/// `software-migracion/docs/api-carga-manual-app-movil.md`. Si el backend
/// cambia el contrato, estos tests son los primeros en avisar.
void main() {
  group('Catálogos — snake_case crudo de Postgres', () {
    test('ServicioDto lee la fila cruda de /servicios', () {
      final dto = ServicioDto.fromJson({
        'id': '3fa1-uuid',
        'nombre': 'Medicina Interna',
        'codigo': 'MED-INT',
        'activo': true,
        'creado_en': '2026-07-15T00:00:00.000Z',
        'actualizado_en': '2026-07-15T00:00:00.000Z',
      });

      expect(dto.id, '3fa1-uuid');
      expect(dto.nombre, 'Medicina Interna');
      expect(dto.codigo, 'MED-INT');
      expect(dto.activo, isTrue);
    });

    test('MapeoServicioDto lee servicio_id y nombre_vaciado', () {
      final dto = MapeoServicioDto.fromJson({
        'servicio_id': '3fa1-uuid',
        'nombre_vaciado': 'Medicina Interna',
        'servicio': {'id': '3fa1-uuid', 'nombre': 'Medicina Interna'},
      });

      expect(dto.servicioId, '3fa1-uuid');
      expect(dto.nombreVaciado, 'Medicina Interna');
    });

    test('MapeoEspecialidadDto prefiere el nombre local al de vaciado', () {
      final dto = MapeoEspecialidadDto.fromJson({
        'especialidad_id': 'esp-1',
        'nombre_vaciado': 'Cardiologia',
        'especialidad': {'id': 'esp-1', 'nombre': 'Cardiología'},
      });

      // En el selector se muestra el nombre del sistema propio, con tilde,
      // no el del sistema al que traducimos.
      expect(dto.toDomain().nombreVaciado, 'Cardiología');
    });

    test('MapeoEspecialidadDto tolera la relación anidada ausente', () {
      final dto = MapeoEspecialidadDto.fromJson({
        'especialidad_id': 'esp-1',
        'nombre_vaciado': 'Cardiologia',
      });

      expect(dto.especialidadNombre, isNull);
      expect(dto.toDomain().nombreVaciado, 'Cardiologia');
    });

    test('Servicio sin fila de mapeo queda marcado como tal (V-06)', () {
      final conMapeo = ServicioDto.fromJson({
        'id': 'a',
        'nombre': 'Medicina Interna',
        'activo': true,
      }).toDomain(nombreVaciado: 'Medicina Interna');

      final sinMapeo = ServicioDto.fromJson({
        'id': 'b',
        'nombre': 'UCIM',
        'activo': true,
      }).toDomain();

      expect(conMapeo.tieneMapeo, isTrue);
      expect(sinMapeo.tieneMapeo, isFalse);
    });
  });

  group('Histórico y cierre', () {
    test('HistoricoCensoDto lee camelCase', () {
      final dto = HistoricoCensoDto.fromJson({
        'fecha': '2026-06-01',
        'servicio': 'Medicina Interna',
        'ingreso': 3,
        'ingresoTraslado': 0,
        'egreso': 2,
        'egresoTraslado': 0,
        'obito': 0,
        'aislamiento': 1,
        'bloqueada': 0,
        'total': 8,
        'libre': 2,
        'dotacion': 10,
      });

      expect(dto.servicio, 'Medicina Interna');
      expect(dto.total, 8);
      expect(dto.dotacion, 10);
    });

    test('CierreCensoDto con origen automático bloquea la carga manual', () {
      final dto = CierreCensoDto.fromJson({
        'fecha_censo': '2026-06-01T00:00:00.000Z',
        'origen': 'automatico',
      });

      expect(dto.toDomain().bloqueaCargaManual, isTrue);
    });

    test('CierreCensoDto con origen manual permite rectificar', () {
      final dto = CierreCensoDto.fromJson({
        'fecha_censo': '2026-06-01T00:00:00.000Z',
        'origen': 'manual',
      });

      expect(dto.toDomain().bloqueaCargaManual, isFalse);
    });

    test('un origen desconocido se trata como automático, por prudencia', () {
      final dto = CierreCensoDto.fromJson({
        'fecha_censo': '2026-06-01T00:00:00.000Z',
        'origen': 'algo_nuevo',
      });

      // Es preferible bloquear una fecha de más que pisar un cierre real.
      expect(dto.toDomain().bloqueaCargaManual, isTrue);
    });
  });

  group('GuardarCargaManualDto — cuerpo del POST', () {
    CensoServicio censoBase() => CensoServicio(
          fecha: DateTime(2026, 6),
          servicioId: '3fa1-uuid',
          ingreso: 3,
          egreso: 2,
          aislamiento: 1,
          libre: 2,
          total: 8,
        );

    test('la fecha viaja como YYYY-MM-DD plano, sin offset (CA-07)', () {
      final json = GuardarCargaManualDto.fromDomain(censoBase()).toJson();

      expect(json['fecha'], '2026-06-01');
      expect((json['fecha'] as String).contains('T'), isFalse);
      expect((json['fecha'] as String).length, 10);
    });

    test('una hora tardía no corre el día', () {
      final censo = censoBase().copyWith(fecha: DateTime(2026, 6, 1, 23, 45));
      final json = GuardarCargaManualDto.fromDomain(censo).toJson();

      expect(json['fecha'], '2026-06-01');
    });

    test('no envía dotacion: el servidor la recalcula', () {
      final json = GuardarCargaManualDto.fromDomain(censoBase()).toJson();

      expect(json.containsKey('dotacion'), isFalse);
    });

    test('envía los 9 campos con los nombres del contrato', () {
      final json = GuardarCargaManualDto.fromDomain(censoBase()).toJson();

      for (final clave in [
        'ingreso',
        'ingresoTraslado',
        'egreso',
        'egresoTraslado',
        'obito',
        'bloqueada',
        'aislamiento',
        'libre',
        'total',
      ]) {
        expect(json.containsKey(clave), isTrue, reason: clave);
      }
      expect(json['servicioId'], '3fa1-uuid');
    });

    test('omite camasPrestadas cuando no hay ninguna', () {
      final json = GuardarCargaManualDto.fromDomain(censoBase()).toJson();

      expect(json.containsKey('camasPrestadas'), isFalse);
    });

    test('serializa camasPrestadas con el literal exacto del tipo', () {
      final censo = censoBase().copyWith(
        camasPrestadas: const [
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 2,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ],
      );

      final json = GuardarCargaManualDto.fromDomain(censo).toJson();
      final camas = json['camasPrestadas']! as List<dynamic>;
      final primera = camas.first as Map<String, dynamic>;

      expect(camas, hasLength(1));
      expect(primera['especialidadId'], 'esp-1');
      expect(primera['cantidad'], 2);
      expect(primera['tipoIngreso'], 'DIRECTO');
    });
  });

  group('CargaManualGuardadaDto — respuesta 201, snake_case', () {
    test('lee la fila de staging del ejemplo de la guía', () {
      final dto = CargaManualGuardadaDto.fromJson({
        'id': 'carga-uuid',
        'fecha': '2026-06-01T00:00:00.000Z',
        'servicio_id': '3fa1-uuid',
        'ingreso': 3,
        'ingreso_traslado': 0,
        'egreso': 2,
        'egreso_traslado': 0,
        'obito': 0,
        'bloqueada': 0,
        'aislamiento': 1,
        'libre': 2,
        'total': 8,
        'dotacion': 10,
        'creado_por_id': 'usr-uuid',
      });

      expect(dto.id, 'carga-uuid');
      expect(dto.servicioId, '3fa1-uuid');
      expect(dto.total, 8);
      expect(dto.dotacion, 10);
      expect(dto.toDomain().dotacion, 10, reason: 'total 8 + libre 2');
    });

    test('lee la respuesta real del backend en camelCase sin id explícito', () {
      final dto = CargaManualGuardadaDto.fromJson({
        'servicioId': '3fa1-uuid',
        'servicioNombre': 'Medicina Interna',
        'fecha': '2026-06-01',
        'ingreso': 3,
        'ingresoTraslado': 1,
        'egreso': 2,
        'egresoTraslado': 1,
        'obito': 0,
        'aislamiento': 1,
        'bloqueada': 0,
        'libre': 2,
        'total': 8,
        'dotacion': 10,
        'camasPrestadas': <dynamic>[],
        'actualizadoEn': '2026-09-03T11:00:00.000Z',
        'creadoPorNombre': 'Operador',
      });

      expect(dto.servicioId, '3fa1-uuid');
      expect(dto.id, '3fa1-uuid');
      expect(dto.ingreso, 3);
      expect(dto.ingresoTraslado, 1);
      expect(dto.egresoTraslado, 1);
      expect(dto.total, 8);
      expect(dto.dotacion, 10);
      expect(dto.toDomain().dotacion, 10);
    });
  });

  group('EstadoCargaManualDto — camelCase', () {
    test('lee el ejemplo de la guía', () {
      final cargado = EstadoCargaManualDto.fromJson({
        'servicioId': '3fa1-uuid',
        'servicioNombre': 'Medicina Interna',
        'cargado': true,
        'cuadra': true,
      });
      final pendiente = EstadoCargaManualDto.fromJson({
        'servicioId': '9c2b-uuid',
        'servicioNombre': 'Pediatría',
        'cargado': false,
        'cuadra': null,
      });

      expect(cargado.toDomain().listo, isTrue);
      expect(pendiente.toDomain().listo, isFalse);
      expect(pendiente.toDomain().cuadra, isNull);
    });

    test('normaliza cuadra a null si el servicio no está cargado', () {
      // Contrato: cargado == false implica cuadra == null. Se normaliza para
      // que el dominio no tenga que desconfiar del servidor.
      final dto = EstadoCargaManualDto.fromJson({
        'servicioId': 'x',
        'servicioNombre': 'X',
        'cargado': false,
        'cuadra': true,
      });

      expect(dto.toDomain().cuadra, isNull);
    });
  });

  group('ConfirmacionDiaDto', () {
    test('lee fecha y cantidad de servicios', () {
      final dto = ConfirmacionDiaDto.fromJson({
        'fecha': '2026-06-01',
        'servicios': 8,
      });

      expect(dto.toDomain().fecha, '2026-06-01');
      expect(dto.toDomain().servicios, 8);
    });
  });
}
