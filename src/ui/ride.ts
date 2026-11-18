/**
 * Riding screen. Positions never move; state only changes emphasis:
 * hero field colour (moving / auto-paused / paused), the grade capsule
 * (red uphill / green downhill), and the bottom buttons.
 */

import { RideSim } from '../data/sim';
import { addRide, rideName, type Ride } from '../data/store';
import { setRideAwake, takeEngine } from '../ride/engine';
import type { RideEngine, RideState } from '../ride/types';
import type { Nav } from './app';
import {
  buzz,
  fmtAlt,
  fmtDist,
  fmtDur,
  fmtGrade,
  fmtSpeed,
  gradeBand,
  holdButton,
  html,
  profileSvg,
  ref,
  roundBtn,
  toast,
  unit,
  type Screen,
} from './kit';

let sim: RideEngine | null = null;

/** The simulated ride, when one is running (drives the desktop demo panel). */
export function currentSim(): RideSim | null {
  return sim instanceof RideSim ? sim : null;
}

function toRide(s: RideState): Ride {
  return {
    id: `ride-${s.startedAt.getTime()}`,
    date: s.startedAt,
    name: rideName(s.startedAt),
    dist: s.dist,
    moving: s.moving,
    total: s.total,
    max: s.max,
    climb: s.climb,
    altMax: s.altMax,
    samples: s.samples.slice(),
    track: s.track.some((seg) => seg.length > 1) ? s.track : undefined,
  };
}

export function createRide(nav: Nav): Screen {
  const el = html(`
    <section class="screen ride" data-status="moving" data-gps="good" data-band="flat">
      <div class="ride-hero">
        <div class="ride-status">
          <span class="gps" aria-hidden="true"><i></i><i></i><i></i></span>
          <span data-ref="statusText">记录中</span>
        </div>
        <div class="ride-speed">
          <span class="num" data-ref="speed">0.0</span>
          <span class="ride-speed-unit" data-ref="speedUnit">km/h</span>
        </div>
      </div>

      <div class="ride-body">
        <div class="cell cell-wide">
          <span class="cell-label" data-ref="timeLabel">时间</span>
          <span class="num cell-big" data-ref="time">0:00:00</span>
        </div>
        <div class="cell cell-wide">
          <span class="cell-label">里程 <em data-ref="distUnit">km</em></span>
          <span class="num cell-big" data-ref="dist">0.00</span>
        </div>

        <i class="ride-rule"></i>

        <div class="cell">
          <span class="cell-label">均速</span>
          <span class="num cell-small" data-ref="avg">0.0</span>
        </div>
        <div class="cell ride-max" data-ref="maxWrap">
          <span class="cell-label">最高</span>
          <span class="num cell-small" data-ref="max">0.0</span>
        </div>
        <div class="cell">
          <span class="cell-label">爬升 <em data-ref="climbUnit">m</em></span>
          <span class="num cell-small" data-ref="climb">0</span>
        </div>
        <div class="cell">
          <span class="cell-label">海拔 <em data-ref="altUnit">m</em></span>
          <span class="num cell-small" data-ref="alt">0</span>
        </div>

        <i class="ride-rule"></i>

        <div class="cell cell-grade">
          <span class="cell-label" data-ref="gradeLabel">坡度 %</span>
          <span class="num cell-mid" data-ref="grade">0.0</span>
        </div>
        <div class="ride-profile" data-ref="profile"></div>
      </div>

      <div class="ride-actions">
        ${roundBtn({ ref: 'resume', icon: 'play', cls: 'rbtn-go ride-act-resume', label: '继续' })}
        ${roundBtn({ ref: 'pause', icon: 'pause', cls: 'rbtn-go ride-act-pause', label: '暂停' })}
        ${roundBtn({ ref: 'end', icon: 'stop', cls: 'rbtn-stop ride-act-end', label: '结束骑行，长按', hold: true })}
      </div>
    </section>
  `);

  const $ = {
    statusText: ref(el, 'statusText'),
    speed: ref(el, 'speed'),
    speedUnit: ref(el, 'speedUnit'),
    timeLabel: ref(el, 'timeLabel'),
    time: ref(el, 'time'),
    dist: ref(el, 'dist'),
    distUnit: ref(el, 'distUnit'),
    avg: ref(el, 'avg'),
    climb: ref(el, 'climb'),
    climbUnit: ref(el, 'climbUnit'),
    gradeLabel: ref(el, 'gradeLabel'),
    grade: ref(el, 'grade'),
    alt: ref(el, 'alt'),
    altUnit: ref(el, 'altUnit'),
    max: ref(el, 'max'),
    maxWrap: ref(el, 'maxWrap'),
    profile: ref(el, 'profile'),
  };
  const gradeCell = el.querySelector<HTMLElement>('.cell-grade')!;
  const pauseBtn = ref(el, 'pause');

  let lastStatus = '';
  let lastMax = 0;
  let lastSamples = -1;
  let lastBand = 'flat';

  const render = () => {
    if (!sim) return;
    const s = sim.state;
    const weak = s.gps === 'weak' && s.status === 'moving';
    const band = s.status === 'moving' ? gradeBand(s.grade) : 'flat';

    el.dataset.status = s.status;
    el.dataset.gps = s.gps;
    el.dataset.band = band;
    if (band !== lastBand) {
      // Pop only when the chip appears, not on every colour step.
      if (lastBand === 'flat') {
        gradeCell.classList.remove('pop');
        void gradeCell.offsetWidth;
        gradeCell.classList.add('pop');
      }
      lastBand = band;
    }

    $.statusText.textContent =
      s.status === 'paused'
        ? '已暂停'
        : s.status === 'autoPaused'
          ? '自动暂停，起步后继续'
          : weak
            ? 'GPS 信号弱，速度暂不可用'
            : '记录中';

    $.speed.textContent = weak ? '--' : fmtSpeed(s.speed);
    $.speedUnit.textContent = unit.speed();
    $.timeLabel.textContent = s.status === 'moving' ? '时间' : '时间（已停表）';
    $.time.textContent = fmtDur(s.moving);
    $.dist.textContent = fmtDist(s.dist);
    $.distUnit.textContent = unit.dist();
    $.avg.textContent = fmtSpeed(s.moving > 0 ? (s.dist / s.moving) * 3.6 : 0);
    $.climb.textContent = fmtAlt(s.climb);
    $.climbUnit.textContent = unit.alt();
    $.gradeLabel.textContent = band === 'flat' ? '坡度 %' : band === 'down' ? '下坡 %' : '上坡 %';
    $.grade.textContent = s.status === 'moving' ? fmtGrade(s.grade) : '0.0';
    $.alt.textContent = fmtAlt(s.alt);
    $.altUnit.textContent = unit.alt();
    $.max.textContent = fmtSpeed(s.max);

    // New top speed: one short highlight, only once the ride is under way.
    if (s.max > lastMax + 0.05 && s.moving > 45) {
      $.maxWrap.classList.remove('flash');
      void $.maxWrap.offsetWidth;
      $.maxWrap.classList.add('flash');
    }
    lastMax = s.max;

    if (s.samples.length !== lastSamples) {
      lastSamples = s.samples.length;
      $.profile.innerHTML = profileSvg(s.samples, 254, 50, 40);
    }

    if (lastStatus && lastStatus !== s.status) {
      // Play the merge only when coming back from a manual pause, never on entry.
      if (lastStatus === 'paused') {
        pauseBtn.classList.remove('merge');
        void pauseBtn.offsetWidth;
        pauseBtn.classList.add('merge');
      }
      if (s.status === 'autoPaused') buzz('light');
      else if (s.status === 'moving' && lastStatus === 'autoPaused') buzz('medium');
    }
    lastStatus = s.status;
  };

  ref(el, 'pause').addEventListener('click', () => {
    buzz('medium');
    sim?.pause();
  });
  ref(el, 'resume').addEventListener('click', () => {
    buzz('medium');
    sim?.resume();
  });
  pauseBtn.addEventListener('animationend', () => pauseBtn.classList.remove('entering', 'merge'));

  holdButton(
    ref(el, 'end'),
    () => {
      if (!sim) return;
      const ride = toRide(sim.state);
      sim.stop();
      sim = null;
      // Finished rides are saved straight away; unwanted ones are deleted from the history list.
      addRide(ride).catch(() => toast('没能写入存储，这次骑行只保留到关闭应用为止'));
      nav.go('summary', { ride, live: true });
    },
    () => toast('长按结束骑行'),
  );

  return {
    el,
    enter: () => {
      sim?.stop();
      sim = takeEngine();
      setRideAwake(true);
      lastStatus = '';
      lastMax = 0;
      lastSamples = -1;
      lastBand = 'flat';
      // Entrance: set before the screen is shown, so the button is never
      // painted at full size first and then animated.
      pauseBtn.classList.remove('merge', 'entering');
      void pauseBtn.offsetWidth;
      pauseBtn.classList.add('entering');
      sim.start(render);
    },
    leave: () => {
      sim?.stop();
      sim = null;
      setRideAwake(false);
    },
  };
}
