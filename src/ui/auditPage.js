import { fetchAuditValidador } from '../services/validatorService.js';
import { mostrarToast } from './toast.js';

export async function cargarAuditPage() {
  const contenedor = document.getElementById('page-audit');
  if (!contenedor) return;

  contenedor.innerHTML = `
    <div class="card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
        <h2>📋 Historial de Auditoría — Intervenciones del Validador</h2>
        <button id="btn-refrescar-audit" class="btn btn-secondary btn-sm">🔄 Refrescar</button>
      </div>

      <div style="margin-bottom: 1rem; display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 1rem;">
        <div>
          <label style="font-size: 12px; color: var(--text2); display: block; margin-bottom: 0.25rem;">Acción:</label>
          <select id="filtro-accion-audit" style="width: 100%; padding: 6px; border: 1px solid var(--border); border-radius: 4px; font-size: 12px;">
            <option value="">Todas</option>
            <option value="procesar_orden">Procesar Orden</option>
            <option value="eliminar_movimiento">Eliminar Movimiento</option>
            <option value="crear_regla">Crear Regla</option>
            <option value="editar_regla">Editar Regla</option>
            <option value="eliminar_regla">Eliminar Regla</option>
          </select>
        </div>
        <div>
          <label style="font-size: 12px; color: var(--text2); display: block; margin-bottom: 0.25rem;">Rol Actuante:</label>
          <select id="filtro-rol-audit" style="width: 100%; padding: 6px; border: 1px solid var(--border); border-radius: 4px; font-size: 12px;">
            <option value="">Todos</option>
            <option value="Refilado">Refilado</option>
            <option value="Acabado">Acabado</option>
            <option value="Empaque">Empaque</option>
          </select>
        </div>
        <div>
          <label style="font-size: 12px; color: var(--text2); display: block; margin-bottom: 0.25rem;">Orden:</label>
          <input id="filtro-orden-audit" type="text" placeholder="Número de orden" style="width: 100%; padding: 6px; border: 1px solid var(--border); border-radius: 4px; font-size: 12px;">
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: flex-end;">
          <button id="btn-limpiar-filtros" class="btn btn-secondary btn-sm" style="flex: 1;">Limpiar</button>
        </div>
      </div>

      <div style="overflow-x: auto;">
        <div id="audit-tabla"></div>
      </div>
    </div>
  `;

  document.getElementById('btn-refrescar-audit')?.addEventListener('click', () => cargarAudit());
  document.getElementById('filtro-accion-audit')?.addEventListener('change', () => cargarAudit());
  document.getElementById('filtro-rol-audit')?.addEventListener('change', () => cargarAudit());
  document.getElementById('filtro-orden-audit')?.addEventListener('input', () => cargarAudit());
  document.getElementById('btn-limpiar-filtros')?.addEventListener('click', () => {
    document.getElementById('filtro-accion-audit').value = '';
    document.getElementById('filtro-rol-audit').value = '';
    document.getElementById('filtro-orden-audit').value = '';
    cargarAudit();
  });

  await cargarAudit();
}

async function cargarAudit() {
  const accion = document.getElementById('filtro-accion-audit')?.value || '';
  const rolActuante = document.getElementById('filtro-rol-audit')?.value || '';
  const ordenId = document.getElementById('filtro-orden-audit')?.value.trim() || '';

  const filtros = {};
  if (accion) filtros.accion = accion;
  if (rolActuante) filtros.rolActuante = rolActuante;
  if (ordenId) filtros.ordenId = ordenId;

  try {
    const data = await fetchAuditValidador(filtros);
    renderTablaAudit(data);
  } catch (err) {
    console.error('[auditPage] Error:', err);
    mostrarToast('Error cargando auditoría', 'error');
  }
}

function renderTablaAudit(registros) {
  const tabla = document.getElementById('audit-tabla');

  if (registros.length === 0) {
    tabla.innerHTML = '<div class="empty">No hay registros de auditoría.</div>';
    return;
  }

  const html = `
    <table style="width: 100%; border-collapse: collapse; font-size: 12px;">
      <thead>
        <tr style="background: var(--bg); border-bottom: 2px solid var(--border);">
          <th style="padding: 8px; text-align: left;">Fecha/Hora</th>
          <th style="padding: 8px; text-align: left;">Acción</th>
          <th style="padding: 8px; text-align: left;">Rol Actuante</th>
          <th style="padding: 8px; text-align: left;">Orden</th>
          <th style="padding: 8px; text-align: left;">Razón</th>
          <th style="padding: 8px; text-align: left;">Detalle</th>
        </tr>
      </thead>
      <tbody>
        ${registros.map((r) => `
          <tr style="border-bottom: 1px solid var(--border);">
            <td style="padding: 8px; font-size: 11px;">${formatearFecha(r.creado_en)}</td>
            <td style="padding: 8px;">
              <span style="background: var(--purple-bg); color: var(--purple-text); padding: 2px 6px; border-radius: 3px; font-size: 11px;">
                ${r.accion}
              </span>
            </td>
            <td style="padding: 8px;"><strong>${r.rol_actuante}</strong></td>
            <td style="padding: 8px;">${r.orden_id || '—'}</td>
            <td style="padding: 8px; color: var(--text2); font-size: 11px;">${r.razon || '—'}</td>
            <td style="padding: 8px; color: var(--text3); font-size: 10px;">
              <code style="background: var(--bg); padding: 2px 4px; border-radius: 2px;">
                ${r.detalle ? JSON.stringify(r.detalle).substring(0, 100) + '...' : '—'}
              </code>
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  tabla.innerHTML = html;
}

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    const d = new Date(fecha);
    const dateStr = d.toLocaleDateString('es-CO');
    const timeStr = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    return `${dateStr} ${timeStr}`;
  } catch {
    return String(fecha);
  }
}
