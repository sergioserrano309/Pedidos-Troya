# Sistema de Pedidos de Producción — Suelas

Sistema web para que los operarios de fábrica gestionen el flujo de producción de suelas (Refilado → Acabado / Mateado → Empaque), con devoluciones y trazabilidad completa, sobre Supabase.

> Este sistema **nunca modifica** la tabla original `Pedidos Prueba` (sincronizada por un ERP externo). Toda la actividad de producción se registra en tablas nuevas (`production_movements`, `returns`) y el progreso se **calcula** en cada consulta.

## Stack

- **Frontend:** HTML + CSS + JavaScript (vanilla), empaquetado con [Vite](https://vitejs.dev/) solo para inyectar variables de entorno y generar el build de producción.
- **Backend:** ninguno propio. Toda la lógica vive en **Supabase** (Postgres + Auth + Realtime), protegida con Row Level Security (RLS) por rol.
- **Hosting:** Vercel (sitio estático).

No hay componente Python en este proyecto, por lo que no existe `requirements.txt`; `package.json` gestiona las únicas dependencias (JavaScript).

## 1. Crear el proyecto de Supabase

1. Crea un proyecto en [supabase.com](https://supabase.com) (o usa uno existente que ya tenga la tabla `Pedidos Prueba` sincronizada desde el ERP).
2. Ve a **SQL Editor** y ejecuta, **en este orden**, los scripts de la carpeta [`supabase/sql/`](supabase/sql):
   1. `001_profiles.sql`
   2. `002_production_movements.sql`
   3. `003_returns.sql`
   4. `004_functions.sql` (función `generar_item_id`, equivalente SQL de `src/lib/itemId.js`)
   5. `005_views_dashboard.sql` (vistas de progreso calculado)
   6. `006_rls_policies.sql` (seguridad por rol)
   7. `008_realtime.sql` (habilita Realtime para refresco automático del dashboard)
3. (Opcional) Usa `007_seed_profiles_example.sql` como referencia únicamente después de crear manualmente los usuarios de prueba en **Authentication → Users**, para vincular cada uno a un rol (`refilado`, `acabado`, `mateado`, `empaque`, `comercial`). El `email` que registres en `profiles` debe coincidir exactamente con el del usuario creado (es lo que se usa para iniciar sesión).
4. Confirma que la tabla `"Pedidos Prueba"` (con espacio, por eso siempre se referencia entre comillas) ya existe y tiene datos. Si tu tabla real tiene otro nombre, ajústalo en `src/services/ordersService.js` (constante `PEDIDOS_TABLE`).

## 2. Variables de entorno requeridas

Copia `.env.example` a `.env` y completa:

| Variable | Descripción | Dónde obtenerla |
|---|---|---|
| `VITE_SUPABASE_URL` | URL del proyecto Supabase | Supabase Dashboard → Project Settings → API → Project URL |
| `VITE_SUPABASE_ANON_KEY` | Clave pública `anon` | Supabase Dashboard → Project Settings → API → Project API keys → `anon` `public` |

**Importante:** nunca uses la `service_role key` en el frontend; solo la `anon key`, cuyo acceso a datos está limitado por las políticas RLS descritas en `005_rls_policies.sql`.

## 3. Desarrollo local

```bash
npm install
npm run dev
```

Abre `http://localhost:5173`.

## 4. Build de producción

```bash
npm run build
npm run preview   # para probar el build localmente
```

El resultado queda en `dist/`.

## 5. Despliegue en Vercel

1. Sube este repositorio a GitHub/GitLab/Bitbucket (asegúrate de que `.env` **no** se suba; `.gitignore` ya lo excluye).
2. En Vercel: **Add New Project** → importa el repositorio.
3. Vercel detecta automáticamente el framework `Vite` (también está fijado explícitamente en `vercel.json`).
4. En **Project Settings → Environment Variables**, agrega (para Production y Preview):
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. Deploy. Cada push a la rama configurada generará un nuevo despliegue.

## 6. Roles del sistema

| Rol | Ve | Puede |
|---|---|---|
| `refilado` | Todas las órdenes pendientes | Procesar y enviar a Acabado o Mateado |
| `acabado` | Solo ítems asignados a Acabado | Procesar y enviar a Empaque |
| `mateado` | Solo ítems asignados a Mateado | Procesar y enviar a Empaque |
| `empaque` | Solo ítems listos para empaque | Marcar producción como completada |
| `comercial` | Todas las órdenes | Registrar devoluciones, ver historial completo |

## 7. Estructura del proyecto

```
index.html                 Entrada de la app (UI original produccion_app.html adaptada)
src/
  main.js                  Bootstrap de la app
  config/supabaseClient.js Cliente de Supabase (usa las env vars VITE_*)
  lib/itemId.js             Generador determinístico de ID de 10 dígitos
  lib/calculations.js       Cálculos de progreso (nunca almacenados)
  services/                 Acceso a datos (auth, pedidos, movimientos, devoluciones, historial)
  state/appState.js         Estado en memoria de la sesión/UI
  ui/                       Lógica de cada pantalla/modal
supabase/sql/               Scripts SQL a ejecutar en Supabase (en orden numérico)
```

## 8. Regla de negocio crítica

La tabla `Pedidos Prueba` es **solo lectura** desde esta aplicación: nunca se ejecuta `INSERT`/`UPDATE`/`DELETE` sobre ella, tanto a nivel de código como reforzado con RLS en la base de datos.
