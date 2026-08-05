-- =====================================================================
-- 010_order_destino.sql
-- Destino (Acabado, Mateado o Empaque directo) que Refilado confirma UNA
-- SOLA VEZ para TODO un pedido completo, ya que un pedido nunca se
-- reparte entre Acabado y Mateado. Se muestra en el encabezado del
-- detalle de la orden y evita tener que volver a preguntar el destino
-- en cada item que Refilado procese.
--
-- La primary key sobre order_number es lo que garantiza "solo se puede
-- confirmar una vez": un segundo intento de insertar para el mismo
-- pedido falla automáticamente.
-- =====================================================================

create table if not exists public.order_destino (
  order_number text primary key,
  destino text not null check (destino in ('Acabado', 'Mateado', 'Empaque')),
  confirmed_by uuid not null references public.profiles(id),
  confirmed_at timestamptz not null default now()
);

alter table public.order_destino enable row level security;

drop policy if exists "order_destino_select_authenticated" on public.order_destino;
create policy "order_destino_select_authenticated"
on public.order_destino
for select
to authenticated
using (true);

-- Solo Refilado puede confirmar el destino de un pedido.
drop policy if exists "order_destino_insert_refilado" on public.order_destino;
create policy "order_destino_insert_refilado"
on public.order_destino
for insert
to authenticated
with check (
  confirmed_by = (select id from public.profiles where auth_id = auth.uid())
  and exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'refilado'
  )
);

-- Sin update/delete: una vez confirmado, es inmutable.

grant select, insert on public.order_destino to authenticated;
revoke update, delete on public.order_destino from authenticated, anon;
