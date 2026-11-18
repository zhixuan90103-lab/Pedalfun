/**
 * Live ride: fix source → tracker → RideState for the UI.
 * Also decides which engine a session uses:
 *   iOS app            → live (native plugin)
 *   browser            → simulated ride, for looking at the UI
 *   browser + ?gps=1   → live from navigator.geolocation
 */

import { Capacitor } from '@capacitor/core';
import { RideSim } from '../data/sim';
import { settings } from '../data/store';
import { haptics } from '../utils/haptics';
import { createSource, type FixSource, type Permission } from './source';
import { RideTracker } from './tracker';
import type { RideEngine, RideState } from './types';

export const isSimMode = (): boolean =>
  !Capacitor.isNativePlatform() && new URLSearchParams(window.location.search).get('gps') !== '1';

export class LiveRide implements RideEngine {
  private readonly source: FixSource = createSource();
  private tracker = new RideTracker(() => settings.autoPause);
  private timer: number | null = null;
  private draining = false;
  private onTick: (() => void) | null = null;

  get state(): RideState {
    return this.tracker.state;
  }

  async prepare(): Promise<void> {
    await this.source.start();
  }

  start(onTick: () => void): void {
    this.onTick = onTick;
    this.tracker = new RideTracker(() => settings.autoPause);
    this.timer = window.setInterval(this.tick, 1000);
    document.addEventListener('visibilitychange', this.tick);
    void this.tick();
  }

  stop(): void {
    if (this.timer !== null) window.clearInterval(this.timer);
    this.timer = null;
    document.removeEventListener('visibilitychange', this.tick);
    this.source.stop();
  }

  pause(): void {
    this.tracker.pause();
    this.onTick?.();
  }

  resume(): void {
    this.tracker.resume();
    this.onTick?.();
  }

  /**
   * Runs once a second, and immediately when the app returns to the
   * foreground: everything recorded natively in the meantime arrives here
   * as one batch and is replayed by timestamp.
   */
  private tick = async (): Promise<void> => {
    if (this.draining) return;
    this.draining = true;
    try {
      const fixes = await this.source.drain();
      for (const f of fixes) this.tracker.push(f);
    } catch (err) {
      console.warn('[ride] drain failed', err);
    } finally {
      this.draining = false;
    }
    const s = this.tracker.state;
    s.total = (Date.now() - s.startedAt.getTime()) / 1000;
    this.onTick?.();
  };
}

let prepared: RideEngine | null = null;

/** Called by the start button, before leaving home. Rejects with a user-facing message. */
export async function prepareRide(): Promise<void> {
  const engine: RideEngine = isSimMode() ? new RideSim() : new LiveRide();
  await engine.prepare();
  prepared?.stop();
  prepared = engine;
}

/** The riding screen takes over the prepared engine (or a fresh one when opened directly). */
export function takeEngine(): RideEngine {
  const engine = prepared ?? (isSimMode() ? new RideSim() : new LiveRide());
  if (!prepared) void engine.prepare().catch((err) => console.warn('[ride] prepare failed', err));
  prepared = null;
  return engine;
}

export async function locationPermission(): Promise<Permission> {
  if (isSimMode()) return 'granted';
  return createSource().permission();
}

export function setRideAwake(on: boolean): void {
  void haptics.setKeepAwake(on && settings.keepAwake);
}
