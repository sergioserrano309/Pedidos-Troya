/**
 * Lógica pura del dashboard operativo (Refilado / Acabado / Mateado).
 * Sin pantalla ni base de datos.
 */

export const ZONA_AREA = 'America/Bogota';

const formateadorLlegada = new Intl.DateTimeFormat('es-CO', {
  timeZone: ZONA_AREA,
  day: 'numeric',
  month: 'short',
  hour: 'numeric',
  minute: '2-digit'
});

function instanteValido(instante) {
  if (!instante) return null;
  const d = new Date(instante);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** "13 oct, 8:28 p. m." en hora de Colombia. */
export function formatearLlegadaArea(instante) {
  const d = instanteValido(instante);
  return d ? formateadorLlegada.format(d) : '—';
}

/** "Hace 22 días", "Ayer", "Hace 3 horas". Para FIFO en planta. */
export function formatearHaceCuanto(instante) {
  const d = instanteValido(instante);
  if (!d) return '—';
  const mins = Math.max(0, Math.floor((Date.now() - d.getTime()) / 60000));
  if (mins < 1) return 'Hace un momento';
  if (mins < 60) return `Hace ${mins} min`;
  const horas = Math.floor(mins / 60);
  if (horas < 24) return horas === 1 ? 'Hace 1 hora' : `Hace ${horas} horas`;
  const dias = Math.floor(horas / 24);
  if (dias === 1) return 'Ayer';
  if (dias < 30) return `Hace ${dias} días`;
  const meses = Math.floor(dias / 30);
  return meses === 1 ? 'Hace 1 mes' : `Hace ${meses} meses`;
}

export function formatearUnidades(valor) {
  return Math.round(Number(valor) || 0).toLocaleString('es-CO');
}

/** "6 pares" / "1 par". En planta se habla de pares, no de "unidades". */
export function formatearPares(valor) {
  const n = Math.round(Number(valor) || 0);
  const txt = n.toLocaleString('es-CO');
  return n === 1 ? `${txt} par` : `${txt} pares`;
}

/** Lo que el usuario teclea: dígitos, máximo 5, con punto de miles. */
export function formatearCantidadEscrita(texto) {
  const digitos = String(texto || '').replace(/\D/g, '').replace(/^0+/, '').slice(0, 5);
  return digitos ? Number(digitos).toLocaleString('es-CO') : '';
}

/** Inverso: "1.000" -> 1000. */
export function leerCantidad(texto) {
  return Number(String(texto || '').replace(/\D/g, '')) || 0;
}

export function tallasDePedido(pedido) {
  const raw = pedido?.tallas;
  if (Array.isArray(raw)) return raw;
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

export function etiquetaOrigen(origen) {
  if (!origen || origen === 'Pedido') return 'Viene del pedido';
  return `Te lo mandó ${origen}`;
}

export function detalleOrigen(origen) {
  if (!origen || origen === 'Pedido') return 'Todavía no pasó por otra área';
  return `Salieron de ${origen} hacia acá`;
}

/**
 * Textos de planta, por área. Frases cortas de lo que hay que hacer.
 * @param {'Refilado'|'Acabado'|'Mateado'} proceso
 */
export function textosPlanta(proceso) {
  const area = proceso || 'esta área';
  const verbo = {
    Refilado: 'refilaste',
    Acabado: 'acabaste',
    Mateado: 'mateaste'
  }[proceso] || 'procesaste';

  const paso3 = proceso === 'Refilado'
    ? 'Enviar → elige Acabado o Mateado'
    : 'Enviar → van a Empaque';

  return {
    titulo: `Tu trabajo en ${area}`,
    pasos: [
      'El de arriba es el más viejo',
      `Anota cuántos pares ya ${verbo}`,
      paso3
    ],
    teLlegaron: 'Te llegaron',
    yaEnviaste: 'Ya enviaste',
    teFaltan: 'Te faltan',
    cuantas: `¿Cuántos pares ya ${verbo}?`,
    usarTodas: 'Todas',
    queHacer: 'Qué tienes que hacer',
    deDonde: 'De dónde vino',
    cuandoLlego: 'Cuándo llegó',
    vacio: `No tienes nada pendiente en ${area}. Cuando te manden suelas, aparecen aquí.`,
    empiezaAqui: 'Empieza por este: es el más antiguo'
  };
}
