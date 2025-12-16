# St. Austin Chatbot - Sistema de Atención Inmobiliaria

## Descripción General

St. Austin Chatbot es un sistema automatizado de atención al cliente desarrollado en **n8n** para la gestión de prospectos inmobiliarios. El sistema integra WhatsApp Business API con inteligencia artificial (Claude de Anthropic) para proporcionar atención personalizada 24/7, calificación automática de leads, y agendamiento de citas.

### Características Principales

- **Atención automatizada por WhatsApp** con IA conversacional
- **Segmentación inteligente** de prospectos por ubicación e interés
- **Calificación automática de leads** basada en presupuesto
- **Sistema Round-Robin** para distribución equitativa de clientes entre asesores
- **Agendamiento automático** de citas con Google Calendar
- **Sincronización con CRM** (HubSpot)
- **Base de conocimiento vectorial** para respuestas precisas
- **Mensajes de seguimiento automatizados**
- **Reasignación automática** de clientes no contactados

---

## Tabla de Contenidos

1. [Arquitectura del Sistema](#arquitectura-del-sistema)
2. [Workflows](#workflows)
   - [Flujo Principal](#1-flujo-principal)
   - [Asignar Asesor](#2-asignar-asesor)
   - [Reasignación de Asesores](#3-reasignación-de-asesores)
   - [Mensajes de Seguimiento](#4-mensajes-de-seguimiento)
   - [Actualizar Usuario en Hoja](#5-actualizar-usuario-en-hoja-del-asesor)
   - [Actualizar Apuntador](#6-actualizar-apuntador-siguiente-asesor)
   - [Poblar Knowledge Base](#7-poblar-tabla-knowledgebasechunks)
3. [Base de Datos](#base-de-datos)
4. [Integraciones Externas](#integraciones-externas)
5. [Enlaces de Hojas de Asesores](#enlaces-de-hojas-de-asesores)
6. [Configuración y Despliegue](#configuración-y-despliegue)
7. [Flujo de Conversación del Bot](#flujo-de-conversación-del-bot)
8. [Mantenimiento](#mantenimiento)

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ARQUITECTURA ST. AUSTIN CHATBOT                    │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────────┐
                              │   Cliente    │
                              │  (WhatsApp)  │
                              └──────┬───────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                              n8n WORKFLOWS                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      FLUJO PRINCIPAL                                 │   │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────────┐  │   │
│  │  │ WhatsApp │──▶│ Supabase │──▶│ AI Agent │──▶│ Google Calendar  │  │   │
│  │  │ Trigger  │   │  Query   │   │ (Claude) │   │ / HubSpot / etc  │  │   │
│  │  └──────────┘   └──────────┘   └──────────┘   └──────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│           ┌─────────────────────────┼─────────────────────────┐            │
│           ▼                         ▼                         ▼            │
│  ┌─────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐   │
│  │ Asignar Asesor  │   │ Mensajes Seguimiento│   │ Reasignación        │   │
│  │ (Round-Robin)   │   │ (Scheduler horario) │   │ (Scheduler 2hrs)    │   │
│  └─────────────────┘   └─────────────────────┘   └─────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│    Supabase     │        │  Google Sheets  │        │    HubSpot      │
│   (PostgreSQL)  │        │  (CRM Asesores) │        │     (CRM)       │
└─────────────────┘        └─────────────────┘        └─────────────────┘
```

### Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Orquestación | n8n (self-hosted) |
| Base de datos | Supabase (PostgreSQL) |
| IA/LLM | Claude Sonnet 4.5 via OpenRouter |
| Embeddings | OpenAI |
| Mensajería | WhatsApp Business API |
| CRM | HubSpot |
| Calendario | Google Calendar |
| Almacenamiento | Google Drive |
| Email | Gmail |
| Hojas de cálculo | Google Sheets |

---

## Workflows

### 1. Flujo Principal

**Workflow:** `workflows/St Austin Flujo Principal.json`

**Descripción:** Workflow maestro que maneja toda la interacción con clientes vía WhatsApp. Implementa un sistema de dos agentes de IA para segmentación inicial y conversación consultiva.

#### Trigger
- **Tipo:** WhatsApp Trigger
- **Evento:** Mensaje entrante de usuario

#### Flujo de Ejecución

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FLUJO PRINCIPAL - DIAGRAMA                          │
└─────────────────────────────────────────────────────────────────────────────┘

     Mensaje WhatsApp
            │
            ▼
    ┌───────────────────┐
    │ Extraer número y  │
    │ contenido mensaje │
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐     NO      ┌─────────────────┐
    │ ¿Cliente existe   │────────────▶│ Crear cliente   │
    │ en BD?            │             │ nuevo en BD     │
    └─────────┬─────────┘             └────────┬────────┘
              │ SÍ                             │
              ▼                                │
    ┌───────────────────┐◀─────────────────────┘
    │ Obtener historial │
    │ conversación      │
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐
    │ AI AGENT 1        │ ◀── Primer mensaje: Segmentación
    │ (Segmentación)    │     - Detecta ubicación (DM/BQ)
    │                   │     - Ofrece: Consultorios/Locales
    └─────────┬─────────┘     - Filtra no calificados
              │
              ▼
    ┌───────────────────┐
    │ AI AGENT 2        │ ◀── Conversación continua: "Eloísa"
    │ (Eloísa - Ventas) │     - Recopila datos del cliente
    │                   │     - Califica presupuesto
    │                   │     - Agenda citas
    └─────────┬─────────┘     - Usa Knowledge Base
              │
              ▼
    ┌───────────────────┐
    │ Detectar acciones │ ◀── Actualización automática de BD
    │ post-mensaje      │     - nombre, email, presupuesto
    └─────────┬─────────┘     - ubicación, instrumento
              │
              ▼
    ┌───────────────────────────────────────────────────────┐
    │                    ACCIONES DERIVADAS                  │
    ├───────────────┬───────────────┬───────────────────────┤
    │ Agendar Cita  │ Asignar Asesor│ Sincronizar HubSpot   │
    │ (Calendar)    │ (Subworkflow) │ (CRM)                 │
    └───────────────┴───────────────┴───────────────────────┘
```

#### Agentes de IA

##### Agent 1: Segmentación Inicial
- **Modelo:** Claude 3.7 Sonnet
- **Propósito:** Primera respuesta, detectar interés y ubicación
- **Funciones:**
  - Bienvenida entusiasta
  - Detectar ubicación (Distrito Médico / Bernardo Quintana)
  - Ofrecer opciones (Consultorios / Locales)
  - Filtrar usuarios no calificados (empleo, proveedores)

##### Agent 2: Eloísa (Ventas Consultivas)
- **Modelo:** Claude Sonnet 4.5
- **Propósito:** Gestión completa de la conversación hasta agendar cita
- **Steps del flujo:**
  1. Proporcionar valor (información del proyecto)
  2. Verificar ubicación de interés
  3. Filtrar no calificados
  4. Recopilar nombre y profesión
  5. Obtener presupuesto y calificar lead
  6. Solicitar correo electrónico
  7. Agendar cita (presencial/online)
  8. Responder preguntas con Knowledge Base

#### Herramientas del Agent

| Herramienta | Función |
|-------------|---------|
| `GetUserDetails` | Obtiene datos actualizados del cliente |
| `KnowledgeBase` | Busca información en base de conocimiento vectorial |
| `GoogleCalendar` | Crea eventos de cita |
| `DeleteCalendarEvent` | Elimina citas para reprogramación |

#### Clasificación de Leads

| Presupuesto | Clasificación |
|-------------|---------------|
| ≥ $3,000,000 MXN | Caliente |
| $300,000 - $2,999,999 MXN | Tibio |
| < $300,000 MXN | Frío |
| Sin especificar | Por calificar |

---

### 2. Asignar Asesor

**Workflow:** `workflows/St Austin Asignar Asesor.json`

**Descripción:** Implementa sistema Round-Robin para distribución equitativa de clientes entre asesores.

#### Trigger
- **Tipo:** Execute Workflow Trigger
- **Llamado desde:** Flujo Principal (cuando cliente tiene nombre y no tiene asesor)

#### Funcionamiento Round-Robin

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SISTEMA ROUND-ROBIN                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    Tabla: RoundRobinPointer
    ┌─────────────────────────────────┐
    │ siguienteAsesor: 3              │ ◀── Apuntador actual
    │ nombreAsesor: "Miguel Tapia"    │
    │ correoAsesor: "tuhogar..."      │
    └─────────────────────────────────┘

    Rotación: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → (vuelve a 1)

    Proceso:
    1. Leer apuntador actual (ej: 3)
    2. Asignar cliente al asesor 3
    3. Incrementar apuntador a 4
    4. Si asesor tiene puntos negativos → saltar al siguiente
```

#### Flujo de Asignación

1. Recibe `idCliente` del workflow padre
2. Obtiene datos del cliente de Supabase
3. Bifurca por ubicación:
   - **Distrito Médico:** Usa tabla `RoundRobinPointer`
   - **Bernardo Quintana:** Usa tabla `RoundRobinPointer_BQ`
4. Obtiene siguiente asesor del round-robin
5. Registra cliente en Google Sheets del asesor
6. Actualiza HubSpot con responsable
7. Incrementa contador de usuarios asignados
8. Envía email de notificación al asesor
9. Registra en hoja global
10. Actualiza apuntador al siguiente asesor

#### Asesores Configurados

| ID | Nombre | Email |
|----|--------|-------|
| 1 | Carlos Rios | carlosrios.inmobiliaria@gmail.com |
| 2 | Miguel Tapia | tuhogarqro2022@gmail.com |
| 3 | Alejandra Barillas | alejandrabarillas2602@gmail.com |
| 4 | Mabel | izta132100@gmail.com |
| 5 | Alex García | alexgarciablanco@gmail.com |
| 6 | Lluvia | lluvia.gonzalezrealestate@gmail.com |
| 7 | Jhona | jhonaizt@gmail.com |
| 8 | Rafa Marín | teorafamarin@gmail.com |
| 9 | Abraham Pérez | perezramabraham79@gmail.com |

---

### 3. Reasignación de Asesores

**Workflow:** `workflows/St Austin Reasignación de Asesores copy.json`

**Descripción:** Reasigna automáticamente clientes cuando el asesor no los contacta dentro de 2 horas.

#### Trigger
- **Tipo:** Schedule Trigger
- **Frecuencia:** Cada 2 horas
- **Horario activo:** 11:00 AM - 5:00 PM

#### Criterios de Reasignación

Un cliente se reasigna cuando:
1. ✅ Tiene asesor asignado (`correoAsesor` no vacío)
2. ✅ `asesorRespondio = false`
3. ✅ Han pasado más de 2 horas desde `fechaAsignacionAsesor`
4. ✅ El campo "¿Contactado?" en Google Sheets del asesor = "No" o vacío

#### Flujo de Reasignación

```
Schedule (cada 2 horas)
        │
        ▼
┌───────────────────┐
│ ¿Entre 11am-5pm?  │──NO──▶ STOP
└─────────┬─────────┘
          │ SÍ
          ▼
┌───────────────────┐
│ Get todos clientes│
└─────────┬─────────┘
          │
          ▼ (para cada cliente)
┌───────────────────┐
│ ¿Tiene asesor?    │──NO──▶ SKIP
└─────────┬─────────┘
          │ SÍ
          ▼
┌───────────────────┐
│ Get hoja asesor   │
│ (Google Sheets)   │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ ¿Asesor contactó? │──SÍ──▶ Marcar asesorRespondio=TRUE
└─────────┬─────────┘
          │ NO
          ▼
┌───────────────────┐
│ ¿Pasaron 2 horas? │──NO──▶ SKIP
└─────────┬─────────┘
          │ SÍ
          ▼
┌───────────────────┐
│ 1. Marcar         │
│    "REASIGNADO"   │
│ 2. Penalizar      │
│    asesor         │
│ 3. Ejecutar       │
│    Asignar Asesor │
└───────────────────┘
```

---

### 4. Mensajes de Seguimiento

**Workflow:** `workflows/St Austin Mensajes de Seguimiento.json`

**Descripción:** Envía mensajes de seguimiento automáticos a clientes que abandonan la conversación.

#### Trigger
- **Tipo:** Schedule Trigger
- **Frecuencia:** Cada hora
- **Horario activo:** 9:00 AM - 7:00 PM

#### Sistema de Puntos

Cada cliente tiene un contador `esperandoRespuesta` que inicia en 8:

| Puntos | Acción |
|--------|--------|
| 8 | Esperando primera respuesta |
| 7 | Primer mensaje de seguimiento |
| 6 | Segundo mensaje |
| 5 | Tercer mensaje |
| 4 | Cuarto mensaje + imagen promocional |
| 3 | Marcar como conversación abandonada |
| 2-1 | Sin más acciones |

#### Estrategias por Intento

| Intento | Estrategia | Tono |
|---------|------------|------|
| 1 | Reconexión suave | "Hola de nuevo, ¿pudiste revisar la información?" |
| 2 | Valor agregado | Compartir beneficio específico del proyecto |
| 3 | Asesor disponible | "Un asesor puede resolver tus dudas" |
| 4 | Cierre respetuoso | "Quedamos atentos cuando gustes" |

---

### 5. Actualizar Usuario en Hoja del Asesor

**Workflow:** `workflows/St Austin Actualizar usuario en hoja del asesor.json`

**Descripción:** Sincroniza datos del cliente desde Supabase a la hoja de Google Sheets del asesor.

#### Trigger
- **Tipo:** Execute Workflow Trigger
- **Llamado desde:** Workflow de Asignar Asesor

#### Datos Sincronizados

| Campo Supabase | Columna Google Sheets |
|----------------|----------------------|
| nombre + apellido | Nombre |
| numeroTelefono | Número de teléfono |
| correoElectronico | Correo electrónico |
| idUbicacionInteres | Ubicación de interés |
| idInstrumentoInversion | Instrumento de interés |
| presupuesto | Presupuesto |
| leadStatus | Tipo de Lead |
| profesion | Profesión |
| citaAgendada | ¿Tiene cita agendada? |
| modalidadCita | Modalidad de la cita |

---

### 6. Actualizar Apuntador Siguiente Asesor

**Workflows:**
- `workflows/St Austin Actualizar Apuntador Siguiente Asesor.json` (Principal)
- `workflows/St Austin Actualizar Apuntador Siguiente Asesor BQ.json` (Bernardo Quintana)

**Descripción:** Mantiene el sistema Round-Robin, actualizando el apuntador al siguiente asesor.

#### Lógica

```javascript
// Pseudocódigo
if (siguienteAsesor < maxAsesores) {
    siguienteAsesor++
} else {
    siguienteAsesor = 1  // Reset al inicio
}

// Si el asesor tiene puntos negativos, saltar al siguiente
if (asesor.puntaje > 0) {
    asesor.puntaje--
    ejecutarWorkflowNuevamente()  // Recursivo
}
```

#### Diferencias entre versiones

| Aspecto | Principal | BQ |
|---------|-----------|-----|
| Tabla | RoundRobinPointer | RoundRobinPointer_BQ |
| Asesores | Asesor | Asesor_BQ |
| Máximo | 9 asesores | 4 asesores |

---

### 7. Poblar Tabla KnowledgeBaseChunks

**Workflow:** `workflows/St Austin Poblar Tabla KnowledgeBaseChunks.json`

**Descripción:** Crea y mantiene la base de datos vectorial para búsqueda semántica.

#### Trigger
- **Tipo:** Manual
- **Ejecución:** Click en "Test workflow" en n8n

#### Proceso

1. Elimina chunks existentes
2. Lee documentos de `KnowledgeBaseDocumento`
3. Concatena ubicación + título + detalles
4. Divide en chunks de 2000 caracteres
5. Genera embeddings con OpenAI
6. Almacena en `KnowledgeBaseChunks`

#### Uso

Ejecutar manualmente cuando:
- Se agregan nuevos documentos a la Knowledge Base
- Se actualiza información de proyectos
- Se modifican detalles de propiedades

---

## Base de Datos

### Diagrama de Entidades

El esquema completo se encuentra en `db/database-schema.sql` y el diagrama visual en `db/supabase-schema.svg`.

### Tablas Principales

#### Cliente
Almacena información de prospectos/clientes.

```sql
CREATE TABLE Cliente (
  idCliente bigint PRIMARY KEY,
  fechaDeCreacion timestamp DEFAULT now(),
  nombre text,
  apellido text,
  numeroTelefono text UNIQUE,
  correoElectronico text,
  presupuesto text,
  profesion text,
  leadStatus text,                    -- Caliente/Tibio/Frio/Por calificar
  idUbicacionInteres bigint,          -- FK: 1=DM, 2=BQ
  idInstrumentoInversion bigint,      -- FK: 0=Tickets, 1=Consultorios, 2=Locales
  idEspecialidadPropiedad bigint,     -- FK: Tipo de especialidad médica
  idEstado bigint DEFAULT 0,          -- FK: Estado del cliente
  correoAsesor text,                  -- Email del asesor asignado
  fechaAsignacionAsesor timestamp,
  asesorRespondio boolean DEFAULT false,
  citaAgendada boolean DEFAULT false,
  modalidadCita text,                 -- Presencial/Videoconferencia
  fechaCita text,
  idCita text,                        -- ID evento Google Calendar
  existeEnHubSpot boolean DEFAULT false,
  briefCompartido boolean DEFAULT false,
  esperandoRespuesta bigint DEFAULT 8,
  fechaUltimoMensaje timestamp,
  origen text
);
```

#### HistorialConversacion
Almacena todos los mensajes de las conversaciones.

```sql
CREATE TABLE HistorialConversacion (
  idHistorialConversacion bigint PRIMARY KEY,
  idCliente bigint REFERENCES Cliente(idCliente),
  mensaje jsonb,
  fechaDeEnvio timestamp DEFAULT now(),
  remitente varchar DEFAULT 'user'    -- 'user' o 'ia'
);
```

#### Asesor
Información de asesores de ventas.

```sql
CREATE TABLE Asesor (
  idAsesor bigint PRIMARY KEY,
  nombreAsesor text,
  correoAsesor text UNIQUE,
  usuariosAsignados bigint DEFAULT 0,
  usuariosNoContactados bigint DEFAULT 0,
  puntaje bigint DEFAULT 0,           -- Puntos negativos para round-robin
  enlace text                         -- URL de su hoja de Google Sheets
);
```

#### RoundRobinPointer
Control del sistema de asignación circular.

```sql
CREATE TABLE RoundRobinPointer (
  correoAsesor text PRIMARY KEY,
  siguienteAsesor bigint,             -- ID del próximo asesor a asignar
  nombreAsesor text
);
```

#### KnowledgeBaseChunks
Base de conocimiento con embeddings vectoriales.

```sql
CREATE TABLE KnowledgeBaseChunks (
  idChunk bigint PRIMARY KEY,
  idDocumento bigint REFERENCES KnowledgeBaseDocumento(idDocumento),
  content text,
  embedding vector,                   -- Embedding de OpenAI
  metadata jsonb
);
```

### Catálogos

#### Ubicacion

| ID | Descripción |
|----|-------------|
| 1 | Distrito Médico |
| 2 | Bernardo Quintana |

#### InstrumentoInversion

| ID | Descripción |
|----|-------------|
| 0 | Tickets |
| 1 | Consultorios |
| 2 | Locales |

#### Estado

| ID | Descripción |
|----|-------------|
| 0 | Activo |
| 1 | En seguimiento |
| 2 | Cita agendada |
| 3 | Conversación abandonada |

---

## Integraciones Externas

### WhatsApp Business API
- **Uso:** Envío y recepción de mensajes
- **Phone Number ID:** 632563839939367
- **Credencial n8n:** WhatsApp St Austin

### Supabase
- **Uso:** Base de datos PostgreSQL
- **Funciones RPC para búsqueda vectorial:**
  - `match_kb_chunks` - Búsqueda en Knowledge Base
  - `match_propiedades` - Búsqueda en propiedades

### OpenRouter
- **Uso:** Acceso a modelos Claude de Anthropic
- **Modelos utilizados:**
  - Claude Sonnet 4.5 (Agente principal)
  - Claude 3.7 Sonnet (Segmentación inicial)

### OpenAI
- **Uso:** Generación de embeddings
- **Modelo:** text-embedding-ada-002

### HubSpot
- **Uso:** CRM - Sincronización de contactos
- **Operación:** Crear contacto + asignar propiedad "responsable"

### Google Calendar
- **Uso:** Agendamiento de citas
- **Calendar ID:** Citas Prospectos Chatbot
- **Conferencia:** Google Meet automático
- **Horarios:**
  - Presencial: 9am - 6pm
  - Online: 9am - 8pm

### Google Sheets
- **Uso:** CRM individual por asesor
- **Hoja Global:** Registro centralizado de asignaciones

### Gmail
- **Uso:** Notificaciones a asesores
- **CC:** eloisa.berrueto@pompano.mx

### Google Drive
- **Uso:** Almacenamiento de brief/presentación del proyecto
- **File ID:** 1fGEkztKDlpZ5ZsrIGgna3uT1Pe6diTgX

---

## Enlaces de Hojas de Asesores

### Hojas Individuales por Asesor

| Asesor | Enlace Google Sheets |
|--------|---------------------|
| Carlos Rios | [Abrir hoja](https://docs.google.com/spreadsheets/d/16DwY7VYSzJkgsjcdsyqLlcuF0SlsBIcrhsQek3xvLjA) |
| Miguel Tapia | [Abrir hoja](https://docs.google.com/spreadsheets/d/1V6VYK3tSseLWl2I108_zg_jbDOyT1ralXQfmdSuabwY) |
| Alejandra Barillas | [Abrir hoja](https://docs.google.com/spreadsheets/d/1Z0JB-HPEVjsF_8iKFW-lzKlBpPQSAEBppUAwSA-NZYQ) |
| Mabel | [Abrir hoja](https://docs.google.com/spreadsheets/d/1QghL3E-fBTSvYJiNweCbCN23xD6V_eJ8iiZq91O5Mbc) |
| Alex García | [Abrir hoja](https://docs.google.com/spreadsheets/d/1XAmpRVZGWpgy81Ms5BrN-BY_Agoj3rt2UrWMZVuGd0g) |
| Lluvia | [Abrir hoja](https://docs.google.com/spreadsheets/d/18bfga_fHDUl9No_2kIiRT1FilVvCDU0Tox8DLUqPq0c) |
| Jhona | [Abrir hoja](https://docs.google.com/spreadsheets/d/1RLDVC57aeUDBHzavrXqEW_imw5OfuqOlTPFPJZK3HS0) |
| Rafa Marín | [Abrir hoja](https://docs.google.com/spreadsheets/d/1X6BHRRkfTqQQWGT5I5GzmX6wTq1X6daUynvJi3QlSyM) |
| Abraham Pérez | [Abrir hoja](https://docs.google.com/spreadsheets/d/1bHjdaetQydesvtpE2dd5jB2gBjJlxD7Ag-qX-0MuydY) |

### Hoja Global (Resumen)

| Documento | Enlace |
|-----------|--------|
| Hoja GLOBAL | [Abrir hoja](https://docs.google.com/spreadsheets/d/1Hxlsmv6X3kEqytcTagKnghLEkHFCKcOQwlH7Mxv9dWg) |

### Columnas en Hojas de Asesores

| Columna | Descripción |
|---------|-------------|
| Nombre | Nombre completo del cliente |
| Número de teléfono | WhatsApp del cliente |
| Correo electrónico | Email del cliente |
| Ubicación de interés | Distrito Médico / Bernardo Quintana |
| Instrumento de interés | Consultorio / Local / Ticket |
| Presupuesto | Monto en MXN |
| Tipo de Lead | Caliente / Tibio / Frío |
| Profesión | Ocupación del cliente |
| ¿Tiene cita agendada? | Sí / No |
| Modalidad de la cita | Presencial / Videoconferencia |
| ¿Contactado? | No / Sí / REASIGNADO |
| Notas del asesor | Campo libre para notas |
| Evidencia del contacto | Captura o descripción |
| Fecha | Fecha de asignación |

---

## Flujo de Conversación del Bot

### Ejemplo de Conversación Típica

```
👤 Usuario: Hola, me interesa información sobre sus consultorios

🤖 Eloísa: ¡Hola! Bienvenido a St. Austin. Me da gusto saludarte.
           ¿Te interesa conocer más sobre nuestros Consultorios médicos
           o Locales comerciales? ¿O tienes alguna otra consulta?

👤 Usuario: Consultorios, por favor

🤖 Eloísa: Excelente elección. Tenemos consultorios disponibles en dos
           ubicaciones estratégicas:

           📍 Distrito Médico (apertura Sept 2027)
           📍 Bernardo Quintana (apertura Ago 2028)

           ¿Cuál te interesa más? ¿Buscas para uso propio o como inversión?

👤 Usuario: Distrito Médico, para invertir

🤖 Eloísa: Perfecto. Los consultorios en Distrito Médico van desde
           $2,000,000 hasta $3,400,000 MXN. Contamos con financiamiento
           hasta 24 meses sin intereses.

           ¿Con quién tengo el gusto?

👤 Usuario: Soy Carlos García, médico

🤖 Eloísa: Mucho gusto, Carlos. ¿Qué presupuesto tienes contemplado
           para esta inversión?

👤 Usuario: Alrededor de 2.5 millones

🤖 Eloísa: Excelente, tenemos opciones que se ajustan perfectamente.
           ¿Me podrías compartir tu correo electrónico para enviarte
           más información?

👤 Usuario: carlos.garcia@gmail.com

🤖 Eloísa: Gracias, Carlos. Para darte información más detallada y
           resolver todas tus dudas, ¿te gustaría agendar una cita
           presencial (10am-6pm) o en línea (10am-8pm)?

👤 Usuario: En línea el viernes a las 11am

🤖 Eloísa: ¡Listo, Carlos! Tu cita quedó agendada para el viernes 20
           de diciembre a las 11:00 AM por videoconferencia.

           Un asesor se pondrá en contacto contigo. ¡Gracias por tu
           interés en St. Austin!
```

### Manejo de Casos Especiales

#### Usuario No Calificado (Empleo/Proveedores)

```
👤 Usuario: Hola, busco trabajo como recepcionista

🤖 Eloísa: Gracias por tu interés en St. Austin.

           Para temas de:
           • Empleo y Proveedores: info@st-austin.mx
           • ¿Eres asesor de ventas?: lluvia.gonzalezrealestate@gmail.com
           • Inversión: Continúa conmigo
```

#### Tickets (Solo Distrito Médico)

```
👤 Usuario: ¿Tienen tickets en Bernardo Quintana?

🤖 Eloísa: Bernardo Quintana cuenta con consultorios y locales.
           Los tickets están disponibles únicamente en Distrito Médico
           desde $300,000 MXN.

           ¿Te interesa conocer más sobre Distrito Médico?
```

---

## Mantenimiento

### Tareas Periódicas

| Tarea | Frecuencia | Descripción |
|-------|------------|-------------|
| Revisar logs de n8n | Diario | Verificar ejecuciones fallidas |
| Backup base de datos | Semanal | Exportar datos de Supabase |
| Actualizar Knowledge Base | Según cambios | Ejecutar workflow de poblado |
| Revisar métricas de asesores | Semanal | Verificar balance de asignaciones |
| Limpiar historial antiguo | Mensual | Archivar conversaciones viejas |

### Monitoreo

#### Workflows a Vigilar

| Workflow | Qué verificar |
|----------|---------------|
| Flujo Principal | Errores en WhatsApp API, respuestas de IA |
| Asignar Asesor | Distribución equitativa, errores de Google Sheets |
| Reasignación | Clientes reasignados incorrectamente |
| Seguimiento | Mensajes duplicados, horarios correctos |

#### Alertas Recomendadas

- Workflow fallido más de 3 veces consecutivas
- Cola de mensajes de WhatsApp atrasada
- Error de autenticación en cualquier servicio
- Rate limit de OpenRouter/OpenAI

### Troubleshooting Común

| Problema | Posible Causa | Solución |
|----------|---------------|----------|
| Bot no responde | Webhook desconectado | Verificar webhook en WhatsApp Business |
| Respuestas lentas | Rate limit de API | Verificar cuotas de OpenRouter |
| No se asigna asesor | Round-robin atascado | Verificar tabla RoundRobinPointer |
| Citas no se crean | Credenciales Calendar | Renovar OAuth de Google |
| Seguimiento no funciona | Horario incorrecto | Verificar timezone del servidor |

---

*Documentación generada para el proyecto St. Austin Chatbot*
