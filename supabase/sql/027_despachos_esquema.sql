-- =====================================================================
-- 027_despachos_esquema.sql
-- Modulo Despachos (Fase 1 — operado unicamente por el rol Empaque, ver
-- plan). Agrupa 1 o varios pedidos ya 100% completos en Empaque en un
-- "despacho" (salida) con consecutivo D1000, D1001, ... y los reparte en
-- N bultos numerados.
--
-- Diseño deliberado para no bloquear una Fase 2 futura (despachos
-- parciales, rol "despachos" propio):
--   - despacho_ordenes NO tiene unique(order_number) solo — solo
--     unique(despacho_id, order_number). "Un pedido ya fue despachado"
--     se valida en la logica del RPC crear_despacho (030), no con una
--     constraint rigida, para poder relajarla despues sin migrar de nuevo.
--   - despacho_orden_bultos es un borrador editable en BD (no solo en
--     memoria del navegador) mientras asignacion_confirmada=false: no es
--     un "hecho ya ocurrido" como production_movements/returns, es una
--     decision todavia en proceso. Una vez confirmado, queda tan
--     inmutable como cualquier otra tabla de esta app (ver RLS en 029).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Secuencia del consecutivo. Un sequence es seguro bajo concurrencia
-- (a diferencia de select max(numero_despacho)+1), y empieza en 1000
-- porque asi lo pidio el usuario (D1000, D1001, D1002, ...).
-- ---------------------------------------------------------------------
create sequence if not exists public.despachos_numero_despacho_seq
  start with 1000
  increment by 1;

-- ---------------------------------------------------------------------
-- despachos: una fila por salida creada. consecutivo es una columna
-- generada (mismo patron que item_id en p_pedidosh, ver
-- 016_item_id_materializado.sql) para que nunca quede desincronizada de
-- numero_despacho.
-- ---------------------------------------------------------------------
create table if not exists public.despachos (
  id uuid primary key default gen_random_uuid(),
  numero_despacho integer not null default nextval('public.despachos_numero_despacho_seq') unique,
  consecutivo text generated always as ('D' || numero_despacho::text) stored,
  total_bultos integer not null check (total_bultos > 0),
  asignacion_confirmada boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  confirmed_by uuid references public.profiles(id),
  confirmed_at timestamptz
);

alter sequence public.despachos_numero_despacho_seq owned by public.despachos.numero_despacho;

create index if not exists idx_despachos_created_at on public.despachos(created_at);

-- ---------------------------------------------------------------------
-- despacho_ordenes: que pedidos pertenecen a que despacho.
-- ---------------------------------------------------------------------
create table if not exists public.despacho_ordenes (
  id uuid primary key default gen_random_uuid(),
  despacho_id uuid not null references public.despachos(id) on delete cascade,
  order_number text not null,
  created_at timestamptz not null default now(),
  unique (despacho_id, order_number)
);

create index if not exists idx_despacho_ordenes_order_number on public.despacho_ordenes(order_number);
create index if not exists idx_despacho_ordenes_despacho on public.despacho_ordenes(despacho_id);

-- ---------------------------------------------------------------------
-- despacho_bultos: los N bultos declarados en "Crear Salida", cada uno
-- con su peso. Se crean todos de una vez, junto con el despacho.
-- ---------------------------------------------------------------------
create table if not exists public.despacho_bultos (
  id uuid primary key default gen_random_uuid(),
  despacho_id uuid not null references public.despachos(id) on delete cascade,
  bulto_numero integer not null check (bulto_numero >= 1),
  peso numeric(10,2) not null check (peso > 0),
  created_at timestamptz not null default now(),
  unique (despacho_id, bulto_numero)
);

create index if not exists idx_despacho_bultos_despacho on public.despacho_bultos(despacho_id);

-- ---------------------------------------------------------------------
-- despacho_orden_bultos: asignacion pedido<->bulto (N a N — un pedido
-- puede ir en varios bultos, un bulto puede llevar varios pedidos). La
-- FK compuesta contra despacho_ordenes garantiza a nivel de esquema que
-- nunca se asigna un bulto a un pedido que no pertenece a ese despacho.
-- ---------------------------------------------------------------------
create table if not exists public.despacho_orden_bultos (
  id uuid primary key default gen_random_uuid(),
  despacho_id uuid not null,
  order_number text not null,
  bulto_numero integer not null check (bulto_numero >= 1),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (despacho_id, order_number, bulto_numero),
  foreign key (despacho_id, order_number)
    references public.despacho_ordenes(despacho_id, order_number)
    on delete cascade,
  foreign key (despacho_id)
    references public.despachos(id)
    on delete cascade
);

create index if not exists idx_despacho_orden_bultos_despacho on public.despacho_orden_bultos(despacho_id);

-- ---------------------------------------------------------------------
-- Trigger de validacion: un CHECK simple no puede comparar contra otra
-- tabla, asi que el rango 1..total_bultos y el bloqueo post-confirmacion
-- se validan aqui. Es defensa en profundidad ademas de la RLS de 029 —
-- si algun dia la RLS cambia sin querer, esto sigue protegiendo.
-- ---------------------------------------------------------------------
create or replace function public.fn_validar_despacho_orden_bulto()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer;
  v_confirmado boolean;
begin
  select total_bultos, asignacion_confirmada
    into v_total, v_confirmado
    from public.despachos
    where id = new.despacho_id;

  if v_total is null then
    raise exception 'El despacho no existe.';
  end if;

  if v_confirmado then
    raise exception 'Este despacho ya fue confirmado: no se pueden modificar sus bultos.';
  end if;

  if new.bulto_numero < 1 or new.bulto_numero > v_total then
    raise exception 'Número de bulto fuera de rango (1-%): %', v_total, new.bulto_numero;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_despacho_orden_bulto on public.despacho_orden_bultos;
create trigger trg_validar_despacho_orden_bulto
  before insert or update on public.despacho_orden_bultos
  for each row execute function public.fn_validar_despacho_orden_bulto();

comment on table public.despachos is 'Salidas/despachos creados por Empaque (Fase 1). consecutivo = D + numero_despacho, empieza en D1000.';
comment on table public.despacho_ordenes is 'Pedidos que pertenecen a cada despacho. Sin unique(order_number) a proposito — ver comentario de cabecera (Fase 2: despachos parciales).';
comment on table public.despacho_bultos is 'Los N bultos declarados al crear la salida, con su peso.';
comment on table public.despacho_orden_bultos is 'Asignacion pedido<->bulto. Borrador editable en BD mientras despachos.asignacion_confirmada=false (ver RLS en 029); inmutable despues.';
