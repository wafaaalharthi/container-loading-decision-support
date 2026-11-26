'use strict';
/* ============================================================
   model.js — containers, SH-102 demo data, IDs, input checks,
   recorded engine results and the ILLUSTRATIVE placement routine.
   Units: UI in cm, layout in mm. x = length (back wall x=0, door x=L),
   y = width, z = height.
   ============================================================ */

const CONTAINERS = {
  '20GP': { code: '20GP', L: 5900, W: 2352, H: 2395, doorW: 2340, doorH: 2292, payload: 28130 },
  '40GP': { code: '40GP', L: 12032, W: 2352, H: 2395, doorW: 2340, doorH: 2292, payload: 28750 },
  '40HC': { code: '40HC', L: 12032, W: 2350, H: 2700, doorW: 2340, doorH: 2597, payload: 28600 }
};
const CONTAINER_ORDER = ['20GP', '40GP', '40HC'];
const containerVolume = c => (c.L * c.W * c.H) / 1e9; // m3

const KINDS = ['electronics', 'glass', 'iron_metal', 'machinery', 'wood_furniture', 'food', 'textiles', 'paper', 'other'];
const GROUP_COLORS = ['#498BFF', '#FF9D55', '#50E5AA', '#FFD25E', '#FF71B3', '#AF79FF', '#4FD6E8', '#FF7A7A', '#A6E05A', '#F2A6FF', '#8FB0FF', '#FFB86B'];

const DEMO = {
  code: 'SH-102',
  groups: [
    { code: 'B01', kind: 'electronics', custom: '', contents: 'Electronic devices', l: 80, w: 60, h: 55, kg: 24, qty: 24, priority: 1, orientation: 'upright', fragile: true, floorOnly: false, stackable: false, stacking: 'any', loadBearing: null, color: '#498BFF' },
    { code: 'B02', kind: 'machinery', custom: '', contents: 'Equipment', l: 100, w: 75, h: 80, kg: 95, qty: 24, priority: 3, orientation: 'upright', fragile: false, floorOnly: false, stackable: true, stacking: 'any', loadBearing: null, color: '#FF9D55' },
    { code: 'B03', kind: 'other', custom: '', contents: 'Supplies', l: 60, w: 50, h: 60, kg: 30, qty: 50, priority: 2, orientation: 'any', fragile: false, floorOnly: false, stackable: true, stacking: 'any', loadBearing: null, color: '#50E5AA' },
    { code: 'B04', kind: 'machinery', custom: '', contents: 'Machine part', l: 150, w: 110, h: 90, kg: 650, qty: 2, priority: 3, orientation: 'upright', fragile: false, floorOnly: true, stackable: false, stacking: 'any', loadBearing: null, color: '#FFD25E' },
    { code: 'B05', kind: 'iron_metal', custom: '', contents: 'Pipe crate', l: 640, w: 60, h: 60, kg: 180, qty: 1, priority: 2, orientation: 'any', fragile: false, floorOnly: false, stackable: true, stacking: 'any', loadBearing: null, color: '#FF71B3' },
    { code: 'B06', kind: 'paper', custom: '', contents: 'Documents', l: 40, w: 30, h: 30, kg: 8, qty: 20, priority: 1, orientation: 'any', fragile: false, floorOnly: false, stackable: true, stacking: 'any', loadBearing: null, color: '#AF79FF' }
  ]
};

/* Recorded aggregate results of the Dart engine (unmodified SH-102 in a 20GP).
   These are replayed, never recomputed. */
const RECORDED = (typeof ENGINE_SH102 !== 'undefined') ? {
  instant: ENGINE_SH102.instant, optimized: ENGINE_SH102.optimized, wall: ENGINE_SH102.wall
} : {};
const VALIDATOR_CHECKS = ['C1', 'C2', 'C3', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6'];

function physSig(code, groups) {
  return String(code) + '|' + groups.map(g => [g.kind, +g.l, +g.w, +g.h, +g.kg, +g.qty, +g.priority, g.orientation,
    !!g.fragile, !!g.floorOnly, !!g.stackable, g.stackable ? g.stacking : '-', g.stackable && g.loadBearing ? +g.loadBearing : 0].join(',')).join(';');
}
const DEMO_SIG = physSig(DEMO.code, DEMO.groups);
function isDemoInventory(ship) { return physSig(ship.code, ship.groups) === DEMO_SIG; }
function recordedRun(ship, contCode, mode) {
  if (contCode !== '20GP' || !isDemoInventory(ship)) return null;
  return RECORDED[mode] || null;
}

/* ---------- IDs ---------- */
const idPrefix = code => String(code || 'SH').replace(/[^A-Za-z0-9]/g, '').toUpperCase() || 'SH';
const pad2 = n => String(n).padStart(2, '0');
const boxId = (shipCode, gcode, i) => `${idPrefix(shipCode)}-${gcode}-${pad2(i)}`;
function nextGroupCode(ship) { return 'B' + pad2(ship.nextSeq || (ship.groups.length + 1)); }
function expandBoxes(ship) {
  const out = [];
  ship.groups.forEach((g, gi) => {
    const q = Math.max(0, Math.floor(+g.qty || 0));
    for (let i = 1; i <= q; i++) out.push({ id: boxId(ship.code, g.code, i), g, gi, idx: i, added: (g.addedAt || 0) + i });
  });
  return out;
}
function splitId(id) { const k = id.indexOf('-'); return k < 0 ? [id, ''] : [id.slice(0, k + 1), id.slice(k + 1)]; }

/* ---------- Group validation ---------- */
function num(v) { if (v === '' || v === null || v === undefined) return NaN; return Number(v); }
function groupErrors(g) {
  const e = {};
  if (!KINDS.includes(g.kind)) e.kind = 'errKind';
  for (const f of ['l', 'w', 'h']) { const v = num(g[f]); if (!isFinite(v)) e[f] = 'errRequired'; else if (v <= 0) e[f] = 'errPositive'; else if (v > 5000) e[f] = 'errTooLarge'; }
  const kg = num(g.kg); if (!isFinite(kg)) e.kg = 'errRequired'; else if (kg <= 0) e.kg = 'errPositive';
  const q = num(g.qty); if (!isFinite(q)) e.qty = 'errRequired'; else if (q < 1 || !Number.isInteger(q)) e.qty = 'errWhole'; else if (q > 999) e.qty = 'errTooLarge';
  const p = num(g.priority); if (!Number.isInteger(p) || p < 1 || p > 9) e.priority = 'errPriority';
  if (!['any', 'upright'].includes(g.orientation)) e.orientation = 'errOrientation';
  if (g.fragile && g.stackable) e.stackable = 'errFragileStack';
  if (g.stackable && !['any', 'same', 'other'].includes(g.stacking)) e.stacking = 'errStacking';
  if (g.stackable && g.loadBearing !== null && g.loadBearing !== '' && g.loadBearing !== undefined) {
    const lb = num(g.loadBearing); if (!isFinite(lb) || lb <= 0) e.loadBearing = 'errPositive';
  }
  return e;
}
function orientations(g) {
  const l = +g.l * 10, w = +g.w * 10, h = +g.h * 10;
  const raw = g.orientation === 'upright' ? [[l, w, h], [w, l, h]] : [[l, w, h], [w, l, h], [l, h, w], [h, l, w], [w, h, l], [h, w, l]];
  const seen = new Set(); const out = [];
  for (const o of raw) { const k = o.join('x'); if (!seen.has(k)) { seen.add(k); out.push(o); } }
  return out;
}
function fitOrientations(g, c) {
  return orientations(g).filter(o => o[0] <= c.L && o[1] <= c.W && o[2] <= c.H && o[1] <= c.doorW && o[2] <= c.doorH);
}
/* Input status of a group in a container: accepted / rejected (+reason) */
function inputStatus(g, c) {
  if (Object.keys(groupErrors(g)).length) return { status: 'rejected', reason: 'invalidData' };
  if (+g.kg > c.payload) return { status: 'rejected', reason: 'overweight' };
  if (!fitOrientations(g, c).length) return { status: 'rejected', reason: 'noOrientation' };
  return { status: 'accepted', reason: null };
}
function shipmentTotals(ship) {
  let boxes = 0, kg = 0, vol = 0;
  for (const g of ship.groups) { const q = Math.max(0, Math.floor(+g.qty || 0)); boxes += q; kg += q * (+g.kg || 0); vol += q * (+g.l * +g.w * +g.h || 0) / 1e6; }
  return { boxes, kg, vol, groups: ship.groups.length };
}
const groupVolume = g => (+g.l * +g.w * +g.h) / 1e6; // m3 per box

/* ============================================================
   Illustrative placement routine (NOT the Dart engine).
   Extreme-point heuristic with allowed orientations, door fit,
   collision-free positions, floor or 100 % support, floor-only,
   fragile / stacking permissions, payload and load-bearing limits.
   ============================================================ */
const EPS = 0.5;
function allowsOnTop(sup, top) {
  if (!sup.stackable || sup.fragile) return false;
  if (sup.stacking === 'same') return sup.code === top.code;
  if (sup.stacking === 'other') return sup.code !== top.code;
  return true;
}
function runPack(items, c, bestOrient) {
  const placed = []; let eps = [[0, 0, 0]]; let kg = 0; const res = {};
  for (const it of items) {
    const g = it.g, w = +g.kg;
    if (kg + w > c.payload + 1e-9) { res[it.id] = { status: 'unplaced', reason: 'payload' }; continue; }
    let ors = fitOrientations(g, c);
    if (bestOrient) ors = ors.slice().sort((a, b) => a[0] - b[0] || b[1] - a[1] || a[2] - b[2]);
    eps.sort((a, b) => a[0] - b[0] || a[2] - b[2] || a[1] - b[1]);
    let found = null;
    outer: for (const p of eps) {
      if (g.floorOnly && p[2] > EPS) continue;
      for (const o of ors) {
        const cand = tryPlace(p, o, g, w, placed, c);
        if (cand) { found = cand; break outer; }
      }
    }
    if (!found) { res[it.id] = { status: 'unplaced', reason: 'noPosition' }; continue; }
    // commit
    for (const [e, a] of found.inc) e.load += a;
    const entry = { id: it.id, g, gcode: g.code, x0: found.x0, y0: found.y0, z0: found.z0, x1: found.x1, y1: found.y1, z1: found.z1, kg: w, load: 0, sups: found.sups, seq: placed.length };
    entry.layer = found.z0 < EPS ? 1 : 1 + Math.max(...found.sups.map(s => s.p.layer));
    placed.push(entry); kg += w;
    eps = eps.filter(p => !(p[0] >= entry.x0 - EPS && p[0] < entry.x1 - EPS && p[1] >= entry.y0 - EPS && p[1] < entry.y1 - EPS && p[2] >= entry.z0 - EPS && p[2] < entry.z1 - EPS));
    const add = [[entry.x1, entry.y0, entry.z0], [entry.x0, entry.y1, entry.z0], [entry.x0, entry.y0, entry.z1]];
    for (const p of add) {
      if (p[0] >= c.L - EPS || p[1] >= c.W - EPS || p[2] >= c.H - EPS) continue;
      if (placed.some(q => p[0] >= q.x0 - EPS && p[0] < q.x1 - EPS && p[1] >= q.y0 - EPS && p[1] < q.y1 - EPS && p[2] >= q.z0 - EPS && p[2] < q.z1 - EPS)) continue;
      if (!eps.some(e => Math.abs(e[0] - p[0]) < EPS && Math.abs(e[1] - p[1]) < EPS && Math.abs(e[2] - p[2]) < EPS)) eps.push(p);
    }
    res[it.id] = { status: 'loaded' };
  }
  return { placed, res, kg };
}
function tryPlace(p, o, g, w, placed, c) {
  const x0 = p[0], y0 = p[1], z0 = p[2], x1 = x0 + o[0], y1 = y0 + o[1], z1 = z0 + o[2];
  if (x1 > c.L + EPS || y1 > c.W + EPS || z1 > c.H + EPS) return null;
  for (const q of placed) {
    if (x0 < q.x1 - EPS && x1 > q.x0 + EPS && y0 < q.y1 - EPS && y1 > q.y0 + EPS && z0 < q.z1 - EPS && z1 > q.z0 + EPS) return null;
  }
  const sups = []; const inc = new Map();
  if (z0 > EPS) {
    const area = o[0] * o[1]; let sum = 0;
    for (const q of placed) {
      if (Math.abs(q.z1 - z0) > EPS) continue;
      const ox = Math.min(x1, q.x1) - Math.max(x0, q.x0), oy = Math.min(y1, q.y1) - Math.max(y0, q.y0);
      if (ox <= EPS || oy <= EPS) continue;
      if (!allowsOnTop(q.g, g)) return null;
      sups.push({ p: q, a: ox * oy }); sum += ox * oy;
    }
    if (sum < area * 0.999) return null; // B3 full support
    for (const s of sups) s.share = s.a / sum;
    const addLoad = (e, amt) => { inc.set(e, (inc.get(e) || 0) + amt); for (const s of e.sups) addLoad(s.p, amt * s.share); };
    for (const s of sups) addLoad(s.p, w * s.share);
    for (const [e, a] of inc) {
      const lim = e.g.stackable && e.g.loadBearing ? +e.g.loadBearing : Infinity;
      if (e.load + a > lim + 1e-9) return null; // B6
    }
  }
  return { x0, y0, z0, x1, y1, z1, sups, inc };
}
function loadingOrder(placed) {
  const rest = placed.slice().sort((a, b) => a.x0 - b.x0 || a.z0 - b.z0 || a.y0 - b.y0);
  const done = new Set(); const out = [];
  while (rest.length) {
    let k = rest.findIndex(e => e.sups.every(s => done.has(s.p)));
    if (k < 0) k = 0;
    const e = rest.splice(k, 1)[0]; done.add(e); out.push(e);
  }
  out.forEach((e, i) => { e.order = i + 1; });
  return out;
}
const ORDERINGS = {
  a: (A, B) => (B.g.floorOnly - A.g.floorOnly) || (B.g.priority - A.g.priority) || (groupVolume(B.g) - groupVolume(A.g)) || (A.id < B.id ? -1 : 1),
  b: (A, B) => (B.g.floorOnly - A.g.floorOnly) || (Math.max(B.g.l * B.g.w, 0) - Math.max(A.g.l * A.g.w, 0)) || (B.g.priority - A.g.priority) || (A.id < B.id ? -1 : 1),
  c: (A, B) => (B.g.floorOnly - A.g.floorOnly) || (B.g.priority - A.g.priority) || (B.g.h - A.g.h) || (groupVolume(B.g) - groupVolume(A.g)) || (A.id < B.id ? -1 : 1),
  d: (A, B) => (B.g.floorOnly - A.g.floorOnly) || (groupVolume(A.g) - groupVolume(B.g)) * -1 || (B.g.kg - A.g.kg) || (A.id < B.id ? -1 : 1)
};
const _layoutCache = new Map();
/* Real engine plan for the unmodified SH-102 in a 20GP (placement order = loading order). */
function engineLayout(ship, contCode, mode) {
  const run = recordedRun(ship, contCode, mode);
  if (!run || !run.p) return null;
  const key = 'engine#' + mode;
  if (_layoutCache.has(key)) return _layoutCache.get(key);
  const c = CONTAINERS[contCode];
  const placements = run.p.map(([id, x, y, z, dx, dy, dz], i) => ({ id, gcode: id.split('-')[1], x0: x, y0: y, z0: z, x1: x + dx, y1: y + dy, z1: z + dz, dx, dy, dz, order: i + 1, layer: 1 }));
  for (const a of placements) {
    if (a.z0 === 0) continue;
    let m = 0;
    for (const b of placements) if (b.z1 === a.z0 && b.x0 < a.x1 && a.x0 < b.x1 && b.y0 < a.y1 && a.y0 < b.y1 && b.order < a.order) m = Math.max(m, b.layer);
    a.layer = m + 1;
  }
  const byId = {}; const outcome = {};
  for (const b of expandBoxes(ship)) {
    const st = inputStatus(b.g, c);
    outcome[b.id] = st.status === 'rejected' ? { status: 'rejected', reason: st.reason } : { status: 'unplaced', reason: 'engineNotLoaded' };
  }
  let kg = 0;
  for (const p of placements) { byId[p.id] = p; outcome[p.id] = { status: 'loaded', placement: p }; const g = ship.groups.find(x => x.code === p.gcode); p.kg = g ? +g.kg : 0; kg += p.kg; }
  const loadedVol = placements.reduce((s, p) => s + p.dx * p.dy * p.dz, 0) / 1e9;
  const out = {
    mode, contCode, placements, byId, outcome, source: 'engine', loaded: placements.length, total: run.total,
    rejected: Object.values(outcome).filter(o => o.status === 'rejected').length, unplaced: Object.values(outcome).filter(o => o.status === 'unplaced').length,
    loadedVol, util: run.util, kg, layers: placements.reduce((m, p) => Math.max(m, p.layer), 0), timeMs: run.timeMs, unload: run.unload,
    validation: validatePlacements(placements, ship, c)
  };
  _layoutCache.set(key, out);
  return out;
}
function layoutPlan(ship, contCode, mode) {
  const eng = engineLayout(ship, contCode, mode); if (eng) return eng;
  const c = CONTAINERS[contCode];
  const key = physSig(ship.code, ship.groups) + '#' + ship.groups.map(g => g.code).join(',') + '#' + contCode + '#' + mode;
  if (_layoutCache.has(key)) return _layoutCache.get(key);
  const t0 = (typeof performance !== 'undefined' ? performance : Date).now();
  const boxes = expandBoxes(ship);
  const outcome = {}; const items = [];
  for (const b of boxes) {
    const st = inputStatus(b.g, c);
    if (st.status === 'rejected') outcome[b.id] = { status: 'rejected', reason: st.reason };
    else items.push(b);
  }
  const runs = [];
  const run = (ord, best) => { const it = items.slice().sort(ORDERINGS[ord]); const r = runPack(it, c, best); r.vol = r.placed.reduce((s, e) => s + (e.x1 - e.x0) * (e.y1 - e.y0) * (e.z1 - e.z0), 0) / 1e9; runs.push(r); };
  run('a', false);
  if (mode === 'optimized') { run('a', true); run('b', true); run('c', true); run('d', true); }
  let best = runs[0];
  for (const r of runs) if (r.vol > best.vol + 1e-9 || (Math.abs(r.vol - best.vol) < 1e-9 && r.placed.length > best.placed.length)) best = r;
  const ordered = loadingOrder(best.placed);
  const placements = ordered.map(e => ({ id: e.id, gcode: e.gcode, x0: e.x0, y0: e.y0, z0: e.z0, x1: e.x1, y1: e.y1, z1: e.z1, dx: e.x1 - e.x0, dy: e.y1 - e.y0, dz: e.z1 - e.z0, layer: e.layer, order: e.order, kg: e.kg }));
  const byId = {};
  for (const p of placements) byId[p.id] = p;
  for (const id in best.res) outcome[id] = best.res[id];
  for (const p of placements) outcome[p.id] = { status: 'loaded', placement: p };
  const loadedVol = best.vol;
  const out = {
    mode, contCode, placements, byId, outcome, source: 'preview',
    loaded: placements.length, total: boxes.length,
    rejected: Object.values(outcome).filter(o => o.status === 'rejected').length,
    unplaced: Object.values(outcome).filter(o => o.status === 'unplaced').length,
    loadedVol, util: loadedVol / containerVolume(c) * 100, kg: best.kg,
    layers: placements.reduce((m, p) => Math.max(m, p.layer), 0)
  };
  out.timeMs = (typeof performance !== 'undefined' ? performance : Date).now() - t0;
  out.unload = unloadingBlocking(placements, ship);
  out.validation = validatePlacements(placements, ship, c);
  _layoutCache.set(key, out);
  return out;
}

/* ---------- Wall-building simulation of traditional manual loading
   (after George & Robinson, 1980): vertical walls across the width,
   from the back wall toward the door; each wall is filled column by
   column, floor first, largest boxes first. ---------- */
function layoutWall(ship, contCode) {
  const eng = engineLayout(ship, contCode, 'wall'); if (eng) return eng;
  const c = CONTAINERS[contCode];
  const key = 'wall#' + physSig(ship.code, ship.groups) + '#' + ship.groups.map(g => g.code).join(',') + '#' + contCode;
  if (_layoutCache.has(key)) return _layoutCache.get(key);
  const t0 = (typeof performance !== 'undefined' ? performance : Date).now();
  const boxes = expandBoxes(ship); const outcome = {}; let rem = [];
  for (const b of boxes) { const st = inputStatus(b.g, c); if (st.status === 'rejected') outcome[b.id] = { status: 'rejected', reason: st.reason }; else rem.push(b); }
  rem.sort((A, B) => (B.g.floorOnly - A.g.floorOnly) || (groupVolume(B.g) - groupVolume(A.g)) || (A.id < B.id ? -1 : 1));
  const placed = []; let kg = 0; let wallX = 0;
  const commit = (it, f) => {
    for (const [e, a] of f.inc) e.load += a;
    const entry = { id: it.id, g: it.g, gcode: it.g.code, x0: f.x0, y0: f.y0, z0: f.z0, x1: f.x1, y1: f.y1, z1: f.z1, kg: +it.g.kg, load: 0, sups: f.sups };
    entry.layer = f.z0 < EPS ? 1 : 1 + Math.max(...f.sups.map(s => s.p.layer));
    placed.push(entry); kg += +it.g.kg; rem = rem.filter(r => r !== it); return entry;
  };
  const tryAt = (p, filter, sortO) => {
    for (const it of rem) {
      if (kg + +it.g.kg > c.payload + 1e-9) continue;
      if (p[2] > EPS && it.g.floorOnly) continue;
      let ors = fitOrientations(it.g, c).filter(filter); if (sortO) ors = ors.sort(sortO);
      for (const o of ors) { const f = tryPlace(p, o, it.g, +it.g.kg, placed, c); if (f) return commit(it, f); }
    }
    return null;
  };
  const face = (a, b) => (b[1] * b[2] - a[1] * a[2]) || (a[0] - b[0]);
  while (rem.length && wallX < c.L - EPS) {
    const lead = tryAt([wallX, 0, 0], o => wallX + o[0] <= c.L + EPS, face);
    if (!lead) break;
    const xEnd = lead.x1;
    let pts = [];
    const addPts = e => { for (const q of [[e.x0, e.y1, e.z0], [e.x0, e.y0, e.z1], [e.x1, e.y0, e.z0]]) if (q[0] < xEnd - EPS && q[1] < c.W - EPS && q[2] < c.H - EPS) pts.push(q); };
    addPts(lead);
    let progress = true;
    while (progress && rem.length) {
      progress = false;
      pts.sort((p1, p2) => p1[1] - p2[1] || p1[2] - p2[2] || p1[0] - p2[0]);
      for (let i = 0; i < pts.length; i++) {
        const q = pts[i];
        const e = tryAt(q, o => q[0] + o[0] <= xEnd + EPS, face);
        if (e) { pts.splice(i, 1); pts = pts.filter(r => !(r[0] >= e.x0 - EPS && r[0] < e.x1 - EPS && r[1] >= e.y0 - EPS && r[1] < e.y1 - EPS && r[2] >= e.z0 - EPS && r[2] < e.z1 - EPS)); addPts(e); progress = true; break; }
      }
    }
    wallX = xEnd;
  }
  for (const it of rem) outcome[it.id] = { status: 'unplaced', reason: kg + +it.g.kg > c.payload ? 'payload' : 'noPosition' };
  const ordered = loadingOrder(placed);
  const placements = ordered.map(e => ({ id: e.id, gcode: e.gcode, x0: e.x0, y0: e.y0, z0: e.z0, x1: e.x1, y1: e.y1, z1: e.z1, dx: e.x1 - e.x0, dy: e.y1 - e.y0, dz: e.z1 - e.z0, layer: e.layer, order: e.order, kg: e.kg }));
  const byId = {}; for (const p of placements) { byId[p.id] = p; outcome[p.id] = { status: 'loaded', placement: p }; }
  const loadedVol = placements.reduce((s, p) => s + p.dx * p.dy * p.dz, 0) / 1e9;
  const out = { mode: 'wall', contCode, placements, byId, outcome, source: 'preview', loaded: placements.length, total: boxes.length,
    rejected: Object.values(outcome).filter(o => o.status === 'rejected').length, unplaced: Object.values(outcome).filter(o => o.status === 'unplaced').length,
    loadedVol, util: loadedVol / containerVolume(c) * 100, kg, layers: placements.reduce((m, p) => Math.max(m, p.layer), 0) };
  out.timeMs = (typeof performance !== 'undefined' ? performance : Date).now() - t0;
  out.unload = unloadingBlocking(placements, ship);
  out.validation = validatePlacements(placements, ship, c);
  _layoutCache.set(key, out);
  return out;
}

/* % of box pairs (different priorities) where the box that unloads later
   sits closer to the door (larger x) than the box that unloads earlier. */
function unloadingBlocking(placements, ship) {
  const pr = {}; for (const g of ship.groups) pr[g.code] = +g.priority;
  let pairs = 0, bad = 0;
  for (let i = 0; i < placements.length; i++) for (let j = i + 1; j < placements.length; j++) {
    const a = placements[i], b = placements[j]; const pa = pr[a.gcode], pb = pr[b.gcode]; if (pa === pb) continue;
    pairs++;
    const early = pa < pb ? a : b, late = pa < pb ? b : a;
    if ((late.x0 + late.x1) / 2 > (early.x0 + early.x1) / 2 + EPS) bad++;
  }
  return pairs ? bad / pairs * 100 : 0;
}

/* Independent checks C1–B6 on a set of placements (prototype validator). */
function validatePlacements(P, ship, c) {
  const G = {}; for (const g of ship.groups) G[g.code] = g;
  const r = { C1: true, C2: true, C3: true, B1: true, B2: true, B3: true, B4: true, B5: true, B6: true };
  let kg = 0;
  for (const a of P) {
    const g = G[a.gcode]; kg += +g.kg;
    if (a.x0 < -EPS || a.y0 < -EPS || a.z0 < -EPS || a.x1 > c.L + EPS || a.y1 > c.W + EPS || a.z1 > c.H + EPS) r.C1 = false;
    if (a.dy > c.doorW + EPS || a.dz > c.doorH + EPS) r.C3 = false;
    const want = [+g.l * 10, +g.w * 10, +g.h * 10].sort((x, y) => x - y).join(), got = [a.dx, a.dy, a.dz].sort((x, y) => x - y).join();
    if (want !== got || (g.orientation === 'upright' && Math.abs(a.dz - g.h * 10) > EPS)) r.B1 = false;
    if (g.floorOnly && a.z0 > EPS) r.B2 = false;
  }
  if (kg > c.payload + 1e-9) r.C2 = false;
  const sup = new Map(P.map(p => [p, []]));
  for (let i = 0; i < P.length; i++) for (let j = 0; j < P.length; j++) {
    if (i === j) continue; const a = P[i], b = P[j];
    const ox = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0), oy = Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0), oz = Math.min(a.z1, b.z1) - Math.max(a.z0, b.z0);
    if (i < j && ox > EPS && oy > EPS && oz > EPS) r.C1 = false;
    if (ox > EPS && oy > EPS && Math.abs(b.z1 - a.z0) <= EPS) sup.get(a).push({ p: b, a: ox * oy });
  }
  for (const a of P) {
    if (a.z0 <= EPS) continue; const ss = sup.get(a); const area = ss.reduce((s, x) => s + x.a, 0);
    if (area < a.dx * a.dy * 0.999) r.B3 = false;
    for (const x of ss) { const sg = G[x.p.gcode], tg = G[a.gcode]; if (sg.fragile) r.B5 = false; if (!allowsOnTop(sg, tg) && !sg.fragile) r.B4 = false; }
  }
  const load = new Map(P.map(p => [p, 0]));
  for (const a of P.slice().sort((x, y) => y.z0 - x.z0)) {
    const ss = sup.get(a); const tot = ss.reduce((s, x) => s + x.a, 0); if (!tot) continue;
    const w = +G[a.gcode].kg + load.get(a);
    for (const x of ss) load.set(x.p, load.get(x.p) + w * x.a / tot);
  }
  for (const a of P) { const g = G[a.gcode]; if (g.stackable && g.loadBearing && load.get(a) > +g.loadBearing + 1e-6) r.B6 = false; }
  r.passed = VALIDATOR_CHECKS.filter(k => r[k]).length; r.ok = r.passed === VALIDATOR_CHECKS.length;
  return r;
}

if (typeof module !== 'undefined') module.exports = { layoutWall, validatePlacements, unloadingBlocking, CONTAINERS, DEMO, RECORDED, layoutPlan, physSig, isDemoInventory, recordedRun, expandBoxes, inputStatus, groupErrors, shipmentTotals, containerVolume, fitOrientations, boxId, splitId };
