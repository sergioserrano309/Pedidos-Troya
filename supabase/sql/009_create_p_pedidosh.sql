-- =====================================================================
-- 009_create_p_pedidosh.sql
-- Crear la tabla p_pedidosh que reemplaza a "Pedidos Prueba"
-- Estructura basada en las columnas reales del proyecto.
--
-- IMPORTANTE: ejecutar DESPUES de 001-008.
-- Si ya existe, este script no hace nada (IF NOT EXISTS).
-- =====================================================================

create table if not exists public.p_pedidosh (
  "PedidoNo" text not null,
  "FechaP" date,
  "Cliente" text,
  "Referencia" text not null,
  "NombreR" text,
  "Talla" text not null,
  "MaterialP" text,
  "ColorP" text,
  "Vira" text,
  "DetalleVira" text,
  "Acabado" text,
  "DetalleAcab" text,
  "Esterilla" text,
  "DetalleEsterilla" text,
  "Marquilla" text,
  "CantidadP" integer,
  "EstadoC" text,
  "Total01Iny" integer,
  "Total02Ref" integer,
  "Total03Pint" integer,
  "Total03Acab" integer,
  "Total03Ref" integer,
  "Total04Emp" integer,
  "Total05Env" integer,
  "Cerrado" boolean default false,
  "FechaCierre" date,
  "FechaCierreS" date,
  "Cancelado" boolean default false,
  "DetalleCancel" text,
  created_at timestamptz default now()
);

-- Comentario descriptivo
comment on table public.p_pedidosh is
  'Tabla de pedidos de produccion (replica de Pedidos Prueba). Solo lectura en la aplicacion. Importar datos desde CSV o sincronizar con ERP.';
