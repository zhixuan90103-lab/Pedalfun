/** Screen router with transitions, theme, and the desktop demo panel. */

import type { Phase } from '../data/sim';
import { loadRides, onSettings, rides, settings } from '../data/store';
import { isSimMode } from '../ride/engine';
import type { Screen } from './kit';
import { createHistory, createHome, createSettings, createSummary } from './pages';
import { createRide, currentSim } from './ride';

export type ScreenName = 'home' | 'ride' | 'summary' | 'history' | 'settings';
export type Nav = { go: (name: ScreenName, param?: unknown) => void };

/** Start-button centre in design coords, passed by home when starting a ride. */
type Origin = { x: number; y: number; r: number };

const DEPTH: Record<ScreenName, number> = { home: 0, history: 1, settings: 1, ride: 1, summary: 2 };
const EASE_OUT = 'cubic-bezier(0.2, 0.8, 0.2, 1)';

function reducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function applyTheme(stage: HTMLElement, forced?: string | null): void {
  const dark =
    settings.theme === 'dark' ||
    (settings.theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  stage.dataset.theme = forced === 'light' || forced === 'dark' ? forced : dark ? 'dark' : 'light';
}

export async function mountApp(uiRoot: HTMLElement, stage: HTMLElement): Promise<void> {
  await loadRides(isSimMode());

  const screens = {} as Record<ScreenName, Screen>;
  let current: ScreenName | null = null;
  let busy = false;

  const reveal = document.createElement('div');
  reveal.id = 'reveal';
  uiRoot.appendChild(reveal);

  const show = (name: ScreenName, param?: unknown) => {
    if (current && current !== name) {
      screens[current].leave?.();
      screens[current].el.classList.remove('active');
    }
    screens[name].el.classList.add('active');
    screens[name].enter?.(param);
    current = name;
    document.body.dataset.screen = name;
  };

  /**
   * Start ride: green floods out of the start button, then retracts upward
   * to become the speed field.
   */
  const startReveal = (o: Origin) => {
    busy = true;
    reveal.style.display = 'block';
    const at = `${o.x}px ${o.y}px`;
    const flood = reveal.animate(
      [{ clipPath: `circle(${o.r}px at ${at})` }, { clipPath: `circle(980px at ${at})` }],
      { duration: 430, easing: 'cubic-bezier(0.5, 0, 0.2, 1)' },
    );
    flood.onfinish = () => {
      show('ride');
      const hero = screens.ride.el.querySelector<HTMLElement>('.ride-hero')!;
      const rest = stage.offsetHeight - hero.offsetHeight;
      const settle = reveal.animate(
        [{ clipPath: 'inset(0 0 0 0)' }, { clipPath: `inset(0 0 ${rest}px 0)` }],
        { duration: 400, easing: 'cubic-bezier(0.3, 0, 0.1, 1)' },
      );
      // The staggered rise-in outlasts the retract; removing the class early
      // would cut it off mid-fade and make the pause button jump.
      const rideEl = screens.ride.el;
      rideEl.classList.add('settling');
      window.setTimeout(() => rideEl.classList.remove('settling'), 800);
      settle.onfinish = () => {
        reveal.style.display = 'none';
        busy = false;
      };
    };
  };

  const nav: Nav = {
    go: (name, param) => {
      if (busy) return;
      const prev = current;
      if (!prev || prev === name || reducedMotion()) {
        show(name, param);
        return;
      }
      if (prev === 'home' && name === 'ride' && param) {
        startReveal(param as Origin);
        return;
      }
      // Push / pop: the old screen stays underneath until the new one lands.
      const forward = DEPTH[name] > DEPTH[prev];
      const oldEl = screens[prev].el;
      const nextEl = screens[name].el;
      show(name, param);
      oldEl.classList.add('leaving');
      nextEl.style.zIndex = '2';
      const anim = nextEl.animate(
        [
          { transform: `translateX(${forward ? 36 : -36}px)`, opacity: 0 },
          { transform: 'none', opacity: 1 },
        ],
        { duration: 260, easing: EASE_OUT },
      );
      const done = () => {
        oldEl.classList.remove('leaving');
        nextEl.style.zIndex = '';
      };
      anim.onfinish = done;
      anim.oncancel = done;
    },
  };

  screens.home = createHome(nav);
  screens.ride = createRide(nav);
  screens.summary = createSummary(nav);
  screens.history = createHistory(nav);
  screens.settings = createSettings(nav);
  for (const s of Object.values(screens)) uiRoot.appendChild(s.el);

  // ?screen= ?phase= ?ff= ?paused=1 ?theme= — jump straight to a state for review.
  const q = new URLSearchParams(window.location.search);
  const forcedTheme = q.get('theme');

  const retheme = () => applyTheme(stage, forcedTheme);
  retheme();
  onSettings(retheme);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', retheme);

  const screen = q.get('screen') as ScreenName | null;
  if (screen === 'ride') {
    show('ride');
    const sim = currentSim();
    if (sim) {
      const ff = Number(q.get('ff') ?? 0);
      if (ff > 0) sim.fastForward(ff);
      const phase = q.get('phase') as Phase | null;
      if (phase) {
        sim.force(phase);
        for (let i = 0; i < 8; i++) sim.step();
      }
      if (q.get('paused') === '1') sim.pause();
      else sim.fastForward(0);
    }
  } else if (screen === 'summary') {
    show('summary', { ride: rides[2], live: q.get('live') === '1', from: 'history' });
  } else if (screen === 'history' || screen === 'settings') {
    show(screen);
  } else {
    show('home');
  }

  if (isSimMode()) mountDemoPanel();
}

function mountDemoPanel(): void {
  const panel = document.getElementById('demo-panel');
  if (!panel) return;
  panel.classList.add('visible');

  panel.addEventListener('click', (ev) => {
    const btn = (ev.target as HTMLElement).closest<HTMLButtonElement>('button[data-demo]');
    const sim = currentSim();
    if (!btn || !sim) return;
    const demo = btn.dataset.demo!;
    if (demo === 'ff') {
      sim.fastForward(1800);
      return;
    }
    sim.force(demo === 'auto' ? null : (demo as Phase));
    panel.querySelectorAll('button[data-demo]').forEach((b) => b.classList.toggle('active', b === btn));
  });
}
