# Instrucciones de Migración: Pedidos Prueba → p_pedidosh

## Resumen de cambios realizados

La aplicación ahora usa **`p_pedidosh`** en lugar de **`"Pedidos Prueba"`** como tabla de datos de solo lectura.

### Archivos modificados:
- ✅ `supabase/sql/004_functions.sql` — comentarios actualizados
- ✅ `supabase/sql/005_views_dashboard.sql` — todas las vistas ahora apuntan a `p_pedidosh`
- ✅ `supabase/sql/006_rls_policies.sql` — políticas de RLS actualizadas
- ✅ `supabase/sql/009_create_p_pedidosh.sql` — **NUEVO**: script para crear la tabla
- ✅ `README.md` — instrucciones actualizadas
- ✅ `DOCUMENTACION_TECNICA.md` — referencias actualizadas

---

## Pasos para completar la migración

### 1. Ejecutar los scripts SQL en Supabase (en orden)

En **SQL Editor** de Supabase, ejecuta todos los scripts de `supabase/sql/` en este orden:

```
001_profiles.sql
002_production_movements.sql
003_returns.sql
004_functions.sql
005_views_dashboard.sql
006_rls_policies.sql
008_realtime.sql
009_create_p_pedidosh.sql  ← NUEVO: crea la tabla p_pedidosh
```

**Nota:** Si ya ejecutaste 001-006 antes con `"Pedidos Prueba"`, solo necesitas:
1. Ejecutar nuevamente `005_views_dashboard.sql` (se recrea automáticamente)
2. Ejecutar nuevamente `006_rls_policies.sql` (se recrea automáticamente)
3. Ejecutar por primera vez `009_create_p_pedidosh.sql`

### 2. Importar datos en `p_pedidosh`

#### Opción A: Desde CSV (recomendado por ahora)

1. Ve a **Table Editor** en Supabase Dashboard
2. Selecciona la tabla `p_pedidosh`
3. Haz clic en **Import data** (o el ícono de importación)
4. Sube tu archivo CSV
5. Mapea las columnas para que coincidan con las de la tabla:
   - `PedidoNo` → `"PedidoNo"`
   - `Referencia` → `"Referencia"`
   - `Talla` → `"Talla"`
   - Etc. (ver `009_create_p_pedidosh.sql` para la lista completa de columnas)
6. Importa

#### Opción B: Desde el ERP (futuro)

Cuando re-conectes con el ERP:
- **Si el ERP escribe en `p_pedidosh` directamente:** listo, funciona igual que antes
- **Si el ERP sigue escribiendo en otra tabla:** haremos un trigger o sincronización automática en ese momento

### 3. Verificar que la aplicación funciona

1. Desarrollo local:
   ```bash
   npm install
   npm run dev
   ```
   Abre `http://localhost:5173` y verifica que ve los pedidos

2. En producción:
   - Asegúrate de que las variables de entorno están configuradas en Vercel
   - Haz un nuevo deploy: `git push`

---

## Columnas de `p_pedidosh`

La tabla fue creada con todas las columnas que el sistema necesita:

| Columna | Tipo | Notas |
|---|---|---|
| `PedidoNo` | text | Identificador del pedido (NO NULL) |
| `Referencia` | text | Referencia del producto (NO NULL) |
| `Talla` | text | Talla (NO NULL) |
| `CantidadP` | integer | Cantidad solicitada |
| `MaterialP` | text | Material del producto |
| `ColorP` | text | Color |
| `Cliente` | text | Nombre del cliente |
| `FechaP` | date | Fecha del pedido |
| `NombreR` | text | Nombre de referencia |
| `Vira` | text | Especificación Vira |
| `DetalleVira` | text | Detalles de Vira |
| `Acabado` | text | Especificación de acabado |
| `DetalleAcab` | text | Detalles de acabado |
| `Esterilla` | text | Especificación Esterilla |
| `DetalleEsterilla` | text | Detalles Esterilla |
| `Marquilla` | text | Especificación Marquilla |
| `EstadoC` | text | Estado (no usado actualmente) |
| `Cancelado` | boolean | Si es true, el pedido no aparece en la aplicación |
| Y más... | — | Ver `009_create_p_pedidosh.sql` para la lista completa |

---

## Notas importantes

### ✅ Regla de solo lectura (reforzada en 3 capas)

1. **Frontend:** no existe código que escriba en `p_pedidosh`
2. **RLS:** la política `p_pedidosh_select_authenticated` solo permite `SELECT`
3. **Permisos Postgres:** `REVOKE INSERT, UPDATE, DELETE` a todos excepto `service_role`

### ✅ El ID determinístico sigue funcionando igual

- La función `generar_item_id()` en SQL sigue siendo idéntica
- El JavaScript `src/lib/itemId.js` también es idéntico
- Los `item_id` calculados para registros ya existentes serán exactamente iguales

### ✅ Las vistas siguen siendo "calculadas" (nunca almacenadas)

- Progreso se calcula en cada consulta combinando `p_pedidosh` + `production_movements` + `returns`
- Sin cambios funcionales, solo el nombre de la tabla

---

## Checklist final

- [ ] Ejecuté todos los scripts SQL en orden (001-009)
- [ ] Importé datos en `p_pedidosh` desde CSV
- [ ] Probé el login y veo los pedidos en el dashboard (desarrollo local o producción)
- [ ] Probé procesar un ítem (debe funcionar igual que antes)
- [ ] Probé registrar una devolución si tengo rol comercial

Si todo funciona, ¡la migración está completa! 🎉

---

## Troubleshooting

| Problema | Solución |
|---|---|
| "Permission denied for schema public" al importar CSV | Asegúrate de usar `anon` key en Supabase, no `service_role` |
| Tabla `p_pedidosh` no aparece | Ejecuta `009_create_p_pedidosh.sql` nuevamente en SQL Editor |
| Las vistas no traen datos | Verifica que `p_pedidosh` tenga datos importados; consulta `SELECT COUNT(*) FROM p_pedidosh;` |
| El dashboard está vacío pero la tabla tiene datos | Limpia la caché del navegador y recarga (Ctrl+Shift+R en Chrome) |
| RLS error al consultar | Verifica que ejecutaste `006_rls_policies.sql` correctamente |
