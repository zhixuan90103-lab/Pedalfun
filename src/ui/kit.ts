/** Shared UI helpers: formatting, elevation profile, hold-to-confirm, toast. */

import { settings } from '../data/store';
import type { Sample } from '../ride/types';
import { haptics } from '../utils/haptics';

export type Screen = {
  el: HTMLElement;
  enter?: (param?: unknown) => void;
  leave?: () => void;
};

export function html(markup: string): HTMLElement {
  const t = document.createElement('template');
  t.innerHTML = markup.trim();
  return t.content.firstElementChild as HTMLElement;
}

export function ref<T extends HTMLElement = HTMLElement>(root: HTMLElement, name: string): T {
  const el = root.querySelector<T>(`[data-ref="${name}"]`);
  if (!el) throw new Error(`missing ref: ${name}`);
  return el;
}

/* ---------- units & formatting ---------- */

const KM_PER_MI = 1.609344;
const FT_PER_M = 3.28084;

export const unit = {
  speed: () => (settings.units === 'km' ? 'km/h' : 'mph'),
  dist: () => (settings.units === 'km' ? 'km' : 'mi'),
  alt: () => (settings.units === 'km' ? 'm' : 'ft'),
};

export function fmtSpeed(kmh: number): string {
  const v = settings.units === 'km' ? kmh : kmh / KM_PER_MI;
  return v.toFixed(1);
}

export function fmtDist(metres: number, digits = 2): string {
  const v = metres / 1000 / (settings.units === 'km' ? 1 : KM_PER_MI);
  return v.toFixed(v >= 100 ? Math.min(digits, 1) : digits);
}

export function fmtAlt(metres: number): string {
  return Math.round(settings.units === 'km' ? metres : metres * FT_PER_M).toString();
}

export function fmtDur(sec: number): string {
  const s = Math.max(0, Math.round(sec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  return `${h}:${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
}

export function fmtGrade(pct: number): string {
  const r = Math.round(pct * 10) / 10;
  if (r === 0) return '0.0';
  return `${r > 0 ? '+' : '−'}${Math.abs(r).toFixed(1)}`;
}

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

export function fmtDate(d: Date): string {
  return `${d.getMonth() + 1}月${d.getDate()}日 ${WEEKDAYS[d.getDay()]}`;
}

export function fmtClock(d: Date): string {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/* ---------- grade bands ---------- */

export type GradeBand = 'down' | 'flat' | 'up';

export function gradeBand(pct: number): GradeBand {
  if (pct <= -3) return 'down';
  if (pct < 3) return 'flat';
  return 'up';
}

/* ---------- elevation profile ---------- */

/** Flat stepped area chart; each segment filled by its grade band. */
export function profileSvg(samples: Sample[], width: number, height: number, maxSeg = 56): string {
  const open = `<svg class="profile" viewBox="0 0 ${width} ${height}" preserveAspectRatio="none" aria-hidden="true">`;
  if (samples.length < 2 || samples[samples.length - 1].d - samples[0].d < 1) {
    return `${open}<rect class="pf-flat" x="0" y="${height - 3}" width="${width}" height="3"/></svg>`;
  }
  const n = Math.min(maxSeg, samples.length - 1);
  const pts: Sample[] = [];
  for (let i = 0; i <= n; i++) {
    pts.push(samples[Math.round((i / n) * (samples.length - 1))]);
  }
  const d0 = pts[0].d;
  const span = pts[n].d - d0;
  let lo = Infinity;
  let hi = -Infinity;
  for (const p of pts) {
    lo = Math.min(lo, p.a);
    hi = Math.max(hi, p.a);
  }
  const range = Math.max(hi - lo, 24);
  const floor = 6;
  const x = (p: Sample) => ((p.d - d0) / span) * width;
  const y = (p: Sample) => height - floor - ((p.a - lo) / range) * (height - floor - 2);

  let out = open;
  for (let i = 0; i < n; i++) {
    const a = pts[i];
    const b = pts[i + 1];
    const run = b.d - a.d;
    if (run <= 0) continue;
    const band = gradeBand(((b.a - a.a) / run) * 100);
    const x1 = x(a).toFixed(1);
    const x2 = x(b).toFixed(1);
    out += `<polygon class="pf-${band}" points="${x1},${height} ${x1},${y(a).toFixed(1)} ${x2},${y(b).toFixed(1)} ${x2},${height}"/>`;
  }
  return `${out}</svg>`;
}

/* ---------- feedback ---------- */

export function buzz(kind: 'light' | 'medium' | 'heavy' = 'medium'): void {
  if (settings.haptics) void haptics.impact(kind);
}

/**
 * Press-and-hold button: the ring fills over `ms`, fires on completion,
 * cancels on early release (`onShort`, e.g. to hint that it needs a hold).
 * Enter / Space fire immediately for keyboard users.
 */
export function holdButton(btn: HTMLElement, onDone: () => void, onShort?: () => void, ms = 600): void {
  let timer: number | null = null;
  btn.style.setProperty('--hold-ms', `${ms}ms`);

  const cancel = (short: boolean) => {
    const wasHolding = timer !== null;
    if (timer !== null) window.clearTimeout(timer);
    timer = null;
    btn.classList.remove('holding');
    if (short && wasHolding) onShort?.();
  };
  btn.addEventListener('pointerdown', (ev) => {
    ev.preventDefault();
    cancel(false);
    btn.classList.add('holding');
    timer = window.setTimeout(() => {
      cancel(false);
      buzz('heavy');
      onDone();
    }, ms);
    buzz('light');
  });
  btn.addEventListener('pointerup', () => cancel(true));
  btn.addEventListener('pointerleave', () => cancel(false));
  btn.addEventListener('pointercancel', () => cancel(false));
  btn.addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter' || ev.key === ' ') {
      ev.preventDefault();
      onDone();
    }
  });
}

export type IconName = keyof typeof ICON;

/**
 * Round icon button. `hold: true` adds the outer ring that fills while the
 * press is held. `label` is the accessible name only; no visible text.
 */
export function roundBtn(o: { ref: string; icon: IconName; label: string; cls?: string; hold?: boolean }): string {
  const ring = o.hold
    ? `<svg class="rbtn-ring" viewBox="0 0 100 100" aria-hidden="true"><circle cx="50" cy="50" r="47" pathLength="100" /></svg>`
    : '';
  return `<button type="button" class="rbtn ${o.hold ? 'rbtn-hold ' : ''}${o.cls ?? ''}" data-ref="${o.ref}" aria-label="${o.label}">${ring}${ICON[o.icon]}</button>`;
}

let toastTimer: number | null = null;

export function toast(text: string): void {
  const el = document.getElementById('toast');
  if (!el) return;
  el.textContent = text;
  el.classList.add('show');
  if (toastTimer !== null) window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => el.classList.remove('show'), 2200);
}

const stroke = (d: string) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
const solid = (d: string) => `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">${d}</svg>`;

export const ICON = {
  back: stroke('<path d="M15 5l-7 7 7 7"/>'),
  list: stroke('<path d="M4 6h16M4 12h16M4 18h10"/>'),
  gear: stroke('<path d="M4 7h9M19 7h1M4 17h1M11 17h9"/><circle cx="16" cy="7" r="2.6"/><circle cx="8" cy="17" r="2.6"/>'),
  play: solid('<path d="M8 5.2v13.6a1.2 1.2 0 0 0 1.8 1l11.3-6.8a1.2 1.2 0 0 0 0-2L9.8 4.2a1.2 1.2 0 0 0-1.8 1z"/>'),
  pause: solid('<rect x="5.5" y="4.5" width="4.6" height="15" rx="1.6"/><rect x="13.9" y="4.5" width="4.6" height="15" rx="1.6"/>'),
  stop: solid('<rect x="5.5" y="5.5" width="13" height="13" rx="2.6"/>'),
  check: stroke('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  trash: stroke('<path d="M4.5 7h15M10 7V4.5h4V7M6.5 7l.9 12.5h9.2L17.500 7M10 11v5M14 11v5"/>'),
  share: stroke('<path d="M12 15V4M8 7.5L12 3.5l4 4M5.5 12v7.5h13V12"/>'),
};
