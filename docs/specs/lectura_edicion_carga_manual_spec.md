# SPEC-003 — Lectura y edición de la carga manual guardada

| Campo | Valor |
|---|---|
| **ID** | SPEC-003 |
| **Título** | Precarga del formulario EST-1 desde el staging del servidor |
| **Estado** | Borrador — listo para implementar |
| **Autor** | Willtech — Arquitectura de Software |
| **Fecha** | 2026-08-03 |
| **Depende de** | SPEC-002, ADR-0005 |
| **Habilitado por** | `software-migracion/docs/superpowers/plans/2026-08-02-leer-carga-manual.md` |
| **Origen** | `docs/solicitudes/backend-leer-carga-manual.md` |

---

## 1. Contexto

El backend implementó el endpoint que pedimos. Hasta ahora la app **no podía leer
lo guardado**: el formulario se abría en cero aunque el servicio ya tuviera
datos, y como `POST /carga-manual` es un upsert, guardar reemplazaba una carga
previa que nadie había visto.

Eso produjo el bug que reportó el cliente el 2026-08-02: cargó el servicio 1,
avanzó al 2 y al 3, y al volver al 1 encontró los campos en cero mientras la
lista lo mostraba como cargado. Se mitigó con `ref.keepAlive()` sobre el
formulario, pero era una curita: solo cubría la sesión en curso y dependía de la
memoria del proceso.

Con este endpoint el problema se resuelve en su origen.

### Lo que este trabajo cierra

- El formulario se abre con los valores reales, no en cero.
- Editar deja de ser retipear a ciegas.
- Desaparece la posibilidad de pisar una carga previa sin enterarse.
- Se puede mostrar quién cargó y cuándo, antes de que alguien reemplace el
  trabajo de otro.

---

## 2. Contrato consumido

```
GET /api/v1/censo-diario/carga-manual?fecha=YYYY-MM-DD[&servicioId=<uuid>]
Roles: cualquier usuario autenticado (sin @Roles, igual que /estado)
```

Verificado contra `carga-manual.controller.ts`, `carga-manual.service.ts` y
`dominio/presentador.ts` del commit implementado.

**Respuesta — array en camelCase.** Un servicio sin fila de staging simplemente
no aparece; fecha sin cargas devuelve `[]`.

```json
[
  {
    "servicioId": "3fa1-uuid",
    "servicioNombre": "Medicina Interna",
    "fecha": "2026-07-16",
    "ingreso": 4, "ingresoTraslado": 0,
    "egreso": 3, "egresoTraslado": 0,
    "obito": 0,
    "aislamiento": 1, "bloqueada": 1, "libre": 2,
    "total": 34, "dotacion": 36,
    "camasPrestadas": [
      {
        "especialidadId": "esp-uuid",
        "especialidadNombre": "Cirugía",
        "cantidad": 1,
        "tipoIngreso": "DIRECTO"
      }
    ],
    "actualizadoEn": "2026-08-01T22:14:03.000Z",
    "creadoPorNombre": "Ana Rojas"
  }
]
```

### 2.1 Cambio de orden que no pedimos y nos conviene

El backend cambió el criterio de ordenamiento de servicios de `nombre` a un
campo nuevo **`indice`**, configurable vía `PATCH /servicios/orden`. Afecta a los
tres endpoints por igual: `GET /servicios`, `GET /carga-manual/estado` y este
nuevo.

Es la respuesta al problema que planteamos al analizar la navegación entre
servicios: el orden alfabético no tenía por qué coincidir con el de la pila de
formularios de papel, y si no coincidía, las flechas obligaban al operador a
buscar la hoja correcta en cada salto.

**Consecuencia para la app: ninguna, y esa es exactamente la intención.** La
lista de navegación ya se construye desde `progreso.servicios` —el orden que
manda `/estado`—, así que hereda `indice` sin tocar nada.

**Regla que queda fijada: la app nunca reordena servicios.** El orden es una
decisión de Admisión, expresada en `indice`. Cualquier `sort` que se agregue del
lado del cliente rompería silenciosamente la correspondencia con el papel.

---

## 3. Decisiones de diseño

### D-1 — Se pide la fecha completa una vez, no servicio por servicio

`servicioId` queda sin usar en el flujo normal. La app pide **todos** los
servicios de la fecha en una sola llamada y cachea el resultado.

*Por qué:* el formulario navega entre servicios con flechas, sin apilar rutas.
Pedir por servicio costaría trece peticiones para recorrer un día, de noche y
sobre la red de un hospital. Fue la razón por la que pedimos el parámetro
opcional en la solicitud original.

### D-2 — La precarga ocurre durante `cargandoReferencias`, no después

El formulario ya tiene una fase de carga donde `cambiarCampo` ignora la entrada.
La precarga entra en esa misma ventana, junto con capacidad y total del día
anterior, y el paso a `edicion` ocurre recién cuando todo llegó.

*Por qué:* si la precarga llegara con el formulario ya editable, habría una
carrera entre lo que el operador tipea y lo que responde el servidor. Poniéndola
antes de la transición, esa carrera no puede existir — no hay que resolverla,
simplemente no ocurre.

### D-3 — Se retira `ref.keepAlive()` del formulario

La corrección de ayer deja de tener sentido: el estado se recupera del servidor,
que es más confiable que la memoria del proceso.

*Por qué retirarlo y no dejarlo por las dudas:* mantener ambos crea dos fuentes
de verdad. Un formulario retenido en memoria podría mostrar valores más viejos
que los del servidor —por ejemplo si otro operador editó la misma fecha desde
otro dispositivo— y ganaría por estar primero. Ese es justamente el tipo de
inconsistencia silenciosa que el endpoint vino a eliminar.

*Red de seguridad:* si el `GET` falla, la precarga se omite y el formulario abre
en cero con un aviso explícito de que no se pudo leer lo guardado. Es peor que
antes en ese caso puntual, pero es **honesto**: mejor decir "no pude leer" que
mostrar memoria vieja como si fuera el estado real.

### D-4 — Guardar invalida la caché de la fecha

Tras un `POST` exitoso se invalida `cargasDelDiaProvider(fecha)`.

*Por qué:* sin eso, volver a un servicio recién guardado lo repoblaría con los
valores anteriores a la edición. Cuesta una petición por guardado y elimina toda
una clase de bugs de caché rancia.

### D-5 — El aviso de sobrescritura se reemplaza por procedencia

`_AvisoCargaPrevia` desaparece: ya no hace falta advertir sobre valores que no
se pueden ver, porque ahora se ven.

En su lugar, cuando el servicio ya tenía carga se muestra **quién y cuándo**:

> Cargado por Ana Rojas · ayer 18:14

**`actualizadoEn` llega en UTC y hay que convertirlo a hora local.** El ejemplo
de §2 (`2026-08-01T22:14:03.000Z`) son las **18:14** en Bolivia, no las 22:14.
Mostrar la hora del servidor como si fuera la del hospital haría dudar al
operador de un dato que está bien. Aplica igual al "Guardado HH:mm" de D-6.

*Por qué importa:* varias personas pueden tocar la misma fecha. Saber que lo que
estás por reemplazar lo cargó otra persona hace una hora es información que
cambia la decisión, y ya viene en la respuesta.

### D-6 — El guardado automático se hace visible

Cuestión abierta desde el bug del 2026-08-02: las flechas guardan solas cuando
el censo cuadra, y el cliente no lo percibe. Con la precarga el síntoma se
atenúa —al volver ve sus datos— pero la sorpresa de fondo sigue: la app persiste
sin que él lo registre.

La barra de navegación pasa a mostrar el estado del servicio actual: **"Sin
guardar" / "Guardado 22:14"**. No agrega gestos y elimina la ambigüedad.

---

## 4. Cambios por capa

### 4.1 `data/`

**`CargaManualGuardadaDto` no sirve para esto.** Parsea la respuesta del `POST`,
que es la fila cruda de Prisma en `snake_case` y sin relaciones. El `GET` nuevo
devuelve camelCase con `servicioNombre`, `especialidadNombre`, `actualizadoEn` y
`creadoPorNombre`. Son dos formas distintas del mismo dato y merecen dos DTOs
distintos: fusionarlos obligaría a un parser tolerante a ambas convenciones, que
es como se llega a un campo en `null` que nadie nota.

```dart
// data/models/carga_manual_dtos.dart
class CargaGuardadaDto {
  factory CargaGuardadaDto.fromJson(Map<String, dynamic> json);

  final String servicioId;
  final String servicioNombre;
  final String fecha;                       // 'YYYY-MM-DD'
  final int ingreso, ingresoTraslado, egreso, egresoTraslado, obito;
  final int aislamiento, bloqueada, libre, total, dotacion;
  final List<CamaPrestadaGuardadaDto> camasPrestadas;
  final DateTime? actualizadoEn;
  final String? creadoPorNombre;

  CensoServicio toDomain();
}
```

`actualizadoEn` y `creadoPorNombre` van **opcionales** a propósito: son
metadatos de presentación, y un cambio futuro en el backend que deje de
enviarlos no debe impedir editar el censo.

**Datasource:**

```dart
Future<List<CargaGuardadaDto>> obtenerCargas(
  DateTime fecha, {
  String? servicioId,
});
```

**Repositorio:** `Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(...)`.

### 4.2 `domain/`

Entidad nueva `CargaGuardada`: el `CensoServicio` más su procedencia.

```dart
class CargaGuardada {
  final CensoServicio censo;
  final String servicioNombre;
  final DateTime? actualizadoEn;
  final String? creadoPorNombre;
}
```

*Por qué no meter los metadatos dentro de `CensoServicio`:* esa entidad
representa **lo que se envía al servidor**. Sumarle campos que nunca viajan la
convertiría en un contenedor mixto y volvería ambigua la comparación
`mismosValoresQue`, que hoy decide si hay cambios sin guardar.

Se agrega al contrato del repositorio y nada más: no hay regla de negocio nueva,
así que no corresponde caso de uso.

### 4.3 `presentation/`

| Elemento | Cambio |
|---|---|
| `cargasDelDiaProvider(fecha)` | Nuevo. `FutureProvider.family<Map<String, CargaGuardada>, DateTime>`, indexado por `servicioId` |
| `CensoFormLogica.cargarReferencias` | Recibe `CargaGuardada?` y precarga antes de pasar a `edicion` |
| `CensoFormState` | Nuevos `cargaPrevia` y `falloLecturaPrevia` (sin tilde: Dart no admite acentos en identificadores) |
| `CensoFormNotifier` | Lee la caché en el microtask; **se retira `keepAlive`** |
| `BarraNavegacionServicios` | Muestra "Sin guardar" / "Guardado HH:mm" |
| `_AvisoCargaPrevia` | Se elimina; lo reemplaza la línea de procedencia |
| Tras guardar | `ref.invalidate(cargasDelDiaProvider(fecha))` |

---

## 5. Criterios de aceptación

| # | Criterio | Verificación |
|---|---|---|
| CA-01 | Abrir un servicio ya cargado muestra sus nueve valores, no ceros. | Integración |
| CA-02 | Se muestran las camas prestadas guardadas, con el nombre de especialidad. | Integración |
| CA-03 | **El bug del cliente no se reproduce**: cargar el servicio 1, avanzar al 2 y al 3, volver al 1 → los valores están. | Manual, escenario exacto del reporte |
| CA-04 | Un servicio sin carga previa abre en cero, sin error. | Unit |
| CA-05 | Se pide la fecha completa **una sola vez** al entrar; recorrer los 13 servicios no genera peticiones nuevas. | Inspección de red |
| CA-06 | Tras guardar y volver al mismo servicio, se ven los valores **nuevos**, no los previos a la edición. | Integración |
| CA-07 | Si el `GET` falla, el formulario abre en cero con aviso explícito y se puede seguir trabajando. | Unit con repositorio que falla |
| CA-08 | Un servicio con carga previa muestra quién la hizo y cuándo. | Widget |
| CA-09 | La barra inferior distingue "Sin guardar" de "Guardado HH:mm". | Widget |
| CA-10 | El orden de los servicios es el que devuelve el servidor; ningún `sort` en el cliente. | Revisión de código + test |
| CA-11 | Editar un valor precargado marca cambios sin guardar; volver al valor original los limpia. | Unit |
| CA-12 | Con rol `lectura` la precarga funciona y los botones de escritura siguen deshabilitados. | Widget |

---

## 6. Plan de tareas

- [x] **T-1 — Capa de datos.** `CargaGuardadaDto` + `CamaPrestadaGuardadaDto`,
      método del datasource, entidad `CargaGuardada`, contrato y método del
      repositorio. Tests de serialización contra el JSON literal de §2.
- [x] **T-2 — Precarga en el formulario.** `cargarReferencias` acepta la carga
      previa y la aplica antes de `edicion`; `censoPersistido` queda apuntando a
      lo precargado para que `hayCambiosSinGuardar` funcione desde el arranque.
      Tests: precarga aplicada, ausencia tolerada, fallo tolerado (CA-04, CA-07,
      CA-11).
- [x] **T-3 — Caché por fecha.** `cargasDelDiaProvider`, consumo desde
      `CensoFormNotifier`, invalidación tras guardar, **retiro de `keepAlive`**.
      Test que reproduce el escenario del cliente (CA-03, CA-05, CA-06).
- [x] **T-4 — Presentación.** Línea de procedencia, estado de guardado en la
      barra, eliminación de `_AvisoCargaPrevia`. Widget tests (CA-08, CA-09).
- [ ] **T-5 — Verificación en dispositivo.** Escenario exacto del reporte del
      cliente, más el caso de red caída.
- [ ] **T-6 — Documentación.** Actualizar §7 y §8 del README, marcar en
      SPEC-002 que la limitación de lectura quedó resuelta, y registrar en
      ADR-0005 la decisión D-3 (retiro del `keepAlive`) con su motivo.

**Orden obligatorio:** T-1 → T-2 → T-3. T-4 puede ir en paralelo a T-3.

---

## 7. Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| R-11 | Retirar `keepAlive` deja al formulario sin red de seguridad si el `GET` falla justo al reabrir un servicio. | El aviso de CA-07 lo hace visible. Se prefiere un fallo explícito a memoria vieja presentada como verdad. |
| R-12 | La caché por fecha puede quedar rancia si otra persona edita la misma fecha desde otro dispositivo. | Se invalida al guardar y al volver a la pantalla de progreso. La línea de procedencia muestra quién y cuándo, así que una edición ajena se nota. |
| R-13 | El backend podría volver a cambiar el criterio de orden sin avisar, como pasó con `nombre` → `indice`. | La app no reordena nunca; hereda el orden del servidor. CA-10 lo fija como criterio verificable. |

---

## 8. Fuera de alcance

- **Edición concurrente real.** No hay bloqueo ni detección de conflicto: si dos
  personas editan la misma fecha, gana la última en guardar. Mostrar la
  procedencia es una mitigación social, no técnica. Si Admisión reporta
  conflictos reales, es un ADR nuevo.
- **Lectura de fechas ya confirmadas.** Este endpoint lee el staging. Para
  fechas confirmadas la fuente es `GET /censo-diario/historico`, que se sigue
  usando solo para el total del día anterior. Unificar ambas lecturas queda
  pendiente y no bloquea nada.
