/**
 * Settings (localStorage) and ride history (IndexedDB, including the full
 * track of each ride). In the browser's simulated mode a few mock rides are
 * appended so the history screens have something to show.
 */

import type { Sample, TrackPoint } from '../ride/types';

export type Units = 'km' | 'mi';
export type ThemePref = 'light' | 'dark' | 'system';

export type Settings = {
  units: Units;
  autoPause: boolean;
  theme: ThemePref;
  keepAwake: boolean;
  haptics: boolean;
};

export type Ride = {
  id: string;
  date: Date;
  name: string;
  /** metres */
  dist: number;
  /** seconds */
  moving: number;
  total: number;
  /** km/h */
  max: number;
  /** metres */
  climb: number;
  altMax: number;
  samples: Sample[];
  /** absent on simulated / mock rides */
  track?: TrackPoint[][];
};

const KEY = 'pedalfun.settings';

const DEFAULTS: Settings = {
  units: 'km',
  autoPause: true,
  theme: 'dark',
  keepAwake: true,
  haptics: true,
};

function load(): Settings {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...DEFAULTS, ...(JSON.parse(raw) as Partial<Settings>) };
  } catch {
    /* ignore */
  }
  return { ...DEFAULTS };
}

export const settings: Settings = load();

const listeners = new Set<() => void>();

export function onSettings(fn: () => void): void {
  listeners.add(fn);
}

export function setSetting<K extends keyof Settings>(key: K, value: Settings[K]): void {
  settings[key] = value;
  try {
    localStorage.setItem(KEY, JSON.stringify(settings));
  } catch {
    /* ignore */
  }
  listeners.forEach((fn) => fn());
}

export function mulberry(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function rideName(date: Date): string {
  const h = date.getHours();
  if (h < 5) return '夜骑';
  if (h < 11) return '晨间骑行';
  if (h < 14) return '午间骑行';
  if (h < 18) return '午后骑行';
  return '夜骑';
}

function mockRide(seed: number, daysAgo: number, hour: number, km: number, hilly: number): Ride {
  const rnd = mulberry(seed);
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  date.setHours(hour, Math.floor(rnd() * 60), 0, 0);

  const n = 90;
  const samples: Sample[] = [];
  const base = 20 + rnd() * 120;
  const p1 = rnd() * 6;
  const p2 = rnd() * 6;
  let climb = 0;
  let altMax = -Infinity;
  let prev = 0;
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    // Amplitude scales with length so slopes stay in a realistic 0–8% range.
    const a =
      base +
      hilly * km * (1.2 * Math.sin(t * Math.PI) + 2.2 * Math.sin(t * 9 + p1) + Math.sin(t * 23 + p2) + 3.2);
    if (i > 0 && a > prev) climb += a - prev;
    prev = a;
    altMax = Math.max(altMax, a);
    samples.push({ d: t * km * 1000, a });
  }
  const avg = 26 - hilly * 4 + rnd() * 3;
  const moving = Math.round((km / avg) * 3600);
  return {
    id: `mock-${seed}`,
    date,
    name: rideName(date),
    dist: km * 1000,
    moving,
    total: moving + Math.round(240 + rnd() * 900),
    max: 44 + hilly * 9 + rnd() * 6,
    climb,
    altMax,
    samples,
  };
}

export const rides: Ride[] = [];

const MOCK = (): Ride[] => [
  mockRide(11, 1, 18, 31.6, 0.6),
  mockRide(12, 2, 7, 36.8, 1.1),
  mockRide(13, 5, 15, 62.3, 1.6),
  mockRide(14, 8, 7, 24.1, 0.4),
  mockRide(15, 11, 19, 18.7, 0.3),
  mockRide(16, 15, 9, 84.5, 2.0),
  mockRide(17, 22, 16, 40.2, 0.9),
  mockRide(18, 29, 7, 28.4, 0.7),
  mockRide(19, 36, 10, 102.6, 1.8),
];

/* ---------- IndexedDB ---------- */

const DB_NAME = 'pedalfun';
const STORE = 'rides';

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: 'id' });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function tx<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  return openDb().then(
    (db) =>
      new Promise<T>((resolve, reject) => {
        const t = db.transaction(STORE, mode);
        const req = run(t.objectStore(STORE));
        t.oncomplete = () => {
          db.close();
          resolve(req.result);
        };
        t.onerror = () => {
          db.close();
          reject(t.error);
        };
        t.onabort = () => {
          db.close();
          reject(t.error);
        };
      }),
  );
}

/** Load saved rides, newest first. `withMock` appends demo rides (browser sim only). */
export async function loadRides(withMock: boolean): Promise<void> {
  let saved: Ride[] = [];
  try {
    saved = await tx<Ride[]>('readonly', (s) => s.getAll());
  } catch (err) {
    console.warn('[store] could not read rides', err);
  }
  saved.sort((a, b) => b.date.getTime() - a.date.getTime());
  rides.length = 0;
  rides.push(...saved, ...(withMock ? MOCK() : []));
}

/** Removes from the in-memory list at once; resolves when it is gone from disk. */
export async function deleteRide(id: string): Promise<void> {
  const i = rides.findIndex((r) => r.id === id);
  if (i >= 0) rides.splice(i, 1);
  await tx('readwrite', (s) => s.delete(id));
}

/** Adds to the in-memory list at once; resolves when it is on disk. */
export async function addRide(ride: Ride): Promise<void> {
  rides.unshift(ride);
  await tx('readwrite', (s) => s.put(ride));
}
