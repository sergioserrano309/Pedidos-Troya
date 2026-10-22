-- =====================================================================
-- 078_despachos_eliminados_en_despachado.sql
-- Despachos > Despachado muestra tambien los despachos ELIMINADOS (en
-- gris, solo consulta), para no tener que bajar el Excel a ver que se
-- borro y por que.
--
-- QUE CAMBIA
--   Una funcion nueva y de SOLO LECTURA: listar_despachos_eliminados.
--   Lee log_eliminaciones (tabla_origen = 'despachos') y devuelve, por
--   cada despacho eliminado, los mismos datos de resumen que la lista
--   normal (consecutivo, fecha, bultos, kilos, unidades, ordenes,
--   factura) mas quien lo elimino, cuando y el motivo, y la copia
--   completa (snapshot) para abrir su detalle.
--
-- POR QUE UNA FUNCION security definer
--   La lectura de log_eliminaciones es solo del Validador (043). Esta
--   funcion deja leer SOLO los despachos eliminados a Empaque y
--   Validador (se valida el rol adentro; Propuesta y los demas reciben
--   un error). No abre la tabla ni los registros de produccion.
--   Respeta el ocultamiento de pedidos anteriores al corte (058).
--
-- NO CAMBIA: listar_despachos_registro, vistas, tablas ni datos.
-- REQUIERE: 014, 039/046 (snapshot), 058 (fn_snapshot_despacho_oculto).
-- Reversa: 078_revertir_despachos_eliminados_en_despachado.sql
-- =====================================================================

begin;

create or replace function public.listar_despachos_eliminados(
  p_orden text default '',
  p_fecha text default '',
  p_consecutivo text default '',
  p_cliente text default '',
  p_factura text default ''
)
returns table (
  log_id uuid,
  despacho_id uuid,
  consecutivo text,
  created_at timestamptz,
  total_bultos integer,
  peso_total numeric,
  numero_ordenes integer,
  order_numbers text[],
  total_unidades bigint,
  numero_factura text,
  eliminado_en timestamptz,
  eliminado_por_nombre text,
  motivo text,
  snapshot jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rol text;
  v_orden text := btrim(coalesce(p_orden, ''));
  v_fecha_txt text := btrim(coalesce(p_fecha, ''));
  v_fecha date;
  v_consecutivo text := btrim(coalesce(p_consecutivo, ''));
  v_cliente text := btrim(coalesce(p_cliente, ''));
  v_factura text := btrim(coalesce(p_factura, ''));
begin
  select lower(pr.role) into v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_rol is null or v_rol not in ('empaque', 'validador') then
    raise exception 'Solo Empaque o Validador pueden consultar los despachos eliminados.';
  end if;

  if v_fecha_txt <> '' then
    v_fecha := v_fecha_txt::date;
  end if;

  return query
  select le.id,
         le.registro_id,
         coalesce(le.snapshot -> 'despacho' ->> 'consecutivo', '—'),
         (le.snapshot -> 'despacho' ->> 'created_at')::timestamptz,
         jsonb_array_length(coalesce(le.snapshot -> 'bultos', '[]'::jsonb)),
         coalesce((select sum((b ->> 'peso')::numeric)
                     from jsonb_array_elements(coalesce(le.snapshot -> 'bultos', '[]'::jsonb)) b), 0),
         jsonb_array_length(coalesce(le.snapshot -> 'ordenes', '[]'::jsonb)),
         coalesce((select array_agg(o ->> 'order_number' order by o ->> 'order_number')
                     from jsonb_array_elements(coalesce(le.snapshot -> 'ordenes', '[]'::jsonb)) o),
                  array[]::text[]),
         coalesce((select sum((i ->> 'cantidad')::numeric)
                     from jsonb_array_elements(coalesce(le.snapshot -> 'items', '[]'::jsonb)) i), 0)::bigint,
         le.snapshot -> 'despacho' ->> 'numero_factura',
         le.eliminado_en,
         pr.name,
         le.motivo,
         le.snapshot
    from public.log_eliminaciones le
    left join public.profiles pr on pr.id = le.eliminado_por
   where le.tabla_origen = 'despachos'
     and not public.fn_snapshot_despacho_oculto(le.snapshot)
     and (v_orden = '' or exists (
           select 1 from jsonb_array_elements(coalesce(le.snapshot -> 'ordenes', '[]'::jsonb)) o
            where o ->> 'order_number' = v_orden))
     and (v_fecha_txt = '' or (
           (le.snapshot -> 'despacho' ->> 'created_at')::timestamptz >= v_fecha::timestamp
           and (le.snapshot -> 'despacho' ->> 'created_at')::timestamptz < (v_fecha + 1)::timestamp))
     and (v_consecutivo = '' or (le.snapshot -> 'despacho' ->> 'consecutivo') ilike '%' || v_consecutivo || '%')
     and (v_cliente = '' or exists (
           select 1
             from jsonb_array_elements(coalesce(le.snapshot -> 'ordenes', '[]'::jsonb)) o
             join public.p_pedidosh ph on ph."PedidoNo"::text = o ->> 'order_number'
            where ph."Cliente" = v_cliente))
     and (v_factura = '' or (le.snapshot -> 'despacho' ->> 'numero_factura') = v_factura)
   order by (le.snapshot -> 'despacho' ->> 'created_at')::timestamptz desc;
end;
$$;

revoke all on function public.listar_despachos_eliminados(text, text, text, text, text) from public, anon;
grant execute on function public.listar_despachos_eliminados(text, text, text, text, text) to authenticated;

comment on function public.listar_despachos_eliminados(text, text, text, text, text) is
  'Despachos eliminados (log_eliminaciones) con resumen y snapshot, para mostrarlos en gris en Despachos > Despachado (078). Solo Empaque y Validador. Solo lectura.';

commit;

-- =====================================================================
-- PRUEBA SEGURA (solo lectura; correr en el editor de Supabase DESPUES
-- de ejecutar lo de arriba). Como el editor no tiene sesion de usuario,
-- la funcion responde con el error de permiso: eso confirma que existe
-- y que bloquea a quien no es Empaque/Validador.
--   select * from public.listar_despachos_eliminados();
-- Comprobacion de datos (sin la funcion) para ver el D1230:
--   select snapshot -> 'despacho' ->> 'consecutivo', motivo, eliminado_en
--     from public.log_eliminaciones where tabla_origen = 'despachos'
--    order by eliminado_en desc limit 5;
-- =====================================================================
