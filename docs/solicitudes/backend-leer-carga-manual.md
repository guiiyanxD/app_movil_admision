# Solicitud al backend — leer la carga manual guardada

**De:** Willtech, equipo de la app móvil de Admisión
**Para:** equipo de `software-migracion` (API NestJS)
**Fecha:** 2026-08-02
**Repositorio afectado:** `software-migracion`
**Prioridad:** alta — hoy la app puede destruir datos sin que el operador lo note

---

## El problema, en una frase

El API permite **escribir y rectificar** la carga manual del censo, pero **no
permite leer lo que ya está guardado**. Como `POST /censo-diario/carga-manual`
es un upsert, la app reemplaza el registro completo cada vez que guarda — y
como no puede mostrar los valores previos, el operador edita a ciegas.

### Cómo se manifiesta hoy

1. El operador carga Medicina Interna para el 16 de julio y guarda.
2. Al día siguiente vuelve a esa fecha para corregir un óbito.
3. **El formulario se abre en cero**, porque la app no tiene de dónde leer los
   nueve valores guardados.
4. Si guarda, el upsert reemplaza los datos correctos por lo que haya en
   pantalla.

La app mitiga esto con una advertencia visible —"este servicio ya fue cargado,
la app no puede mostrarte esos valores"— pero es una curita: no evita la
pérdida, solo la anuncia.

### Qué sí existe y no alcanza

- `GET /censo-diario/carga-manual/estado?fecha=` devuelve
  `{ servicioId, servicioNombre, cargado, cuadra }`. Son **booleanos**: dicen
  que hay algo cargado, no qué.
- `GET /censo-diario/historico?fecha=` sí devuelve los valores completos, pero
  lee de `VaciadoCenso` — es decir, **solo sirve para fechas ya confirmadas**.
  Las que están en staging (`CargaManualCenso`), que son justamente las que se
  están editando, no se pueden leer por ningún lado.

---

## Lo que se pide

Un endpoint de lectura del staging:

```
GET /api/v1/censo-diario/carga-manual?fecha=YYYY-MM-DD[&servicioId=<uuid>]
```

### Comportamiento

- Devuelve las filas de `CargaManualCenso` de esa fecha, con sus
  `camasPrestadas` anidadas.
- `servicioId` es **opcional**. Sin él devuelve todos los servicios cargados de
  la fecha; con él, solo ese.
- Un servicio sin fila de staging simplemente **no aparece** en el array. No es
  un 404 ni un error: es el estado normal de un servicio todavía no cargado.
- Fecha sin ninguna carga → array vacío.

### Por qué el parámetro `servicioId` es opcional

La app móvil recorre los servicios del día con flechas de navegación, sin
volver a la pantalla anterior. Si el endpoint fuera solo por servicio, cada
salto costaría una petición: trece llamadas para recorrer un día, sobre la
conexión de un hospital y de noche. Devolviendo la fecha completa, la app pide
una vez y cachea.

Se mantiene el filtro por servicio porque hay casos donde alcanza con uno y no
tiene sentido traer todo.

### Respuesta esperada — camelCase

Consistente con `estado` e `historico`, que ya son camelCase y viven en el
mismo módulo:

```json
[
  {
    "servicioId": "3fa1-uuid",
    "servicioNombre": "Medicina Interna",
    "fecha": "2026-07-16",
    "ingreso": 4,
    "ingresoTraslado": 0,
    "egreso": 3,
    "egresoTraslado": 0,
    "obito": 0,
    "aislamiento": 1,
    "bloqueada": 1,
    "libre": 2,
    "total": 34,
    "dotacion": 36,
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

**Sobre `actualizadoEn` y `creadoPorNombre`:** no son decorativos. Este módulo
escribe el histórico estadístico de un hospital y varias personas pueden tocar
la misma fecha. Poder mostrar "última edición: Ana Rojas, ayer 22:14" antes de
que alguien pise el trabajo de otro es barato acá y caro de reconstruir después.
Ambos campos ya están en el modelo (`actualizado_en`, relación `creadoPor`).

**Sobre `especialidadNombre`:** evita que la app tenga que cruzar contra el
catálogo de especialidades solo para mostrar una fila. Mismo criterio que ya usa
`presentarFilaCamaPrestada`.

**Sobre `dotacion`:** la calcula el servidor (`total + libre`) y la app no la
envía. Devolverla permite mostrar exactamente lo que quedó guardado en vez de
recalcularla del lado del cliente.

---

## Dónde va, según las convenciones del proyecto

**No hace falta un caso de uso.** Es una lectura simple, así que corresponde un
método más en el servicio existente, igual que `obtenerEstado`. La regla del
proyecto —"un caso de uso = una clase con `.ejecutar()` y su `.spec.ts`"— aplica
a `casos-uso/`, no a servicios de lectura.

| Archivo | Cambio |
|---|---|
| `apps/api/src/modulos/censo-diario/carga-manual/carga-manual.service.ts` | Nuevo método `obtenerCargas(fecha, servicioId?)` |
| `apps/api/src/modulos/censo-diario/carga-manual/carga-manual.controller.ts` | Nuevo `@Get()` con `@ApiOperation` y `@ApiQuery` |
| `apps/api/src/modulos/censo-diario/dominio/presentador.ts` | Nuevo `presentarCargaManual(fila)`, mismo patrón que `presentarVaciadoCenso` |

### Autorización

**Sin `@Roles`**, igual que `GET /carga-manual/estado`. Es solo lectura y el
criterio ya establecido en el proyecto es dejar los `GET` abiertos a cualquier
usuario autenticado, incluido el rol `lectura`. Aplicar `@Roles(admin, operador)`
acá rompería el modo consulta de la app móvil sin ganar nada.

### Convención de fecha

La misma que usa todo el módulo:

```ts
const fechaDate = new Date(`${fecha}T00:00:00Z`);
```

### Bosquejo

```ts
// carga-manual.service.ts
async obtenerCargas(fecha: string, servicioId?: string) {
  const fechaDate = new Date(`${fecha}T00:00:00Z`);

  return this.prisma.cargaManualCenso.findMany({
    where: {
      fecha: fechaDate,
      ...(servicioId && { servicio_id: servicioId }),
    },
    include: {
      servicio: true,
      creadoPor: true,
      camasPrestadas: { include: { especialidad: true } },
    },
    // Mismo orden que obtenerEstado, para que la app no tenga que reordenar.
    orderBy: { servicio: { nombre: 'asc' } },
  });
}
```

```ts
// carga-manual.controller.ts
@ApiOperation({
  summary: 'Valores ya cargados en staging para una fecha, para poder editarlos',
})
@ApiQuery({ name: 'fecha', example: '2026-07-16' })
@ApiQuery({ name: 'servicioId', required: false })
@Get()
async obtener(
  @Query('fecha') fecha: string,
  @Query('servicioId') servicioId?: string,
) {
  const filas = await this.cargaManualService.obtenerCargas(fecha, servicioId);
  return filas.map(presentarCargaManual);
}
```

---

## Lo que NO se pide

Vale aclararlo para que nadie invierta de más:

- **No hay que tocar `estado`.** Es deliberadamente barato y la app lo llama
  cada vez que entra a la pantalla de progreso. Engordarlo con los valores
  encarecería la consulta más frecuente para servir un caso que ocurre menos.
  Que sean dos endpoints separados es intencional.
- **No hace falta un `PUT`/`PATCH`.** La rectificación ya funciona: `POST
  /carga-manual` es upsert por `(fecha, servicioId)` y `POST /confirmar` es
  idempotente. Lo único que falta es **leer**.
- **No hay que versionar ni auditar los cambios.** `AuditoriaService` ya
  registra `CARGA_MANUAL_SERVICIO` en cada guardado.

---

## Criterios de aceptación

| # | Criterio |
|---|---|
| 1 | `GET /censo-diario/carga-manual?fecha=2026-07-16` devuelve un array con todos los servicios cargados de esa fecha, en camelCase. |
| 2 | Agregar `&servicioId=<uuid>` devuelve solo esa fila. |
| 3 | Una fecha sin cargas devuelve `[]`, no un 404. |
| 4 | Un servicio sin fila de staging no aparece en el array; no se devuelve una fila en cero. |
| 5 | Las `camasPrestadas` vienen anidadas, con `especialidadNombre` resuelto. |
| 6 | Un usuario con rol `lectura` puede consultarlo (sin `@Roles`). |
| 7 | El orden coincide con el de `GET /carga-manual/estado` (`nombre` ascendente). |
| 8 | Aparece en Swagger bajo el tag `censo-diario/carga-manual`. |
| 9 | `pnpm --filter @migracion/api typecheck` y la suite de Vitest siguen en verde. |

---

## Verificación manual sugerida

1. Cargar un servicio con `POST /censo-diario/carga-manual`, incluyendo al
   menos una cama prestada.
2. `GET /censo-diario/carga-manual?fecha=<esa fecha>` → la fila aparece con los
   nueve valores, la dotación calculada y la cama prestada anidada.
3. Volver a guardar el mismo servicio con valores distintos → el `GET` refleja
   los nuevos, sin duplicar filas.
4. Consultar una fecha sin cargas → `[]`.
5. Repetir el paso 2 con un token de rol `lectura` → 200.

---

## Impacto en la app móvil

Con este endpoint, el formulario se abre con los valores reales y editar deja
de ser retipear a ciegas. Desaparece la advertencia de sobrescritura y, sobre
todo, desaparece la posibilidad de que alguien borre una carga previa sin
enterarse.

Mientras tanto la app va a precargar desde `GET /censo-diario/historico` para
las fechas **ya confirmadas**, que es lo único legible hoy. Las fechas en
staging —las que están a medio cargar, que son las que más se editan— siguen
sin solución hasta que exista este endpoint.
