-- =====================================================================
-- 003_returns.sql
-- Tabla NUEVA para registrar devoluciones (solo rol Comercial). Igual
-- que production_movements, jamas modifica "Pedidos Prueba".
--
-- Campos alineados con el modal "Registrar Devolucion" de
-- produccion_app.html: pedido, talla, cantidad, causal, proceso que
-- fallo, accion (MOLIDO/REPROCESO), destino de reproceso y observacion.
-- =====================================================================

create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),

  item_id text not null check (item_id ~ '^[0-9]{10}$'),
  order_number text not null,              -- Pedidos Prueba.PedidoNo
  size text,                               -- Pedidos Prueba.Talla

  quantity integer not null check (quantity > 0),

  -- Causal segun el select #dev-causal del frontend
  causal text not null check (causal in ('QA_INTERNO', 'CLIENTE')),

  -- Proceso que fallo, segun el select #dev-proceso del frontend
  failed_process text not null check (failed_process in ('Inyección', 'Refilado', 'Acabado', 'Mateado')),

  -- Accion segun los radio buttons #dev-molido / #dev-reproceso
  action text not null check (action in ('MOLIDO', 'REPROCESO')),

  -- Solo aplica si action = 'REPROCESO' (select #dev-reproceso-destino)
  reprocess_destination text check (reprocess_destination in ('Refilado', 'Acabado', 'Mateado')),

  observation text,                        -- textarea #dev-obs

  user_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),

  constraint chk_reprocess_destination_required check (
    (action = 'REPROCESO' and reprocess_destination is not null)
    or (action = 'MOLIDO' and reprocess_destination is null)
  )
);

create index if not exists idx_returns_item_id on public.returns(item_id);
create index if not exists idx_returns_order_number on public.returns(order_number);
create index if not exists idx_returns_user_id on public.returns(user_id);
create index if not exists idx_returns_created_at on public.returns(created_at desc);

alter table public.returns enable row level security;

-- Historial inmutable: no hay politicas de UPDATE/DELETE. Politicas de
-- SELECT/INSERT en 006_rls_policies.sql.
