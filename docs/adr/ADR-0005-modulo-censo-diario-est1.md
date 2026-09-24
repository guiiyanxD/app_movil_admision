# ADR-0005 — Módulo Censo Diario (EST-1): alcance, modelo y captura por voz

| Campo | Valor |
|---|---|
| **Estado** | Aceptado |
| **Fecha** | 2026-07-31 |
| **Decide** | Willtech — Arquitectura de Software |
| **Consultado** | Servicio de Admisión, Caja Petrolera de Salud (Regional Santa Cruz) |
| **Implementa** | SPEC-002 (`docs/specs/censo_diario_est1_spec.md`) |
| **Relacionados** | ADR-0001 (Clean Architecture), ADR-0002 (Riverpod), ADR-0003 (Speech-to-Text), ADR-0004 (CI/CD iOS sin Mac) |
| **Sprint** | 1 (MVP interno, 3 semanas) |

---

## Contexto

El Servicio de Admisión opera en papel el formulario **EST-1 — Censo Diario**, uno por servicio
hospitalario y por día. El sistema `software-migracion` calcula el censo en vivo automáticamente a
partir de eventos de paciente (`BedStay`), pero para las fechas **anteriores al cutover a
producción** esos eventos no existen: no hay nada que calcular. El backend ya expone un API de
**carga manual histórica** (staging + confirmación atómica) implementada y verificada contra
Postgres real.

Willtech construye la app móvil Flutter que consume ese API. Al analizar el formulario físico
contra el contrato HTTP aparecieron divergencias que exigían decisión antes de escribir código.

**Hecho central que condicionó todo lo demás:** el EST-1 impreso **está desactualizado**. Con los
años se implementaron reglas nuevas sin reimprimir el formulario, de modo que hay etiquetas que ya
no significan lo que dicen y datos que se registran al margen, sin casilla propia.

---

## Decisiones

### D-1 — El módulo es exclusivamente backfill histórico

Cubre únicamente la carga de fechas **anteriores a hoy**. No reemplaza ni duplica el censo diario
en vivo, que sigue siendo automático y fuera del alcance de la app.

*Por qué:* el backend rechaza con `403` la fecha actual y futura (`puedeCargarManual`), y bloquea
sobrescribir una fecha con `CierreCenso.origen = 'automatico'`. Operar el censo en vivo desde la
app exigiría cambios de backend y una política de convivencia con el cierre automático — decisión
de producto distinta, no una extensión de esta.

*Consecuencia:* si Admisión pide operación diaria en vivo, se abre un ADR nuevo. No se modifica
éste.

### D-2 — Solo se persisten contadores agregados; el detalle por paciente queda en el papel

La app **no captura** H.C., Pieza, Hora ni Nombre del paciente. Persiste los 9 contadores del
consolidado + camas prestadas.

*Por qué:* el contrato HTTP no tiene ningún campo ni endpoint donde persistir movimientos
individuales. Capturarlos en el dispositivo crearía un almacén paralelo que nadie consume, que
nadie respalda y que divergiría del sistema central — deuda sin contraparte de valor. Pedir un
endpoint nuevo bloquearía la entrega móvil de 3 semanas contra el ciclo del equipo de backend.

*Consecuencia:* el formulario de papel sigue siendo el respaldo legal del detalle. Los bloques de
movimiento detallado se usan como **insumo de conteo**: el operador cuenta filas y tipea el total.

### D-3 — Correspondencia papel → app, con las etiquetas desactualizadas explicitadas

| Fila impresa en el EST-1 | Campo del API |
|---|---|
| Pacientes del día anterior | *referencia* (`GET /historico` de `fecha − 1`) |
| Pacientes ingresados | *referencia* |
| Pacientes fallecidos | `obito` |
| **"Ingresos y egresos del mismo día"** ⚠️ etiqueta desactualizada | `egreso` (egresos directos) |
| Saldo pacientes a las 24 horas | `total` |
| Números de camas libres | `libre` |
| Capacidad del servicio | *referencia* (`GET /camas`) |
| *(sin fila impresa)* | `aislamiento`, `bloqueada` |
| Conteo del bloque `INGRESO (POR ADMISIÓN)` | `ingreso` |
| Conteo del bloque `INGRESO — POR TRASLADO DEL SERVICIO` | `ingresoTraslado` |
| Conteo del bloque `EGRESO — POR TRASLADO DEL SERVICIO` | `egresoTraslado` |

**Los cuatro contadores de movimiento salen de contar bloques, nunca de leer una casilla del
resumen.** El RESUMEN no tiene fila propia para traslados.

*Decisión de rotulado:* la app **no reproduce** la etiqueta "Ingresos y egresos del mismo día".
Rotula el campo **"Egresos por salida"** y muestra como texto auxiliar *"en el formulario: fila
«Ingresos y egresos del mismo día»"*.

*Por qué:* copiar el rótulo viejo perpetúa un error que Admisión ya identificó; ocultarlo del todo
deja al operador sin poder ubicar la correspondencia con el papel que tiene delante. Se muestran
ambos, con jerarquía visual clara.

### D-4 — El óbito es independiente del egreso

```
saldo24h = díaAnterior + ingreso + ingresoTraslado − egreso − egresoTraslado − obito
```

Un paciente fallecido **no** se cuenta además como egreso. Verificado contra la muestra
fotografiada del 16-jul (Medicina Interna, piso 1°): `33 + 4 − 3 − 0 = 34`.

*Consecuencia:* la fórmula se implementa en `CensoServicio.saldoEsperado` y alimenta la validación
**V-07**, que es **advertencia, no bloqueo**. Durante un backfill es esperable que falte el cierre
del día previo o que el papel tenga inconsistencias propias; la app muestra la aritmética completa
y deja decidir al operador, que es quien tiene el documento a la vista.

### D-5 — Camas prestadas: registro informativo, ajeno a toda fórmula

Semántica fijada según la query `construirFilasCamasPrestadas` (`censo-diario.service.ts:146`),
definición canónica en este sistema:

- `servicio` = el servicio **dueño de la cama** (el del EST-1 que se está llenando).
- `especialidadId` = especialidad **del paciente**, distinta de la especialidad nativa de la cama.
  En la anotación "Cir = 1" de la muestra: paciente de **Cirugía** en cama de Medicina Interna.
- `tipoIngreso` = `DIRECTO` si esa estancia no tiene una estancia previa contigua; `TRASLADO` si
  el paciente venía de otra cama.
- Es un **flujo**, no un stock: cuenta estancias que **empiezan** ese día, igual que los
  contadores de ingreso.

**No participa en `total`, ni en `dotacion`, ni en el cuadre contra la capacidad.** Solo se
registra. Mismo criterio ya vigente en la vista web
(`2026-07-17-camas-prestadas-censo-diario-design.md`). El paciente en cama prestada **sí** cuenta
en `total`, porque ocupa una cama del servicio.

*Diferencia relevante con el flujo en vivo:* `CerrarCensoCasoUso` recalcula camas prestadas desde
los `BedStay` y pisaría cualquier edición manual, pero `ConfirmarCargaManualCasoUso` **copia tal
cual** lo cargado en staging. En backfill no hay `BedStay` que recalcular, así que el conteo manual
del operador es el único dato y sobrevive a la confirmación.

*Consecuencia:* sección **opcional y colapsada**; su ausencia nunca bloquea. Validación
informativa **V-10** (`Σ DIRECTO <= ingreso`), sin equivalente para `TRASLADO` porque éste incluye
movimientos internos dentro del mismo servicio y daría falsos positivos.

### D-6 — La voz cubre solo cifras, y nunca persiste sin doble confirmación

**Alcance:** dictado de los contadores del resumen (`"ingresos cuatro, egresos tres, óbitos
cero"`). **No** se dictan nombres de paciente, H.C. ni códigos de pieza.

*Por qué:* el reconocimiento de antropónimos bolivianos y de códigos alfanuméricos tiene una tasa
de error que obligaría a una pantalla de corrección tan pesada que anularía la ganancia de
velocidad. Los números en español son un dominio cerrado y verificable con tests unitarios.

**Dos compuertas, no una:**

1. Confirmar la propuesta de voz **solo la aplica al formulario en memoria**.
2. La persistencia exige además pulsar "Guardar servicio".

*Invariante verificable:* no existe transición desde `escuchandoVoz`, `procesandoVoz` ni
`confirmandoVoz` hacia `guardando`. Se comprueba con un test unitario que enumera todas las
transiciones de la máquina de estados, no con revisión de código.

**La voz es siempre aditiva.** Sin permiso de micrófono, o sin locale `es_*` disponible, el
formulario es 100% operable por teclado y el botón de voz se oculta — nunca se muestra roto ni se
cae en silencio a `en_US`.

### D-7 — El catálogo manda: prohibido codificar la cantidad de servicios

Todo servicio que se abre físicamente se crea en el sistema web y aparece en `GET /servicios`. La
app renderiza lo que devuelva el endpoint. **Ninguna pantalla, constante ni test fija el número
13.** Un servicio nuevo aparece sin necesidad de release.

*Requisito asociado:* el servicio nuevo necesita su fila de mapeo a vaciado-admisión, que es un
paso manual del equipo de datos. La app lo detecta al cargar referencias (**V-06**) y lo muestra
en la pantalla de progreso desde el inicio, no al confirmar.

### D-8 — `admin` y `operador` usan la app; `lectura` entra en modo consulta

Ambos roles cubren los 10 endpoints del flujo, sin gating propio en la UI. El rol `lectura`, que
no puede escribir carga manual, abre la app en **modo consulta**: progreso y formularios visibles
en solo lectura, con "Guardar servicio" y "Confirmar día" deshabilitados y con la razón explícita.

*Por qué:* dejar que alguien complete nueve campos para recibir un `403` al guardar es un fallo de
diseño, no un caso de error.

### D-9 — La regla de fecha se valida en hora local de Bolivia, más estricta que el backend

El backend evalúa `puedeCargarManual` en **UTC**; Bolivia es UTC−4 sin horario de verano. Entre
las 20:00 y la medianoche local, el backend ya considera "ayer" al día en curso y lo aceptaría.

**El cliente valida en `America/La_Paz` a propósito: nunca es más permisivo que el servidor.** No
se debe relajar esta regla para "aprovechar" el hueco de UTC.

*Nota de serialización:* `fecha` viaja como `'YYYY-MM-DD'` plano. Nunca ISO-8601 con offset — el
backend hace `new Date(\`${fecha}T00:00:00Z\`)` y un offset `-04:00` corre el día.

### D-12 — El estado del formulario se recupera del servidor, no de la memoria

*Añadido 2026-08-03, tras el bug reportado por el cliente el 2026-08-02.*

Cuando el API no permitía leer el staging, el formulario se abría en cero al
volver a un servicio ya cargado. Se corrigió reteniéndolo en memoria con
`ref.keepAlive()`. Con el endpoint `GET /censo-diario/carga-manual` disponible,
**esa retención se retira**.

*Por qué no dejar ambos:* crearía dos fuentes de verdad. Un formulario retenido
podría mostrar valores más viejos que los del servidor —otro operador editando
la misma fecha desde otro dispositivo— y ganaría por estar primero. Es
exactamente la inconsistencia silenciosa que el endpoint vino a eliminar.

*Consecuencia asumida:* si la lectura falla, el formulario abre en cero **y lo
declara**. Es peor que retener memoria en ese caso puntual, pero honesto:
preferimos decir "no pude leer" a presentar ceros como si fueran el estado real
del servidor.

*Efecto secundario que hay que vigilar:* descartar cambios que todavía no se
pueden guardar ahora sí pierde el trabajo. Antes sobrevivía en memoria aunque el
diálogo dijera lo contrario. Se mitigó invirtiendo el énfasis —"Quedarme acá" es
la acción primaria— pero si en uso real los operadores pierden trabajo por esta
vía, la solución no es volver al `keepAlive` sino permitir guardar borradores que
no cuadren, lo que exige cambiar el contrato con el backend.

### D-11 — Camas libres se sugiere, no se calcula

La regla de cuadre del backend, despejada, da el valor exacto:

```
  total + libre + bloqueada + aislamiento == capacidad
→ libre = capacidad − total − bloqueada − aislamiento
```

Aun así **el campo sigue siendo tipeado**, y el valor deducido se ofrece como
sugerencia de un toque.

*Por qué no calcularlo:*

1. **Se perdería el único control cruzado.** `libre` viene transcrito del papel
   —Admisión sí llena esa fila, confirmado 2026-08-02— y compararlo contra el
   cálculo es la única forma de detectar un error de tipeo en los otros cuatro
   números. Si el campo se calcula, la ecuación cuadra siempre por construcción:
   un `total` de 43 en vez de 34 produciría unas camas libres perfectamente
   plausibles y el error entraría al histórico sin que nadie lo note.
2. **La capacidad es de hoy, no de la fecha cargada.** Sale del catálogo de
   camas actual. Usarla para *validar y avisar* es razonable; usarla para
   *generar* un dato que se persiste como hecho histórico sería inventar una
   cifra que nunca fue cierta ese día. Es el mismo riesgo R-03, pero mientras
   validar lo expone, calcular lo esconde.

*Consecuencia:* se gana casi toda la velocidad —un toque en lugar de tipear—
sin perder la señal. La sugerencia se calla cuando coincide con lo cargado,
cuando el formulario está intacto, cuando no hay capacidad conocida y cuando el
cálculo da negativo (ese caso ya lo explica V-05 con números concretos).

### D-10 — Se usan dos endpoints que la guía de integración no documenta

Verificados en el código fuente, no inferidos:

1. **`GET /camas?servicioId=&soloActivas=true`** — la guía afirma en §9 que está fuera del alcance
   y que la app no puede prevalidar el cuadre. Existe, no tiene `@Roles`, y filtra por
   `activa: true`, el mismo criterio del `count` del backend. La capacidad es el `length` de esa
   lista. Con esto **V-05** es bloqueante en el cliente y se evita el viaje de ida y vuelta al
   `400`. Si la llamada falla, degrada a advertencia: nunca se bloquea al operador por una falla
   de red en una consulta auxiliar.
2. **`GET /censo-diario/cierre/:fecha`** — devuelve la fila de `CierreCenso` con su `origen`.
   Permite bloquear en el **calendario** las fechas ya cerradas por el flujo automático
   (**V-09**), en vez de descubrirlo tras digitar todos los servicios.

*Acción pendiente:* proponer al equipo de backend la corrección de §9 de
`api-carga-manual-app-movil.md` y la incorporación de ambos endpoints a la guía.

### D-13 — Los reportes en PDF se generan en el dispositivo, con `pdf` + `printing`

*Agregada el 2026-08-03 con SPEC-004.*

El reporte de censo debe poder verse, imprimirse y descargarse desde el móvil. La web lo
resuelve con `jspdf` en el navegador; el equivalente establecido en Dart es el paquete `pdf`
para construir el documento y `printing` para el diálogo del sistema, que cubre **imprimir,
compartir y guardar con una sola integración**.

Se descartó pedirle el PDF al backend: hoy no existe ese endpoint, la web tampoco lo usa, y
crearlo ataría la entrega móvil al ciclo de otro equipo por un documento que el cliente ya sabe
construir con los datos que recibe.

**Consecuencia sobre la cadena de build.** `printing` trae código nativo Android e iOS, o sea
el mismo perfil de riesgo que ya se materializó con `permission_handler` (R-10). Por eso la
primera tarea de SPEC-004 fue una pantalla de humo que genera un PDF de una página —
`features/diagnostico/presentation/pantalla_prueba_pdf.dart` — antes de escribir una línea del
reporte. Si la cadena rompe, **se fija la versión del plugin; no se migra el toolchain a mitad
de sprint**.

Esa pantalla verifica algo más que la compilación: las fuentes base del paquete `pdf` cubren
Latin-1, y el proyecto usa el signo menos tipográfico `−` (U+2212), que no está ahí. Si sale
como cuadro hay que empaquetar una fuente, lo que cambia el peso del APK. Es barato saberlo
antes y caro descubrirlo después.

**Dónde vive la aritmética.** Los totales por fila, por columna y el general **no** se calculan
en el generador de PDF, sino en `reporteria/domain/usecases/armar_matriz_reporte.dart`. La
pantalla toma un movimiento de ese cálculo y el PDF toma los ocho, del mismo resultado. Si cada
uno sumara por su cuenta podrían discrepar, y una diferencia entre el total que se ve y el que
se imprime no la detecta nadie hasta que alguien la suma a mano.

**Y el orden de las columnas** sigue la regla de D-7: sale del catálogo cruzado con el mapeo,
no de una constante. La web sí tiene una lista fija de doce servicios (`SERVICIOS_CENSO`); si
los dos impresos difieren en el orden, la desactualizada es esa constante, y se reporta como
deuda en vez de copiarla.

---

## Alternativas consideradas y descartadas

| Alternativa | Por qué se descartó |
|---|---|
| Capturar el detalle por paciente en SQLite local y derivar los contadores | Crea un almacén paralelo que ningún sistema consume ni respalda, y que divergiría del central. El valor de trazabilidad ya lo cubre el papel. |
| Pedir al backend un endpoint de movimientos detallados | Bloquea la entrega móvil de 3 semanas contra el ciclo de otro equipo, por un requisito que el papel ya satisface. |
| Modo offline-first con cola de sincronización | El contrato guarda staging en el servidor en cada `POST`; no hay ventana de trabajo sin conexión en el diseño actual. Sería complejidad especulativa. |
| Dictado de movimiento completo (pieza, hora, nombre) | Tasa de error inaceptable en antropónimos bolivianos; la pantalla de corrección necesaria anularía la ganancia de velocidad. Reevaluable tras medir precisión real (R-05). |
| Aplicar la voz directamente al formulario, sin pantalla de confirmación | Viola el criterio de calidad crítico del proyecto. Un error de transcripción entraría al histórico institucional sin que nadie lo vea. |
| Reproducir en la app las etiquetas del formulario impreso | Perpetúa errores que Admisión ya identificó como desactualizados. |

---

## Consecuencias

**Positivas**

- Alcance cerrado y alineado 1:1 con un API ya implementado y verificado: cero dependencia de
  trabajo pendiente de backend para el Sprint 1.
- Superficie de captura reducida a 9 enteros por servicio: viable para un equipo de 1-2
  desarrolladores en 3 semanas, y rápido de operar de noche en una docena de servicios.
- La lógica de negocio (fórmulas, cuadre, regla de fecha, parser de números) queda en `domain/`
  como Dart puro: los tests más valiosos son también los más baratos.
- Las divergencias del formulario impreso quedan documentadas en un solo lugar
  (`GuiaTranscripcionEst1` + §2.1 de SPEC-002), no dispersas en el código.

**Negativas y riesgos aceptados**

- El detalle por paciente no se digitaliza: si en el futuro se quiere auditar movimiento por
  movimiento en fechas históricas, habrá que volver al papel.
- Las camas prestadas dependen de un conteo manual sin respaldo estructurado (**R-08**). V-10 solo
  detecta el caso extremo de exceder los ingresos del día.
- El EST-1 impreso acumula reglas desactualizadas; pueden existir divergencias aún no detectadas
  (**R-09**). Se revisa con Admisión al cerrar el Sprint 1.
- La precisión del STT con números en `es-BO` no está medida (**R-05**). Spike de 1 día sobre
  dispositivo físico en el Sprint 1; si resulta baja, la voz pasa a "nice to have" y el teclado
  sostiene el MVP sin replanificar.
- `cuadra` se recalcula contra la capacidad de camas **actual** en cada consulta: un día ya cargado
  puede dejar de cuadrar si cambia el catálogo (**R-03**). Se mitiga refrescando `GET /estado`
  inmediatamente antes de habilitar "Confirmar día".
- **R-10 — El ecosistema Flutter está migrando a AGP 9 y los plugins se adelantan al canal
  estable.** Ya golpeó: `permission_handler` 13.x trae un `build.gradle.kts` que no compila contra
  el AGP 8.11.1 que genera el Flutter actual. Se resolvió con un pin en 12.x (README §7). Es
  previsible que vuelva a pasar con otros plugins. **Política del proyecto:** ante un fallo de
  compilación de Gradle originado en un plugin, la respuesta por defecto es **fijar la versión del
  plugin**, no migrar el toolchain a mitad de sprint. La migración a AGP 9 se hace una sola vez,
  planificada, cuando `speech_to_text` y `flutter_secure_storage` también estén listos.

---

## Verificación

Esta decisión se considera correctamente implementada cuando pasan los criterios **CA-01 a CA-17**
de SPEC-002. Los que verifican directamente este ADR:

| Decisión | Criterio |
|---|---|
| D-4 | CA-11 y el test de `saldoEsperado` con la muestra del 16-jul |
| D-5 | CA-14 + tests de V-10 |
| D-6 | **CA-04** (enumeración exhaustiva de transiciones), CA-02, CA-03, CA-09 |
| D-7 | CA-15 (agregar un servicio en el sistema web lo hace aparecer sin recompilar) |
| D-8 | CA-16 (una cuenta `lectura` nunca recibe un `403` por intentar guardar) |
| D-9 | CA-06 y CA-07 (incluye el caso de las 21:00 hora Bolivia) |
| D-10 | CA-13 (fecha con cierre automático bloqueada en el calendario) |
