library;
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/fecha_censo.dart';

/// DTOs de carga manual del censo diario.


/// Cuerpo de `POST /censo-diario/carga-manual`.
class GuardarCargaManualDto {
  const GuardarCargaManualDto({
    required this.fecha,
    required this.servicioId,
    required this.ingreso,
    required this.ingresoTraslado,
    required this.egreso,
    required this.egresoTraslado,
    required this.obito,
    required this.bloqueada,
    required this.aislamiento,
    required this.libre,
    required this.total,
    this.camasPrestadas,
  });

  factory GuardarCargaManualDto.fromDomain(CensoServicio censo) {
    return GuardarCargaManualDto(
      fecha: FechaCenso.truncar(censo.fecha),
      servicioId: censo.servicioId,
      ingreso: censo.ingreso,
      ingresoTraslado: censo.ingresoTraslado,
      egreso: censo.egreso,
      egresoTraslado: censo.egresoTraslado,
      obito: censo.obito,
      bloqueada: censo.bloqueada,
      aislamiento: censo.aislamiento,
      libre: censo.libre,
      total: censo.total,
      camasPrestadas: censo.camasPrestadas
          .map(CamaPrestadaDto.fromDomain)
          .toList(),
    );
  }

  final DateTime fecha;
  final String servicioId;
  final int ingreso;
  final int ingresoTraslado;
  final int egreso;
  final int egresoTraslado;
  final int obito;
  final int bloqueada;
  final int aislamiento;
  final int libre;
  final int total;
  final List<CamaPrestadaDto>? camasPrestadas;

  /// El backend hace `new Date(\`${fecha}T00:00:00Z\`)`, así que la fecha viaja
  /// como `YYYY-MM-DD` plano. Un ISO-8601 con offset `-04:00` correría el día
  /// entero hacia atrás.
  ///
  /// **`dotacion` no se envía**: no existe en el DTO del backend, que la
  /// recalcula como `total + libre` e ignora cualquier valor recibido.
  Map<String, dynamic> toJson() {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return <String, dynamic>{
      'fecha': '${fecha.year}-$mes-$dia',
      'servicioId': servicioId,
      'ingreso': ingreso,
      'ingresoTraslado': ingresoTraslado,
      'egreso': egreso,
      'egresoTraslado': egresoTraslado,
      'obito': obito,
      'bloqueada': bloqueada,
      'aislamiento': aislamiento,
      'libre': libre,
      'total': total,
      // Se omite por completo cuando no hay camas prestadas. El campo es
      // opcional en el backend y mandar una lista vacía no aporta nada.
      if (camasPrestadas != null && camasPrestadas!.isNotEmpty)
        'camasPrestadas': camasPrestadas!.map((c) => c.toJson()).toList(),
    };
  }
}

class CamaPrestadaDto {
  const CamaPrestadaDto({
    required this.especialidadId,
    required this.cantidad,
    required this.tipoIngreso,
  });

  factory CamaPrestadaDto.fromDomain(CamaPrestada cama) => CamaPrestadaDto(
        especialidadId: cama.especialidadId,
        cantidad: cama.cantidad,
        tipoIngreso: cama.tipoIngreso.valorApi,
      );

  factory CamaPrestadaDto.fromJson(Map<String, dynamic> json) =>
      CamaPrestadaDto(
        // La respuesta viene en snake_case aunque el request va en camelCase.
        especialidadId:
            (json['especialidad_id'] ?? json['especialidadId']) as String,
        cantidad: (json['cantidad'] as num).toInt(),
        tipoIngreso:
            (json['tipo_ingreso'] ?? json['tipoIngreso']) as String,
      );

  final String especialidadId;
  final int cantidad;

  /// Literal exacto: `'DIRECTO'` o `'TRASLADO'`.
  final String tipoIngreso;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'especialidadId': especialidadId,
        'cantidad': cantidad,
        'tipoIngreso': tipoIngreso,
      };

  CamaPrestada toDomain() => CamaPrestada(
        especialidadId: especialidadId,
        cantidad: cantidad,
        tipoIngreso: TipoIngresoCamaPrestada.desdeApi(tipoIngreso),
      );
}

/// Respuesta 201 de `POST /carga-manual`: fila cruda de staging, snake_case.
class CargaManualGuardadaDto {
  const CargaManualGuardadaDto({
    required this.id,
    required this.fecha,
    required this.servicioId,
    required this.ingreso,
    required this.ingresoTraslado,
    required this.egreso,
    required this.egresoTraslado,
    required this.obito,
    required this.bloqueada,
    required this.aislamiento,
    required this.libre,
    required this.total,
    required this.dotacion,
    this.camasPrestadas = const [],
  });

  factory CargaManualGuardadaDto.fromJson(Map<String, dynamic> json) {
    int entero(String clave1, [String? clave2]) {
      final v1 = json[clave1];
      if (v1 is num) return v1.toInt();
      if (clave2 != null) {
        final v2 = json[clave2];
        if (v2 is num) return v2.toInt();
      }
      return 0;
    }

    final fechaRaw = (json['fecha'] ?? json['fecha_censo'])?.toString() ?? '';
    final fecha = fechaRaw.isNotEmpty ? DateTime.parse(fechaRaw) : DateTime.now();

    final servicioId = (json['servicioId'] ?? json['servicio_id'])?.toString() ?? '';
    final id = (json['id']?.toString()) ?? servicioId;

    final camas = json['camasPrestadas'] ?? json['camas_prestadas'];

    return CargaManualGuardadaDto(
      id: id,
      fecha: fecha,
      servicioId: servicioId,
      ingreso: entero('ingreso'),
      ingresoTraslado: entero('ingresoTraslado', 'ingreso_traslado'),
      egreso: entero('egreso'),
      egresoTraslado: entero('egresoTraslado', 'egreso_traslado'),
      obito: entero('obito'),
      bloqueada: entero('bloqueada'),
      aislamiento: entero('aislamiento'),
      libre: entero('libre'),
      total: entero('total'),
      dotacion: entero('dotacion'),
      camasPrestadas: camas is List
          ? camas
              .cast<Map<String, dynamic>>()
              .map(CamaPrestadaDto.fromJson)
              .map((c) => c.toDomain())
              .toList()
          : const [],
    );
  }

  final String id;
  final DateTime fecha;
  final String servicioId;
  final int ingreso;
  final int ingresoTraslado;
  final int egreso;
  final int egresoTraslado;
  final int obito;
  final int bloqueada;
  final int aislamiento;
  final int libre;
  final int total;

  /// Calculada por el servidor. Se lee para confirmar lo que quedó guardado.
  final int dotacion;
  final List<CamaPrestada> camasPrestadas;

  CensoServicio toDomain({List<CamaPrestada> camasPrestadas = const []}) =>
      CensoServicio(
        fecha: fecha,
        servicioId: servicioId,
        ingreso: ingreso,
        ingresoTraslado: ingresoTraslado,
        egreso: egreso,
        egresoTraslado: egresoTraslado,
        obito: obito,
        bloqueada: bloqueada,
        aislamiento: aislamiento,
        libre: libre,
        total: total,
        camasPrestadas: camasPrestadas.isNotEmpty ? camasPrestadas : this.camasPrestadas,
      );
}

/// `GET /carga-manual?fecha=` — **camelCase**, ya presentado y con relaciones.
///
/// Convive con [CargaManualGuardadaDto] y no se fusiona con él: aquel parsea la
/// respuesta del `POST`, que es la fila cruda de Prisma en snake_case, sin
/// nombres ni procedencia. Son dos formas distintas del mismo dato, y un parser
/// único tolerante a ambas convenciones aceptaría media respuesta en silencio:
/// así se llega a un campo en `null` que nadie nota (SPEC-003, §4.1).
class CargaGuardadaDto {
  const CargaGuardadaDto({
    required this.servicioId,
    required this.servicioNombre,
    required this.fecha,
    required this.ingreso,
    required this.ingresoTraslado,
    required this.egreso,
    required this.egresoTraslado,
    required this.obito,
    required this.aislamiento,
    required this.bloqueada,
    required this.libre,
    required this.total,
    required this.dotacion,
    this.camasPrestadas = const [],
    this.actualizadoEn,
    this.creadoPorNombre,
  });

  factory CargaGuardadaDto.fromJson(Map<String, dynamic> json) {
    int entero(String clave) => (json[clave] as num?)?.toInt() ?? 0;

    final camas = json['camasPrestadas'];
    final actualizado = json['actualizadoEn'] as String?;

    return CargaGuardadaDto(
      servicioId: json['servicioId'] as String,
      servicioNombre: json['servicioNombre'] as String,
      fecha: json['fecha'] as String,
      ingreso: entero('ingreso'),
      ingresoTraslado: entero('ingresoTraslado'),
      egreso: entero('egreso'),
      egresoTraslado: entero('egresoTraslado'),
      obito: entero('obito'),
      aislamiento: entero('aislamiento'),
      bloqueada: entero('bloqueada'),
      libre: entero('libre'),
      total: entero('total'),
      dotacion: entero('dotacion'),
      // Un servicio sin camas prestadas puede llegar con la clave ausente o con
      // la lista vacía; las dos cosas significan lo mismo.
      camasPrestadas: camas is List
          ? camas
              .cast<Map<String, dynamic>>()
              .map(CamaPrestadaGuardadaDto.fromJson)
              .toList()
          : const [],
      // `tryParse` y no `parse` por la misma razón por la que el campo es
      // opcional: un timestamp ilegible degrada la procedencia, no la edición.
      actualizadoEn:
          actualizado == null ? null : DateTime.tryParse(actualizado),
      creadoPorNombre: json['creadoPorNombre'] as String?,
    );
  }

  final String servicioId;
  final String servicioNombre;

  /// `'YYYY-MM-DD'` plano, tal como lo presenta el backend.
  final String fecha;

  final int ingreso;
  final int ingresoTraslado;
  final int egreso;
  final int egresoTraslado;
  final int obito;
  final int aislamiento;
  final int bloqueada;
  final int libre;
  final int total;

  /// Calculada por el servidor como `total + libre`. Se lee para poder
  /// contrastarla, pero **no se propaga**: `CensoServicio.dotacion` la deriva
  /// con la misma fórmula, y dos fuentes para un mismo número terminan
  /// discrepando sin que nadie sepa cuál manda.
  final int dotacion;

  final List<CamaPrestadaGuardadaDto> camasPrestadas;

  /// Procedencia de la carga (D-5). Opcionales a propósito: si el backend
  /// dejara de enviarlos se pierde el "quién y cuándo", no la posibilidad de
  /// editar el censo.
  final DateTime? actualizadoEn;
  final String? creadoPorNombre;

  CensoServicio toDomain() => CensoServicio(
        // El contrato dice `YYYY-MM-DD`, pero se trunca igual: si algún día
        // llegara con hora, la fecha quedaría con componente horario y dejaría
        // de coincidir con la que el formulario usa como clave.
        fecha: FechaCenso.truncar(DateTime.parse(fecha)),
        servicioId: servicioId,
        ingreso: ingreso,
        ingresoTraslado: ingresoTraslado,
        egreso: egreso,
        egresoTraslado: egresoTraslado,
        obito: obito,
        aislamiento: aislamiento,
        bloqueada: bloqueada,
        libre: libre,
        total: total,
        camasPrestadas: camasPrestadas.map((c) => c.toDomain()).toList(),
      );
}

/// Cama prestada tal como la devuelve el `GET`: camelCase y con el nombre de la
/// especialidad ya resuelto, que el `POST` no trae (comparar con
/// [CamaPrestadaDto], que además serializa el cuerpo del request).
class CamaPrestadaGuardadaDto {
  const CamaPrestadaGuardadaDto({
    required this.especialidadId,
    required this.especialidadNombre,
    required this.cantidad,
    required this.tipoIngreso,
  });

  factory CamaPrestadaGuardadaDto.fromJson(Map<String, dynamic> json) =>
      CamaPrestadaGuardadaDto(
        especialidadId: json['especialidadId'] as String,
        especialidadNombre: json['especialidadNombre'] as String,
        cantidad: (json['cantidad'] as num).toInt(),
        tipoIngreso: TipoIngresoCamaPrestada.desdeApi(
          json['tipoIngreso'] as String,
        ),
      );

  final String especialidadId;

  /// Nombre para mostrar (CA-02). Lo resuelve el servidor, así que listar lo
  /// guardado no depende de tener cargado el mapeo de especialidades.
  final String especialidadNombre;

  final int cantidad;

  /// Ya resuelto al enum: el literal crudo no hace falta después del parseo.
  final TipoIngresoCamaPrestada tipoIngreso;

  CamaPrestada toDomain() => CamaPrestada(
        especialidadId: especialidadId,
        cantidad: cantidad,
        tipoIngreso: tipoIngreso,
      );
}

/// `GET /carga-manual/estado?fecha=` — **camelCase**.
class EstadoCargaManualDto {
  const EstadoCargaManualDto({
    required this.servicioId,
    required this.servicioNombre,
    required this.cargado,
    this.cuadra,
  });

  factory EstadoCargaManualDto.fromJson(Map<String, dynamic> json) =>
      EstadoCargaManualDto(
        servicioId: json['servicioId'] as String,
        servicioNombre: json['servicioNombre'] as String,
        cargado: json['cargado'] as bool? ?? false,
        cuadra: json['cuadra'] as bool?,
      );

  final String servicioId;
  final String servicioNombre;
  final bool cargado;
  final bool? cuadra;

  ProgresoServicio toDomain() => ProgresoServicio(
        servicioId: servicioId,
        servicioNombre: servicioNombre,
        cargado: cargado,
        // Contrato: cargado == false implica cuadra == null. Se normaliza acá
        // para que la capa de dominio no tenga que desconfiar del servidor.
        cuadra: cargado ? cuadra : null,
      );
}

/// Respuesta de `POST /carga-manual/confirmar`.
class ConfirmacionDiaDto {
  const ConfirmacionDiaDto({required this.fecha, required this.servicios});

  factory ConfirmacionDiaDto.fromJson(Map<String, dynamic> json) =>
      ConfirmacionDiaDto(
        fecha: json['fecha'] as String,
        servicios: (json['servicios'] as num?)?.toInt() ?? 0,
      );

  final String fecha;
  final int servicios;

  ConfirmacionDia toDomain() =>
      ConfirmacionDia(fecha: fecha, servicios: servicios);
}
