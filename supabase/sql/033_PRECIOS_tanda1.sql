-- =====================================================================
-- DATOS INICIALES: PRECIOS DE SUELAS
-- =====================================================================
-- Que hace este archivo:
--   Carga en las tablas los datos que ya tenias en tu Excel (PRECIOS.xlsx,
--   hoja BASE). Son 63 combinaciones de suela con sus precios.
--
-- IMPORTANTE: ejecuta primero 01_schema.sql. Este archivo depende de que
-- las tablas ya existan.
--
-- NOTA: se excluyeron del Excel original las filas 65 a 87 (una lista de
-- precios sueltos bajo la etiqueta 'ACABADOS', sin referencia ni material
-- asociado). Revisa el mensaje de Claude en el chat para decidir que hacer
-- con esos datos.
-- =====================================================================

-- Materiales
insert into materiales (nombre) values
  ('EXPANSO'), ('GOMAFLEX'), ('PVC'), ('T.R.')
on conflict (nombre) do nothing;

-- Colores
insert into colores (nombre) values
  ('COLORES'), ('NEGRO')
on conflict (nombre) do nothing;

-- Clientes ('TODOS' = precio general)
insert into clientes (nombre) values
  ('BOOTS MICHEL'), ('FIDENCY'), ('TODOS')
on conflict (nombre) do nothing;

-- Tallas
insert into tallas (rango, talla_min, talla_max) values
  ('27-33', 27, 33),
  ('34-39', 34, 39),
  ('34-40', 34, 40),
  ('34-41', 34, 41),
  ('37-42', 37, 42),
  ('37-43', 37, 43)
on conflict (rango) do nothing;

-- Referencias (modelos de suela)
insert into referencias (codigo) values
  ('ABRIL'),
  ('ADA'),
  ('ADEL'),
  ('ADRIA'),
  ('ALDANA'),
  ('ALEJANDRA'),
  ('ALEN'),
  ('ALEX'),
  ('ALHELI'),
  ('ALMA'),
  ('AMAYA'),
  ('AMBER'),
  ('ANABEL'),
  ('ANALIA'),
  ('ANGELA'),
  ('ANGELLO'),
  ('ANTONELLA'),
  ('ANTONIA'),
  ('ARYA'),
  ('ASHA'),
  ('ASHER'),
  ('AYAX'),
  ('BOSTON'),
  ('BRENDA'),
  ('BRISA'),
  ('BRITANY'),
  ('CAMILA'),
  ('CARMELA'),
  ('CELIA'),
  ('CESAR'),
  ('CLARK'),
  ('CORINA'),
  ('DAFNE'),
  ('ISSA'),
  ('MARIA'),
  ('SIMONA')
on conflict (codigo) do nothing;

-- ---------------------------------------------------------------------
-- Precios (63 combinaciones tomadas del Excel)
-- ---------------------------------------------------------------------
insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 17100, 19100
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANALIA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 14600, 15900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADRIA' and m.nombre = 'GOMAFLEX' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 13500, 15500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADRIA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11800, 12900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADRIA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 17200, 20300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALHELI' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 15300, 17500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALHELI' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, true, false, false, false, '', 11700, 13600
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7800, 8500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 12900, 15000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRENDA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 8300, 9800
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRITANY' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7700, 0
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRITANY' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7700, 9000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'COLORES' and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7700, 9000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ABRIL' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11600, 13400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11600, 13400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADEL' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11400, 13200
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALDANA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9500, 11100
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALDANA' and m.nombre = 'PVC' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 8600, 9300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALDANA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7300, 8500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALEJANDRA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9200, 10700
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALEN' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11100, 13000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALEX' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9100, 10600
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALMA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 8100, 10900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALMA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 10600, 0
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AMAYA' and m.nombre = 'T.R.' and c.nombre = 'FIDENCY' and co.nombre = 'NEGRO' and t.rango = '34-39'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 13900, 16000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AMBER' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 12100, 14100
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AMBER' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 15600, 18000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANABEL' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 10200, 11100
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9600, 10400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11900, 12900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELLO' and m.nombre = 'GOMAFLEX' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11000, 12900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELLO' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11800, 13500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANALIA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11000, 12900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANTONELLA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9900, 11600
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANTONIA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7600, 8300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANTONIA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 0, 22400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALHELI' and m.nombre = 'T.R.' and c.nombre = 'FIDENCY' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 12000, 0
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ARYA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9600, 10400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ARYA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11600, 13400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ASHA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, true, true, false, false, false, '', 13900, 16000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ASHER' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'COLORES' and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, true, false, false, false, false, '', 12600, 14600
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ASHER' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'COLORES' and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7500, 9700
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AYAX' and m.nombre = 'PVC' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 10400, 11500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AYAX' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9600, 0
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AYAX' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 10300, 12100
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, true, false, false, false, '', 13400, 15400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON' and m.nombre = 'T.R.' and c.nombre = 'FIDENCY' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11700, 13300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRISA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 13500, 14700
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRISA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 10100, 11800
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CAMILA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 7500, 8800
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CAMILA' and m.nombre = 'T.R.' and c.nombre = 'FIDENCY' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 14100, 16300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CARMELA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11300, 16600
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CARMELA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 8900, 10200
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CELIA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 8100, 9500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CELIA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-41'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 12400, 14300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CESAR' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 9700, 11100
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CESAR' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 10100, 11000
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CLARK' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 15100, 17500
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CORINA' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 15500, 17900
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CORINA' and m.nombre = 'T.R.' and c.nombre = 'FIDENCY' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, true, false, false, false, '', 16800, 19400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CORINA' and m.nombre = 'T.R.' and c.nombre = 'FIDENCY' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '3.5', 9000, 10300
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAFNE' and m.nombre = 'T.R.' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 11500, 0
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA' and m.nombre = 'EXPANSO' and c.nombre = 'BOOTS MICHEL' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor, precio_fabricante)
select r.id, m.id, c.id, co.id, t.id, false, false, false, false, false, '', 13600, 15400
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARIA' and m.nombre = 'EXPANSO' and c.nombre = 'TODOS' and co.nombre = 'NEGRO' and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor = excluded.precio_distribuidor,
  precio_fabricante   = excluded.precio_fabricante;
