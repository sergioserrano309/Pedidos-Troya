# Plan: Dashboard operativo de procesos (Refilado → Acabado / Mateado → Empaque)

Documento de trabajo. Aquí se registran las decisiones del dashboard por rol, lo que ya existe en la plataforma, lo que hay que validar antes de tocar datos viejos, y el orden de desarrollo. **No sustituye** `DOCUMENTACION_TECNICA.md`.

Última actualización: 4 nov 2026.

---

## 1. Objetivo

Dar a **refilado, acabado, mateado y empaque** una pestaña de dashboard **fácil de usar en planta**:

- Ver qué les **entró**.
- Registrar de forma simple qué **salió**.
- Ver el **pendiente** (entrada − salida).
- Priorizar lo que **llegó primero al área**.
- Cada rol ve **solo su tubería**. No se cruza información entre áreas.

El dashboard técnico del **validador** (solicitado / despachado / pendiente por despachar, SQL 084) **no se modifica**.

Órdenes, Compensación, Registros, Despachos, Control Central e Inyección **no se tocan**.

---

## 2. Decisiones cerradas

| # | Tema | Decisión |
|---|---|---|
| 1 | Dónde vive | Pestaña nueva **Dashboard** dentro de Órdenes. El dashboard del validador queda igual. |
| 2 | Granularidad | **Una fila por pedido.** El número de pedido **no se muestra**. Hay que **validar** si en planta se pueden distinguir dos pedidos iguales (misma suela / material / color) sin ver el número. Internamente la fila sigue siendo un pedido. |
| 3 | Talla | Información adicional dentro de la fila del pedido. El usuario **escribe la cantidad por talla**. |
| 4 | Destino | Un pedido se envía a **un solo proceso**. Sí se permiten **parciales**. |
| 5 | Refilado → Empaque | En este dashboard **no**. Refilado solo manda a **Acabado** o **Mateado**. Datos viejos / reglas: **validar** (§8.1). |
| 6 | Empaque: procesados vs a despachar | **No son lo mismo.** Fase 2. **Validar** (§8.3). |
| 7 | Origen | Cada entrada lleva **etiqueta del proceso que la mandó**. |
| 8 | Orden | Por **llegada al área** del lote **más viejo que todavía está pendiente**. El front lo dice claro. **Validar** en planta si esa hora se entiende (§8.6). |
| 9 | Campos visibles | Suela, material, color, tallas, unidades (entrada / salida / pendiente), llegada al área, origen. **Sin número de pedido. Sin cliente.** |
| 10 | Cómo se registra una salida | El usuario escribe unidades **por talla**. **Cada talla** tiene su botón de envío. Antes de guardar, un **resumen corto** (talla, cantidad, destino) y confirmar. Sin abrir el detalle de Órdenes. |
| 11 | Aislamiento | Solo de **pantalla**. No se cambia RLS en esta fase. |
| 12 | Resto de módulos | **No se tocan.** |
| 13 | Inicio del flujo | **Todo inicia en refilado.** Ningún otro proceso recibe trabajo que refilado no haya enviado. Auto-enrutamiento: refilado no ve esos pedidos (igual que Órdenes); el destino sí los ve como enviados por Refilado (el sistema actúa como refilado). **No se cambia en fase 1.** Validar si más adelante debe hacerlo una persona (§8.2). |
| 14 | Alcance primera entrega | **Refilado + Acabado + Mateado.** Empaque después. |
| 15 | Validador | **No** ve esta pestaña. Sigue con su dashboard técnico. |
| 16 | Nombre de la pestaña | **Dashboard.** |
| 17 | Filtros | **No.** Solo lista ordenada por llegada al área. |
| 18 | Números por talla | Se muestra el **pendiente de esa talla**. Entrada/salida/pendiente del **pedido** van en el encabezado del bloque. |
| 19 | Devoluciones / reproceso | **No entran en fase 1.** Se documentan y se validan después (§8.7). |
| 20 | Destino en refilado | Un botón **Enviar** por talla. **Acabado o Mateado se elige en el resumen.** Si el pedido ya tiene destino, el resumen lo muestra fijo. |
| 21 | Observaciones | **No.** El movimiento queda sin texto. |
| 22 | Paginación | **30 pedidos por página**, igual que Órdenes, por llegada al área. |

---

## 3. Cómo llega la información hoy (no se inventa)

Las órdenes **no se crean en esta app**. Access (ERP) las sincroniza a `p_pedidosh`. Cada fila es un pedido × talla, con:

- `PedidoNo` — número de pedido (clave interna; **no se pinta** en este dashboard)
- `NombreR` — nombre de la suela
- `MaterialP` — material
- `ColorP` — color
- `Talla`
- `CantidadP` — unidades pedidas (entrada de refilado)
- `FechaP` — fecha del pedido
- `created_at` — cuándo se insertó la línea en Supabase

El avance de planta **no se guarda en el pedido**. Se calcula con `production_movements` (quién mandó qué, de qué proceso a cuál, cuántas unidades, cuándo).

Fórmulas por área (igual que `src/lib/stageQuantities.js`):

```
Refilado:   entrada = CantidadP del pedido
            salida  = suma de movimientos from_process = Refilado
            pendiente = entrada − salida

Acabado:    entrada = suma de movimientos to_process = Acabado
            (solo los que vienen de Refilado; ver §4)
            salida  = suma de movimientos from_process = Acabado
            pendiente = entrada − salida

Mateado:    igual, con Mateado.

Empaque:    igual, con Empaque. (fase 2)
            entrada solo desde Acabado o Mateado.
```

Pendiente nunca es negativo.

---

## 4. Flujo acordado

```
Órdenes (ERP / Access)
        │
        ▼
   [Refilado]  ← única puerta de entrada. Nadie más recibe del ERP.
        │
        │  parciales permitidos; cantidad la escribe el usuario por talla
        │  un pedido → un solo destino
        ├──────────────► [Acabado] ──► [Empaque]  (fase 2)
        │
        └──────────────► [Mateado] ──► [Empaque]  (fase 2)
                              │
                              ▼
                    Activas → Procesados → A despachar → Despachados
                    (fase 2; procesados ≠ a despachar; validar)
```

Regla de pipeline:

- **Solo refilado** toma trabajo de las órdenes.
- Acabado y mateado **solo** reciben lo que refilado envió (`from_process = Refilado`).
- Empaque **solo** recibe lo que acabado o mateado enviaron (fase 2). En el dashboard nuevo, refilado **no** manda a empaque.
- Refilado elige **Acabado o Mateado** la primera vez que envía ese pedido. Los parciales siguientes van al mismo destino.
- Cada fila muestra de qué área vino. En refilado el origen es el pedido (ERP).

Auto-enrutamiento (hoy): el sistema inserta movimientos `Refilado → destino` con `es_automatico = true`. Para acabado/mateado eso **sí** cuenta como “lo envió refilado” (el proceso, no una persona). Esos pedidos **no** aparecen en el dashboard de refilado. Fase 1 no cambia este comportamiento.

---

## 5. Qué ve cada rol (fase 1)

Pestaña **Dashboard**, distinta por rol. Mismos campos, distintas cantidades.

### 5.1 Quién ve la pestaña

| Rol | Pestaña Dashboard operativa | Dashboard técnico (084) |
|---|---|---|
| Refilado | Sí (su tubería) | No |
| Acabado | Sí (su tubería) | No |
| Mateado | Sí (su tubería) | No |
| Empaque | No en fase 1 | No |
| Validador | **No** | Sí, igual que hoy |
| Comercial / Propuesta | No | No |

Rol Activo del validador **no** abre este dashboard en fase 1.

### 5.2 Qué se ve en cada fila (un pedido)

| Campo | Visible | Notas |
|---|---|---|
| Número de pedido | **No** | Sigue siendo la clave interna. **Validar** si hace falta mostrarlo para no confundir dos pedidos iguales (§8.5). |
| Cliente | **No** | |
| Suela | Sí | `NombreR` |
| Material | Sí | `MaterialP` |
| Color | Sí | `ColorP` |
| Tallas | Sí | Extra, dentro de la fila. Cada talla con su pendiente y un campo para escribir unidades. |
| Origen | Sí | Refilado: “Pedido”. Acabado / mateado: “Refilado”. Empaque (fase 2): “Acabado” o “Mateado”. |
| Llegada al área | Sí | Fecha y hora. Texto en pantalla: **“Llegada al área”**. Hora de Colombia. |
| Entrada / salida / pendiente | Sí | Totales del pedido en **esta** área. |
| Registrar | Sí | Cantidad por talla + botón de destino. |

No se muestran: %, vira / acabado / esterilla / marquilla, días del pedido, Control Central.

### 5.3 Orden de las filas

De la **llegada al área más antigua** a la más nueva, usando el lote **más viejo que todavía está pendiente**.

| Área | Llegada al área |
|---|---|
| Refilado | Momento en que el pedido existe para refilado. Candidatos: `p_pedidosh.created_at` o `FechaP`. **Validar** (§8.4). |
| Acabado / mateado | Hora del movimiento de entrada más viejo cuyas unidades **aún no han salido** (FIFO sobre los parciales). Si el parcial del lunes ya salió y queda el del miércoles, manda la hora del miércoles. **Validar** en planta (§8.6). |

Aproximación técnica de fase 1 (si el FIFO exacto por unidades se complica): entre las tallas con pendiente > 0, la `MIN(created_at)` de sus entradas a esa área. Dejar anotado si no coincide del todo con el FIFO por unidades.

### 5.4 Qué pedidos salen en la lista

- Refilado: pendiente de refilado > 0, **sin** auto-enrutados (igual que Órdenes).
- Acabado / mateado: les llegó algo **desde Refilado** y aún tienen pendiente.
- Sin líneas canceladas (`Cancelado`).
- Cierre forzado: fuera (siguen en Completadas / Registros).
- **No** se aplica el corte “desde el 3095” del dashboard del validador.

Al quedar pendiente = 0, la fila **sale**. El historial sigue en **Registros**.

### 5.5 Cómo se registra una salida (fase 1)

En la misma fila, **talla por talla**:

1. Cada talla muestra su **pendiente** y un campo para escribir unidades.
2. Vacío o 0 = esa talla no se manda. No se puede escribir más que el pendiente de esa talla.
3. **Cada talla** tiene un solo botón **Enviar** (no se mandan varias de un golpe).
4. Se abre un **resumen corto**: suela, material, color, talla, cantidad. Sin número de pedido. Sin observaciones.
   - Refilado, primer envío del pedido: en el resumen se elige **Acabado** o **Mateado** y se confirma. Eso **fija** `order_destino`.
   - Refilado, el pedido ya tiene destino: el resumen lo muestra fijo; no se puede cambiar.
   - Acabado / mateado: el resumen muestra destino **Empaque** fijo.
5. Al confirmar se crea **un** `production_movement` de esa talla (mismo modelo que hoy). Compensación y Registros no se tocan.

Destinos del dashboard nuevo: refilado → Acabado | Mateado (nunca Empaque). Acabado / mateado → Empaque.

Si la talla queda en pendiente 0, desaparece de la lista de tallas. Si el pedido queda en pendiente 0, desaparece el bloque.

---

## 6. Pantalla (intención, no mock final)

Fácil de leer. Nada del dashboard técnico del validador.

```
[ Órdenes: Activas | Completadas | Registros | Dashboard ]

  Pendiente del área: 1.240 und
  Ordenado por llegada al área (más antiguo arriba)

  Suela X · Material Y · Color Z
  Origen  Pedido                         Llegada al área  3 nov 2026, 08:14
  Entró 200 · Salió 80 · Pendiente 120

    Talla 35   pend. 20   [    ]  [ Enviar ]
    Talla 36   pend. 40   [    ]  [ Enviar ]
    Talla 37   pend. 10   [    ]  [ Enviar ]

  → resumen corto
     (refilado: elegir Acabado o Mateado si el pedido aún no tiene destino)
     (si ya tiene destino, o en acabado/mateado: destino fijo)
  → confirmar
```

Sin filtros. Sin observaciones. Páginas de 30. Sin número de pedido a la vista. Dos bloques con la misma suela / material / color pueden verse muy parecidos: **validar** (§8.5).

---

## 7. Qué no se toca

- Dashboard del validador (`dashboardPage.js`, `lib/dashboard.js`, SQL 084).
- Órdenes Activas / Completadas (listado, detalle, modal Procesar).
- Compensación.
- Registros.
- Despachos (A despachar / Despachado).
- Control Central.
- Vista Inyección de empaque.
- Reglas de enrutamiento (UI del validador).
- RLS (aislamiento solo en pantalla).

En **Órdenes** (flujo viejo) refilado **sigue pudiendo** mandar a Empaque. El **dashboard nuevo** no ofrece ese destino. Limpiar el flujo viejo queda a la validación del §8.

---

## 8. Hay que validar (no inventar; no borrar a ciegas)

En fase 1 **no se cambian** estos comportamientos. Sí se anotan.

### 8.1 Refilado → Empaque (histórico y reglas)

Hoy refilado **sí puede** terminar en Empaque en Órdenes / reglas / `order_destino`, y el CHECK de SQL 002 a veces no lo permite. Validar conteos en producción (manual vs automático) antes de quitarlo del sistema viejo.

El dashboard nuevo **no** ofrece Empaque como destino de refilado.

### 8.2 Enrutamiento automático y “todo inicia en refilado”

Hoy una regla puede crear `Refilado → Acabado|Mateado|Empaque` sin que una persona de refilado lo vea.

Regla de negocio acordada: **otro proceso no puede recibir nada que refilado no haya enviado.**

Matices:

- El auto-enrutamiento **sí** envía como `from_process = Refilado`. Para acabado/mateado es entrada desde refilado.
- **No** es una persona de refilado quien lo mandó.
- Destino Empaque por regla salta acabado/mateado: choca con “refilado no manda a empaque” y hay que validarlo con §8.1.

Fase 1:

- Dashboard de refilado: **no muestra** auto-enrutados (igual que Órdenes).
- Dashboard de acabado/mateado: **sí muestra** lo que les llegó con origen Refilado, aunque haya sido automático.
- No se apagan las reglas.

Pendiente de validar después: ¿debe hacerlo siempre una persona de refilado?

### 8.3 Empaque: cuatro estados (fase 2)

Hoy, al marcar Completado, ya se puede despachar. El usuario dijo que **procesados ≠ a despachar**. Validar en planta antes de construir esa pantalla.

### 8.4 Llegada al área en refilado

No hay movimiento “entrada a refilado”. Candidatos: `created_at` de `p_pedidosh` vs `FechaP`.

### 8.5 No mostrar el número de pedido

Decisión: **oculto**. Riesgo: dos pedidos con la misma suela, material y color se ven iguales (solo se distinguen por tallas, cantidades y llegada al área).

Validar en planta si eso basta o si hay que mostrar el número (o el cliente) para no registrar la salida en el bloque equivocado.

La app **siempre** sabe el `order_number` por detrás.

### 8.6 Hora del lote pendiente más viejo

Decisión: ordenar por esa hora. Validar si en planta se entiende, y si el FIFO aproximado por talla pendiente es suficiente.

### 8.7 Devoluciones / reproceso

Comercial puede devolver y mandar a reproceso (otra vez a refilado / acabado / mateado). Eso **no** es “lo envió refilado”.

**Fase 1: no se tienen en cuenta.** Este dashboard solo muestra:

- Refilado: lo pedido (`CantidadP`), sin auto-enrutados.
- Acabado / mateado: entradas con `from_process = Refilado`.

Un reproceso **no** aparece aquí. Validar después si debe entrar y con qué etiqueta de origen.

---

## 9. Plan de desarrollo por partes

### Fase 0 — Validaciones de datos (sin UI nueva)

Solo lectura:

- Movimientos Refilado → Empaque (manual vs automático).
- `order_destino` y reglas con destino Empaque.
- Pedidos auto-enrutados.
- `FechaP` vs `created_at` en pedidos reales.
- Pedidos distintos con misma suela / material / color a la vez (qué tan seguido chocaría §8.5).

Salida: números + nota en este archivo.

### Fase 1 — Dashboard Refilado / Acabado / Mateado

En código (4 nov 2026). Hay que **ejecutar en Supabase** `supabase/sql/085_vista_dashboard_proceso.sql`. El dashboard del validador (084) no se tocó. Reversa: `085_revertir_vista_dashboard_proceso.sql`.

Pantalla: pestaña Dashboard (solo refilado / acabado / mateado) → `src/ui/dashboardProcesoPage.js`. Datos: `vw_dashboard_proceso`. Envío: un movimiento por talla vía `production_movements` + `order_destino`.

1. Vista SQL de solo lectura por proceso (pedido interno, suela, material, color, tallas, origen, llegada al área, entrada, salida, pendiente). Sin escribir en `p_pedidosh`.
2. Pestaña **Dashboard** solo para esos tres roles. Validador no la ve.
3. Lista simple, sin número de pedido, ordenada por llegada al área del pendiente más viejo. Texto de ayuda visible.
4. Registrar **talla por talla**: cantidad + **Enviar** + resumen corto (en refilado se elige el destino ahí si aún no está fijo) + confirmar. Un movimiento por confirmación. Sin observaciones.
5. Refilado: Acabado | Mateado en el resumen (la primera talla fija el destino). Acabado y mateado: Empaque fijo.
6. Pendiente 0 de la talla o del pedido → desaparece.
7. Sin filtros. No tocar validador, Órdenes, Compensación, Registros, Despachos. No incluir reprocesos.

### Fase 2 — Dashboard Empaque

Después de §8.3. Mismos campos + origen Acabado / Mateado. Cuatro estados.

### Fase 3 — (opcional, no pedida)

- RLS por proceso.
- Quitar Empaque como destino de refilado en Órdenes, si la validación lo confirma.
- Replantear auto-enrutamiento para que siempre lo ejecute una persona de refilado.
- Validador viendo este dashboard según Rol Activo.
- Mostrar número de pedido, si la validación §8.5 lo pide.

---

## 10. Preguntas abiertas

Ninguna bloquea la fase 1. Lo que falta es **validar en planta / datos** (§8), no decidir pantalla.

Supuestos cerrados al no contradecirlos: **sin observaciones**; **30 pedidos por página**.

---

## 11. Criterio técnico (cuando se implemente)

- No escribir en `p_pedidosh`.
- Reusar `production_movements` y `order_destino`; no inventar tabla de tickets si con eso basta.
- Acabado/mateado: contar solo entradas con `from_process = 'Refilado'`. Reproceso/devoluciones fuera de fase 1.
- Vistas nuevas `security_invoker`, solo SELECT, numeradas a partir de `085_`.
- Scripts de reversa, como el resto de SQL del repo.
- UI en vanilla JS, mismo patrón de pestañas. El validador sigue cargando `dashboardPage.js`; los tres roles cargan **otra** pantalla (no reutilizar la lógica 084).
- Textos en español, hora de Colombia para “Llegada al área”.
- `order_number` viaja en el HTML como dato interno (`data-order`), no como texto visible.

---

## 12. Historial de decisiones

| Fecha | Qué se cerró |
|---|---|
| 4 nov 2026 | Alcance, granularidad por pedido, talla extra, un destino con parciales, sin Refilado→Empaque en el dashboard nuevo, origen visible, orden por llegada al área, registro con cantidad + botón, aislamiento solo UI, no tocar el resto de módulos, fase 1 = R/A/M, empaque después. Validador 084 intacto. |
| 4 nov 2026 | Cantidad **la escribe el usuario por talla**. Número de pedido **oculto** (validar). Orden = lote pendiente más viejo (validar). Validador no ve la pestaña. Nombre **Dashboard**. Pipeline: nadie recibe trabajo que refilado no haya enviado. Auto-enrutamiento se deja como está en fase 1 (refilado no los ve; el destino sí, origen Refilado). |
| 4 nov 2026 | Envío **talla por talla**. Confirmación con **resumen corto**. **Sin filtros.** Por talla se ve el **pendiente**. Reproceso/devoluciones: documentados, se validan después, **fuera de fase 1**. |
| 4 nov 2026 | Refilado: un **Enviar** por talla; **Acabado/Mateado se elige en el resumen** (si ya hay destino, queda fijo). Sin observaciones. Páginas de 30. Fase 1 de pantalla **cerrada**. |
