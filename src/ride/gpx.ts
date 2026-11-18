/** GPX 1.1 export of a recorded ride. */

import type { Ride } from '../data/store';

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export function hasTrack(ride: Ride): boolean {
  return !!ride.track && ride.track.some((seg) => seg.length > 1);
}

export function toGpx(ride: Ride): string {
  const segs = (ride.track ?? [])
    .filter((seg) => seg.length > 1)
    .map(
      (seg) =>
        `    <trkseg>\n${seg
          .map(
            (p) =>
              `      <trkpt lat="${p.lat.toFixed(7)}" lon="${p.lon.toFixed(7)}"><ele>${p.ele.toFixed(1)}</ele><time>${new Date(p.t).toISOString()}</time></trkpt>`,
          )
          .join('\n')}\n    </trkseg>`,
    )
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Pedalfun" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><time>${ride.date.toISOString()}</time></metadata>
  <trk>
    <name>${esc(ride.name)}</name>
    <type>cycling</type>
${segs}
  </trk>
</gpx>
`;
}

export function gpxFileName(ride: Ride): string {
  const d = ride.date;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `pedalfun-${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}.gpx`;
}
