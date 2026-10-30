/** Pure formatting and command helpers; no machine readings are fabricated. */
export function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

export function commandFor(runtime, args) {
  if (!runtime || typeof runtime.python !== 'string' || typeof runtime.cli !== 'string' || !runtime.python.startsWith('/') || !runtime.cli.startsWith('/')) return null;
  return [runtime.python, runtime.cli, ...args].map(shellQuote).join(' ');
}

export function parsePayload(output) {
  if (!output || !String(output).trim()) return { error: 'Waiting for device measurements…' };
  try {
    const payload = JSON.parse(output);
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) throw new Error('Expected an object');
    return payload;
  } catch (_) {
    return { error: 'Could not read widget data. Run check-system.sh for diagnostics.' };
  }
}

export function numberOrNull(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export function percentage(value) {
  const numeric = numberOrNull(value);
  return numeric === null ? 'Unavailable' : `${Math.round(Math.max(0, Math.min(100, numeric)))}%`;
}

export function formatBytes(value) {
  const numeric = numberOrNull(value);
  if (numeric === null || numeric < 0) return 'Unavailable';
  if (numeric < 1024 ** 3) return `${Math.round(numeric / 1024 ** 2)} MB`;
  return `${(numeric / 1024 ** 3).toFixed(1)} GB`;
}

export function temperature(value, unit = 'celsius') {
  const numeric = numberOrNull(value);
  return numeric === null ? '—' : `${Math.round(numeric)}°${unit === 'fahrenheit' || unit === '°F' || unit === 'F' ? 'F' : 'C'}`;
}

export function weatherSymbol(code) {
  if (code === null || code === undefined) return '◌';
  if (code === 0) return '☀';
  if ([1, 2].includes(code)) return '⛅';
  if (code === 3) return '☁';
  if ([45, 48].includes(code)) return '≋';
  if (code >= 95) return 'ϟ';
  if ([71, 73, 75, 77, 85, 86].includes(code)) return '❄';
  return '☂';
}

export function focusRemaining(focus, now = Date.now()) {
  if (!focus || focus.endsAt === null || focus.endsAt === undefined) return null;
  const endsAt = typeof focus.endsAt === 'number' ? focus.endsAt : Date.parse(focus.endsAt);
  if (!Number.isFinite(endsAt)) return null;
  return Math.max(0, Math.ceil((endsAt - now) / 1000));
}

export function clockDuration(seconds) {
  if (seconds === null) return 'Ready';
  return `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
}

export function monthCells(date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const offset = new Date(year, month, 1).getDay();
  const length = new Date(year, month + 1, 0).getDate();
  const result = Array(offset).fill(null);
  for (let day = 1; day <= length; day++) result.push(day);
  while (result.length % 7) result.push(null);
  return result;
}

export function panelPosition(config = {}) {
  const finite = (value, fallback, min, max) => {
    const num = numberOrNull(value);
    return num === null ? fallback : Math.min(max, Math.max(min, num));
  };
  return { left: finite(config.x, 24, 0, 30000), top: finite(config.y, 48, 0, 30000), width: finite(config.width, 292, 180, 900) };
}
