# ADR-0006 — Desacoplamiento de la configuración, la capa de red y los providers

| Campo | Valor |
|---|---|
| **ID** | ADR-0006 |
| **Estado** | Propuesta — pendiente de aprobación de Williams |
| **Fecha** | 2026-08-04 |
| **Autor** | Willtech — Arquitectura de Software |
| **Relacionada con** | SPEC-005 (plan de migración), ADR-0005 (módulo censo diario) |

---

## Contexto

La URL base del API está declarada dentro de
`lib/features/auth/presentation/auth_providers.dart`, un archivo de la **capa de
presentación** de la feature de autenticación:

```dart
abstract final class AppConfig {
  static const String urlBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.66.225:3001',
  );
}
```

El síntoma que lo hizo visible fue operativo —configurar la URL obliga a editar
un archivo de estado— pero la auditoría del repositorio mostró que no es un
descuido aislado. Es el punto donde asoma una decisión que nunca se tomó: **dónde
vive la composición de dependencias**.

### Evidencia recogida (2026-08-04)

**E-1 — Hay tres URLs distintas en el repositorio y ninguna coincide.**

| Fuente | Valor | Puerto |
|---|---|---|
| `auth_providers.dart:19` (valor por defecto real) | `http://192.168.66.225:3001` | 3001 |
| `auth_providers.dart:12` (comentario de uso) | `http://10.0.2.2:3001` | 3001 |
| `README.md:376` (instrucción al desarrollador) | `http://10.0.2.2:3000` | **3000** |

El valor por defecto es la **IP de la LAN de una máquina de desarrollo**. Un APK
compilado sin `--dart-define` apunta a una red que en el hospital no existe, y
falla con un error de red genérico que manda a diagnosticar por el lado
equivocado. La documentación y el código además discrepan en el puerto: ya hay
dos verdades sobre a qué servidor conectarse.

**E-2 — `AppConfig` es importado por otras dos features a través de la capa de
presentación de `auth`.** Para saber contra qué servidor consulta el módulo de
reportería hay que abrir el archivo de providers de autenticación. `dioProvider`
—el cliente HTTP con bearer y renovación— también vive ahí y lo consumen
`censo_diario` y `reporteria`.

**E-3 — `auth` es la única feature sin contrato en `domain/`.** `AuthRepository`
es una clase **concreta** en `data/` que la presentación instancia y consume
directamente. `censo_diario` y `reporteria` sí declaran
`abstract interface class` en `domain/repositories/`. Que el defecto de la URL
haya aparecido justo en la feature sin abstracción no es casualidad.

**E-4 — `AuthRepository` acumula cuatro responsabilidades.** I/O de red,
persistencia cifrada, **estado de sesión mutable en memoria** (`Sesion? _sesion`)
y **control de concurrencia** del refresco (`Future<bool>? _refrescoEnCurso`). Es
un almacén de estado viviendo en la capa de datos.

**E-5 — No existe raíz de composición.** `main.dart` monta
`ProviderScope(child: AppMovil())` **sin `overrides`**. La construcción de `Dio`,
datasources y repositorios está repartida entre tres archivos
`*_providers.dart` de presentación. Consecuencia directa: las tres features
tienen presentación importando `data/`.

**E-6 — Hay ciclos de dependencia entre features.** Ocho aristas cruzadas, con
tres ciclos: `censo_diario ⇄ reporteria`, `censo_diario ⇄ diagnostico` y
`auth → diagnostico → censo_diario → auth`. Ninguna feature se puede extraer,
probar ni compilar de forma aislada.

**E-7 — Lo que sí está sano y no se toca.** `domain/` es puro en las cuatro
features: cero imports de Flutter o de plugins. `Resultado<T>` y `Failure` son
jerarquías selladas en `core/`. Dos de tres repositorios ya tienen interfaz.
Esta base es lo que hace que el refactor sea acotado y no una reescritura.

### Lo que este ADR **no** decide

El encargo original describía la gestión de estado como `provider ^2.6.1` con
`MultiProvider` y `ProxyProvider`. Se verificó el `pubspec.yaml`: la dependencia
instalada es **`flutter_riverpod: ^2.6.1`**. En `lib/` hay **0** apariciones de
`ChangeNotifier`, `MultiProvider`, `ProxyProvider`, `context.read` o
`context.watch`, y **48** de `ConsumerWidget`, `NotifierProvider`,
`FutureProvider` y `ref.watch` repartidas en 10 archivos.

Confirmado con Williams el 2026-08-04: **se mantiene Riverpod**. Migrar a
`package:provider` implicaría reescribir los diez archivos de estado y perder
`autoDispose` y `family`, de los que el formulario del censo depende hoy
(SPEC-003, D-3 y D-12). El problema diagnosticado —acoplamiento y violación del
DIP— es real y se resuelve igual, con la herramienta que ya está en el proyecto.

---

## Decisiones

### D-1 — La configuración es un contrato del dominio, no una constante

Se define `ConfiguracionApp` como **interfaz** en `lib/core/config/`, con una
implementación que lee `String.fromEnvironment`:

```
core/config/
├── configuracion_app.dart          abstract interface class ConfiguracionApp
├── configuracion_dart_define.dart  implementación por --dart-define
└── ambiente.dart                   enum Ambiente { desarrollo, pruebas, produccion }
```

Se expone con un provider que **lanza si no está sobreescrito**:

```dart
final configuracionProvider = Provider<ConfiguracionApp>((ref) {
  throw UnimplementedError(
    'ConfiguracionApp debe inyectarse en el ProviderScope de main.dart',
  );
});
```

**Por qué lanzar en vez de devolver un valor por defecto.** Un valor por defecto
es exactamente cómo se llegó a `192.168.66.225` en producción: el código
compilaba, arrancaba y fallaba tarde, en el hospital, con un error de red que no
dice nada. Con esta forma, un olvido de inyección es un error inmediato,
determinista y en la primera línea de `main`. Es la diferencia entre un fallo que
se descubre en desarrollo y uno que se descubre en el turno de noche.

**Consecuencia inmediata:** desaparece el valor por defecto. La URL pasa a ser
obligatoria en el arranque, y las tres verdades de E-1 se reducen a una.

### D-2 — `main.dart` es la única raíz de composición

Toda la construcción de dependencias se concentra en un `bootstrap` invocado
desde `main.dart`, que arma el `ProviderScope` con sus `overrides`.

Esto es **inversión de dependencias en Riverpod**: los providers de infra se
declaran en `core/` como contratos sin implementación, y la raíz decide con qué
se satisfacen. Los tests hacen lo mismo con otros `overrides`, sin tocar
`main.dart` ni variables de entorno.

**Por qué no `get_it` ni un service locator.** El `ProviderScope` con
`overrides` ya es un contenedor de inyección, con la ventaja de que las
dependencias quedan tipadas y el compilador verifica el grafo. Sumar un locator
sería un segundo mecanismo de resolución para el mismo problema, y dos
mecanismos es peor que uno imperfecto.

### D-3 — El cliente HTTP sale de la feature de autenticación

`dioProvider` e `InterceptorSesion` se mueven a `core/red/`. `auth` deja de ser
el dueño del transporte de toda la aplicación.

El interceptor **no depende de `AuthRepository`**: depende de un contrato mínimo
declarado en `core/`, con solo lo que necesita —leer el token, pedir renovación,
avisar que la sesión se perdió—. Así `core/red/` no conoce la feature de
autenticación, y la relación queda invertida: es `auth` quien satisface un
contrato del núcleo.

```dart
// core/red/proveedor_de_sesion.dart
abstract interface class ProveedorDeSesion {
  String? get accessToken;
  Future<bool> refrescar();
  void alPerderSesion();
}
```

### D-4 — `auth` recibe el mismo tratamiento que las otras features

Se declara `AuthRepository` como `abstract interface class` en
`features/auth/domain/repositories/`, y la implementación pasa a
`data/repositories/auth_repository_impl.dart`.

Y se separa la responsabilidad de E-4: el **estado de sesión en memoria** y el
**single-flight del refresco** salen del repositorio. El estado es de la capa de
presentación (`SesionNotifier`, que ya existe); el single-flight es una
preocupación de coordinación y vive junto al contrato que lo necesita.

### D-5 — Los ciclos entre features se cortan por navegación e identidad

Los tres ciclos de E-6 tienen dos causas y dos remedios distintos:

**Navegación** — `seleccion_fecha_page` importa páginas de `reporteria` y
`diagnostico` para poder navegar a ellas. Se corta con `go_router`, que **ya está
en el `pubspec.yaml` y hoy no se usa**: las rutas se declaran en `app/` y ninguna
feature importa páginas de otra.

**Identidad y sesión** — `censo_diario` y `reporteria` importan
`auth_providers.dart` por `puedeEscribirProvider` y `dioProvider`. Con D-3 el
cliente HTTP ya sale de `auth`; lo que queda —"¿este usuario puede escribir?"— es
una pregunta transversal y su respuesta se expone desde `core/`.

**Lo que queda y se acepta:** `diagnostico → censo_diario` y
`reporteria → censo_diario/domain/value_objects/fecha_censo.dart`. Son
dependencias hacia el **dominio** de otra feature, no hacia su presentación, y
son unidireccionales: no forman ciclo. `FechaCenso` codifica la regla horaria de
Bolivia, que es conocimiento institucional compartido; si aparece un tercer
consumidor se muda a `core/`, no antes.

### D-6 — No se crean casos de uso donde no hay lógica que encapsular

El encargo pide que el estado consuma "casos de uso o repositorios abstractos".
Se elige lo segundo donde la operación es un paso directo al repositorio.

Un `ObtenerProgresoDiaUseCase` que solo reenvía la llamada agrega un archivo, un
test y una indirección sin encapsular ninguna regla. Los tres casos de uso que
existen —`InterpretarDictadoCenso`, `ValidarCensoServicio`,
`ArmarMatrizReporte`— existen porque **sí** contienen lógica de negocio, y por
eso están testeados sin Flutter.

Se agregan casos de uso solo cuando aparezca lógica que hoy vive en la
presentación. La regla que importa es que la presentación dependa de una
**abstracción**, y eso lo da D-4 y las interfaces ya existentes.

---

## Alternativas consideradas y descartadas

| Alternativa | Por qué se descartó |
|---|---|
| Dejar `AppConfig` donde está y solo moverlo a `core/` | Resuelve el síntoma y deja intactas E-3, E-4, E-5 y E-6. La URL volvería a filtrarse en cuanto haga falta un segundo parámetro de ambiente. |
| Migrar a `package:provider` con `MultiProvider`/`ProxyProvider` | Reescribe diez archivos de estado y pierde `autoDispose` y `family`, de los que depende el formulario del censo. Resuelve el mismo problema con más riesgo. Ver "Lo que este ADR no decide". |
| `get_it` / service locator | Segundo mecanismo de resolución conviviendo con `ProviderScope`. Además oculta el grafo al compilador: un faltante se descubre en runtime. |
| `flutter_dotenv` con archivo `.env` | Suma una dependencia y un asset que hay que empaquetar y no versionar. `--dart-define` ya resuelve esto, se integra con CI y no viaja dentro del APK como recurso legible. |
| Big-bang: reestructurar todo en una rama larga | Con 1-2 desarrolladores y un MVP en curso, una rama larga de refactor se desincroniza y termina descartándose. El plan de SPEC-005 es incremental y cada paso deja la app funcionando. |
| Mantener el valor por defecto "por comodidad" | Es la causa raíz de E-1. La comodidad de no pasar `--dart-define` en desarrollo cuesta un APK que apunta a una LAN ajena. |

---

## Consecuencias

**Positivas**

- La URL y el ambiente se configuran en un solo lugar y se verifican en el
  arranque. Desaparece la posibilidad de un build que apunta a la LAN de alguien.
- `core/red/` deja de depender de `auth`; la dependencia queda invertida.
- Las tres features pasan a consumir **abstracciones** y no implementaciones que
  ellas mismas construyen.
- Los tests pueden sustituir configuración, red y repositorios con `overrides`,
  sin variables de entorno ni servidor.
- Sin ciclos entre features, cada una se puede compilar y probar aislada.

**Negativas o costos aceptados**

- **Ya no se puede compilar sin `--dart-define`.** Es deliberado (D-1) y obliga a
  actualizar `bootstrap.ps1`, el README y la configuración de ejecución del IDE.
- Más archivos: cada contrato nuevo es un archivo más. Se acepta porque
  reemplaza acoplamiento implícito por dependencias declaradas.
- El refactor toca archivos que **nunca se compilaron** (ver R-19). Es la razón
  por la que SPEC-005 arranca con `flutter analyze` y no con el primer cambio.

**Riesgos**

| ID | Riesgo | Mitigación |
|---|---|---|
| R-18 | El refactor se cruza con el bug P0 del PDF y se mezclan dos cambios en la misma rama. | El bug del PDF se cierra **primero**. SPEC-005 no arranca hasta que esté resuelto. |
| R-19 | Unos 30 archivos de SPEC-003 y SPEC-004 nunca pasaron por `flutter analyze` ni `flutter test`. Refactorizar sobre código no compilado hace imposible saber si un error es viejo o nuevo. | T-0 de SPEC-005: dejar el árbol en verde **antes** de tocar arquitectura. Innegociable. |
| R-20 | Un `override` olvidado en `main.dart` tumba la app en el arranque. | Es el comportamiento buscado (D-1): falla inmediata y determinista, no tardía y silenciosa. Se cubre con un test de arranque. |
| R-21 | El refactor consume tiempo del MVP de 3 semanas sin entregar función visible al cliente. | El plan es incremental: cada tarea deja la app compilando y funcionando, y se puede pausar entre tareas sin dejar el árbol a medias. |

---

## Verificación

Una decisión que solo vive en este documento se erosiona. Cada una tiene su
comprobación mecánica, definida en SPEC-005 §5:

| Decisión | Cómo se verifica |
|---|---|
| D-1 | Test: `configuracionProvider` sin override lanza. Y un script que falle si `String.fromEnvironment` aparece fuera de `core/config/`. |
| D-2 | Script que falle si `presentation/` importa `data/`. |
| D-3 | Script que falle si `core/` importa `features/`. |
| D-4 | El tipo declarado en el provider de `auth` es la interfaz, no la implementación. |
| D-5 | Script de detección de ciclos entre features, corriendo en cada commit. |

Los tres scripts son una sola herramienta: un verificador de límites de capa en
`tool/verificar_arquitectura.dart`, que corre junto a `flutter analyze`. Sin eso,
esta decisión dura hasta el primer apuro.
