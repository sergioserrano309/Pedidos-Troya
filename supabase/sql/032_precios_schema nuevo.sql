-- =====================================================================
-- ESQUEMA NUEVO - BASE DE DATOS DE PRECIOS DE SUELAS (v2)
-- =====================================================================
-- Qué hace este archivo:
--   Crea 6 tablas con la estructura definitiva para la base de precios:
--   - Catálogos: referencias, materiales, colores, clientes, tallas
--   - Central: precios_suelas (438 registros)
--
-- CAMBIOS respecto a versión anterior:
--   * Tabla colores ahora tiene: nombre + categoria (NEGRO o COLORES)
--   * Se excluye material "ACABADOS" (era error)
--   * Se cargan 438 registros (no 63)
--
-- Cómo usarlo:
--   1. Entra a tu proyecto en supabase.com → SQL Editor
--   2. Pega TODO este archivo en una consulta nueva
--   3. Dale "Run"
--   4. Cuando termine sin errores (mensaje verde), ejecuta 06_cargar_datos.sql
-- =====================================================================

-- =====================================================================
-- TABLA 1: referencias
-- Catálogo maestro de modelos de suela (LUCIANA, EIMY, GRETA, JORDAN...)
-- =====================================================================
create table if not exists referencias (
    id              bigint generated always as identity primary key,
    codigo          text not null unique,
    creado_en       timestamptz not null default now()
);
comment on table referencias is 'Catalogo maestro de 205 modelos/referencias de suela';
comment on column referencias.codigo is 'Nombre del modelo: LUCIANA, EIMY, GRETA, JORDAN, etc.';

-- =====================================================================
-- TABLA 2: materiales
-- Tipo de material: T.R., EXPANSO, GOMAFLEX, PVC, PVC CRISTAL, TPU
-- =====================================================================
create table if not exists materiales (
    id          bigint generated always as identity primary key,
    nombre      text not null unique,
    creado_en   timestamptz not null default now()
);
comment on table materiales is 'Tipos de material de fabricacion de la suela';

-- =====================================================================
-- TABLA 3: colores
-- Colores específicos (NEGRO, MELON-CREPES, MATRIX, VERDE ACUARELA, etc.)
-- + su categoría (NEGRO o COLORES)
-- =====================================================================
create table if not exists colores (
    id          bigint generated always as identity primary key,
    nombre      text not null unique,
    categoria   text not null check (categoria in ('NEGRO', 'COLORES')),
    creado_en   timestamptz not null default now()
);
comment on table colores is 'Colores específicos de suela + su categoría (NEGRO o COLORES)';
comment on column colores.nombre is 'Color detallado: NEGRO, COLORES, MELON-CREPES, MATRIX, VERDE ACUARELA, CRISTAL, CAFE, etc.';
comment on column colores.categoria is 'Agrupación: solo NEGRO o COLORES';

-- =====================================================================
-- TABLA 4: clientes
-- TODOS (precio general) + 13 clientes con precio especial
-- =====================================================================
create table if not exists clientes (
    id          bigint generated always as identity primary key,
    nombre      text not null unique,
    creado_en   timestamptz not null default now()
);
comment on table clientes is 'TODOS = precio general. Otro nombre = precio especial exclusivo para ese cliente';

-- =====================================================================
-- TABLA 5: tallas
-- Rangos de tallas (34-40, 27-33, 37-42, etc.)
-- =====================================================================
create table if not exists tallas (
    id          bigint generated always as identity primary key,
    rango       text not null unique,
    talla_min   smallint not null,
    talla_max   smallint not null,
    creado_en   timestamptz not null default now(),
    constraint tallas_rango_valido check (talla_max >= talla_min)
);
comment on table tallas is 'Rangos de tallas disponibles (34-40, 27-33, 37-42, etc.)';
comment on column tallas.rango is 'Formato: min-max, ej. 34-40';

-- =====================================================================
-- TABLA 6: precios_suelas (TABLA CENTRAL)
-- Cada fila = una combinación única de referencia + material + cliente
--             + color específico + características (bicolor, vira, etc.)
--             + talla + comentario
--
-- Con sus precios distribuidor/fabricante (con y sin IVA)
-- =====================================================================
create table if not exists precios_suelas (
    id                              bigint generated always as identity primary key,

    -- IDs hacia las tablas de catálogo (llaves foráneas)
    referencia_id                   bigint not null references referencias(id) on delete restrict,
    material_id                     bigint not null references materiales(id) on delete restrict,
    cliente_id                      bigint not null references clientes(id) on delete restrict,
    color_id                        bigint not null references colores(id) on delete restrict,
    talla_id                        bigint not null references tallas(id) on delete restrict,

    -- Características booleanas de la suela
    bicolor                         boolean not null default false,
    vira                            boolean not null default false,
    esterilla                       boolean not null default false,
    acabado                         boolean not null default false,
    aplique                         boolean not null default false,

    -- Comentario libre (vacío si no aplica)
    comentario                      text not null default '',

    -- PRECIOS DISTRIBUIDOR
    precio_distribuidor_con_iva     numeric(12,2) not null default 0 
        check (precio_distribuidor_con_iva >= 0),
    precio_distribuidor_sin_iva     numeric(12,2) not null default 0 
        check (precio_distribuidor_sin_iva >= 0),

    -- PRECIOS FABRICANTE
    precio_fabricante_con_iva       numeric(12,2) not null default 0 
        check (precio_fabricante_con_iva >= 0),
    precio_fabricante_sin_iva       numeric(12,2) not null default 0 
        check (precio_fabricante_sin_iva >= 0),

    -- Auditoría y referencias
    idluz                           text,  -- ID original para trazabilidad
    id_original                     text,  -- Concatenado del Excel para referencia

    -- Timestamps
    creado_en                       timestamptz not null default now(),
    actualizado_en                  timestamptz not null default now(),

    -- Restricción: evita crear dos veces la MISMA combinación
    constraint precios_suelas_variante_unica unique (
        referencia_id, material_id, cliente_id, color_id,
        bicolor, vira, esterilla, acabado, aplique,
        talla_id, comentario
    )
);
comment on table precios_suelas is 'Tabla central: 438 combinaciones de suela con precios distribuidor/fabricante (IVA incluido y excluido)';
comment on column precios_suelas.comentario is 'Campo libre para anotar variante especial (ej. MELONCREPES, MATRIX, etc.). Vacío si no aplica.';
comment on column precios_suelas.idluz is 'ID anterior para auditoría y seguimiento de cambios';
comment on column precios_suelas.id_original is 'ID concatenado del Excel (ref-material-cliente-color-opciones-talla-comentario)';

-- =====================================================================
-- INDICES - para que las búsquedas sean rápidas
-- =====================================================================
create index if not exists idx_precios_referencia 
    on precios_suelas(referencia_id);
create index if not exists idx_precios_material 
    on precios_suelas(material_id);
create index if not exists idx_precios_cliente 
    on precios_suelas(cliente_id);
create index if not exists idx_precios_color 
    on precios_suelas(color_id);
create index if not exists idx_precios_talla 
    on precios_suelas(talla_id);

-- Indices para búsquedas combinadas frecuentes
create index if not exists idx_precios_ref_mat_cli 
    on precios_suelas(referencia_id, material_id, cliente_id);
create index if not exists idx_precios_cli_ref 
    on precios_suelas(cliente_id, referencia_id);

-- =====================================================================
-- TRIGGER - Actualizar automáticamente "actualizado_en" cuando
-- el comercial edite un precio
-- =====================================================================
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
-- ROW LEVEL SECURITY (RLS) - IMPORTANTE LEER
-- =====================================================================
-- Por defecto, sin RLS habilitado, cualquiera con tu "anon key" (llave pública)
-- podría leer y modificar los precios.
--
-- Estas políticas están COMENTADAS a proposito. Descomenta y adapta
-- cuando estés listo para conectar tu página web de verdad, según cómo
-- autentiques al "usuario comercial".
--
-- Ejemplo MUY permisivo (NO USAR EN PRODUCCION):
--
-- alter table precios_suelas enable row level security;
-- create policy "lectura publica" on precios_suelas
--   for select using (true);
-- create policy "escritura solo autenticados" on precios_suelas
--   for insert with check (auth.role() = 'authenticated');
--
-- Para una setup más segura, consulta la documentación de Supabase.
-- =====================================================================

