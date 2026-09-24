# app_movil — Servicio de Admisión, Caja Petrolera de Salud

Aplicación móvil institucional del Servicio de Admisión (Regional Santa Cruz).
Módulo inicial: **Censo Diario EST-1**, carga manual de fechas históricas.

Desarrollo: **Willtech**.

## 1. Requisitos

| Requisito | Valor |
|---|---|
| Flutter | canal `stable` |
| Dart SDK | `^3.5.0` |
| **Android mínimo** | **10 (API 29)** |
| iOS mínimo | 12.0 |
| Windows Desktop | target secundario, no bloqueante |

## 2. Puesta en marcha

```powershell
powershell -ExecutionPolicy Bypass -File tool\bootstrap.ps1
```

El script es idempotente y hace, en orden:

1. Genera `android/`, `ios/` y `windows/` sin pisar el scaffold ya escrito.
2. Agrega las dependencias con `flutter pub add`, para que pub resuelva las
   versiones vigentes y el `pubspec.lock` quede como pin real. **Por eso el
   `pubspec.yaml` no trae versiones a mano**: fijarlas sin resolver es cómo se
   llega a un lock que no compila en la máquina del otro desarrollador.
3. Fija `minSdk = 29` (Android 10).
4. Inyecta en `AndroidManifest.xml` los permisos y el bloque `<queries>`.
5. Agrega a `Info.plist` las descripciones de uso de micrófono.
6. Corre `flutter analyze` y `flutter test`.

### Correr la app

```powershell
.\tool\correr.ps1 -Donde hospital     # 192.168.66.225
.\tool\correr.ps1 -Donde oficinas     # 192.168.100.104
.\tool\correr.ps1 -Donde emulador     # 10.0.2.2
.\tool\correr.ps1 -Listar             # ver los destinos sin arrancar
```

**`flutter run` a secas no arranca**, y es deliberado (ADR-0006, D-1). La app no
define una URL por defecto: si falta `API_URL` muestra una pantalla que dice qué
falta y cómo pasarlo. Antes sí había un valor por defecto, y era la IP de la LAN
de una laptop de desarrollo — un build sin `--dart-define` apuntaba a una red
que en el hospital no existe, y fallaba con un error de red genérico.

`tool\correr.ps1` es el **único lugar del repositorio donde vive una dirección
IP**. Cuando el backend suba a la nube se agrega una línea a `$Destinos` y no se
toca una sola línea de Dart. Que la regla se cumpla lo verifica
`dart run tool\verificar_arquitectura.dart`.

El destino activo se muestra al pie de la pantalla de login. Mientras el backend
viva en una laptop que se mueve entre dos redes, "no conecta" tiene dos causas
parecidas y un diagnóstico distinto; verlo en pantalla evita recompilar para
averiguarlo.

### El bloque `<queries>` no es opcional

Desde **Android 11 (API 30)** rige el filtrado de visibilidad de paquetes. Sin
este bloque la app no puede consultar el servicio de reconocimiento de voz, y
`speech_to_text` reporta el dispositivo como **no soportado** aunque sí lo
soporte:

```xml
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

Como el piso es Android 10 pero el parque real de dispositivos será 11, 12, 13
y 14, esto afecta a casi todos los equipos en producción. Es el error más
frecuente al integrar STT en Flutter y se manifiesta como "este dispositivo no
soporta reconocimiento de voz", que manda a diagnosticar por el lado equivocado.

## 3. Estructura

```
lib/
├── main.dart
├── core/
│   ├── error/                           Resultado sellado, Failure, mapeo de errores
│   ├── red/api_client.dart              Dio + interceptor de token
│   └── voz/numero_es_parser.dart        Números en español → int (0–999)
└── features/censo_diario/
    ├── domain/                          Dart puro: sin Flutter, sin plugins
    │   ├── entities/                    CensoServicio, CamaPrestada, Servicio,
    │   │                                ProgresoDia, PropuestaVoz
    │   ├── value_objects/               FechaCenso, CampoCenso
    │   ├── repositories/                Contrato del repositorio
    │   └── usecases/                    InterpretarDictadoCenso
    ├── data/
    │   ├── models/                      DTOs escritos a mano (sin codegen)
    │   ├── datasources/                 Los 8 endpoints del contrato
    │   └── repositories/                Implementación + traducción de errores
    └── presentation/
        └── state/fase_formulario.dart   Máquina de estados del formulario

test/                                    Espeja la estructura de lib/
docs/
├── adr/ADR-0005-modulo-censo-diario-est1.md
└── specs/censo_diario_est1_spec.md
```

Regla de dependencia: `presentation → domain ← data`. La carpeta `domain/` no
importa Flutter ni ningún plugin, así que sus tests corren sin emulador y son
los más baratos del proyecto.

### Dos decisiones de la capa `data` que conviene conocer

**Los DTOs se escriben a mano.** Son seis modelos chicos. `freezed` +
`json_serializable` traerían `build_runner` y un paso de codegen en cada cambio
para ahorrar unas líneas de `fromJson`. Con este volumen la maquinaria cuesta
más que el código que evita. Si los modelos crecen, se reevalúa.

**La convención de nombres del API no es uniforme.** Los catálogos
(`/servicios`, `/mapeo/*`, `/camas`) devuelven filas crudas de Postgres en
`snake_case`; `/carga-manual/estado` e `/historico` devuelven `camelCase` ya
presentado. No hay regla global: cada DTO declara la suya y los tests la fijan
contra los ejemplos de la guía de integración. Asumir una convención única es
cómo se llega a un campo en `null` que nadie nota hasta producción.

## 4. Qué ya está implementado y probado

| Pieza | Qué resuelve |
|---|---|
| `NumeroEsParser` | Dictado de números en español, con y sin tildes, en palabra o en dígito. Rechaza construcciones inválidas en vez de adivinar. |
| `CensoServicio` | Fórmulas del EST-1: saldo de 24 h, dotación, cuadre contra capacidad, duplicados de camas prestadas. |
| `FechaCenso` | Regla de fecha en hora de Bolivia y serialización `YYYY-MM-DD` sin offset. |
| `InterpretarDictadoCenso` | Transcripción → propuesta de campos, con diff y confianza. |
| `FaseFormulario` | Máquina de estados y el invariante de que la voz nunca llega sola a la persistencia. |
| `ProgresoDia` | Cuándo se habilita "Confirmar día". Nunca con lista vacía. |
| `MapeadorDeFallas` | Traduce los errores de NestJS: `message` string es regla de negocio, array es validación de campos. |
| `CensoDiarioRemoteDataSource` | Los 8 endpoints del contrato, con el formato de fecha correcto. |
| `CensoDiarioRepositoryImpl` | Cruza servicios con su mapeo, resuelve el total del día anterior y traduce toda excepción a `Resultado`. |
| `ArmarMatrizReporte` | Filas planas del reporte → matriz período × servicio, con el orden institucional y los totales. La misma aritmética alimenta la pantalla y el PDF. |
| `GeneradorPdfCenso` | Las ocho páginas del reporte, con el encabezado y el pie del impreso de la web. |

```powershell
flutter test
```

### El test que más importa

`test/features/censo_diario/presentation/fase_formulario_test.dart` verifica,
enumerando **todas** las transiciones, que ninguna fase de voz alcanza
`guardando`. Un dato dictado solo llega al servidor cruzando dos gestos
deliberados del operador: confirmar la propuesta y después guardar.

Si alguien agrega una arista que rompa eso, el test falla — no depende de que
un revisor lo note.

## 5. Documentación

| Documento | Contenido |
|---|---|
| [`docs/adr/ADR-0005`](docs/adr/ADR-0005-modulo-censo-diario-est1.md) | Las 10 decisiones de arquitectura del módulo, con sus alternativas descartadas |
| [`docs/specs/censo_diario_est1_spec.md`](docs/specs/censo_diario_est1_spec.md) | SPEC-002 — dominio, contrato, validaciones, componentes, criterios de aceptación |
| [`docs/specs/lectura_edicion_carga_manual_spec.md`](docs/specs/lectura_edicion_carga_manual_spec.md) | SPEC-003 — precarga del formulario desde el staging del servidor |
| [`docs/specs/reporte_censo_mensual_spec.md`](docs/specs/reporte_censo_mensual_spec.md) | SPEC-004 — reporte de movimientos por servicio, con impresión y PDF |
| [`docs/solicitudes/`](docs/solicitudes/) | Pedidos formales al equipo de backend |

El backend que consume esta app está en `../software-migracion`. Su guía de
integración es `../software-migracion/docs/api-carga-manual-app-movil.md`.

## 7. Problemas conocidos

### ~~El formulario no se descarta al navegar entre servicios~~ — resuelto

**Resuelto el 2026-08-03 (SPEC-003).** El backend expuso
`GET /censo-diario/carga-manual`, así que el formulario se precarga desde el
servidor y el `keepAlive` se retiró: mantener ambos habría creado dos fuentes de
verdad, y un formulario retenido en memoria podía mostrar valores más viejos que
los del servidor ganando por estar primero.

Lo que sigue describe el problema original y por qué la corrección de emergencia
ya no aplica.

<details>
<summary>Historia del bug</summary>

`censoFormProvider` es `autoDispose`, así que al cambiar de servicio con las
flechas el formulario anterior deja de ser observado y Riverpod lo destruye. Al
volver, se reconstruía desde cero y **los campos aparecían vacíos aunque el
servidor tuviera la carga** — la lista de progreso marcaba el servicio como
cargado y el formulario mostraba ceros.

La causa de fondo no es el `autoDispose`: es que el API **no expone ningún
endpoint para leer el staging** (§8 y `docs/solicitudes/`). Una vez perdido el
estado en memoria, no hay de dónde recuperarlo. Mientras ese endpoint no
exista, lo que la app cargó en la sesión es la única copia legible.

`CensoFormNotifier` llama a `ref.keepAlive()` en cuanto el censo deja de estar
vacío. Un formulario abierto y no tocado se sigue descartando, así que la
memoria crece con los servicios **usados**, no con los visitados.

Cuando exista el endpoint de lectura, este `keepAlive` deja de ser necesario y
conviene quitarlo: el estado se recuperaría del servidor, que es más confiable
que la memoria del proceso.

</details>

### Descartar cambios que no se pueden guardar ahora sí pierde el trabajo

Consecuencia directa de haber retirado el `keepAlive`. Un servicio a medio
transcribir que todavía **no se puede guardar** —censo que no cuadra, POST
fallido, rol `lectura`— antes sobrevivía en memoria aunque el diálogo dijera lo
contrario. Ahora el diálogo dice la verdad: si el operador elige "Descartar y
seguir", se pierde de verdad.

Mitigado invirtiendo el énfasis del diálogo: **"Quedarme acá" es la acción
primaria** y "Descartar y seguir" quedó discreta. El caso frecuente —censo que
cuadra— no se ve afectado, porque las flechas guardan solas.

Si en uso real resulta que los operadores pierden trabajo por esta vía, la
solución no es volver al `keepAlive` sino permitir guardar borradores que no
cuadren, y eso requiere un cambio de contrato con el backend.

### `permission_handler` está fijado en 12.x a propósito

**Síntoma.** `flutter run` falla al compilar el script de Gradle del plugin:

```
permission_handler_android-14.0.0/android/build.gradle.kts:68:1: Unresolved reference
:69:5: Unresolved reference: compilerOptions
:70:9: Unresolved reference: jvmTarget
Line 40: java.srcDirs("src/main/kotlin")
         ^ 'srcDirs(vararg Any): Any' is deprecated. Use `directories` mutable set instead
```

**Causa.** No es un error del proyecto. `permission_handler` 13.0.0 arrastra
`permission_handler_android` 14.0.0, cuyo `build.gradle.kts` ya está migrado al
**Android Gradle Plugin 9 / Gradle 9**. Este proyecto corre lo que genera el
Flutter actual:

| Componente | Versión del proyecto |
|---|---|
| Android Gradle Plugin | 8.11.1 |
| Gradle wrapper | 8.14 |
| Kotlin Gradle Plugin | 2.2.20 |

Las APIs que usa el plugin (`kotlin { compilerOptions { jvmTarget } }`,
`directories` en lugar de `srcDirs`) no existen o están marcadas como
deprecación de nivel error en AGP 8. El script del plugin ni siquiera llega a
ejecutarse: falla al compilarse.

Es un desfase de calendario, no un bug: el ecosistema Flutter está en plena
migración a AGP 9 y los plugins se están adelantando al toolchain que genera el
canal estable.

**Solución adoptada.** Pin en `permission_handler: ^12.0.3`, cuya línea depende
de `permission_handler_android` 13.x y compila con AGP 8. Un cambio de una
línea, sin perder ninguna funcionalidad.

**No hacer** `flutter pub add permission_handler` a secas ni
`flutter pub upgrade --major-versions`: pub resolvería 13.x y volvería a romper
el build.

**Alternativas evaluadas y descartadas:**

| Alternativa | Por qué no |
|---|---|
| Subir el proyecto a AGP 9 + Gradle 9 | AGP 9 trae muchos cambios incompatibles y el resto de plugins (`speech_to_text`, `flutter_secure_storage`) todavía no migraron. Es un sumidero de tiempo a mitad de un sprint de 3 semanas. |
| Quitar `permission_handler` y usar solo `speech_to_text` | `speech_to_text.initialize()` pide el permiso de micrófono por su cuenta, así que técnicamente alcanza. Pero se pierde `openAppSettings()`, que SPEC-002 §6.5 necesita para el caso "denegado permanentemente". Queda como plan B si el pin se vuelve insostenible. |
| `android.newDsl=false` en `gradle.properties` | Es la palanca inversa: sirve para proyectos ya en AGP 9 que quieren diferir el DSL nuevo. No aplica acá. |

**Cuándo revisar este pin.** Cuando el proyecto migre a AGP 9, o cuando
`speech_to_text` y `flutter_secure_storage` publiquen versiones para AGP 9 y
convenga mover todo el toolchain de una vez. No antes: migrar por un solo
plugin no compensa.

## 9. Spike R-05 — medir la precisión del dictado

**Menú de usuario → "Probar dictado".** Requiere dispositivo físico: el
emulador no expone micrófono real.

La pantalla muestra el estado del motor, la locale seleccionada y todas las
locales españolas instaladas; propone once frases de prueba y, por cada una,
registra qué entendió el motor, con cuánta confianza y qué extrajo el
intérprete campo por campo. Al final, "Copiar informe" deja un texto listo para
pegar en el ADR o pasarle al cliente.

**La métrica que decide es "frases enteras", no "campos sueltos."** Que 8 de 9
campos caigan bien no le sirve al operador: igual tiene que revisar los 9. Un
80% por campo puede convivir con un 20% por frase, y son situaciones distintas.

**Se cuentan aparte los campos inventados** — los que el intérprete extrajo sin
que nadie los dictara. Un falso positivo es peor que un campo faltante: el
operador ve un número plausible en un campo que nunca tocó, y no tiene motivo
para desconfiar de él.

La batería va de lo simple a lo exigente a propósito. Si la precisión se
derrumba, importa saber **dónde**: un motor que resuelve "cuatro" pero falla
"treinta y cuatro" pide una decisión de producto distinta a uno que falla todo.

Antes de salir a medir conviene correr `flutter test`: hay un test que verifica
que cada frase de la batería, transcrita perfecta, produce el resultado
esperado. Sirve para no medir con una regla torcida.

### Por qué la escucha se corta sola

Hay cuatro criterios de cierre, y el que más se nota **no es nuestro**:

| Criterio | Quién lo controla |
|---|---|
| Resultado final del reconocedor | El motor, camino normal |
| `pauseFor` (8 s de silencio) | Nosotros — *pero ver abajo* |
| `listenFor` (30 s de sesión) | Nosotros, tope duro real |
| `cancelOnError` | Nosotros, ante cualquier error |
| **Silencio detectado por Android** | **El sistema, y suele ganar** |

El `SpeechRecognizer` nativo tiene su propia detección de silencio, del orden
de uno o dos segundos, y el motor de Google habitualmente ignora los extras que
piden alargarla. Por eso `pauseFor: 8s` es una intención, no una garantía: si
el operador hace una pausa para pensar a mitad de la frase, Android cierra
antes de que nuestros 8 segundos entren en juego.

**Consecuencia de diseño:** el dictado sirve para enunciados cortos y seguidos,
no para frases pensadas en voz alta. La batería de prueba está armada así a
propósito. Si la medición muestra que los operadores pausan naturalmente, la
respuesta no es subir `pauseFor` —no serviría— sino acotar el dictado a un
campo por vez.

Los valores son configurables por llamada (`silencioMaximo`, `duracionMaxima`)
para poder experimentar durante el spike.

### Retroalimentación durante el dictado

`PanelEscuchaActiva` reemplaza la barra inferior mientras el motor escucha.
Muestra, en este orden de prominencia:

1. **La transcripción parcial en vivo.** Es lo que responde de una sola vez las
   tres preguntas del operador: ¿arrancó?, ¿me escucha?, ¿entendió bien?
2. **El halo de amplitud** alrededor del micrófono. Cubre el hueco anterior:
   cuando el motor todavía no entendió nada, un silencio de reconocimiento es
   indistinguible de un micrófono roto.
3. **El anillo de tiempo restante**, que se vacía sobre el ícono. Los segundos
   en números aparecen solo en los últimos 10.

**Por qué el contador no es protagonista.** El enunciado típico dura dos
segundos contra un tope de 45. Un cronómetro grande pondría presión sobre algo
que nunca se acerca al límite, y apuntaría al criterio equivocado: lo que suele
cerrar la sesión es el silencio detectado por Android, no el tope.

### "Listo" conserva lo dictado

Tocar el botón significa *terminé de hablar*, no *descartá lo que dije*. Antes
`detener()` tiraba la sesión entera y se perdía un enunciado completo por
adelantarse medio segundo al motor.

El orden importa: `stop()` suele provocar que el reconocedor entregue su
resultado final poco después, y ese es mejor que cualquier parcial. Se le da un
margen de 400 ms y solo si no llega se usa el último parcial retenido.

`cancelar()` sigue descartando: es lo que corresponde cuando el operador se
arrepiente, y por eso son dos botones distintos y no uno.

## 6. Pendiente del Sprint 1

- Pipeline de CI y build iOS por Codemagic (ADR-0004). La inscripción al Apple
  Developer Program tiene demora externa: conviene tramitarla ya.

## 8. Autenticación

Contrato verificado contra `apps/api/src/modulos/auth/`:

| Endpoint | Cuerpo | Respuesta |
|---|---|---|
| `POST /auth/login` | `{ email, password }` | `{ accessToken, refreshToken, usuario: { id, nombreCompleto, email, rol } }` |
| `POST /auth/refresh` | `{ refreshToken }` — **en el cuerpo**, no en el header | `{ accessToken, refreshToken }`, **sin** usuario |
| `POST /auth/logout` | — (bearer) | — |

Tres detalles del contrato que condicionan la implementación:

1. **Renovar rota el refresh token.** El servidor guarda el hash del nuevo y
   descarta el anterior. Si no se persiste el rotado, la siguiente renovación
   falla con "Sesión inválida" y el operador queda afuera sin motivo aparente.
2. **El refresh no devuelve el usuario.** La sesión conserva el que trajo el
   login; de ahí sale el rol que decide si se habilita la escritura.
3. **El refresh token viaja en el cuerpo.** La estrategia del backend lo extrae
   con `ExtractJwt.fromBodyField('refreshToken')`, no del header.

El `access token` dura un día y el `refresh` siete. `InterceptorSesion` renueva
ante un 401 y reintenta la petición original **una sola vez**; las rutas de
`/auth` quedan exentas para no entrar en bucle. La renovación es de un solo
vuelo: si varias peticiones fallan a la vez, se dispara una y las demás esperan
su resultado.

Los tokens se guardan en `flutter_secure_storage` (Keystore en Android,
Keychain en iOS). No en `SharedPreferences`: en un dispositivo con root serían
legibles en texto plano, y dan acceso al censo de un hospital.

### Cómo probar contra el backend

Ver §2, "Correr la app". Los destinos están en `tool\correr.ps1`.

Si todas las llamadas fallan por red, mirá primero el pie del login: dice contra
qué URL está corriendo esta compilación. En el emulador tiene que ser
`10.0.2.2` —el host de la máquina visto desde adentro—; `localhost` ahí apunta
al propio emulador y no llega a la API.

## 10. Reporte de censo

Consulta de movimientos por servicio en un rango de fechas, agrupables por día
o por mes, con impresión y descarga en PDF. Se entra desde la pantalla inicial,
en **Reporte de censo**. Es solo lectura: el rol `lectura` lo usa completo,
incluido el PDF.

```powershell
flutter pub get   # trae `pdf` y `printing`, agregados con SPEC-004
```

### Lo que hay que saber antes de comparar contra la web

**Solo muestra fechas confirmadas.** El endpoint lee `public.censo`, que es el
censo oficial. Un día cargado y sin confirmar no aparece — y como en esta app se
carga y se reporta desde el mismo lugar, es la confusión más probable del
módulo. Por eso la pantalla y el PDF lo declaran siempre, no solo cuando el
resultado viene vacío.

**El orden de las columnas puede no coincidir con el de la web.** Acá sale del
catálogo (`Servicio.indice`) cruzado con el mapeo a vaciado; la web usa su
constante `SERVICIOS_CENSO`, una lista fija de doce nombres copiada a mano. Si
difieren, la desactualizada es la constante: un servicio nuevo no aparecería en
la web y uno renombrado sería una columna de ceros, en silencio.

Un servicio que llega en el reporte pero no tiene mapeo **no se descarta**: se
muestra al final. Ocultarlo sería perder filas por un problema de catálogo.

### Verificación pendiente en dispositivo (T-6 de SPEC-004)

Generar el mismo rango en la web y en el móvil y compararlos **cifra por
cifra**, no de vistazo. Lo que hay que mirar:

- que los totales por fila, por columna y el general coincidan;
- que el orden de las columnas sea el mismo (si no, ver arriba);
- que las tildes, la `ñ` y el signo menos `−` se impriman y no salgan como
  cuadros — las fuentes base del paquete `pdf` cubren Latin-1 y `−` (U+2212) no
  está ahí;
- que **imprimir** abra el diálogo del sistema y **compartir** la hoja de
  compartir de Android.

Mientras eso no esté hecho, el módulo no está cerrado.
