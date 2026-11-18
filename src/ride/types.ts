/** Shared ride types. No imports with side effects: tracker.ts must stay pure. */

/** One location sample from the device (native plugin or browser geolocation). */
export type Fix = {
  /** epoch ms */
  t: number;
  lat: number;
  lon: number;
  /** m/s from the receiver (Doppler); null or negative = unavailable */
  speed: number | null;
  /** horizontal accuracy in metres; negative = invalid */
  hAcc: number;
  /** GPS altitude in metres */
  alt: number | null;
  vAcc: number | null;
  /** barometric altitude relative to recording start, metres (iOS only) */
  baro: number | null;
  /** recent accelerometer vibration level in g (iOS only); ~0 when the phone is still */
  motion: number | null;
};

export type TrackPoint = { t: number; lat: number; lon: number; ele: number };

export type Sample = { d: number; a: number };

export type RideStatus = 'moving' | 'autoPaused' | 'paused';

export type RideState = {
  status: RideStatus;
  gps: 'good' | 'weak';
  startedAt: Date;
  /** seconds */
  moving: number;
  total: number;
  /** metres */
  dist: number;
  /** km/h */
  speed: number;
  max: number;
  /** metres */
  alt: number;
  altMax: number;
  climb: number;
  /** percent */
  grade: number;
  /** distance / altitude pairs for the elevation profile */
  samples: Sample[];
  /** recorded path, one array per continuous segment (split at pauses) */
  track: TrackPoint[][];
};

export interface RideEngine {
  state: RideState;
  /** Acquire what the ride needs (location permission, sensors). Rejects with a user-facing message. */
  prepare(): Promise<void>;
  start(onTick: () => void): void;
  stop(): void;
  pause(): void;
  resume(): void;
}
