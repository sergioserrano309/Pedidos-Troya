-- =====================================================================
-- 019_fix_validador_rls.sql
-- Validador quedó definido como ROL INDEPENDIENTE en profiles.role
-- ('validador'), NO como un rol adicional vía user_roles (esa tabla del
-- archivo 017 asumía multi-rol por usuario, pero se decidió que un
-- usuario es Refilado O Validador, nunca ambos a la vez).
--
-- La política de audit_validador (017) validaba contra user_roles, que
-- ahora queda vacía/sin uso — eso bloquearía al validador para ver su
-- propio log de auditoría. Se corrige para validar contra profiles.role.
-- =====================================================================

drop policy if exists "audit_validador_select_validador_only" on public.audit_validador;

create policy "audit_validador_select_validador_only"
on public.audit_validador
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.auth_id = auth.uid() and p.role = 'validador'
  )
);

-- Misma correccion para user_roles (queda sin uso practico por ahora,
-- pero se deja consistente por si se retoma en el futuro).
drop policy if exists "user_roles_select_own_or_validador" on public.user_roles;

create policy "user_roles_select_own_or_validador"
on public.user_roles
for select
to authenticated
using (
  user_id = auth.uid() or
  exists (
    select 1 from public.profiles p
    where p.auth_id = auth.uid() and p.role = 'validador'
  )
);

comment on table public.audit_validador is
  'Log de auditoria de intervenciones del validador. Registra cada accion para trazabilidad. Visibilidad: solo profiles.role = validador (fix 019).';
