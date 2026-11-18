/**
 * Where fixes come from.
 * - iOS app: RideTracker native plugin (plugins/native-ride). It keeps
 *   recording into a native buffer while the web view is suspended (locked
 *   screen / background); JS drains that buffer about once a second.
 * - Browser: navigator.geolocation, for development only (no background,
 *   no barometer, no accelerometer).
 */

import { Capacitor, registerPlugin } from '@capacitor/core';
import type { Fix } from './types';

export type Permission = 'granted' | 'prompt' | 'denied';

type NativeFix = Fix & { seq: number };

type RideTrackerPlugin = {
  permission(): Promise<{ state: Permission }>;
  start(): Promise<void>;
  stop(): Promise<void>;
  drain(opts: { after: number }): Promise<{ fixes: NativeFix[] }>;
  shareFile(opts: { name: string; text: string }): Promise<void>;
};

const RideTrackerNative = registerPlugin<RideTrackerPlugin>('RideTracker');

export const isNativeRide = (): boolean =>
  Capacitor.isNativePlatform() && Capacitor.isPluginAvailable('RideTracker');

export interface FixSource {
  permission(): Promise<Permission>;
  /** Rejects with a user-facing message when location cannot be used. */
  start(): Promise<void>;
  stop(): void;
  drain(): Promise<Fix[]>;
}

const DENIED = '没有定位权限。请到 设置 > 隐私与安全性 > 定位服务 里允许本应用使用定位。';

class NativeSource implements FixSource {
  private lastSeq = 0;

  async permission(): Promise<Permission> {
    return (await RideTrackerNative.permission()).state;
  }

  async start(): Promise<void> {
    this.lastSeq = 0;
    try {
      await RideTrackerNative.start();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      throw new Error(msg.includes('denied') ? DENIED : `无法开始定位：${msg}`);
    }
  }

  stop(): void {
    void RideTrackerNative.stop();
  }

  async drain(): Promise<Fix[]> {
    const { fixes } = await RideTrackerNative.drain({ after: this.lastSeq });
    if (fixes.length) this.lastSeq = fixes[fixes.length - 1].seq;
    return fixes;
  }
}

class WebSource implements FixSource {
  private watch: number | null = null;
  private queue: Fix[] = [];

  async permission(): Promise<Permission> {
    if (!('geolocation' in navigator)) return 'denied';
    try {
      const status = await navigator.permissions.query({ name: 'geolocation' });
      return status.state;
    } catch {
      return 'prompt';
    }
  }

  start(): Promise<void> {
    this.stop();
    this.queue = [];
    if (!('geolocation' in navigator)) {
      return Promise.reject(new Error('这个浏览器不支持定位。'));
    }
    return new Promise((resolve, reject) => {
      let settled = false;
      const ok = () => {
        if (!settled) {
          settled = true;
          resolve();
        }
      };
      // Don't hold the UI for a slow first fix; only a refusal blocks.
      const timer = window.setTimeout(ok, 2500);
      this.watch = navigator.geolocation.watchPosition(
        (pos) => {
          const c = pos.coords;
          this.queue.push({
            t: pos.timestamp,
            lat: c.latitude,
            lon: c.longitude,
            speed: c.speed,
            hAcc: c.accuracy,
            alt: c.altitude,
            vAcc: c.altitudeAccuracy,
            baro: null,
            motion: null,
          });
          ok();
        },
        (err) => {
          if (err.code === err.PERMISSION_DENIED && !settled) {
            settled = true;
            window.clearTimeout(timer);
            this.stop();
            reject(new Error(DENIED));
          }
        },
        { enableHighAccuracy: true, maximumAge: 0 },
      );
    });
  }

  stop(): void {
    if (this.watch !== null) navigator.geolocation.clearWatch(this.watch);
    this.watch = null;
  }

  async drain(): Promise<Fix[]> {
    const out = this.queue;
    this.queue = [];
    return out;
  }
}

export function createSource(): FixSource {
  return isNativeRide() ? new NativeSource() : new WebSource();
}

/** Hand a text file to the system share sheet (iOS) or download it (browser). */
export async function shareTextFile(name: string, text: string, mime: string): Promise<void> {
  if (isNativeRide()) {
    await RideTrackerNative.shareFile({ name, text });
    return;
  }
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 2000);
}
