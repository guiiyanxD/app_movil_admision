# Especificación Técnica: Módulo de Gestión y Trazabilidad de Historiales Clínicos

## 1. Objetivo del Módulo
El objetivo de este módulo es digitalizar el control, gestión y trazabilidad de los historiales clínicos entre los servicios de Admisión y Archivo Clínico. Actualmente, el proceso se lleva en un cuaderno manual donde existen vacíos de información, pérdidas de historiales y problemas en la validación de entrega y recepción. La digitalización permite asegurar el rastreo de quién solicita, quién busca y quién recibe el historial en tiempo real.

## 2. Análisis del Problema y Eventos
El ciclo de vida de un historial clínico para internación consta de los siguientes eventos clave, los cuales ahora quedan formalizados:

1. **Solicitud (`REQUESTED`)**: Admisión requiere el historial de pacientes recién ingresados (generalmente consolidado a las 6:00 AM).
2. **Búsqueda y Actualización (`READY` / `NOT_FOUND` / `LENT`)**: Archivo Clínico busca el historial y dictamina su estado. Cualquier actualización aquí significa que la solicitud ya fue **gestionada**.
3. **Notificación de Lote**: Archivo Clínico notifica a Admisión que ha terminado la búsqueda de un lote de solicitudes, enviando un resumen de cuáles están listos y cuáles no se encontraron o están prestados.
4. **Recepción Conforme (`RECEIVED`)**: Admisión recoge físicamente los historiales marcados como listos (`READY`) y confirma en el sistema.
5. **Discrepancia/Refutación (`DISCREPANCY`)**: Admisión reporta que un historial marcado como `READY` por el Archivo, no se encuentra físicamente en el lote entregado.

## 3. Diagrama de Flujo del Proceso

```mermaid
sequenceDiagram
    actor A as Personal de Admisión
    participant S as Sistema (App/API)
    actor C as Archivo Clínico
    
    A->>S: 1. Selecciona pacientes e inicia "Solicitud de Historial"
    S-->>C: 2. Solicitudes aparecen Pendientes (REQUESTED)
    
    loop Por cada solicitud pendiente
        C->>C: Busca el historial físico
        alt Historial Encontrado
            C->>S: 3a. Marca como "Listo" (READY)
        else Historial Prestado / No Encontrado
            C->>S: 3b. Marca como "Prestado/No encontrado" (LENT / NOT_FOUND)
        end
        Note right of S: Se registra la fecha_gestion_archivo
    end
    
    C->>S: 4. Clic en "Notificar Lote"
    S-->>A: 5. Envía alerta a Admisión (Resumen)
    
    A->>C: 6. Va físicamente a recoger los historiales "READY"
    
    loop Por cada historial READY recibido
        A->>S: 7. Verifica en la App
        alt Coincide con lo entregado
            A->>S: 8a. Marca "Recibido Conforme" (RECEIVED)
        else Falta físicamente
            A->>S: 8b. Marca "Refutar" (DISCREPANCY)
            S-->>C: 9. Alerta de Discrepancia a Archivo Clínico
        end
        Note left of S: Se registra la fecha_recepcion_admision
    end
```

## 4. Diseño de Base de Datos (ERD)

El siguiente diagrama ilustra cómo el nuevo módulo se integra con las tablas (o colecciones) maestras existentes:

```mermaid
erDiagram
    PACIENTES {
        uuid id PK
        string matricula "Opcional"
        string nombre
        string apellido_paterno
        string apellido_materno
        date fecha_nacimiento
        string tipo_paciente
        uuid titular_id FK
    }

    INTERNACIONES {
        uuid id PK
        uuid paciente_id FK
        datetime fecha_ingreso
        string servicio
        string cama_codigo
        string diagnostico_inicial
        string estado
    }

    USUARIOS {
        uuid id PK
        string nombre
        string rol "ADMISION, ARCHIVO"
    }

    LOTES_SOLICITUD {
        uuid id PK
        datetime fecha_creacion
        uuid creado_por_usuario_id FK
        string estado "PENDING, NOTIFIED, COMPLETED"
    }

    SOLICITUDES_HISTORIAL {
        uuid id PK
        uuid internacion_id FK
        uuid paciente_id FK
        uuid lote_id FK "Opcional"
        
        string estado "REQUESTED, READY, NOT_FOUND, LENT, RECEIVED, DISCREPANCY"
        string notas_archivo
        
        datetime fecha_solicitud
        datetime fecha_gestion_archivo
        datetime fecha_recepcion_admision
        
        uuid solicitado_por_usuario_id FK
        uuid gestionado_por_usuario_id FK
        uuid recibido_por_usuario_id FK
    }

    %% Relaciones
    PACIENTES ||--o{ PACIENTES : "Depende de (Titular)"
    PACIENTES ||--o{ INTERNACIONES : "Tiene"
    
    INTERNACIONES ||--o{ SOLICITUDES_HISTORIAL : "Genera"
    PACIENTES ||--o{ SOLICITUDES_HISTORIAL : "Referencia"
    
    LOTES_SOLICITUD ||--o{ SOLICITUDES_HISTORIAL : "Agrupa"
    
    USUARIOS ||--o{ LOTES_SOLICITUD : "Crea"
    USUARIOS ||--o{ SOLICITUDES_HISTORIAL : "Solicita"
    USUARIOS ||--o{ SOLICITUDES_HISTORIAL : "Gestiona (Archivo)"
    USUARIOS ||--o{ SOLICITUDES_HISTORIAL : "Recibe (Admisión)"
```

## 5. Estructuras de Datos (JSON / API Payload)

La entidad central desnormalizará datos de consulta frecuente (como nombres y código de cama) para que las vistas del lado de Archivo Clínico no requieran queries anidadas costosas.

```json
{
  "id": "uuid",
  "paciente_id": "uuid",
  "internacion_id": "uuid",
  "lote_id": "uuid_opcional",
  
  "nombre_paciente": "Davila Susano Elizabeth",
  "matricula_paciente": "19525414DSE",
  "matricula_titular": "19500504ZBH",
  "cama_codigo": "216-B",
  
  "estado": "REQUESTED", 
  "notas_archivo": null, 
  
  "fecha_solicitud": "2026-09-17T06:00:00Z",
  "fecha_gestion_archivo": "2026-09-17T06:20:00Z",
  "fecha_recepcion_admision": "2026-09-17T06:45:00Z",
  
  "solicitado_por_usuario_id": "uuid",
  "gestionado_por_usuario_id": "uuid",
  "recibido_por_usuario_id": "uuid"
}
```

### Endpoints Propuestos (Fase 1)
1. **`POST /api/historiales/solicitudes`**: Crea el lote (Admisión).
2. **`GET /api/historiales/solicitudes?fecha=YYYY-MM-DD`**: Retorna el lote del día para ser buscado (Archivo).
3. **`PATCH /api/historiales/solicitudes/{id}/estado`**: Archivo Clínico asienta `READY`, `NOT_FOUND` o `LENT` e imprime su huella en `fecha_gestion_archivo`.
4. **`POST /api/historiales/solicitudes/notificar-lote`**: Push notification al culminar la búsqueda del día.
5. **`PATCH /api/historiales/solicitudes/{id}/recepcion`**: Admisión escanea/confirma la recepción, o reporta un faltante (`RECEIVED` vs `DISCREPANCY`), dejando huella en `fecha_recepcion_admision`.

## 6. Fases de Construcción
- **Fase 1**: Desarrollo del Backend (API, creación de tablas, migraciones).
- **Fase 2**: Integración de las pantallas móviles (prototipadas).
- **Fase 3**: Dashboard en la aplicación Web para análisis estadísticos (ej. porcentaje de pérdidas de historias, tiempos promedio de entrega).
