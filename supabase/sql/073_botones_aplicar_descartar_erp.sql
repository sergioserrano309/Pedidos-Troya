-- =====================================================================
-- 073_botones_aplicar_descartar_erp.sql
-- BOTONES "Aplicar" y "Descartar" de la pestana Cambios ERP (solo Validador).
--
-- POR QUE
--   Hay cambios que el sistema NO aplica solo y quedan pendientes (hoy: un
--   pedido cancelado en Access que ya esta COMPLETO, como 3457 y 3493). El
--   Validador necesita decidir desde la pantalla, con los MISMOS botones para
--   cualquier tipo de cambio (las fases 4 y 5 los reutilizan):
--     Aplicar    el cambio se aplica ahora, a mano.
--     Descartar  el cambio se rechaza (desaparecen el aviso y el triangulo;
--                queda una nota gris). Se puede aplicar despues.
--     Deshacer   (ya existia) revierte un cambio aplicado.
--
-- QUE SE PUEDE APLICAR A MANO HOY
--   Solo el CANCELADO: cierra el pedido a la fuerza con motivo "Cancelado en
--   Troya", FIRMADO por el Validador que hace clic (queda en audit_validador
--   igual que el cierre manual de siempre). Se permite tambien en pedidos
--   completos: es una decision del Validador. Los demas tipos de cambio
--   todavia no tienen "Aplicar" (se agregan en las fases 4 y 5).
--
-- QUE SE PUEDE DESCARTAR
--   Cualquier diferencia pendiente (de cualquier tipo): solo cambia su estado
--   a "rechazado". No toca ningun pedido. Si Access cambia el valor despues,
--   vuelve a aparecer como pendiente.
--
-- SEGURIDAD
--   * Solo el Validador (se verifica en la base, no solo en pantalla).
--   * Una funcion INTERNA hace el trabajo (solo service_role, la usan las
--     pruebas seguras) y una funcion PUBLICA verifica quien llama.
--   * Un cierre firmado por el Validador NUNCA lo reabre el sistema solo
--     (072 solo reabre cierres con "cerrado por" vacio).
--
-- Deshacer un cierre hecho con "Aplicar": se amplia erp_revertir_cambio_interno
-- para que tambien reabra cierres firmados por el Validador.
--
-- Reversa: 073_revertir_botones_aplicar_descartar_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Aplicar a mano (interna + publica)
-- ---------------------------------------------------------------------
create or replace function public.erp_aplicar_cambio_interno(p_id bigint, p_perfil uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
begin
  if p_perfil is null then
    raise exception 'Falta el perfil del Validador.';
  end if;

  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  if r.estado not in ('pendiente', 'rechazado') then
    raise exception 'Este cambio ya no esta pendiente.';
  end if;

  if r.tipo <> 'cancelado' or r.talla is not null then
    raise exception 'Este tipo de cambio todavia no se puede aplicar a mano.';
  end if;

  if not exists (select 1 from public.p_pedidosh p where p."PedidoNo"::text = r.pedido) then
    raise exception 'El pedido % no existe.', r.pedido;
  end if;

  -- Ya estaba cerrado a la fuerza: se da por atendido, no se toca.
  if exists (select 1 from public.pedido_cierre_forzado f where f.order_number = r.pedido) then
    update public.erp_cambios c
       set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'ya cerrado',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'ya_cerrado', 'por', p_perfil::text))
     where c.id = r.id;
    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'ya_cerrado');
  end if;

  insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por)
  values (r.pedido, 'Cancelado en Troya', p_perfil);

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (p_perfil, 'cerrar_forzado', 'Validador', r.pedido, null, 'Cancelado en Troya');

  update public.erp_cambios c
     set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'validador',
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'cerrado', 'motivo', 'Cancelado en Troya', 'por', p_perfil::text))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'cerrado');
end;
$$;

comment on function public.erp_aplicar_cambio_interno(bigint, uuid) is
  'Aplica a mano un cambio pendiente (073). Hoy solo CANCELADO: cierra a la fuerza firmado por el Validador. Solo service_role.';

revoke all on function public.erp_aplicar_cambio_interno(bigint, uuid) from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambio_interno(bigint, uuid) to service_role;

create or replace function public.erp_aplicar_cambio(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid;
begin
  select pr.id into v_perfil
    from public.profiles pr
   where pr.auth_id = auth.uid() and lower(pr.role) = 'validador';

  if auth.uid() is null or v_perfil is null then
    raise exception 'Solo el Validador puede aplicar cambios.';
  end if;

  return public.erp_aplicar_cambio_interno(p_id, v_perfil);
end;
$$;

comment on function public.erp_aplicar_cambio(bigint) is
  'Boton "Aplicar" de la pestana Cambios ERP (073). Solo el Validador.';

revoke all on function public.erp_aplicar_cambio(bigint) from public, anon;
grant execute on function public.erp_aplicar_cambio(bigint) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Descartar (interna + publica): cualquier diferencia pendiente
-- ---------------------------------------------------------------------
create or replace function public.erp_descartar_cambio_interno(p_id bigint, p_perfil uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
begin
  if p_perfil is null then
    raise exception 'Falta el perfil del Validador.';
  end if;

  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  if r.estado <> 'pendiente' then
    raise exception 'Solo se puede descartar un cambio pendiente.';
  end if;

  update public.erp_cambios c
     set estado = 'rechazado',
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'descartado', 'por', p_perfil::text))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'descartado');
end;
$$;

comment on function public.erp_descartar_cambio_interno(bigint, uuid) is
  'Descarta (rechaza) una diferencia pendiente (073): solo cambia su estado, no toca ningun pedido. Solo service_role.';

revoke all on function public.erp_descartar_cambio_interno(bigint, uuid) from public, anon, authenticated;
grant execute on function public.erp_descartar_cambio_interno(bigint, uuid) to service_role;

create or replace function public.erp_descartar_cambio(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid;
begin
  select pr.id into v_perfil
    from public.profiles pr
   where pr.auth_id = auth.uid() and lower(pr.role) = 'validador';

  if auth.uid() is null or v_perfil is null then
    raise exception 'Solo el Validador puede descartar cambios.';
  end if;

  return public.erp_descartar_cambio_interno(p_id, v_perfil);
end;
$$;

comment on function public.erp_descartar_cambio(bigint) is
  'Boton "Descartar" de la pestana Cambios ERP (073). Solo el Validador.';

revoke all on function public.erp_descartar_cambio(bigint) from public, anon;
grant execute on function public.erp_descartar_cambio(bigint) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Deshacer: ahora tambien reabre un cierre hecho con "Aplicar" (firmado
--    por el Validador). La de 072 solo reabria los del sistema.
-- ---------------------------------------------------------------------
create or replace function public.erp_revertir_cambio_interno(p_id bigint, p_quien text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  v_n integer;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  if r.tipo <> 'cancelado' then
    return public.erp_revertir_texto_interno(p_id, p_quien);
  end if;

  if r.estado <> 'aplicado' or r.aplicado_por not in ('automatico', 'validador') then
    raise exception 'Solo se puede deshacer un cierre por cancelacion hecho por el sistema o por el Validador con Aplicar.';
  end if;

  if exists (select 1 from public.erp_cambios c
              where c.id <> r.id and c.estado in ('pendiente', 'rechazado')
                and c.pedido = r.pedido and c.tipo = 'cancelado'
                and coalesce(c.talla, '') = coalesce(r.talla, '')
                and coalesce(c.campo, '') = coalesce(r.campo, '')
                and coalesce(c.clave_linea, '') = coalesce(r.clave_linea, '')) then
    raise exception 'El pedido % ya tiene otra diferencia de cancelacion abierta; resuelvala primero.', r.pedido;
  end if;

  delete from public.pedido_cierre_forzado f
   where f.order_number = r.pedido
     and f.motivo = 'Cancelado en Troya'
     and ((r.aplicado_por = 'automatico' and f.cerrado_por is null)
          or (r.aplicado_por = 'validador' and f.cerrado_por is not null));
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'El pedido % ya no tiene el cierre que se aplico (alguien lo reabrio o lo cambio a mano); no se toca.', r.pedido;
  end if;

  update public.erp_cambios c
     set estado = 'rechazado',
         ultima_revision_at = now(),
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'revertido', 'por', p_quien))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'reabierto');
end;
$$;

comment on function public.erp_revertir_cambio_interno(bigint, text) is
  'Deshace un cambio aplicado: texto (071, via erp_revertir_texto_interno) o cierre por cancelacion (072/073: reabre el pedido). Queda "rechazado": no se vuelve a aplicar. Solo service_role.';

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

commit;
