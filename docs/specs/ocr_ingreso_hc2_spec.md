# Especificación del Módulo OCR para Ingreso HC-2

Este documento describe la arquitectura, flujo y lógica de extracción implementada para procesar el Formulario HC-2 utilizando el sensor de la cámara del dispositivo móvil e Inteligencia Artificial (ML Kit).

## 1. Objetivo del Módulo

Automatizar el ingreso de pacientes al sistema de internaciones mediante la captura fotográfica del formulario físico HC-2. El sistema debe extraer la información crítica (matrícula, nombre, apellidos, cama, servicio, tipo de paciente), verificar si el paciente (titular y/o beneficiario) existe en el backend, y registrar los datos faltantes, agilizando el flujo operativo y minimizando errores de transcripción manual. Se da énfasis al procesamiento local en el dispositivo (Edge ML) para alivianar la carga del servidor y operar bajo conexiones deficientes.

## 2. Flujo del Usuario

1. **Captura Inicial**: Desde el tablero de camas o menú de opciones, el usuario selecciona el botón flotante "Escanear HC-2" o usa el diálogo modal `CapturaHC2Dialog`.
2. **Interfaz de Cámara (`CamaraEscaneoHC2Page`)**:
   - Muestra el feed de la cámara en tiempo real.
   - Cuenta con una guía visual (marco 16:10) para enfocar únicamente el formulario HC-2.
   - Ofrece control de flash para ambientes poco iluminados.
3. **Recorte y OCR**: 
   - Se toma la foto completa del sensor, y mediante la librería `image`, se recorta **estrictamente** lo contenido dentro del marco guía.
   - La imagen recortada se pasa a Google ML Kit (Text Recognition).
4. **Validación y Extracción (Local)**:
   - Los datos brutos del texto (`textoCrudo`) pasan por el `HC2ParserService`.
   - Se estructuran en un modelo `DatosIngresoHC2`.
5. **Pantalla de Revisión (`RevisionIngresoHC2Page`)**:
   - Antes de enviar los datos al backend, el usuario revisa los campos en un formulario tradicional.
   - En esta pantalla, la aplicación consulta el backend para identificar si el paciente es nuevo o ya está registrado.
   - Al guardar, los datos finales se suben al servidor (con un límite de Timeout de 45 segundos por la conexión de red débil).

## 3. Desafíos Resueltos en la Extracción (Lógica de Fallbacks)

La lectura óptica de documentos físicos es ruidosa. El parser de la app implementa múltiples capas de recuperación de errores (fallbacks) que garantizan robustez frente a lecturas distorsionadas, marcas de agua y columnas alineadas verticalmente.

### 3.1. Extracción de Nombres y Apellidos
Los formularios mal orientados o muy pegados provocan que ML Kit agrupe las palabras verticalmente. Para evitar que el software confunda apellidos y nombres en diferentes líneas, se aplican los siguientes métodos en orden de prioridad:

- **Búsqueda por Etiqueta Directa:** Identifica "Nombre Titular:" o "Apellido Paterno:" seguido del nombre.
- **Validación de Líneas Contiguas:** Si el nombre completo abarca dos líneas debido al diseño del formulario, la función evalúa la línea previa o siguiente.
- **Anclaje a través de la Matrícula CPS (Clave de Éxito):** La matrícula de la CPS (ej. `19525414DSE`) termina en 3 o 4 caracteres alfabéticos que coinciden con las iniciales del paciente (Davila Susano Elizabeth). Si el software no puede distinguir entre un apellido paterno y uno materno, **se extraen estas iniciales de la matrícula leída y se emparejan con las palabras encontradas** en el área general del paciente. Esto soluciona problemas críticos de lectura fragmentada.

### 3.2. Código de Cama
En los HC-2 reales, el bloque "Cama:" suele tener superpuesta una enorme marca de agua "de salud" y líneas horizontales en su límite inferior, provocando lecturas como "Carna: U0216-B" o "Camo 0216 - B".
- Se implementó una **Expresión Regular Tolerante** para el campo cama: `(?:Cama|Carna|Camo|Cam\s*a|Cam)[\s\:\.\-]*([A-Z0-9\-\s/]+?)`
- **Extracción de Dígitos Puros:** Puesto que en el software solo se guarda el número final de cama, una vez extraído el valor bruto (ej. `U0216-B`), la lógica aplica la regla `^[A-Z]*0*` para barrer letras y ceros inútiles del inicio, extrayendo exitosamente valores como `216-B` o `9`.

## 4. Timeout de Conexión

Se agregó una configuración global (`configuracion_dart_define.dart` y `mapeador_de_fallas.dart`) que interrumpe la carga al servidor si supera los **45 segundos**. Esto responde a quejas de la etapa inicial donde bajo conexiones inestables la aplicación quedaba cargando infinitamente sin emitir respuesta. Transcurrido el límite, el usuario visualizará una notificación indicando que la cobertura es insuficiente.

## 5. Mantenimiento y Extensibilidad (Zero Lints)
Toda la lógica fue programada garantizando cumplimiento estricto del análisis estático de Flutter (`flutter analyze = 0 issues`). El código en `CamaraEscaneoHC2Page` y `HC2ParserService` hace uso diligente de concurrencia asíncrona (`unawaited`), clausulas controladas (`on Object catch`), widgets de alto rendimiento (`ColoredBox`) y simplificación de colas de render en Canvas (`Path`).

La suite de pruebas (`hc2_parser_service_test.dart`) incluye muestras literales del comportamiento de la cámara en entorno físico para asegurar que cualquier mejora futura no rompa la capacidad del algoritmo de recuperación de fallas (Regresión).
