import { getState } from '../state/appState.js';
import { fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { fetchReglasEnrutamiento, crearReglaEnrutamiento, eliminarReglaEnrutamiento } from '../services/reglasEnrutamientoService.js';
import { ICONO_PROCESO } from '../lib/roles.js';
import { mostrarToast } from './toast.js';

let opcionesCargadas = false;

export function inicializarPaginaReglas() {
  document.getElementById('btn-guardar-regla').addEventListener('click', guardarRegla);
}

export async function cargarReglas() {
  if (!opcionesCargadas) {
    await poblarSelectsRegla();
    opcionesCargadas = true;
  }

  const tbody = document.getElementById('reglas-tabla');
  tbody.innerHTML = '<tr><td colspan="6" class="empty">Cargando...</td></tr>';

  const reglas = await fetchReglasEnrutamiento();

  if (reglas.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty">No hay reglas configuradas.</td></tr>';
    return;
  }

  tbody.innerHTML = reglas
    .map((r) => `
      <tr>
        <td>${escapeHtml(r.nombre_referencia || 'Cualquiera')}</td>
        <td>${escapeHtml(r.material || 'Cualquiera')}</td>
        <td>${escapeHtml(r.color || 'Cualquiera')}</td>
        <td>${escapeHtml(r.destino)} ${ICONO_PROCESO[r.destino] || ''}</td>
        <td>${escapeHtml(r.profiles?.name || '—')}</td>
        <td><button class="btn btn-danger btn-sm btn-eliminar-regla" data-id="${r.id}">Eliminar</button></td>
      </tr>`)
    .join('');

  tbody.querySelectorAll('.btn-eliminar-regla').forEach((btn) => {
    btn.addEventListener('click', async () => {
      if (!confirm('¿Eliminar esta regla de enrutamiento?')) return;
      try {
        await eliminarReglaEnrutamiento(btn.dataset.id);
        mostrarToast('Regla eliminada.', 'ok');
        cargarReglas();
      } catch (err) {
        mostrarToast(err.message, 'error');
      }
    });
  });
}

async function poblarSelectsRegla() {
  const rellenar = (id, valores) => {
    const select = document.getElementById(id);
    if (!select) return;
    valores.forEach((valor) => {
      const option = document.createElement('option');
      option.value = valor;
      option.textContent = valor;
      select.appendChild(option);
    });
  };

  try {
    const [nombresSuela, materiales, colores] = await Promise.all([
      fetchOpcionesNombreSuela(),
      fetchOpcionesMaterial(),
      fetchOpcionesColor()
    ]);
    rellenar('regla-nombre-suela', nombresSuela);
    rellenar('regla-material', materiales);
    rellenar('regla-color', colores);
  } catch (err) {
    console.error('[reglasPage] Error cargando opciones:', err);
  }
}

async function guardarRegla() {
  const { user } = getState();

  const nombreReferencia = document.getElementById('regla-nombre-suela').value;
  const material = document.getElementById('regla-material').value;
  const color = document.getElementById('regla-color').value;
  const destino = document.getElementById('regla-destino').value;

  if (!nombreReferencia && !material && !color) {
    mostrarToast('Selecciona al menos un criterio (Nombre Suela, Material o Color).', 'error');
    return;
  }
  if (!destino) {
    mostrarToast('Selecciona el destino de la regla.', 'error');
    return;
  }

  const btn = document.getElementById('btn-guardar-regla');
  btn.disabled = true;

  try {
    await crearReglaEnrutamiento({ nombreReferencia, material, color, destino }, user);
    mostrarToast('Regla guardada correctamente.', 'ok');
    document.getElementById('regla-nombre-suela').value = '';
    document.getElementById('regla-material').value = '';
    document.getElementById('regla-color').value = '';
    document.getElementById('regla-destino').value = '';
    cargarReglas();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
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
