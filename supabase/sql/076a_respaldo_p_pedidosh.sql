-- =====================================================================
-- 076a_respaldo_p_pedidosh.sql
-- PASO 1 de 3 de la Etapa 1 de la Fase 5: COPIA DE RESPALDO de p_pedidosh.
--
-- Se ejecuta ANTES de congelar el codigo interno (076_item_id_fijo.sql).
-- Crea p_pedidosh_respaldo_076: una copia exacta (valores incluidos, el
-- item_id como columna normal) de la tabla de pedidos.
--
-- SEGURIDAD DE LA COPIA
--   Una tabla nueva en el esquema public queda, por defecto, expuesta a
--   traves de la API de Supabase. Esta copia contiene datos de clientes, asi
--   que se le activa RLS y se le quitan los permisos de anon y authenticated
--   en la MISMA transaccion: nadie puede leerla desde la aplicacion; solo se
--   consulta desde el SQL Editor / service_role.
--
-- Repetible: si la copia ya existe, no la pisa (borrela a mano si quiere
-- rehacerla: drop table public.p_pedidosh_respaldo_076;).
--
-- Cuando ya no haga falta (pasadas unas semanas sin problemas):
--   drop table public.p_pedidosh_respaldo_076;
-- =====================================================================

begin;

create table if not exists public.p_pedidosh_respaldo_076 as
  table public.p_pedidosh;

alter table public.p_pedidosh_respaldo_076 enable row level security;
revoke all on table public.p_pedidosh_respaldo_076 from anon, authenticated;

comment on table public.p_pedidosh_respaldo_076 is
  'Copia de p_pedidosh antes de congelar item_id (076). Sin acceso desde la aplicacion. Se puede borrar cuando ya no haga falta.';

-- Si la copia no tiene EXACTAMENTE las mismas filas que el original, se
-- deshace todo (no se deja una copia incompleta).
do $$
declare
  v_origen bigint;
  v_copia bigint;
begin
  select count(*) into v_origen from public.p_pedidosh;
  select count(*) into v_copia from public.p_pedidosh_respaldo_076;
  if v_origen <> v_copia then
    raise exception 'La copia tiene % filas y el original %: no se guarda.', v_copia, v_origen;
  end if;
end $$;

commit;

-- Para comprobarla despues (solo lee): debe dar el mismo numero en las dos.
--   select (select count(*) from public.p_pedidosh) as original,
--          (select count(*) from public.p_pedidosh_respaldo_076) as copia;
