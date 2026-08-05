-- =====================================================================
-- 014_eliminacion_registros.sql
-- Permite eliminar un registro (movimiento) desde "Registros", con
-- motivo OBLIGATORIO, dejando un log inmutable de la eliminación
-- (log_eliminaciones). Reglas:
--   1. Solo el usuario que CREÓ el movimiento puede eliminarlo.
--   2. Solo se puede eliminar si es el movimiento MÁS RECIENTE de esa
--      talla (item_id) — si algo se creó después basándose en él, no se
--      puede borrar, para no dejar huecos de datos inconsistentes.
--   3. No existe una forma de borrar sin pasar por esta función: la
--      tabla production_movements sigue sin política de DELETE directa,
--      así que el motivo queda garantizado siempre.
-- =====================================================================

create table if not exists public.log_eliminaciones (
  id uuid primary key default gen_random_uuid(),
  tabla_origen text not null,
  registro_id uuid not null,
  snapshot jsonb not null,
  eliminado_por uuid not null references public.profiles(id),
  motivo text not null,
  eliminado_en timestamptz not null default now()
);

alter table public.log_eliminaciones enable row level security;

drop policy if exists "log_eliminaciones_select_authenticated" on public.log_eliminaciones;
create policy "log_eliminaciones_select_authenticated"
on public.log_eliminaciones
for select
to authenticated
using (true);

-- Sin insert/update/delete directo: solo se llena vía la función
-- eliminar_movimiento_con_motivo (security definer, más abajo).
grant select on public.log_eliminaciones to authenticated;

create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_perfil_id uuid;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no válido.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from v_perfil_id then
    raise exception 'Solo puedes eliminar registros que tú mismo creaste.';
  end if;

  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: ya se generó otro movimiento posterior para esta talla.';
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('production_movements', v_registro.id, to_jsonb(v_registro), v_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;
