import { supabase } from '../config/supabaseClient.js';
import { formatearFechaPedido } from '../lib/fechas.js';
import { mostrarToast } from './toast.js';
import { fetchOpcionesCliente, fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { construirMapaUltimaFechaPorProceso, calcularDiasPorProceso } from '../lib/procesoDias.js';
import { esValidador } from '../services/validatorService.js';
import { montarMultiSelect } from './multiSelect.js';
import { ESTADOS_CONTROL_CENTRAL, condicionEstados, cumpleEstados } from '../lib/estadosPedido.js';
import { calcularOpciones } from '../lib/facetas.js';
import { porcentajeReal } from '../lib/calculations.js';
import { getState } from '../state/appState.js';
import { fetchInyectadoPorPedidos, fetchEstadoSincronizacion } from '../services/inyeccionService.js';
import { aplicaInyeccion, estadoSincronizacion } from '../lib/inyeccion.js';
import { fetchEstadoPedidos } from '../services/despachosService.js';
import { fetchTroyaPorPedidos, fetchTiposCierreONulo, etiquetaTipoCierre } from '../services/cierreForzadoService.js';
import { fetchComentariosActivosPorPedidos, fetchResumenComentarios } from '../services/comentariosPedidoService.js';
import { abrirComentariosPedido } from './comentariosPedidoModal.js';
import { colorPorVencimiento, resaltarEtiquetasHtml, formatearVencimiento, ROLES_ETIQUETABLES, diasParaVencer } from '../lib/etiquetasRol.js';

// Estado de la sincronización del Total Inyectado (solo Validador). Se refresca
// con cada carga de la tabla y, mientras la pantalla esté abierta, cada minuto.
let estadoInyeccion = null;
let temporizadorInyeccion = null;
const MS_REFRESCO_ESTADO = 60 * 1000;

let paginaActual = 0;
const PAGE_SIZE = 50;
let hayPaginaSiguiente = false;
// cliente / nombreSuela / material / color admiten VARIAS opciones (listas).
const filtrosVacios = () => ({ orden: '', cliente: [], nombreSuela: [], material: [], color: [], fecha: '', vira: '', acabado: '', esterilla: '', marquilla: '' });
let filtros = filtrosVacios();

// Desplegables de selección múltiple (se montan al dibujar la pantalla).
const MULTI_FILTROS = {
  cliente: { id: 'validador-filtro-cliente', placeholder: 'Cliente...', plural: 'clientes', columna: 'cliente' },
  nombreSuela: { id: 'validador-filtro-nombre-suela', placeholder: 'Nombre Suela...', plural: 'nombres', columna: 'nombre_referencia' },
  material: { id: 'validador-filtro-material', placeholder: 'Material...', plural: 'materiales', columna: 'material' },
  color: { id: 'validador-filtro-color', placeholder: 'Color...', plural: 'colores', columna: 'color' }
};
const multis = {};

// Filtro por Estado (solo Validador): En proceso / Completado / Cerrado, varios a la vez.
let estadosFiltro = [];
// Map(pedido cerrado -> tipo|null) para "Cerrado · Clasificado / Sin clasificar"; null = no llegó.
let tiposCierre = null;

async function refrescarTiposCierre() {
  const tipos = await fetchTiposCierreONulo();
  if (tipos) tiposCierre = tipos;
}

// Filtro por Comentarios (093/094): varias opciones a la vez (se unen con O).
//   todos -> órdenes con algún comentario activo
//   con   -> órdenes con al menos un accionable SIN cerrar
//   sin   -> órdenes con comentarios que NUNCA tuvieron un accionable (ni abierto ni cerrado)
const OPCIONES_COMENTARIOS = [
  { valor: 'todos', etiqueta: 'Comentarios (todos)' },
  { valor: 'con', etiqueta: 'Con accionables' },
  { valor: 'sin', etiqueta: 'Sin accionables' }
];
let comentariosFiltro = [];

// Filtro "Etiquetado": órdenes con algún comentario activo que etiquete a alguno de los roles elegidos.
let etiquetadoFiltro = [];

// Filtro "Vence en": según el accionable PENDIENTE que vence antes (los mismos cortes del color del botón).
const OPCIONES_VENCE = [
  { valor: 'mas10', etiqueta: 'Más de 10 días' },
  { valor: 'entre', etiqueta: 'Entre 6 y 10 días' },
  { valor: 'menos5', etiqueta: '5 días o menos' }
];
let venceFiltro = [];

function hayFiltroComentarios() {
  return comentariosFiltro.length > 0 || etiquetadoFiltro.length > 0 || venceFiltro.length > 0;
}

function cubetaVence(fechaISO) {
  const dias = diasParaVencer(fechaISO);
  if (dias === null) return null;
  if (dias > 10) return 'mas10';
  if (dias > 5) return 'entre';
  return 'menos5'; // 5 días o menos, incluidos los ya vencidos
}
// Map(orden -> { abiertos }) de TODAS las órdenes con comentarios; null = aún no llega / falló.
let resumenComentarios = null;

function cumpleComentarios(numeroOrden) {
  if (!hayFiltroComentarios() || !resumenComentarios) return true; // sin filtro (o sin datos todavía)
  const r = resumenComentarios.get(String(numeroOrden));
  if (!r) return false; // sin comentarios: no entra en ninguna de las 3 opciones
  // Entre filtros se cumplen todos (Y); dentro de cada uno basta con una opción (O).
  return (comentariosFiltro.length === 0 || comentariosFiltro.some((v) =>
    v === 'todos' || (v === 'con' && r.abiertos > 0) || (v === 'sin' && r.accionables === 0)))
    && (etiquetadoFiltro.length === 0 || etiquetadoFiltro.some((rol) => r.roles.has(rol)))
    && (venceFiltro.length === 0 || (r.minVence != null && venceFiltro.includes(cubetaVence(r.minVence))));
}

async function refrescarResumenComentarios() {
  const resumen = await fetchResumenComentarios();
  if (resumen) resumenComentarios = resumen;
}

// Atributos Sí/No por pedido (alguna línea = Sí), ver SQL 082.
const ATRIBUTOS_SI_NO = ['vira', 'acabado', 'esterilla', 'marquilla'];

/** Rol real Empaque (no el emulado por el Validador, que ya tiene todo). */
function esEmpaque() {
  return getState().user?.role === 'empaque';
}

const ESTILO_INPUT = 'padding:8px 12px;border:1.5px solid var(--border2);border-radius:var(--r);font-size:13px;';

export async function cargarValidadorPage() {
  const contenedor = document.getElementById('page-validador');
  if (!contenedor) return;

  contenedor.innerHTML = `
    <div class="card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
        <h2>🔍 Control Central — Estado Completo de Órdenes</h2>
        <button id="btn-refrescar-validador" class="btn btn-secondary btn-sm">🔄 Refrescar</button>
      </div>

      <div id="validador-filtros" style="display:grid;grid-template-columns:150px 1.2fr 1.2fr 1fr 1fr;gap:0.75rem;margin-bottom:1rem;">
        <input type="text" id="validador-filtro-orden" placeholder="No. Orden" maxlength="4" style="${ESTILO_INPUT}">
        <div id="validador-filtro-cliente" class="filtro-estado-celda"></div>
        <div id="validador-filtro-nombre-suela" class="filtro-estado-celda"></div>
        <div id="validador-filtro-material" class="filtro-estado-celda"></div>
        <div id="validador-filtro-color" class="filtro-estado-celda"></div>
        <input type="date" id="validador-filtro-fecha" style="${ESTILO_INPUT}">
        <div id="validador-filtro-estado" class="filtro-estado-celda"></div>
        <div id="validador-filtro-comentarios" class="filtro-estado-celda"></div>
        <div id="validador-filtro-etiquetado" class="filtro-estado-celda"></div>
        <div id="validador-filtro-vence" class="filtro-estado-celda"></div>
        ${['Vira', 'Acabado', 'Esterilla', 'Marquilla'].map((nombre) => `
        <label class="filtro-toggle" data-filtro-toggle="validador-filtro-${nombre.toLowerCase()}" title="Mostrar solo pedidos con ${nombre.toLowerCase()}">
          <span class="filtro-toggle-lbl">${nombre}</span>
          <span class="propuesta-switch">
            <input type="checkbox" id="validador-filtro-${nombre.toLowerCase()}">
            <span class="propuesta-switch-slider"></span>
          </span>
        </label>`).join('')}
      </div>

      <div id="validador-resumen"></div>

      ${esValidador()
        ? '<div id="validador-nota-inyeccion" style="font-size:11px; color:var(--text3); margin:-0.25rem 0 0.5rem;">I% = Inyección (ERP): pares inyectados | % de lo solicitado. Verificando actualización…</div>'
        : esEmpaque()
          ? '<div style="font-size:11px; color:var(--text3); margin:-0.25rem 0 0.5rem;">I% = Inyección (ERP): pares inyectados | % de lo solicitado.</div>'
          : ''}

      <div style="overflow-x: auto;">
        <div id="validador-tabla"></div>
      </div>

      <div style="margin-top: 1rem; display: flex; gap: 0.5rem; justify-content: center;">
        <button id="validador-pag-prev" class="btn btn-secondary btn-sm">← Anterior</button>
        <span id="validador-pag-info" style="display: flex; align-items: center;">Página 1</span>
        <button id="validador-pag-next" class="btn btn-secondary btn-sm">Siguiente →</button>
      </div>
    </div>
  `;

  // El HTML se reconstruye con todo vacío: el estado también.
  filtros = filtrosVacios();
  estadosFiltro = [];
  comentariosFiltro = [];
  etiquetadoFiltro = [];
  venceFiltro = [];

  // Cada cambio de filtro: la tabla se vuelve a pedir al servidor y las
  // opciones de los desplegables y las tarjetas se recalculan al instante
  // con los datos ya descargados (sin consultar).
  const alCambiarFiltros = () => {
    paginaActual = 0;
    actualizarOpcionesFiltros();
    pintarResumenActual();
    cargarValidador();
  };

  const celdaEstado = document.getElementById('validador-filtro-estado');
  if (celdaEstado) {
    montarMultiSelect(celdaEstado, {
      placeholder: 'Estado...',
      opciones: ESTADOS_CONTROL_CENTRAL,
      alCambiar: (valores) => {
        estadosFiltro = valores;
        alCambiarFiltros();
      }
    });
  }

  const celdaComentarios = document.getElementById('validador-filtro-comentarios');
  if (celdaComentarios) {
    montarMultiSelect(celdaComentarios, {
      placeholder: 'Comentarios...',
      etiquetaPlural: 'opciones',
      opciones: OPCIONES_COMENTARIOS,
      alCambiar: (valores) => {
        comentariosFiltro = valores;
        alCambiarFiltros();
      }
    });
  }

  const celdaEtiquetado = document.getElementById('validador-filtro-etiquetado');
  if (celdaEtiquetado) {
    montarMultiSelect(celdaEtiquetado, {
      placeholder: 'Etiquetado...',
      etiquetaPlural: 'roles',
      opciones: ROLES_ETIQUETABLES.map((r) => ({ valor: r.rol, etiqueta: `@${r.etiqueta}` })),
      alCambiar: (valores) => {
        etiquetadoFiltro = valores;
        alCambiarFiltros();
      }
    });
  }

  const celdaVence = document.getElementById('validador-filtro-vence');
  if (celdaVence) {
    montarMultiSelect(celdaVence, {
      placeholder: 'Vence en...',
      etiquetaPlural: 'opciones',
      opciones: OPCIONES_VENCE,
      alCambiar: (valores) => {
        venceFiltro = valores;
        alCambiarFiltros();
      }
    });
  }

  Object.entries(MULTI_FILTROS).forEach(([clave, cfg]) => {
    const celda = document.getElementById(cfg.id);
    if (!celda) return;
    multis[clave] = montarMultiSelect(celda, {
      placeholder: cfg.placeholder,
      etiquetaPlural: cfg.plural,
      buscable: true,
      opciones: [],
      alCambiar: (valores) => {
        filtros[clave] = valores;
        alCambiarFiltros();
      }
    });
  });

  document.getElementById('btn-refrescar-validador')?.addEventListener('click', () => {
    cargarBase({ silencioso: true });
    cargarValidador();
  });

  const FILTRO_ID_A_CLAVE = {
    'validador-filtro-orden': 'orden',
    'validador-filtro-fecha': 'fecha',
    'validador-filtro-vira': 'vira',
    'validador-filtro-acabado': 'acabado',
    'validador-filtro-esterilla': 'esterilla',
    'validador-filtro-marquilla': 'marquilla'
  };

  let debounceTimer = null;
  Object.keys(FILTRO_ID_A_CLAVE).forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;

    if (el.type === 'checkbox') {
      // Interruptor: encendido = solo pedidos con ese atributo; apagado = sin filtro.
      el.addEventListener('change', () => {
        filtros[FILTRO_ID_A_CLAVE[id]] = el.checked ? 'Si' : '';
        alCambiarFiltros();
      });
    } else if (el.type === 'date') {
      el.addEventListener('change', () => {
        filtros[FILTRO_ID_A_CLAVE[id]] = el.value.trim();
        alCambiarFiltros();
      });
    } else {
      el.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          filtros[FILTRO_ID_A_CLAVE[id]] = el.value.trim();
          alCambiarFiltros();
        }, 350);
      });
    }
  });

  document.getElementById('validador-pag-prev')?.addEventListener('click', () => {
    if (paginaActual > 0) {
      paginaActual--;
      cargarValidador();
    }
  });
  document.getElementById('validador-pag-next')?.addEventListener('click', () => {
    if (hayPaginaSiguiente) {
      paginaActual++;
      cargarValidador();
    }
  });

  poblarFiltrosDropdown();
  iniciarTemporizadorInyeccion();
  pintarResumen(null); // "…" hasta que llegue la base
  cargarBase();
  await cargarValidador();
}

/**
 * Pinta el rótulo de Inyección según el estado de la sincronización: al día
 * ("Actualizado hace 3 min"), en falla (pausada, detenida o sin actualizar
 * hace más de 15 min) o "no se pudo verificar". No hace nada si la nota no
 * está en pantalla (cualquier usuario que no sea Validador).
 */
function pintarNotaInyeccion() {
  const nota = document.getElementById('validador-nota-inyeccion');
  if (!nota) return false;

  const info = estadoSincronizacion(estadoInyeccion);
  const base = 'I% = Inyección (ERP): pares inyectados | % de lo solicitado.';

  if (info.nivel === 'ok') {
    nota.style.cssText = 'font-size:11px; color:var(--text3); margin:-0.25rem 0 0.5rem;';
    nota.innerHTML = `${base} <strong style="color:var(--green-text);">${escapeHtml(info.texto)}</strong>`;
  } else {
    const alerta = info.nivel === 'alerta';
    nota.style.cssText = [
      'font-size:12px', 'margin:0 0 0.75rem', 'padding:6px 10px', 'border-radius:var(--r)',
      `background:var(--${alerta ? 'red' : 'amber'}-bg)`,
      `color:var(--${alerta ? 'red' : 'amber'}-text)`
    ].join('; ') + ';';
    nota.innerHTML = `${alerta ? '⚠ ' : ''}${base} <strong>${escapeHtml(info.texto)}</strong>`;
  }
  return true;
}

async function actualizarEstadoInyeccion() {
  if (!esValidador()) return;
  estadoInyeccion = await fetchEstadoSincronizacion();
  pintarNotaInyeccion();
}

/**
 * Mantiene el "hace X min" al día mientras la pantalla siga abierta (sin
 * esto diría "hace 3 min" para siempre). Consulta una sola fila, solo si la
 * pestaña se está viendo, y se apaga sola cuando la nota deja de existir.
 */
function iniciarTemporizadorInyeccion() {
  if (temporizadorInyeccion) {
    clearInterval(temporizadorInyeccion);
    temporizadorInyeccion = null;
  }
  if (!esValidador()) return;

  temporizadorInyeccion = setInterval(async () => {
    const nota = document.getElementById('validador-nota-inyeccion');
    if (!nota) {
      clearInterval(temporizadorInyeccion);
      temporizadorInyeccion = null;
      return;
    }
    if (nota.offsetParent === null) return; // pestaña oculta: no se consulta
    await actualizarEstadoInyeccion();
  }, MS_REFRESCO_ESTADO);
}

/**
 * Mismos dropdowns (valores DISTINCT en vivo desde la BD) que usa el
 * listado normal de Órdenes — ver poblarFiltrosDropdown() en dashboard.js.
 */
async function poblarFiltrosDropdown() {
  const aOpciones = (valores) => valores.map((v) => ({ valor: v, etiqueta: v }));
  try {
    const [clientes, nombresSuela, materiales, colores] = await Promise.all([
      fetchOpcionesCliente(),
      fetchOpcionesNombreSuela(),
      fetchOpcionesMaterial(),
      fetchOpcionesColor()
    ]);
    // Si la base ya llegó, sus opciones en cascada mandan (no se pisan).
    if (baseCC) return;
    multis.cliente?.actualizarOpciones(aOpciones(clientes));
    multis.nombreSuela?.actualizarOpciones(aOpciones(nombresSuela));
    multis.material?.actualizarOpciones(aOpciones(materiales));
    multis.color?.actualizarOpciones(aOpciones(colores));
  } catch (err) {
    console.error('[validadorPage] Error cargando opciones de filtros:', err);
  }
}

/**
 * Refresco liviano (solo los datos, sin reconstruir los inputs de
 * filtro) — usado por realtime cuando la pestaña Control Central ya
 * está inicializada. cargarValidadorPage() reconstruye todo el HTML,
 * lo que borraría lo que el usuario esté escribiendo en los filtros.
 */
export async function refrescarValidadorSiVisible() {
  if (!document.getElementById('validador-tabla')) return;
  // Realtime puede disparar muchas veces seguidas: los datos de las tarjetas y
  // de las opciones se vuelven a bajar una sola vez por ráfaga (tras 1,5 s).
  clearTimeout(temporizadorBase);
  temporizadorBase = setTimeout(() => cargarBase({ silencioso: true }), 1500);
  await cargarValidador();
}

/**
 * Consulta de pedidos de la tabla con TODOS los filtros activos aplicados.
 */
function consultaPedidosFiltrados(columnas) {
  // Con algún interruptor encendido se lee vw_pedido_progreso_atributos (082).
  const atributos = ATRIBUTOS_SI_NO.filter((a) => filtros[a] === 'Si');
  let query = supabase
    .from(atributos.length > 0 ? 'vw_pedido_progreso_atributos' : 'vw_pedido_progreso')
    .select(columnas)
    .order('order_number', { ascending: false });
  atributos.forEach((a) => {
    query = query.eq(a, true);
  });
  const condEstados = condicionEstados(estadosFiltro, tiposCierre);
  if (condEstados) query = query.or(condEstados);
  if (hayFiltroComentarios() && resumenComentarios) {
    const ordenes = [...resumenComentarios.keys()].filter(cumpleComentarios);
    query = query.in('order_number', ordenes.length > 0 ? ordenes : ['__sin_comentarios__']);
  }

  if (filtros.orden.trim()) {
    query = query.ilike('order_number', `%${filtros.orden.trim()}%`);
  }
  // Selección múltiple: uno o varios valores exactos.
  Object.entries(MULTI_FILTROS).forEach(([clave, cfg]) => {
    if (filtros[clave].length > 0) query = query.in(cfg.columna, filtros[clave]);
  });
  if (filtros.fecha) {
    query = query.eq('fecha_pedido', filtros.fecha);
  }
  return query;
}

async function cargarValidador() {
  // Con el filtro de Comentarios activo, la lista de órdenes sale del resumen: se refresca antes.
  if (hayFiltroComentarios()) await refrescarResumenComentarios();
  // Tipos de cierre: para el filtro Estado y el detalle del badge "Cerrada".
  await refrescarTiposCierre();
  const query = consultaPedidosFiltrados('*');

  const { data, error } = await query.range(
    paginaActual * PAGE_SIZE,
    paginaActual * PAGE_SIZE + PAGE_SIZE
  );

  if (error) {
    console.error('[validadorPage] Error:', error);
    mostrarToast('Error cargando órdenes', 'error');
    return;
  }

  hayPaginaSiguiente = data?.length > PAGE_SIZE;
  const ordenes = (data || []).slice(0, PAGE_SIZE);

  // Movimientos SOLO de las órdenes visibles en esta página, necesarios
  // para calcular D_Refilado/Acabado/Mateado/Empaque (misma lógica que
  // el Excel, ver src/lib/procesoDias.js).
  const numerosOrden = ordenes.map((o) => o.order_number);
  let mapaUltimaFecha = {};
  if (numerosOrden.length > 0) {
    const { data: movimientos, error: errorMov } = await supabase
      .from('production_movements')
      .select('order_number, from_process, created_at, observation')
      .in('order_number', numerosOrden);

    if (errorMov) {
      console.error('[validadorPage] Error obteniendo movimientos para días:', errorMov);
    } else {
      mapaUltimaFecha = construirMapaUltimaFechaPorProceso(movimientos || []);
    }
  }

  // Inyección (ERP): dato informativo de Access, solo para el Validador.
  // undefined = la columna no se muestra; null = la consulta falló ("—").
  // Empaque ve la misma columna; el estado de la sincronización (rótulo
  // "Actualizado hace X min") sigue siendo solo del Validador (RLS).
  let inyeccion;
  if (esValidador()) {
    [inyeccion] = await Promise.all([fetchInyectadoPorPedidos(numerosOrden), actualizarEstadoInyeccion()]);
  } else if (esEmpaque()) {
    inyeccion = await fetchInyectadoPorPedidos(numerosOrden);
  }

  // Unidades despachadas por pedido (Despachos + Troya). null = la consulta
  // falló ("—"); no debe tumbar el resto de la tabla.
  const despachadas = await despachadasPorPedidos(numerosOrden);

  // Comentarios activos por orden (093). null = la consulta falló: los botones
  // se ven apagados pero siguen abriendo el historial.
  comentariosPorOrden = await fetchComentariosActivosPorPedidos(numerosOrden);

  renderTablaValidador(ordenes, mapaUltimaFecha, inyeccion, despachadas);
  renderPaginacionValidador();
}

// ---------------------------------------------------------------------
// Datos base en memoria: alimentan las tarjetas y las opciones en cascada
// ---------------------------------------------------------------------
//
// Se descargan UNA vez al entrar (y al pulsar Refrescar o cuando realtime avisa
// de cambios): una fila por pedido con solo las columnas necesarias. Después,
// filtrar no consulta nada: se filtra aquí mismo y las tarjetas y las listas
// responden al instante. La tabla sí se sigue pidiendo al servidor (paginada).

const LOTE_PEDIDOS = 150; // números de pedido por consulta (evita URLs enormes)
const LOTE_FILAS = 1000; // tope de filas por consulta de Supabase
const COLUMNAS_BASE = 'order_number, cliente, nombre_referencia, material, color, fecha_pedido, estatus_general, cierre_forzado, vira, acabado, esterilla, marquilla, total_solicitado, procesado_refilado, procesado_acabado, procesado_mateado, procesado_empaque';
const CARGANDO = 'cargando';

let baseCC = null; // pedidos; null = aún no llega
let extraCC = null; // { inyectado, despachadas } por pedido; null = aún no llega
let versionBase = 0;
let temporizadorBase = null;

// Mismas columnas y modos que usa Activas/Completadas para sus listas en cascada.
const CAMPOS_FACETAS = {
  orden: { columna: 'order_number', modo: 'contiene' },
  cliente: { columna: 'cliente', modo: 'exacto', lista: true },
  nombreSuela: { columna: 'nombre_referencia', modo: 'exacto', lista: true },
  material: { columna: 'material', modo: 'exacto', lista: true },
  color: { columna: 'color', modo: 'exacto', lista: true },
  fecha: { columna: 'fecha_pedido', modo: 'exacto' }
};

/** Parte la lista en lotes y los consulta todos a la vez. */
async function porLotes(lista, fn) {
  const lotes = [];
  for (let i = 0; i < lista.length; i += LOTE_PEDIDOS) {
    lotes.push(lista.slice(i, i + LOTE_PEDIDOS));
  }
  return Promise.all(lotes.map(fn));
}

/**
 * Unidades despachadas por pedido = Despachos + lo despachado en Troya (089).
 * Map(pedido -> { despachadas, troya }), o null si la consulta falló.
 */
async function despachadasPorPedidos(numeros) {
  const lista = [...new Set(numeros.map(String))];
  const mapa = new Map();
  try {
    const lotes = await porLotes(lista, (lote) =>
      Promise.all([fetchEstadoPedidos(lote), fetchTroyaPorPedidos(lote)]));
    lotes.forEach(([estado, troya]) => {
      estado.forEach((v, k) => mapa.set(k, { despachadas: v.despachadas ?? 0, troya: 0 }));
      troya.forEach((pares, k) => {
        const previo = mapa.get(k) || { despachadas: 0, troya: 0 };
        mapa.set(k, { despachadas: previo.despachadas + pares, troya: pares });
      });
    });
    return mapa;
  } catch (err) {
    console.error('[validadorPage] Error obteniendo unidades despachadas:', err);
    return null;
  }
}

/** Inyectado por pedido de TODOS los pedidos dados (por lotes). null si falla. */
async function inyectadoPorPedidos(numeros) {
  const lotes = await porLotes(numeros, (lote) => fetchInyectadoPorPedidos(lote));
  if (lotes.some((m) => m === null)) return null;
  const mapa = new Map();
  lotes.forEach((m) => m.forEach((v, k) => mapa.set(k, v)));
  return mapa;
}

/** Todos los pedidos (solo las columnas de la base), sin filtros. */
async function leerBaseDatos() {
  const leer = async (desde) => {
    const { data, error } = await supabase
      .from('vw_pedido_progreso_atributos')
      .select(COLUMNAS_BASE)
      .order('order_number', { ascending: false })
      .range(desde, desde + LOTE_FILAS - 1);
    if (error) throw error;
    return data || [];
  };
  const filas = await leer(0);
  // Lo normal es que quepa en una consulta; si no, se piden varias páginas a la vez
  // (el orden por order_number es único: no se repiten ni se pierden filas).
  if (filas.length < LOTE_FILAS) return filas;
  const resto = [];
  for (let desde = LOTE_FILAS; desde < LOTE_FILAS * 8; desde += LOTE_FILAS) resto.push(leer(desde));
  const paginas = await Promise.all(resto);
  paginas.forEach((pg) => filas.push(...pg));
  if (paginas[paginas.length - 1].length === LOTE_FILAS) {
    // Más de 8.000 pedidos: se sigue de forma secuencial.
    for (let desde = LOTE_FILAS * 8; ; desde += LOTE_FILAS) {
      const pg = await leer(desde);
      filas.push(...pg);
      if (pg.length < LOTE_FILAS) break;
    }
  }
  return filas;
}

/**
 * Descarga la base y los datos de Inyección/Despachos y repinta tarjetas y
 * listas. silencioso=true (Refrescar, realtime): conserva lo que ya se ve hasta
 * que llegue lo nuevo, sin volver a mostrar "…".
 */
async function cargarBase({ silencioso = false } = {}) {
  if (!document.getElementById('validador-resumen')) return;
  const version = ++versionBase;
  if (!silencioso) {
    baseCC = null;
    extraCC = null;
    pintarResumen(null);
  }
  try {
    const [filas, resumen] = await Promise.all([leerBaseDatos(), fetchResumenComentarios(), refrescarTiposCierre()]);
    if (version !== versionBase) return; // llegó una carga más nueva
    if (resumen) resumenComentarios = resumen;
    baseCC = filas.map((f) => ({ ...f, fecha_pedido: f.fecha_pedido ? String(f.fecha_pedido).slice(0, 10) : '' }));
    actualizarOpcionesFiltros();
    pintarResumenActual();

    const numeros = baseCC.map((p) => String(p.order_number));
    const verInyeccion = esValidador() || esEmpaque();
    const [inyectado, despachadas] = await Promise.all([
      verInyeccion ? inyectadoPorPedidos(numeros) : Promise.resolve(undefined),
      despachadasPorPedidos(numeros)
    ]);
    if (version !== versionBase) return;
    extraCC = { inyectado, despachadas };
    pintarResumenActual();
  } catch (err) {
    if (version !== versionBase) return;
    console.error('[validadorPage] Error cargando los datos de las tarjetas:', err);
    if (!baseCC) pintarResumen(undefined);
  }
}

/** Interruptores Sí/No y Estado (lo que no entra en las listas en cascada). */
function cumpleAtributosYEstado(fila) {
  return ATRIBUTOS_SI_NO.every((a) => filtros[a] !== 'Si' || fila[a] === true)
    && cumpleEstados(fila, estadosFiltro, tiposCierre)
    && cumpleComentarios(fila.order_number);
}

/** Pedidos que cumplen TODOS los filtros actuales. */
function pedidosFiltrados() {
  const orden = filtros.orden.trim().toLowerCase();
  return baseCC.filter((f) =>
    cumpleAtributosYEstado(f)
    && (!orden || String(f.order_number).toLowerCase().includes(orden))
    && (!filtros.fecha || f.fecha_pedido === filtros.fecha)
    && Object.entries(MULTI_FILTROS).every(([clave, cfg]) =>
      filtros[clave].length === 0 || filtros[clave].includes(String(f[cfg.columna] ?? ''))));
}

/**
 * Listas en cascada: cada desplegable muestra solo lo que existe en los pedidos
 * que cumplen los DEMÁS filtros (nunca el suyo), igual que Activas/Completadas.
 * Aquí además cuentan los interruptores y el Estado.
 */
function actualizarOpcionesFiltros() {
  if (!baseCC) return;
  const candidatos = baseCC.filter(cumpleAtributosYEstado);
  const opciones = calcularOpciones(candidatos, filtros, CAMPOS_FACETAS);
  Object.keys(MULTI_FILTROS).forEach((clave) => {
    multis[clave]?.actualizarOpciones((opciones[clave] || []).map((v) => ({ valor: v, etiqueta: v })));
  });
}

/** Suma las tarjetas sobre los pedidos filtrados (sin consultar nada). */
function pintarResumenActual() {
  if (!document.getElementById('validador-resumen')) return;
  if (!baseCC) {
    pintarResumen(null);
    return;
  }
  const pedidos = pedidosFiltrados();
  const suma = (campo) => pedidos.reduce((t, p) => t + (Number(p[campo]) || 0), 0);
  const solicitado = suma('total_solicitado');
  const verInyeccion = esValidador() || esEmpaque();

  // Inyección y despachos llegan un poco después de la base: mientras tanto "…".
  let inyectado = verInyeccion ? CARGANDO : undefined;
  let despachado = CARGANDO;
  let pctI = CARGANDO;
  let pctD = CARGANDO;

  if (extraCC) {
    const { inyectado: iny, despachadas } = extraCC;
    if (verInyeccion) {
      if (iny) {
        let sumaIny = 0;
        let solicitadoIny = 0;
        pedidos.forEach((p) => {
          if (!aplicaInyeccion(p.order_number)) return;
          solicitadoIny += Number(p.total_solicitado) || 0;
          sumaIny += iny.get(String(p.order_number)) ?? 0;
        });
        inyectado = sumaIny;
        pctI = porcentajeReal(sumaIny, solicitadoIny);
      } else {
        inyectado = null; // falló
        pctI = null;
      }
    }
    if (despachadas) {
      despachado = pedidos.reduce((t, p) => t + (despachadas.get(String(p.order_number))?.despachadas ?? 0), 0);
      pctD = porcentajeReal(despachado, solicitado);
    } else {
      despachado = null; // falló
      pctD = null;
    }
  }

  pintarResumen({
    solicitado,
    inyectado,
    refilado: suma('procesado_refilado'),
    acabado: suma('procesado_acabado'),
    mateado: suma('procesado_mateado'),
    empacado: suma('procesado_empaque'),
    despachado,
    pctI,
    pctD
  });
}

/**
 * Pinta las tarjetas. datos: objeto = listo; null = calculando ("…");
 * undefined = falló ("—").
 */
function pintarResumen(datos) {
  const cont = document.getElementById('validador-resumen');
  if (!cont) return;

  const fmt = (v) => {
    if (datos === null || v === CARGANDO) return '…';
    if (datos === undefined || v === null || v === undefined) return '—';
    return Number(v).toLocaleString('es-CO');
  };
  const fmtPct = (v) => {
    if (datos === null || v === CARGANDO) return '…';
    if (datos === undefined || v === null || v === undefined) return '—';
    return `${v}%`;
  };
  // Mismos colores que los badges de la tabla.
  const AZUL = ['var(--blue)', '#fff', '1px solid var(--blue)']; // azul principal de la plataforma
  const GRIS = ['var(--bg)', 'var(--text2)', '1px dashed var(--border2)'];
  const GRIS_PCT = ['var(--border)', 'var(--text)', '1px solid var(--border2)'];
  // Inyección solo la ven Validador y Empaque (igual que la columna I%).
  const verInyeccion = esValidador() || esEmpaque();
  const tarjetas = [
    ['Solicitado', fmt(datos?.solicitado), AZUL, 'Pares solicitados de todos los pedidos filtrados'],
    ...(verInyeccion ? [['Inyectado', fmt(datos?.inyectado), GRIS, 'Pares inyectados (ERP), pedidos desde el 3095']] : []),
    ['Refilado', fmt(datos?.refilado), ['var(--blue-bg)', 'var(--blue)', '1px solid transparent'], 'Pares que ya salieron de Refilado'],
    ['Acabado', fmt(datos?.acabado), ['var(--green-bg)', 'var(--green-text)', '1px solid transparent'], 'Pares que ya salieron de Acabado'],
    ['Mateado', fmt(datos?.mateado), ['var(--purple-bg)', 'var(--purple-text)', '1px solid transparent'], 'Pares que ya salieron de Mateado'],
    ['Empacado', fmt(datos?.empacado), ['var(--amber-bg)', 'var(--amber-text)', '1px solid transparent'], 'Pares que ya salieron de Empaque'],
    ['Despachado', fmt(datos?.despachado), AZUL, 'Pares despachados (Despachos + Troya)'],
    ...(verInyeccion ? [['%I', fmtPct(datos?.pctI), GRIS_PCT, '% Inyectado = Inyectado / Solicitado (solo pedidos desde el 3095)']] : []),
    ['%D', fmtPct(datos?.pctD), GRIS_PCT, '% Despachado = Despachado / Solicitado']
  ];

  cont.style.cssText = 'display:grid;grid-template-columns:repeat(auto-fit,minmax(105px,1fr));gap:0.5rem;margin:0 0 0.75rem;';
  cont.innerHTML = tarjetas.map(([titulo, valor, [bg, color, borde], ayuda]) => `
    <div title="${escapeHtml(ayuda)}" style="background:${bg};color:${color};border:${borde};border-radius:var(--r);padding:8px 10px;text-align:center;">
      <div style="font-size:11px;font-weight:600;opacity:0.85;">${titulo}</div>
      <div style="font-size:18px;font-weight:700;line-height:1.3;">${valor}</div>
    </div>`).join('');
}

/**
 * Mismo código de color que usa cada proceso en el resto de la app
 * (Refilado=azul, Acabado=verde, Mateado=morado, Empaque=ámbar), para
 * que la etapa se lea de un vistazo sin tener que leer la letra.
 */
function badgeEtapa(etapa) {
  const estilos = {
    R: { bg: 'var(--blue-bg)', color: 'var(--blue)' },
    A: { bg: 'var(--green-bg)', color: 'var(--green-text)' },
    M: { bg: 'var(--purple-bg)', color: 'var(--purple-text)' },
    E: { bg: 'var(--amber-bg)', color: 'var(--amber-text)' },
    Fin: { bg: 'var(--green-bg)', color: 'var(--green-text)' }
  };
  const s = estilos[etapa] || { bg: 'var(--bg)', color: 'var(--text2)' };
  return `<span style="background:${s.bg}; color:${s.color}; padding:3px 10px; border-radius:4px; font-weight:600;">${etapa || '—'}</span>`;
}

/**
 * Badge de Estado. Un pedido cerrado a la fuerza por el Validador (057)
 * conserva su estatus_general real (p. ej. "En Proceso", porque no se
 * completó), así que se muestra "Cerrada" para que no parezca abierto.
 */
function badgeEstado(o) {
  if (o.cierre_forzado) {
    const quien = o.cierre_forzado_por || 'el Validador';
    const motivo = o.cierre_forzado_motivo ? `: ${o.cierre_forzado_motivo}` : '';
    const tipo = tiposCierre ? ` · Tipo: ${etiquetaTipoCierre(tiposCierre.get(String(o.order_number)))}` : '';
    return `<span class="estado-badge estado-cerrada" title="${escapeHtml(`Cerrada a la fuerza por ${quien}${motivo}${tipo}`)}">Cerrada</span>`;
  }
  return `<span class="estado-badge estado-${o.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">${o.estatus_general}</span>`;
}

/** Bocadillo de comentario: el mismo icono y estilos del botón de Despachos. */
const ICONO_COMENTARIO = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`;

// Comentarios activos por orden de la página visible (Map orden -> lista).
let comentariosPorOrden = new Map();

/**
 * Botón de comentarios de la orden (093): amarillo con la cantidad si tiene
 * comentarios activos, gris si no. Siempre se puede abrir (para agregar).
 */
function botonComentarioOrden(orden) {
  const lista = comentariosPorOrden?.get(String(orden.order_number)) ?? [];
  const n = lista.length;
  const num = escapeHtml(orden.order_number);
  if (n > 0) {
    const titulo = `${n} comentario${n === 1 ? '' : 's'}`;
    const color = colorPorVencimiento(lista); // verde / amarillo / rojo
    const claseColor = color === 'amarillo' ? '' : ` venc-${color}`;
    return `<button type="button" class="btn-comentario-registro con-comentario${claseColor}" data-comentarios-orden="${num}" title="${titulo}" aria-label="${titulo}">${ICONO_COMENTARIO}<span class="btn-comentario-badge" aria-hidden="true">${n}</span></button>`;
  }
  return `<button type="button" class="btn-comentario-registro sin-comentario" data-comentarios-orden="${num}" style="cursor:pointer;" title="Agregar comentario" aria-label="Agregar comentario">${ICONO_COMENTARIO}</button>`;
}

let tooltipComentarios = null;
let botonTooltip = null;

/** Cuadro de solo lectura (el mismo de Despachos) con todos los comentarios activos de la orden. */
function mostrarTooltipComentarios(boton) {
  cerrarTooltipComentarios();
  const lista = comentariosPorOrden?.get(boton.dataset.comentariosOrden) ?? [];
  if (lista.length === 0) return;

  const bloques = lista.map((c) => {
    const d = new Date(c.created_at);
    const fecha = `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`;
    return `
      <div class="regd-comentario-popover-titulo" style="text-transform:none; letter-spacing:0;">${escapeHtml(c.autor_nombre)} · ${fecha}${c.accionable ? (c.cerrado ? ' · Hecho' : ' · Pendiente') : ''}${c.accionable && !c.cerrado && c.fecha_vencimiento ? ` · vence ${formatearVencimiento(c.fecha_vencimiento)}` : ''}</div>
      <div class="regd-comentario-popover-texto">${resaltarEtiquetasHtml(escapeHtml(c.texto))}</div>`;
  });

  const pop = document.createElement('div');
  pop.className = 'regd-comentario-popover';
  pop.style.pointerEvents = 'none';
  pop.style.maxHeight = '60vh';
  pop.style.overflow = 'hidden';
  pop.innerHTML = bloques.join('');
  document.body.appendChild(pop);

  const rect = boton.getBoundingClientRect();
  const margen = 8;
  let left = rect.left + rect.width / 2 - pop.offsetWidth / 2;
  left = Math.max(margen, Math.min(left, window.innerWidth - pop.offsetWidth - margen));
  let top = rect.bottom + 6;
  if (top + pop.offsetHeight + margen > window.innerHeight && rect.top - pop.offsetHeight - 6 > margen) {
    top = rect.top - pop.offsetHeight - 6;
  }
  pop.style.left = `${Math.round(left)}px`;
  pop.style.top = `${Math.round(top)}px`;

  tooltipComentarios = pop;
  botonTooltip = boton;
}

function cerrarTooltipComentarios() {
  tooltipComentarios?.remove();
  tooltipComentarios = null;
  botonTooltip = null;
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[c]));
}

/**
 * Badge de avance de un proceso: "pares | %". Los pares son los que ya
 * salieron de ese proceso (procesado_*, el mismo numerador del %). El % de
 * la vista llega topado en 100 pero los pares no, así que si un proceso
 * registró de más se ve el número real (ej. "105 | 100%").
 */
function badgeAvance(pares, porcentaje, bg, color, estiloExtra = '') {
  return `<span style="background: ${bg}; color: ${color}; padding: 2px 6px; border-radius: 3px; white-space: nowrap; ${estiloExtra}">${pares || 0} | ${porcentaje || 0}%</span>`;
}

/**
 * Celda de Inyección (ERP). Neutra y con borde punteado para que no se
 * confunda con un proceso de la cadena. "—" si el pedido es anterior al
 * 3095 o si la consulta falló.
 */
function celdaInyeccion(orden, inyeccion) {
  if (inyeccion === null || !aplicaInyeccion(orden.order_number)) {
    return '<span style="color: var(--text3);">—</span>';
  }
  const pares = inyeccion.get(String(orden.order_number)) ?? 0;
  return badgeAvance(pares, porcentajeReal(pares, orden.total_solicitado), 'var(--bg)', 'var(--text2)', 'border: 1px dashed var(--border2);');
}

/** Solo se usa para fecha_pedido (fecha de calendario a medianoche UTC): ver lib/fechas.js. */
function formatearFecha(fecha) {
  return formatearFechaPedido(fecha);
}

/** Celda de días: números tal cual, 'No'/'NA' en gris tenue. */
function celdaDias(valor) {
  if (valor === 'No' || valor === 'NA') {
    return `<span style="color: var(--text3);">${valor}</span>`;
  }
  return `<strong>${valor}</strong>`;
}

/** Celda DESP.: unidades despachadas del pedido ("—" si la consulta falló). */
function celdaDespachadas(orden, despachadas) {
  if (despachadas === null) return '<span style="color: var(--text3);">—</span>';
  const d = despachadas.get(String(orden.order_number));
  const total = d?.despachadas ?? 0;
  if (d?.troya > 0) {
    return `<strong title="${total - d.troya} por Despachos + ${d.troya} despachados en Troya">${total}</strong>`;
  }
  return `<strong>${total}</strong>`;
}

function renderTablaValidador(ordenes, mapaUltimaFecha, inyeccion, despachadas) {
  const tabla = document.getElementById('validador-tabla');
  const verInyeccion = inyeccion !== undefined;

  if (ordenes.length === 0) {
    tabla.innerHTML = '<div class="empty">No hay órdenes para mostrar.</div>';
    return;
  }

  const html = `
    <table style="width: 100%; border-collapse: collapse; font-size: 12px;">
      <thead>
        <tr style="background: var(--bg); border-bottom: 2px solid var(--border);">
          <th style="padding: 8px; text-align: left;">Orden</th>
          <th style="padding: 8px; text-align: left;">Cliente</th>
          <th style="padding: 8px; text-align: left;">Nombre Suela</th>
          <th style="padding: 8px; text-align: left;">Material</th>
          <th style="padding: 8px; text-align: left;">Color</th>
          <th style="padding: 8px; text-align: left;">Fecha Pedido</th>
          <th style="padding: 8px; text-align: center;" title="Unidades (pares) totales del pedido">UNDS.</th>
          <th style="padding: 8px; text-align: center;" title="Unidades despachadas del pedido (suma de todas sus salidas en Despachos + lo despachado en Troya)">DESP.</th>
          ${verInyeccion ? `<th style="padding: 8px; text-align: center;" title="Inyección (ERP): pares inyectados | % de lo solicitado.${esValidador() ? ` ${escapeHtml(estadoSincronizacion(estadoInyeccion).texto)}.` : ''}">I%</th>` : ''}
          <th style="padding: 8px; text-align: center;" title="Refilado: pares procesados | % de avance">R%</th>
          <th style="padding: 8px; text-align: center;" title="Acabado: pares procesados | % de avance">A%</th>
          <th style="padding: 8px; text-align: center;" title="Mateado: pares procesados | % de avance">M%</th>
          <th style="padding: 8px; text-align: center;" title="Empaque: pares procesados | % de avance">E%</th>
          <th style="padding: 8px; text-align: center;" title="Días Refilado">D.R</th>
          <th style="padding: 8px; text-align: center;" title="Días Acabado">D.A</th>
          <th style="padding: 8px; text-align: center;" title="Días Mateado">D.M</th>
          <th style="padding: 8px; text-align: center;" title="Días Empaque">D.E</th>
          <th style="padding: 8px; text-align: center;" title="Días Orden (total)">D.O</th>
          <th style="padding: 8px; text-align: center;">Etapa</th>
          <th style="padding: 8px; text-align: center;">Estado</th>
          <th style="padding: 8px; text-align: center;" title="Comentarios de la orden">Comentarios</th>
        </tr>
      </thead>
      <tbody>
        ${ordenes.map((o) => {
          const dias = calcularDiasPorProceso(o, mapaUltimaFecha);
          return `
          <tr style="border-bottom: 1px solid var(--border);">
            <td style="padding: 8px;"><strong>${o.order_number}</strong></td>
            <td style="padding: 8px;">${o.cliente || '—'}</td>
            <td style="padding: 8px;">${o.nombre_referencia || '—'}</td>
            <td style="padding: 8px;">${o.material || '—'}</td>
            <td style="padding: 8px;">${o.color || '—'}</td>
            <td style="padding: 8px;">${formatearFecha(o.fecha_pedido)}</td>
            <td style="padding: 8px; text-align: center;"><strong>${o.total_solicitado ?? 0}</strong></td>
            <td style="padding: 8px; text-align: center;">${celdaDespachadas(o, despachadas)}</td>
            ${verInyeccion ? `<td style="padding: 8px; text-align: center;">${celdaInyeccion(o, inyeccion)}</td>` : ''}
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_refilado, porcentajeReal(o.procesado_refilado, o.total_refilado), 'var(--blue-bg)', 'var(--blue)')}</td>
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_acabado, porcentajeReal(o.procesado_acabado, o.total_acabado), 'var(--green-bg)', 'var(--green-text)')}</td>
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_mateado, porcentajeReal(o.procesado_mateado, o.total_mateado), 'var(--purple-bg)', 'var(--purple-text)')}</td>
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_empaque, porcentajeReal(o.procesado_empaque, o.total_empaque), 'var(--amber-bg)', 'var(--amber-text)')}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dRefilado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dAcabado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dMateado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dEmpaque)}</td>
            <td style="padding: 8px; text-align: center;"><strong>${o.dias_orden ?? 0}</strong></td>
            <td style="padding: 8px; text-align: center;">${badgeEtapa(o.etapa_actual)}</td>
            <td style="padding: 8px; text-align: center;">
              ${badgeEstado(o)}
            </td>
            <td style="padding: 8px; text-align: center;">
              <div class="regd-col-comentario">${botonComentarioOrden(o)}</div>
            </td>
          </tr>
        `;
        }).join('')}
      </tbody>
    </table>
  `;

  cerrarTooltipComentarios();
  tabla.innerHTML = html;

  // Un solo escuchador para todos los botones de comentarios (la tabla se redibuja).
  if (!tabla.dataset.comentariosListo) {
    tabla.dataset.comentariosListo = '1';
    tabla.addEventListener('click', (event) => {
      const boton = event.target.closest?.('[data-comentarios-orden]');
      if (!boton) return;
      cerrarTooltipComentarios();
      abrirComentariosPedido(boton.dataset.comentariosOrden, { alCambiar: () => cargarValidador() });
    });
    // Al pasar el cursor por un botón con comentarios: cuadro con autor, fecha y texto.
    tabla.addEventListener('mouseover', (event) => {
      const boton = event.target.closest?.('.btn-comentario-registro.con-comentario');
      if (boton && boton !== botonTooltip) mostrarTooltipComentarios(boton);
    });
    tabla.addEventListener('mouseout', (event) => {
      const boton = event.target.closest?.('.btn-comentario-registro.con-comentario');
      if (boton && !boton.contains(event.relatedTarget)) cerrarTooltipComentarios();
    });
    tabla.addEventListener('scroll', cerrarTooltipComentarios, true);
  }
}

function renderPaginacionValidador() {
  const el = document.getElementById('validador-pag-info');
  el.textContent = `Página ${paginaActual + 1}`;
  document.getElementById('validador-pag-prev').disabled = paginaActual === 0;
  document.getElementById('validador-pag-next').disabled = !hayPaginaSiguiente;
}
