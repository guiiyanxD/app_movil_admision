# SPEC-002 — Módulo Censo Diario (Formulario EST-1)

| Campo | Valor |
|---|---|
| **ID** | SPEC-002 |
| **Título** | Captura móvil del Censo Diario — Formulario EST-1 (backfill histórico) |
| **Estado** | Borrador v4 — P-01 a P-06 resueltas (2026-07-31). La limitación de lectura del staging quedó **resuelta** por SPEC-003 (2026-08-03). |
| **Autor** | Willtech — Arquitectura de Software |
| **Fecha** | 2026-07-31 |
| **Sprint objetivo** | Sprint 1 (MVP interno, 3 semanas) |
| **Contrato consumido** | `software-migracion/docs/api-carga-manual-app-movil.md` |
| **Fuentes primarias** | `software-migracion/docs/superpowers/plans/2026-07-29-carga-manual-censo-diario.md`, `apps/api/src/modulos/censo-diario/` |
| **Depende de** | SPEC-001 (Speech-to-Text), ADR-0002 (Riverpod), ADR-0003 (STT) |

---

## 1. Contexto y alcance

El Servicio de Admisión de la Caja Petrolera de Salud (Regional Santa Cruz) opera diariamente el
formulario **EST-1 — Censo Diario**, en papel, para ~13 servicios hospitalarios (cifra
referencial, **nunca una constante del código** — ver P-03). El sistema
`software-migracion` calcula el censo **en vivo** de forma automática a partir de eventos de
paciente (`BedStay`), pero **no existen esos eventos para las fechas anteriores al cutover a
producción**. Esta app móvil existe para poblar esa historia.

### 1.1 Dentro del alcance

- Captura del **consolidado estadístico** por servicio y fecha: los 9 contadores del EST-1.
- Captura opcional de **camas prestadas** por especialidad.
- **Entrada dual**: teclado numérico y dictado por voz (Speech-to-Text).
- **Pre-carga y confirmación explícita** de todo dato originado en voz, antes de cualquier
  persistencia.
- **Panel de progreso del día**: qué servicios están cargados y cuáles cuadran.
- **Confirmación del día completo** (escritura definitiva en las tablas de vaciado-admisión).

### 1.2 Fuera del alcance (decisiones cerradas, 2026-07-31)

| Fuera de alcance | Razón |
|---|---|
| **Movimientos detallados por paciente** (H.C., Pieza, Hora, Nombre) | El contrato HTTP **no tiene ningún campo ni endpoint** para persistirlos. Se decidió capturar únicamente contadores agregados. El detalle sigue viviendo en el formulario de papel. |
| **Censo diario en vivo / operación a medianoche** | El backend rechaza con `403` la fecha de hoy y futuras, y bloquea sobrescribir un cierre de `origen: automatico`. Este módulo es exclusivamente **backfill histórico**. |
| **Dictado por voz de nombres propios y códigos de pieza** | Alto índice de error del STT con antropónimos bolivianos. La voz cubre **solo cifras del resumen**. |
| **Modo offline-first con cola de sincronización** | El contrato guarda staging en el servidor en cada `POST`; no hay ventana de trabajo sin conexión contemplada (§10 de la guía de integración). |
| **Módulo de cámara** | Planificado estructuralmente para Sprint 2 (solo esqueleto de carpetas). |

> **Riesgo abierto (R-01).** Si en el futuro Admisión quiere operar el censo diario en vivo desde
> la app, este módulo **no sirve tal cual**: requiere negociar con el equipo de backend un cambio
> en `puedeCargarManual` y una política de convivencia con `CierreCenso.origen = 'automatico'`.
> Registrar como ADR nuevo, no como cambio incremental de esta spec.

---

## 2. Modelo de dominio

### 2.1 Lectura del formulario físico (EST-1)

El formulario en papel tiene bloques de **movimiento detallado** (una fila por paciente) y un
bloque **RESUMEN**. Solo se digitalizan cifras; el detalle se usa como insumo de conteo manual.

**Bloques de movimiento detallado → contadores**

| Bloque en papel | Destino digital |
|---|---|
| `INGRESO (POR ADMISIÓN)` — H.C., Pieza, Hora, Nombre | Se cuenta → `ingreso` |
| `INGRESO — POR TRASLADO DEL SERVICIO` | Se cuenta → `ingresoTraslado` |
| `EGRESO (POR SALIDA)` — H.C., Pieza, Hora, Nombre | Se cuenta → `egreso` |
| `EGRESO — POR TRASLADO DEL SERVICIO` | Se cuenta → `egresoTraslado` |
| `EGRESO — POR MUERTE` | Se cuenta → `obito` |

**Bloque RESUMEN, fila por fila** (confirmado con Admisión, 2026-07-31)

| Etiqueta impresa en el papel | Significado real | Destino digital |
|---|---|---|
| Pacientes del día anterior | Saldo de cierre del día previo | **Referencia** (V-07). No se envía; se obtiene de `GET /historico` de `fecha − 1`. |
| Pacientes ingresados | Pacientes que entraron al servicio | Referencia. Los contadores salen de contar los bloques, no de esta casilla. |
| Pacientes fallecidos | Óbitos | `obito` |
| ~~Ingresos y egresos del mismo día~~ | ⚠️ **Etiqueta desactualizada.** En la práctica acá se registran los **egresos directos**. | `egreso` |
| Saldo pacientes a las 24 horas | Pacientes al cierre de la jornada | `total` |
| Números de camas libres | Camas disponibles | `libre` |
| Capacidad del servicio | Camas del servicio | **Referencia** (V-05). No se envía; se obtiene de `GET /camas`. |
| *(sin fila impresa)* | Camas en aislamiento | `aislamiento` |
| *(sin fila impresa)* | Camas bloqueadas | `bloqueada` |
| *(sin fila impresa)* | Camas prestadas | Anotación manual al margen (ej. "Cir = 1"). Ver §2.5. |

> **La etiqueta impresa miente y no se va a reimprimir.** "Ingresos y egresos del mismo día" es
> texto heredado; el operador escribe ahí los egresos directos. La app **no debe reproducir esa
> etiqueta**: rotula el campo como "Egresos por salida" y muestra, como texto auxiliar, *"en el
> formulario: fila «Ingresos y egresos del mismo día»"*. Reproducir el rótulo viejo perpetúa el
> error; ocultarlo por completo hace que el operador no encuentre la correspondencia con el papel
> que tiene delante. Se muestran ambos, con jerarquía. Ver componente `GuiaTranscripcionEst1` §8.3.

**Verificación aritmética con la muestra fotografiada** (Medicina Interna, 16-jul, piso 1°):
`33 (día anterior) + 4 (ingresados) − 3 (fila desactualizada = egresos) − 0 (fallecidos) = 34`
= saldo a las 24 h registrado. La fórmula de `saldoEsperado` (§2.3) reproduce exactamente esto.

### 2.5 Camas prestadas — semántica exacta

Confirmado con Admisión y verificado contra la query `construirFilasCamasPrestadas`
(`censo-diario.service.ts:146`), que es la definición canónica de qué es una cama prestada en
este sistema:

```sql
WHERE cp.inicio >= fecha AND cp.inicio < fecha + 1      -- estancias que EMPIEZAN ese día
  AND cp.especialidad_id != cp.especialidad_nativa_id   -- paciente en cama de otra especialidad
```

| Campo | Significado exacto |
|---|---|
| `servicio` | Servicio **dueño de la cama** — el servicio cuyo EST-1 se está llenando. |
| `especialidadId` | Especialidad **del paciente**, distinta de la especialidad nativa de la cama. En la anotación "Cir = 1" de la muestra: el paciente es de **Cirugía** y ocupa una cama de Medicina Interna. |
| `cantidad` | Cuántos pacientes con esa combinación. |
| `tipoIngreso` | `DIRECTO` si la estancia no tiene una estancia previa contigua (ingreso por admisión); `TRASLADO` si el paciente venía de otra cama. |

**Tres consecuencias de diseño:**

1. **Es un flujo, no un stock.** Cuenta estancias que **empiezan** ese día, igual que los
   contadores de ingreso — no camas prestadas ocupadas al cierre. En la muestra: de los 4 ingresos
   del día, 1 entró a una cama prestada, por admisión directa.
2. **No participa en ninguna fórmula.** No afecta `total`, ni `dotacion`, ni el cuadre contra la
   capacidad. Es un registro paralelo, puramente informativo — el mismo criterio que ya rige en la
   vista web (`2026-07-17-camas-prestadas-censo-diario-design.md`: *"No participa en el cálculo de
   `cuadrado` ni bloquea el botón de cierre"*). El paciente en cama prestada **sí** cuenta como
   paciente del servicio en `total`, porque ocupa una cama del servicio.
3. **En backfill sí persiste lo que carga el operador.** Diferencia importante con el flujo en
   vivo: `CerrarCensoCasoUso` recalcula camas prestadas desde los `BedStay` y pisaría cualquier
   edición manual, pero `ConfirmarCargaManualCasoUso` **copia tal cual** lo cargado en staging a
   `VaciadoCamaPrestada`. Para fechas históricas no hay `BedStay` que recalcular, así que el
   conteo manual del operador es el único dato — y sobrevive.

> **R-08 — Única entrada sin respaldo estructurado.** El EST-1 impreso no tiene sección de camas
> prestadas; el conteo se hace a mano desde hace años y se anota al margen. Es el dato más frágil
> del formulario. La sección va **opcional y colapsada**: su ausencia nunca bloquea el guardado ni
> la confirmación del día.

> **Origen de los traslados.** El RESUMEN **no tiene fila propia para ingresos ni egresos por
> traslado**: esos números salen **exclusivamente de contar los bloques
> `POR TRASLADO DEL SERVICIO`**, nunca de leer una casilla del resumen (confirmado con Admisión,
> 2026-07-31). La app debe reflejar ese orden de trabajo: los cuatro contadores de movimiento se
> obtienen contando bloques; el RESUMEN solo aporta `total`, `libre` y las referencias.

### 2.2 Enums

```dart
// lib/features/censo_diario/domain/entities/tipo_movimiento_censo.dart

/// Los 5 tipos de evento del EST-1. En este módulo NO clasifican filas de paciente
/// (ver §1.2): etiquetan cada uno de los 5 contadores de movimiento del consolidado.
enum TipoMovimientoCenso {
  ingresoDirecto(etiqueta: 'Ingreso por admisión', campoApi: 'ingreso'),
  ingresoPorTraslado(etiqueta: 'Ingreso por traslado', campoApi: 'ingresoTraslado'),
  egresoDirecto(etiqueta: 'Egreso por salida', campoApi: 'egreso'),
  egresoPorTraslado(etiqueta: 'Egreso por traslado', campoApi: 'egresoTraslado'),
  obito(etiqueta: 'Egreso por muerte', campoApi: 'obito');

  const TipoMovimientoCenso({required this.etiqueta, required this.campoApi});

  final String etiqueta;
  final String campoApi;

  /// Signo con el que el contador afecta el saldo de las 24 horas.
  int get signoEnSaldo => switch (this) {
        ingresoDirecto || ingresoPorTraslado => 1,
        egresoDirecto || egresoPorTraslado || obito => -1,
      };
}

/// Estado de una cama que NO está ocupada por un paciente censado.
enum EstadoCamaCenso { aislamiento, bloqueada, libre }

/// Tipo de ingreso de una cama prestada. Literal exacto exigido por el backend.
enum TipoIngresoCamaPrestada {
  directo('DIRECTO'),
  traslado('TRASLADO');

  const TipoIngresoCamaPrestada(this.valorApi);
  final String valorApi;
}

/// Origen del valor de un campo. Determina si exige confirmación explícita.
enum OrigenDato { manual, voz, calculado }
```

### 2.3 Entidades de dominio (Dart puro, sin Flutter ni plugins)

```dart
// lib/features/censo_diario/domain/entities/servicio.dart
class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.activo,
  });
  final String id;        // uuid — se usa como servicioId en todos los endpoints
  final String nombre;
  final String? codigo;
  final bool activo;
}

// lib/features/censo_diario/domain/entities/mapeo_vaciado.dart
/// Traducción servicioId/especialidadId → nombre en vaciado-admisión.
/// Sin esta fila el día NO se puede confirmar (400 del backend).
class MapeoVaciado {
  const MapeoVaciado({required this.entidadId, required this.nombreVaciado});
  final String entidadId;
  final String nombreVaciado;
}

// lib/features/censo_diario/domain/entities/cama_prestada.dart
class CamaPrestada {
  const CamaPrestada({
    required this.especialidadId,
    required this.cantidad,      // >= 1
    required this.tipoIngreso,
  });
  final String especialidadId;
  final int cantidad;
  final TipoIngresoCamaPrestada tipoIngreso;

  /// Clave de unicidad exigida por el backend: no puede repetirse (400).
  String get claveUnicidad => '$especialidadId::${tipoIngreso.valorApi}';
}

// lib/features/censo_diario/domain/entities/censo_servicio.dart
/// Consolidado estadístico de UN servicio en UNA fecha. Núcleo del EST-1.
class CensoServicio {
  const CensoServicio({
    required this.fecha,              // solo fecha, sin hora
    required this.servicioId,
    required this.ingreso,
    required this.ingresoTraslado,
    required this.egreso,
    required this.egresoTraslado,
    required this.obito,
    required this.aislamiento,
    required this.bloqueada,
    required this.libre,
    required this.total,              // "Saldo pacientes a las 24 horas"
    this.camasPrestadas = const [],
  });

  final DateTime fecha;
  final String servicioId;
  final int ingreso, ingresoTraslado, egreso, egresoTraslado, obito;
  final int aislamiento, bloqueada, libre, total;
  final List<CamaPrestada> camasPrestadas;

  // ── Reglas de negocio derivadas ──────────────────────────────────────────

  /// Regla del backend. NO se envía: el servidor la recalcula como total + libre.
  int get dotacion => total + libre;

  int get totalIngresos => ingreso + ingresoTraslado;
  int get totalEgresos => egreso + egresoTraslado + obito;

  /// Cuadre contra la capacidad real del servicio (cantidad de camas activas).
  /// Idéntica a `calcularCuadreCargaManual` del backend.
  bool cuadraCon(int capacidad) =>
      total + libre + bloqueada + aislamiento == capacidad;

  int sumaEstadosCama() => total + libre + bloqueada + aislamiento;

  /// Saldo esperado a las 24 h a partir del cierre del día anterior.
  /// Decisión de dominio (2026-07-31): el ÓBITO es independiente del egreso;
  /// un fallecido NO se cuenta también como egreso.
  int saldoEsperado(int totalDiaAnterior) =>
      totalDiaAnterior + totalIngresos - totalEgresos;
}

// lib/features/censo_diario/domain/entities/progreso_dia.dart
class ProgresoServicio {
  const ProgresoServicio({
    required this.servicioId,
    required this.servicioNombre,
    required this.cargado,
    required this.cuadra,   // null cuando cargado == false
  });
  final String servicioId;
  final String servicioNombre;
  final bool cargado;
  final bool? cuadra;

  bool get listo => cargado && cuadra == true;
}

class ProgresoDia {
  const ProgresoDia({required this.fecha, required this.servicios});
  final DateTime fecha;
  final List<ProgresoServicio> servicios;

  int get cargados => servicios.where((s) => s.cargado).length;
  int get total => servicios.length;
  bool get puedeConfirmar =>
      servicios.isNotEmpty && servicios.every((s) => s.listo);
}
```

### 2.4 Regla de fecha (invariante de dominio)

```dart
// lib/features/censo_diario/domain/value_objects/fecha_censo.dart
/// Espejo cliente de `puedeCargarManual` del backend. IMPORTANTE: el backend
/// compara en UTC; Bolivia es UTC-4 sin DST, así que entre las 20:00 y las 23:59
/// hora local el backend YA considera "ayer" al día en curso y lo aceptaría.
/// El cliente usa hora local de Bolivia a propósito: es MÁS ESTRICTO que el
/// backend, nunca menos. Nunca se debe relajar esta regla para "aprovechar" el
/// hueco de UTC. (Riesgo R-02.)
class FechaCenso {
  factory FechaCenso(DateTime fecha, {DateTime? ahora}) { ... }

  /// Serialización obligatoria: 'YYYY-MM-DD' plano.
  /// NUNCA enviar ISO-8601 con offset local — el backend hace
  /// `new Date(`${fecha}T00:00:00Z`)` y un offset -04:00 corre el día.
  String get comoParametroApi => ...;

  static bool esCargable(DateTime fecha, {DateTime? ahora}) => ...;
}
```

---

## 3. Contrato consumido (resumen operativo)

| # | Método | Ruta | Rol | Uso |
|---|---|---|---|---|
| 1 | POST | `/api/v1/auth/login` | público | Login (`accessToken` 1 d, `refreshToken` 7 d) |
| 2 | GET | `/api/v1/servicios?soloActivos=true` | cualquiera | Selector de servicio (cachear) |
| 3 | GET | `/api/v1/censo-diario/mapeo/servicios` | admin, operador | Traducción a nombre de vaciado (cachear) |
| 4 | GET | `/api/v1/censo-diario/mapeo/especialidades` | admin, operador | Ídem para camas prestadas |
| 5 | GET | `/api/v1/camas?servicioId=&soloActivas=true` | cualquiera | **Capacidad** para prevalidar el cuadre |
| 6 | GET | `/api/v1/censo-diario/historico?fecha=` | cualquiera | Total de cierre del día anterior |
| 7 | POST | `/api/v1/censo-diario/carga-manual` | admin, operador | Guardar un servicio (upsert por fecha+servicio) |
| 8 | GET | `/api/v1/censo-diario/carga-manual/estado?fecha=` | cualquiera | Progreso del día |
| 9 | POST | `/api/v1/censo-diario/carga-manual/confirmar` | admin, operador | Cerrar el día completo |
| 10 | GET | `/api/v1/censo-diario/cierre/:fecha` | cualquiera | **Pre-chequeo**: ¿la fecha ya está cerrada y con qué `origen`? |

> **Dos endpoints útiles que la guía de integración no documenta.** Verificados en el código
> fuente, no inferidos:
>
> 1. **`GET /api/v1/camas?servicioId=&soloActivas=true`** — §9 de `api-carga-manual-app-movil.md`
>    afirma que está "fuera del alcance" y que la app no puede prevalidar el cuadre. Existe en
>    `camas.controller.ts`, acepta ambos query params y no tiene `@Roles`. `camas.service.listar`
>    filtra por `activa: true`, exactamente el mismo criterio que usa el backend para calcular la
>    capacidad (`tx.cama.count({ where: { servicio_id, activa: true } })`). **La capacidad es el
>    `length` de esa lista.** Con esto la app prevalida el cuadre y evita el `400`.
> 2. **`GET /api/v1/censo-diario/cierre/:fecha`** — devuelve la fila de `CierreCenso` (incluido
>    `origen`) o `null`. Permite detectar **antes** de que el operador empiece a cargar que esa
>    fecha ya tiene un cierre `origen: "automatico"`, que hará fallar la confirmación con `403`
>    después de digitar los 13 servicios. Se usa en la selección de fecha, no al confirmar.
>
> **Acción:** proponer al equipo de backend la corrección de §9 y la incorporación de ambos
> endpoints a la guía de integración.

**Notas de contrato que la implementación debe respetar:**

- Los `GET` de catálogo (2, 3) devuelven **filas crudas de Postgres en `snake_case`**.
  Los endpoints 6 y 8 devuelven **`camelCase`**. Los mapeadores deben ser distintos — no asumir
  una convención global.
- `POST /carga-manual` responde **`201`** (default de NestJS), no `200`.
- `POST /carga-manual` es **upsert por `(fecha, servicioId)`**: reenviar reemplaza, no duplica.
  Las camas prestadas se **reemplazan completas**, no se acumulan.
- **`dotacion` no se envía.** No existe en el DTO; cualquier valor enviado se ignora.
- `confirmar` **revalida todos los servicios** contra la capacidad de camas *del momento de
  confirmar*. Un servicio que cuadraba puede dejar de cuadrar si cambió el catálogo de camas.
  → La app debe refrescar `GET /estado` inmediatamente antes de habilitar "Confirmar día".

---

## 4. Capa de datos: DTOs y mapeo

Regla de capas: los DTO viven en `data/models/`, conocen `snake_case`/`camelCase` y JSON. Las
entidades de `domain/` no saben que existe HTTP.

```dart
// lib/features/censo_diario/data/models/guardar_carga_manual_dto.dart
@freezed
class GuardarCargaManualDto with _$GuardarCargaManualDto {
  const factory GuardarCargaManualDto({
    required String fecha,          // 'YYYY-MM-DD' plano
    required String servicioId,
    required int ingreso,
    required int ingresoTraslado,
    required int egreso,
    required int egresoTraslado,
    required int obito,
    required int bloqueada,
    required int aislamiento,
    required int libre,
    required int total,
    List<CamaPrestadaDto>? camasPrestadas,   // se OMITE si está vacía
  }) = _GuardarCargaManualDto;

  factory GuardarCargaManualDto.fromDomain(CensoServicio censo) => ...;
  factory GuardarCargaManualDto.fromJson(Map<String, dynamic> json) => ...;
}

// data/models/cama_prestada_dto.dart
@freezed
class CamaPrestadaDto with _$CamaPrestadaDto {
  const factory CamaPrestadaDto({
    required String especialidadId,
    required int cantidad,          // >= 1
    required String tipoIngreso,    // 'DIRECTO' | 'TRASLADO'
  }) = _CamaPrestadaDto;
}

// data/models/servicio_dto.dart — OJO: snake_case crudo de Postgres
@freezed
class ServicioDto with _$ServicioDto {
  const factory ServicioDto({
    required String id,
    required String nombre,
    String? codigo,
    required bool activo,
    @JsonKey(name: 'creado_en') DateTime? creadoEn,
    @JsonKey(name: 'actualizado_en') DateTime? actualizadoEn,
  }) = _ServicioDto;
}

// data/models/mapeo_servicio_dto.dart — snake_case + relación anidada
@freezed
class MapeoServicioDto with _$MapeoServicioDto {
  const factory MapeoServicioDto({
    @JsonKey(name: 'servicio_id') required String servicioId,
    @JsonKey(name: 'nombre_vaciado') required String nombreVaciado,
  }) = _MapeoServicioDto;
}

// data/models/estado_carga_manual_dto.dart — camelCase
@freezed
class EstadoCargaManualDto with _$EstadoCargaManualDto {
  const factory EstadoCargaManualDto({
    required String servicioId,
    required String servicioNombre,
    required bool cargado,
    bool? cuadra,
  }) = _EstadoCargaManualDto;
}

// data/models/historico_censo_dto.dart — camelCase
@freezed
class HistoricoCensoDto with _$HistoricoCensoDto {
  const factory HistoricoCensoDto({
    required String fecha,
    required String servicio,     // nombre de VACIADO, no el nombre local
    required int ingreso, required int ingresoTraslado,
    required int egreso, required int egresoTraslado,
    required int obito, required int aislamiento, required int bloqueada,
    required int total, required int libre, required int dotacion,
  }) = _HistoricoCensoDto;
}
```

### 4.1 Contratos de repositorio (domain)

```dart
abstract interface class CensoDiarioRepository {
  Future<Either<Failure, List<Servicio>>> obtenerServiciosActivos();
  Future<Either<Failure, List<MapeoVaciado>>> obtenerMapeoServicios();
  Future<Either<Failure, List<MapeoVaciado>>> obtenerMapeoEspecialidades();
  Future<Either<Failure, int>> obtenerCapacidadServicio(String servicioId);
  /// null ⇒ la fecha no está cerrada. Se usa para bloquear fechas con
  /// cierre de origen automático antes de que el operador empiece a cargar.
  Future<Either<Failure, CierreCenso?>> obtenerCierre(DateTime fecha);
  Future<Either<Failure, int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  });
  Future<Either<Failure, CensoServicio>> guardarCargaManual(CensoServicio censo);
  Future<Either<Failure, ProgresoDia>> obtenerProgresoDia(DateTime fecha);
  Future<Either<Failure, ConfirmacionDia>> confirmarDia(DateTime fecha);
}
```

### 4.2 Casos de uso

| Caso de uso | Responsabilidad |
|---|---|
| `CargarReferenciasCenso` | Servicios activos + mapeos + marcar servicios sin mapeo. Cacheable por sesión. |
| `ObtenerContextoServicio` | Capacidad de camas + total del día anterior para (fecha, servicioId). |
| `ValidarCensoServicio` | Puro. Devuelve `List<ValidacionCenso>` (bloqueantes y advertencias). |
| `GuardarCensoServicio` | Valida y hace `POST /carga-manual`. |
| `ObtenerProgresoDia` | `GET /estado`. |
| `ConfirmarDiaCenso` | Refresca progreso, verifica `puedeConfirmar`, `POST /confirmar`. |
| `InterpretarDictadoCenso` | Puro. `String transcripción → PropuestaVoz`. Sin I/O, 100% testeable. |

---

## 5. Máquina de estados del formulario

```dart
// presentation/state/censo_form_state.dart
@freezed
class CensoFormState with _$CensoFormState {
  const factory CensoFormState({
    required FaseFormulario fase,
    required DateTime? fecha,
    required Servicio? servicio,
    required Map<CampoCenso, CampoValor> campos,   // valor + OrigenDato
    required List<CamaPrestada> camasPrestadas,
    int? capacidadServicio,      // GET /camas
    int? totalDiaAnterior,       // GET /historico (fecha-1)
    @Default([]) List<ValidacionCenso> validaciones,
    PropuestaVoz? propuestaPendiente,   // no-null ⇒ hay diff esperando confirmación
    Failure? error,
  }) = _CensoFormState;

  bool get tieneVozPendiente => propuestaPendiente != null;
  bool get puedeGuardar =>
      fase == FaseFormulario.edicion &&
      !tieneVozPendiente &&                        // ← candado duro
      validaciones.none((v) => v.esBloqueante);
}

enum FaseFormulario {
  inicial,
  cargandoReferencias,
  edicion,
  escuchandoVoz,
  procesandoVoz,
  confirmandoVoz,   // pre-carga visible, esperando decisión del usuario
  guardando,
  guardado,
  error,
}
```

Transiciones legales:

```
inicial → cargandoReferencias → edicion
edicion ⇄ escuchandoVoz → procesandoVoz → confirmandoVoz
confirmandoVoz → edicion          (aceptar total, parcial o descartar)
edicion → guardando → guardado | error
error → edicion                   (reintento conserva los valores tipeados)
```

**Invariante crítico (I-01):** desde `escuchandoVoz`, `procesandoVoz` y `confirmandoVoz` **no
existe ninguna arista hacia `guardando`**. Es imposible, por construcción de la máquina, que un
valor originado en voz llegue a la API sin pasar por `edicion`, y a `edicion` solo se entra desde
`confirmandoVoz` por una acción explícita del usuario. Esto se verifica con un test unitario que
enumera todas las transiciones.

---

## 6. Flujo de voz: captura → parsing → confirmación → persistencia

### 6.1 Diagrama del flujo

```
┌──────────────┐  tap FAB   ┌───────────────┐  onResult final ┌────────────────┐
│   edicion    │───────────▶│ escuchandoVoz │────────────────▶│ procesandoVoz  │
│  (teclado)   │            │ parciales en  │                 │ InterpretarDic-│
└──────────────┘            │ vivo + ampli- │                 │ tadoCenso      │
       ▲                    │ tud del mic   │                 └───────┬────────┘
       │                    └───────────────┘                         │
       │                                                              ▼
       │                                                  ┌────────────────────┐
       │       aceptar / editar / descartar (explícito)   │  confirmandoVoz    │
       └──────────────────────────────────────────────────│ HojaConfirmacion-  │
                                                          │ Voz (diff)         │
                                                          └────────────────────┘
                                                     GATE 1 ── confirmación de voz
                          ┌──────────────┐
   GATE 2 ── botón        │  guardando   │  POST /censo-diario/carga-manual
   "Guardar servicio" ───▶│              │
                          └──────────────┘
```

**Dos compuertas, no una.** El criterio de calidad crítico exige confirmación antes de persistir.
Esta spec va un paso más allá: confirmar la propuesta de voz **solo la aplica al formulario en
memoria**; la persistencia exige además la acción deliberada de "Guardar servicio". Ningún camino
del código escribe en el API como efecto directo de un `onResult` del STT.

### 6.2 Gramática de dictado

Alcance cerrado: **solo cifras del resumen**. Un enunciado = un par `campo + número`; se admiten
varios pares encadenados en una misma dictación.

| Campo | Alias reconocidos (normalizados sin tildes, minúsculas) |
|---|---|
| `ingreso` | `ingreso`, `ingresos`, `ingreso directo`, `ingresos por admision`, `admisiones` |
| `ingresoTraslado` | `ingreso por traslado`, `ingresos por traslado`, `traslado de entrada`, `entra por traslado` |
| `egreso` | `egreso`, `egresos`, `egreso directo`, `altas`, `salidas` |
| `egresoTraslado` | `egreso por traslado`, `egresos por traslado`, `traslado de salida`, `sale por traslado` |
| `obito` | `obito`, `obitos`, `fallecido`, `fallecidos`, `muerte`, `muertes`, `defunciones` |
| `aislamiento` | `aislamiento`, `camas en aislamiento`, `aisladas` |
| `bloqueada` | `bloqueada`, `bloqueadas`, `camas bloqueadas` |
| `libre` | `libre`, `libres`, `camas libres`, `disponibles` |
| `total` | `total`, `saldo`, `saldo de pacientes`, `saldo a las veinticuatro horas`, `pacientes al cierre` |

**Ejemplos válidos:**

- `"ingresos cuatro, egresos tres, óbitos cero"`
- `"camas libres dos, bloqueadas una, aislamiento uno"`
- `"saldo treinta y cuatro"`
- `"ingreso por traslado uno y egreso por traslado cero"`

**Comandos de control (no son datos):** `"borrar"`, `"cancelar"`, `"repetir"`, `"listo"`.
Se interceptan antes del parseo de campos y no generan propuesta.

**Parser de números en español (`NumeroEsParser`, Dart puro, `core/`):**

- Rango soportado: `0`–`999` (cubre con margen cualquier valor del EST-1).
- Debe aceptar **ambas** formas: palabra (`"treinta y cuatro"`) y dígito (`"34"`) — el motor STT
  devuelve una u otra según el motor del dispositivo y la locale, no es determinista.
- Casos irregulares obligatorios en el set de tests: `un`/`uno`/`una`, `veintiuno`, `veintidós`,
  `dieciséis`, `treinta y cuatro`, `cien`, `ciento uno`, `cero`.
- Ambigüedad conocida: `"un"` puede ser artículo (`"un ingreso"`) o cardinal (`"ingreso un"`).
  Regla: el número se toma **siempre después** de la etiqueta del campo. `"un ingreso"` no produce
  propuesta; produce una advertencia de dictado no reconocido.

### 6.3 Modelo de la propuesta

```dart
@freezed
class PropuestaVoz with _$PropuestaVoz {
  const factory PropuestaVoz({
    required String transcripcion,        // literal, se muestra siempre
    required DateTime capturadaEn,
    required List<CampoPropuesto> campos,
    required List<String> fragmentosNoReconocidos,
  }) = _PropuestaVoz;

  bool get estaVacia => campos.isEmpty;
}

@freezed
class CampoPropuesto with _$CampoPropuesto {
  const factory CampoPropuesto({
    required CampoCenso campo,
    required int? valorAnterior,
    required int valorPropuesto,
    required double confianza,     // 0.0–1.0, del motor STT
    required String textoOrigen,   // fragmento exacto que lo originó
    @Default(true) bool aceptado,  // el usuario puede desmarcar campo por campo
  }) = _CampoPropuesto;

  bool get esSobrescritura => valorAnterior != null && valorAnterior != 0;
  bool get confianzaBaja => confianza < 0.70;
}
```

### 6.4 Reglas de la pantalla de confirmación

1. La transcripción literal se muestra **siempre**, arriba del diff — el operador debe poder ver
   qué entendió el motor, no solo el resultado.
2. Cada campo se presenta como fila `Campo · valor anterior → valor propuesto`, con checkbox
   individual. Por defecto todos aceptados **salvo** los de `confianzaBaja`, que llegan
   desmarcados y con indicador visual + texto (nunca solo color).
3. Toda **sobrescritura** de un valor previamente tipeado a mano se marca de forma destacada:
   es el caso de mayor riesgo de pérdida de dato.
4. Los `fragmentosNoReconocidos` se listan explícitamente. Un dictado parcialmente entendido
   nunca se presenta como éxito total.
5. Acciones: **Aplicar seleccionados** · **Editar antes de aplicar** (abre el campo en teclado) ·
   **Descartar todo** · **Volver a dictar**.
6. La hoja **no se puede cerrar por gesto ni por back** sin elegir una de las acciones: cerrarla
   accidentalmente no debe aplicar nada silenciosamente.
7. Todo campo aplicado por voz queda marcado con `OrigenDato.voz` y muestra un ícono discreto en
   el formulario hasta que se guarde, para revisión visual final.

### 6.5 Permisos y disponibilidad

- Permiso de micrófono con `permission_handler`; solicitud **en el primer tap del FAB**, nunca al
  abrir la pantalla.
- Estados a manejar: concedido, denegado, denegado permanentemente (→ CTA a Ajustes del sistema),
  no disponible en el dispositivo.
- **Selección de locale:** intentar `es_BO` → `es_419` → `es_MX` → `es_ES` → primer `es_*`
  disponible, leyendo `SpeechToText.locales()`. Si no hay ninguna locale `es_*`, **deshabilitar el
  botón de voz** con mensaje explicativo. Jamás caer a `en_US` en silencio.
- Timeout de escucha: 8 s sin habla → cierre automático con lo capturado.
- El botón de voz es **siempre opcional**: el formulario es 100% operable solo con teclado. La voz
  nunca es la única vía para completar un campo.

---

## 7. Validaciones en el cliente

El backend es la única fuente de verdad. Estas validaciones dan feedback inmediato.

| ID | Regla | Severidad | Mensaje |
|---|---|---|---|
| V-01 | Todos los contadores enteros `>= 0` | Bloqueante | "El valor no puede ser negativo" |
| V-02 | `cantidad` de cama prestada `>= 1` | Bloqueante | "La cantidad debe ser al menos 1" |
| V-03 | Fecha `<` hoy (hora local de Bolivia) | Bloqueante | "Solo se pueden cargar fechas anteriores a hoy" |
| V-04 | Sin duplicados de `(especialidadId, tipoIngreso)` | Bloqueante | "Esa especialidad ya está registrada con ese tipo de ingreso" |
| V-05 | `total + libre + bloqueada + aislamiento == capacidad` | Bloqueante | "El censo no cuadra: la suma da N y la capacidad del servicio es M" |
| V-06 | Servicio con mapeo a vaciado presente | Advertencia | "Este servicio aún no tiene mapeo. Se puede guardar, pero el día no podrá confirmarse hasta que el equipo de datos lo complete." |
| V-07 | `total == totalDiaAnterior + ingresos − egresos − óbitos` | Advertencia | "El saldo esperado según el día anterior es N. Verificá los movimientos." |
| V-08 | Existe fila del día anterior | Informativa | "No hay cierre del día anterior para este servicio. No se puede contrastar el saldo." |
| V-09 | La fecha no tiene un `CierreCenso` con `origen: "automatico"` | Bloqueante, **en selección de fecha** | "Esta fecha ya fue cerrada por el cálculo automático del sistema. No puede cargarse manualmente." |
| V-10 | `Σ camasPrestadas(DIRECTO) <= ingreso` | Informativa | "Registraste N camas prestadas por ingreso directo, pero solo hay M ingresos por admisión." |

Notas:

- **V-05 es bloqueante en el cliente** porque conocemos la capacidad vía `GET /camas`. Si esa
  llamada falla, degrada a advertencia y se deja que el backend rechace — nunca se bloquea al
  operador por una falla de red en una consulta auxiliar.
- **V-07 nunca bloquea.** Durante el backfill es esperable que falten días previos, o que el papel
  tenga inconsistencias. Se muestra la aritmética completa para que el operador decida.
- **V-09 se evalúa en `SeleccionFechaPage`**, no al confirmar. Descubrir que la fecha era
  inconfirmable después de digitar todos los servicios es el peor escenario de UX del módulo.
- **V-10 nunca bloquea, y deliberadamente no tiene equivalente para `TRASLADO`.** Una cama
  prestada `DIRECTO` es siempre un ingreso por admisión al servicio, así que la desigualdad
  aplica. Pero `TRASLADO` incluye también movimientos **internos** dentro del mismo servicio
  (paciente que pasa de su cama a una prestada), que no son ingresos por traslado del servicio —
  la desigualdad no se sostiene y una validación ahí daría falsos positivos.
- `dotacion = total + libre` se muestra como campo **calculado y de solo lectura**, con nota de
  que el servidor lo recalcula.

---

## 8. Estrategia de componentes Flutter (UI/UX Pro Max)

### 8.1 Principio rector

El operador transcribe papel a pantalla, de noche, en una docena de servicios seguidos. La métrica de diseño
es **campos correctos por minuto**, no cantidad de pantallas bonitas. Todo lo que obligue a
alternar entre teclado numérico y otro modo de entrada cuesta tiempo real.

### 8.2 Arquitectura de pantallas

| Pantalla | Ruta | Rol |
|---|---|---|
| `SeleccionFechaPage` | `/censo` | Calendario con hoy y futuro deshabilitados; badge de progreso por fecha reciente |
| `ProgresoDiaPage` | `/censo/:fecha` | Checklist de **todos los servicios activos** que devuelva `GET /estado` + botón "Confirmar día" |
| `CensoServicioFormPage` | `/censo/:fecha/servicio/:id` | Formulario EST-1 de un servicio |
| `ConfirmacionDiaPage` | `/censo/:fecha/confirmar` | Resumen previo a la escritura definitiva |

### 8.3 Catálogo de componentes reutilizables

| Componente | Ubicación | Responsabilidad y criterios |
|---|---|---|
| `CampoNumericoCenso` | `features/censo_diario/presentation/widgets/` | Campo entero con `−`/`+` de 48×48 dp mínimo, `TextInputType.number`, selección total al enfocar, avance con `TextInputAction.next`. Muestra badge de `OrigenDato.voz`. |
| `GrupoMovimientos` | ídem | Agrupa los 5 contadores de `TipoMovimientoCenso` con subtotales vivos de ingresos y egresos. |
| `GrupoCamas` | ídem | `aislamiento`, `bloqueada`, `libre` + capacidad de referencia. |
| `IndicadorCuadre` | ídem | Barra persistente: `suma / capacidad`. Estados cuadra / no cuadra / desconocido, cada uno con **ícono + texto**, nunca solo color. Háptico ligero al pasar a "cuadra". |
| `PanelSaldoEsperado` | ídem | Aritmética visible: `anterior + ingresos − egresos = esperado` contra el `total` tipeado. |
| `BotonDictado` | `core/widgets/voice/` | FAB extendido. Estados: inactivo, escuchando (onda de amplitud real de `soundLevel`), procesando. Mantiene el teclado accesible. |
| `HojaConfirmacionVoz` | `core/widgets/voice/` | `DraggableScrollableSheet` no descartable. Transcripción + diff por campo + no reconocidos + 4 acciones (§6.4). |
| `TarjetaServicioProgreso` | `features/censo_diario/presentation/widgets/` | Fila del checklist: nombre, estado (cargado/pendiente/no cuadra/sin mapeo), tap para editar. |
| `GuiaTranscripcionEst1` | `features/censo_diario/presentation/widgets/` | Hoja de ayuda desplegable: correspondencia fila del papel → campo de la app, con la advertencia de la etiqueta desactualizada (§2.1). Accesible desde el `AppBar` del formulario. Se abre automáticamente la primera vez que el usuario entra, y nunca más salvo que la pida. |
| `BannerFallaApi` | `core/widgets/` | Traduce `Failure` a mensaje accionable; renderiza `message` como string o como `List<String>` (el backend devuelve ambos). |
| `TecladoNumericoAccesorio` | `core/widgets/` | Barra sobre el teclado: "Anterior / Siguiente / Listo" — evita cerrar y reabrir el teclado 9 veces por servicio. |

### 8.4 Criterios de UX no negociables

1. **Un solo teclado, un solo recorrido.** Los 9 campos se completan con `next` sin cerrar el
   teclado ni una vez. El `IndicadorCuadre` vive fijo sobre el teclado, siempre visible.
2. **Cero pérdida de dato.** El estado del formulario sobrevive a rotación y a background
   (`AutoDisposeNotifier` con `keepAlive` mientras la ruta esté activa). Salir con cambios sin
   guardar exige confirmación.
3. **La voz es aditiva, nunca obligatoria.** Sin permiso de micrófono la pantalla funciona
   completa; el FAB se oculta, no se muestra roto.
4. **Accesibilidad.** Contraste AA mínimo; `Semantics` con etiqueta y valor en cada campo;
   objetivos táctiles ≥ 48 dp; soporte de escala de texto hasta 1.3× sin desbordes; ningún estado
   se comunica solo por color.
5. **Errores accionables.** Cada `Failure` se traduce a qué pasó, por qué y qué hacer. El `400` de
   cuadre debe mostrar los números concretos, no el texto crudo del backend.
6. **Confirmar día es irreversible en la percepción del usuario.** Diálogo con el resumen de los
   servicios del día y escritura explícita de la consecuencia, aunque técnicamente sea idempotente.
7. **El catálogo manda, no el código.** Ninguna pantalla, test o constante fija la cantidad de
   servicios: se renderiza lo que devuelva el endpoint. Un servicio nuevo abierto en el hospital
   aparece en la app sin release (P-03).

---

## 9. Estructura de carpetas del feature

```
lib/features/censo_diario/
├── domain/
│   ├── entities/        censo_servicio.dart, servicio.dart, cama_prestada.dart,
│   │                    progreso_dia.dart, mapeo_vaciado.dart,
│   │                    tipo_movimiento_censo.dart
│   ├── value_objects/   fecha_censo.dart, campo_censo.dart
│   ├── repositories/    censo_diario_repository.dart
│   └── usecases/        cargar_referencias_censo.dart, obtener_contexto_servicio.dart,
│                        validar_censo_servicio.dart, guardar_censo_servicio.dart,
│                        obtener_progreso_dia.dart, confirmar_dia_censo.dart,
│                        interpretar_dictado_censo.dart
├── data/
│   ├── datasources/     censo_diario_remote_datasource.dart
│   ├── models/          *_dto.dart (+ .freezed.dart / .g.dart)
│   └── repositories/    censo_diario_repository_impl.dart
└── presentation/
    ├── providers/       censo_form_provider.dart, progreso_dia_provider.dart,
    │                    referencias_provider.dart, dictado_provider.dart
    ├── state/           censo_form_state.dart, propuesta_voz.dart
    ├── pages/           seleccion_fecha_page.dart, progreso_dia_page.dart,
    │                    censo_servicio_form_page.dart, confirmacion_dia_page.dart
    └── widgets/         (catálogo §8.3)
```

---

## 10. Criterios de aceptación

| # | Criterio | Verificación |
|---|---|---|
| CA-01 | El operador completa los 9 campos de un servicio con teclado y guarda; el backend responde `201`. | Manual + integración |
| CA-02 | Dictar `"ingresos cuatro, egresos tres, óbitos cero"` produce una propuesta con 3 campos y **no modifica el formulario** hasta aceptar. | Widget test |
| CA-03 | Descartar la propuesta de voz deja el formulario **byte a byte** como estaba antes de dictar. | Widget test |
| CA-04 | **No existe transición de estado que lleve de `escuchandoVoz`/`procesandoVoz`/`confirmandoVoz` a `guardando`.** | Unit test exhaustivo de la máquina de estados |
| CA-05 | Con `total+libre+bloqueada+aislamiento ≠ capacidad`, el botón "Guardar servicio" está deshabilitado y el `IndicadorCuadre` explica el desvío con números. | Widget test |
| CA-06 | El selector de fecha rechaza hoy y futuro en hora local de Bolivia. | Unit test con `ahora` inyectado, incluyendo 21:00 hora Bolivia |
| CA-07 | `fecha` viaja como `'YYYY-MM-DD'` plano, sin offset, con el dispositivo en `America/La_Paz`. | Unit test del DTO |
| CA-08 | "Confirmar día" solo se habilita cuando **todos** los servicios devueltos por `GET /estado` están `cargado && cuadra`, y refresca ese endpoint antes de habilitarse. | Widget + integración |
| CA-15 | Agregar un servicio nuevo en el sistema web lo hace aparecer en la app sin recompilar ni actualizar constantes. Ningún test ni código fija la cantidad de servicios. | Integración + revisión de código |
| CA-16 | Una cuenta con rol `lectura` abre la app en modo consulta: nunca recibe un `403` por intentar guardar. | Widget test |
| CA-17 | El campo de egresos directos se rotula "Egresos por salida" y muestra como texto auxiliar la fila impresa "Ingresos y egresos del mismo día". | Widget test |
| CA-09 | Sin permiso de micrófono, la pantalla es 100% funcional por teclado y el FAB no aparece roto. | Manual (dispositivo físico) |
| CA-10 | Un `400` con `message` como **array** de errores de validación se renderiza legible. | Widget test |
| CA-11 | `NumeroEsParser` resuelve `0`, `un/uno/una`, `dieciséis`, `veintiuno`, `treinta y cuatro`, `cien`, `ciento uno` y sus formas en dígitos. | Unit test |
| CA-12 | Reenviar el mismo `(fecha, servicioId)` actualiza y no duplica; las camas prestadas se reemplazan. | Integración contra backend real |
| CA-13 | Una fecha con `CierreCenso.origen == 'automatico'` aparece bloqueada **en el calendario**, con explicación, antes de poder abrir ningún servicio. | Widget + integración |
| CA-14 | Dos camas prestadas con la misma `(especialidadId, tipoIngreso)` se bloquean en el cliente, sin llegar al `400` del backend. | Unit test de `ValidarCensoServicio` |

## 11. Plan de pruebas

- **Unitarias (`domain/`, sin Flutter):** `NumeroEsParser`, `InterpretarDictadoCenso`,
  `ValidarCensoServicio`, `FechaCenso`, reglas de `CensoServicio`, máquina de estados.
- **Widget:** `HojaConfirmacionVoz` (aceptar total / parcial / descartar), `CampoNumericoCenso`,
  `IndicadorCuadre`, formulario completo con repositorio falso.
- **Integración:** contra la API real de desarrollo, siguiendo la secuencia de verificación de la
  Task 7 del plan de backend (estado → guardar → estado → confirmar prematuro `400` → cargar todo
  → confirmar `201` → reconfirmar idempotente).
- **Dispositivo físico obligatorio** para STT: el simulador de iOS no expone micrófono real.
  Mínimo un Android y un iPhone vía TestFlight.

## 12. Riesgos y preguntas abiertas

| ID | Riesgo / pregunta | Impacto | Mitigación / responsable |
|---|---|---|---|
| R-01 | Si Admisión quiere operación diaria en vivo, este módulo no aplica. | Alto | Cerrado como fuera de alcance. Requiere ADR nuevo y cambio de backend. |
| R-02 | El backend evalúa la regla de fecha en **UTC**; Bolivia es UTC-4. Entre 20:00 y 24:00 local aceptaría el día en curso. | Medio | El cliente valida en hora local (más estricto). Proponer al backend usar `America/La_Paz`. |
| R-03 | `cuadra` se recalcula contra la capacidad **actual**; un día ya cargado puede dejar de cuadrar si cambia el catálogo de camas. | Medio | Refrescar `GET /estado` antes de habilitar "Confirmar" y mostrar la fecha del último refresco. |
| R-04 | Servicios activos sin fila de mapeo bloquean la confirmación del día completo. | Alto | V-06 lo detecta al cargar referencias y lo muestra en `ProgresoDiaPage` desde el inicio, no al confirmar. |
| R-05 | Precisión del STT con números en `es-BO` no está medida. | Medio | Spike de 1 día en Sprint 1 sobre dispositivo físico. Si la precisión es baja, la voz pasa a "nice to have" y el teclado sostiene el MVP. |
| ~~R-07~~ | ~~Doble conteo de ingresos/egresos por traslado.~~ | **Descartado** | Falsa alarma: la anotación "Cir = 1" refiere a **camas prestadas**, no a un ingreso por traslado. No infla el censo. Ver §2.5. |
| R-08 | Las camas prestadas se cuentan a mano desde hace años, fuera del EST-1 impreso. Es la única entrada del formulario sin respaldo documental estructurado. | Medio | Sección opcional y colapsada; conteo declarado por el operador. Su ausencia nunca bloquea el guardado. V-10 avisa si excede los ingresos. |
| R-09 | El EST-1 impreso acumula reglas desactualizadas (etiquetas heredadas, filas sin uso, datos que se anotan al margen). Pueden existir otras divergencias todavía no detectadas. | Medio | `GuiaTranscripcionEst1` centraliza la correspondencia papel→app; cada divergencia nueva se documenta ahí y en §2.1, no en el código. Revisión con Admisión al cerrar el Sprint 1. |

### 12.1 Preguntas cerradas (2026-07-31, con Admisión)

| ID | Pregunta | Respuesta | Consecuencia en el diseño |
|---|---|---|---|
| P-01 | ¿Qué es la fila "Ingresos y egresos del mismo día"? | Etiqueta **desactualizada**: ahí se registran los **egresos directos**. | Mapea a `egreso`. La app rotula "Egresos por salida" y muestra la etiqueta impresa como texto auxiliar (§2.1, `GuiaTranscripcionEst1`). |
| P-02 | ¿De dónde salen las camas prestadas si no están en el formulario? | El formulario está desactualizado, pero el **conteo manual se hace desde hace años**, anotado al margen. | Sección opcional y colapsada. Ver R-08. |
| P-05 | ¿Qué significa la anotación "Cir = 1" de la muestra? | **Camas prestadas.** De los 4 ingresos del día, 1 ocupó una cama prestada; el tipo de ingreso se determina por evaluación visual (ahí, `DIRECTO`). **No participa en ninguna fórmula, solo se registra.** | Descarta R-07. Fija la semántica de §2.5 y la validación informativa V-10. |
| P-06 | ¿De dónde salen los ingresos/egresos por traslado, si el RESUMEN no tiene fila para ellos? | **Solo del conteo de los bloques `POR TRASLADO DEL SERVICIO`.** | El formulario de la app ordena los campos siguiendo el orden de conteo de bloques, no el orden del RESUMEN. |
| P-03 | ¿Los servicios del papel corresponden 1:1 con los del sistema? | **Sí.** Todo servicio que se abre físicamente se crea en el sistema web y aparece en `GET /servicios`. Los campos de carga no cambian. | **Prohibido codificar el número 13.** La app renderiza los servicios que devuelva el endpoint. Un servicio nuevo aparece solo, sin release. El único requisito adicional es su fila de mapeo (V-06). |
| P-04 | ¿Qué rol usa la app? | **`admin` y `operador`**, ambos. | Sin gating de rol propio en la UI: ambos cubren los 10 endpoints. Se agrega manejo del rol `lectura` (ver §12.2). |

### 12.2 Manejo del rol `lectura`

Aunque Admisión operará con `admin` y `operador`, el sistema tiene un tercer rol `lectura` que
**no puede escribir carga manual**. Si una cuenta `lectura` inicia sesión, la app entra en **modo
consulta**: `SeleccionFechaPage` y `ProgresoDiaPage` funcionan normal, los formularios abren en
solo lectura y los botones "Guardar servicio" y "Confirmar día" se muestran deshabilitados con la
razón explícita. Nunca se deja que el operador complete los 9 campos para recibir un `403` al
guardar.
