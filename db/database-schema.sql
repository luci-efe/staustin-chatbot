-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.Asesor (
  idAsesor bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nombreAsesor text,
  correoAsesor text UNIQUE,
  usuariosAsignados bigint DEFAULT '0'::bigint,
  usuariosNoContactados bigint DEFAULT '0'::bigint,
  puntaje bigint DEFAULT '0'::bigint,
  enlace text,
  CONSTRAINT Asesor_pkey PRIMARY KEY (idAsesor)
);
CREATE TABLE public.Asesor_BQ (
  idAsesor bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nombreAsesor text,
  correoAsesor text UNIQUE,
  usuariosAsignados bigint DEFAULT '0'::bigint,
  usuariosNoContactados bigint DEFAULT '0'::bigint,
  puntaje bigint DEFAULT '0'::bigint,
  enlace text,
  CONSTRAINT Asesor_BQ_pkey PRIMARY KEY (idAsesor)
);
CREATE TABLE public.Cliente (
  idCliente bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  fechaDeCreacion timestamp with time zone NOT NULL DEFAULT now(),
  idUbicacionInteres bigint,
  nombre text,
  numeroTelefono text UNIQUE,
  correoElectronico text,
  esperandoRespuesta bigint DEFAULT '8'::bigint,
  fechaUltimoMensaje timestamp with time zone,
  citaAgendada boolean NOT NULL DEFAULT false,
  asesorRespondio boolean NOT NULL DEFAULT false,
  presupuesto text,
  profesion text,
  idEspecialidadPropiedad bigint,
  idEstado bigint NOT NULL DEFAULT '0'::bigint,
  existeEnHubSpot boolean NOT NULL DEFAULT false,
  idInstrumentoInversion bigint,
  apellido text,
  correoAsesor text,
  fechaAsignacionAsesor timestamp with time zone,
  idCita text,
  briefCompartido boolean DEFAULT false,
  leadStatus text,
  modalidadCita text,
  fechaCita text,
  origen text,
  CONSTRAINT Cliente_pkey PRIMARY KEY (idCliente),
  CONSTRAINT fk_cliente_especialidad_propiedad FOREIGN KEY (idEspecialidadPropiedad) REFERENCES public.Especialidad(idEspecialidad),
  CONSTRAINT fk_cliente_estado FOREIGN KEY (idEstado) REFERENCES public.Estado(idEstado),
  CONSTRAINT fk_cliente_ubicacion_interes FOREIGN KEY (idUbicacionInteres) REFERENCES public.Ubicacion(idUbicacion),
  CONSTRAINT fk_cliente_instrumento_inversion FOREIGN KEY (idInstrumentoInversion) REFERENCES public.InstrumentoInversion(idInstrumentoInversion)
);
CREATE TABLE public.Especialidad (
  idEspecialidad bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  especialidadDescripcion character varying NOT NULL UNIQUE,
  CONSTRAINT Especialidad_pkey PRIMARY KEY (idEspecialidad)
);
CREATE TABLE public.Estado (
  idEstado bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  estadoDescripcion character varying NOT NULL,
  CONSTRAINT Estado_pkey PRIMARY KEY (idEstado)
);
CREATE TABLE public.HistorialConversacion (
  idHistorialConversacion bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  idCliente bigint NOT NULL,
  mensaje jsonb,
  fechaDeEnvio timestamp with time zone NOT NULL DEFAULT now(),
  remitente character varying NOT NULL DEFAULT 'user'::character varying,
  CONSTRAINT HistorialConversacion_pkey PRIMARY KEY (idHistorialConversacion),
  CONSTRAINT fk_historial_conversacion_cliente FOREIGN KEY (idCliente) REFERENCES public.Cliente(idCliente)
);
CREATE TABLE public.InstrumentoInversion (
  idInstrumentoInversion bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  descripcionInstrumentoInversion character varying NOT NULL,
  CONSTRAINT InstrumentoInversion_pkey PRIMARY KEY (idInstrumentoInversion)
);
CREATE TABLE public.KnowledgeBaseChunks (
  embedding USER-DEFINED NOT NULL,
  content text,
  metadata jsonb,
  idChunk bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idDocumento bigint,
  CONSTRAINT KnowledgeBaseChunks_pkey PRIMARY KEY (idChunk),
  CONSTRAINT KnowledgeBaseChunks_idDocumento_fkey FOREIGN KEY (idDocumento) REFERENCES public.KnowledgeBaseDocumento(idDocumento)
);
CREATE TABLE public.KnowledgeBaseDocumento (
  idDocumento bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  idUbicacion bigint,
  titulo text,
  detalles text,
  CONSTRAINT KnowledgeBaseDocumento_pkey PRIMARY KEY (idDocumento)
);
CREATE TABLE public.Propiedad (
  idPropiedad bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  nombrePropiedad character varying NOT NULL,
  tamanio character varying NOT NULL,
  precio character varying NOT NULL,
  descripcionPropiedad character varying NOT NULL,
  idInstrumentoInversion bigint NOT NULL,
  idUbicacion bigint NOT NULL,
  idEspecialidad bigint NOT NULL,
  CONSTRAINT Propiedad_pkey PRIMARY KEY (idPropiedad),
  CONSTRAINT fk_propiedad_ubicacion FOREIGN KEY (idUbicacion) REFERENCES public.Ubicacion(idUbicacion),
  CONSTRAINT fk_propiedad_especialidad FOREIGN KEY (idEspecialidad) REFERENCES public.Especialidad(idEspecialidad),
  CONSTRAINT fk_propiedad_instrumento FOREIGN KEY (idInstrumentoInversion) REFERENCES public.InstrumentoInversion(idInstrumentoInversion)
);
CREATE TABLE public.PropiedadEmbeddings (
  idPropiedad bigint,
  embedding USER-DEFINED NOT NULL,
  content text,
  metadata jsonb,
  idPropiedadEmbeddings bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  CONSTRAINT PropiedadEmbeddings_pkey PRIMARY KEY (idPropiedadEmbeddings),
  CONSTRAINT PropiedadEmbeddings_idPropiedad_fkey FOREIGN KEY (idPropiedad) REFERENCES public.Propiedad(idPropiedad)
);
CREATE TABLE public.RoundRobinPointer (
  correoAsesor text NOT NULL,
  siguienteAsesor bigint,
  nombreAsesor text,
  CONSTRAINT RoundRobinPointer_pkey PRIMARY KEY (correoAsesor)
);
CREATE TABLE public.RoundRobinPointer_BQ (
  correoAsesor text NOT NULL,
  siguienteAsesor bigint,
  nombreAsesor text,
  CONSTRAINT RoundRobinPointer_BQ_pkey PRIMARY KEY (correoAsesor)
);
CREATE TABLE public.Ubicacion (
  idUbicacion bigint GENERATED ALWAYS AS IDENTITY NOT NULL UNIQUE,
  ubicacionDescripcion character varying NOT NULL,
  CONSTRAINT Ubicacion_pkey PRIMARY KEY (idUbicacion)
);
