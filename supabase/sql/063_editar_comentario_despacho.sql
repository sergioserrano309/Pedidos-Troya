-- =====================================================================
-- 063_editar_comentario_despacho.sql
-- El Validador (y SOLO el Validador) puede editar, agregar o quitar el
-- comentario de un despacho ya creado (Despachos > Despachado > detalle).
--
-- POR QUE
--   El comentario se fija al crear la salida (062). Si Empaque despacha
--   sin comentario y la informacion clave no quedo expuesta, no habia
--   forma de dejarla anotada despues ni de saber quien la agrego.
--
-- COMO (mismo patron que 053, marcar_despacho_revisado)
--   * Un RPC security definer es la UNICA via de escritura. El cliente
--     no puede hacer UPDATE directo en despachos (039 lo revoco), asi que
--     no se abre ningun permiso nuevo ni se toca ninguna politica RLS.
--   * La regla "solo Validador" vive en la base: esconder el campo en la
--     pantalla no la impide, y el RPC rechaza a cualquier otro rol aunque
--     lo llamen a mano.
--   * Cada cambio queda en audit_validador (accion
--     'editar_comentario_despacho'): quien, cuando, comentario anterior y
--     nuevo. Si el texto no cambia, no se escribe nada ni se audita.
--
-- REGLAS DE NEGOCIO (decididas con el dueno)
--   * Con el visto bueno (Revisado) puesto SI se puede editar. El
--     Validador nunca queda bloqueado por su propio visto bueno (053).
--   * Texto vacio o solo espacios = quitar el comentario.
--   * Maximo 255 caracteres (mismo limite que al crear, 062).
--
-- REQUIERE 062 (columna despachos.comentario). No toca vistas ni
-- ninguna otra funcion.
-- Reversa: 063_revertir_editar_comentario_despacho.sql
-- =====================================================================

create or replace function public.editar_comentario_despacho(
  p_despacho_id uuid,
  p_comentario text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_nuevo text;
  v_anterior text;
  v_consecutivo text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede editar el comentario de un despacho.';
  end if;

  v_nuevo := nullif(trim(coalesce(p_comentario, '')), '');
  if v_nuevo is not null and char_length(v_nuevo) > 255 then
    raise exception 'El comentario no puede superar 255 caracteres (tiene %).', char_length(v_nuevo);
  end if;

  -- for update: dos ediciones simultaneas se serializan y el "anterior"
  -- que queda en la auditoria es siempre el real.
  select d.comentario, d.consecutivo
    into v_anterior, v_consecutivo
    from public.despachos d
   where d.id = p_despacho_id
   for update;

  if not found then
    raise exception 'El despacho no existe o ya fue eliminado.';
  end if;

  -- Sin cambios: ni se escribe ni se audita.
  if v_anterior is not distinct from v_nuevo then
    return;
  end if;

  -- despachos.id calificado a proposito (ver 038).
  update public.despachos
     set comentario = v_nuevo
   where despachos.id = p_despacho_id;

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (
    v_perfil_id,
    'editar_comentario_despacho',
    'Validador',
    v_consecutivo,
    jsonb_build_object(
      'despacho_id', p_despacho_id,
      'comentario_anterior', v_anterior,
      'comentario_nuevo', v_nuevo
    ),
    null
  );
end;
$$;

revoke all on function public.editar_comentario_despacho(uuid, text) from public, anon;
grant execute on function public.editar_comentario_despacho(uuid, text) to authenticated;

comment on function public.editar_comentario_despacho(uuid, text) is
  'Edita, agrega o quita el comentario de un despacho ya creado (063). Solo Validador; audita en audit_validador con el texto anterior y el nuevo. Texto vacio = quitar. Maximo 255 caracteres.';
