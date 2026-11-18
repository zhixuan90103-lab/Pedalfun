/** Home, summary, history and settings screens. */

import {
  deleteRide,
  onSettings,
  rides,
  setSetting,
  settings,
  type Ride,
  type Settings,
} from '../data/store';
import { locationPermission, prepareRide } from '../ride/engine';
import { gpxFileName, hasTrack, toGpx } from '../ride/gpx';
import { shareTextFile } from '../ride/source';
import type { Nav } from './app';
import {
  ICON,
  buzz,
  fmtAlt,
  fmtClock,
  fmtDate,
  fmtDist,
  fmtDur,
  fmtSpeed,
  html,
  profileSvg,
  ref,
  roundBtn,
  toast,
  unit,
  type Screen,
} from './kit';

/* ================= home ================= */

function weekStart(now: Date): Date {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  return d;
}

export function createHome(nav: Nav): Screen {
  const el = html(`
    <section class="screen home">
      <header class="topbar">
        <span class="wordmark">Pedalfun</span>
        <span class="topbar-actions">
          <button type="button" class="icon-btn" data-ref="toHistory" aria-label="骑行记录">${ICON.list}</button>
          <button type="button" class="icon-btn" data-ref="toSettings" aria-label="设置">${ICON.gear}</button>
        </span>
      </header>

      <div class="home-week">
        <span class="cell-label">本周里程</span>
        <div class="home-week-num">
          <span class="num" data-ref="weekDist">0.0</span>
          <span class="home-week-unit" data-ref="weekUnit">km</span>
        </div>
        <p class="home-week-sub" data-ref="weekSub"></p>
        <div class="week-bars" data-ref="bars"></div>
      </div>

      <button type="button" class="last-ride" data-ref="last"></button>

      <div class="home-go">
        ${roundBtn({ ref: 'start', icon: 'play', cls: 'rbtn-go rbtn-xl', label: '开始骑行' })}
        <span class="gps-chip" data-ref="gpsChip" data-perm="prompt"><span data-ref="gpsText">GPS</span><span class="gps" aria-hidden="true"><i></i><i></i><i></i></span></span>
      </div>
    </section>
  `);

  const render = () => {
    const now = new Date();
    const start = weekStart(now);
    const todayIdx = (now.getDay() + 6) % 7;
    const perDay = [0, 0, 0, 0, 0, 0, 0];
    let dist = 0;
    let climb = 0;
    let moving = 0;
    let count = 0;
    for (const r of rides) {
      if (r.date < start) continue;
      perDay[(r.date.getDay() + 6) % 7] += r.dist;
      dist += r.dist;
      climb += r.climb;
      moving += r.moving;
      count += 1;
    }
    ref(el, 'weekDist').textContent = fmtDist(dist, 1);
    ref(el, 'weekUnit').textContent = unit.dist();
    ref(el, 'weekSub').textContent =
      count === 0
        ? '这周还没骑。'
        : `${count} 次骑行，${fmtDur(moving)}，爬升 ${fmtAlt(climb)} ${unit.alt()}`;

    const peak = Math.max(...perDay, 1);
    ref(el, 'bars').innerHTML = ['一', '二', '三', '四', '五', '六', '日']
      .map((label, i) => {
        const pct = perDay[i] > 0 ? Math.max(6, (perDay[i] / peak) * 100) : 0;
        const cls = i === todayIdx ? ' today' : i > todayIdx ? ' future' : '';
        const day = new Date(start);
        day.setDate(start.getDate() + i);
        return `<div class="week-bar${cls}"><span class="week-bar-track"><i style="height:${pct}%;--i:${i}"></i></span><span class="week-bar-label">${label}<b>${day.getDate()}</b></span></div>`;
      })
      .join('');

    const last = rides[0];
    const lastEl = ref(el, 'last');
    lastEl.hidden = !last;
    if (last) {
      lastEl.innerHTML = `
        <span class="last-ride-text">
          <span class="cell-label">上次骑行，${fmtDate(last.date)}</span>
          <span class="last-ride-nums">
            <b class="num">${fmtDist(last.dist, 1)}</b> ${unit.dist()}
            <b class="num">${fmtDur(last.moving)}</b>
          </span>
        </span>
        <span class="last-ride-profile">${profileSvg(last.samples, 120, 40, 30)}</span>`;
    }
  };

  ref(el, 'toHistory').addEventListener('click', () => nav.go('history'));
  ref(el, 'toSettings').addEventListener('click', () => nav.go('settings'));
  ref(el, 'last').addEventListener('click', () => nav.go('summary', { ride: rides[0], live: false, from: 'home' }));
  const refreshGps = () => {
    void locationPermission().then((perm) => {
      ref(el, 'gpsChip').dataset.perm = perm;
      ref(el, 'gpsText').textContent = perm === 'denied' ? '定位未授权' : 'GPS';
    });
  };

  const start = ref(el, 'start');
  let starting = false;
  start.addEventListener('click', async () => {
    if (starting) return;
    starting = true;
    buzz('medium');
    try {
      // Ask for location (first run) before leaving home.
      await prepareRide();
    } catch (err) {
      toast(err instanceof Error ? err.message : '无法开始骑行');
      refreshGps();
      return;
    } finally {
      starting = false;
    }
    // offsetParent is the screen, so these are already design coords.
    nav.go('ride', {
      x: start.offsetLeft + start.offsetWidth / 2,
      y: start.offsetTop + start.offsetHeight / 2,
      r: start.offsetWidth / 2,
    });
  });

  return {
    el,
    enter: () => {
      render();
      refreshGps();
    },
  };
}

/* ================= summary ================= */

export type SummaryParam = { ride: Ride; live: boolean; from?: 'home' | 'history' };

export function createSummary(nav: Nav): Screen {
  const el = html(`
    <section class="screen summary">
      <header class="topbar">
        <button type="button" class="icon-btn" data-ref="back" aria-label="返回">${ICON.back}</button>
        <span class="topbar-title" data-ref="when"></span>
        <span class="icon-btn" aria-hidden="true"></span>
      </header>

      <div class="scroll summary-scroll">
        <p class="summary-name" data-ref="name"></p>
        <div class="summary-dist">
          <span class="num" data-ref="dist"></span>
          <span class="summary-dist-unit" data-ref="distUnit"></span>
        </div>

        <div class="summary-chart">
          <div data-ref="profile"></div>
          <div class="summary-chart-axis">
            <span>0</span>
            <span data-ref="axisEnd"></span>
          </div>
          <div class="legend" aria-label="坡度颜色">
            <span><i class="pf-flat"></i>平路</span>
            <span><i class="pf-down"></i>下坡</span>
            <span><i class="pf-up"></i>上坡</span>
          </div>
        </div>

        <div class="stat-grid" data-ref="grid"></div>
      </div>

      <div class="summary-actions" data-ref="actions"></div>
    </section>
  `);

  let param: SummaryParam | null = null;

  const leaveTo = () => nav.go(param?.from === 'history' ? 'history' : 'home');

  const render = () => {
    if (!param) return;
    const r = param.ride;
    const avg = r.moving > 0 ? (r.dist / r.moving) * 3.6 : 0;
    ref(el, 'when').textContent = `${fmtDate(r.date)} ${fmtClock(r.date)}`;
    ref(el, 'name').textContent = param.live ? `${r.name}，已保存` : r.name;
    ref(el, 'dist').textContent = fmtDist(r.dist);
    ref(el, 'distUnit').textContent = unit.dist();
    ref(el, 'profile').innerHTML = profileSvg(r.samples, 342, 104, 64);
    ref(el, 'axisEnd').textContent = `${fmtDist(r.dist, 1)} ${unit.dist()}`;

    const stats: [string, string, string][] = [
      ['移动时间', fmtDur(r.moving), ''],
      ['总耗时', fmtDur(r.total), ''],
      ['均速', fmtSpeed(avg), unit.speed()],
      ['最高速度', fmtSpeed(r.max), unit.speed()],
      ['爬升', fmtAlt(r.climb), unit.alt()],
      ['最高海拔', fmtAlt(r.altMax), unit.alt()],
    ];
    ref(el, 'grid').innerHTML = stats
      .map(
        ([label, value, u]) =>
          `<div class="cell"><span class="cell-label">${label}</span><span class="stat-value"><b class="num">${value}</b>${u ? ` <em>${u}</em>` : ''}</span></div>`,
      )
      .join('');

    const actions = ref(el, 'actions');
    ref(el, 'back').style.visibility = param.live ? 'hidden' : 'visible';
    if (param.live) {
      // Already saved when the ride ended; this only confirms and returns home.
      actions.innerHTML = roundBtn({ ref: 'done', icon: 'check', cls: 'rbtn-go', label: '确定' });
      ref(actions, 'done').addEventListener('click', () => {
        buzz('medium');
        nav.go('home');
      });
    } else {
      actions.innerHTML = roundBtn({ ref: 'export', icon: 'share', label: '导出 GPX' });
      ref(actions, 'export').addEventListener('click', () => {
        if (!hasTrack(r)) {
          toast('这条记录没有轨迹，无法导出');
          return;
        }
        shareTextFile(gpxFileName(r), toGpx(r), 'application/gpx+xml').catch(() => toast('导出失败'));
      });
    }
  };

  ref(el, 'back').addEventListener('click', leaveTo);
  onSettings(render);

  return {
    el,
    enter: (p) => {
      param = p as SummaryParam;
      el.querySelector('.scroll')!.scrollTop = 0;
      render();
    },
  };
}

/* ================= history ================= */

export function createHistory(nav: Nav): Screen {
  const el = html(`
    <section class="screen history">
      <header class="topbar">
        <button type="button" class="icon-btn" data-ref="back" aria-label="返回">${ICON.back}</button>
        <span class="topbar-title">骑行记录</span>
        <span class="icon-btn" aria-hidden="true"></span>
      </header>
      <div class="scroll" data-ref="list"></div>
    </section>
  `);

  const list = ref(el, 'list');

  const render = () => {
    if (rides.length === 0) {
      list.innerHTML = `<p class="empty">还没有骑行记录。回到首页，点「开始骑行」记下第一条。</p>`;
      return;
    }
    const groups = new Map<string, Ride[]>();
    for (const r of rides) {
      const key = `${r.date.getFullYear()}年${r.date.getMonth() + 1}月`;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(r);
    }
    let out = '';
    for (const [month, items] of groups) {
      const total = items.reduce((s, r) => s + r.dist, 0);
      out += `<div class="month"><span>${month}</span><span>${items.length} 次，<b class="num">${fmtDist(total, 1)}</b> ${unit.dist()}</span></div>`;
      for (const r of items) {
        out += `
          <div class="ride-item" data-id="${r.id}">
            <button type="button" class="ride-del" aria-label="删除这条记录">${ICON.trash}</button>
            <button type="button" class="ride-row">
              <span class="ride-row-main">
                <span class="cell-label">${fmtDate(r.date)}，${r.name}</span>
                <span class="ride-row-nums">
                  <span class="ride-row-dist"><b class="num">${fmtDist(r.dist, 1)}</b> ${unit.dist()}</span>
                  <span><b class="num">${fmtDur(r.moving)}</b></span>
                  <span>↑ <b class="num">${fmtAlt(r.climb)}</b> ${unit.alt()}</span>
                </span>
              </span>
              <span class="ride-row-profile">${profileSvg(r.samples, 84, 36, 24)}</span>
            </button>
          </div>`;
      }
    }
    list.innerHTML = out;
  };

  /* Swipe a row left to reveal delete. Only one row is open at a time. */
  const OPEN = 76;
  let open: HTMLElement | null = null;
  let drag: { item: HTMLElement; row: HTMLElement; x: number; y: number; base: number; scale: number; active: boolean } | null = null;
  let swiped = false;

  const setX = (item: HTMLElement, x: number, animate: boolean) => {
    const row = item.querySelector<HTMLElement>('.ride-row')!;
    row.style.transition = animate ? '' : 'none';
    row.style.transform = x ? `translateX(${x}px)` : '';
    item.classList.toggle('open', x <= -OPEN);
  };
  const close = () => {
    if (open) setX(open, 0, true);
    open = null;
  };

  list.addEventListener('pointerdown', (ev) => {
    const target = ev.target as HTMLElement;
    const item = target.closest<HTMLElement>('.ride-item');
    const row = target.closest<HTMLElement>('.ride-row');
    swiped = false;
    // Pressing the open row's own delete button must not close it first.
    if (open && open !== item) close();
    if (!row || !item) return;
    drag = {
      item,
      row,
      x: ev.clientX,
      y: ev.clientY,
      base: item === open ? -OPEN : 0,
      // The stage is CSS-scaled, so pointer distances are not design pixels.
      scale: row.getBoundingClientRect().width / row.offsetWidth || 1,
      active: false,
    };
  });
  list.addEventListener('pointermove', (ev) => {
    if (!drag) return;
    const dx = (ev.clientX - drag.x) / drag.scale;
    const dy = (ev.clientY - drag.y) / drag.scale;
    if (!drag.active) {
      if (Math.abs(dx) < 8 || Math.abs(dx) < Math.abs(dy)) return;
      drag.active = true;
      swiped = true;
    }
    // Slight resistance past the open position.
    let x = Math.min(0, drag.base + dx);
    if (x < -OPEN) x = -OPEN + (x + OPEN) * 0.25;
    setX(drag.item, x, false);
  });
  const endDrag = (ev: PointerEvent) => {
    if (!drag) return;
    const d = drag;
    drag = null;
    if (!d.active) return;
    const dx = (ev.clientX - d.x) / d.scale;
    if (d.base + dx < -OPEN / 2) {
      setX(d.item, -OPEN, true);
      open = d.item;
    } else {
      setX(d.item, 0, true);
      if (open === d.item) open = null;
    }
  };
  list.addEventListener('pointerup', endDrag);
  list.addEventListener('pointercancel', endDrag);
  list.addEventListener('scroll', close);

  list.addEventListener('click', (ev) => {
    const target = ev.target as HTMLElement;
    const item = target.closest<HTMLElement>('.ride-item');
    if (!item) return;
    const id = item.dataset.id!;
    if (target.closest('.ride-del')) {
      buzz('medium');
      open = null;
      // Collapse the row, then drop it from the list.
      item.style.height = `${item.offsetHeight}px`;
      void item.offsetHeight;
      item.classList.add('removing');
      item.style.height = '0px';
      window.setTimeout(render, 260);
      deleteRide(id).then(
        () => toast('已删除'),
        () => toast('删除没有写入存储，重启后可能还在'),
      );
      return;
    }
    // A swipe, or a tap that just closed an open row, is not a tap on the row.
    if (swiped) return;
    if (open) {
      close();
      return;
    }
    const ride = rides.find((r) => r.id === id);
    if (ride) nav.go('summary', { ride, live: false, from: 'history' });
  });
  ref(el, 'back').addEventListener('click', () => nav.go('home'));
  onSettings(render);

  return {
    el,
    enter: () => {
      open = null;
      render();
    },
  };
}

/* ================= settings ================= */

type SegDef<K extends keyof Settings> = {
  key: K;
  label: string;
  hint?: string;
  options: [Settings[K], string][];
};

function seg<K extends keyof Settings>(def: SegDef<K>): string {
  return `
    <div class="set-row">
      <span class="set-text">
        <span class="set-label">${def.label}</span>
        ${def.hint ? `<span class="set-hint">${def.hint}</span>` : ''}
      </span>
      <span class="seg" role="group" aria-label="${def.label}">
        <i class="seg-thumb"></i>
        ${def.options
          .map(
            ([value, text]) =>
              `<button type="button" data-key="${def.key}" data-value="${String(value)}">${text}</button>`,
          )
          .join('')}
      </span>
    </div>`;
}

function toggle(key: keyof Settings, label: string, hint?: string): string {
  return `
    <div class="set-row">
      <span class="set-text">
        <span class="set-label">${label}</span>
        ${hint ? `<span class="set-hint">${hint}</span>` : ''}
      </span>
      <button type="button" class="switch" role="switch" data-key="${key}" aria-label="${label}"><i></i></button>
    </div>`;
}

export function createSettings(nav: Nav): Screen {
  const el = html(`
    <section class="screen settings">
      <header class="topbar">
        <button type="button" class="icon-btn" data-ref="back" aria-label="返回">${ICON.back}</button>
        <span class="topbar-title">设置</span>
        <span class="icon-btn" aria-hidden="true"></span>
      </header>
      <div class="scroll">
        ${seg({ key: 'units', label: '单位', options: [['km', '公里'], ['mi', '英里']] })}
        ${seg({ key: 'theme', label: '外观', hint: '强光下浅色更清楚', options: [['dark', '深色'], ['light', '浅色'], ['system', '自动']] })}
        ${toggle('autoPause', '自动暂停', '停车时停表，起步后继续')}
        ${toggle('keepAwake', '骑行时屏幕常亮')}
        ${toggle('haptics', '震动反馈', '暂停、继续、结束时震一下')}
        <p class="set-note">只用手机 GPS 记录，不连接心率带、功率计等外设。</p>
      </div>
    </section>
  `);

  const sync = () => {
    el.querySelectorAll<HTMLButtonElement>('.seg button').forEach((b) => {
      const key = b.dataset.key as keyof Settings;
      const on = String(settings[key]) === b.dataset.value;
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', String(on));
      if (on) {
        const group = b.parentElement!;
        group.style.setProperty('--thumb-x', `${b.offsetLeft}px`);
        group.style.setProperty('--thumb-w', `${b.offsetWidth}px`);
      }
    });
    el.querySelectorAll<HTMLButtonElement>('.switch').forEach((b) => {
      b.setAttribute('aria-checked', String(settings[b.dataset.key as keyof Settings] === true));
    });
  };

  el.addEventListener('click', (ev) => {
    const target = ev.target as HTMLElement;
    const sw = target.closest<HTMLButtonElement>('.switch');
    if (sw) {
      const key = sw.dataset.key as keyof Settings;
      setSetting(key, !settings[key] as never);
      buzz('light');
      return;
    }
    const b = target.closest<HTMLButtonElement>('.seg button');
    if (!b) return;
    setSetting(b.dataset.key as keyof Settings, b.dataset.value as never);
  });
  ref(el, 'back').addEventListener('click', () => nav.go('home'));
  onSettings(sync);

  return {
    el,
    enter: () => {
      // First layout: place thumbs without sliding in from the edge.
      el.classList.remove('ready');
      sync();
      requestAnimationFrame(() => el.classList.add('ready'));
    },
  };
}
