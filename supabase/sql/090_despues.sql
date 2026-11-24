-- =====================================================================
-- 090_despues.sql — CORRER DESPUES de ejecutar el 090 (y despues de 090_antes.sql)
--
-- Compara lo que devuelven ahora las vistas con la foto de 090_antes.sql.
-- Cada consulta dice que se espera. Todo es de solo lectura, salvo el ultimo
-- bloque, que borra las tablas de apoyo (correrlo solo cuando todo cuadre).
-- =====================================================================

-- 1) Pedidos cuyo ESTADO, ETAPA o PENDIENTES cambiaron.
--    ESPERADO: 0 filas con los datos de hoy (ninguna talla ha superado su
--    pedido todavia, asi que el calculo por talla da lo mismo que la suma).
select
  o.order_number,
  o.estatus_general as estatus_antes, n.estatus_general as estatus_ahora,
  o.etapa_actual as etapa_antes, n.etapa_actual as etapa_ahora,
  o.total_pendiente as pend_antes, n.total_pendiente as pend_ahora
from public.tmp_090_pedidos o
join public.vw_pedido_progreso n using (order_number)
where (o.estatus_general, o.etapa_actual, o.total_pendiente,
       o.pendiente_refilado, o.pendiente_acabado, o.pendiente_mateado, o.pendiente_empaque)
  is distinct from
      (n.estatus_general, n.etapa_actual, n.total_pendiente,
       n.pendiente_refilado, n.pendiente_acabado, n.pendiente_mateado, n.pendiente_empaque)
order by o.order_number desc;

-- 2) Pedidos cuyo % cambio por una razon DISTINTA a "no redondear a 100".
--    ESPERADO: 0 filas.
select o.order_number,
       o.porcentaje_completado as c_antes, n.porcentaje_completado as c_ahora,
       o.porcentaje_refilado   as r_antes, n.porcentaje_refilado   as r_ahora,
       o.porcentaje_acabado    as a_antes, n.porcentaje_acabado    as a_ahora,
       o.porcentaje_mateado    as m_antes, n.porcentaje_mateado    as m_ahora,
       o.porcentaje_empaque    as e_antes, n.porcentaje_empaque    as e_ahora
from public.tmp_090_pedidos o
join public.vw_pedido_progreso n using (order_number)
where (o.porcentaje_completado <> n.porcentaje_completado and not (o.porcentaje_completado = 100 and n.porcentaje_completado = 99))
   or (o.porcentaje_refilado   <> n.porcentaje_refilado   and not (o.porcentaje_refilado   = 100 and n.porcentaje_refilado   = 99))
   or (o.porcentaje_acabado    <> n.porcentaje_acabado    and not (o.porcentaje_acabado    = 100 and n.porcentaje_acabado    = 99))
   or (o.porcentaje_mateado    <> n.porcentaje_mateado    and not (o.porcentaje_mateado    = 100 and n.porcentaje_mateado    = 99))
   or (o.porcentaje_empaque    <> n.porcentaje_empaque    and not (o.porcentaje_empaque    = 100 and n.porcentaje_empaque    = 99));

-- 3) Los casos "no redondear a 100" (esperados, INFORMATIVO): pedidos que
--    antes decian 100% teniendo algo pendiente y ahora dicen 99%.
select o.order_number,
       o.porcentaje_empaque as empaque_antes, n.porcentaje_empaque as empaque_ahora,
       n.total_pendiente
from public.tmp_090_pedidos o
join public.vw_pedido_progreso n using (order_number)
where (o.porcentaje_completado = 100 and n.porcentaje_completado = 99)
   or (o.porcentaje_refilado   = 100 and n.porcentaje_refilado   = 99)
   or (o.porcentaje_acabado    = 100 and n.porcentaje_acabado    = 99)
   or (o.porcentaje_mateado    = 100 and n.porcentaje_mateado    = 99)
   or (o.porcentaje_empaque    = 100 and n.porcentaje_empaque    = 99)
order by o.order_number desc;

-- 4) Pedidos que aparecian y ya no (o al reves). ESPERADO: 0 filas.
select 'solo antes' as donde, o.order_number from public.tmp_090_pedidos o
 where not exists (select 1 from public.vw_pedido_progreso n where n.order_number = o.order_number)
union all
select 'solo ahora', n.order_number from public.vw_pedido_progreso n
 where not exists (select 1 from public.tmp_090_pedidos o where o.order_number = n.order_number);

-- 5) Liquidacion de comisiones (vw_pedido_rol_gate). ESPERADO: 0 filas.
--    Si sale alguna, es un pedido+rol cuya fecha de liquidacion cambio: revisarla
--    antes de seguir (puede ser un pedido que hoy se liquida con una talla corta).
select
  coalesce(o.order_number, n.order_number) as order_number,
  coalesce(o.rol, n.rol) as rol,
  o.fecha_liquidacion as fecha_antes, n.fecha_liquidacion as fecha_ahora
from public.tmp_090_gate o
full outer join public.vw_pedido_rol_gate n
  on n.order_number = o.order_number and n.rol = o.rol
where o.fecha_liquidacion is distinct from n.fecha_liquidacion
   or (o.order_number is null) or (n.order_number is null)
order by 1 desc, 2;

-- 6) Columnas nuevas funcionando (INFORMATIVO): pedidos con tallas incompletas.
select order_number, tallas_total, tallas_ok_refilado, tallas_ok_acabado,
       tallas_ok_mateado, tallas_ok_empaque, estatus_general
from public.vw_pedido_progreso
order by order_number desc
limit 10;

-- 7) El candado y la regla existen.
select
  (select count(*) from pg_trigger where tgname = 'trg_validar_tope_refilado' and not tgisinternal) as candado_instalado,
  public.fn_extra_refilado(5) as extra_para_5,
  public.fn_extra_refilado(100) as extra_para_100;

-- =====================================================================
-- LIMPIEZA: correr SOLO cuando las consultas 1, 2, 4 y 5 salieron vacias
-- (o expliquen todo lo que mostraron).
-- =====================================================================
-- drop table if exists public.tmp_090_pedidos;
-- drop table if exists public.tmp_090_gate;
