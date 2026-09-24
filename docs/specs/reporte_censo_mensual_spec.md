# SPEC-004 — Reporte de censo mensual en la app móvil

| Campo | Valor |
|---|---|
| **ID** | SPEC-004 |
| **Título** | Reporte de movimientos por servicio, con impresión y descarga en PDF |
| **Estado** | Aprobada — P-07 y P-08 cerradas con el cliente (2026-08-03) |
| **Autor** | Willtech — Arquitectura de Software |
| **Fecha** | 2026-08-03 |
| **Depende de** | SPEC-002 (dominio del censo), autenticación |
| **Análisis previo** | `software-migracion/docs/superpowers/specs/2026-08-03-reporte-carga-manual-design.md` |

---

## 1. Contexto y alcance

Admisión necesita, desde la app móvil, **ver, imprimir y descargar en PDF** el
reporte de movimientos por servicio en un rango de fechas, con la posibilidad de
agrupar por día o por mes. Es el mismo reporte que ya tiene la web.

Se verificó con el cliente que la carga manual y lo que muestra el frontend son
el mismo dato una vez confirmado el día: `ConfirmarCargaManual` copia el staging
a `public.censo`. **No hace falta ningún cambio en el backend.**

### Dentro del alcance

- Consumo de `GET /reporteria/censo-mensual`.
- Vista en pantalla, adaptada a un teléfono.
- Generación de PDF con el mismo layout que el de la web.
- Compartir e imprimir.

### Fuera del alcance

| Fuera | Razón |
|---|---|
| **Filtro por servicio** | Confirmado con el cliente (2026-08-03): no es requisito. La web tampoco filtra, y el objetivo es que el módulo genere lo mismo. Agregarlo sería código que nadie pidió y que hay que mantener igual. |
| **Reporte de camas prestadas** | Sí hace falta, pero **va por spec separada**. Exige consumir el catálogo de especialidades, que esta app todavía no tiene, y meterlo acá mezclaría dos trabajos con dependencias distintas. La infraestructura de PDF de este trabajo lo habilita. |
| Censo diario en vivo | Existe en la web y nadie lo pidió en el móvil. |
| Exportación a Excel | La web la tiene; en un teléfono un `.xlsx` no se abre ni se edita cómodamente. Si se pide, es otra decisión. |
| Reportar fechas cargadas **sin confirmar** | El endpoint lee el censo oficial y esa es la semántica correcta. Ver §3, D-4. |

**Criterio que ordena esta tabla:** se implementa lo que se pidió y nada más.
Cada opción de más es superficie que hay que probar, documentar y mantener, y en
un módulo de reportería estadística también es una forma más de que dos personas
obtengan cifras distintas del mismo período.

---

## 2. Contrato consumido

```
GET /api/v1/reporteria/censo-mensual?fechaInicio=YYYY-MM-DD&fechaFin=YYYY-MM-DD&detalle=true|false
Roles: cualquier usuario autenticado
```

Respuesta en camelCase, una fila por período y servicio:

```json
[
  {
    "periodo": "2026-07-16",
    "servicio": "Medicina Interna",
    "ingreso": 4, "ingresoTraslado": 0,
    "egreso": 3, "egresoTraslado": 0,
    "obito": 0,
    "aislamiento": 1, "bloqueada": 1,
    "total": 34
  }
]
```

- `detalle=true` → `periodo` es `YYYY-MM-DD`.
- `detalle=false` → `periodo` es `YYYY-MM`, con los valores **sumados** en el mes.

**Lo que la respuesta NO trae:** `servicioId` ni `indice`. `servicio` es el
nombre de **vaciado-admisión**, no el del catálogo propio — sin tildes
(`Pediatria`, `Neonatologia`). Y el SQL ordena alfabéticamente, no por el orden
institucional. Los tres puntos condicionan D-2.

---

## 3. Decisiones de diseño

### D-1 — El PDF se genera en el dispositivo, con `pdf` + `printing`

La web usa `jspdf`; en Dart el equivalente establecido es el paquete `pdf` para
construir el documento y `printing` para el diálogo del sistema, que resuelve
**imprimir, compartir y guardar con una sola integración**. Es exactamente lo
que se pidió.

**Riesgo asociado.** `printing` trae código nativo Android e iOS, así que puede
chocar con la cadena de build igual que pasó con `permission_handler` 13.x. La
política del proyecto ya está fijada (ADR-0005, R-10): ante un fallo de Gradle
originado en un plugin, **se fija la versión del plugin**, no se migra el
toolchain a mitad de sprint. La primera tarea de este trabajo es verificar que
compila antes de escribir el reporte.

### D-2 — El orden de las columnas se recupera cruzando con el mapeo

Las columnas del reporte son los servicios. El endpoint los devuelve por nombre
de vaciado y en orden alfabético, pero el orden que Admisión configuró vive en
`Servicio.indice` del catálogo propio.

La app ya consume `GET /censo-diario/mapeo/servicios`, que traduce
`servicioId → nombreVaciado`. Cruzando ambos se recupera el orden institucional
**sin pedirle nada al backend**:

```
nombre de vaciado → (mapeo) → servicioId → (catálogo) → indice
```

Un servicio que aparezca en el reporte pero no tenga mapeo **no se descarta**: va
al final, después de los ordenados. Ocultarlo sería perder datos del reporte por
un problema de catálogo.

*Por qué no copiar la constante de la web:* `SERVICIOS_CENSO` es una lista fija
de doce nombres. Un servicio nuevo no aparecería y uno renombrado se volvería una
columna de ceros, en silencio. Es la misma regla que ya rige en esta app desde
ADR-0005 D-7: **ninguna constante del cliente fija la cantidad de servicios**.

### D-3 — En pantalla, un movimiento por vez; en el PDF, los ocho

El reporte tiene ocho movimientos y una docena de servicios. En papel tamaño
carta eso entra —la web emite una página por movimiento—. En un teléfono no.

La pantalla muestra **un movimiento a la vez**, elegido con un selector, y la
tabla se desplaza en horizontal. Es el mismo patrón que usa la web con su
`movimientoActivo`, y ahí la pantalla es mucho más ancha.

El PDF, en cambio, **no se degrada**: emite las ocho páginas completas, porque
su destino es el papel o la pantalla de una computadora, no el teléfono. Reducir
el PDF al movimiento visible sería entregar un reporte distinto según desde
dónde se generó.

### D-4 — El reporte declara que muestra solo lo confirmado

`GET /reporteria/censo-mensual` lee `public.censo`, que solo tiene fechas
confirmadas. Una fecha cargada y no confirmada **no aparece**.

Es la semántica correcta —un reporte estadístico muestra el censo oficial— pero
en esta app es una trampa previsible: **es la misma app donde se carga**. El
operador carga cinco días, abre el reporte y no ve nada.

Por eso el reporte lo dice siempre, no solo cuando viene vacío: una línea fija
bajo el título aclarando que se muestran las fechas ya confirmadas. Y cuando el
rango devuelve `[]`, el estado vacío lo repite con la acción a mano —ir a
confirmar el día— en vez de un "sin datos" que no explica nada.

### D-5 — Los totales se calculan en el cliente

La web suma en el generador de PDF: total por fila, total por columna y total
general. El endpoint no los devuelve.

Se replica, **pero en `domain/`**, no en el generador de PDF. Así la misma
aritmética alimenta la tabla en pantalla y el PDF, y se testea sin renderizar
nada. Que el total impreso y el de la pantalla puedan discrepar es exactamente
el tipo de error que nadie detecta hasta que alguien lo suma a mano.

---

## 4. Estructura

```
lib/features/reporteria/
├── domain/
│   ├── entities/fila_reporte_censo.dart      Una fila del endpoint
│   ├── entities/movimiento_reporte.dart      Los 8 movimientos, con etiqueta
│   ├── value_objects/rango_fechas.dart       Validación del rango
│   └── usecases/armar_matriz_reporte.dart    Períodos × servicios + totales
├── data/
│   ├── models/fila_reporte_censo_dto.dart
│   ├── datasources/reporteria_remote_datasource.dart
│   └── repositories/reporteria_repository_impl.dart
└── presentation/
    ├── providers/reporteria_providers.dart
    ├── pages/reporte_censo_page.dart
    ├── widgets/                              Selector de rango, de agrupación,
    │                                         de movimiento, tabla
    └── pdf/generar_pdf_censo.dart
```

`armar_matriz_reporte` es el corazón y es Dart puro: recibe las filas planas y
el orden de servicios, y devuelve la matriz con sus totales. Es lo que hace que
D-5 sea verificable.

---

## 5. Criterios de aceptación

| # | Criterio | Verificación |
|---|---|---|
| CA-01 | Con un rango y "detalle diario", se ve una fila por día y servicio. | Integración |
| CA-02 | Al cambiar a "resumen mensual", los valores quedan **sumados por mes**. | Integración |
| CA-03 | Las columnas siguen el orden `indice` del catálogo, no el alfabético. | Unit |
| CA-04 | Un servicio presente en el reporte pero sin mapeo aparece igual, al final. | Unit |
| CA-05 | Ninguna constante del código fija la lista ni la cantidad de servicios. | Revisión + unit |
| CA-06 | Los totales por fila, por columna y el general coinciden entre pantalla y PDF. | Unit sobre `armar_matriz_reporte` |
| CA-07 | El reporte declara que muestra solo fechas confirmadas, y el estado vacío lo explica. | Widget |
| CA-08 | El PDF emite las ocho páginas de movimientos, sin importar cuál se ve en pantalla. | Unit + revisión visual |
| CA-09 | Se puede imprimir y compartir desde el diálogo del sistema. | Manual en dispositivo |
| CA-10 | Un rango invertido o vacío se rechaza antes de pedir nada al servidor. | Unit |
| CA-11 | Con rol `lectura` el reporte funciona completo: es solo consulta. | Widget |
| CA-12 | Un fallo de red muestra el error con reintento, no una pantalla en blanco. | Unit |

---

## 6. Plan de tareas

- [x] **T-1 — Verificar el toolchain.** Agregar `pdf` y `printing`, compilar en
      Android y generar un PDF de una página. **Antes de cualquier otra cosa**:
      si hay conflicto de Gradle, se fija versión y se replantea, y no conviene
      descubrirlo con el reporte ya escrito.
      → `features/diagnostico/presentation/pantalla_prueba_pdf.dart`.
- [x] **T-2 — Capa de datos.** DTO, datasource, repositorio y contrato, con
      tests de deserialización contra el JSON de §2.
- [x] **T-3 — Dominio.** `armar_matriz_reporte` con el cruce de orden (D-2) y
      los totales (D-5). Es la tarea con más tests y ninguno necesita Flutter.
- [x] **T-4 — Pantalla.** Selectores de rango, agrupación y movimiento; tabla
      desplazable; estado vacío de D-4; manejo de error.
- [x] **T-5 — PDF.** Ocho páginas, encabezado y pie equivalentes a los de la
      web, y el diálogo de compartir/imprimir.
- [ ] **T-6 — Verificación en dispositivo.** Comparar el PDF del móvil contra el
      de la web para el mismo rango: deben coincidir cifra por cifra.
      **Es de Williams y es lo único que puede cerrar CA-09 y la parte visual de
      CA-08.** Hasta entonces el módulo no está terminado, solo escrito.
- [x] **T-7 — Documentación.** README y ADR con la decisión de D-1
      (ADR-0005 D-13, README §10).

**Orden obligatorio:** T-1 → T-2 → T-3. T-4 y T-5 pueden ir en paralelo tras T-3.

### Hallazgo de la primera corrida de tests (2026-08-04)

**Las fuentes base del paquete `pdf` cubren Latin-1 y nada más.** Un carácter
fuera de ese rango no revienta: el paquete lo avisa por consola —donde nadie
mira— y **lo omite del documento**. Así se fue una raya «—» (U+2014) al
encabezado del reporte, que se imprimía con un hueco.

Las tildes y la ñ **sí** entran en Latin-1. Los que no: rayas largas, comillas
tipográficas y el signo menos «−» (U+2212), que es el que la pantalla de humo de
T-1 venía a detectar.

Corregido con el punto medio «·» (U+00B7). Y el test
`generar_pdf_censo_test.dart` ahora revisa el código del generador y falla si
aparece cualquier carácter fuera de Latin-1, con el número de línea. Era la
única forma de que esto no vuelva: un defecto que solo se ve mirando el impreso
con lupa no lo detecta ninguna revisión.

**Y lo más importante de esa corrida:** los cinco tests del generador pasan,
incluido el de tamaño real (31 días × 12 servicios × 8 movimientos). `construir()`
no se cuelga. **El cuelgue reportado por el cliente está en `printing`, en el
dispositivo, no en la generación del documento.**

### Lo que queda abierto al cerrar T-5

| Pendiente | Por qué importa |
|---|---|
| `flutter pub get` con `pdf` y `printing` recién agregados al `pubspec.yaml` | Si Gradle rompe, aplica R-14: se fija la versión del plugin, no se migra el toolchain. |
| `flutter analyze` y `flutter test` | Nada de SPEC-003 ni de SPEC-004 se compiló todavía: se escribió sin SDK a mano. Es la deuda más grande abierta. |
| Borrar `pantalla_prueba_pdf.dart` | Se conserva hasta T-6: su línea de control de caracteres (`á é í ó ú ñ − `) es la forma rápida de verificar las fuentes en el dispositivo. |

---

## 7. Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| R-14 | `printing` o `pdf` no compilan con AGP 8.11.1, como pasó con `permission_handler`. | T-1 lo verifica antes de invertir en el reporte. Política ya fijada: fijar la versión del plugin, no migrar el toolchain. |
| R-15 | El PDF del móvil y el de la web difieren en el orden de columnas: la web usa su constante y el móvil el `indice`. | **Puede pasar y hay que verificarlo (T-6).** Si difieren, la que está mal es la web: su constante es una copia manual del orden. Se reporta como deuda, no se copia el error. |
| R-16 | Un rango largo con detalle diario devuelve muchas filas y la tabla se vuelve pesada. | El agrupado por mes es la salida natural y ya está en el requisito. Si molesta, se limita el rango. |
| R-17 | El operador interpreta que el reporte vacío significa que su carga se perdió. | D-4 lo aborda de frente. Es el riesgo de usabilidad más probable de este trabajo. |

---

## 8. Preguntas cerradas (2026-08-03, con el cliente)

| ID | Pregunta | Respuesta | Consecuencia |
|---|---|---|---|
| P-07 | ¿El reporte debe poder filtrarse por servicio? | **No es requisito.** Que el módulo genere lo mismo que la web es suficiente. | Sin filtro. Queda fuera de alcance de forma explícita para que nadie lo agregue "por si acaso". |
| P-08 | ¿Hace falta el reporte de camas prestadas en el móvil? | **Sí, pero por separado.** Requiere consumir especialidades, que la app todavía no tiene. | Spec propia. **No se implementa nada de camas prestadas en este trabajo**, ni siquiera preparatorio. |

### Lo que P-08 implica para este trabajo

La tentación al construir T-5 va a ser generalizar el generador de PDF "para que
después sirva también a camas prestadas". **No hacerlo.** Ese reporte tiene otra
forma —detalle más totales por especialidad y tipo de ingreso, no una matriz de
períodos por servicios— y otra fuente de datos. Una abstracción diseñada sin
tener el segundo caso delante casi siempre termina estorbando cuando llega.

Lo que sí queda disponible y es legítimo reutilizar después: la dependencia de
PDF ya integrada y verificada (T-1), y el encabezado y pie comunes del
documento.

---

## 9. Preguntas abiertas

Ninguna. La spec está lista para implementar.
