-- =====================================================================
-- 036_rls_access_codes.sql
-- Activa RLS en access_codes (hoy pública, sin RLS — cualquiera con la
-- anon key podría leer los códigos de acceso de TODOS los usuarios).
--
-- Por qué es seguro activarlo sin romper el login:
-- accessCodeService.js valida el código DESPUÉS de que el usuario ya
-- inició sesión con correo/contraseña (supabase.auth.signInWithPassword),
-- así que en el momento en que se consulta access_codes ya existe un
-- auth.uid() válido. La política de abajo solo permite a un usuario
-- autenticado leer SU PROPIA fila (donde profiles.auth_id = auth.uid()
-- y profiles.id = access_codes.user_id) — exactamente la fila que
-- validarCodigoAcceso(userId, code) ya pide con
-- .eq('user_id', userId).eq('code', code). Ningún usuario podrá leer el
-- código de acceso de otro.
--
-- No se agregan políticas de insert/update/delete: los códigos se
-- gestionan manualmente desde Supabase Studio (service_role, que
-- ignora RLS), igual que profiles — el cliente web nunca necesita
-- escribir en esta tabla.
-- =====================================================================

alter table public.access_codes enable row level security;

drop policy if exists "access_codes_select_own" on public.access_codes;
create policy "access_codes_select_own"
on public.access_codes
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and pr.id = access_codes.user_id
  )
);

grant select on public.access_codes to authenticated;
