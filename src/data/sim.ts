/**
 * Simulated ride for the UI stage. Replaced later by the native
 * location / motion plugin; the RideState shape is what screens render.
 */

import type { RideEngine, RideState } from '../ride/types';
import { mulberry, settings } from './store';

export type Phase = 'cruise' | 'climb' | 'descent' | 'stop' | 'gpsWeak';

const SCRIPT: [Phase, number][] = [
  ['cruise', 16],
  ['climb', 22],
  ['descent', 10],
  ['cruise', 10],
  ['stop', 9],
  ['cruise', 12],
  ['gpsWeak', 6],
];
const SCRIPT_LEN = SCRIPT.reduce((s, [, n]) => s + n, 0);

export class RideSim implements RideEngine {
  state: RideState;
  /** null = follow the scripted loop */
  forced: Phase | null = null;

  private rnd = mulberry(7);
  private lowTicks = 0;
  private timer: number | null = null;
  private onTick: (() => void) | null = null;

  constructor() {
    this.state = {
      status: 'moving',
      gps: 'good',
      startedAt: new Date(),
      moving: 0,
      total: 0,
      dist: 0,
      speed: 0,
      max: 0,
      alt: 86,
      altMax: 86,
      climb: 0,
      grade: 0,
      samples: [{ d: 0, a: 86 }],
      track: [[]],
    };
  }

  async prepare(): Promise<void> {
    /* nothing to acquire */
  }

  start(onTick: () => void): void {
    this.onTick = onTick;
    this.timer = window.setInterval(() => {
      this.step();
      onTick();
    }, 1000);
    onTick();
  }

  stop(): void {
    if (this.timer !== null) window.clearInterval(this.timer);
    this.timer = null;
  }

  pause(): void {
    this.state.status = 'paused';
    this.state.speed = 0;
    this.onTick?.();
  }

  resume(): void {
    this.state.status = 'moving';
    this.lowTicks = 0;
    this.onTick?.();
  }

  force(phase: Phase | null): void {
    this.forced = phase;
  }

  fastForward(seconds: number): void {
    const keep = this.forced;
    this.forced = null;
    for (let i = 0; i < seconds; i++) this.step();
    this.forced = keep;
    this.state.startedAt = new Date(Date.now() - this.state.total * 1000);
    this.onTick?.();
  }

  private scripted(): Phase {
    let t = this.state.total % SCRIPT_LEN;
    for (const [phase, len] of SCRIPT) {
      if (t < len) return phase;
      t -= len;
    }
    return 'cruise';
  }

  step(): void {
    const s = this.state;
    s.total += 1;
    if (s.status === 'paused') return;

    const phase = this.forced ?? this.scripted();
    const wobble = Math.sin(s.total / 3.1);
    let targetSpeed = 27 + wobble * 1.8;
    let targetGrade = wobble * 0.8;
    if (phase === 'climb') {
      targetSpeed = 12.5 + wobble;
      targetGrade = 6.8 + wobble * 2.4;
    } else if (phase === 'descent') {
      targetSpeed = 46 + wobble * 5;
      targetGrade = -4.6 + wobble * 0.8;
    } else if (phase === 'stop') {
      targetSpeed = 0;
      targetGrade = 0;
    }
    // Rolling terrain over kilometre scale so the scripted profile has shape.
    if (!this.forced && phase !== 'stop') targetGrade += 3.2 * Math.sin(s.dist / 1300);
    s.gps = phase === 'gpsWeak' ? 'weak' : 'good';

    s.speed += (targetSpeed - s.speed) * 0.4 + (this.rnd() - 0.5) * 0.8;
    if (targetSpeed === 0 && s.speed < 1.2) s.speed = 0;
    s.speed = Math.max(0, s.speed);
    s.grade += (targetGrade - s.grade) * 0.35;

    if (settings.autoPause) {
      this.lowTicks = s.speed < 1.5 ? this.lowTicks + 1 : 0;
      if (s.status === 'moving' && this.lowTicks >= 2) s.status = 'autoPaused';
      else if (s.status === 'autoPaused' && s.speed > 3) s.status = 'moving';
    } else if (s.status === 'autoPaused') {
      s.status = 'moving';
    }

    if (s.status !== 'moving') return;

    s.moving += 1;
    const dd = s.speed / 3.6;
    s.dist += dd;
    const da = (dd * s.grade) / 100;
    s.alt += da;
    if (da > 0) s.climb += da;
    s.altMax = Math.max(s.altMax, s.alt);
    s.max = Math.max(s.max, s.speed);
    if (s.moving % 4 === 0) s.samples.push({ d: s.dist, a: s.alt });
  }
}
