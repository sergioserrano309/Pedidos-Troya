# Sistema de Órdenes de Producción — Resumen del Proyecto

## 📋 Objetivo General

Construir un **Sistema de Gestión de Órdenes de Producción** con Supabase como backend, que permita rastrear el flujo completo de producción desde Refilado hasta Empaque, con roles específicos para cada proceso y automatización de decisiones de enrutamiento.

**Flujo de Producción:**
```
Refilado → (Acabado O Mateado, nunca ambos) → Empaque → Completado
```

---

## ✅ Funcionalidades Implementadas

### 1. **Dashboard de Órdenes de Producción**
- **Listado paginado** de órdenes (30 por página)
- **Filtros dinámicos** (Cliente, Nombre Suela, Material, Color)
- **Columnas visibles:**
  - Orden, Cliente, Nombre Suela, Material, Color, **Etapa Actual**
  - Total Suelas, Procesadas, Pendientes, Días desde creación
  - Estado (Completado/En Proceso) con porcentaje
- **Detalle de orden:** Abre cartilla con todas las tallas (ítems) y su etapa

### 2. **Cartilla de Orden (Order Detail)**
- Muestra cada **talla/tamaño** por separado
- **Entrada:** cantidad solicitada
- **Salida:** cantidad a procesar (editable)
- **Botón "Procesar Toda la Orden"** (verde)
  - Recopila todas las tallas con cantidad > 0
  - Abre modal de confirmación con resumen
  - Procesa TODAS en una sola transacción DB
- **Etapa Actual** visible para cada ítem (R, A, M, E, Fin)

### 3. **Procesamiento por Lotes (Batch Processing)**
- Usuario completa cantidades para múltiples tallas
- Click en "Procesar Toda la Orden"
- Modal muestra **resumen de todas las tallas** a procesar
- Confirmación = 1 viaje a BD (no múltiples inserts)
- Después de procesar: **cierra automáticamente la cartilla** y vuelve al listado

### 4. **Reglas de Enrutamiento Automático (Reglas Inteligentes)**
- **3 criterios opcionales:** Nombre Suela, Material, Color
- **Lógica:** Más específica gana (ej: Nombre + Material + Color > solo Nombre)
- **Resultado:** Cuando Refilado procesa una orden que coincide, se crea movimiento con `es_automatico = true` y se rutea automáticamente a Acabado O Mateado
- **Automatismo:** No requiere confirmación manual de destino
- **Visibilidad:** Refilado NO ve órdenes auto-ruteadas en su listado
- **Métricas:** Auto-ruteadas NO cuentan hacia "Procesado" de Refilado (solo conteo global)

### 5. **Gestión de Registros (Historial)**
- **Tabla de movimientos** de cada orden (entrada/salida de procesos)
- **Eliminar registro** con modal que requiere **motivo obligatorio**
- **Validaciones:**
  - Solo usuario que creó el movimiento puede eliminarlo
  - Solo si es el movimiento MÁS RECIENTE de esa talla
- **Log inmutable** en `log_eliminaciones` (fecha, usuario, motivo, snapshot completo)

### 6. **Gestión de Reglas de Enrutamiento**
- CRUD completo (Crear, Leer, Actualizar, Eliminar)
- **Eliminar regla** con modal de confirmación (sin motivo)
- **Listado dinámico** actualizado en vivo
- **Dropdowns** para criterios: Nombre Suela, Material, Color (valores DISTINCT de BD)

### 7. **Descarga Excel Completa**
- **Botón "Descargar Excel"** en dashboard
- **6 hojas:**
  1. **Órdenes:** Resumen global con todas las métricas
  2. **Refilado:** Movimientos de Refilado
  3. **Acabado:** Movimientos de Acabado
  4. **Empaque:** Movimientos de Empaque
  5. **Inyección:** Devoluciones fallidas en Inyección
  6. **Eliminaciones:** Registro completo de eliminaciones

- **Columnas Hoja Órdenes:**
  - Orden, Cliente, Nombre Suela, Material, Color, Fecha
  - Total Solicitado, Procesado, Pendiente, % Completado, Total Ítems
  - Regla (Sí/No), ReglaProceso (destino automático)
  - P_Refilado, P_Acabado, P_Empaque, P_Mateado (unidades procesadas)
  - %_Refilado, %_Acabado, %_Empaque, %_Mateado (porcentajes por proceso)

- **Columnas Hojas de Proceso (Refilado, Acabado, Empaque, Inyección):**
  - Orden, Nombre Suela, Material, Color, Talla
  - Cantidad, Enviado a, Usuario (muestra "Regla" si es automático)
  - Fecha, Hora, Observaciones

- **Columnas Hoja Eliminaciones:**
  - Fecha Eliminación, ID Eliminación, Orden, Talla, Cantidad
  - Proceso Origen, Proceso Destino, Referencia, Usuario, Motivo

---

## 🛠️ Arquitectura Técnica

### **Frontend (JavaScript/Vite)**
- `src/ui/dashboard.js` — Listado paginado con filtros dinámicos
- `src/ui/orderDetail.js` — Cartilla con batch processing
- `src/ui/processModal.js` — Modal de confirmación de lotes
- `src/ui/historyPage.js` — Historial con modal de eliminación
- `src/ui/reglasPage.js` — CRUD de reglas con dropdowns
- `src/services/excelService.js` — Generación de Excel con 6 hojas

### **Backend (Supabase/PostgreSQL)**
- **Tablas principales:**
  - `p_pedidosh` — Órdenes (solo lectura)
  - `production_movements` — Movimientos entre procesos
  - `order_destino` — Destino final de cada orden (Acabado/Mateado/Empaque)
  - `reglas_enrutamiento` — Reglas automáticas
  - `returns` — Devoluciones fallidas
  - `log_eliminaciones` — Auditoría de eliminaciones

- **Vistas SQL (calculadas en tiempo real):**
  - `vw_pedidos_con_id` — Órdenes con item_id materializado
  - `vw_item_progreso` — Progreso por item (talla)
  - `vw_item_stage` — Etapa actual de cada item
  - `vw_pedido_progreso` — Progreso agregado por orden
  - `vw_historial` — Timeline combinada (movimientos + devoluciones)

- **Funciones PL/pgSQL:**
  - `generar_item_id()` — SHA-256 + talla/material/color/referencia
  - `aplicar_regla_enrutamiento()` — Trigger automático al insertar pedido
  - `backfill_auto_enrutamiento()` — Aplicar reglas retroactivamente
  - `eliminar_movimiento_con_motivo()` — Eliminación con auditoria

- **RLS (Row Level Security):**
  - Cada rol solo ve órdenes donde tiene entrada (`entrada_X > 0`)
  - `log_eliminaciones` solo lectura autenticada
  - Dropdowns filtrados por DISTINCT valores

---

## 🚀 Optimizaciones Realizadas

### **Performance (12s → millisegundos)**
1. **Problema:** Listado tardaba 12+ segundos
2. **Causa raíz:** `generar_item_id()` (SHA-256 + PL/pgSQL 64-step loop) recalculado 25,000+ veces por consulta
3. **Solución:** Materializar `item_id` como **columna GENERATED STORED** en `p_pedidosh`
4. **Resultado:** Dramático speedup, índice en item_id

### **Índices Agregados**
- `idx_pedidosh_pedidono` — Búsquedas por orden
- `idx_pedidosh_nombrer`, `_materialp`, `_colorp`, `_cliente` — Dropdowns de filtro
- `idx_pedidosh_cancelado` — Filtrado de órdenes canceladas
- `idx_movements_from_process`, `_to_process` — Filtrados de procesos
- `idx_pedidosh_item_id` — Lookups de item

### **Paginación Inteligente**
- Cambio de `count: 'exact'` (ejecutaba 2 queries) → `hayMas` boolean
- Fetch de `PAGE_SIZE + 1` filas para detectar siguiente página
- Evita contar todas las filas (especialmente costoso en BD con RLS)

### **Race Condition Prevention**
- Contador `solicitudActual` en dashboard
- Descarta respuestas stale si llegan fuera de orden
- Previene sobrescritura de datos frescos con datos viejos

### **SQL Optimization**
- Fusión de CTEs en `vw_pedido_progreso` — antes leía `vw_item_progreso` 2 veces
- Uso de `FILTER (WHERE ...)` en lugar de subqueries — más eficiente

---

## 📊 Lógica de Cálculos

### **Visibilidad por Rol**
- **Refilado:** Ve todas las órdenes (super usuario)
- **Acabado:** Solo órdenes donde `entrada_acabado > 0`
- **Mateado:** Solo órdenes donde `entrada_mateado > 0`
- **Empaque:** Solo órdenes donde `entrada_empaque > 0`

### **Porcentaje de Completado (Global)**
```
% = (suma todas tallas procesadas) / (suma todas tallas solicitadas) * 100
```

### **Porcentaje por Proceso (por rol)**
Cada proceso ve su propio porcentaje:
```
% Refilado = (salida refilado) / (total) * 100
% Acabado  = (salida acabado) / (total) * 100
% Mateado  = (salida mateado) / (total) * 100
% Empaque  = (salida empaque) / (total) * 100
```

**IMPORTANTE:** Auto-ruteadas (es_automatico=true) desde Refilado **NO cuentan** hacia porcentaje de Refilado (pero SÍ hacia global).

### **Etapa Actual**
- **Valor:** R (Refilado), A (Acabado), M (Mateado), E (Empaque), Fin (Completado), Sin Procesar
- **Cálculo:** Máxima etapa alcanzada por cualquier item de la orden
- **Se actualiza:** Cada que se crea un movimiento

---

## 🔐 Seguridad & Validaciones

### **Constraints de Negocio**
1. **Un pedido = un destino único** (Acabado O Mateado, nunca ambos)
2. **No reprocesar items** — validación en `registrarMovimientosLote()`
3. **Cancelación respetada** — órdenes canceladas no se procesan
4. **Motivo obligatorio** para eliminar movimiento

### **Auditoría**
- Cada eliminación registra en `log_eliminaciones` con:
  - Usuario que eliminó
  - Snapshot JSON completo del movimiento
  - Motivo texto
  - Timestamp

---

## 📱 UI/UX

### **Responsividad**
- **Desktop** (≥1200px): Layout completo
- **Tablet** (768-1199px): Ajustes grid
- **Mobile** (<768px): Stack vertical

### **Colores**
- Azul primario: `#2563eb`
- Verde éxito: `#16a34a`
- Rojo error: `#dc2626`
- Púrpura (auto-ruteado): `#7c3aed` (fondo: `#ddd6fe`)
- Ámbar advertencia: `#d97706`

### **Modales**
- Eliminación de registros: Requiere **motivo texto**
- Eliminación de reglas: Confirmación simple
- Procesamiento de lotes: Resumen visual de tallas

---

## 📦 Stack Tecnológico

| Aspecto | Tecnología |
|--------|-----------|
| Backend | Supabase (PostgreSQL) |
| Frontend | Vite + Vanilla JS |
| Auth | Supabase Auth (Row Level Security) |
| Excel | XLSX (SheetJS community) |
| Styling | CSS Grid + Flexbox |
| Versionado | Git |

---

## 📝 Archivos Clave

```
src/
├── ui/
│   ├── dashboard.js          → Listado + paginación + filtros
│   ├── orderDetail.js        → Cartilla + batch processing
│   ├── processModal.js       → Modal de procesamiento
│   ├── historyPage.js        → Historial + eliminar
│   ├── reglasPage.js         → CRUD reglas
│   └── toast.js              → Notificaciones
├── services/
│   ├── ordersService.js      → Fetch órdenes + filtros
│   ├── movementsService.js   → Registrar movimientos
│   ├── reglasEnrutamientoService.js → Reglas CRUD
│   ├── excelService.js       → Generar Excel 6 hojas
│   └── destinoService.js     → Destino orden (Acabado/Mateado/Empaque)
├── lib/
│   ├── calculations.js       → Cálculos (porcentaje, etapa, etc)
│   ├── roles.js              → Mapeos rol → proceso + emojis
│   └── validations.js        → Validaciones de negocio
├── config/
│   └── supabaseClient.js     → Inicialización Supabase
└── state/
    └── appState.js           → Estado global (usuario, órdenes activas)

supabase/sql/
├── 005_views_dashboard.sql          → Vistas (item_progreso, pedido_progreso, historial)
├── 006_rls_policies.sql             → Políticas de seguridad
├── 010_order_destino.sql            → Tabla destino + constraint único
├── 011_filtros_opciones.sql         → Vistas para dropdowns
├── 012_reglas_enrutamiento.sql      → Tabla + trigger automático
├── 014_eliminacion_registros.sql    → Log eliminaciones + función
├── 015_indices_performance.sql      → Índices para speedup
├── 016_item_id_materializado.sql    → Columna generated stored
└── FASE_11_SUPABASE_MIGRATION.sql   → Optimizaciones finales vw_pedido_progreso

index.html                   → HTML estructura + CSS
```

---

## 🎯 Estado Actual

✅ **COMPLETO:**
- Dashboard listado paginado con filtros dinámicos
- Cartilla de orden con batch processing
- Historial de movimientos con eliminación auditada
- Reglas de enrutamiento automático (CRUD)
- Descarga Excel completa (6 hojas)
- Seguridad (RLS, validaciones, auditoría)
- Performance optimizado (millisegundos)

✅ **PRÓXIMOS PASOS (Fuera del alcance actual):**
- Crear rol "Visualizador" (si se necesita)
- Reportes avanzados por fecha/cliente
- Exportar PDF en lugar de Excel
- Análisis de bottlenecks (cuál proceso es más lento)

---

## 🚨 Notas Importantes

1. **No hacer commits manualmente** — el código tiene cambios pending
2. **`npm install`** necesario si es primera vez (para `xlsx`)
3. **`npm run dev`** para probar localmente
4. **Migraciones SQL** se aplican directamente en Supabase SQL Editor
5. **RLS activo** — solo usuarios autenticados ven sus datos
6. **Datos de prueba:** ~16,500 órdenes en producción actual

---

**Versión:** Proyecto FASE 7 (Excel + Eliminaciones + Reglas + Batch Processing)  
**Última actualización:** 2026-08-07
