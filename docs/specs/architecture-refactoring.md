# SPEC-005 — Refactorización arquitectónica: configuración, red e inyección de dependencias

| Campo | Valor |
|---|---|
| **ID** | SPEC-005 |
| **Título** | Desacoplamiento de configuración, capa de red y composición de dependencias |
| **Estado** | Borrador — pendiente de aprobación de Williams |
| **Autor** | Willtech — Arquitectura de Software |
| **Fecha** | 2026-08-04 |
| **Depende de** | Cierre del bug P0 del PDF; árbol en verde (`flutter analyze` + `flutter test`) |
| **ADR relacionados** | **ADR-0006** (decisiones), ADR-0005 (módulo censo diario) |

---

## 1. Contexto y alcance

La URL base del API está declarada dentro de un archivo de la capa de
presentación (`features/auth/presentation/auth_providers.dart`). El síntoma es
operativo; la causa es que **nunca se decidió dónde se componen las
dependencias**, y por defecto se compusieron donde hacían falta: en los
providers de cada feature.

Esta spec ejecuta las decisiones de **ADR-0006**. El razonamiento de cada una
está allí; acá está el plan.

### Gestión de estado: aclaración previa

El encargo describía `provider ^2.6.1` con `MultiProvider` y `ProxyProvider`. El
`pubspec.yaml` tiene **`flutter_riverpod: ^2.6.1`**, y en `lib/` hay 0 usos de
`ChangeNotifier`/`MultiProvider`/`ProxyProvider` contra 48 de Riverpod.
Confirmado con Williams el 2026-08-04: **se mantiene Riverpod**. La estrategia de
DI de §4 es el equivalente exacto de lo pedido, con `ProviderScope` +
`overrides` en lugar de `MultiProvider` + `ProxyProvider`.

### Dentro del alcance

- Extracción de la configuración a un contrato en `core/config/`, inyectado.
- Raíz de composición única en `main.dart` / `app/bootstrap.dart`.
- Traslado del cliente HTTP y del interceptor de `features/auth/` a `core/red/`.
- Contrato abstracto para `AuthRepository`, al nivel de las otras dos features.
- Corte de los ciclos de dependencia entre features.
- Verificador automático de límites de capa.

### Fuera del alcance

| Fuera | Razón |
|---|---|
| **Migrar a `package:provider`** | Reescribe diez archivos de estado y pierde `autoDispose` y `family`, de los que depende el formulario del censo (SPEC-003 D-3/D-12). Resuelve el mismo problema con más riesgo. ADR-0006, "Lo que este ADR no decide". |
| **Casos de uso para operaciones de paso directo** | Un caso de uso que solo reenvía al repositorio agrega un archivo y un test sin encapsular ninguna regla. ADR-0006 D-6. |
| **Reescribir la lógica de negocio** | Este refactor mueve y desacopla; no cambia una sola fórmula del EST-1. Si un test de dominio se rompe, el refactor está mal. |
| **Cambiar el contrato del backend** | Ninguna decisión de acá requiere nada de `software-migracion`. |
| **Modularización en paquetes Dart separados** | Con 1-2 desarrolladores, un `melos` multi-paquete es sobrecarga de tooling. El verificador de §5 da la misma garantía de límites a costo casi cero. Reevaluable si el equipo crece. |
| **Introducir `get_it` o similar** | ADR-0006, alternativas descartadas. |

**Criterio que ordena esta tabla:** el objetivo es que el próximo parámetro de
configuración no vuelva a terminar en un archivo de presentación. Todo lo que no
contribuya a eso es otro trabajo.

---

## 2. Auditoría del estado actual

Relevada el 2026-08-04 sobre `lib/` (57 archivos Dart, 4 features).

| # | Hallazgo | Evidencia | Principio violado |
|---|---|---|---|
| H-1 | URL base y valor por defecto en la capa de presentación | `auth_providers.dart:16-21` | SRP, DIP |
| H-2 | **Tres URLs distintas en el repositorio, ninguna coincide** | Código `…:3001` (IP de LAN), comentario `10.0.2.2:3001`, README `10.0.2.2:3000` | — |
| H-3 | `AppConfig` y `dioProvider` consumidos por otras dos features desde `auth/presentation/` | `censo_providers.dart`, `reporteria_providers.dart` | Bajo acoplamiento |
| H-4 | `auth` no tiene contrato en `domain/`: `AuthRepository` es concreto en `data/` | `features/auth/` sin `domain/repositories/` | DIP |
| H-5 | `AuthRepository` acumula 4 responsabilidades: red, persistencia, estado en memoria, concurrencia | `auth_repository.dart:28,36` | SRP |
| H-6 | No hay raíz de composición: `ProviderScope` sin `overrides` | `main.dart:9` | — |
| H-7 | Presentación importa `data/` en las 3 features con red | los tres `*_providers.dart` | Clean Architecture |
| H-8 | 11 aristas cruzadas entre features hacia capas no-dominio, con **4 ciclos** | ver §2.1 | Bajo acoplamiento |
| H-9 | Timeouts de red hardcodeados | `core/red/api_client.dart:17-19` | SRP (menor) |
| H-10 | **`core/` importa una entidad de `features/auth/`** | `core/almacenamiento/almacen_sesion.dart:3` | Regla de dependencia |

**H-10 lo encontró la herramienta de T-1, no la auditoría manual.** `AlmacenSesion`
es un contrato del núcleo cuya firma está escrita en términos de `Sesion`, una
entidad que vive dentro de la feature de autenticación. El núcleo depende de una
feature, que es la única dirección que la regla no admite. Se resuelve en T-4
moviendo `Sesion` a `core/sesion/` —es identidad, no censo— o parametrizando el
contrato. Es exactamente el tipo de defecto que una lectura a ojo no encuentra y
un script sí: la primera tarea del plan ya se pagó sola.

### 2.1 Ciclos de dependencia

```
censo_diario  ⇄  reporteria
censo_diario  ⇄  diagnostico
auth  →  diagnostico  →  censo_diario  →  auth
auth  →  diagnostico  →  censo_diario  →  reporteria  →  auth
```

Mientras existan, ninguna feature se compila ni se prueba aislada.

### 2.3 Marcador del refactor

`dart run tool/verificar_arquitectura.dart`, 68 archivos:

| Regla | Criterio | T-1 (base) | T-2 | T-3 | T-4 | T-5 | T-6 |
|---|---|---|---|---|---|---|---|
| `CONFIG-CENTRAL` | CA-01 | 1 | **0** | 0 | 0 | 0 | 0 |
| `SIN-URLS` | CA-02 | 1 | **0** | 0 | 0 | 0 | 0 |
| `PRES-NO-DATA` | CA-04 | 6 | 6 | 6 | 8 ↑ | **0** | 0 |
| `CORE-AISLADO` | CA-05 | 1 | 1 | 1 | **0** | 0 | 0 |
| `DOMINIO-PURO` | CA-07 | 0 | 0 | 0 | 0 | 0 | 0 |
| `FEATURE-A-DOMINIO` | CA-06 | 11 | 11 | **9** | 9 | 9 | **0** |
| `SIN-CICLOS` | CA-06 | 4 | 4 | **3** | 3 | 3 | **0** |
| | **Total** | **24** | **22** | **19** | **20** | **12** | **0** |

Grafo de features resultante, acíclico y solo hacia `domain/`:

```
diagnostico  →  censo_diario/domain      (vocabulario del censo para medir el dictado)
reporteria   →  censo_diario/domain      (FechaCenso: la regla horaria de Bolivia)
```

**El total subió en T-4 y no es un retroceso.** `PRES-NO-DATA` cuenta imports,
no violaciones distintas: `auth_providers.dart` construía dos clases de `data/`
y ahora construye cuatro, porque el repositorio que hacía cuatro cosas se
separó en cuatro piezas. La infracción de fondo es la misma —la presentación
sigue construyendo infraestructura— y es exactamente lo que elimina T-5, de una
vez y para las tres features. Se deja el número a la vista en lugar de
maquillarlo: un marcador que solo baja deja de medir.

Este número es el marcador del refactor: cada tarea siguiente tiene que bajarlo,
y T-7 lo deja en cero.

### 2.2 Lo que está sano y no se toca

- **`domain/` es puro en las 4 features**: 0 imports de Flutter o plugins. Es la
  razón por la que este refactor es acotado y no una reescritura.
- `Resultado<T>` y `Failure` sellados en `core/error/`.
- `censo_diario` y `reporteria` ya declaran `abstract interface class` para sus
  repositorios. El patrón existe; falta aplicarlo parejo.
- `AlmacenSesion` y `ServicioDictado` ya son contratos con implementación
  inyectable.

**Diagnóstico honesto:** la arquitectura está bien planteada y mal cerrada. El
problema no es el diseño, es que la composición quedó sin dueño.

---

## 3. Arquitectura objetivo

```
lib/
├── main.dart                        Solo: bootstrap() y runApp()
├── app/
│   ├── bootstrap.dart               ← NUEVO. Raíz de composición
│   ├── rutas.dart                   ← NUEVO. go_router; corta ciclos de navegación
│   └── tema.dart
├── core/
│   ├── config/                      ← NUEVO
│   │   ├── configuracion_app.dart   abstract interface class
│   │   ├── configuracion_dart_define.dart
│   │   └── config_providers.dart    configuracionProvider (lanza sin override)
│   ├── red/
│   │   ├── api_client.dart          toma timeouts de ConfiguracionApp
│   │   ├── interceptor_sesion.dart  ← MOVIDO desde auth
│   │   ├── proveedor_de_sesion.dart ← NUEVO. Contrato mínimo del interceptor
│   │   └── red_providers.dart       ← NUEVO. dioProvider vive acá
│   ├── error/                       (sin cambios)
│   ├── sesion/
│   │   └── permisos_providers.dart  ← NUEVO. puedeEscribirProvider transversal
│   ├── almacenamiento/ · formato/ · voz/
└── features/
    └── <feature>/
        ├── domain/        entities · value_objects · repositories · usecases
        ├── data/          models · datasources · repositories
        └── presentation/  providers · pages · widgets · state
```

**Regla de dependencia, verificada por herramienta (§5):**

```
presentation → domain ← data
core ← features          (core NUNCA importa features)
feature → feature        solo hacia domain/, y sin ciclos
```

### 3.1 Cambios por feature

| Feature | Cambio |
|---|---|
| `auth` | Gana `domain/repositories/auth_repository.dart` (interfaz). `AuthRepository` → `data/repositories/auth_repository_impl.dart`. Entrega `dioProvider` e `InterceptorSesion` a `core/`. Implementa `ProveedorDeSesion`. |
| `censo_diario` | Deja de importar `auth/presentation/`. Toma `dioProvider` de `core/red/` y `puedeEscribirProvider` de `core/sesion/`. Deja de importar páginas de otras features. |
| `reporteria` | Igual. Conserva la dependencia hacia `censo_diario/domain/value_objects/fecha_censo.dart` (unidireccional, sin ciclo). |
| `diagnostico` | Conserva su dependencia hacia `censo_diario/domain/`. Deja de ser destino de imports directos: se navega por ruta. |

---

## 4. Estrategia de inyección de dependencias

Equivalencia con lo pedido en el encargo:

| Encargo (`package:provider`) | Equivalente aplicado (Riverpod) |
|---|---|
| `MultiProvider` en la raíz | `ProviderScope(overrides: [...])` en `bootstrap()` |
| `Provider<T>` de infraestructura | `Provider<T>` declarado en `core/`, satisfecho por override |
| `ProxyProvider<A, B>` | `Provider<B>` que hace `ref.watch(aProvider)` |
| `ChangeNotifierProvider` | `NotifierProvider` / `AsyncNotifierProvider` |

### 4.1 El contrato de configuración

```dart
// core/config/configuracion_app.dart
abstract interface class ConfiguracionApp {
  String get urlBaseApi;

  /// Nombre legible del destino, para mostrar en pantalla y en diagnósticos.
  /// El código no conoce "hospital" ni "oficinas": recibe una etiqueta.
  String get nombreDestino;

  Duration get timeoutConexion;
  Duration get timeoutRespuesta;
}
```

```dart
// core/config/config_providers.dart
final configuracionProvider = Provider<ConfiguracionApp>((ref) {
  throw UnimplementedError(
    'ConfiguracionApp debe inyectarse en el ProviderScope de bootstrap()',
  );
});
```

**Lanza a propósito.** Un valor por defecto es exactamente cómo
`192.168.66.225` llegó a ser la configuración efectiva: compilaba, arrancaba y
fallaba tarde. Acá un olvido revienta en la primera línea de `main`, en
desarrollo, no en el turno de noche del hospital (ADR-0006, D-1).

### 4.2 La raíz de composición

```dart
// app/bootstrap.dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Única lectura de --dart-define en toda la aplicación.
  final configuracion = ConfiguracionDartDefine.desdeEntorno();

  runApp(
    ProviderScope(
      overrides: [
        configuracionProvider.overrideWithValue(configuracion),
      ],
      child: const AppMovil(),
    ),
  );
}
```

```dart
// main.dart  — queda en dos líneas
void main() => bootstrap();
```

### 4.3 Encadenado de dependencias (el `ProxyProvider` de Riverpod)

```dart
// core/red/red_providers.dart
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(configuracionProvider);   // ← el "proxy"
  final sesion = ref.watch(proveedorDeSesionProvider);

  return ApiClient.crear(config)
    ..interceptors.add(InterceptorSesion(proveedor: sesion));
});
```

`core/red/` no conoce `features/auth/`: depende de `ProveedorDeSesion`, un
contrato declarado en `core/` que `auth` satisface. La dependencia queda
invertida (ADR-0006, D-3).

### 4.4 Qué gana la prueba

```dart
ProviderScope(
  overrides: [
    configuracionProvider.overrideWithValue(ConfiguracionDePrueba()),
    censoRepositoryProvider.overrideWithValue(RepositorioFalso()),
  ],
  child: const ProgresoDiaPage(fecha: ...),
);
```

Hoy esto no se puede hacer sin levantar un servidor: el widget termina
construyendo su propio `Dio` contra la URL compilada.

---

## 5. Criterios de aceptación

| # | Criterio | Verificación |
|---|---|---|
| CA-01 | `String.fromEnvironment` no aparece fuera de `core/config/` | Script |
| CA-02 | Ninguna URL literal en `lib/`, salvo en `core/config/` | Script |
| CA-03 | `configuracionProvider` sin override lanza `UnimplementedError` | Unit |
| CA-04 | Ningún archivo de `presentation/` importa `data/` | Script |
| CA-05 | Ningún archivo de `core/` importa `features/` | Script |
| CA-06 | No hay ciclos de dependencia entre features | Script |
| CA-07 | `domain/` no importa Flutter ni plugins (se conserva) | Script |
| CA-08 | Los providers de repositorio declaran el tipo **interfaz** | Revisión + compilador |
| CA-09 | Un `ProviderScope` con overrides permite montar cualquier página sin red | Widget |
| CA-10 | `flutter analyze` sin advertencias y `flutter test` en verde | CI |
| CA-11 | **Ningún test de dominio existente cambia de resultado** | `flutter test` |
| CA-12 | La app compila y arranca contra el backend real, con login y carga funcionando | Manual en dispositivo |

**CA-11 es el criterio que define si el refactor está bien hecho.** Este trabajo
mueve y desacopla; no cambia una fórmula del EST-1. Si un test de dominio se
rompe, se rompió el refactor, no el test.

### 5.1 El verificador de límites

CA-01, CA-02 y CA-04 a CA-07 se comprueban con una sola herramienta:
`tool/verificar_arquitectura.dart`, que recorre los imports de `lib/` y falla con
código distinto de cero. Corre junto a `flutter analyze` en `bootstrap.ps1`.

Sin esto, las reglas duran hasta el primer apuro y volvemos a este documento en
seis meses.

---

## 6. Plan de migración incremental

**Cada tarea deja la app compilando, andando y con los tests en verde.** No hay
rama larga: si hay que parar, se para entre tareas.

- [ ] **T-0 — Dejar el árbol en verde. Innegociable.**
      `flutter pub get`, `flutter analyze`, `flutter test`. Unos 30 archivos de
      SPEC-003 y SPEC-004 nunca pasaron por el SDK. Refactorizar sobre código no
      compilado hace imposible distinguir un error viejo de uno nuevo. **Además:
      el bug P0 del PDF se cierra antes de empezar** (R-18).

- [x] **T-1 — Verificador de arquitectura.** `tool/verificar_arquitectura.dart`
      con las siete reglas de §5, corriendo y **fallando** contra el estado
      actual: 24 infracciones (§2.3). Encontró H-10, que la auditoría manual no
      había visto. No toca código de producción.
      *Se encadena a `bootstrap.ps1` en T-7, cuando ya pase: hacerlo bloqueante
      ahora rompería el arranque del proyecto a días de la entrega.*

- [x] **T-2 — Configuración.** `core/config/` completo, `bootstrap()`, override
      en `ProviderScope`. `AppConfig` eliminado de `auth_providers.dart`.
      `tool/correr.ps1` con las tres ubicaciones de P-09 —único lugar del
      repositorio donde vive una IP—. La URL activa se muestra en el login.
      README §2 actualizado. **Cierra H-1, H-2, CA-01 a CA-03.**
      *Verificador: 24 → 22. `CONFIG-CENTRAL` y `SIN-URLS` pasan.*

- [x] **T-3 — Red al núcleo.** `dioProvider` y el contrato `ProveedorDeSesion`
      en `core/red/`; `InterceptorSesion` pasa a depender del contrato en lugar
      de tres callbacks sueltos. `auth` lo satisface con
      `ProveedorDeSesionAuth`, cableado en `bootstrap()`.
      `censo_providers` y `reporteria_providers` dejan de importar
      `auth/presentation/`. **Cierra H-3, H-9.**
      *Verificador: 22 → 19. `FEATURE-A-DOMINIO` 11 → 9, `SIN-CICLOS` 4 → 3.*

      **Corrección a esta spec:** T-3 no cierra CA-05, como decía antes. La
      única infracción de `CORE-AISLADO` es H-10 —`core/almacenamiento` importa
      la entidad `Sesion` de `auth`— y se resuelve en T-4. La red ya no depende
      de ninguna feature, que era lo que esta tarea tenía que lograr.

- [x] **T-4 — Contrato de `auth`.** `AuthRepository` es interfaz en
      `domain/repositories/` y `AuthRepositoryImpl` vive en `data/repositories/`.
      El `Sesion?` mutable salió a `SesionEnMemoria` y el single-flight del
      refresco a `ProveedorDeSesionAuth`, que es quien promete esa garantía en
      su contrato (H-5). **Cierra H-4, H-5, H-10, CA-05, CA-08.**
      *Verificador: `CORE-AISLADO` 1 → 0.*

      **H-10 se resolvió al revés de lo previsto.** La spec decía mover `Sesion`
      a `core/sesion/`. Se verificó que `AlmacenSesion` no lo usa nadie fuera de
      `auth`, así que se movió el almacén a la feature en vez de subir la
      entidad al núcleo: es un archivo en lugar de tres, y guardar la sesión es
      asunto de autenticación. Poner en `core/` lo que sirve a una sola feature
      es cómo un núcleo se convierte en un cajón.

- [x] **T-5 — Providers de repositorio.** Los tres `*_providers.dart` dejan de
      construir datasources y repositorios: declaran el contrato y
      `bootstrap()` lo satisface. Desaparecen `datasourceProvider`,
      `reporteriaDatasourceProvider`, `almacenSesionProvider`, `authDioProvider`
      y `sesionEnMemoriaProvider`: eran detalle de construcción, no puntos de
      extensión. **Cierra H-6, H-7, CA-04, CA-09.**
      *Verificador: 20 → 12. `PRES-NO-DATA` 8 → **0**.*

      `bootstrap.dart` es ahora el único archivo de `lib/` que importa `data/`
      de las tres features, y es correcto que así sea: componer es justamente
      saber qué clase concreta cada abstracción.

- [x] **T-6 — Rutas y corte de ciclos.** Tabla de rutas en `app/rutas.dart`,
      menú de cuenta a `app/widgets/`, `puedeEscribirProvider` a `core/sesion/`,
      `servicioDictadoProvider` a `core/voz/` y `ordenServiciosProvider` como
      contrato. **Cierra H-8, CA-06.**
      *Verificador: 12 → **0**. Las siete reglas pasan.*

      **Se usó `onGenerateRoute` y no `go_router`.** Solo cuatro navegaciones
      cruzan features; las otras dos son internas y no tocan ningún límite. Una
      tabla de rutas de cuarenta líneas las resuelve sin reescribir el árbol de
      navegación ni introducir un router a días de la entrega — que es
      exactamente la salida que R-23 dejó prevista. `go_router` sigue en el
      `pubspec.yaml`: **o se usa cuando haga falta rutas profundas, o se quita.**
      Queda como deuda declarada, no como olvido.

- [ ] **T-7 — Verificación.** El verificador pasa entero, `flutter test` en
      verde, prueba en dispositivo contra el backend real. **Cierra CA-10 a
      CA-12.**

- [ ] **T-8 — Documentación.** README (estructura, `--dart-define` obligatorio,
      cómo agregar una feature), ADR-0006 a "Aceptada", esta spec a
      "Implementada".

**Orden obligatorio:** T-0 → T-1 → T-2 → T-3 → T-4 → T-5 → T-6 → T-7 → T-8.

T-2 es el que resuelve el problema que originó el pedido. Si hubiera que
detenerse en cualquier punto, el mejor lugar es **después de T-2 o T-3**: ambos
dejan una mejora completa y autónoma.

---

## 7. Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| R-18 | El refactor se cruza con el bug P0 del PDF y se mezclan dos cambios. | El bug se cierra primero. T-0 lo exige. |
| R-19 | ~30 archivos nunca compilados. | T-0. Innegociable. |
| R-20 | Un `override` olvidado tumba la app en el arranque. | Es el comportamiento buscado (§4.1). Test de arranque en T-7. |
| R-21 | El refactor consume tiempo del MVP sin función visible. | Plan incremental; se puede pausar entre tareas. T-2 solo ya paga el pedido. |
| R-22 | Mover `InterceptorSesion` rompe el refresco 401 single-flight, que no tiene test de integración. | T-3 no cambia su lógica, solo su ubicación y su dependencia. Antes de moverlo, escribir el test del single-flight que hoy falta. |
| R-23 | `go_router` está en el `pubspec.yaml` pero nunca se usó: introducirlo en T-6 puede traer sorpresas con el `Navigator` imperativo actual. | T-6 es la última tarea funcional y la más aislable. Si complica, se posterga: los ciclos de navegación son el hallazgo menos grave de la lista. |
| R-24 | Al obligar `--dart-define`, alguien compila sin él y cree que la app está rota. | El mensaje de `UnimplementedError` dice exactamente qué falta y dónde. Documentado en README y en `bootstrap.ps1`. |

---

## 8. Preguntas cerradas (2026-08-04, con Williams)

| ID | Pregunta | Respuesta |
|---|---|---|
| P-09 | ¿Cuáles son las URLs reales de cada ambiente? | **Dos, y dependen de dónde esté enchufada la laptop del backend:** `192.168.66.225` en el hospital y `192.168.100.104` en oficinas administrativas. Ambas de LAN, hasta que el backend se suba a la nube. |
| P-10 | ¿Cómo se genera el APK del cliente? | **No se genera.** Lo que usa el cliente es el proyecto corriendo por depuración USB. |
| P-11 | ¿Entra en el MVP? | **Sí.** Entrega el lunes; la refactorización debe estar dentro para mostrar un producto escalable. |

### Lo que P-09 y P-10 cambian del diseño

**No hay ambientes: hay ubicaciones físicas, y son temporales.** Modelar
`Ambiente { desarrollo, pruebas, produccion }` sería inventar una taxonomía que
no existe y que además va a morir cuando el backend llegue a la nube. Se descarta
el enum de §3.

En su lugar, `ConfiguracionApp` expone la URL y un **nombre legible** del destino,
sin que el código conozca "hospital" ni "administrativo" como conceptos. Las dos
IPs viven fuera de Dart, en scripts de arranque:

```
tool/correr.ps1 -Donde hospital        → --dart-define=API_URL=http://192.168.66.225:3001
tool/correr.ps1 -Donde oficinas        → --dart-define=API_URL=http://192.168.100.104:3001
tool/correr.ps1 -Donde emulador        → --dart-define=API_URL=http://10.0.2.2:3001
```

Cuando el backend suba a la nube se agrega una línea al script y **no se toca una
sola línea de Dart**. Ese es exactamente el objetivo del pedido original.

**Y como no hay APK**, el `--dart-define` no es un paso de empaquetado sino algo
que se tipea en cada `flutter run`. Un flag que se escribe a mano varias veces al
día y que cambia según la red se olvida seguro. Por eso los scripts no son
documentación: son el mecanismo.

**Consecuencia operativa que se agrega a T-2.** Con dos redes, sin APK y con la
laptop moviéndose, la pregunta "¿contra qué URL está corriendo esto?" va a
aparecer cada vez que algo no conecte. La app va a mostrar la URL activa en la
pantalla de login. Son unas pocas líneas y evitan la sesión de diagnóstico más
recurrente que va a tener este proyecto hasta que el backend salga de la LAN.

### Nota sobre el plazo (P-11)

La entrega es el lunes y T-0 sigue siendo condición previa: el bug del PDF y el
árbol en verde. **T-1 no depende de T-0** —es una herramienta que analiza texto,
no código compilado— así que puede avanzar en paralelo mientras se cierra el bug.
