# Contexto de Sesión - Mejoras al Sistema de Órdenes de Producción

## 📋 Tanda de Comentarios / Requisitos del Usuario

El usuario (Sergio) solicitó las siguientes mejoras a la aplicación de gestión de órdenes de producción:

### 1. **Login** - PENDIENTE (dejado de últimas)
- Cambiar de login con correo a login con **Usuario (nombre de usuario)** + **Contraseña**
- Campo `name` en tabla `profiles` es lo que se usa como usuario
- Campo `role` en tabla `profiles` define el rol del usuario

### 2. **Descripción de Orden Mejorada** - PENDIENTE
- Mostrar en la cabecera:
  - Número de Orden, Cliente, Fecha (como está)
  - **Agregar**: Referencia, ColorP, MaterialP, Vira, Acabado, Esterilla, Marquilla
- Mostrar comentarios (solo si existen):
  - DetalleVira
  - DetalleAcab
  - DetalleEsterilla
- Remover barra de progreso en ítems (redundancia)
- Cambiar layout a tabla con columnas: Talla | Solicitado | Procesado | Etapa Actual | [Campo entrada] | [Botón]

### 3. **Filtros Independientes** - ✅ COMPLETADO
- Reemplazar búsqueda simple por 4 filtros independientes:
  - Número de Orden
  - Cliente
  - Material
  - Color
- Los filtros son acumulativos (ej: Material=Cuero + Color=Rojo)
- Implementado con inputs de texto (no dropdowns aún)

### 4. **Procesamiento Mejorado** - PENDIENTE
- El botón "Procesar" debe permitir procesar **múltiples veces** (no solo una)
- Hasta completar todas las unidades solicitadas
- Nueva tabla con columnas: Talla | Solicitado | Procesado | Etapa Actual | [Campo para cantidad] | [Botón Procesar]
- Al hacer clic en "Procesar", modal simplificado con solo:
  - "Enviar a Proceso"
  - "Observaciones (Opcional)"
  - Botones: Cancelar / Guardar Procesamiento

### 5. **Procesos Destino** - INFO
- "Refilado" puede enviar a: Acabado, Mateado, **Empaque** (no solo Acabado y Mateado)

### 6. **Descargable Excel** - PENDIENTE
- Todas las órdenes (no solo activas)
- Una hoja por proceso: Inyección, Refilado, Acabado, Mateado, Empaque
- Incluir historial de cada procesamiento por orden

### 7. **Historial** - PENDIENTE
- Cambiar de menú a **tabs adicionales en Órdenes de Producción**:
  - "Activas"
  - "Completadas"
  - "Registros (Historial)" - NUEVO
- Agregar columnas de estado por proceso:
  - Pedido | Usuario | Acción | Cantidad | Fecha | Hora | Detalles
  - **NUEVO**: Refilado | Mateado | Acabado | Empaque (Sí/No para cada proceso)

### 8. **Futuro** - PENDIENTE (en el tintero)
- Calcular tiempo desde creación hasta empaque
- Descomponer tiempo por proceso
- Por ahora solo Sí/No, sin fechas/horas en el estado del proceso

---

## 🗄️ Información de Base de Datos

### Tabla `profiles`
- `id` (uuid) - PK
- `auth_id` (uuid) - referencia a Supabase Auth
- `name` - nombre de usuario (diferente del email)
- `email` - email
- `role` - rol del usuario
- `created_at`

### Tabla `p_pedidosh` (órdenes)
- Campos de especificación:
  - `Referencia` - referencia del producto
  - `ColorP` - color del producto
  - `MaterialP` - material (no existe `Material` separado)
  - `Vira` (boolean)
  - `Acabado` (boolean)
  - `Esterilla` (boolean)
  - `Marquilla` (boolean)
  - `DetalleVira` - comentario
  - `DetalleAcab` - comentario
  - `DetalleEsterilla` - comentario
- Otros campos: `PedidoNo`, `FechaP`, `Cliente`, `CantidadP`, `Talla`, `NombreR`, `Cancelado`

### Vistas SQL
- `vw_pedido_progreso` - datos agregados por PedidoNo (usado en listado)
- `vw_item_progreso` - datos por ítem (Talla) con progreso calculado

---

## ✅ Cambios Realizados

### FASE 2: Filtros Independientes - COMPLETADO
**Commits:**
- `5415e83` - Agregar filtros independientes (Cliente, Orden, Material, Color)
- `bef20e6` - Fix: filtros de material y color en JavaScript, no en SQL

**Archivos modificados:**
1. **index.html**
   - Reemplazó input de búsqueda simple por 4 inputs: Número de Orden, Cliente, Material, Color

2. **src/services/ordersService.js**
   - Actualizado `fetchOrders()` para aceptar objeto `filters` con 4 campos
   - Filtros de orden y cliente se aplican en SQL
   - Filtros de material y color se aplican en JavaScript (por compatibilidad)

3. **src/ui/dashboard.js**
   - Actualizado `inicializarPaginaOrdenes()` para escuchar 4 inputs
   - Los filtros se aplican con debounce de 350ms
   - `cargarOrdenes()` pasa los filtros al servicio

4. **supabase/sql/005_views_dashboard.sql**
   - Se intentó agregar `material` y `color` a `vw_pedido_progreso`
   - Se revertió para mantener compatibilidad

**Estado:** Desplegado en Vercel en vivo
- URL: https://pedidos-troya-cyan.vercel.app/

---

## 🔴 Problema Actual

**Error:** "No se pudieron cargar las órdenes"

**Causa probable:**
- Los campos `material` y `color` intentaron agregarse a `vw_pedido_progreso`, pero pueden no existir o haber causado un error en la vista SQL
- El filtro en JavaScript intenta acceder a `order.material` y `order.color` que podrían ser `undefined`

**Solución propuesta:**
- Obtener datos de `vw_item_progreso` (que sí tiene estos campos)
- Hacer la agregación en JavaScript en lugar de SQL
- Esto requiere cambios en `ordersService.js`

---

## 📊 Plan Pendiente

### FASE 1: Login - PENDIENTE (últimas)
### FASE 2: Filtros Independientes - ✅ COMPLETADO
### FASE 3: Descripción de Orden Mejorada - PENDIENTE
### FASE 4: Tabla de Tallas Mejorada - PENDIENTE
### FASE 5: Modal de Procesamiento Simplificado - PENDIENTE
### FASE 6: Historial con Columnas de Procesos - PENDIENTE
### FASE 7: Descargable Excel - PENDIENTE

---

## 🔧 Configuración Agregada

- `.claude/mcp.json` - Configuración para conectar a Supabase MCP (requiere reinicio de Claude Code)

---

## 📝 Notas

- Git está configurado y todos los commits están pusheados a GitHub (sergioserrano309/Pedidos-Troya)
- Vercel tiene auto-deploy habilitado
- Los cambios se despliegan automáticamente cuando se hace `git push`
- Usuario usa VSCode + GitHub + Vercel + Supabase (no ejecuta npm localmente)

