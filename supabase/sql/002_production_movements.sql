-- =====================================================================
-- 002_production_movements.sql
-- Tabla NUEVA que registra cada movimiento de produccion. Esta tabla es
-- la unica forma de avanzar la produccion: la tabla original
-- "Pedidos Prueba" NUNCA se modifica (regla critica de negocio).
-- =====================================================================

create table if not exists public.production_movements (
  id uuid primary key default gen_random_uuid(),

  -- ID logico de 10 digitos generado deterministicamente a partir de
  -- PedidoNo + Referencia + Talla + MaterialP + ColorP (ver
  -- src/lib/itemId.js en el frontend y public.generar_item_id en SQL).
  item_id text not null check (item_id ~ '^[0-9]{10}$'),

  order_number text not null,              -- Pedidos Prueba.PedidoNo
  reference text,                          -- Pedidos Prueba.Referencia / NombreR
  size text,                               -- Pedidos Prueba.Talla

  quantity integer not null check (quantity > 0),

  from_process text not null check (from_process in ('Refilado', 'Acabado', 'Mateado', 'Empaque')),
  -- 'Completado' es el estado terminal: se usa cuando Empaque marca la
  -- producción como finalizada (from_process='Empaque', to_process='Completado').
  to_process text not null check (to_process in ('Acabado', 'Mateado', 'Empaque', 'Completado')),

  user_id uuid not null references public.profiles(id),
  observation text,

  created_at timestamptz not null default now(),

  -- Refuerza a nivel de base de datos el flujo de negocio valido
  -- (seccion 6 del documento): cada rol solo puede mover un item al
  -- siguiente proceso permitido.
  --   Refilado  -> Acabado | Mateado
  --   Acabado   -> Empaque
  --   Mateado   -> Empaque
  --   Empaque   -> Completado
  constraint chk_valid_process_transition check (
    (from_process = 'Refilado' and to_process in ('Acabado', 'Mateado'))
    or (from_process = 'Acabado' and to_process = 'Empaque')
    or (from_process = 'Mateado' and to_process = 'Empaque')
    or (from_process = 'Empaque' and to_process = 'Completado')
  )
);

create index if not exists idx_movements_item_id on public.production_movements(item_id);
create index if not exists idx_movements_order_number on public.production_movements(order_number);
create index if not exists idx_movements_user_id on public.production_movements(user_id);
create index if not exists idx_movements_created_at on public.production_movements(created_at desc);

alter table public.production_movements enable row level security;

-- Historial inmutable: no se define ninguna politica de UPDATE/DELETE,
-- por lo que quedan bloqueados para cualquier rol distinto de
-- service_role. Las politicas de SELECT/INSERT estan en
-- 006_rls_policies.sql.
