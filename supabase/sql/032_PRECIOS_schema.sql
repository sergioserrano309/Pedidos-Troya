-- =====================================================================
-- ESQUEMA DE BASE DE DATOS: PRECIOS DE SUELAS
-- =====================================================================
-- Qué hace este archivo:
--   Crea las tablas necesarias para guardar el listado de precios de
--   suelas de forma ordenada (sin repetir texto innecesariamente).
--
-- Cómo usarlo:
--   1. Entra a tu proyecto de Supabase.
--   2. Ve a "SQL Editor" (menú de la izquierda).
--   3. Pega TODO este archivo y dale "Run".
--   4. Cuando termine sin errores, sigue con el archivo 02_datos_iniciales.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLA 1: materiales
-- Catálogo de materiales con los que se hace una suela
-- (T.R., EXPANSO, GOMAFLEX, PVC...)
-- ---------------------------------------------------------------------
create table if not exists materiales (
    id      bigint generated always as identity primary key,
    nombre  text not null unique
);
comment on table materiales is 'Catálogo de materiales de fabricación de la suela';

-- ---------------------------------------------------------------------
-- TABLA 2: colores
-- ---------------------------------------------------------------------
create table if not exists colores (
    id      bigint generated always as identity primary key,
    nombre  text not null unique
);
comment on table colores is 'Catálogo de colores disponibles para una suela';

-- ---------------------------------------------------------------------
-- TABLA 3: clientes
-- 'TODOS' = precio general, aplica a cualquier cliente.
-- Un nombre propio (ej. FIDENCY) = precio especial SOLO para ese cliente.
-- ---------------------------------------------------------------------
create table if not exists clientes (
    id      bigint generated always as identity primary key,
    nombre  text not null unique
);
comment on table clientes is 'TODOS = precio general. Un nombre propio = excepcion de precio para ese cliente';

-- ---------------------------------------------------------------------
-- TABLA 4: tallas
-- Rangos de tallas en los que se vende una suela (ej. 34-40)
-- ---------------------------------------------------------------------
create table if not exists tallas (
    id         bigint generated always as identity primary key,
    rango      text not null unique,
    talla_min  smallint not null,
    talla_max  smallint not null,
    constraint tallas_rango_valido check (talla_max >= talla_min)
);
comment on table tallas is 'Rangos de tallas disponibles, ej. 34-40';

-- ---------------------------------------------------------------------
-- TABLA 5: referencias
-- Catálogo maestro de referencias (modelos) de suela: ADRIA, BOSTON...
-- ---------------------------------------------------------------------
create table if not exists referencias (
    id      bigint generated always as identity primary key,
    codigo  text not null unique
);
comment on table referencias is 'Catalogo maestro de referencias (modelos) de suela';

-- ---------------------------------------------------------------------
-- TABLA 6: precios_suelas  (tabla principal)
-- Cada fila = una combinacion unica de
-- referencia + material + cliente + color + caracteristicas + talla,
-- con sus dos precios: distribuidor y fabricante.
-- ---------------------------------------------------------------------
create table if not exists precios_suelas (
    id                    bigint generated always as identity primary key,

    -- llaves foraneas (conectan con los catalogos de arriba)
    referencia_id         bigint not null references referencias(id) on delete restrict,
    material_id           bigint not null references materiales(id) on delete restrict,
    cliente_id            bigint not null references clientes(id)   on delete restrict,
    color_id              bigint not null references colores(id)   on delete restrict,
    talla_id              bigint not null references tallas(id)    on delete restrict,

    -- caracteristicas de la suela (Si/No)
    bicolor               boolean not null default false,
    vira                  boolean not null default false,
    esterilla             boolean not null default false,
    acabado               boolean not null default false,
    aplique               boolean not null default false,

    -- comentario libre. Se guarda vacio ('') cuando el Excel decia "na"
    comentario            text not null default '',

    -- precios
    precio_distribuidor   numeric(12,2) not null default 0 check (precio_distribuidor >= 0),
    precio_fabricante     numeric(12,2) not null default 0 check (precio_fabricante >= 0),

    creado_en             timestamptz not null default now(),
    actualizado_en        timestamptz not null default now(),

    -- evita crear dos veces la MISMA combinacion de variante
    constraint precios_suelas_variante_unica unique (
        referencia_id, material_id, cliente_id, color_id,
        bicolor, vira, esterilla, acabado, aplique,
        talla_id, comentario
    )
);
comment on table precios_suelas is 'Precio distribuidor/fabricante para cada combinacion unica de referencia+material+cliente+color+opciones+talla';

-- Indices para que las busquedas por cada catalogo sean rapidas
-- (Postgres NO crea estos indices automaticamente para llaves foraneas)
create index if not exists idx_precios_referencia on precios_suelas(referencia_id);
create index if not exists idx_precios_material    on precios_suelas(material_id);
create index if not exists idx_precios_cliente     on precios_suelas(cliente_id);
create index if not exists idx_precios_color       on precios_suelas(color_id);
create index if not exists idx_precios_talla       on precios_suelas(talla_id);

-- ---------------------------------------------------------------------
-- Mantener "actualizado_en" al dia automaticamente cuando el comercial
-- edite un precio
-- ---------------------------------------------------------------------
create or replace function set_actualizado_en()
returns trigger as $$
begin
    new.actualizado_en = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists trg_precios_actualizado_en on precios_suelas;
create trigger trg_precios_actualizado_en
before update on precios_suelas
for each row
execute function set_actualizado_en();

-- =====================================================================
-- SEGURIDAD (RLS) -- IMPORTANTE, LEER ANTES DE CONECTAR TU PAGINA WEB
-- =====================================================================
-- Por defecto, si una tabla NO tiene "Row Level Security" (RLS)
-- habilitado, cualquiera que tenga la llave publica de tu proyecto
-- (la "anon key") puede leer y escribir sin restriccion.
--
-- Estas lineas estan comentadas a proposito: decide primero como se
-- va a autenticar tu "usuario comercial" en la pagina, y luego activa
-- las politicas que correspondan. Ejemplo (MUY permisivo, solo de
-- referencia, no lo uses tal cual en produccion):
--
-- alter table precios_suelas enable row level security;
-- create policy "lectura publica" on precios_suelas
--   for select using (true);
-- create policy "escritura solo autenticados" on precios_suelas
--   for insert with check (auth.role() = 'authenticated');
