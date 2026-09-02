-- =====================================================================
-- CARGAR DATOS - BASE DE PRECIOS DE SUELAS v2
-- =====================================================================
-- Qué hace este archivo:
--   Carga en las tablas los 438 registros limpios del Excel nuevo
--   BDPRECIOSMKT.xlsx
--
-- IMPORTANTE: ejecuta primero 04_limpiar_supabase_SOLO_NUESTRAS_TABLAS.sql
-- luego 05_schema_nuevo.sql, y finalmente este archivo.
-- =====================================================================

-- 1. CARGAR MATERIALES (6 tipos)
insert into materiales (nombre) values
  ('EXPANSO'),
  ('GOMAFLEX'),
  ('PVC'),
  ('PVC CRISTAL'),
  ('T.R.'),
  ('TPU')
on conflict (nombre) do nothing;

-- 2. CARGAR REFERENCIAS (205 modelos)
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
  ('ANA'),
  ('ANABEL'),
  ('ANALIA'),
  ('ANDRES'),
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
  ('CANADA'),
  ('CARMELA'),
  ('CELIA'),
  ('CESAR'),
  ('CLARK'),
  ('CORINA'),
  ('DAFNE'),
  ('DAKOTA'),
  ('DALLAS'),
  ('DAMARA'),
  ('DARSY'),
  ('DEIMER'),
  ('DIAMANTE'),
  ('DIANA'),
  ('DOROTEA'),
  ('DOROTY'),
  ('DOTACION'),
  ('DR'),
  ('EIMY'),
  ('ELENA'),
  ('ELSA'),
  ('EMILIA'),
  ('EMYSOFIA'),
  ('ERIKA'),
  ('ESMERALDA'),
  ('ESTRELLA'),
  ('EVELIN'),
  ('FENIX'),
  ('FLAVIA'),
  ('FRANCIA'),
  ('FRANCO'),
  ('GABY'),
  ('GEMA'),
  ('GEORGE'),
  ('GINA'),
  ('GISELL'),
  ('GRETA'),
  ('GUADALUPE'),
  ('HELEN'),
  ('HILARY'),
  ('IRIS'),
  ('IRLANDA'),
  ('ISABEL'),
  ('ISSA'),
  ('ITALIA'),
  ('IVANKA'),
  ('IVY'),
  ('JEIMI'),
  ('JORDAN'),
  ('JULIANA'),
  ('JULIETA'),
  ('JULIO'),
  ('KARINA'),
  ('KARLA'),
  ('KARLOTA'),
  ('KATERIN'),
  ('KATTY'),
  ('KEILA'),
  ('KEITY'),
  ('KENDAL'),
  ('KIRA'),
  ('KLOE'),
  ('LANCE'),
  ('LARA'),
  ('LAURA'),
  ('LAURENT'),
  ('LEIN'),
  ('LEO'),
  ('LILA'),
  ('LINA'),
  ('LINDA'),
  ('LIVES'),
  ('LIVI'),
  ('LIZET'),
  ('LOLA'),
  ('LOLITA'),
  ('LONDON'),
  ('LORENA'),
  ('LORY'),
  ('LUCAS'),
  ('LUCIANA'),
  ('LUISA'),
  ('MADONA'),
  ('MAGUI'),
  ('MAITE'),
  ('MALAGA'),
  ('MALU'),
  ('MANUELA'),
  ('MARCE'),
  ('MARGARATH'),
  ('MARGOTH'),
  ('MARIA'),
  ('MARIANA'),
  ('MARLENY'),
  ('MARTHA'),
  ('MARTINA'),
  ('MARTINELI'),
  ('MARYLUZ'),
  ('MEGAN'),
  ('MELANIA'),
  ('MERIDA'),
  ('MICHEL'),
  ('MIEL'),
  ('MILE'),
  ('MILLER'),
  ('MONACO'),
  ('MONIK'),
  ('MONSERRAT'),
  ('NAILA'),
  ('NARDO'),
  ('NASTIA'),
  ('NATALY'),
  ('NATIS'),
  ('NAYIVE'),
  ('NIRVANA'),
  ('NOELIA'),
  ('PALOMA'),
  ('PAMELA'),
  ('PAOLA'),
  ('PARIS'),
  ('PATRICIA'),
  ('PATRICK'),
  ('PAULA'),
  ('PEGUI'),
  ('PENY'),
  ('PERLA'),
  ('PIKO'),
  ('PLANTISUELAJOHA'),
  ('POLETH'),
  ('PRINCE'),
  ('RAFAELA'),
  ('REY'),
  ('ROBIN'),
  ('ROSSY'),
  ('RUBY'),
  ('RUMANIA'),
  ('SALMA'),
  ('SALOME'),
  ('SANDALIA'),
  ('SARTA'),
  ('SELENA'),
  ('SEXIMODA'),
  ('SHARON'),
  ('SHIRLY'),
  ('SIENA'),
  ('SILVANA'),
  ('SILVIA'),
  ('SIMONA'),
  ('SIMONITA'),
  ('SOFI'),
  ('SOL'),
  ('SONY'),
  ('STEFANY'),
  ('TANIA'),
  ('TATIANA'),
  ('TEXAS'),
  ('THALIA'),
  ('TIM'),
  ('TOMY'),
  ('TRIZZA'),
  ('TURQUIA'),
  ('UMA'),
  ('VALENTINA'),
  ('VALERY'),
  ('VANESSA'),
  ('VARONY'),
  ('VICTORIA'),
  ('XIMENA'),
  ('XIOMY'),
  ('YORELI'),
  ('YULI'),
  ('ZAFIRO'),
  ('ZAIRA'),
  ('ZANSA'),
  ('ZOE'),
  ('ZULMA')
on conflict (codigo) do nothing;

-- 3. CARGAR CLIENTES (14: TODOS + 13 especiales)
insert into clientes (nombre) values
  ('BERNARDO'),
  ('BOOTS MICHEL'),
  ('BOSSI'),
  ('BRAYAN OLAYA'),
  ('FIDENCY'),
  ('JAVIER MOLINA'),
  ('JORGE BELTRAN'),
  ('LANDROVER'),
  ('PINTUGEMA'),
  ('SANTORINI'),
  ('TODOS'),
  ('VALERY ROSSY'),
  ('WILLIAM CACERES'),
  ('WILMER TABARES')
on conflict (nombre) do nothing;

-- 4. CARGAR TALLAS (24 rangos)
insert into tallas (rango, talla_min, talla_max) values
  ('18-26', 18, 26),
  ('19-26', 19, 26),
  ('19-30', 19, 30),
  ('21-26', 21, 26),
  ('23-26', 23, 26),
  ('26-33', 26, 33),
  ('27-32', 27, 32),
  ('27-33', 27, 33),
  ('27-34', 27, 34),
  ('33-36', 33, 36),
  ('33-40', 33, 40),
  ('34-34', 34, 34),
  ('34-36', 34, 36),
  ('34-38', 34, 38),
  ('34-39', 34, 39),
  ('34-40', 34, 40),
  ('34-41', 34, 41),
  ('35-39', 35, 39),
  ('35-40', 35, 40),
  ('37-40', 37, 40),
  ('37-42', 37, 42),
  ('37-43', 37, 43),
  ('37-44', 37, 44),
  ('41-42', 41, 42)
on conflict (rango) do nothing;

-- 5. CARGAR COLORES (12 específicos + categoría)
insert into colores (nombre, categoria) values
  ('CAFÉ', 'COLORES'),
  ('CAFÉ CRISTAL', 'COLORES'),
  ('COLORES', 'COLORES'),
  ('CORCHO', 'COLORES'),
  ('CREPE KEILA', 'COLORES'),
  ('CREPES', 'COLORES'),
  ('CRISTAL', 'COLORES'),
  ('MATRIX', 'COLORES'),
  ('MELON-CREPES', 'COLORES'),
  ('NEGRO', 'NEGRO'),
  ('PANELA-VAINILLA', 'COLORES'),
  ('VERDE ACUARELA', 'COLORES')
on conflict (nombre) do nothing;

-- 6. CARGAR PRECIOS (438 combinaciones)

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8700, 7310.9243697479,
  10000, 8403.361344537816,
  'LUCIANA SIN VIRA -SIN APLIQUE', 'LUCIANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  10800, 9075.63025210084,
  12400, 10420.16806722689,
  'EIMI BICOLOR COLORES', 'EIMY-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EIMY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  'MELONCREPES',
  11400, 9579.83193277311,
  13200, 11092.436974789916,
  'EIMY TR BICOLOR (MELON-CREPES)', 'EIMY-T.R.-TODOS-COLORES-Si-No-No-No-No-MELONCREPES-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EIMY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'MELON-CREPES'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'MATRIX',
  27700, 23277.310924369747,
  27700, 23277.310924369747,
  'GRETA (VALERY ROSSY) MATRIX', 'GRETA-T.R.-VALERY ROSSY-COLORES-No-No-No-No-No-MATRIX-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GRETA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'MATRIX'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'VERDEACUA',
  29800, 25042.01680672269,
  29800, 25042.01680672269,
  'GRETA (VALERY ROSSY) VERDE ACUARELA', 'GRETA-T.R.-VALERY ROSSY-COLORES-No-No-No-No-No-VERDEACUA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GRETA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'VERDE ACUARELA'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CREPE',
  32700, 27478.991596638658,
  32700, 27478.991596638658,
  'GRETA (VALERY ROSSY) CREPE KEILA', 'GRETA-T.R.-VALERY ROSSY-COLORES-No-No-No-No-No-CREPE-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GRETA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'CREPE KEILA'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8000, 6722.689075630253,
  9200, 7731.09243697479,
  'JORDAN PVC. Negro 27-33', 'JORDAN-PVC-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10300, 8655.46218487395,
  11600, 9747.899159663866,
  'JORDAN PVC. Negro 34-40', 'JORDAN-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-38]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-38'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8200, 6890.756302521008,
  9400, 7899.1596638655465,
  'JORDAN PVC. Sin VIRA 27-33', 'JORDAN-PVC-TODOS-COLORES-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  10600, 8907.563025210084,
  'JORDAN PVC. Sin VIRA 34-40', 'JORDAN-PVC-TODOS-COLORES-No-No-No-No-No-na-[34-38]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '34-38'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  '',
  9700, 8151.260504201681,
  11200, 9411.764705882353,
  'LUCIANA APLIQUE', 'LUCIANA-T.R.-TODOS-NEGRO-No-No-No-No-Si-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15300, 12857.142857142857,
  17700, 14873.949579831933,
  'MARIA', 'MARIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9900, 8319.327731092437,
  11600, 9747.899159663866,
  'MARIANA SIN Aplique', 'MARIANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CRISTAL',
  13200, 11092.436974789916,
  15100, 12689.075630252102,
  'MARTINELLI PVC CRISTAL 34-40', 'MARTINELI-PVC-TODOS-COLORES-No-No-No-No-No-CRISTAL-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINELI'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CAFE',
  10300, 8655.46218487395,
  11900, 10000,
  'MARTINELLI PVC CAFE 34-40', 'MARTINELI-PVC-TODOS-COLORES-No-No-No-No-No-CAFE-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINELI'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'CAFÉ'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17100, 14369.747899159665,
  19100, 16050.420168067227,
  'ANALIA', 'ANALIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14600, 12268.90756302521,
  15900, 13361.344537815126,
  'ADRIA GOMAFLEX', 'ADRIA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADRIA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13500, 11344.53781512605,
  15500, 13025.210084033613,
  'ADRIA A', 'ADRIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADRIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11800, 9915.966386554623,
  12900, 10840.336134453783,
  'ADRIA B', 'ADRIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADRIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  17200, 14453.781512605043,
  20300, 17058.823529411766,
  'ALHELI CUÑO', 'ALHELI-T.R.-TODOS-NEGRO-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALHELI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  15300, 12857.142857142857,
  17500, 14705.882352941177,
  'ALHELI CUÑO/EXPANSO', 'ALHELI-EXPANSO-TODOS-NEGRO-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALHELI'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  11700, 9831.932773109243,
  13600, 11428.57142857143,
  'BOSTON Vira mezcauchos', 'BOSTON-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7800, 6554.621848739496,
  8500, 7142.857142857143,
  'BOSTON EXPANSO', 'BOSTON-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12900, 10840.336134453783,
  15000, 12605.042016806723,
  'BRENDA', 'BRENDA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRENDA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8300, 6974.789915966387,
  9800, 8235.29411764706,
  'BRITANY TR MONOCOLOR', 'BRITANY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRITANY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7700, 6470.588235294118,
  7700, 6470.588235294118,
  'BRITANY EXPANSO', 'BRITANY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRITANY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  12100, 10168.067226890757,
  'ELSA', 'ELSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ELSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9700, 8151.260504201681,
  11200, 9411.764705882353,
  'GISELL', 'GISELL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GISELL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12400, 10420.16806722689,
  14200, 11932.773109243699,
  'ISABEL TR sin vira', 'ISABEL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISABEL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9900, 8319.327731092437,
  11600, 9747.899159663866,
  'JEIMI', 'JEIMI-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JEIMI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10700, 8991.596638655463,
  'LEIN sin aplique', 'LEIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LEIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11800, 9915.966386554623,
  13700, 11512.605042016807,
  'MAGUI', 'MAGUI-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MAGUI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  10700, 8991.596638655463,
  'NOELIA ', 'NOELIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NOELIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10400, 8739.495798319329,
  12100, 10168.067226890757,
  'SIMONA  TR SIN VIRA 34-40', 'SIMONA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9100, 7647.058823529412,
  10600, 8907.563025210084,
  'SIMONITA SIN VIRA 34-36', 'SIMONITA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-36]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONITA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-36'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6700, 5630.252100840336,
  7700, 6470.588235294118,
  'SIMONITA SIN VIRA 27-33', 'SIMONITA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONITA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  4500, 3781.512605042017,
  5000, 4201.680672268908,
  'SIMONITA SIN VIRA 23-26', 'SIMONITA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[23-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONITA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '23-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12200, 10252.100840336136,
  14100, 11848.73949579832,
  'TATIANA / SIN VIRA', 'TATIANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TATIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7700, 6470.588235294118,
  9000, 7563.025210084034,
  'ABRIL 3 Y 1/2', 'ABRIL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ABRIL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11600, 9747.899159663866,
  13400, 11260.504201680673,
  'ADA TR NEGRO MONOCOLOR', 'ADA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11600, 9747.899159663866,
  13400, 11260.504201680673,
  'ADEL sin vira', 'ADEL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ADEL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  13200, 11092.436974789916,
  'ALDANA sin vira ', 'ALDANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALDANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9500, 7983.193277310925,
  11100, 9327.731092436976,
  'ALDANA sin vira PVC', 'ALDANA-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALDANA'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8600, 7226.890756302521,
  9300, 7815.126050420168,
  'ALDANA EXPANSO', 'ALDANA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALDANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7300, 6134.453781512605,
  8500, 7142.857142857143,
  'ALEJANDRA', 'ALEJANDRA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALEJANDRA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9200, 7731.09243697479,
  10700, 8991.596638655463,
  'ALEN ', 'ALEN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALEN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11100, 9327.731092436976,
  13000, 10924.36974789916,
  'ALEX', 'ALEX-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALEX'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9100, 7647.058823529412,
  10600, 8907.563025210084,
  'ALMA A', 'ALMA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8100, 6806.72268907563,
  10900, 9159.66386554622,
  'ALMA B', 'ALMA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALMA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  10600, 8907.563025210084,
  'AMAYA FIDENCY', 'AMAYA-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-39]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AMAYA'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-39'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13900, 11680.672268907563,
  16000, 13445.378151260506,
  'AMBER TR', 'AMBER-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AMBER'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12100, 10168.067226890757,
  14100, 11848.73949579832,
  'AMBER EXPANSO', 'AMBER-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AMBER'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15600, 13109.243697478993,
  18000, 15126.050420168069,
  'ANABEL ', 'ANABEL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANABEL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10200, 8571.428571428572,
  11100, 9327.731092436976,
  'ANGELA ', 'ANGELA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10400, 8739.495798319329,
  'ANGELA /expanso', 'ANGELA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11900, 10000,
  12900, 10840.336134453783,
  'ANGELLO  GOMAFLEX', 'ANGELLO-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELLO'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11000, 9243.697478991597,
  12900, 10840.336134453783,
  'ANGELLO ', 'ANGELLO-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANGELLO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11800, 9915.966386554623,
  13500, 11344.53781512605,
  'ANALIA EXPANSO', 'ANALIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANALIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11000, 9243.697478991597,
  12900, 10840.336134453783,
  'ANTONELLA', 'ANTONELLA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANTONELLA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9900, 8319.327731092437,
  11600, 9747.899159663866,
  'ANTONIA sin vira', 'ANTONIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANTONIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7600, 6386.55462184874,
  8300, 6974.789915966387,
  'ANTONIA EXPANSO', 'ANTONIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANTONIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  'CUÑO',
  22400, 18823.529411764706,
  22400, 18823.529411764706,
  'ALHELI CUÑO/APLIQUE SANTORINI/FIDENCY', 'ALHELI-T.R.-FIDENCY-NEGRO-No-No-No-No-Si-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ALHELI'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12000, 10084.03361344538,
  12000, 10084.03361344538,
  'ARYA', 'ARYA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ARYA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10400, 8739.495798319329,
  'ARYA EXPANSO', 'ARYA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ARYA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11600, 9747.899159663866,
  13400, 11260.504201680673,
  'ASHA ', 'ASHA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ASHA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, true, false, false, false,
  '',
  13900, 11680.672268907563,
  16000, 13445.378151260506,
  'ASHER TR BICOLOR CON VIRA', 'ASHER-T.R.-TODOS-COLORES-Si-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ASHER'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  12600, 10588.235294117647,
  14600, 12268.90756302521,
  'ASHER TR BICOLOR SIN VIRA', 'ASHER-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ASHER'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7500, 6302.5210084033615,
  9700, 8151.260504201681,
  'AYAX SIN VIRA  PVC', 'AYAX-PVC-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AYAX'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10400, 8739.495798319329,
  11500, 9663.865546218487,
  'AYAX ', 'AYAX-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AYAX'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  9600, 8067.226890756303,
  'AYAX EXPANSO', 'AYAX-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'AYAX'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10300, 8655.46218487395,
  12100, 10168.067226890757,
  'BOSTON SIN Vira mezcauchos', 'BOSTON-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  13400, 11260.504201680673,
  15400, 12941.176470588236,
  'BOSTON VIRA fidenci', 'BOSTON-T.R.-FIDENCY-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BOSTON'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11700, 9831.932773109243,
  13300, 11176.470588235296,
  'BRISA EXPANSO', 'BRISA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRISA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13500, 11344.53781512605,
  14700, 12352.94117647059,
  'BRISA', 'BRISA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'BRISA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10100, 8487.394957983193,
  11800, 9915.966386554623,
  'CAMILA DOTACION MONOCOLOR', 'CAMILA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CAMILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7500, 6302.5210084033615,
  8800, 7394.957983193278,
  'CAMILA TR 34-40/FIDENCY', 'CAMILA-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CAMILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14100, 11848.73949579832,
  16300, 13697.47899159664,
  'CARMELA A', 'CARMELA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CARMELA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11300, 9495.798319327732,
  16600, 13949.579831932773,
  'CARMELA B', 'CARMELA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CARMELA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'CELIA A', 'CELIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CELIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8100, 6806.72268907563,
  9500, 7983.193277310925,
  'CELIA B', 'CELIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-41]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CELIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-41'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12400, 10420.16806722689,
  14300, 12016.806722689076,
  'CESAR', 'CESAR-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CESAR'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9700, 8151.260504201681,
  11100, 9327.731092436976,
  'CESAR SIN VIRA EXPANSO', 'CESAR-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CESAR'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10100, 8487.394957983193,
  11000, 9243.697478991597,
  'CLARK/EXPANSO', 'CLARK-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CLARK'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15100, 12689.075630252102,
  17500, 14705.882352941177,
  'CORINA TR MONOCOLOR', 'CORINA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CORINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15500, 13025.210084033613,
  17900, 15042.01680672269,
  'CORINA TR MONOCOLOR  FIDENCY', 'CORINA-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CORINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  16800, 14117.64705882353,
  19400, 16302.521008403362,
  'CORINA TR MONOCOLOR CON VIRA  FIDENCY', 'CORINA-T.R.-FIDENCY-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CORINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'ALTURA3.5',
  9000, 7563.025210084034,
  10300, 8655.46218487395,
  'DAFNE  3,5  -', 'DAFNE-T.R.-TODOS-NEGRO-No-No-No-No-No-ALTURA3.5-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAFNE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13500, 11344.53781512605,
  15900, 13361.344537815126,
  'DAKOTA/VALERY', 'DAKOTA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAKOTA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17200, 14453.781512605043,
  18700, 15714.285714285716,
  'DAKOTA GOMAFLEX', 'DAKOTA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAKOTA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11700, 9831.932773109243,
  12600, 10588.235294117647,
  'DAKOTA EXPANSO', 'DAKOTA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAKOTA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  24500, 20588.235294117647,
  24500, 20588.235294117647,
  'DAMARA(VALERY ROSSY)/MAS CUÑO/NEGRO', 'DAMARA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAMARA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  25200, 21176.470588235294,
  25200, 21176.470588235294,
  'DAMARA(VALERY ROSSY)/MAS CUÑO/MATRIX', 'DAMARA-T.R.-VALERY ROSSY-COLORES-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAMARA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'MATRIX'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  18200, 15294.117647058823,
  19700, 16554.621848739498,
  'DAMARA /MEZ PALSTIC', 'DAMARA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAMARA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  15100, 12689.075630252102,
  17200, 14453.781512605043,
  'DAMARA CUÑO EXPANSO( ECUADOR)', 'DAMARA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DAMARA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  9400, 7899.1596638655465,
  9400, 7899.1596638655465,
  'DALLAS /VIRA', 'DALLAS-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DALLAS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12700, 10672.268907563026,
  14500, 12184.873949579833,
  'DARSY EXPANSO', 'DARSY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-34]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DARSY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-34'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16600, 13949.579831932773,
  19100, 16050.420168067227,
  'DARSY', 'DARSY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DARSY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  13200, 11092.436974789916,
  'DIAMANTE A', 'DIAMANTE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DIAMANTE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10700, 8991.596638655463,
  12000, 10084.03361344538,
  'DIAMANTE B', 'DIAMANTE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DIAMANTE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12800, 10756.302521008403,
  14800, 12436.974789915967,
  'DIANA', 'DIANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10400, 8739.495798319329,
  'DIANA expanso', 'DIANA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DIANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  11000, 9243.697478991597,
  12600, 10588.235294117647,
  'DOROTEA CON VIRA', 'DOROTEA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DOROTEA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9700, 8151.260504201681,
  11200, 9411.764705882353,
  'DOROTEA SIN VIRA', 'DOROTEA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DOROTEA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14000, 11764.705882352942,
  9800, 8235.29411764706,
  'DOROTY TR MONOCOLOR', 'DOROTY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DOROTY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'BINUMERO',
  26000, 21848.73949579832,
  26000, 21848.73949579832,
  'DOTACION DON CARLOS(DIELECTRIC) BINUMERO', 'DOTACION-TPU-TODOS-NEGRO-No-No-No-No-No-BINUMERO-[37-44]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DOTACION'
  and m.nombre = 'TPU'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-44'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7200, 6050.420168067227,
  7200, 6050.420168067227,
  'DEIMER /EXPANSO MONOCOLOR', 'DEIMER-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DEIMER'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6300, 5294.117647058823,
  6300, 5294.117647058823,
  'DEIMER /PVC MONOCOLOR', 'DEIMER-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DEIMER'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  7800, 6554.621848739496,
  7800, 6554.621848739496,
  'DEIMER /PVC BICOLOR', 'DEIMER-PVC-TODOS-COLORES-Si-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DEIMER'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12800, 10756.302521008403,
  14800, 12436.974789915967,
  'DEIMER  MONOCOLOR', 'DEIMER-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DEIMER'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, true, false, false,
  '',
  20000, 16806.722689075632,
  20000, 16806.722689075632,
  'DR-NEGRO ( DIANA RAMIREZ -BOSSI)-VIRA-ESTERILLA Y VIRADO', 'DR-T.R.-BOSSI-NEGRO-No-Si-Si-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DR'
  and m.nombre = 'T.R.'
  and c.nombre = 'BOSSI'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, true, false, false,
  '',
  21000, 17647.058823529413,
  21000, 17647.058823529413,
  'DR-CAFE ( DIANA RAMIREZ -BOSSI)-VIRA-ESTERILLA Y VIRADO', 'DR-T.R.-BOSSI-COLORES-No-Si-Si-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'DR'
  and m.nombre = 'T.R.'
  and c.nombre = 'BOSSI'
  and co.nombre = 'CAFÉ'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7900, 6638.6554621848745,
  13300, 11176.470588235296,
  'EMYSOFIA (WILMER TABARES)', 'EMYSOFIA-T.R.-WILMER TABARES-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EMYSOFIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'WILMER TABARES'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8100, 6806.72268907563,
  9300, 7815.126050420168,
  'ELENA EXPANSO A', 'ELENA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ELENA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10300, 8655.46218487395,
  12900, 10840.336134453783,
  'ELENA EXPANSO B', 'ELENA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ELENA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13800, 11596.638655462186,
  16000, 13445.378151260506,
  'ELENA TR', 'ELENA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ELENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10000, 8403.361344537816,
  11700, 9831.932773109243,
  'ELENA TR niña', 'ELENA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ELENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'EMILIA TR ', 'EMILIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EMILIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  10000, 8403.361344537816,
  11600, 9747.899159663866,
  'EMILIA TR VIRA', 'EMILIA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EMILIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11500, 9663.865546218487,
  13300, 11176.470588235296,
  'ERIKA', 'ERIKA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ERIKA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10300, 8655.46218487395,
  11900, 10000,
  'ESMERALDA ', 'ESMERALDA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ESMERALDA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  'BRILLANTE',
  9300, 7815.126050420168,
  9300, 7815.126050420168,
  'ESTRELLA NEGRO/BRILLANTE/APLIQUE  SANTORINI', 'ESTRELLA-T.R.-SANTORINI-NEGRO-No-No-No-No-Si-BRILLANTE-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ESTRELLA'
  and m.nombre = 'T.R.'
  and c.nombre = 'SANTORINI'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  '',
  9800, 8235.29411764706,
  9800, 8235.29411764706,
  'ESTRELLA CAFÉ CRISTAL//APLIQUE  SANTORINI', 'ESTRELLA-T.R.-SANTORINI-COLORES-No-No-No-No-Si-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ESTRELLA'
  and m.nombre = 'T.R.'
  and c.nombre = 'SANTORINI'
  and co.nombre = 'CAFÉ CRISTAL'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'EVELIN TR SIN VIRA', 'EVELIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EVELIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  13300, 11176.470588235296,
  15300, 12857.142857142857,
  'FENIX BICOLOR', 'FENIX-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FENIX'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  12400, 10420.16806722689,
  14300, 12016.806722689076,
  'FENIX BICOLOR panela/vainilla', 'FENIX-EXPANSO-TODOS-COLORES-Si-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FENIX'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'PANELA-VAINILLA'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PLA10',
  13600, 11428.57142857143,
  13600, 11428.57142857143,
  'FLAVIA / pla 10', 'FLAVIA-T.R.-TODOS-NEGRO-No-No-No-No-No-PLA10-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FLAVIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  24900, 20924.36974789916,
  24900, 20924.36974789916,
  'FRANCIA( VALERY ROSSY) NEGRO', 'FRANCIA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FRANCIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  18200, 15294.117647058823,
  19700, 16554.621848739498,
  'FRANCIA NEGRO MEZPLASTIC', 'FRANCIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FRANCIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12700, 10672.268907563026,
  13800, 11596.638655462186,
  'FRANCIA EXPANSO', 'FRANCIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FRANCIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13300, 11176.470588235296,
  15300, 12857.142857142857,
  'FRANCO TR SIN VIRA 37-43', 'FRANCO-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FRANCO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11100, 9327.731092436976,
  13000, 10924.36974789916,
  'FRANCO SIN VIRA EXPANSO', 'FRANCO-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'FRANCO'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11700, 9831.932773109243,
  13300, 11176.470588235296,
  'GABY ', 'GABY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GABY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11200, 9411.764705882353,
  41600, 34957.983193277316,
  'GEMA NEGRO', 'GEMA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GEMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  10300, 8655.46218487395,
  'GEMA NEGRO PVC', 'GEMA-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GEMA'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  12900, 10840.336134453783,
  'GEMA EXP', 'GEMA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GEMA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11900, 10000,
  11900, 10000,
  'GEORGE ', 'GEORGE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GEORGE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  11200, 9411.764705882353,
  'GINA EXPANSO', 'GINA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GINA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  12900, 10840.336134453783,
  'GINA ', 'GINA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9500, 7983.193277310925,
  11100, 9327.731092436976,
  'GINA PVC MONOCOLOR', 'GINA-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GINA'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  27000, 22689.0756302521,
  27000, 22689.0756302521,
  'GRETA (VALERY ROSSY) NEGRO', 'GRETA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GRETA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13800, 11596.638655462186,
  14900, 12521.008403361346,
  'GRETA EXPANSO MEZ PLASTIC', 'GRETA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GRETA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9200, 7731.09243697479,
  9200, 7731.09243697479,
  'GEORGE', 'GEORGE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GEORGE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13000, 10924.36974789916,
  14200, 11932.773109243699,
  'GUADALUPE EXPANSO/ CLIENTES BOGOTA', 'GUADALUPE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GUADALUPE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14800, 12436.974789915967,
  16200, 13613.44537815126,
  'GUADALUPE GOMAFLEX/ EXCL PINTUGEMA BOGOTA', 'GUADALUPE-GOMAFLEX-PINTUGEMA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GUADALUPE'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'PINTUGEMA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12300, 10336.134453781513,
  14000, 11764.705882352942,
  'HELEN EXPANSO', 'HELEN-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'HELEN'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15300, 12857.142857142857,
  17700, 14873.949579831933,
  'HELEN', 'HELEN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'HELEN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  10300, 8655.46218487395,
  'HILARY', 'HILARY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'HILARY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9300, 7815.126050420168,
  10800, 9075.63025210084,
  'IRIS / SIN VIRA', 'IRIS-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'IRIS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7000, 5882.352941176471,
  8200, 6890.756302521008,
  'IRLANDA 35-39( FIDENCY)', 'IRLANDA-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[35-39]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'IRLANDA'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '35-39'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10000, 8403.361344537816,
  11700, 9831.932773109243,
  'IVANKA', 'IVANKA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'IVANKA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13500, 11344.53781512605,
  14600, 12268.90756302521,
  'ISSA', 'ISSA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14600, 12268.90756302521,
  15900, 13361.344537815126,
  'ISSA GOMAFLEX', 'ISSA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'BINUMERO',
  7000, 5882.352941176471,
  7600, 6386.55462184874,
  'ISSA EXPANSO /BINUMERO', 'ISSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-BINUMERO-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8600, 7226.890756302521,
  9600, 8067.226890756303,
  'ISSA EXPANSO A', 'ISSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11300, 9495.798319327732,
  12200, 10252.100840336136,
  'ISSA EXPANSO B', 'ISSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11500, 9663.865546218487,
  11500, 9663.865546218487,
  'ISSA EXPANSO/BOOTS MICHEL', 'ISSA-EXPANSO-BOOTS MICHEL-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'BOOTS MICHEL'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10700, 8991.596638655463,
  10700, 8991.596638655463,
  'ISSA EXPANSO /BRAYAN', 'ISSA-EXPANSO-BRAYAN OLAYA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'BRAYAN OLAYA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13800, 11596.638655462186,
  16200, 13613.44537815126,
  'IVY /VALERY', 'IVY-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'IVY'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12100, 10168.067226890757,
  13200, 11092.436974789916,
  'IVY', 'IVY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'IVY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8800, 7394.957983193278,
  9600, 8067.226890756303,
  'JORDAN/ GOMAFLEX', 'JORDAN-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  10000, 8403.361344537816,
  11000, 9243.697478991597,
  'JORDAN VIRA / GOMAFLEX', 'JORDAN-GOMAFLEX-TODOS-NEGRO-No-Si-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5800, 4873.949579831933,
  6000, 5042.01680672269,
  'JORDAN /EXPANSO', 'JORDAN-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[26-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '26-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8800, 7394.957983193278,
  10100, 8487.394957983193,
  'JORDAN  Monocolor 27-33', 'JORDAN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12000, 10084.03361344538,
  13800, 11596.638655462186,
  'JORDAN  Monocolor  34-40', 'JORDAN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  10900, 9159.66386554622,
  12500, 10504.20168067227,
  'JORDAN  Monocolor vira traslucido 27-33', 'JORDAN-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  14100, 11848.73949579832,
  16400, 13781.512605042017,
  'JORDAN  Monocolor vira traslucido 34-40', 'JORDAN-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  14700, 12352.94117647059,
  17000, 14285.714285714286,
  'JORDAN  Monocolor vira traslucido 41-42', 'JORDAN-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[41-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '41-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  10200, 8571.428571428572,
  11800, 9915.966386554623,
  'JORDAN PVC. CRISTAL VIRA 27-33', 'JORDAN-PVC-TODOS-COLORES-No-Si-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  15400, 12941.176470588236,
  17700, 14873.949579831933,
  'JORDAN PVC. CRISTAL VIRA 34-40', 'JORDAN-PVC-TODOS-COLORES-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JORDAN'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  10300, 8655.46218487395,
  'JULIETA TR MONOCOLO', 'JULIETA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JULIETA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  'DOBLE VIRA',
  12600, 10588.235294117647,
  14700, 12352.94117647059,
  'JULIO -  2-3 Version doble vira', 'JULIO-T.R.-TODOS-NEGRO-No-Si-No-No-No-DOBLE VIRA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JULIO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  11800, 9915.966386554623,
  13700, 11512.605042016807,
  'JULIO Hombre fidenci + VIRA', 'JULIO-T.R.-FIDENCY-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JULIO'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'KARINA SIN VIRA', 'KARINA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KARINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15300, 12857.142857142857,
  17700, 14873.949579831933,
  'KARLA', 'KARLA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[35-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KARLA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '35-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  17300, 14537.81512605042,
  19900, 16722.689075630253,
  'KARLOTA con vira fidenci', 'KARLOTA-T.R.-FIDENCY-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KARLOTA'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10400, 8739.495798319329,
  12100, 10168.067226890757,
  'KATERIN SIN VIRA', 'KATERIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KATERIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10400, 8739.495798319329,
  12100, 10168.067226890757,
  'KATTY', 'KATTY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KATTY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  13000, 10924.36974789916,
  'KATTY Fidency', 'KATTY-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KATTY'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10500, 8823.529411764706,
  12100, 10168.067226890757,
  'KEILA EXPANSO', 'KEILA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KEILA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15600, 13109.243697478993,
  18000, 15126.050420168069,
  'KEILA ', 'KEILA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KEILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16400, 13781.512605042017,
  17700, 14873.949579831933,
  'KEILA  GOMAFLEX', 'KEILA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KEILA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14300, 12016.806722689076,
  19300, 16218.487394957983,
  'KEILA /BRAYAN', 'KEILA-T.R.-BRAYAN OLAYA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KEILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'BRAYAN OLAYA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13600, 11428.57142857143,
  15500, 13025.210084033613,
  'KEITY ', 'KEITY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KEITY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10000, 8403.361344537816,
  11700, 9831.932773109243,
  'KENDAL', 'KENDAL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KENDAL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  12200, 10252.100840336136,
  'KLOE ', 'KLOE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KLOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  12300, 10336.134453781513,
  14200, 11932.773109243699,
  'LANCE BICOLOR SIN VIRA', 'LANCE-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LANCE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, true, false, false, false,
  '',
  13900, 11680.672268907563,
  16800, 14117.64705882353,
  'LANCE BICOLOR CON VIRA/ CON CREPES', 'LANCE-T.R.-TODOS-COLORES-Si-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LANCE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CREPES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12000, 10084.03361344538,
  13800, 11596.638655462186,
  'LANCE MONOCOLOR SIN VIRA', 'LANCE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LANCE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9700, 8151.260504201681,
  11100, 9327.731092436976,
  'LANCE MONOCOLOR SIN VIRA EXP', 'LANCE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LANCE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'LAURA', 'LAURA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LAURA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16500, 13865.546218487396,
  19100, 16050.420168067227,
  'LAURENT A', 'LAURENT-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LAURENT'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  19400, 16302.521008403362,
  'LAURENT B', 'LAURENT-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LAURENT'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14100, 11848.73949579832,
  16300, 13697.47899159664,
  'LEO', 'LEO-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LEO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10700, 8991.596638655463,
  12200, 10252.100840336136,
  'LEO EXPANSO', 'LEO-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LEO'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  7200, 6050.420168067227,
  8400, 7058.823529411765,
  'LINA VIRA A', 'LINA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[23-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '23-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6800, 5714.285714285715,
  7800, 6554.621848739496,
  'LINA', 'LINA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  8000, 6722.689075630253,
  9200, 7731.09243697479,
  'LINA VIRA B', 'LINA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  9700, 8151.260504201681,
  10600, 8907.563025210084,
  'LINA VIRA C', 'LINA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[33-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '33-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5700, 4789.915966386555,
  6500, 5462.18487394958,
  'LINA EXPANSO', 'LINA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LINA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11300, 9495.798319327732,
  13000, 10924.36974789916,
  'LINDA TR ', 'LINDA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LINDA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, true,
  '',
  13600, 11428.57142857143,
  15500, 13025.210084033613,
  'LIVES/VIRA APLIQUE', 'LIVES-T.R.-TODOS-NEGRO-No-Si-No-No-Si-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LIVES'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9700, 8151.260504201681,
  11100, 9327.731092436976,
  'LIVES EXPANSO', 'LIVES-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LIVES'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9300, 7815.126050420168,
  10800, 9075.63025210084,
  'LIVI / SIN VIRA', 'LIVI-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LIVI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8400, 7058.823529411765,
  9700, 8151.260504201681,
  'LIZET', 'LIZET-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LIZET'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8600, 7226.890756302521,
  9900, 8319.327731092437,
  'LARA', 'LARA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LARA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10900, 9159.66386554622,
  12500, 10504.20168067227,
  'LOLA', 'LOLA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LOLA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7800, 6554.621848739496,
  9100, 7647.058823529412,
  'LOLITA', 'LOLITA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LOLITA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11500, 9663.865546218487,
  13300, 11176.470588235296,
  'LONDON', 'LONDON-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LONDON'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8300, 6974.789915966387,
  9500, 7983.193277310925,
  'LORENA', 'LORENA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LORENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  4100, 3445.378151260504,
  4700, 3949.5798319327732,
  'LORY PVC', 'LORY-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LORY'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6000, 5042.01680672269,
  6900, 5798.319327731093,
  'LORY', 'LORY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LORY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7500, 6302.5210084033615,
  8900, 7478.991596638656,
  'LORY FIDENCY', 'LORY-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LORY'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  'INSERTO',
  17100, 14369.747899159665,
  18700, 15714.285714285716,
  'LUCAS / VIRA/INSERTO  GOMAFLEX', 'LUCAS-GOMAFLEX-TODOS-NEGRO-No-Si-No-No-No-INSERTO-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCAS'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13500, 11344.53781512605,
  15500, 13025.210084033613,
  'LUCAS ', 'LUCAS-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCAS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  'INSERTO',
  16600, 13949.579831932773,
  18900, 15882.352941176472,
  'LUCAS / VIRA/INSERTO ', 'LUCAS-T.R.-TODOS-NEGRO-No-Si-No-No-No-INSERTO-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCAS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'INSERTO',
  15500, 13025.210084033613,
  17800, 14957.983193277312,
  'LUCAS/ INSERTO', 'LUCAS-T.R.-TODOS-NEGRO-No-No-No-No-No-INSERTO-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCAS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11300, 9495.798319327732,
  12200, 10252.100840336136,
  'LUCAS /SIN VIRA', 'LUCAS-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCAS'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, true,
  '',
  10100, 8487.394957983193,
  11700, 9831.932773109243,
  'LUCIANA VIRA-APLIQUE', 'LUCIANA-T.R.-TODOS-NEGRO-No-Si-No-No-Si-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  4600, 3865.546218487395,
  5200, 4369.7478991596645,
  'LUISA A', 'LUISA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[18-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '18-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5800, 4873.949579831933,
  5200, 4369.7478991596645,
  'LUISA B', 'LUISA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PUNTUDA',
  6000, 5042.01680672269,
  6900, 5798.319327731093,
  'LUISA PUNTUDA A', 'LUISA-T.R.-TODOS-NEGRO-No-No-No-No-No-PUNTUDA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PUNTUDA',
  4100, 3445.378151260504,
  5200, 4369.7478991596645,
  'LUISA PUNTUDA B', 'LUISA-PVC-TODOS-NEGRO-No-No-No-No-No-PUNTUDA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  7200, 6050.420168067227,
  9100, 7647.058823529412,
  'LUISA BICOLOR CRISTAL 18-26', 'LUISA-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  8400, 7058.823529411765,
  10200, 8571.428571428572,
  'LUISA BICOLOR CRISTAL 27-32', 'LUISA-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7300, 6134.453781512605,
  8700, 7310.9243697479,
  'LUISA  MONOCOLOR CRISTAL A', 'LUISA-T.R.-TODOS-COLORES-No-No-No-No-No-na-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8500, 7142.857142857143,
  8500, 7142.857142857143,
  'LUISA  MONOCOLOR CRISTAL B', 'LUISA-T.R.-TODOS-COLORES-No-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUISA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10000, 8403.361344537816,
  11700, 9831.932773109243,
  'MADONA', 'MADONA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MADONA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, true, false, false,
  '',
  22900, 19243.6974789916,
  22900, 19243.6974789916,
  'MALAGA-VIRA-ESTERILLA ( javier molina)', 'MALAGA-T.R.-JAVIER MOLINA-NEGRO-No-Si-Si-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MALAGA'
  and m.nombre = 'T.R.'
  and c.nombre = 'JAVIER MOLINA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  12900, 10840.336134453783,
  14900, 12521.008403361346,
  'MALAGA-VIRA MEZCAUCHOS ', 'MALAGA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MALAGA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12900, 10840.336134453783,
  14800, 12436.974789915967,
  'MALU A', 'MALU-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MALU'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10200, 8571.428571428572,
  11700, 9831.932773109243,
  'MALU B', 'MALU-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MALU'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10000, 8403.361344537816,
  11600, 9747.899159663866,
  'MAITE PVC MONOCOLOR', 'MAITE-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MAITE'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12400, 10420.16806722689,
  14200, 11932.773109243699,
  'MAITE TR MONOCOLOR', 'MAITE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MAITE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11600, 9747.899159663866,
  13400, 11260.504201680673,
  'MANUELA', 'MANUELA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MANUELA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13600, 11428.57142857143,
  15400, 12941.176470588236,
  'MARIA expanso', 'MARIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16600, 13949.579831932773,
  17800, 14957.983193277312,
  'MARIA GOMAFLEX', 'MARIA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARIA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7800, 6554.621848739496,
  9100, 7647.058823529412,
  'MARCE A', 'MARCE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARCE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8800, 7394.957983193278,
  10100, 8487.394957983193,
  'MARCE B', 'MARCE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARCE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5300, 4453.781512605042,
  6100, 5126.050420168068,
  'MARCE EXPANSO A', 'MARCE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARCE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6600, 5546.218487394958,
  6100, 5126.050420168068,
  'MARCE EXPANSO B', 'MARCE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARCE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  8500, 7142.857142857143,
  9800, 8235.29411764706,
  'MARGARATH con vira PVC', 'MARGARATH-PVC-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARGARATH'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'MARGARATH TR con vira', 'MARGARATH-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARGARATH'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'MARGOTH TR ', 'MARGOTH-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARGOTH'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  '',
  10600, 8907.563025210084,
  12200, 10252.100840336136,
  'MARIANA Aplique', 'MARIA-T.R.-TODOS-NEGRO-No-No-No-No-Si-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11000, 9243.697478991597,
  12600, 10588.235294117647,
  'MARLENI TR /sin vira', 'MARLENY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARLENY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  12200, 10252.100840336136,
  'MARTHA TR / SIN VIRA', 'MARTHA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTHA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10200, 8571.428571428572,
  12000, 10084.03361344538,
  'MARTINA', 'MARTINA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9200, 7731.09243697479,
  10400, 8739.495798319329,
  'MARTINA EXPANSO', 'MARTINA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8400, 7058.823529411765,
  13700, 11512.605042016807,
  'MARTINELLI PVC NEGRO 34-40', 'MARTINELI-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINELI'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16000, 13445.378151260506,
  18400, 15462.18487394958,
  'MARTINELLI TR 34-40', 'MARTINELI-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINELI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12300, 10336.134453781513,
  13300, 11176.470588235296,
  'MARTINELLI EXPANSO', 'MARTINELI-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTINELI'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8600, 7226.890756302521,
  9800, 8235.29411764706,
  'MARY LUZ TR SIN VIRA', 'MARYLUZ-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARYLUZ'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  10300, 8655.46218487395,
  'MEGAN- fidency ?', 'MEGAN-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MEGAN'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9800, 8235.29411764706,
  11300, 9495.798319327732,
  'MELANIA', 'MELANIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MELANIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14900, 12521.008403361346,
  17200, 14453.781512605043,
  'MERIDA A', 'MERIDA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MERIDA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17500, 14705.882352941177,
  17500, 14705.882352941177,
  'MERIDA B', 'MERIDA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MERIDA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10400, 8739.495798319329,
  12100, 10168.067226890757,
  'MICHEL  ', 'MICHEL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MICHEL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PLANTISUELA Y TAPA',
  10100, 8487.394957983193,
  10100, 8487.394957983193,
  'MICHEL PLANTISUELA Y TAPA /TPU', 'MICHEL-TPU-TODOS-NEGRO-No-No-No-No-No-PLANTISUELA Y TAPA-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MICHEL'
  and m.nombre = 'TPU'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PLANTISUELA Y TAPA',
  8600, 7226.890756302521,
  8600, 7226.890756302521,
  'MICHEL PLANTISUELA Y TAPA ', 'MICHEL-T.R.-TODOS-NEGRO-No-No-No-No-No-PLANTISUELA Y TAPA-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MICHEL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'MIEL sin vira ', 'MIEL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MIEL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11000, 9243.697478991597,
  12500, 10504.20168067227,
  'MILE ', 'MILE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MILE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8900, 7478.991596638656,
  10200, 8571.428571428572,
  'MILE PVC', 'MILE-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MILE'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11500, 9663.865546218487,
  12500, 10504.20168067227,
  'MILLER CABALLERO/EXCLUSIVA', 'MILLER-T.R.-LANDROVER-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MILLER'
  and m.nombre = 'T.R.'
  and c.nombre = 'LANDROVER'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14400, 12100.840336134454,
  16600, 13949.579831932773,
  'MONACO A', 'MONACO-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MONACO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  16600, 13949.579831932773,
  'MONACO B', 'MONACO-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MONACO'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7800, 6554.621848739496,
  9000, 7563.025210084034,
  'MONIK TR SIN VIRA-SIN APLIQUE', 'MONIK-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MONIK'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  12200, 10252.100840336136,
  'MONSERRAT ', 'MONSERRAT-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MONSERRAT'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10900, 9159.66386554622,
  12500, 10504.20168067227,
  'NARDO ', 'NARDO-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NARDO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8500, 7142.857142857143,
  9800, 8235.29411764706,
  'NASTIA', 'NASTIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NASTIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7700, 6470.588235294118,
  9000, 7563.025210084034,
  'NATALY', 'NATALY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NATALY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10100, 8487.394957983193,
  11800, 9915.966386554623,
  'NATIS TR MONOCOLOR', 'NATIS-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NATIS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9700, 8151.260504201681,
  11200, 9411.764705882353,
  'NAYIVE SIN VIRA', 'NAYIVE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NAYIVE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11200, 9411.764705882353,
  12900, 10840.336134453783,
  'NIRVANA', 'NIRVANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NIRVANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8800, 7394.957983193278,
  10100, 8487.394957983193,
  'PALOMA / SIN VIRA 27-33', 'PALOMA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PALOMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10100, 8487.394957983193,
  11800, 9915.966386554623,
  'PALOMA / SIN VIRA 34-40', 'PALOMA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PALOMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6500, 5462.18487394958,
  6500, 5462.18487394958,
  'PALOMA EXPANSO A', 'PALOMA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PALOMA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7500, 6302.5210084033615,
  7500, 6302.5210084033615,
  'PALOMA EXPANSO B', 'PALOMA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PALOMA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9200, 7731.09243697479,
  10700, 8991.596638655463,
  'PAMELA SIN VIRA', 'PAMELA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PAMELA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17600, 14789.915966386556,
  19300, 16218.487394957983,
  'PAOLA GOMAFLEX', 'PAOLA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PAOLA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13900, 11680.672268907563,
  15800, 13277.310924369749,
  'PAOLA EXPANSO', 'PAOLA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PAOLA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8600, 7226.890756302521,
  9900, 8319.327731092437,
  'PARIS A', 'PARIS-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PARIS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7900, 6638.6554621848745,
  8800, 7394.957983193278,
  'PARIS B', 'PARIS-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PARIS'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  '',
  10200, 8571.428571428572,
  10200, 8571.428571428572,
  'PATRICIA MARCA SANTORINI/PAMU SAS', 'PATRICIA-T.R.-SANTORINI-NEGRO-No-No-No-No-Si-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PATRICIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'SANTORINI'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8400, 7058.823529411765,
  9700, 8151.260504201681,
  'PATRICIA ', 'PATRICIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PATRICIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  14600, 12268.90756302521,
  14600, 12268.90756302521,
  'PATRICK /VIRA', 'PATRICK-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PATRICK'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12900, 10840.336134453783,
  14900, 12521.008403361346,
  'PATRICK expanso ', 'PATRICK-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PATRICK'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  14000, 11764.705882352942,
  16100, 13529.411764705883,
  'PATRICK expanso /VIRA', 'PATRICK-EXPANSO-TODOS-NEGRO-No-Si-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PATRICK'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  9200, 7731.09243697479,
  10700, 8991.596638655463,
  'PAULA MEDIA VIRA', 'PAULA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PAULA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8200, 6890.756302521008,
  9800, 8235.29411764706,
  'PAULA ', 'PAULA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PAULA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7300, 6134.453781512605,
  8000, 6722.689075630253,
  'PAULA EXPANSO', 'PAULA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PAULA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10300, 8655.46218487395,
  11900, 10000,
  'PEGUI', 'PEGUI-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PEGUI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9400, 7899.1596638655465,
  10900, 9159.66386554622,
  'PENY TR / SIN VIRA', 'PENY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PENY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7200, 6050.420168067227,
  7600, 6386.55462184874,
  'PENY TR / SIN VIRA expanso', 'PENY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PENY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11300, 9495.798319327732,
  13000, 10924.36974789916,
  'PERLA', 'PERLA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PERLA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  8800, 7394.957983193278,
  10100, 8487.394957983193,
  'PIKO CON vira', 'PIKO-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PIKO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  3700, 3109.2436974789916,
  4400, 3697.478991596639,
  'PLANTISUELA JHOA', 'PLANTISUELAJOHA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PLANTISUELAJOHA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9500, 7983.193277310925,
  9200, 7731.09243697479,
  'PRINCE ', 'PRINCE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PRINCE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  25600, 21512.605042016807,
  25600, 21512.605042016807,
  'POLETH TR 34-40 ( PAMU SAS)', 'POLETH-T.R.-SANTORINI-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'POLETH'
  and m.nombre = 'T.R.'
  and c.nombre = 'SANTORINI'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15500, 13025.210084033613,
  16800, 14117.64705882353,
  'POLETH TR 34-40  MEZCAUCHOS', 'POLETH-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'POLETH'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16400, 13781.512605042017,
  19000, 15966.38655462185,
  'RAFAELA TR ', 'RAFAELA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RAFAELA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  13600, 11428.57142857143,
  15500, 13025.210084033613,
  'REY TR CON VIRA  33-36', 'REY-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[33-36]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'REY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '33-36'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13700, 11512.605042016807,
  15600, 13109.243697478993,
  'REY TR MONOCOLOR SIN VIRA', 'REY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'REY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12500, 10504.20168067227,
  13600, 11428.57142857143,
  'REY / SIN VIRA', 'REY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'REY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13700, 11512.605042016807,
  13700, 11512.605042016807,
  'robin', 'ROBIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  11400, 9579.83193277311,
  'RUBY PVC/SV', 'RUBY-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RUBY'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14500, 12184.873949579833,
  16700, 14033.613445378152,
  'RUBY', 'RUBY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RUBY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9800, 8235.29411764706,
  11300, 9495.798319327732,
  'ROBIN SIN  vira 27-33', 'ROBIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12300, 10336.134453781513,
  14200, 11932.773109243699,
  'ROBIN SIN  vira 34-40', 'ROBIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14700, 12352.94117647059,
  17000, 14285.714285714286,
  'ROBIN  SIN vira 41-42', 'ROBIN-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[41-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '41-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  14200, 11932.773109243699,
  16400, 13781.512605042017,
  'ROBIN CRISTAL con vira 34-40', 'ROBIN-T.R.-TODOS-COLORES-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  8100, 6806.72268907563,
  9400, 7899.1596638655465,
  'ROBIN con vira EXP 27- 33', 'ROBIN-EXPANSO-TODOS-NEGRO-No-Si-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  12500, 10504.20168067227,
  13200, 11092.436974789916,
  'ROBIN con vira EXP 34-40', 'ROBIN-EXPANSO-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  13200, 11092.436974789916,
  15300, 12857.142857142857,
  'ROBIN con vira EXP 41-42', 'ROBIN-EXPANSO-TODOS-NEGRO-No-Si-No-No-No-na-[41-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROBIN'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '41-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12700, 10672.268907563026,
  14500, 12184.873949579833,
  'ROSSY /PINTUGEMA EXPANSO', 'ROSSY-EXPANSO-PINTUGEMA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROSSY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'PINTUGEMA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  19700, 16554.621848739498,
  22700, 19075.63025210084,
  'ROSSY  MEZPLASTIC/PINTUGEMA', 'ROSSY-T.R.-PINTUGEMA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROSSY'
  and m.nombre = 'T.R.'
  and c.nombre = 'PINTUGEMA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  29800, 25042.01680672269,
  29300, 24621.8487394958,
  'ROSSY MATRIX (EXCLUSIVO COLOMBIA VALERY ROSSY)', 'ROSSY-T.R.-VALERY ROSSY-COLORES-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ROSSY'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'MATRIX'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  13200, 11092.436974789916,
  'SALMA /EXPANSO', 'SALMA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SALMA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13600, 11428.57142857143,
  15500, 13025.210084033613,
  'SALMA VALERY ROSSY', 'SALMA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SALMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14100, 11848.73949579832,
  16300, 13697.47899159664,
  'SALMA VALERY ROSSY-MATRIX', 'SALMA-T.R.-VALERY ROSSY-COLORES-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SALMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'MATRIX'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'SUELIN-MATE',
  13500, 11344.53781512605,
  13500, 11344.53781512605,
  'SANDALIA CORCHO  CON SUELIN/ MATE A', 'SANDALIA-T.R.-TODOS-COLORES-No-No-No-No-No-SUELIN-MATE-[19-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SANDALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CORCHO'
  and t.rango = '19-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'SUELIN-MATE',
  14500, 12184.873949579833,
  14500, 12184.873949579833,
  'SANDALIA CORCHO  CON SUELIN/ MATE B', 'SANDALIA-T.R.-TODOS-COLORES-No-No-No-No-No-SUELIN-MATE-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SANDALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CORCHO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'SUELIN-MATE',
  17100, 14369.747899159665,
  17100, 14369.747899159665,
  'SANDALIA CORCHO  CON SUELIN/ MATE C', 'SANDALIA-T.R.-TODOS-COLORES-No-No-No-No-No-SUELIN-MATE-[34-39]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SANDALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'CORCHO'
  and t.rango = '34-39'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'SUELIN-MATE',
  13700, 11512.605042016807,
  15800, 13277.310924369749,
  'SANDALIA COLORES TR  CON SUELIN/ MATE', 'SANDALIA-T.R.-TODOS-COLORES-No-No-No-No-No-SUELIN-MATE-[19-30]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SANDALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '19-30'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7500, 6302.5210084033615,
  8900, 7478.991596638656,
  'SARTA SIN VIRA', 'SARTA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SARTA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'ALTURA3.5',
  7800, 6554.621848739496,
  9100, 7647.058823529412,
  'SELENA 3.5  ', 'SELENA-T.R.-TODOS-NEGRO-No-No-No-No-No-ALTURA3.5-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SELENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17300, 14537.81512605042,
  19900, 16722.689075630253,
  'SIENA TR MEZ PLASTIC//PINTUGEMA', 'SIENA-T.R.-PINTUGEMA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'PINTUGEMA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16400, 13781.512605042017,
  18700, 15714.285714285716,
  'SIENA EXPANSO', 'SIENA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIENA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  3700, 3109.2436974789916,
  3700, 3109.2436974789916,
  'SEXIMODA/BERNADO', 'SEXIMODA-PVC-BERNARDO-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SEXIMODA'
  and m.nombre = 'PVC'
  and c.nombre = 'BERNARDO'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10100, 8487.394957983193,
  11800, 9915.966386554623,
  'SHIRLY sin vira', 'SHIRLY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SHIRLY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8000, 6722.689075630253,
  9200, 7731.09243697479,
  'SILVANA ', 'SILVANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SILVANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  12200, 10252.100840336136,
  'SILVIA', 'SILVIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SILVIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5200, 4369.7478991596645,
  6000, 5042.01680672269,
  'SIMONA EXPANSO A', 'SIMONA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6500, 5462.18487394958,
  6000, 5042.01680672269,
  'SIMONA EXPANSO B', 'SIMONA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7700, 6470.588235294118,
  9000, 7563.025210084034,
  'SIMONA SIN VIRA 27-33', 'SIMONA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SIMONA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10300, 8655.46218487395,
  11200, 9411.764705882353,
  'SOFI TR ( PINTUGEMA)', 'SOFI-T.R.-PINTUGEMA-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SOFI'
  and m.nombre = 'T.R.'
  and c.nombre = 'PINTUGEMA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10900, 9159.66386554622,
  13200, 11092.436974789916,
  'SOFI TR ( PINTUGEMA) COLORES', 'SOFI-T.R.-PINTUGEMA-COLORES-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SOFI'
  and m.nombre = 'T.R.'
  and c.nombre = 'PINTUGEMA'
  and co.nombre = 'COLORES'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7700, 6470.588235294118,
  9000, 7563.025210084034,
  'SOL ', 'SOL-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SOL'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9400, 7899.1596638655465,
  10900, 9159.66386554622,
  'SONY  SIN VIRA', 'SONY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SONY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9500, 7983.193277310925,
  11100, 9327.731092436976,
  'STEFANY sin vira', 'STEFANY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'STEFANY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13000, 10924.36974789916,
  15000, 12605.042016806723,
  'TANIA ', 'TANIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TANIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9100, 7647.058823529412,
  10600, 8907.563025210084,
  'TEXAS ', 'TEXAS-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TEXAS'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9900, 8319.327731092437,
  11600, 9747.899159663866,
  'THALIA SIN VIRA', 'THALIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'THALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  8400, 7058.823529411765,
  9700, 8151.260504201681,
  'TIM  bicolor 21-26', 'TIM-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TIM'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  9500, 7983.193277310925,
  11100, 9327.731092436976,
  'TIM  bicolor 27-32', 'TIM-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TIM'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  11700, 9831.932773109243,
  13600, 11428.57142857143,
  'TIM  bicolor 33-36', 'TIM-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[33-36]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TIM'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '33-36'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  13800, 11596.638655462186,
  15500, 13025.210084033613,
  'TIM  bicolor 37-42', 'TIM-T.R.-TODOS-COLORES-Si-No-No-No-No-na-[37-42]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TIM'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-42'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9100, 7647.058823529412,
  11100, 9327.731092436976,
  'TRIZZA', 'TRIZZA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TRIZZA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PLANA',
  7800, 6554.621848739496,
  9100, 7647.058823529412,
  'TOMY plana hombre', 'TOMY-T.R.-TODOS-NEGRO-No-No-No-No-No-PLANA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TOMY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  23200, 19495.798319327732,
  23200, 19495.798319327732,
  'UMA TR / VALERY ROSSY', 'UMA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'UMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11400, 9579.83193277311,
  11400, 9579.83193277311,
  'UMA PVC', 'UMA-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'UMA'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15600, 13109.243697478993,
  18000, 15126.050420168069,
  'UMA  TR/  MEZ PLASTIC', 'UMA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'UMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  18700, 15714.285714285716,
  20100, 16890.756302521007,
  'VALERY GOMAFLEX', 'VALERY-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VALERY'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  13300, 11176.470588235296,
  15400, 12941.176470588236,
  'VALERY  EXPANSO', 'VALERY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VALERY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5800, 4873.949579831933,
  6700, 5630.252100840336,
  'VANESSA A', 'VANESSA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VANESSA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8200, 6890.756302521008,
  8400, 7058.823529411765,
  'VANESSA B', 'VANESSA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-34]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VANESSA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-34'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9900, 8319.327731092437,
  11500, 9663.865546218487,
  'VANESSA C', 'VANESSA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VANESSA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'BINUMERO',
  4400, 3697.478991596639,
  4400, 3697.478991596639,
  'VANESA BINUMERO EXPANSO A', 'VANESSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-BINUMERO-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VANESSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'BINUMERO',
  5200, 4369.7478991596645,
  5200, 4369.7478991596645,
  'VANESA BINUMERO EXPANSO B', 'VANESSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-BINUMERO-[27-34]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VANESSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-34'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'BINUMERO',
  6500, 5462.18487394958,
  6500, 5462.18487394958,
  'VANESA BINUMERO EXPANSO C', 'VANESSA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-BINUMERO-[37-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VANESSA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  12600, 10588.235294117647,
  14600, 12268.90756302521,
  'VALENTINA/VIRA', 'VALENTINA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VALENTINA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14500, 12184.873949579833,
  16700, 14033.613445378152,
  'VALENTINA SIN VIRA EXP', 'VALENTINA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VALENTINA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, true, false, false, false,
  '',
  13800, 11596.638655462186,
  16000, 13445.378151260506,
  'VARONY vira-  Bicolor ', 'VARONY-T.R.-TODOS-COLORES-Si-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VARONY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, true, false, false, false,
  'MALVA',
  14300, 12016.806722689076,
  16500, 13865.546218487396,
  'VARONY vira-  Bicolor /MALVA', 'VARONY-T.R.-TODOS-COLORES-Si-Si-No-No-No-MALVA-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VARONY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  13300, 11176.470588235296,
  15300, 12857.142857142857,
  'VARONY vira-  MONOCOLOR', 'VARONY-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VARONY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12200, 10252.100840336136,
  12200, 10252.100840336136,
  'VARONY  MONOCOLOR/SIN VIRA', 'VARONY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VARONY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, true, false, false, false,
  '',
  17600, 14789.915966386556,
  20400, 17142.857142857145,
  'VARONY vira-  Bicolor  EXP', 'VARONY-EXPANSO-TODOS-COLORES-Si-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VARONY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'COLORES'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  12000, 10084.03361344538,
  13700, 11512.605042016807,
  'VARONY VIRA/MONO  EXPANSO', 'VARONY-EXPANSO-TODOS-NEGRO-No-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VARONY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  10300, 8655.46218487395,
  'VICTORIA / SIN VIRA ', 'VICTORIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'VICTORIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9400, 7899.1596638655465,
  11200, 9411.764705882353,
  'XIMENA', 'XIMENA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'XIMENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, true, false, false,
  '',
  10700, 8991.596638655463,
  12400, 10420.16806722689,
  'XIMENA/ ESTERILLA', 'XIMENA-T.R.-TODOS-NEGRO-No-No-Si-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'XIMENA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8400, 7058.823529411765,
  9100, 7647.058823529412,
  'XIMENA EXPANSO', 'XIMENA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'XIMENA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10600, 8907.563025210084,
  12100, 10168.067226890757,
  'XIOMY A', 'XIOMY-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'XIOMY'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9400, 7899.1596638655465,
  10900, 9159.66386554622,
  'XIOMY B', 'XIOMY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'XIOMY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14100, 11848.73949579832,
  16300, 13697.47899159664,
  'YORELI', 'YORELI-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'YORELI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11000, 9243.697478991597,
  11000, 9243.697478991597,
  'ZAIRA ', 'ZAIRA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZAIRA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8300, 6974.789915966387,
  9800, 8235.29411764706,
  'ZAFIRO /MEZCAUCHOS', 'ZAFIRO-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZAFIRO'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8400, 7058.823529411765,
  9700, 8151.260504201681,
  'ZAFIRO Fidency', 'ZAFIRO-T.R.-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZAFIRO'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10900, 9159.66386554622,
  12800, 10756.302521008403,
  'ZANSA  sin VIRA', 'ZANSA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZANSA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5200, 4369.7478991596645,
  5200, 4369.7478991596645,
  'ZOE EXPANSO A', 'ZOE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[23-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '23-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5900, 4957.983193277311,
  5900, 4957.983193277311,
  'ZOE EXPANSO B', 'ZOE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6500, 5462.18487394958,
  6500, 5462.18487394958,
  'ZOE EXPANSO C', 'ZOE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[33-36]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '33-36'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5900, 4957.983193277311,
  6600, 5546.218487394958,
  'ZOE  equitacion niña sin vira 23-26', 'ZOE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[23-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '23-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6300, 5294.117647058823,
  7200, 6050.420168067227,
  'ZOE  equitacion niña sin vira 27-32', 'ZOE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6800, 5714.285714285715,
  7700, 6470.588235294118,
  'ZOE  equitacion niña sin vira 33-36', 'ZOE-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[33-36]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '33-36'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  6900, 5798.319327731093,
  8000, 6722.689075630253,
  'ZOE  equitacion niña Vira 23-26', 'ZOE-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[23-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '23-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  7300, 6134.453781512605,
  8700, 7310.9243697479,
  'ZOE  equitacion niña Vira 27-32', 'ZOE-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[27-32]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-32'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  8000, 6722.689075630253,
  9200, 7731.09243697479,
  'ZOE  equitacion niña Vira 33-36', 'ZOE-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[33-36]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZOE'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '33-36'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11800, 9915.966386554623,
  13700, 11512.605042016807,
  'ZULMA', 'ZULMA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ZULMA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  18700, 15714.285714285716,
  20200, 16974.789915966387,
  'NAILA A', 'NAILA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NAILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14800, 12436.974789915967,
  16100, 13529.411764705883,
  'NAILA B', 'NAILA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NAILA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PLATILLAS',
  20300, 17058.823529411766,
  20300, 17058.823529411766,
  'NAILA CON PLANTILLAS/ BRAYAN', 'NAILA-T.R.-BRAYAN OLAYA-NEGRO-No-No-No-No-No-PLATILLAS-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NAILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'BRAYAN OLAYA'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'PLATILLAS',
  20800, 17478.991596638658,
  20800, 17478.991596638658,
  'NAILA CON PLANTILLAS/  BOOTS MICHEL', 'NAILA-T.R.-BOOTS MICHEL-NEGRO-No-No-No-No-No-PLATILLAS-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'NAILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'BOOTS MICHEL'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14100, 11848.73949579832,
  15200, 12773.10924369748,
  'LILA', 'LILA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LILA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15200, 12773.10924369748,
  16500, 13865.546218487396,
  'LILA GOMAFLEX', 'LILA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LILA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12100, 10168.067226890757,
  13100, 11008.403361344539,
  'LILA EXPANSO', 'LILA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LILA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14300, 12016.806722689076,
  15400, 12941.176470588236,
  'JULIANA', 'JULIANA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'JULIANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  15500, 13025.210084033613,
  16800, 14117.64705882353,
  'ANA CUÑO', 'ANA-T.R.-TODOS-NEGRO-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'NIÑA',
  6400, 5378.151260504202,
  6900, 5798.319327731093,
  'ANA  EXPANSO/NIÑA BINUMERO', 'ANA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-NIÑA-[21-26]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '21-26'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'NIÑA',
  8300, 6974.789915966387,
  9100, 7647.058823529412,
  'ANA  EXPANSO/NIÑA', 'ANA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-NIÑA-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'NIÑA',
  8500, 7142.857142857143,
  8500, 7142.857142857143,
  'ANA  EXPANSO/NIÑA WIILIAM CACERES', 'ANA-EXPANSO-WILLIAM CACERES-NEGRO-No-No-No-No-No-NIÑA-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'WILLIAM CACERES'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'NIÑA',
  10400, 8739.495798319329,
  11400, 9579.83193277311,
  'ANA  EXPANSO/NIÑA GOMAFLEX', 'ANA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-NIÑA-[27-33]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '27-33'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CUÑO',
  10600, 8907.563025210084,
  11500, 9663.865546218487,
  'ANA CUÑO EXPANSO', 'ANA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-CUÑO-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12300, 10336.134453781513,
  13300, 11176.470588235296,
  'ITALIA EXPANSO', 'ITALIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ITALIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CAJA',
  12300, 10336.134453781513,
  13300, 11176.470588235296,
  'ITALIA B- CON CAJA PARA COSTURA', 'ITALIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-CAJA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ITALIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CAJA',
  14500, 12184.873949579833,
  16700, 14033.613445378152,
  'ITALIA B CON CAJA/ PVC CRISTAL', 'ITALIA-PVC CRISTAL-TODOS-COLORES-No-No-No-No-No-CAJA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ITALIA'
  and m.nombre = 'PVC CRISTAL'
  and c.nombre = 'TODOS'
  and co.nombre = 'CRISTAL'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  6800, 5714.285714285715,
  7400, 6218.487394957983,
  'YULI BICOLOR', 'YULI-T.R.-TODOS-NEGRO-Si-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'YULI'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  5900, 4957.983193277311,
  5900, 4957.983193277311,
  'YULI MONOCOLOR NEGRO', 'YULI-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'YULI'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17600, 14789.915966386556,
  19100, 16050.420168067227,
  'GRETTA MEZ PLASTIC', 'GRETA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'GRETA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10400, 8739.495798319329,
  'KIRA SIN APLIQUE ', 'KIRA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'KIRA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  14400, 12100.840336134454,
  15500, 13025.210084033613,
  'CANADA EXCLUSIVO VALERY', 'CANADA-T.R.-VALERY ROSSY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CANADA'
  and m.nombre = 'T.R.'
  and c.nombre = 'VALERY ROSSY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15500, 13025.210084033613,
  16800, 14117.64705882353,
  'CANADA/GOMAFLEX', 'CANADA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CANADA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  10100, 8487.394957983193,
  10800, 9075.63025210084,
  'ANDRES JORGE BELTRAN + VIRA', 'ANDRES-T.R.-JORGE BELTRAN-NEGRO-No-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANDRES'
  and m.nombre = 'T.R.'
  and c.nombre = 'JORGE BELTRAN'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  11400, 9579.83193277311,
  12300, 10336.134453781513,
  'ANDRES COLOMBIA + VIRA', 'ANDRES-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[37-43]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ANDRES'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '37-43'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  true, false, false, false, false,
  '',
  12400, 10420.16806722689,
  13500, 11344.53781512605,
  'TURQUIA BICOLOR', 'TURQUIA-T.R.-TODOS-NEGRO-Si-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'TURQUIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8100, 6806.72268907563,
  8800, 7394.957983193278,
  'EVELIN EXPANSO', 'EVELIN-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EVELIN'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  16400, 13781.512605042017,
  17700, 14873.949579831933,
  'ITALIA TR', 'ITALIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ITALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  'CAJA',
  16400, 13781.512605042017,
  17700, 14873.949579831933,
  'ITALIA B-CON CAJA PARA COSTURA', 'ITALIA-T.R.-TODOS-NEGRO-No-No-No-No-No-CAJA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ITALIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17700, 14873.949579831933,
  19200, 16134.453781512606,
  'ITALIA  GOMAFLEX', 'ITALIA-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ITALIA'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  15900, 13361.344537815126,
  17200, 14453.781512605043,
  'SALOME', 'SALOME-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SALOME'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  17700, 14873.949579831933,
  19200, 16134.453781512606,
  'SALOME/GOMAFLEX', 'SALOME-GOMAFLEX-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SALOME'
  and m.nombre = 'GOMAFLEX'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  12500, 10504.20168067227,
  13600, 11428.57142857143,
  'SALOME EXPANSO', 'SALOME-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SALOME'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10000, 8403.361344537816,
  10900, 9159.66386554622,
  'PERLA EXPANSO', 'PERLA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PERLA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7300, 6134.453781512605,
  7900, 6638.6554621848745,
  'MONIK EXPANSO', 'MONIK-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MONIK'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7100, 5966.386554621849,
  7700, 6470.588235294118,
  'PATRICIA EXPANSO', 'PATRICIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'PATRICIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  10200, 8571.428571428572,
  11100, 9327.731092436976,
  'MILE EXPANSO', 'MILE-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MILE'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9400, 7899.1596638655465,
  10100, 8487.394957983193,
  'MARLENY EXPANSO', 'MARLENY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARLENY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7200, 6050.420168067227,
  7800, 6554.621848739496,
  'MARLENY PVC', 'MARLENY-PVC-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARLENY'
  and m.nombre = 'PVC'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  9700, 8151.260504201681,
  'MARTHA EXPANSO', 'MARTHA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'MARTHA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9000, 7563.025210084034,
  9700, 8151.260504201681,
  'LOLA EXPANSO', 'LOLA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LOLA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  6900, 5798.319327731093,
  8000, 6722.689075630253,
  'LUCIANA EXPANSO', 'LUCIANA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'LUCIANA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10800, 9075.63025210084,
  'RUMANIA', 'RUMANIA-T.R.-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RUMANIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, false, false, false,
  '',
  10700, 8991.596638655463,
  11900, 10000,
  'RUMANIA VIRA', 'RUMANIA-T.R.-TODOS-NEGRO-No-Si-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RUMANIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, true, true, false, false,
  'SALPA',
  11600, 9747.899159663866,
  13200, 11092.436974789916,
  'RUMANIA VIRA/ESTERILLA SALPA', 'RUMANIA-T.R.-TODOS-NEGRO-No-Si-Si-No-No-SALPA-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RUMANIA'
  and m.nombre = 'T.R.'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  9600, 8067.226890756303,
  10400, 8739.495798319329,
  'RUMANIA /EXPANSO', 'RUMANIA-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'RUMANIA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, true,
  '',
  11700, 9831.932773109243,
  12900, 10840.336134453783,
  'SHARON/ APLIQUE SANTORINI( FIDENCY)', 'SHARON-T.R.-FIDENCY-NEGRO-No-No-No-No-Si-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'SHARON'
  and m.nombre = 'T.R.'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  7500, 6302.5210084033615,
  8700, 7310.9243697479,
  'CAMILA/FIDENCY /EXPANSO', 'CAMILA-EXPANSO-FIDENCY-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'CAMILA'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'FIDENCY'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  8600, 7226.890756302521,
  9800, 8235.29411764706,
  'EIMY EXPANSO MONOCOLOR', 'EIMY-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'EIMY'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;

insert into precios_suelas (referencia_id, material_id, cliente_id, color_id, talla_id, bicolor, vira, esterilla, acabado, aplique, comentario, precio_distribuidor_con_iva, precio_distribuidor_sin_iva, precio_fabricante_con_iva, precio_fabricante_sin_iva, idluz, id_original)
select
  r.id, m.id, c.id, co.id, t.id,
  false, false, false, false, false,
  '',
  11500, 9663.865546218487,
  13300, 11176.470588235296,
  'ISABEL/EXPANSO', 'ISABEL-EXPANSO-TODOS-NEGRO-No-No-No-No-No-na-[34-40]'
from referencias r, materiales m, clientes c, colores co, tallas t
where r.codigo = 'ISABEL'
  and m.nombre = 'EXPANSO'
  and c.nombre = 'TODOS'
  and co.nombre = 'NEGRO'
  and t.rango = '34-40'
on conflict on constraint precios_suelas_variante_unica do update set
  precio_distribuidor_con_iva = excluded.precio_distribuidor_con_iva,
  precio_distribuidor_sin_iva = excluded.precio_distribuidor_sin_iva,
  precio_fabricante_con_iva = excluded.precio_fabricante_con_iva,
  precio_fabricante_sin_iva = excluded.precio_fabricante_sin_iva;
