/**
 * Turns a stream of location fixes into ride numbers. Pure: no DOM, no
 * storage, no timers — everything is driven by fix timestamps, so fixes can
 * arrive one at a time or in a batch after the web view was suspended.
 *
 * Auto-pause is back-dated: a stop is confirmed a couple of seconds after it
 * began, then time and distance are rolled back to the moment it began; a
 * start is confirmed after about a second and the buffered fixes are replayed.
 * So the confirmation delay never leaks into the recorded numbers.
 *
 * The thresholds below are starting points and need tuning on real rides.
 */

import type { Fix, RideState, TrackPoint } from './types';

const TUNE = {
  /** fixes worse than this are shown as "GPS weak" */
  weakAcc: 35,
  /** fixes worse than this add no distance */
  rejectAcc: 65,
  /** faster than this between two fixes is a position glitch (m/s) */
  maxSpeed: 35,
  /** below this the bike is stopped (m/s) */
  stopSpeed: 0.6,
  /** with a still accelerometer, anything below this is GPS drift (m/s) */
  driftSpeed: 1.4,
  /** above this the bike is moving again (m/s) */
  goSpeed: 1.2,
  /** accelerometer level under which the phone counts as still (g) */
  stillMotion: 0.012,
  /** how long a stop must last before it is confirmed (ms) */
  stopConfirm: 2500,
  /** how long movement must last before it is confirmed (ms) */
  goConfirm: 1000,
  /** longest gap between fixes still credited as riding time (s) */
  maxGap: 15,
  /** barometer: climb hysteresis and grade window (m) */
  baroClimb: 1.5,
  baroWindow: 40,
  /** GPS altitude is much noisier */
  gpsClimb: 4,
  gpsWindow: 100,
  /** spacing of elevation-profile samples (m) */
  sampleEvery: 20,
};

const EARTH = 6371000;

export function haversine(aLat: number, aLon: number, bLat: number, bLon: number): number {
  const rad = Math.PI / 180;
  const dLat = (bLat - aLat) * rad;
  const dLon = (bLon - aLon) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(aLat * rad) * Math.cos(bLat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH * Math.asin(Math.min(1, Math.sqrt(h)));
}

type Snapshot = {
  since: number;
  moving: number;
  dist: number;
  climb: number;
  altMax: number;
  max: number;
  samples: number;
  trackPts: number;
  climbRef: number | null;
};

type Step = { fix: Fix; dd: number; dt: number; v: number; weak: boolean };

export class RideTracker {
  readonly state: RideState;

  private last: Fix | null = null;
  private altBase: number | null = null;
  private altSmooth: number | null = null;
  private climbRef: number | null = null;
  private window: { d: number; a: number }[] = [];
  private lastSampleD = 0;
  private stopCand: Snapshot | null = null;
  private goBuf: Step[] = [];

  constructor(
    private readonly autoPause: () => boolean,
    startedAt = new Date(),
  ) {
    this.state = {
      status: 'moving',
      gps: 'weak',
      startedAt,
      moving: 0,
      total: 0,
      dist: 0,
      speed: 0,
      max: 0,
      alt: 0,
      altMax: 0,
      climb: 0,
      grade: 0,
      samples: [],
      track: [[]],
    };
  }

  pause(): void {
    const s = this.state;
    // A stop that was still being confirmed is real: roll back to its start.
    if (this.stopCand) this.rollback(this.stopCand);
    this.stopCand = null;
    this.goBuf = [];
    s.status = 'paused';
    s.speed = 0;
    s.grade = 0;
  }

  resume(): void {
    this.state.status = 'moving';
    this.stopCand = null;
    this.goBuf = [];
    this.window = [];
    this.newSegment();
  }

  push(fix: Fix): void {
    const s = this.state;
    const prev = this.last;
    this.last = fix;

    const weak = !(fix.hAcc >= 0 && fix.hAcc <= TUNE.weakAcc);
    s.gps = weak ? 'weak' : 'good';

    const alt = this.altitude(fix);
    if (!prev) {
      s.alt = alt;
      s.altMax = alt;
      this.climbRef = alt;
      s.samples.push({ d: 0, a: alt });
      return;
    }
    s.alt = alt;
    if (s.status === 'paused') return;

    const dt = (fix.t - prev.t) / 1000;
    if (dt <= 0) return;
    const dd = haversine(prev.lat, prev.lon, fix.lat, fix.lon);
    if (dd / dt > TUNE.maxSpeed) return;
    const v = fix.speed !== null && fix.speed >= 0 ? fix.speed : dd / dt;
    const step: Step = { fix, dd, dt, v, weak };

    if (!this.autoPause()) {
      if (s.status === 'autoPaused') s.status = 'moving';
      this.stopCand = null;
      this.goBuf = [];
      this.accumulate(step);
      return;
    }

    const still = fix.motion !== null && fix.motion < TUNE.stillMotion;

    if (s.status === 'moving') {
      const stopped = v < TUNE.stopSpeed || (still && v < TUNE.driftSpeed);
      if (!stopped) {
        this.stopCand = null;
        this.accumulate(step);
        return;
      }
      this.stopCand ??= this.snapshot(prev.t);
      if (fix.t - this.stopCand.since >= TUNE.stopConfirm) {
        this.rollback(this.stopCand);
        this.stopCand = null;
        s.status = 'autoPaused';
        s.speed = 0;
        s.grade = 0;
        return;
      }
      // Still unconfirmed: keep counting, rollback undoes it if it was a stop.
      this.accumulate(step);
      return;
    }

    // autoPaused
    const going = v > TUNE.goSpeed && !(still && v < TUNE.driftSpeed * 1.5);
    if (!going) {
      this.goBuf = [];
      s.speed = 0;
      return;
    }
    this.goBuf.push(step);
    if (fix.t - this.goBuf[0].fix.t >= TUNE.goConfirm) {
      s.status = 'moving';
      this.window = [];
      this.newSegment();
      for (const st of this.goBuf) this.accumulate(st);
      this.goBuf = [];
    }
  }

  private altitude(fix: Fix): number {
    if (fix.baro !== null) {
      if (this.altBase === null) this.altBase = (fix.alt ?? 0) - fix.baro;
      return this.altBase + fix.baro;
    }
    if (fix.alt !== null) {
      this.altSmooth =
        this.altSmooth === null ? fix.alt : this.altSmooth + (fix.alt - this.altSmooth) * 0.15;
      return this.altSmooth;
    }
    return this.state.alt;
  }

  private accumulate({ fix, dd, dt, v, weak }: Step): void {
    const s = this.state;
    const usable = fix.hAcc >= 0 && fix.hAcc <= TUNE.rejectAcc;
    const baro = fix.baro !== null;
    const alt = s.alt;

    if (dt <= TUNE.maxGap || dd / dt > TUNE.goSpeed) s.moving += dt;
    if (usable) s.dist += dd;
    s.speed = v * 3.6;
    if (!weak) s.max = Math.max(s.max, s.speed);
    s.altMax = Math.max(s.altMax, alt);

    // Climb with hysteresis, so sensor noise on flat ground adds nothing.
    const hyst = baro ? TUNE.baroClimb : TUNE.gpsClimb;
    if (this.climbRef === null) this.climbRef = alt;
    if (alt - this.climbRef >= hyst) {
      s.climb += alt - this.climbRef;
      this.climbRef = alt;
    } else if (alt < this.climbRef - hyst) {
      this.climbRef = alt;
    }

    // Grade over a distance window, not between two fixes.
    const win = baro ? TUNE.baroWindow : TUNE.gpsWindow;
    this.window.push({ d: s.dist, a: alt });
    while (this.window.length > 2 && this.window[1].d <= s.dist - win) this.window.shift();
    const run = s.dist - this.window[0].d;
    if (run >= win * 0.6) {
      const raw = Math.max(-25, Math.min(25, ((alt - this.window[0].a) / run) * 100));
      s.grade += (raw - s.grade) * 0.3;
    } else {
      s.grade *= 0.8;
    }

    if (s.dist - this.lastSampleD >= TUNE.sampleEvery) {
      this.lastSampleD = s.dist;
      s.samples.push({ d: s.dist, a: alt });
    }
    if (usable) {
      const point: TrackPoint = { t: fix.t, lat: fix.lat, lon: fix.lon, ele: alt };
      s.track[s.track.length - 1].push(point);
    }
  }

  private newSegment(): void {
    const track = this.state.track;
    if (track[track.length - 1].length > 0) track.push([]);
  }

  private snapshot(since: number): Snapshot {
    const s = this.state;
    return {
      since,
      moving: s.moving,
      dist: s.dist,
      climb: s.climb,
      altMax: s.altMax,
      max: s.max,
      samples: s.samples.length,
      trackPts: s.track[s.track.length - 1].length,
      climbRef: this.climbRef,
    };
  }

  private rollback(snap: Snapshot): void {
    const s = this.state;
    s.moving = snap.moving;
    s.dist = snap.dist;
    s.climb = snap.climb;
    s.altMax = snap.altMax;
    s.max = snap.max;
    s.samples.length = Math.min(s.samples.length, Math.max(1, snap.samples));
    s.track[s.track.length - 1].length = Math.min(s.track[s.track.length - 1].length, snap.trackPts);
    this.climbRef = snap.climbRef;
    this.lastSampleD = s.samples.length ? s.samples[s.samples.length - 1].d : 0;
    this.window = [];
  }
}
