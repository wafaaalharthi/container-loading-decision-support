'use strict';
/* ============================================================
   app.js — state, routing, screens, flows.
   ============================================================ */
const STORE_KEY = 'senior-loading-v1';
const $ = (s, r = document) => r.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ltr = s => `<span class="ltr">${esc(s)}</span>`;
const clone = o => JSON.parse(JSON.stringify(o));
const nf = (v, d = 0) => Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const nfx = (v, d = 2) => Number(v).toLocaleString('en-US', { maximumFractionDigits: d });
const uid = () => Math.random().toString(36).slice(2, 10);
const pad3 = n => String(n).padStart(3, '0');

function t(k, v) {
  const L = I18N[S.lang] || I18N.en;
  let s = L[k] ?? I18N.en[k] ?? k;
  if (v) s = s.replace(/\{(\w+)\}/g, (m, x) => (v[x] !== undefined ? v[x] : m));
  return s;
}
const th = (k, v) => esc(t(k, v));

/* ---------- icons ---------- */
const ICONS = {
  home: 'M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z', plans: 'M9 3h6v3H9zM7 4.5H5V21h14V4.5h-2M8 11h8M8 15h6',
  box: 'M3 7.5 12 3l9 4.5v9L12 21l-9-4.5zM3 7.5l9 4.5 9-4.5M12 12v9', menu: 'M4 7h16M4 12h16M4 17h16',
  bell: 'M6 16v-5a6 6 0 0 1 12 0v5l2 2H4zM10 20.5a2 2 0 0 0 4 0', back: 'M15 5l-7 7 7 7', next: 'M9 5l7 7-7 7',
  upload: 'M12 16V4M7 9l5-5 5 5M4 17v3h16v-3', download: 'M12 4v12M7 11l5 5 5-5M4 17v3h16v-3', list: 'M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01',
  plus: 'M12 5v14M5 12h14', minus: 'M5 12h14', reset: 'M4 12a8 8 0 1 0 2.3-5.6M4 4v4h4',
  info: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v6M12 7.5v.01', check: 'M5 12.5l4.5 4.5L19 7.5',
  shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM8.5 12l2.5 2.5 4.5-5', warn: 'M12 3 2 20h20zM12 10v4M12 17v.01',
  x: 'M6 6l12 12M18 6 6 18', share: 'M4 13v7h16v-7M12 3v12M7 8l5-5 5 5', eye: 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  layers: 'M12 3 2 8l10 5 10-5zM2 12.5l10 5 10-5M2 17l10 5 10-5', clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
  gauge: 'M4 18a8 8 0 1 1 16 0M12 18l4-6', edit: 'M4 20h4L19 9l-4-4L4 16zM14 6l4 4', trash: 'M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13',
  file: 'M6 3h8l4 4v14H6zM14 3v4h4', camera: 'M4 8h3l2-3h6l2 3h3v11H4zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  barcode: 'M4 5v14M7 5v14M10 5v10M13 5v14M16 5v10M19 5v14', search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM21 21l-5-5',
  play: 'M7 5v14l12-7z', pause: 'M8 5v14M16 5v14', user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
  logout: 'M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10', chart: 'M4 20V10M10 20V4M16 20v-7M2 20h20',
  weight: 'M6 20h12l-2-11H8zM9 9a3 3 0 1 1 6 0', container: 'M2 7h20v11H2zM6 7v11M10 7v11M14 7v11M18 7v11',
  inside: 'M3 12h4M17 12h4M12 3v4M12 17v4M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z', orbit: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v4h-4',
  lock: 'M6 11h12v10H6zM8 11V8a4 4 0 0 1 8 0v3', bolt: 'M13 2 4 14h7l-1 8 9-12h-7z',
  spark: 'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6', steps: 'M4 20h4v-4h4v-4h4V8h4',
  report: 'M5 3h14v18H5zM8 8h8M8 12h8M8 16h5', swap: 'M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7', tag: 'M3 12V4h8l10 10-8 8zM7.5 8.5v.01',
  door: 'M5 21V3h11v18M3 21h16M12.5 12v.01', globe: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3c2.5 2.5 3.5 5.5 3.5 9s-1 6.5-3.5 9c-2.5-2.5-3.5-5.5-3.5-9s1-6.5 3.5-9z'
};
const ic = (n, cls = '') => `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true"><path d="${ICONS[n] || ''}"/></svg>`;

/* ---------- state ---------- */
function demoGroups() { return DEMO.groups.map((g, i) => Object.assign(clone(g), { addedAt: 1000 + i * 1000 })); }
function defaults() {
  return {
    v: 1, lang: 'en', route: 'welcome', params: {}, stack: [], session: null, users: [],
    container: '20GP', shipment: { code: DEMO.code, groups: demoGroups(), nextSeq: 7 }, inventoryApproved: true,
    plan: null, plans: [], unsaved: [], reports: [], notifications: [], planSeq: 1, reportSeq: 1,
    prefs: { alwaysAuto: false, autoImport: false, notif: { optimized: true, unplaced: true, inventory: true, approved: true, exported: true } },
    drafts: { box: null, import: null, compare: null }, exportLast: null
  };
}
function loadState() {
  const d = defaults(); let s = null;
  try { s = JSON.parse(localStorage.getItem(STORE_KEY) || 'null'); } catch (e) { s = null; }
  if (!s || typeof s !== 'object') return d;
  const m = Object.assign(d, s);
  m.prefs = Object.assign(defaults().prefs, s.prefs || {}); m.prefs.notif = Object.assign(defaults().prefs.notif, (s.prefs || {}).notif || {});
  m.drafts = Object.assign(defaults().drafts, s.drafts || {});
  if (!m.shipment || !Array.isArray(m.shipment.groups)) m.shipment = defaults().shipment;
  if (!CONTAINERS[m.container]) m.container = '20GP';
  if (!Array.isArray(m.unsaved)) m.unsaved = [];
  return m;
}
let S = loadState();
function save() { try { localStorage.setItem(STORE_KEY, JSON.stringify(S)); } catch (e) { /* storage unavailable */ } }

/* in-memory UI state (survives language switches, not reloads) */
const UI = {
  viewer: { labels: true, layer: 0, hidden: {}, selected: null },
  steps: { i: 1, playing: false, timer: null, mode: null },
  boxes: { q: '', cat: '', code: '', sort: 'old' },
  exportFmt: 'pdf', exportOpts: { image: true, positions: true, unplaced: true, steps: true },
  modal: null, toast: null, toastTimer: null, lastExport: null, expandUnplaced: {}, touchedBox: false, showChecks: false
};

/* ---------- derived helpers ---------- */
const cont = () => CONTAINERS[S.container];
const groupByCode = code => S.shipment.groups.find(g => g.code === code);
const colorOf = code => (groupByCode(code) || {}).color || '#7f8cff';
const kindLabel = g => (g.kind === 'other' && g.custom ? `${t('kind_other')} · ${g.custom}` : t('kind_' + g.kind));
const dims = g => `${nfx(g.l, 1)} × ${nfx(g.w, 1)} × ${nfx(g.h, 1)} cm`;
function genReady(mode) { const p = S.plan; if (!p || !p.gen || p.gen.status === 'none') return false; return mode === 'instant' ? true : p.gen.status === 'done'; }
function layoutFor(mode) { return layoutPlan(S.shipment, S.container, mode); }
function recFor(mode) { return recordedRun(S.shipment, S.container, mode); }
function fmtTime(ms) { return ms < 1 ? '< 1 ms' : ms < 1000 ? `${nf(ms)} ms` : `${nfx(ms / 1000, 1)} s`; }
function metricsFor(mode) {
  const rec = recFor(mode); const lay = layoutFor(mode);
  return {
    rec, lay,
    util: rec ? { v: rec.util, src: 'rec' } : { v: lay.util, src: 'prev' },
    loaded: rec ? { v: rec.loaded, t: rec.total, src: 'rec' } : { v: lay.loaded, t: lay.total, src: 'prev' },
    unplaced: rec ? { v: rec.unplaced, src: 'rec' } : { v: lay.unplaced + lay.rejected, src: 'prev' },
    time: rec ? { v: rec.timeMs, src: 'rec' } : { v: lay.timeMs, src: 'prev' },
    unload: rec ? { v: rec.unload, src: 'rec' } : { v: lay.unload, src: 'prev' },
    valid: rec ? { ok: true, n: 9, src: 'rec' } : { ok: lay.validation.ok, n: lay.validation.passed, src: 'prev' },
    engine: rec ? rec.engine : t('previewEngine')
  };
}
const geoTag = (lay, extra) => t(lay.source === 'engine' ? 'engineTagN' : 'illusTagN', { n: lay.loaded }) + (extra ? ' · ' + extra : '');
const srcBadge = src => `<span class="src ${src}">${th(src === 'rec' ? 'srcRec' : 'srcPrev')}</span>`;
const CAT_COLORS = { electronics: '#3987e5', glass: '#d95926', iron_metal: '#199e70', machinery: '#c98500', wood_furniture: '#d55181', food: '#0ca30c', textiles: '#e66767', paper: '#9085e9', other: '#7d879f' };
function fmtDate(ts) { try { return new Date(ts).toLocaleString(S.lang === 'ar' ? 'ar-SA-u-nu-latn-ca-gregory' : 'en-GB', { dateStyle: 'medium', timeStyle: 'short' }); } catch (e) { return new Date(ts).toISOString(); } }
function rulesText(g) {
  const r = [t(g.orientation === 'upright' ? 'rule_upright' : 'rule_any')];
  if (g.fragile) r.push(t('rule_fragile'));
  if (g.floorOnly) r.push(t('rule_floor'));
  if (g.stackable) { r.push(t('rule_stack_' + g.stacking)); if (g.loadBearing) r.push(t('rule_lb', { kg: nfx(g.loadBearing) })); }
  else r.push(t('rule_nonstack'));
  return r.join(' · ');
}
function reasonText(reason, g) {
  if (reason === 'noOrientation') return t('reason_noOrientation', { c: S.container });
  return t('reason_' + reason);
}

/* ---------- plans, events, notifications ---------- */
function archiveCurrent() {
  const p = S.plan; if (!p || p.approved) return;
  const snap = clone(p); snap.groups = clone(S.shipment.groups); snap.shipmentCode = S.shipment.code; snap.nextSeq = S.shipment.nextSeq; snap.container = S.container; snap.savedAt = Date.now();
  if (snap.gen && snap.gen.status === 'optimizing') snap.gen.status = 'done';
  S.unsaved = [snap, ...S.unsaved.filter(x => x.id !== snap.id)].slice(0, 30);
}
function newPlan() {
  archiveCurrent();
  const p = { id: 'PLN-' + pad3(S.planSeq++), createdAt: Date.now(), container: S.container, shipmentCode: S.shipment.code, mode: 'instant', gen: { status: 'none' }, approved: false, autoApproved: false, events: [{ type: 'created', t: Date.now() }], reportIds: [] };
  S.plan = p; return p;
}
function addEvent(type) { if (!S.plan) return; const ev = S.plan.events; if (type === 'dataApproved' && ev.length && ev[ev.length - 1].type === 'dataApproved') return; S.plan.events.push({ type, t: Date.now() }); syncSaved(); }
function syncSaved() {
  const p = S.plan; if (!p) return;
  const i = S.plans.findIndex(x => x.id === p.id);
  if (i >= 0) S.plans[i] = Object.assign(S.plans[i], { events: clone(p.events), reportIds: clone(p.reportIds), mode: p.mode, approved: p.approved, autoApproved: p.autoApproved });
}
function snapshotPlan() {
  const p = S.plan; const snap = clone(p);
  snap.groups = clone(S.shipment.groups); snap.shipmentCode = S.shipment.code; snap.nextSeq = S.shipment.nextSeq; snap.container = S.container;
  const m = metricsFor(p.mode); snap.util = m.util.v; snap.utilSrc = m.util.src; snap.loaded = m.loaded.v; snap.total = m.loaded.t;
  const i = S.plans.findIndex(x => x.id === p.id); if (i >= 0) S.plans[i] = snap; else S.plans.unshift(snap);
}
function notify(type, route, params, vars) {
  if (!S.prefs.notif[type]) return;
  S.notifications.unshift({ id: uid(), type, t: Date.now(), read: false, route, params: params || {}, vars: vars || {} });
  S.notifications = S.notifications.slice(0, 60);
}
function inputsChanged() {
  S.inventoryApproved = false;
  const p = S.plan;
  if (p && p.approved) newPlan();
  else if (p && p.gen && p.gen.status !== 'none') { p.gen = { status: 'none' }; p.mode = 'instant'; p.events = p.events.filter(e => e.type === 'created'); }
  UI.viewer.selected = null; S.drafts.compare = null;
}
function ensureDraftPlan() { if (!S.plan || S.plan.approved) newPlan(); return S.plan; }

/* ---------- optimization (replays the recorded Beam Search run time for SH-102 / 20GP) ---------- */
let optTimer = null;
const optDuration = () => (recFor('optimized') ? RECORDED.optimized.timeMs : 1500);
function ensureOptTimer() { if (S.plan && S.plan.gen && S.plan.gen.status === 'optimizing' && !optTimer) optTimer = setInterval(tickOpt, 80); }
function optFraction() { const p = S.plan; return Math.min(1, (Date.now() - p.gen.startedAt) / optDuration()); }
function tickOpt() {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status !== 'optimizing') { clearInterval(optTimer); optTimer = null; return; }
  const f = optFraction();
  const bar = document.getElementById('optbar'); if (bar) bar.style.width = (f * 100).toFixed(1) + '%';
  const lab = document.getElementById('optpct'); if (lab) lab.textContent = `${Math.round(f * 100)}% · ${nfx(Math.min(optDuration(), Date.now() - p.gen.startedAt) / 1000, 1)} s`;
  if (f >= 1) { clearInterval(optTimer); optTimer = null; finishOptimization(); }
}
function startGeneration() {
  const fresh = !S.plan || S.plan.approved;
  const p = ensureDraftPlan();
  if (fresh && S.inventoryApproved) p.events.push({ type: 'dataApproved', t: Date.now() });
  p.container = S.container; p.shipmentCode = S.shipment.code; p.mode = 'instant'; p.approved = false; p.autoApproved = false;
  p.gen = { status: 'optimizing', startedAt: Date.now() };
  addEvent('generated'); save(); ensureOptTimer();
}
function finishOptimization() {
  const p = S.plan; p.gen.status = 'done'; p.mode = 'optimized';
  notify('optimized', 'results');
  showToast(t('toastOptimized'), 'spark');
  finalizeGeneration(); save(); render();
}
function keepInstant() {
  const p = S.plan; if (!p || p.gen.status !== 'optimizing') return;
  clearInterval(optTimer); optTimer = null; p.gen.status = 'kept'; p.mode = 'instant';
  showToast(t('toastKept'), 'bolt'); finalizeGeneration(); save(); render();
}
function finalizeGeneration() {
  const p = S.plan; const n = metricsFor(p.mode).unplaced.v;
  if (n > 0) notify('unplaced', 'unplaced', {}, { n });
  if (S.prefs.alwaysAuto) approvePlan(true);
}
function approvePlan(auto) {
  const p = S.plan; if (!p || p.approved) return;
  p.approved = true; p.autoApproved = !!auto; addEvent('approved'); snapshotPlan();
  notify('approved', 'plan', { id: p.id }, { id: p.id, how: t(auto ? 'approvedAutoShort' : 'approvedManualShort') });
}

/* ---------- routing ---------- */
const TAB_OF = { home: 'home', container: 'home', results: 'home', viewer: 'home', unplaced: 'home', steps: 'home', compare: 'home', export: 'home', exportDone: 'home', review: 'shipments', shipment: 'shipments', addbox: 'shipments', import: 'shipments', boxes: 'shipments', box: 'shipments', plans: 'plans', plan: 'plans', reports: 'plans', report: 'plans', notifications: 'more', settings: 'more', opsRecords: 'more', contact: 'more' };
const ROOTS = { home: 'home', plans: 'plans', shipments: 'shipment', more: 'settings' };
const PUBLIC = ['welcome', 'signin', 'signup'];
function go(route, params, opt) {
  opt = opt || {};
  stopSteps();
  if (opt.root) S.stack = [];
  else if (!opt.replace && S.route) S.stack.push({ route: S.route, params: S.params });
  if (S.stack.length > 30) S.stack = S.stack.slice(-30);
  S.route = route; S.params = params || {};
  UI.modal = null; scrollMemo = { route: null, top: 0 };
  save(); render(true);
}
function back() {
  stopSteps();
  const prev = S.stack.pop();
  if (prev) { S.route = prev.route; S.params = prev.params || {}; }
  else S.route = S.session ? 'home' : 'welcome';
  UI.modal = null; save(); render(true);
}

/* ---------- toast / modal ---------- */
function showToast(msg, icon) {
  UI.toast = { msg, icon: icon || 'check' };
  clearTimeout(UI.toastTimer);
  UI.toastTimer = setTimeout(() => { UI.toast = null; const el = $('#toast'); if (el) el.remove(); }, 3200);
  const host = $('#toasthost'); if (host) host.innerHTML = toastHtml();
}
const toastHtml = () => UI.toast ? `<div class="toast" id="toast" role="status">${ic(UI.toast.icon)}<span>${esc(UI.toast.msg)}</span></div>` : '';
function openModal(m) { UI.modal = m; renderModal(); }
function closeModal() { UI.modal = null; renderModal(); }

/* ============================================================
   Rendering
   ============================================================ */
let scrollMemo = { route: null, top: 0 };
function render(fresh) {
  const root = $('#app');
  const ae = document.activeElement; const focusId = ae && ae.id && !fresh ? ae.id : null;
  let caret = null; try { if (focusId && typeof ae.selectionStart === 'number') caret = ae.selectionStart; } catch (e) { }
  const main0 = $('#main');
  if (main0 && !fresh) scrollMemo = { route: S.route, top: main0.scrollTop };
  if (!PUBLIC.includes(S.route) && !S.session) { S.route = 'welcome'; S.stack = []; }
  document.documentElement.lang = S.lang; document.documentElement.dir = S.lang === 'ar' ? 'rtl' : 'ltr';
  document.title = 'Senior Project · Loading Studio';
  const page = (PAGES[S.route] || PAGES.home)();
  const tab = TAB_OF[S.route];
  const canBack = page.back !== false && S.route !== 'welcome' && !(Object.values(ROOTS).includes(S.route) && !S.stack.length);
  const unread = S.notifications.filter(n => !n.read).length;
  root.innerHTML = `
    <header class="topbar">
      ${canBack ? `<button class="iconbtn" data-act="back" aria-label="${th('back')}">${ic('back', 'flip')}</button>` : `<span style="width:4px"></span>`}
      ${page.blank ? `<span style="flex:1"></span>` : `<h1>${esc(page.title)}</h1>`}
      ${S.session ? `<button class="iconbtn" data-act="nav" data-route="notifications" aria-label="${th('notifications')}${unread ? ' (' + unread + ')' : ''}">${ic('bell')}${unread ? `<span class="badge">${unread > 9 ? '9+' : unread}</span>` : ''}</button>` : ''}
      <button class="langbtn" data-act="lang" aria-label="${th('switchLang')}"><span class="${S.lang === 'ar' ? 'on' : ''}">ع</span><span class="muted">/</span><span class="${S.lang === 'en' ? 'on' : ''}">EN</span></button>
    </header>
    <main class="main" id="main" tabindex="-1">${page.body}</main>
    ${S.session && tab ? navHtml(tab) : ''}
    <div id="toasthost">${toastHtml()}</div>
    <div id="modalhost"></div>`;
  const main = $('#main');
  if (scrollMemo.route === S.route && !fresh) main.scrollTop = scrollMemo.top;
  attachScenes();
  renderModal();
  if (focusId && !UI.modal) { const el = document.getElementById(focusId); if (el && el.focus) { el.focus({ preventScroll: true }); if (caret !== null) { try { el.setSelectionRange(caret, caret); } catch (e) { } } } }
  if (page.after) page.after();
  ensureOptTimer();
}
function navHtml(tab) {
  const items = [['home', 'home', 'navHome'], ['plans', 'plans', 'navPlans'], ['shipments', 'box', 'navShipments'], ['more', 'menu', 'navMore']];
  return `<nav class="nav" aria-label="${th('mainNav')}">${items.map(([k, icn, lbl]) => `<button class="navbtn ${tab === k ? 'active' : ''}" data-act="tab" data-tab="${k}" ${tab === k ? 'aria-current="page"' : ''}>${ic(icn)}<span>${th(lbl)}</span></button>`).join('')}</nav>`;
}

/* ---------- 3D scene data ---------- */
function boxesFromLayout(lay, filter) { return lay.placements.filter(p => !filter || filter(p)); }
function sceneSpec(kind, el) {
  const doorLabel = t('doorLabel');
  if (kind === 'welcome') {
    const ship = { code: DEMO.code, groups: DEMO.groups };
    const lay = layoutPlan(ship, '20GP', 'optimized');
    const col = c => (DEMO.groups.find(g => g.code === c) || {}).color;
    return { id: 'welcome', auto: true, framing: 0.95, getData: () => ({ cont: CONTAINERS['20GP'], boxes: lay.placements, colorOf: col, labels: true, doorLabel }) };
  }
  if (kind === 'home') {
    const p = S.plan; const ready = p && p.gen && p.gen.status !== 'none';
    const lay = ready ? layoutFor(p.mode) : null;
    return { id: 'home', auto: true, framing: 0.95, getData: () => ({ cont: cont(), boxes: lay ? lay.placements : [], colorOf, labels: true, doorLabel }) };
  }
  if (kind === 'container') return { id: 'container', auto: false, framing: 0.92, getData: () => ({ cont: cont(), boxes: [], colorOf, doorLabel }) };
  if (kind === 'results') {
    const lay = layoutFor(S.plan.mode);
    return { id: 'results', framing: 0.92, getData: () => ({ cont: cont(), boxes: lay.placements, colorOf, labels: true, doorLabel }) };
  }
  if (kind === 'viewer' || kind === 'glbprev') {
    const v = UI.viewer;
    return {
      id: kind, framing: 0.84, allowInside: kind === 'viewer',
      onPick: kind === 'viewer' ? (id => { v.selected = id; render(); }) : null,
      onInside: kind === 'viewer' ? (val => { const r = $('#insideRange'); if (r) r.value = Math.round(val * 100); }) : null,
      getData: () => {
        const lay = layoutFor(S.plan.mode);
        const boxes = kind === 'glbprev' ? lay.placements : lay.placements.filter(p => !v.hidden[p.gcode] && (!v.layer || p.layer <= v.layer));
        return { cont: cont(), boxes, colorOf, labels: kind === 'glbprev' ? UI.exportOpts.positions : v.labels, selectedId: v.selected, doorLabel };
      }
    };
  }
  if (kind === 'cmpManual') {
    const W = layoutWall(S.shipment, S.container);
    return { id: 'cmpManual', auto: true, framing: 0.98, getData: () => ({ cont: cont(), boxes: W.placements, colorOf, labels: true, doorLabel }) };
  }
  if (kind === 'cmpSystem') {
    const lay = layoutFor((S.drafts.compare && S.drafts.compare.mode) || S.plan.mode);
    return { id: 'cmpSystem', auto: true, framing: 0.98, getData: () => ({ cont: cont(), boxes: lay.placements, colorOf, labels: true, doorLabel }) };
  }
  if (kind === 'steps') {
    return {
      id: 'steps', framing: 0.88,
      getData: () => {
        const lay = layoutFor(S.plan.mode); const i = UI.steps.i;
        const cur = lay.placements[i - 1];
        return { cont: cont(), boxes: lay.placements.filter(p => p.order <= i), colorOf, labels: true, highlightId: cur && cur.id, doorLabel };
      }
    };
  }
  return null;
}
function attachScenes() {
  document.querySelectorAll('canvas[data-scene]').forEach(cv => {
    const spec = sceneSpec(cv.dataset.scene, cv); if (!spec) return;
    Scenes.create(cv, spec);
  });
}
function viewerHtml(kind, h, tag, tools) {
  return `<div class="viewer" style="height:${h}px">
    <canvas data-scene="${kind}" style="height:${h}px" tabindex="0" role="img" aria-label="${th('canvasAria')}"></canvas>
    ${tools ? `<div class="tools">
      <button class="iconbtn" data-act="zoom" data-id="${kind}" data-f="0.85" aria-label="${th('zoomIn')}">${ic('plus')}</button>
      <button class="iconbtn" data-act="zoom" data-id="${kind}" data-f="1.18" aria-label="${th('zoomOut')}">${ic('minus')}</button>
      <button class="iconbtn" data-act="camreset" data-id="${kind}" aria-label="${th('resetView')}">${ic('reset')}</button></div>` : ''}
    ${tag ? `<span class="tag">${esc(tag)}</span>` : ''}
  </div>`;
}

/* ---------- small UI builders ---------- */
const sw = (code) => `<span class="swatch" style="background:${colorOf(code)};color:${colorOf(code)}"></span>`;
function switchHtml(id, checked, label, sub, opts) {
  opts = opts || {};
  return `<div class="switchrow"><div class="grow"><label for="${id}">${esc(label)}</label>${sub ? `<small>${sub}</small>` : ''}</div>
    <span class="switch"><input type="checkbox" role="switch" id="${id}" ${checked ? 'checked' : ''} ${opts.disabled ? 'disabled' : ''} ${opts.attrs || ''}><span class="tr"></span><span class="th"></span></span></div>`;
}
function segHtml(act, value, options, label) {
  return `<div class="seg" role="group" aria-label="${esc(label || '')}">${options.map(o => `<button data-act="${act}" data-v="${o.v}" aria-pressed="${o.v === value}" ${o.disabled ? 'disabled' : ''}>${o.icon ? ic(o.icon, 'sm') : ''}${esc(o.label)}</button>`).join('')}</div>`;
}
function metric(icon, k, v, s, extra) { return `<div class="metric">${extra || ''}<span class="k">${ic(icon, 'sm')}${esc(k)}</span><span class="v">${v}</span>${s ? `<span class="s">${s}</span>` : ''}</div>`; }
function notice(kind, icon, html) { return `<div class="notice ${kind}" role="note">${ic(icon, 'sm')}<div>${html}</div></div>`; }
function linkRow(icon, label, sub, act, attrs) { return `<button class="row-btn" data-act="${act}" ${attrs || ''}><span class="qa-ico" style="color:var(--cyan)">${ic(icon)}</span><span class="grow"><span style="display:block;font-weight:600">${esc(label)}</span>${sub ? `<span class="sub">${sub}</span>` : ''}</span>${ic('next', 'flip sm')}</button>`; }

/* ============================================================
   Pages
   ============================================================ */
const PAGES = {};

PAGES.welcome = () => ({
  back: false, title: '', blank: true,
  body: `<div class="welcome">
    <p class="muted xs" style="margin:0 0 2px">${th('uj')}</p>
    <h1 class="hero">Senior Project 1</h1>
    ${viewerHtml('welcome', 270, '', false)}
    <p class="lead">${th('welcomeWhat')}</p>
    <div class="stack" style="margin-top:16px">
      <button class="btn primary block" data-act="nav" data-route="signin">${ic('user', 'sm')}${th('signIn')}</button>
      <button class="btn block" data-act="nav" data-route="signup">${ic('plus', 'sm')}${th('createAccount')}</button>
    </div>
  </div>`
});

function authPage(kind) {
  const f = UI.auth || (UI.auth = { name: '', email: '', pw: '', err: '' });
  return {
    title: t(kind === 'signin' ? 'signIn' : 'createAccount'),
    body: `<form data-form="${kind}" novalidate>
      ${notice('', 'info', th('authNote'))}
      ${kind === 'signup' ? `<div class="field"><label for="au_name">${th('fullName')}</label><input class="input" id="au_name" autocomplete="name" data-ui="auth.name" value="${esc(f.name)}"></div>` : ''}
      <div class="field"><label for="au_email">${th('email')}</label><input class="input ltr" id="au_email" type="email" autocomplete="email" data-ui="auth.email" value="${esc(f.email)}"></div>
      <div class="field"><label for="au_pw">${th('password')}</label><input class="input ltr" id="au_pw" type="password" autocomplete="${kind === 'signin' ? 'current-password' : 'new-password'}" data-ui="auth.pw" value="${esc(f.pw)}"></div>
      ${f.err ? `<p class="errtxt" role="alert">${esc(f.err)}</p>` : ''}
      <button class="btn primary block" type="submit">${th(kind === 'signin' ? 'signIn' : 'createAccount')}</button>
      <button class="btn ghost block" type="button" style="margin-top:8px" data-act="nav" data-route="${kind === 'signin' ? 'signup' : 'signin'}" data-replace="1">${th(kind === 'signin' ? 'noAccount' : 'haveAccount')}</button>
    </form>`
  };
}
PAGES.signin = () => authPage('signin');
PAGES.signup = () => authPage('signup');

PAGES.home = () => {
  const p = S.plan; const ready = p && p.gen && p.gen.status !== 'none';
  const m = ready ? metricsFor(p.mode) : null;
  const t0 = shipmentTotals(S.shipment);
  const status = !p ? '' : p.approved ? `<span class="chip ok">${ic('check', 'sm')}${th(p.autoApproved ? 'approvedAuto' : 'approved')}</span>` : ready ? `<span class="chip cyan">${th(p.gen.status === 'optimizing' ? 'optimizing' : 'generated')}</span>` : `<span class="chip warn">${th('draft')}</span>`;
  return {
    title: t('loadingStudio'), back: false,
    body: `<p class="muted small" style="margin-bottom:10px">${th('homeHello', { name: S.session && S.session.name ? S.session.name : t('demoUser') })}</p>
    <div class="card glow">
      <div class="row between" style="margin-bottom:8px"><strong>${th('lastPlan')}</strong>${status}</div>
      ${viewerHtml('home', 178, ready ? t('illusTag') : t('emptyTag'), false)}
      <div class="row between" style="margin-top:10px">
        <div><div class="row wrap"><span class="chip">${ic('container', 'sm')}${ltr(S.container)}</span><span class="chip">${ic('box', 'sm')}${ltr(S.shipment.code)}</span>${p ? `<span class="chip">${ltr(p.id)}</span>` : ''}</div>
          <p class="small muted" style="margin:6px 0 0">${th('boxesGroups', { b: t0.boxes, g: t0.groups })}</p></div>
        <div style="text-align:end"><div class="big">${m ? ltr(nfx(m.util.v, 1) + '%') : '—'}</div><div class="xs muted">${m ? `${th('mUtil')} · ${th(p.mode)}` : th('emptyTag')}</div>${m ? srcBadge(m.util.src) : ''}</div>
      </div>
      <button class="btn primary block" style="margin-top:10px" data-act="openPlan">${ic('eye', 'sm')}${th('openPlan')}</button>
    </div>
    ${pieHtml()}
    <h2>${th('quickActions')}</h2>
    <div class="qa">
      <button class="row-btn" data-act="newPlan"><span class="ico">${ic('plus')}</span>${th('newPlan')}</button>
      <button class="row-btn" data-act="nav" data-route="import"><span class="ico">${ic('upload')}</span>${th('uploadShipment')}</button>
      <button class="row-btn" data-act="nav" data-route="boxes"><span class="ico">${ic('list')}</span>${th('allBoxes')}</button>
      <button class="row-btn" data-act="nav" data-route="plans"><span class="ico">${ic('plans')}</span>${th('savedPlans')}</button>
    </div>`
  };
};

function pieHtml() {
  const by = UI.pieBy || 'count'; const agg = {};
  for (const g of S.shipment.groups) { const q = Math.max(0, Math.floor(+g.qty || 0)); const v = by === 'count' ? q : q * groupVolume(g); agg[g.kind] = (agg[g.kind] || 0) + v; }
  const kinds = KINDS.filter(k => agg[k] > 0); const total = kinds.reduce((s, k) => s + agg[k], 0);
  const fmtV = v => by === 'count' ? nf(v) : `${nfx(v, 2)} m³`;
  let a0 = -Math.PI / 2; const R = 64, C = 72;
  const slices = kinds.map(k => {
    const frac = agg[k] / total; const a1 = a0 + frac * Math.PI * 2;
    const large = a1 - a0 > Math.PI ? 1 : 0;
    const d = frac >= 0.9999 ? `M${C} ${C - R}A${R} ${R} 0 1 1 ${C - 0.01} ${C - R}Z` : `M${C} ${C}L${(C + R * Math.cos(a0)).toFixed(2)} ${(C + R * Math.sin(a0)).toFixed(2)}A${R} ${R} 0 ${large} 1 ${(C + R * Math.cos(a1)).toFixed(2)} ${(C + R * Math.sin(a1)).toFixed(2)}Z`;
    a0 = a1;
    return `<path d="${d}" fill="${CAT_COLORS[k]}" stroke="#101A35" stroke-width="2" stroke-linejoin="round"><title>${esc(t('kind_' + k))}: ${esc(fmtV(agg[k]))} (${nfx(frac * 100, 1)}%)</title></path>`;
  }).join('');
  return `<div class="card"><div class="row between" style="margin-bottom:8px"><strong>${th('pieTitle')}</strong><span class="xs muted ltr">${esc(S.shipment.code)}</span></div>
    ${segHtml('pieBy', by, [{ v: 'count', label: t('pieCount') }, { v: 'volume', label: t('pieVolume') }], t('pieTitle'))}
    ${total ? `<div class="pie"><svg viewBox="0 0 144 144" role="img" aria-label="${th('pieTitle')}">${slices}</svg>
      <ul class="pielegend">${kinds.map(k => `<li><span class="swatch" style="background:${CAT_COLORS[k]};color:${CAT_COLORS[k]}"></span><span class="grow">${th('kind_' + k)}</span><span class="ltr">${esc(fmtV(agg[k]))}</span><span class="muted ltr" style="min-width:44px;text-align:end">${nfx(agg[k] / total * 100, 1)}%</span></li>`).join('')}</ul></div>` : `<div class="empty">${th('noGroups')}</div>`}
  </div>`;
}

PAGES.container = () => {
  const c = cont();
  return {
    title: t('chooseContainer'),
    body: `<p class="muted small">${th('containerIntro')}</p>
    ${segHtml('pickContainer', S.container, CONTAINER_ORDER.map(k => ({ v: k, label: k })), t('chooseContainer'))}
    <div style="margin-top:10px">${viewerHtml('container', 220, t('dragToRotate'), true)}</div>
    <div class="card" style="margin-top:10px"><dl class="kv">
      <dt>${th('insideDims')}</dt><dd>${ltr(`${nfx(c.L / 10, 1)} × ${nfx(c.W / 10, 1)} × ${nfx(c.H / 10, 1)} cm`)}</dd>
      <dt>${th('doorDims')}</dt><dd>${ltr(`${nfx(c.doorW / 10, 1)} × ${nfx(c.doorH / 10, 1)} cm`)}</dd>
      <dt>${th('payload')}</dt><dd>${ltr(nf(c.payload) + ' kg')}</dd>
      <dt>${th('volume')}</dt><dd>${ltr(nfx(containerVolume(c), 2) + ' m³')}</dd>
    </dl><p class="xs muted" style="margin:8px 0 0">${th('hapagNote')}</p></div>
    <button class="btn primary block" data-act="nav" data-route="shipment">${th('continueShipment')}${ic('next', 'flip sm')}</button>`
  };
};

PAGES.shipment = () => {
  const tt = shipmentTotals(S.shipment); const c = cont();
  return {
    title: t('shipmentInventory'),
    body: `<div class="card">
      <div class="row between"><div><div class="xs muted">${th('shipmentCode')}</div><div class="big">${ltr(S.shipment.code)}</div></div>
        <button class="chip-btn" data-act="nav" data-route="container">${ic('container', 'sm')}${ltr(S.container)}</button></div>
      <div class="grid3" style="margin-top:10px">
        ${metric('box', t('totalBoxes'), nf(tt.boxes))}${metric('layers', t('groups'), nf(tt.groups))}${metric('weight', t('totalWeight'), `${nf(tt.kg)}<span class="xs muted"> kg</span>`)}
      </div>
      <p class="xs muted" style="margin:8px 0 0">${th('volLine', { v: nfx(tt.vol, 2), c: nfx(containerVolume(c), 2) })}</p>
    </div>
    ${S.inventoryApproved ? notice('ok', 'check', th('dataApprovedNote')) : notice('warn', 'warn', th('dataNotApproved'))}
    <div class="grid2"><button class="btn" data-act="addBox">${ic('plus', 'sm')}${th('manualEntry')}</button><button class="btn" data-act="nav" data-route="import">${ic('upload', 'sm')}${th('uploadExcelCsv')}</button></div>
    <h2>${th('groups')}</h2>
    <div class="list">${S.shipment.groups.length ? S.shipment.groups.map(g => {
      const st = inputStatus(g, c);
      return `<div class="card flat" style="margin:0;padding:10px">
        <div class="row">${sw(g.code)}<strong class="mono ltr">${esc(g.code)}</strong><span class="grow small">${esc(g.contents || kindLabel(g))}</span>
          <span class="chip ${st.status === 'accepted' ? 'ok' : 'bad'}">${th(st.status)}</span></div>
        <div class="xs muted" style="margin:5px 0">${esc(kindLabel(g))} · ${ltr(dims(g))} · ${ltr(nfx(g.kg) + ' kg')} · ×${nf(g.qty)} · ${th('priorityN', { n: g.priority })}</div>
        <div class="xs muted">${esc(rulesText(g))}</div>
        <div class="row" style="margin-top:6px;justify-content:flex-end">
          <button class="btn sm ghost" data-act="editGroup" data-code="${g.code}">${ic('edit', 'sm')}${th('edit')}</button>
          <button class="btn sm ghost danger" data-act="removeGroup" data-code="${g.code}">${ic('trash', 'sm')}${th('remove')}</button></div>
      </div>`;
    }).join('') : `<div class="empty">${th('noGroups')}</div>`}</div>
    <div class="grid2" style="margin-top:12px"><button class="btn" data-act="nav" data-route="boxes">${ic('list', 'sm')}${th('allBoxes')}</button>
      <button class="btn primary" data-act="nav" data-route="review" ${tt.boxes ? '' : 'disabled'}>${th('reviewInputs')}${ic('next', 'flip sm')}</button></div>`
  };
};

/* ---------- manual entry ---------- */
function emptyBoxDraft(editCode) {
  if (editCode) { const g = groupByCode(editCode); if (g) return Object.assign(clone(g), { editCode, loadBearing: g.loadBearing ?? '' }); }
  return { editCode: null, kind: '', custom: '', contents: '', l: '', w: '', h: '', kg: '', qty: '', priority: 1, orientation: 'any', fragile: false, floorOnly: false, stackable: false, stacking: 'any', loadBearing: '' };
}
PAGES.addbox = () => {
  const d = S.drafts.box || (S.drafts.box = emptyBoxDraft());
  const editing = !!d.editCode;
  const code = editing ? d.editCode : nextGroupCode(S.shipment);
  const errs = groupErrors(Object.assign({}, d, { loadBearing: d.loadBearing === '' ? null : d.loadBearing }));
  const show = UI.touchedBox;
  const er = f => show && errs[f] ? `<span class="errtxt">${th(errs[f])}</span>` : '';
  const ec = f => show && errs[f] ? 'err' : '';
  const q = Number(d.qty); const qOk = Number.isInteger(q) && q >= 1 && q <= 999;
  const preview = qOk ? (q === 1 ? boxId(S.shipment.code, code, 1) : `${boxId(S.shipment.code, code, 1)} … ${boxId(S.shipment.code, code, q)}`) : boxId(S.shipment.code, code, 1) + ' …';
  const numField = (f, lbl, unit, extra) => `<div class="field"><label for="bx_${f}">${esc(lbl)} <span class="xs">(${unit})</span></label><input class="input ltr ${ec(f)}" id="bx_${f}" inputmode="decimal" data-draft="box.${f}" value="${esc(d[f])}" ${extra || ''}>${er(f)}</div>`;
  return {
    title: editing ? t('editGroupTitle', { code }) : t('addNewBox'),
    body: `<form data-form="box" novalidate>
      <div class="field"><label for="bx_kind">${th('category')}</label>
        <select class="input ${ec('kind')}" id="bx_kind" data-draft="box.kind" data-rerender="1">
          <option value="" ${!d.kind ? 'selected' : ''} disabled>${th('selectCategory')}</option>
          ${KINDS.map(k => `<option value="${k}" ${d.kind === k ? 'selected' : ''}>${th('kind_' + k)}</option>`).join('')}
        </select>${er('kind')}</div>
      ${d.kind === 'other' ? `<div class="field"><label for="bx_custom">${th('otherLabel')}</label><input class="input" id="bx_custom" data-draft="box.custom" value="${esc(d.custom)}" placeholder="${th('optional')}"></div>` : ''}
      <div class="field"><label for="bx_contents">${th('contents')} <span class="xs">(${th('optional')})</span></label><input class="input" id="bx_contents" data-draft="box.contents" value="${esc(d.contents)}"></div>
      <div class="grid3">${numField('l', t('lengthL'), 'cm')}${numField('w', t('widthW'), 'cm')}${numField('h', t('heightH'), 'cm')}</div>
      <div class="grid2">${numField('kg', t('weightEach'), 'kg')}${numField('qty', t('quantity'), t('boxesUnit'), 'inputmode="numeric"')}</div>
      <div class="field"><span class="lbl" id="orl">${th('orientation')}</span>${segHtml('boxOrient', d.orientation, [{ v: 'any', label: t('orAny') }, { v: 'upright', label: t('orUpright') }], t('orientation'))}</div>
      <div class="field"><span class="lbl">${th('priority')}</span>
        <div class="row between"><div class="stepper">
          <button type="button" class="iconbtn" style="border:1px solid var(--border)" data-act="prio" data-d="-1" aria-label="${th('decrease')}">${ic('minus')}</button>
          <span class="val" aria-live="polite">${esc(d.priority)}</span>
          <button type="button" class="iconbtn" style="border:1px solid var(--border)" data-act="prio" data-d="1" aria-label="${th('increase')}">${ic('plus')}</button></div>
          <span class="xs muted" style="max-width:180px">${th('priorityHint')}</span></div>${er('priority')}</div>
      <div class="card flat"><strong class="small">${th('handling')}</strong>
        ${switchHtml('bx_fragile', d.fragile, t('fragile'), th('fragileSub'), { attrs: 'data-draftbool="box.fragile"' })}
        ${switchHtml('bx_floor', d.floorOnly, t('floorOnly'), th('floorSub'), { attrs: 'data-draftbool="box.floorOnly"' })}
        ${switchHtml('bx_stack', d.stackable && !d.fragile, t('stackable'), d.fragile ? `${ic('lock', 'sm')} ${th('stackLocked')}` : th('stackSub'), { disabled: d.fragile, attrs: 'data-draftbool="box.stackable"' })}
        ${d.stackable && !d.fragile ? `<div class="field" style="margin-top:8px"><label for="bx_stacking">${th('onTop')}</label>
          <select class="input" id="bx_stacking" data-draft="box.stacking">${['any', 'same', 'other'].map(k => `<option value="${k}" ${d.stacking === k ? 'selected' : ''}>${th('stack_' + k)}</option>`).join('')}</select></div>
          ${numField('loadBearing', t('loadBearing') + ' · ' + t('optional'), 'kg')}` : ''}
      </div>
      <div class="card flat"><div class="lbl">${th('idPreview')}</div><div class="mono ltr" style="margin-top:4px">${esc(preview)}</div>
        <p class="xs muted" style="margin:5px 0 0">${th(editing ? 'idPreviewEdit' : 'idPreviewNote', { code })}</p></div>
      ${show && Object.keys(errs).length ? `<p class="errtxt" role="alert">${th('fixErrors')}</p>` : ''}
      <button class="btn primary block" type="submit">${ic('check', 'sm')}${th(editing ? 'saveChanges' : 'addToShipment')}</button>
      <button class="btn ghost block" type="button" style="margin-top:8px" data-act="cancelBox">${th('cancel')}</button>
    </form>`
  };
};

/* ---------- import ---------- */
const TEMPLATE_FIELDS = ['kind', 'custom', 'contents', 'length_cm', 'width_cm', 'height_cm', 'weight_kg', 'quantity', 'priority', 'orientation', 'fragile', 'floor_only', 'stackable', 'stacking', 'load_bearing_kg'];
function groupToRow(g) { return [g.kind, g.custom || '', g.contents || '', g.l, g.w, g.h, g.kg, g.qty, g.priority, g.orientation, g.fragile ? 'yes' : 'no', g.floorOnly ? 'yes' : 'no', g.stackable ? 'yes' : 'no', g.stackable ? g.stacking : '', g.loadBearing || '']; }
function sampleRows() { return DEMO.groups.map(g => { const r = groupToRow(g); if (g.code === 'B03') r[4] = -50; return r; }); }
function templateRows() { return [TEMPLATE_FIELDS, groupToRow({ kind: 'electronics', custom: '', contents: 'Example: monitors', l: 80, w: 60, h: 55, kg: 24, qty: 10, priority: 1, orientation: 'upright', fragile: true, floorOnly: false, stackable: false, stacking: '', loadBearing: '' })]; }
const KIND_ALIASES = { 'iron & metal': 'iron_metal', 'iron and metal': 'iron_metal', iron: 'iron_metal', metal: 'iron_metal', 'wood & furniture': 'wood_furniture', wood: 'wood_furniture', furniture: 'wood_furniture', 'إلكترونيات': 'electronics', 'زجاج': 'glass', 'حديد ومعادن': 'iron_metal', 'آلات': 'machinery', 'خشب وأثاث': 'wood_furniture', 'أغذية': 'food', 'منسوجات': 'textiles', 'ورق': 'paper', 'أخرى': 'other' };
function normKind(v) { const s = String(v || '').trim().toLowerCase(); if (KINDS.includes(s)) return s; if (KIND_ALIASES[s]) return KIND_ALIASES[s]; const u = s.replace(/[\s&]+/g, '_').replace(/_+/g, '_'); return KINDS.includes(u) ? u : s; }
const truthy = v => ['yes', 'true', '1', 'y', 'نعم', 'x'].includes(String(v).trim().toLowerCase());
function rowsToDrafts(rows) {
  if (!rows.length) return [];
  const head = rows[0].map(h => String(h).trim().toLowerCase());
  const hasHead = head.includes('kind') || head.includes('length_cm');
  const idx = f => hasHead ? head.indexOf(f) : TEMPLATE_FIELDS.indexOf(f);
  const get = (r, f) => { const i = idx(f); return i < 0 ? '' : (r[i] ?? ''); };
  const numOrRaw = v => { const s = String(v).trim(); if (s === '') return ''; const n = Number(s.replace(',', '.')); return isFinite(n) ? n : s; };
  return rows.slice(hasHead ? 1 : 0).map((r, i) => {
    const stack = truthy(get(r, 'stackable'));
    const lb = numOrRaw(get(r, 'load_bearing_kg'));
    return {
      row: i + (hasHead ? 2 : 1), kind: normKind(get(r, 'kind')), custom: String(get(r, 'custom')).trim(), contents: String(get(r, 'contents')).trim(),
      l: numOrRaw(get(r, 'length_cm')), w: numOrRaw(get(r, 'width_cm')), h: numOrRaw(get(r, 'height_cm')), kg: numOrRaw(get(r, 'weight_kg')),
      qty: numOrRaw(get(r, 'quantity')), priority: numOrRaw(get(r, 'priority')) === '' ? 1 : numOrRaw(get(r, 'priority')),
      orientation: (String(get(r, 'orientation')).trim().toLowerCase() || 'any'), fragile: truthy(get(r, 'fragile')), floorOnly: truthy(get(r, 'floor_only')),
      stackable: stack, stacking: stack ? (String(get(r, 'stacking')).trim().toLowerCase() || 'any') : 'any', loadBearing: stack && lb !== '' ? lb : null
    };
  });
}
const draftErrors = d => groupErrors(d);
function fixable(d) {
  const e = draftErrors(d); const keys = Object.keys(e); if (!keys.length) return false;
  return keys.every(k => (['l', 'w', 'h', 'kg', 'loadBearing'].includes(k) && typeof d[k] === 'number' && d[k] < 0) || (k === 'qty' && typeof d.qty === 'number' && d.qty !== 0) || (k === 'priority' && typeof d.priority === 'number') || (k === 'stackable'));
}
function fixDraft(d) {
  for (const k of ['l', 'w', 'h', 'kg', 'loadBearing']) if (typeof d[k] === 'number' && d[k] < 0) d[k] = Math.abs(d[k]);
  if (typeof d.qty === 'number') d.qty = Math.max(1, Math.round(Math.abs(d.qty)));
  if (typeof d.priority === 'number') d.priority = Math.min(9, Math.max(1, Math.round(d.priority)));
  if (d.fragile && d.stackable) d.stackable = false;
  return d;
}
function importSummary(rows) { let boxes = 0; for (const r of rows) { const q = Number(r.qty); if (isFinite(q) && q > 0) boxes += Math.floor(q); } return { boxes, types: rows.length, bad: rows.filter(r => Object.keys(draftErrors(r)).length).length }; }
PAGES.import = () => {
  const im = S.drafts.import;
  const disabledOpt = (icon, label) => `<div class="row-btn disabled-opt" aria-disabled="true"><span style="color:var(--muted)">${ic(icon)}</span><span class="grow">${esc(label)}</span><span class="chip next">${th('nextTerm')}</span></div>`;
  let body = `<p class="muted small">${th('importIntro')}</p>
    <label class="btn primary block" style="position:relative">${ic('upload', 'sm')}${th('chooseFile')}<input type="file" accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" data-act-change="importFile" style="position:absolute;inset:0;opacity:0;cursor:pointer" aria-label="${th('chooseFile')}"></label>
    <div class="grid2" style="margin-top:8px"><button class="btn" data-act="loadSample">${ic('file', 'sm')}${th('loadSample')}</button><button class="btn" data-act="openTemplates">${ic('download', 'sm')}${th('templates')}</button></div>
    <div class="list" style="margin-top:10px">${disabledOpt('file', t('pdfUpload'))}${disabledOpt('camera', t('cameraMeasure'))}${disabledOpt('barcode', t('barcodeScan'))}</div>`;
  if (im && im.rows) {
    const sm = importSummary(im.rows);
    const view = im.view || 'list';
    body += `<div class="hr"></div>
      <div class="card ${sm.bad ? 'warn' : 'ok'}"><div class="row">${ic(sm.bad ? 'warn' : 'check')}<strong class="grow">${th('inventoryComplete', { b: sm.boxes, t: sm.types })}</strong></div>
        <p class="xs muted" style="margin:6px 0 0">${th('readFrom', { f: im.fileName })}${sm.bad ? ' · ' + th('rowsNeedAttention', { n: sm.bad }) : ' · ' + th('allRowsValid')}</p>
        ${im.autoStopped && sm.bad ? `<p class="small" style="margin:6px 0 0;color:var(--warn)">${th('autoStopped')}</p>` : ''}</div>
      ${segHtml('importView', view, [{ v: 'list', label: t('reviewList'), icon: 'list' }, { v: 'one', label: t('reviewOne'), icon: 'edit' }], t('reviewMode'))}
      <div style="margin-top:10px">${view === 'list' ? importList(im) : importOne(im)}</div>
      <div class="field" style="margin-top:6px"><span class="lbl">${th('importInto')}</span>${segHtml('importMode', im.mode || 'replace', [{ v: 'replace', label: t('replaceInv') }, { v: 'append', label: t('appendInv') }], t('importInto'))}</div>
      <button class="btn primary block" data-act="confirmImport" ${sm.bad || !im.rows.length ? 'disabled' : ''}>${ic('check', 'sm')}${th('confirmImport')}</button>
      <p class="xs muted" style="margin-top:6px">${S.prefs.autoImport ? th('autoImportOn') : th('autoImportOff')}</p>`;
  }
  return { title: t('importReview'), body };
};
function importList(im) {
  return `<div class="list">${im.rows.map((r, i) => {
    const e = draftErrors(r); const bad = Object.keys(e).length; const code = 'B' + pad2(i + 1);
    return `<div class="row-btn ${bad ? 'err' : ''}" style="flex-direction:column;align-items:stretch;cursor:default">
      <div class="row"><span class="mono ltr">${esc(code)}</span><span class="grow small">${esc(r.contents || t('kind_' + r.kind) || r.kind)}</span><span class="xs muted">${th('rowN', { n: r.row })}</span>
        <span class="chip ${bad ? 'bad' : 'ok'}">${th(bad ? 'needsFix' : 'valid')}</span></div>
      <div class="xs muted ltr" style="text-align:start">${['l', 'w', 'h'].map(f => e[f] ? `<b style="color:var(--danger)">${esc(r[f])}</b>` : esc(r[f])).join(' × ')} cm · ${esc(r.kg)} kg · ×${esc(r.qty)}</div>
      ${bad ? `<div class="xs" style="color:var(--danger)">${Object.entries(e).map(([f, k]) => esc(t('field_' + f) + ': ' + t(k))).join(' · ')}</div>
        <div class="row" style="justify-content:flex-end">${fixable(r) ? `<button class="btn sm primary" data-act="fixRow" data-i="${i}">${ic('check', 'sm')}${th('oneTapFix', { v: fixPreview(r) })}</button>` : ''}
        <button class="btn sm" data-act="editRow" data-i="${i}">${ic('edit', 'sm')}${th('edit')}</button></div>` : ''}
    </div>`;
  }).join('')}</div>`;
}
function fixPreview(r) { const c = fixDraft(clone(r)); const e = draftErrors(r); const f = Object.keys(e)[0]; return f === 'stackable' ? t('stackOff') : `${t('field_' + f)} → ${c[f]}`; }
function importOne(im) {
  const i = Math.min(im.idx || 0, im.rows.length - 1); const r = im.rows[i]; const e = draftErrors(r);
  const inp = (f, lbl, unit) => `<div class="field"><label for="ir_${f}">${esc(lbl)}${unit ? ` <span class="xs">(${unit})</span>` : ''}</label><input class="input ltr ${e[f] ? 'err' : ''}" id="ir_${f}" data-draft="import.rows.${i}.${f}" data-num="1" data-rerender="blur" value="${esc(r[f] ?? '')}">${e[f] ? `<span class="errtxt">${th(e[f])}</span>` : ''}</div>`;
  return `<div class="card ${Object.keys(e).length ? 'bad' : ''}">
    <div class="row between" style="margin-bottom:8px"><strong class="mono ltr">B${pad2(i + 1)}</strong><span class="xs muted">${th('rowOf', { i: i + 1, n: im.rows.length })}</span></div>
    <div class="field"><label for="ir_kind">${th('category')}</label><select class="input ${e.kind ? 'err' : ''}" id="ir_kind" data-draft="import.rows.${i}.kind" data-rerender="1">${KINDS.map(k => `<option value="${k}" ${r.kind === k ? 'selected' : ''}>${th('kind_' + k)}</option>`).join('')}${KINDS.includes(r.kind) ? '' : `<option selected value="${esc(r.kind)}">${esc(r.kind || '—')}</option>`}</select></div>
    <div class="field"><label for="ir_contents">${th('contents')}</label><input class="input" id="ir_contents" data-draft="import.rows.${i}.contents" value="${esc(r.contents)}"></div>
    <div class="grid3">${inp('l', t('lengthL'), 'cm')}${inp('w', t('widthW'), 'cm')}${inp('h', t('heightH'), 'cm')}</div>
    <div class="grid3">${inp('kg', t('weightEach'), 'kg')}${inp('qty', t('quantity'))}${inp('priority', t('priority'))}</div>
    <p class="xs muted">${esc(rulesText(Object.assign({ stacking: 'any' }, r)))}</p>
    ${fixable(r) ? `<button class="btn sm primary" data-act="fixRow" data-i="${i}">${ic('check', 'sm')}${th('oneTapFix', { v: fixPreview(r) })}</button>` : ''}
    <div class="grid2" style="margin-top:10px">
      <button class="btn" data-act="importStep" data-d="-1" ${i <= 0 ? 'disabled' : ''}>${ic('back', 'flip sm')}${th('previous')}</button>
      <button class="btn" data-act="importStep" data-d="1" ${i >= im.rows.length - 1 ? 'disabled' : ''}>${th('next')}${ic('next', 'flip sm')}</button></div>
  </div>`;
}

/* ---------- all boxes / details ---------- */
function boxStatus(b) {
  const st = inputStatus(b.g, cont());
  const p = S.plan; let out = null;
  if (st.status === 'accepted' && p && p.gen && p.gen.status !== 'none') { const o = layoutFor(p.mode).outcome[b.id]; if (o) out = o; }
  return { input: st, out };
}
PAGES.boxes = () => {
  const f = UI.boxes; const q = f.q.trim().toLowerCase();
  let list = expandBoxes(S.shipment).filter(b => (!q || b.id.toLowerCase().includes(q) || (b.g.contents || '').toLowerCase().includes(q) || (b.g.custom || '').toLowerCase().includes(q)) && (!f.cat || b.g.kind === f.cat) && (!f.code || b.g.code === f.code));
  const sorters = { old: (a, b) => a.added - b.added || (a.id < b.id ? -1 : 1), new: (a, b) => b.added - a.added || (a.id < b.id ? 1 : -1), id: (a, b) => (a.id < b.id ? -1 : 1), contents: (a, b) => (a.g.contents || '').localeCompare(b.g.contents || '') || (a.id < b.id ? -1 : 1) };
  list.sort(sorters[f.sort] || sorters.old);
  const kinds = [...new Set(S.shipment.groups.map(g => g.kind))];
  return {
    title: t('allBoxes'),
    body: `<div class="field"><label for="bq" class="sr">${th('search')}</label><div class="row" style="position:relative"><input class="input" id="bq" type="search" placeholder="${th('searchPh')}" data-ui="boxes.q" data-live="1" value="${esc(f.q)}"></div></div>
    <div class="grid3">
      <div class="field"><label for="bcat">${th('category')}</label><select class="input" id="bcat" data-ui="boxes.cat" data-rerender="1"><option value="">${th('all')}</option>${kinds.map(k => `<option value="${k}" ${f.cat === k ? 'selected' : ''}>${th('kind_' + k)}</option>`).join('')}</select></div>
      <div class="field"><label for="bcode">${th('groupCode')}</label><select class="input" id="bcode" data-ui="boxes.code" data-rerender="1"><option value="">${th('all')}</option>${S.shipment.groups.map(g => `<option value="${g.code}" ${f.code === g.code ? 'selected' : ''}>${g.code}</option>`).join('')}</select></div>
      <div class="field"><label for="bsort">${th('sort')}</label><select class="input" id="bsort" data-ui="boxes.sort" data-rerender="1">${['old', 'new', 'id', 'contents'].map(k => `<option value="${k}" ${f.sort === k ? 'selected' : ''}>${th('sort_' + k)}</option>`).join('')}</select></div>
    </div>
    <p class="xs muted" id="boxcount">${th('nBoxesShown', { n: list.length, t: shipmentTotals(S.shipment).boxes })}</p>
    <div class="list" id="boxlist">${list.map(b => { const s = boxStatus(b); return `<button class="row-btn" data-act="nav" data-route="box" data-id="${b.id}">${sw(b.g.code)}<span class="grow"><span class="mono ltr" style="display:block">${esc(b.id)}</span><span class="sub">${esc(b.g.contents || kindLabel(b.g))} · ${esc(kindLabel(b.g))}</span></span>
      <span class="stack" style="align-items:flex-end;gap:4px"><span class="chip ${s.input.status === 'accepted' ? 'ok' : 'bad'}">${th(s.input.status)}</span>${s.out ? `<span class="chip ${s.out.status === 'loaded' ? 'cyan' : 'warn'}">${th(s.out.status)}</span>` : ''}</span></button>`; }).join('') || `<div class="empty">${th('noMatches')}</div>`}</div>`
  };
};
PAGES.box = () => {
  const b = expandBoxes(S.shipment).find(x => x.id === S.params.id);
  if (!b) return { title: t('boxDetails'), body: `<div class="empty">${th('boxNotFound')}</div>` };
  const g = b.g; const s = boxStatus(b); const pl = s.out && s.out.placement;
  const mode = S.plan && S.plan.mode;
  return {
    title: t('boxDetails'),
    body: `<div class="card glow"><div class="row">${sw(g.code)}<strong class="mono ltr grow" style="font-size:17px">${esc(b.id)}</strong></div>
      <div class="row wrap" style="margin-top:8px"><span class="chip ${s.input.status === 'accepted' ? 'ok' : 'bad'}">${th('inputStatus')}: ${th(s.input.status)}</span>${s.out ? `<span class="chip ${s.out.status === 'loaded' ? 'cyan' : 'warn'}">${th('illusOutcome', { m: t(mode) })}: ${th(s.out.status)}</span>` : ''}</div></div>
    <div class="card"><dl class="kv">
      <dt>${th('category')}</dt><dd>${esc(kindLabel(g))}</dd>
      <dt>${th('contents')}</dt><dd>${esc(g.contents || '—')}</dd>
      <dt>${th('groupCode')}</dt><dd class="mono ltr">${esc(g.code)}</dd>
      <dt>${th('dimensions')}</dt><dd>${ltr(dims(g))}</dd>
      <dt>${th('weight')}</dt><dd>${ltr(nfx(g.kg) + ' kg')}</dd>
      <dt>${th('rules')}</dt><dd>${esc(rulesText(g))}</dd>
      <dt>${th('priority')}</dt><dd>${th('priorityN', { n: g.priority })}</dd>
      <dt>${th('position')}</dt><dd>${pl ? ltr(`x ${nfx(pl.x0 / 10, 1)} · y ${nfx(pl.y0 / 10, 1)} · z ${nfx(pl.z0 / 10, 1)} cm`) : '—'}</dd>
      <dt>${th('placedOrientation')}</dt><dd>${pl ? ltr(`${nfx(pl.dx / 10, 1)} × ${nfx(pl.dy / 10, 1)} × ${nfx(pl.dz / 10, 1)} cm`) : '—'}</dd>
      <dt>${th('loadingOrder')}</dt><dd>${pl ? ltr('#' + pl.order + ' · ' + t('layerN', { n: pl.layer })) : '—'}</dd>
      <dt>${th('reason')}</dt><dd>${s.input.status === 'rejected' ? esc(reasonText(s.input.reason, g)) : s.out && s.out.reason ? esc(reasonText(s.out.reason, g)) : '—'}</dd>
    </dl>${pl ? `<p class="xs muted" style="margin:8px 0 0">${th(layoutFor(mode).source === 'engine' ? 'posEngine' : 'posIllustrative')}</p>` : ''}</div>
    <div class="grid2"><button class="btn" data-act="editGroup" data-code="${g.code}">${ic('edit', 'sm')}${th('editGroup')}</button>
      <button class="btn" data-act="showIn3d" data-id="${b.id}" ${pl ? '' : 'disabled'}>${ic('box', 'sm')}${th('showIn3d')}</button></div>`
  };
};

/* ---------- review inputs ---------- */
PAGES.review = () => {
  const c = cont(); const tt = shipmentTotals(S.shipment); const cv = containerVolume(c);
  const rejected = []; let accepted = 0;
  for (const b of expandBoxes(S.shipment)) { const st = inputStatus(b.g, c); if (st.status === 'rejected') rejected.push({ id: b.id, g: b.g, reason: st.reason }); else accepted++; }
  const over = tt.vol > cv; const heavy = tt.kg > c.payload;
  return {
    title: t('reviewInputs'),
    body: `<div class="grid2">
      <button class="metric row-btn" style="align-items:flex-start;flex-direction:column" data-act="nav" data-route="container"><span class="k">${ic('container', 'sm')}${th('container')}</span><span class="v ltr">${esc(c.code)}</span><span class="s ltr">${nfx(c.L / 10, 1)} × ${nfx(c.W / 10, 1)} × ${nfx(c.H / 10, 1)} cm</span></button>
      <button class="metric row-btn tip" style="align-items:flex-start;flex-direction:column" data-act="nav" data-route="boxes" title="${th('reviewTheBoxes')}"><span class="bubble">${th('reviewTheBoxes')}</span><span class="k">${ic('box', 'sm')}${th('boxCount')}</span><span class="v">${nf(tt.boxes)}</span><span class="s">${rejected.length ? th('nRejected', { n: rejected.length }) : th('allAccepted')} · ${th('reviewTheBoxes')}</span></button>
      ${metric('weight', t('totalWeight'), `${nf(tt.kg)} <span class="xs muted">kg</span>`, th('ofPayload', { p: nf(c.payload) }))}
      ${metric('layers', t('totalVolume'), `${nfx(tt.vol, 2)} <span class="xs muted">m³</span>`, th('ofCapacity', { c: nfx(cv, 2) }))}
    </div>
    <h2>${th('checks')}</h2>
    ${over ? notice('warn', 'warn', th('overCapacity', { v: nfx(tt.vol, 2), c: nfx(cv, 2), p: nfx(tt.vol / cv * 100, 1) })) : notice('ok', 'check', th('volumeOk'))}
    ${heavy ? notice('bad', 'warn', th('overPayload')) : notice('ok', 'check', th('payloadOk', { kg: nf(tt.kg), p: nf(c.payload) }))}
    ${rejected.length ? notice('bad', 'x', `<strong>${th('rejectedTitle', { n: rejected.length })}</strong><br>${rejected.map(r => `${ltr(r.id)} — ${esc(reasonText(r.reason, r.g))}`).join('<br>')}`) : notice('ok', 'check', th('allAcceptedLong'))}
    <div class="card flat"><div class="row between"><span>${th('acceptedBoxes')}</span><strong>${nf(accepted)}</strong></div><div class="row between"><span>${th('rejectedBoxes')}</span><strong>${nf(rejected.length)}</strong></div></div>
    ${recFor('optimized') ? notice('', 'info', th('recordedAvailable')) : notice('warn', 'info', th('noRecordedForInput'))}
    <button class="btn primary block" data-act="approveData" ${tt.boxes && accepted ? '' : 'disabled'}>${ic('spark', 'sm')}${th(S.inventoryApproved ? 'generatePlan' : 'approveAndGenerate')}</button>`
  };
};

/* ---------- results ---------- */
PAGES.results = () => {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status === 'none') return { title: t('planResults'), body: `<div class="empty">${ic('spark')}<p>${th('noPlanYet')}</p><button class="btn primary" data-act="nav" data-route="review">${th('reviewInputs')}</button></div>` };
  const mode = p.mode; const rec = recFor(mode); const lay = layoutFor(mode);
  const optRec = recFor('optimized');
  let prog = '';
  if (p.gen.status === 'optimizing') {
    const f = optFraction();
    prog = `<div class="card glow" aria-live="polite"><div class="row">${ic('spark')}<strong class="grow">${th(optRec ? 'optimizingBeam' : 'optimizingPreview')}</strong><span class="xs muted ltr" id="optpct">${Math.round(f * 100)}%</span></div>
      <div class="progress" style="margin:9px 0"><i id="optbar" style="width:${(f * 100).toFixed(1)}%"></i></div>
      <p class="xs muted">${th(optRec ? 'optimizingNote' : 'optimizingPreviewNote', { t: nfx(RECORDED.optimized.timeMs / 1000, 1) })}</p>
      <button class="btn block" data-act="keepInstant">${ic('bolt', 'sm')}${th('keepInstant')}</button></div>`;
  } else if (p.gen.status === 'kept') {
    prog = notice('', 'bolt', `${th('instantKept')} <button class="btn sm ghost" data-act="rerunOpt">${th('runOptAgain')}</button>`);
  }
  const M = metricsFor(mode); const unpl = M.unplaced.v;
  const infoBtn = `<button class="iconbtn info" data-act="unloadInfo" aria-label="${th('unloadInfoAria')}">${ic('info', 'sm')}</button>`;
  const V = lay.validation;
  return {
    title: t('planResults'),
    body: `${prog}
    ${segHtml('planMode', mode, [{ v: 'instant', label: t('instant'), icon: 'bolt' }, { v: 'optimized', label: t('optimized'), icon: 'spark', disabled: !genReady('optimized') }], t('planMode'))}
    <div style="margin-top:10px">${viewerHtml('results', 208, geoTag(lay), false)}</div>
    <p class="xs muted srcline">${M.rec ? `${srcBadge('rec')} ${th('srcRecLineAll')}` : `${srcBadge('prev')} ${th('srcPrevLine')}`}</p>
    <div class="grid2">
      ${metric('gauge', t('mUtil'), ltr(`${nfx(M.util.v, 1)}%`), (M.rec ? th('engineName', { e: M.rec.engine }) + ' ' : '') + srcBadge(M.util.src))}
      ${metric('box', t('mLoaded'), `${M.loaded.v} <span class="xs muted">${th('ofN', { n: M.loaded.t })}</span>`, th('unplacedN', { n: M.unplaced.v }) + ' ' + srcBadge(M.loaded.src))}
      ${metric('clock', t('mTime'), ltr(fmtTime(M.time.v)), (M.rec ? th(mode === 'optimized' ? 'budgetNote' : 'instantNote') + ' ' : '') + srcBadge(M.time.src))}
      ${metric('door', t('mUnload'), ltr(`${nfx(M.unload.v, 1)}%`), th('lowerBetter') + ' ' + srcBadge(M.unload.src), infoBtn)}
    </div>
    <div class="card ${M.valid.ok ? 'ok' : 'bad'}"><div class="row">${ic('shield')}<strong class="grow">${th('validator')}</strong></div>
      <div class="row wrap" style="margin-top:6px">${M.rec ? `<span class="chip ok">${ic('check', 'sm')}${th('engineValid')}</span>` : ''}${M.rec ? '' : `<span class="chip ${V.ok ? 'ok' : 'bad'}">${ic(V.ok ? 'check' : 'x', 'sm')}${th('prevValid', { n: V.passed })}</span>`}</div>
      <button class="btn sm ghost" style="margin-top:6px" data-act="toggleChecks" aria-expanded="${UI.showChecks}">${th(UI.showChecks ? 'hideChecks' : 'showChecks')}</button>
      ${UI.showChecks ? `<ul class="small" style="margin:6px 0 0;padding-inline-start:18px">${VALIDATOR_CHECKS.map(k => `<li><span class="mono">${k}</span> — ${th('chk_' + k)} <span style="color:${V[k] ? 'var(--green)' : 'var(--danger)'}">${V[k] ? '✓' : '✗'}</span></li>`).join('')}</ul><p class="xs muted" style="margin-top:6px">${th(lay.source === 'engine' ? 'validatorEngineNote' : 'validatorPrevNote')}</p>` : ''}</div>
    <div class="list">
      ${linkRow('box', t('full3d'), th('full3dSub'), 'nav', 'data-route="viewer"')}
      ${linkRow('warn', t('unplacedBoxes'), th('unplacedSub', { n: unpl }), 'nav', 'data-route="unplaced"')}
      ${linkRow('steps', t('loadingSteps'), th('stepsSub', { n: lay.loaded }), 'nav', 'data-route="steps"')}
      ${linkRow('chart', t('manualComparison'), th('compareSub'), 'nav', 'data-route="compare"')}
      ${linkRow('download', t('export'), th('exportSub'), 'nav', 'data-route="export"')}
    </div>
    <div style="margin-top:12px">${p.approved ? `<div class="card ok"><div class="row">${ic('check')}<strong class="grow">${th(p.autoApproved ? 'approvedAuto' : 'approved')}</strong><span class="chip">${ltr(p.id)}</span></div><p class="xs muted" style="margin:5px 0 0">${th(p.autoApproved ? 'approvedAutoNote' : 'approvedNote')}</p></div>`
      : `<button class="btn primary block" data-act="approvePlan" ${p.gen.status === 'optimizing' ? 'disabled' : ''}>${ic('check', 'sm')}${th('approvePlan')}</button>${p.gen.status === 'optimizing' ? `<p class="xs muted" style="margin-top:5px">${th('approveWait')}</p>` : ''}${S.prefs.alwaysAuto ? `<p class="xs muted" style="margin-top:5px">${th('alwaysAutoHint')}</p>` : ''}`}</div>`
  };
};

/* ---------- full 3D viewer ---------- */
PAGES.viewer = () => {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status === 'none') return { title: t('full3d'), body: `<div class="empty">${th('noPlanYet')}</div>` };
  const lay = layoutFor(p.mode); const v = UI.viewer; const cam = Scenes.getCam('viewer');
  if (v.selected && !lay.byId[v.selected]) v.selected = null;
  const selP = v.selected && lay.byId[v.selected]; const selVisible = selP && !v.hidden[selP.gcode] && (!v.layer || selP.layer <= v.layer);
  if (selP && !selVisible) v.selected = null;
  const sel = v.selected ? expandBoxes(S.shipment).find(b => b.id === v.selected) : null;
  const codes = [...new Set(lay.placements.map(x => x.gcode))];
  return {
    title: t('full3d'),
    body: `<div style="margin-bottom:8px">${segHtml('camMode', cam.mode, [{ v: 'orbit', label: t('orbitView'), icon: 'orbit' }, { v: 'inside', label: t('insideView'), icon: 'inside' }], t('viewMode'))}</div>
    ${viewerHtml('viewer', 325, geoTag(lay, t(p.mode)), true)}
    ${cam.mode === 'inside' ? `<div class="field" style="margin-top:8px"><label for="insideRange">${th('walkSlider')}</label><input type="range" class="range" id="insideRange" min="0" max="100" value="${Math.round(cam.insideT * 100)}" data-act-input="inside"><div class="row between xs muted"><span>${th('atDoor')}</span><span>${th('atBack')}</span></div></div>`
      : `<p class="xs muted" style="margin:6px 0">${th('viewerHelp')}</p>`}
    ${sel ? (() => { const pl = lay.byId[sel.id]; return `<div class="card glow" aria-live="polite"><div class="row">${sw(sel.g.code)}<strong class="mono ltr grow">${esc(sel.id)}</strong><button class="iconbtn" data-act="clearSel" aria-label="${th('close')}">${ic('x', 'sm')}</button></div>
      <dl class="kv" style="margin-top:6px"><dt>${th('category')}</dt><dd>${esc(kindLabel(sel.g))}</dd><dt>${th('contents')}</dt><dd>${esc(sel.g.contents || '—')}</dd>
      <dt>${th('position')}</dt><dd>${ltr(`x ${nfx(pl.x0 / 10, 1)} · y ${nfx(pl.y0 / 10, 1)} · z ${nfx(pl.z0 / 10, 1)} cm`)}</dd>
      <dt>${th('placedOrientation')}</dt><dd>${ltr(`${nfx(pl.dx / 10, 1)} × ${nfx(pl.dy / 10, 1)} × ${nfx(pl.dz / 10, 1)} cm`)}</dd>
      <dt>${th('weight')}</dt><dd>${ltr(nfx(sel.g.kg) + ' kg')}</dd><dt>${th('rules')}</dt><dd>${esc(rulesText(sel.g))}</dd>
      <dt>${th('priority')}</dt><dd>${th('priorityN', { n: sel.g.priority })}</dd><dt>${th('loadingOrder')}</dt><dd>${ltr('#' + pl.order + ' · ' + t('layerN', { n: pl.layer }))}</dd></dl>
      <button class="btn sm block" style="margin-top:8px" data-act="nav" data-route="box" data-id="${sel.id}">${th('allDetails')}</button></div>`; })() : ''}
    <div class="card flat">
      ${switchHtml('sw_labels', v.labels, t('idLabels'), th('idLabelsSub'), { attrs: 'data-act-change="labels"' })}
      <div class="field" style="margin:8px 0 4px"><label for="layerSel">${th('layers')}</label><select class="input" id="layerSel" data-act-change="layer"><option value="0">${th('allLayers')}</option>${Array.from({ length: lay.layers }, (_, i) => `<option value="${i + 1}" ${v.layer === i + 1 ? 'selected' : ''}>${th('upToLayer', { n: i + 1 })}</option>`).join('')}</select></div>
      <div class="lbl" style="margin:8px 0 6px">${th('groupsVisible')}</div>
      <div class="legend">${codes.map(c => `<button class="chip-btn" data-act="toggleGroup" data-code="${c}" aria-pressed="${!v.hidden[c]}">${sw(c)}<span class="mono ltr">${c}</span></button>`).join('')}</div>
    </div>`
  };
};

/* ---------- unplaced ---------- */
PAGES.unplaced = () => {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status === 'none') return { title: t('unplacedBoxes'), body: `<div class="empty">${th('noPlanYet')}</div>` };
  const rec = recFor(p.mode); const lay = layoutFor(p.mode);
  const groups = {};
  for (const b of expandBoxes(S.shipment)) { const o = lay.outcome[b.id]; if (!o || o.status === 'loaded') continue; const k = b.g.code + '|' + o.status + '|' + o.reason; (groups[k] = groups[k] || { g: b.g, status: o.status, reason: o.reason, ids: [] }).ids.push(b.id); }
  const list = Object.values(groups);
  return {
    title: t('unplacedBoxes'),
    body: `${rec ? `<div class="card"><div class="row">${ic('gauge')}<strong class="grow">${th('engineAggregate')}</strong><span class="big">${rec.unplaced}</span></div><p class="xs muted" style="margin:6px 0 0">${th('engineAggregateNote', { e: rec.engine, l: rec.loaded, t: rec.total })} ${srcBadge('rec')}</p></div>` : `<div class="card"><div class="row">${ic('gauge')}<strong class="grow">${th('prevAggregate')}</strong><span class="big">${lay.unplaced + lay.rejected}</span></div><p class="xs muted" style="margin:6px 0 0">${th('prevAggregateNote', { l: lay.loaded, t: lay.total })} ${srcBadge('prev')}</p></div>`}
    <h2>${th(lay.source === 'engine' ? 'engineOutcomes' : 'illusOutcomes')}</h2>
    <p class="xs muted">${th(lay.source === 'engine' ? 'engineOutcomesNote' : 'illusOutcomesNote', { n: lay.unplaced + lay.rejected, m: t(p.mode) })}</p>
    ${list.length ? list.map((u, i) => {
      const k = u.g.code + u.reason; const open = UI.expandUnplaced[k]; const ids = open ? u.ids : u.ids.slice(0, 8);
      return `<div class="card"><div class="row">${sw(u.g.code)}<strong class="mono ltr">${esc(u.g.code)}</strong><span class="grow small">${esc(u.g.contents || kindLabel(u.g))}</span><span class="chip ${u.status === 'rejected' ? 'bad' : 'warn'}">${nf(u.ids.length)} · ${th(u.status)}</span></div>
        <p class="small" style="margin:8px 0">${esc(reasonText(u.reason, u.g))}</p>
        <div class="idchips">${ids.map(id => `<span class="chip">${esc(id)}</span>`).join('')}${u.ids.length > 8 ? `<button class="chip-btn" data-act="expandU" data-k="${esc(k)}">${th(open ? 'showLess' : 'showMoreN', { n: u.ids.length - 8 })}</button>` : ''}</div>
        <div class="grid2" style="margin-top:10px"><button class="btn sm" data-act="editGroup" data-code="${u.g.code}">${ic('edit', 'sm')}${th('editBox')}</button><button class="btn sm" data-act="nav" data-route="container">${ic('container', 'sm')}${th('changeContainer')}</button></div></div>`;
    }).join('') : notice('ok', 'check', th('allPlacedIllus'))}`
  };
};

/* ---------- loading steps ---------- */
function stepsLayout() { return layoutFor(S.plan.mode); }
PAGES.steps = () => {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status === 'none') return { title: t('loadingSteps'), body: `<div class="empty">${th('noPlanYet')}</div>` };
  const lay = stepsLayout(); const N = lay.placements.length;
  if (UI.steps.mode !== p.mode) { UI.steps.mode = p.mode; UI.steps.i = 1; }
  UI.steps.i = Math.max(1, Math.min(N || 1, UI.steps.i));
  return {
    title: t('loadingSteps'),
    body: N ? `${viewerHtml('steps', 270, geoTag(lay, t(p.mode)), true)}
    <div class="card" style="margin-top:10px" aria-live="polite" id="stepinfo">${stepInfoHtml(lay)}</div>
    <input type="range" class="range" min="1" max="${N}" value="${UI.steps.i}" id="stepRange" data-act-input="step" aria-label="${th('stepSlider')}">
    <div class="grid3" style="margin-top:6px">
      <button class="btn" data-act="stepMove" data-d="-1" aria-label="${th('previous')}">${ic('back', 'flip sm')}${th('previous')}</button>
      <button class="btn primary" data-act="stepPlay" id="playBtn">${UI.steps.playing ? ic('pause', 'sm') + th('pause') : ic('play', 'sm') + th('play')}</button>
      <button class="btn" data-act="stepMove" data-d="1" aria-label="${th('next')}">${th('next')}${ic('next', 'flip sm')}</button></div>
    <p class="xs muted" style="margin-top:8px">${th('stepsNote')}</p>` : `<div class="empty">${th('nothingPlaced')}</div>`
  };
};
function stepInfoHtml(lay) {
  const pl = lay.placements[UI.steps.i - 1]; if (!pl) return '';
  const g = groupByCode(pl.gcode) || {};
  return `<div class="row between"><span class="small muted">${th('stepOf', { i: UI.steps.i, n: lay.placements.length })}</span><span class="chip">${th('layerN', { n: pl.layer })}</span></div>
    <div class="row" style="margin-top:6px">${sw(pl.gcode)}<strong class="mono ltr grow" style="font-size:16px">${esc(pl.id)}</strong></div>
    <p class="small" style="margin:6px 0 0">${ltr(`x ${nfx(pl.x0 / 10, 1)} · y ${nfx(pl.y0 / 10, 1)} · z ${nfx(pl.z0 / 10, 1)} cm`)} <span class="muted">· ${esc(g.contents || '')}</span></p>`;
}
function stepUpdate() {
  const lay = stepsLayout(); const info = $('#stepinfo'); if (info) info.innerHTML = stepInfoHtml(lay);
  const r = $('#stepRange'); if (r) r.value = UI.steps.i;
  const pb = $('#playBtn'); if (pb) pb.innerHTML = UI.steps.playing ? ic('pause', 'sm') + th('pause') : ic('play', 'sm') + th('play');
  Scenes.invalidate('steps');
}
function stopSteps() { UI.steps.playing = false; clearInterval(UI.steps.timer); UI.steps.timer = null; }
function toggleSteps() {
  const N = stepsLayout().placements.length;
  if (UI.steps.playing) { stopSteps(); stepUpdate(); return; }
  if (UI.steps.i >= N) UI.steps.i = 1;
  UI.steps.playing = true;
  UI.steps.timer = setInterval(() => { if (S.route !== 'steps') { stopSteps(); return; } if (UI.steps.i >= N) { stopSteps(); stepUpdate(); return; } UI.steps.i++; stepUpdate(); }, 650);
  stepUpdate();
}

/* ---------- comparison with the wall-building simulation of manual loading ---------- */
const signed = (v, d) => (v > 0 ? '+' : v < 0 ? '−' : '±') + nfx(Math.abs(v), d);
function donut(label, pct, color, sub) {
  const r = 52, C = 2 * Math.PI * r; const off = C * (1 - Math.max(0, Math.min(100, pct)) / 100);
  return `<div class="donut"><svg viewBox="0 0 132 132" role="img" aria-label="${esc(label)} ${nfx(pct, 1)}%"><circle class="bg" cx="66" cy="66" r="${r}" fill="none" stroke-width="13"/>
    <circle class="fg" cx="66" cy="66" r="${r}" fill="none" stroke="${color}" stroke-width="13" stroke-linecap="round" stroke-dasharray="${C.toFixed(2)}" stroke-dashoffset="${off.toFixed(2)}" style="--c:${C.toFixed(2)}"/>
    <text x="66" y="64" text-anchor="middle" fill="#F3F6FF" font-size="21" font-weight="700" direction="ltr">${nfx(pct, 1)}%</text><text x="66" y="84" text-anchor="middle" fill="#A0AFD1" font-size="11">${esc(sub)}</text></svg>
    <div style="font-weight:700;margin-top:2px">${esc(label)}</div></div>`;
}
function buildComparison(mode) {
  const M = metricsFor(mode); const W = layoutWall(S.shipment, S.container); const cv = containerVolume(cont());
  const sysVol = M.lay.source === 'engine' ? M.util.v / 100 * cv : M.lay.loadedVol;
  return {
    v: 2, id: null, t: Date.now(), planId: S.plan ? S.plan.id : null, container: S.container, shipment: S.shipment.code, mode, cv,
    manual: { util: W.util, volume: W.loadedVol, boxes: W.loaded, total: W.total, unload: W.unload, valid: W.validation.passed, src: W.source === 'engine' ? 'rec' : 'prev' },
    system: { engine: M.engine, util: M.util.v, volume: sysVol, boxes: M.loaded.v, total: M.loaded.t, unload: M.unload.v, valid: M.valid.n, engineValid: !!M.rec, src: M.util.src },
    diff: { pp: M.util.v - W.util, boxes: M.loaded.v - W.loaded, unload: M.unload.v - W.unload }
  };
}
function comparisonHtml(r) {
  if (r.v !== 2) return legacyComparisonHtml(r);
  const m = r.manual, s = r.system;
  const row = (k, a, b, d) => `<tr><td>${esc(k)}</td><td class="num">${a}</td><td class="num">${b}</td><td class="num">${d}</td></tr>`;
  return `<div class="donuts">${donut(t('manualSimShort'), m.util, '#FFC27A', t('utilShort'))}${donut(t('system'), s.util, '#63E7FF', t(r.mode))}</div>
    <div class="card" style="margin-top:10px"><div style="overflow-x:auto"><table class="table dark"><thead><tr><th></th><th style="color:#FFC27A">${th('manualSimShort')}</th><th style="color:var(--cyan)">${th('system')}</th><th>${th('difference')}</th></tr></thead><tbody>
      ${row(t('utilShort'), `${nfx(m.util, 1)}%`, `${nfx(s.util, 1)}%`, `${signed(r.diff.pp, 1)} ${esc(t('pp'))}`)}
      ${row(t('utilVolume'), `${nfx(m.volume, 2)} m³`, `${nfx(s.volume, 2)} m³`, `${signed(s.volume - m.volume, 2)} m³`)}
      ${row(t('mLoaded'), `${nf(m.boxes)} / ${nf(m.total)}`, `${nf(s.boxes)} / ${nf(s.total)}`, signed(r.diff.boxes, 0))}
      ${row(t('mUnload'), `${nfx(m.unload, 1)}%`, `${nfx(s.unload, 1)}%`, `${signed(r.diff.unload, 1)} ${esc(t('pp'))}`)}
      ${row(t('validator'), `${m.valid}/9`, `${s.valid}/9`, '—')}
    </tbody></table></div>
    <p class="xs muted" style="margin:8px 0 0">${th('manualSimShort')}: ${srcBadge(m.src || 'prev')} · ${th('system')}: ${srcBadge(s.src)}</p></div>
    <div class="lbl">${th('formulaTitle')}</div>
    <div class="formula">Utilization = loaded box volume ÷ inside container volume × 100</div>
    <div class="formula" style="margin-top:6px">${esc(t('manualSimShort'))}: ${nfx(m.volume, 2)} m³ ÷ ${nfx(r.cv, 2)} m³ × 100 = ${nfx(m.util, 1)}%</div>
    <div class="formula" style="margin-top:6px">${esc(t('system'))}: ${nfx(s.volume, 2)} m³ ÷ ${nfx(r.cv, 2)} m³ × 100 = ${nfx(s.util, 1)}%</div>
    <ul class="small" style="margin:10px 0;padding-inline-start:18px">
      <li>${th('sumUtil', { d: signed(r.diff.pp, 1) })}</li><li>${th('sumBoxes', { d: signed(r.diff.boxes, 0) })}</li><li>${th('sumUnload', { d: signed(r.diff.unload, 1) })}</li></ul>`;
}
function legacyComparisonHtml(r) {
  const m = r.manual, s = r.system;
  return `<div class="donuts">${donut(t('manual'), m.util, '#FFC27A', t('utilShort'))}${donut(t('system'), s.util, '#63E7FF', t(r.mode))}</div>
    <div class="card" style="margin-top:10px"><dl class="kv"><dt>${th('utilShort')}</dt><dd>${nfx(m.util, 1)}% → ${nfx(s.util, 1)}%</dd><dt>${th('mLoaded')}</dt><dd>${nf(m.boxes)} → ${nf(s.boxes)}</dd></dl></div>`;
}
PAGES.compare = () => {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status === 'none') return { title: t('manualComparison'), body: `<div class="empty">${th('noPlanYet')}</div>` };
  const d = S.drafts.compare && S.drafts.compare.container === S.container ? S.drafts.compare : (S.drafts.compare = { container: S.container, mode: genReady('optimized') ? 'optimized' : 'instant', savedId: null });
  if (!genReady(d.mode)) d.mode = 'instant';
  const r = buildComparison(d.mode); const W = layoutWall(S.shipment, S.container);
  return {
    title: t('manualComparison'),
    body: `<div class="card glow"><strong>${th('manualSim')}</strong><p class="small muted" style="margin:4px 0 0">${th('manualSimLine')}</p></div>
    <div class="field"><span class="lbl">${th('compareAgainst')}</span>${segHtml('cmpMode', d.mode, [{ v: 'instant', label: t('instant') }, { v: 'optimized', label: t('optimized'), disabled: !genReady('optimized') }], t('compareAgainst'))}</div>
    <div class="grid2 twin">
      <div><div class="lbl" style="margin-bottom:4px">${th('manualSimShort')}</div>${viewerHtml('cmpManual', 170, geoTag(W), false)}</div>
      <div><div class="lbl" style="margin-bottom:4px">${th('system')} · ${th(d.mode)}</div>${viewerHtml('cmpSystem', 170, geoTag(layoutFor(d.mode)), false)}</div>
    </div>
    <h2>${th('comparisonResult')}</h2>
    ${comparisonHtml(r)}
    ${d.savedId ? `<div class="card ok"><div class="row">${ic('check')}<span class="grow">${th('savedToReports', { id: d.savedId })}</span><button class="btn sm" data-act="nav" data-route="report" data-id="${d.savedId}">${th('view')}</button></div></div>` : `<button class="btn primary block" data-act="saveCompare">${ic('report', 'sm')}${th('saveComparison')}</button>`}`
  };
};

/* ---------- plans & reports ---------- */
const EVENT_ICONS = { created: 'plus', dataApproved: 'check', generated: 'spark', approved: 'shield', compared: 'chart', exported: 'download' };
function timelineHtml(events) { return `<ul class="timeline">${events.map(e => `<li><strong>${th('ev_' + e.type)}</strong><br><span class="xs muted">${esc(fmtDate(e.t))}</span></li>`).join('')}</ul>`; }
PAGES.plans = () => {
  const p = S.plan;
  return {
    title: t('savedPlans'), back: false,
    body: `${p && !p.approved ? `<div class="card"><div class="row"><strong class="grow">${th('currentDraft')}</strong><span class="chip warn">${ltr(p.id)}</span></div><p class="xs muted" style="margin:5px 0 8px">${th('draftNote')}</p><button class="btn sm block" data-act="openPlan">${th('openPlan')}</button></div>` : ''}
    <h2>${th('approvedPlans')}</h2>
    <div class="list">${S.plans.length ? S.plans.map(x => `<button class="row-btn" data-act="nav" data-route="plan" data-id="${x.id}">${ic('plans')}<span class="grow"><span style="display:block;font-weight:700" class="ltr">${esc(x.id)}</span><span class="sub">${ltr(x.container + ' · ' + x.shipmentCode)} · ${th(x.mode)} · ${x.util != null ? nfx(x.util, 1) + '%' : '—'}</span>${x.util != null ? srcBadge(x.utilSrc || 'rec') : ''}<span class="sub" style="display:block">${esc(fmtDate(x.events[x.events.length - 1].t))}</span></span><span class="chip ok">${th(x.autoApproved ? 'approvedAuto' : 'approved')}</span></button>`).join('') : `<div class="empty">${th('noSavedPlans')}</div>`}</div>
    <div style="margin-top:12px">${linkRow('report', t('previousReports'), th('nReports', { n: S.reports.length }), 'nav', 'data-route="reports"')}</div>`
  };
};
PAGES.plan = () => {
  const x = S.plans.find(p => p.id === S.params.id);
  if (!x) return { title: t('planDetails'), body: `<div class="empty">${th('planNotFound')}</div>` };
  return {
    title: t('planDetails'),
    body: `<div class="card glow"><div class="row"><strong class="grow ltr" style="font-size:17px">${esc(x.id)}</strong><span class="chip ok">${th(x.autoApproved ? 'approvedAuto' : 'approved')}</span></div>
      <dl class="kv" style="margin-top:8px"><dt>${th('container')}</dt><dd class="ltr">${esc(x.container)}</dd><dt>${th('shipmentCode')}</dt><dd class="ltr">${esc(x.shipmentCode)}</dd>
      <dt>${th('planMode')}</dt><dd>${th(x.mode)}</dd><dt>${th('mUtil')}</dt><dd>${x.util != null ? nfx(x.util, 1) + '% ' + srcBadge(x.utilSrc || 'rec') : '—'}</dd>
      <dt>${th('mLoaded')}</dt><dd>${x.loaded != null ? `${x.loaded} / ${x.total}` : '—'}</dd><dt>${th('groups')}</dt><dd>${x.groups.length}</dd></dl></div>
    <h2>${th('timeline')}</h2><div class="card">${timelineHtml(x.events)}</div>
    ${x.reportIds && x.reportIds.length ? `<h2>${th('previousReports')}</h2><div class="list">${x.reportIds.map(id => linkRow('report', id, '', 'nav', `data-route="report" data-id="${id}"`)).join('')}</div>` : ''}
    <button class="btn primary block" style="margin-top:12px" data-act="reopenPlan" data-id="${x.id}">${ic('eye', 'sm')}${th('reopenPlan')}</button>`
  };
};
PAGES.reports = () => ({
  title: t('previousReports'),
  body: `<div class="list">${S.reports.length ? S.reports.map(r => `<button class="row-btn" data-act="nav" data-route="report" data-id="${r.id}">${ic('chart')}<span class="grow"><span class="ltr" style="display:block;font-weight:700">${esc(r.id)}</span><span class="sub">${ltr(r.container + ' · ' + r.shipment)} · ${th(r.mode)} · ${esc(fmtDate(r.t))}</span><span class="sub" style="display:block">${th(r.v === 2 ? 'manualSimShort' : 'manual')} ${nfx(r.manual.util, 1)}% · ${th('system')} ${nfx(r.system.util, 1)}%</span></span>${ic('next', 'flip sm')}</button>`).join('') : `<div class="empty">${th('noReports')}</div>`}</div>`
});
PAGES.report = () => {
  const r = S.reports.find(x => x.id === S.params.id);
  if (!r) return { title: t('comparisonReport'), body: `<div class="empty">${th('reportNotFound')}</div>` };
  return { title: t('comparisonReport'), body: `<div class="row wrap" style="margin-bottom:10px"><span class="chip ltr">${esc(r.id)}</span><span class="chip">${ltr(r.container + ' · ' + r.shipment)}</span>${r.planId ? `<span class="chip ltr">${esc(r.planId)}</span>` : ''}<span class="chip">${esc(fmtDate(r.t))}</span></div>${comparisonHtml(r)}` };
};

/* ---------- export ---------- */
const FMT = { pdf: { ext: 'pdf', mime: 'application/pdf', label: 'PDF', opts: ['image', 'positions', 'unplaced', 'steps'] }, xlsx: { ext: 'xlsx', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', label: 'Excel', opts: ['positions', 'unplaced', 'steps'] }, csv: { ext: 'csv', mime: 'text/csv', label: 'CSV', opts: ['positions', 'unplaced', 'steps'] }, glb: { ext: 'glb', mime: 'model/gltf-binary', label: 'GLB', opts: ['positions', 'unplaced', 'steps'] } };
PAGES.export = () => {
  const p = S.plan;
  if (!p || !p.gen || p.gen.status === 'none') return { title: t('export'), body: `<div class="empty">${th('noPlanYet')}</div>` };
  const f = UI.exportFmt; const o = UI.exportOpts;
  return {
    title: t('export'),
    body: `${segHtml('exportFmt', f, Object.keys(FMT).map(k => ({ v: k, label: FMT[k].label })), t('format'))}
    <p class="xs muted" style="margin:8px 0">${th('fmtDesc_' + f)}</p>
    <div class="card flat">${FMT[f].opts.map(k => switchHtml('eo_' + k, o[k], t('opt_' + k + (f === 'glb' ? '_glb' : '')), th('optSub_' + k + (f === 'glb' ? '_glb' : '')), { attrs: `data-act-change="exportOpt" data-k="${k}"` })).join('')}</div>
    ${notice('', 'info', th('exportHonesty'))}
    <div class="grid2"><button class="btn" data-act="previewExport">${ic('eye', 'sm')}${th('previewBefore')}</button><button class="btn primary" data-act="doExport">${ic('download', 'sm')}${th('exportAs', { f: FMT[f].label })}</button></div>`
  };
};
PAGES.exportDone = () => {
  const e = UI.lastExport; const meta = S.exportLast;
  if (!meta) return { title: t('exportReady'), body: `<div class="empty">${th('noExport')}</div>` };
  return {
    title: t('exportReady'),
    body: `<div class="card ok glow" style="text-align:center;padding:20px 14px">${ic('check')}<h2 style="margin:8px 0 4px">${th('exportSuccess')}</h2><p class="mono ltr small" style="word-break:break-all">${esc(meta.name)}</p><p class="xs muted">${FMT[meta.fmt].label} · ${nfx(meta.size / 1024, 1)} KB · ${esc(fmtDate(meta.t))}</p></div>
    <div class="grid3"><button class="btn" data-act="previewExport" data-last="1">${ic('eye', 'sm')}${th('preview')}</button><button class="btn" data-act="shareExport">${ic('share', 'sm')}${th('share')}</button><button class="btn primary" data-act="downloadExport">${ic('download', 'sm')}${th('download')}</button></div>
    ${!e ? `<p class="xs muted" style="margin-top:8px">${th('regenNote')}</p>` : ''}
    <button class="btn ghost block" style="margin-top:10px" data-act="nav" data-route="results">${th('backToResults')}</button>`
  };
};

/* ---------- notifications & settings ---------- */
function planRow(x, kind) {
  const ready = x.gen && x.gen.status !== 'none';
  const chip = kind === 'saved' ? `<span class="chip ok">${th(x.autoApproved ? 'approvedAuto' : 'approved')}</span>` : `<span class="chip ${ready ? 'cyan' : 'warn'}">${th(ready ? 'notSaved' : 'draft')}</span>`;
  const last = x.events && x.events.length ? x.events[x.events.length - 1].t : (x.savedAt || x.createdAt);
  const n = (x.groups || []).reduce((a, g) => a + Math.max(0, Math.floor(+g.qty || 0)), 0);
  return `<button class="row-btn" data-act="${kind === 'saved' ? 'nav' : 'openUnsaved'}" ${kind === 'saved' ? `data-route="plan"` : ''} data-id="${esc(x.id)}">${ic(kind === 'saved' ? 'plans' : 'edit')}<span class="grow"><span class="ltr" style="display:block;font-weight:700">${esc(x.id)}${x.current ? ` <span class="xs muted">· ${th('currentLabel')}</span>` : ''}</span><span class="sub">${ltr((x.container || S.container) + ' · ' + (x.shipmentCode || S.shipment.code))} · ${th('nBoxes', { n })}</span><span class="sub" style="display:block">${esc(fmtDate(last))}</span></span>${chip}</button>`;
}
function unsavedList() {
  const list = S.unsaved.slice();
  if (S.plan && !S.plan.approved) list.unshift(Object.assign(clone(S.plan), { current: true, groups: S.shipment.groups, container: S.container, shipmentCode: S.shipment.code }));
  return list;
}
PAGES.opsRecords = () => {
  const tab = UI.opsTab || 'saved'; const uns = unsavedList();
  return {
    title: t('opsRecords'),
    body: `${segHtml('opsTab', tab, [{ v: 'saved', label: `${t('savedOps')} (${S.plans.length})` }, { v: 'unsaved', label: `${t('unsavedOps')} (${uns.length})` }], t('opsRecords'))}
    <p class="xs muted" style="margin:8px 0">${th(tab === 'saved' ? 'savedOpsNote' : 'unsavedOpsNote')}</p>
    <div class="list">${tab === 'saved' ? (S.plans.map(x => planRow(x, 'saved')).join('') || `<div class="empty">${th('noSavedPlans')}</div>`) : (uns.map(x => planRow(x, 'unsaved')).join('') || `<div class="empty">${th('noUnsaved')}</div>`)}</div>`
  };
};

PAGES.notifications = () => ({
  title: t('notifications'),
  body: `${S.notifications.some(n => !n.read) ? `<button class="btn sm ghost" style="margin-bottom:8px" data-act="readAll">${ic('check', 'sm')}${th('markAllRead')}</button>` : ''}
  <div class="list">${S.notifications.length ? S.notifications.map(n => `<button class="row-btn notifrow ${n.read ? '' : 'unread'}" data-act="openNotif" data-id="${n.id}">${n.read ? '' : '<span class="dot" aria-hidden="true"></span>'}<span style="color:var(--cyan)">${ic({ optimized: 'spark', unplaced: 'warn', inventory: 'box', approved: 'shield', exported: 'download' }[n.type])}</span><span class="grow"><span style="display:block;font-weight:600">${th('n_' + n.type, n.vars)}</span><span class="sub">${esc(fmtDate(n.t))}${n.read ? '' : ' · ' + th('unread')}</span></span>${ic('next', 'flip sm')}</button>`).join('') : `<div class="empty">${ic('bell')}<p>${th('noNotifications')}</p></div>`}</div>`
});
PAGES.settings = () => ({
  title: t('moreSettings'), back: false,
  body: `<h2>${th('records')}</h2><div class="list">
    ${linkRow('plans', t('opsRecords'), th('opsRecordsSub', { s: S.plans.length, u: unsavedList().length }), 'nav', 'data-route="opsRecords"')}
    ${linkRow('report', t('reportRecords'), th('nReports', { n: S.reports.length }), 'nav', 'data-route="reports"')}</div>
  <h2>${th('contact')}</h2><div class="card flat">
    ${[['container', 'contactCompany', '+966 12 000 0000'], ['user', 'contactSupport', '800 000 0000'], ['file', 'contactEmail', 'support@seniorproject1.example']].map(([icn, k, v]) => `<div class="row" style="min-height:52px">${ic(icn)}<span class="grow"><span class="xs muted" style="display:block">${th(k)}</span><span class="ltr" style="font-weight:600;overflow-wrap:anywhere">${esc(v)}</span></span><button class="btn sm ghost" data-act="copyText" data-v="${esc(v)}" aria-label="${th('copy')} ${th(k)}">${th('copy')}</button></div>`).join('')}
    <p class="xs muted" style="margin:6px 0 0">${th('contactHours')} · ${th('contactDemo')}</p></div>
  <h2>${th('language')}</h2>${segHtml('setLang', S.lang, [{ v: 'en', label: 'English' }, { v: 'ar', label: 'العربية' }], t('language'))}
  <h2>${th('automation')}</h2><div class="card flat">
    ${switchHtml('st_auto', S.prefs.alwaysAuto, t('alwaysAuto'), th('alwaysAutoSub'), { attrs: 'data-act-change="pref" data-k="alwaysAuto"' })}
    ${switchHtml('st_import', S.prefs.autoImport, t('autoImport'), th('autoImportSub'), { attrs: 'data-act-change="pref" data-k="autoImport"' })}</div>
  <h2>${th('notifications')}</h2><div class="card flat">${['optimized', 'unplaced', 'inventory', 'approved', 'exported'].map(k => switchHtml('sn_' + k, S.prefs.notif[k], t('nt_' + k), '', { attrs: `data-act-change="notifPref" data-k="${k}"` })).join('')}</div>
  <h2>${th('engineInfo')}</h2><div class="card">
    <div class="row">${ic('bolt')}<span class="grow"><strong>${th('instant')}</strong> — Block-Building</span><span class="xs muted ltr">${nfx(RECORDED.instant.util, 1)}% · ${fmtTime(RECORDED.instant.timeMs)}</span></div>
    <div class="row" style="margin-top:6px">${ic('spark')}<span class="grow"><strong>${th('optimized')}</strong> — Beam Search</span><span class="xs muted ltr">${nfx(RECORDED.optimized.util, 1)}% · ${fmtTime(RECORDED.optimized.timeMs)}</span></div>
    <p class="xs muted" style="margin:8px 0">${th('engineNote')}</p>
    <div class="lbl">${th('validator')}</div><ul class="small" style="margin:4px 0 6px;padding-inline-start:18px">${VALIDATOR_CHECKS.map(k => `<li><span class="mono">${k}</span> — ${th('chk_' + k)}</li>`).join('')}</ul>
    <p class="xs muted" style="margin:0">${th('unloadInfo')}</p></div>
  <h2>${th('data')}</h2><div class="card flat"><p class="xs muted">${th('storageNote')}</p><button class="btn sm block" data-act="restoreDemo">${ic('reset', 'sm')}${th('restoreDemo')}</button></div>
  <h2>${th('account')}</h2><div class="card flat"><div class="row">${ic('user')}<span class="grow">${S.session && S.session.email ? `${esc(S.session.name || '')} <span class="xs muted ltr">${esc(S.session.email)}</span>` : th('demoSession')}</span></div>
    <button class="btn danger block" style="margin-top:10px" data-act="signOut">${ic('logout', 'sm flip')}${th('signOut')}</button></div>
  <p class="foot">Senior Project 1 · ${th('uj')}<br>${th('conceptFooter')}</p>`
});

/* ============================================================
   Modals
   ============================================================ */
function renderModal() {
  const host = $('#modalhost'); if (!host) return;
  const m = UI.modal; if (!m) { host.innerHTML = ''; return; }
  let title = '', body = '';
  if (m.type === 'unloadInfo') { title = t('mUnload'); body = `<p>${th('unloadInfo')}</p><p class="small muted">${th('unloadInfoDash')}</p>`; }
  else if (m.type === 'confirm') { title = m.title; body = `<p>${esc(m.text)}</p><div class="grid2"><button class="btn" data-act="closeModal">${th('cancel')}</button><button class="btn ${m.danger ? 'danger' : 'primary'}" data-act="confirmYes">${esc(m.yes)}</button></div>`; }
  else if (m.type === 'templates') {
    title = t('templates');
    body = `<p class="small muted">${th('templateNote')}</p><div class="formula" style="font-size:11px;margin-bottom:10px">${TEMPLATE_FIELDS.join(',')}</div>
      <div class="stack"><button class="btn" data-act="dlTemplate" data-f="csv">${ic('download', 'sm')}${th('csvTemplate')}</button><button class="btn" data-act="dlTemplate" data-f="xlsx">${ic('download', 'sm')}${th('xlsxTemplate')}</button>
      <button class="btn" data-act="dlTemplate" data-f="sample-csv">${ic('download', 'sm')}${th('sampleCsv')}</button><button class="btn" data-act="dlTemplate" data-f="sample-xlsx">${ic('download', 'sm')}${th('sampleXlsx')}</button></div>
      <p class="xs muted" style="margin-top:8px">${th('fieldHelp')}</p>`;
  } else if (m.type === 'preview') { title = t('previewTitle', { f: FMT[m.fmt].label }); body = m.html; }
  host.innerHTML = `<div class="modal" data-act="modalBg"><div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(title)}"><div class="head"><h3>${esc(title)}</h3><button class="iconbtn" data-act="closeModal" aria-label="${th('close')}">${ic('x')}</button></div>${body}</div></div>`;
  host.querySelectorAll('canvas[data-scene]').forEach(cv => Scenes.create(cv, sceneSpec(cv.dataset.scene)));
  const btn = host.querySelector('.sheet [data-act="closeModal"]'); if (btn) btn.focus();
}

/* ============================================================
   Export builders
   ============================================================ */
function exportData() {
  const p = S.plan; const mode = p.mode; const rec = recFor(mode); const lay = layoutFor(mode); const c = cont(); const M = metricsFor(mode);
  const tag = src => ` (${t(src === 'rec' ? 'srcRec' : 'srcPrev')})`;
  const boxes = expandBoxes(S.shipment);
  const summary = [
    [t('x_plan'), p.id], [t('shipmentCode'), S.shipment.code], [t('container'), `${c.code} (${nfx(c.L / 10, 1)} × ${nfx(c.W / 10, 1)} × ${nfx(c.H / 10, 1)} cm)`], [t('x_mode'), t(mode)],
    [t('x_engine'), M.engine], [t('mUtil'), `${nfx(M.util.v, 1)}%` + tag(M.util.src)], [t('mLoaded'), `${M.loaded.v} / ${M.loaded.t}` + tag(M.loaded.src)],
    [t('unplacedBoxes'), String(M.unplaced.v) + tag(M.unplaced.src)], [t('mTime'), fmtTime(M.time.v) + tag(M.time.src)],
    [t('validator'), (rec ? t('engineValid') + ' · ' : '') + t('prevValid', { n: lay.validation.passed })], [t('mUnload'), `${nfx(lay.unload, 1)}%` + tag('prev')],
    [t('x_status'), p.approved ? t(p.autoApproved ? 'approvedAuto' : 'approved') : t('draft')], [t('x_date'), fmtDate(Date.now())]
  ];
  const illus = lay.source === 'engine' ? [[t('x_geometry'), t('x_geometryEngine')], [t('mLoaded'), `${lay.loaded} / ${lay.total}`]] : [[t('x_geometry'), t('x_geometryNote')], [t('x_illusPlaced'), `${lay.loaded} / ${lay.total}`], [t('x_illusUtil'), `${nfx(lay.util, 1)}%`]];
  const posHead = [t('x_id'), t('groupCode'), t('category'), t('contents'), t('x_illusStatus'), t('loadingOrder'), t('x_layer'), 'x_cm', 'y_cm', 'z_cm', 'L_cm', 'W_cm', 'H_cm', 'kg'];
  const posRows = boxes.map(b => { const o = lay.outcome[b.id] || {}; const pl = o.placement; return [b.id, b.g.code, kindLabel(b.g), b.g.contents || '', t(o.status || 'rejected'), pl ? pl.order : '', pl ? pl.layer : '', pl ? +(pl.x0 / 10).toFixed(1) : '', pl ? +(pl.y0 / 10).toFixed(1) : '', pl ? +(pl.z0 / 10).toFixed(1) : '', pl ? +(pl.dx / 10).toFixed(1) : '', pl ? +(pl.dy / 10).toFixed(1) : '', pl ? +(pl.dz / 10).toFixed(1) : '', +b.g.kg]; });
  const unHead = [t('x_id'), t('groupCode'), t('x_illusStatus'), t('reason')];
  const unRows = boxes.filter(b => (lay.outcome[b.id] || {}).status !== 'loaded').map(b => { const o = lay.outcome[b.id] || {}; return [b.id, b.g.code, t(o.status), reasonText(o.reason, b.g)]; });
  const stHead = [t('x_step'), t('x_id'), 'x_cm', 'y_cm', 'z_cm', t('x_layer')];
  const stRows = lay.placements.map(pl => [pl.order, pl.id, +(pl.x0 / 10).toFixed(1), +(pl.y0 / 10).toFixed(1), +(pl.z0 / 10).toFixed(1), pl.layer]);
  return { p, mode, rec, lay, c, summary, illus, posHead, posRows, unHead, unRows, stHead, stRows };
}
function buildSheets(D, o) {
  const sheets = [{ name: t('x_sheetSummary'), rows: [[t('x_engineSummary'), ''], ...D.summary, ['', ''], [t('x_illusDetails'), ''], ...D.illus], headerRows: [0, D.summary.length + 2] }];
  if (o.positions) sheets.push({ name: t('x_sheetPositions'), rows: [D.posHead, ...D.posRows], headerRows: [0] });
  if (o.unplaced) sheets.push({ name: t('x_sheetUnplaced'), rows: [D.unHead, ...D.unRows], headerRows: [0] });
  if (o.steps) sheets.push({ name: t('x_sheetSteps'), rows: [D.stHead, ...D.stRows], headerRows: [0] });
  return sheets;
}
function buildCsvRows(D, o) {
  const rows = [['# ' + t('x_engineSummary')], ...D.summary, [], ['# ' + t('x_illusDetails')], ...D.illus, []];
  const head = [t('x_id'), t('groupCode'), t('category'), t('contents'), t('x_illusStatus')];
  if (o.steps) head.push(t('loadingOrder'), t('x_layer'));
  if (o.positions) head.push('x_cm', 'y_cm', 'z_cm', 'L_cm', 'W_cm', 'H_cm');
  if (o.unplaced) head.push(t('reason'));
  rows.push(head);
  for (const r of D.posRows) {
    const row = r.slice(0, 5);
    if (o.steps) row.push(r[5], r[6]);
    if (o.positions) row.push(...r.slice(7, 13));
    if (o.unplaced) { const u = D.unRows.find(x => x[0] === r[0]); row.push(u ? u[3] : ''); }
    rows.push(row);
  }
  return rows;
}
function buildPdfPages(D, o) {
  const PW = 1240, PH = 1754, M = 80; const rtl = S.lang === 'ar';
  const UIF = "'IBM Plex Sans Arabic','Noto Sans Arabic','Segoe UI',Tahoma,sans-serif";
  const pages = []; let cv, ctx, y;
  const X = x => rtl ? PW - x : x;
  const newPage = () => {
    cv = document.createElement('canvas'); cv.width = PW; cv.height = PH; ctx = cv.getContext('2d');
    ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, PW, PH); ctx.direction = rtl ? 'rtl' : 'ltr';
    ctx.fillStyle = '#2f6bff'; ctx.fillRect(0, 0, PW, 14);
    ctx.fillStyle = '#7a86a8'; ctx.font = `500 18px ${UIF}`; ctx.textAlign = rtl ? 'right' : 'left';
    ctx.fillText(`Senior Project · ${t('x_reportTitle')} · ${D.p.id}`, X(M), PH - 40);
    ctx.textAlign = rtl ? 'left' : 'right'; ctx.fillText(`${pages.length + 1}`, X(PW - M), PH - 40);
    pages.push(cv); y = M;
  };
  const ensure = h => { if (y + h > PH - 90) newPage(); };
  const text = (s, x, size, weight, color, align) => { ctx.font = `${weight || 400} ${size}px ${UIF}`; ctx.fillStyle = color || '#0b1739'; ctx.textAlign = align === 'end' ? (rtl ? 'left' : 'right') : (rtl ? 'right' : 'left'); ctx.textBaseline = 'alphabetic'; ctx.fillText(String(s), X(x), y); };
  const h2 = s => { ensure(70); y += 30; text(s, M, 30, 700, '#0b1739'); y += 14; ctx.fillStyle = '#dbe3f7'; ctx.fillRect(M, y, PW - 2 * M, 2); y += 30; };
  const kv = rows => { for (const [k, v] of rows) { ensure(36); text(k, M, 21, 500, '#55617f'); text(v, PW - M, 21, 600, '#0b1739', 'end'); y += 34; } };
  const table = (head, rows, widths) => {
    const tw = PW - 2 * M; const tot = widths.reduce((a, b) => a + b, 0); const ws = widths.map(w => w / tot * tw);
    const row = (cells, isHead) => {
      ensure(32); if (isHead) { ctx.fillStyle = '#e8eefc'; ctx.fillRect(M, y - 22, tw, 30); }
      let x = M; cells.forEach((c, i) => { ctx.save(); ctx.beginPath(); ctx.rect(rtl ? PW - x - ws[i] : x, y - 24, ws[i] - 6, 32); ctx.clip(); text(c, x + 6, isHead ? 16 : 16.5, isHead ? 700 : 400, '#0b1739'); ctx.restore(); x += ws[i]; });
      y += 30;
    };
    row(head, true); for (const r of rows) { if (y + 30 > PH - 90) { newPage(); row(head, true); } row(r, false); }
    y += 10;
  };
  newPage();
  text('Senior Project', M, 22, 600, '#2f6bff'); y += 46;
  text(t('x_reportTitle'), M, 44, 700); y += 40;
  text(`${D.p.id} · ${S.shipment.code} · ${D.c.code} · ${t(D.mode)} · ${fmtDate(Date.now())}`, M, 21, 400, '#55617f'); y += 16;
  h2(t('x_engineSummary')); kv(D.summary);
  ensure(60); ctx.fillStyle = '#fff6e6'; ctx.fillRect(M, y - 6, PW - 2 * M, 66); y += 22; text(t('x_illusBanner'), M + 14, 19, 600, '#8a5a00'); y += 28; text(t('x_illusBanner2'), M + 14, 17, 400, '#8a5a00'); y += 40;
  if (o.image) {
    h2(t('x_planImage')); ensure(600);
    const snap = Scenes.snapshot(PW - 2 * M, 560, { id: 'pdfsnap', framing: 0.9, background: '#0b1430', getData: () => ({ cont: D.c, boxes: D.lay.placements, colorOf, labels: true, doorLabel: t('doorLabel') }) });
    ctx.drawImage(snap, M, y); y += 575; text(geoTag(D.lay), M, 17, 400, '#55617f'); y += 20;
  }
  h2(t('x_illusDetails')); kv(D.illus);
  if (o.positions) { h2(t('x_sheetPositions')); table([t('x_id'), t('groupCode'), t('x_illusStatus'), t('loadingOrder'), 'x', 'y', 'z (cm)', 'L×W×H (cm)'], D.posRows.map(r => [r[0], r[1], r[4], r[5], r[7], r[8], r[9], r[10] !== '' ? `${r[10]}×${r[11]}×${r[12]}` : '']), [2.3, 1, 1.3, 1, 0.9, 0.9, 1, 2]); }
  if (o.unplaced) { h2(t('x_sheetUnplaced')); table(D.unHead, D.unRows, [2, 1, 1.2, 5.4]); }
  if (o.steps) { h2(t('x_sheetSteps')); table(D.stHead, D.stRows, [1, 2.4, 1, 1, 1, 1]); }
  return pages;
}
function buildExport(fmt) {
  const D = exportData(); const o = UI.exportOpts; const name = `SeniorProject_${D.p.id}_${D.c.code}_${D.mode}.${FMT[fmt].ext}`;
  let bytes;
  if (fmt === 'csv') bytes = new TextEncoder().encode(Files.csvWrite(buildCsvRows(D, o)));
  else if (fmt === 'xlsx') bytes = Files.xlsxWrite(buildSheets(D, o));
  else if (fmt === 'pdf') bytes = Files.pdfFromCanvases(buildPdfPages(D, o), `Senior Project ${D.p.id}`);
  else if (fmt === 'glb') bytes = Files.glbWrite({
    cont: D.c, placements: D.lay.placements, colorOf, names: o.positions,
    extrasFor: pl => { const ex = {}; if (o.positions) Object.assign(ex, { id: pl.id, group: pl.gcode, x_cm: pl.x0 / 10, y_cm: pl.y0 / 10, z_cm: pl.z0 / 10, illustrative: true }); if (o.steps) Object.assign(ex, { loadingOrder: pl.order, layer: pl.layer }); return Object.keys(ex).length ? ex : null; },
    sceneExtras: Object.assign({ engineSummary: Object.fromEntries(D.summary), geometry: 'illustrative' }, o.unplaced ? { unplaced: D.unRows.map(r => ({ id: r[0], status: r[2], reason: r[3] })) } : {})
  });
  return { blob: new Blob([bytes], { type: FMT[fmt].mime }), name, fmt, mime: FMT[fmt].mime, size: bytes.length, D };
}
function previewHtml(fmt, D) {
  const o = UI.exportOpts;
  if (fmt === 'pdf') { const pages = buildPdfPages(D, o); return `<p class="xs muted">${th('pdfPages', { n: pages.length })}</p><div class="stack">${pages.map(c => `<div class="pdfprev"><img alt="${th('pdfPageAlt')}" src="${c.toDataURL('image/jpeg', 0.8)}"></div>`).join('')}</div>`; }
  if (fmt === 'glb') return `<p class="xs muted">${th('glbPreviewNote')}</p>${viewerHtml('glbprev', 300, geoTag(D.lay), true)}`;
  const tbl = rows => `<div class="sheetprev"><table class="table"><tbody>${rows.slice(0, 40).map((r, i) => `<tr>${r.map(c => i === 0 ? `<th>${esc(c)}</th>` : `<td>${esc(c)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>${rows.length > 40 ? `<p class="xs muted">${th('moreRows', { n: rows.length - 40 })}</p>` : ''}`;
  if (fmt === 'csv') return tbl(buildCsvRows(D, o));
  return buildSheets(D, o).map(s => `<div class="lbl" style="margin:8px 0 4px">${ic('file', 'sm')} ${esc(s.name)}</div>${tbl(s.rows)}`).join('');
}
let DL = null;
async function downloadBlob(blob, name) {
  if (DL) {
    let fname = name, data = blob;
    if (/\.glb$/i.test(name)) { const u8 = new Uint8Array(await blob.arrayBuffer()); data = new Blob([Files.zipStore([{ name, data: u8 }])]); fname = name + '.zip'; }
    try { await DL.save({ filename: fname, data }); showToast(t(fname !== name ? 'downloadedZip' : 'downloaded'), 'download'); }
    catch (e) { if (e && e.code === 'declined') return; showToast(t('downloadFailed'), 'warn'); }
    return;
  }
  const url = URL.createObjectURL(blob); const a = document.createElement('a');
  a.href = url; a.download = name; a.rel = 'noopener'; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
  showToast(t('downloaded'), 'download');
}

/* ============================================================
   Actions
   ============================================================ */
function startDemoSession() {
  S.session = S.session || { demo: true, name: '' };
  if (!S.plan) {
    newPlan(); S.plan.events.push({ type: 'dataApproved', t: Date.now() }, { type: 'generated', t: Date.now() });
    S.plan.gen = { status: 'done', startedAt: Date.now() - 3000 }; S.plan.mode = 'optimized'; S.inventoryApproved = true;
  }
  UI.auth = null; go('home', {}, { root: true });
}
function hashPw(s) { let h = 0x811c9dc5; for (const ch of String(s)) { h ^= ch.charCodeAt(0); h = Math.imul(h, 0x01000193) >>> 0; } return h.toString(16); }
function submitAuth(kind) {
  const f = UI.auth || {}; const email = (f.email || '').trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) { f.err = t('errEmail'); return render(); }
  if ((f.pw || '').length < 6) { f.err = t('errPw'); return render(); }
  if (kind === 'signup') {
    if (!(f.name || '').trim()) { f.err = t('errName'); return render(); }
    if (S.users.some(u => u.email === email)) { f.err = t('errExists'); return render(); }
    S.users.push({ email, name: f.name.trim(), pw: hashPw(f.pw) });
    S.session = { email, name: f.name.trim() };
  } else {
    const u = S.users.find(x => x.email === email);
    if (!u || u.pw !== hashPw(f.pw)) { f.err = t('errLogin'); return render(); }
    S.session = { email, name: u.name };
  }
  UI.auth = null; startDemoSession();
}
function saveBoxDraft() {
  const d = S.drafts.box; UI.touchedBox = true;
  const g = Object.assign({}, d, { loadBearing: d.stackable && d.loadBearing !== '' ? Number(d.loadBearing) : null });
  for (const k of ['l', 'w', 'h', 'kg', 'qty', 'priority']) g[k] = g[k] === '' ? '' : Number(g[k]);
  if (g.fragile) g.stackable = false;
  if (Object.keys(groupErrors(g)).length) return render();
  const fields = ['kind', 'custom', 'contents', 'l', 'w', 'h', 'kg', 'qty', 'priority', 'orientation', 'fragile', 'floorOnly', 'stackable', 'stacking', 'loadBearing'];
  const clean = {}; for (const k of fields) clean[k] = g[k];
  if (clean.kind !== 'other') clean.custom = '';
  if (!clean.stackable) { clean.stacking = 'any'; clean.loadBearing = null; }
  if (d.editCode) {
    Object.assign(groupByCode(d.editCode), clean); showToast(t('toastGroupSaved', { code: d.editCode }));
  } else {
    const code = nextGroupCode(S.shipment); const seq = S.shipment.nextSeq || S.shipment.groups.length + 1;
    S.shipment.groups.push(Object.assign({ code, color: GROUP_COLORS[(seq - 1) % GROUP_COLORS.length], addedAt: Date.now() }, clean));
    S.shipment.nextSeq = seq + 1; showToast(t('toastGroupAdded', { code, n: clean.qty }));
  }
  inputsChanged(); S.drafts.box = null; UI.touchedBox = false; save(); go('shipment', {}, { replace: true });
}
async function readImportFile(file) {
  try {
    let rows;
    if (/\.xlsx$/i.test(file.name)) rows = await Files.xlsxRead(await file.arrayBuffer());
    else if (/\.(csv|txt)$/i.test(file.name)) rows = Files.csvParse(await file.text());
    else throw new Error('type');
    setImport(rowsToDrafts(rows), file.name);
  } catch (e) { console.error(e); showToast(t('importFailed'), 'warn'); }
}
function setImport(drafts, fileName) {
  S.drafts.import = { rows: drafts, fileName, view: 'list', idx: 0, mode: 'replace', autoStopped: false };
  const sm = importSummary(drafts);
  notify('inventory', 'shipment', {}, { b: sm.boxes, t: sm.types });
  if (S.prefs.autoImport) {
    if (sm.bad) { S.drafts.import.autoStopped = true; showToast(t('autoStoppedToast', { n: sm.bad }), 'warn'); }
    else { save(); return confirmImport(true); }
  }
  save(); render();
}
function confirmImport(auto) {
  const im = S.drafts.import; if (!im) return;
  if (importSummary(im.rows).bad) return render();
  const replace = (im.mode || 'replace') === 'replace';
  if (replace) { S.shipment.groups = []; S.shipment.nextSeq = 1; }
  let seq = S.shipment.nextSeq || S.shipment.groups.length + 1;
  const now = Date.now();
  im.rows.forEach((r, i) => {
    const code = 'B' + pad2(seq);
    const sample = DEMO.groups.find(g => g.kind === r.kind && +g.l === +r.l && +g.w === +r.w && +g.h === +r.h);
    S.shipment.groups.push({ code, kind: r.kind, custom: r.kind === 'other' ? r.custom || '' : '', contents: r.contents || '', l: +r.l, w: +r.w, h: +r.h, kg: +r.kg, qty: +r.qty, priority: +r.priority, orientation: r.orientation, fragile: !!r.fragile, floorOnly: !!r.floorOnly, stackable: !!r.stackable && !r.fragile, stacking: r.stackable ? r.stacking : 'any', loadBearing: r.stackable && r.loadBearing ? +r.loadBearing : null, color: sample && sample.code === code ? sample.color : GROUP_COLORS[(seq - 1) % GROUP_COLORS.length], addedAt: now + i });
    seq++;
  });
  S.shipment.nextSeq = seq;
  inputsChanged();
  S.inventoryApproved = true; ensureDraftPlan(); addEvent('dataApproved');
  const sm = importSummary(im.rows);
  S.drafts.import = null;
  showToast(auto ? t('importedAuto', { b: sm.boxes, t: sm.types }) : t('importedOk', { b: sm.boxes, t: sm.types }));
  save(); go('shipment', {}, { replace: true });
}
function setDeep(obj, path, val) { const ks = path.split('.'); let o = obj; for (let i = 0; i < ks.length - 1; i++) { if (o[ks[i]] === undefined || o[ks[i]] === null) o[ks[i]] = {}; o = o[ks[i]]; } o[ks[ks.length - 1]] = val; }
function confirmModal(title, text, yes, fn, danger) { UI.confirmFn = fn; openModal({ type: 'confirm', title, text, yes, danger }); }

const ACT = {
  back: () => back(),
  nav: el => { if (el.dataset.route === 'box' || el.dataset.route === 'plan' || el.dataset.route === 'report') go(el.dataset.route, { id: el.dataset.id }); else go(el.dataset.route, {}, { replace: !!el.dataset.replace }); },
  tab: el => { go(ROOTS[el.dataset.tab], {}, { root: true }); },
  lang: () => { S.lang = S.lang === 'en' ? 'ar' : 'en'; save(); render(); Scenes.invalidate(); },
  setLang: el => { S.lang = el.dataset.v; save(); render(); Scenes.invalidate(); },
  demo: () => startDemoSession(),
  openPlan: () => { const p = S.plan; if (p && p.gen && p.gen.status !== 'none') go('results'); else go(S.shipment.groups.length ? 'review' : 'shipment'); },
  newPlan: () => { if (!S.plan || S.plan.approved || (S.plan.gen && S.plan.gen.status !== 'none')) newPlan(); save(); go('container'); },
  pickContainer: el => { if (S.container === el.dataset.v) return; S.container = el.dataset.v; inputsChanged(); if (S.plan) S.plan.container = S.container; save(); render(); Scenes.invalidate(); },
  zoom: el => Scenes.zoom(el.dataset.id, +el.dataset.f),
  camreset: el => Scenes.reset(el.dataset.id),
  addBox: () => { S.drafts.box = emptyBoxDraft(); UI.touchedBox = false; go('addbox'); },
  editGroup: el => { S.drafts.box = emptyBoxDraft(el.dataset.code); UI.touchedBox = false; go('addbox'); },
  cancelBox: () => { S.drafts.box = null; UI.touchedBox = false; back(); },
  removeGroup: el => { const code = el.dataset.code; confirmModal(t('removeGroupQ', { code }), t('removeGroupText'), t('remove'), () => { S.shipment.groups = S.shipment.groups.filter(g => g.code !== code); inputsChanged(); save(); showToast(t('toastRemoved', { code })); render(); }, true); },
  boxOrient: el => { S.drafts.box.orientation = el.dataset.v; save(); render(); },
  prio: el => { const d = S.drafts.box; d.priority = Math.max(1, Math.min(9, (Number(d.priority) || 1) + Number(el.dataset.d))); save(); render(); },
  loadSample: () => setImport(rowsToDrafts([TEMPLATE_FIELDS, ...sampleRows()]), 'SH-102_sample.csv'),
  openTemplates: () => openModal({ type: 'templates' }),
  dlTemplate: el => {
    const f = el.dataset.f;
    if (f === 'csv') downloadBlob(new Blob([Files.csvWrite(templateRows())], { type: 'text/csv' }), 'SeniorProject_template.csv');
    else if (f === 'xlsx') downloadBlob(new Blob([Files.xlsxWrite([{ name: 'Shipment', rows: templateRows(), headerRows: [0] }])], { type: FMT.xlsx.mime }), 'SeniorProject_template.xlsx');
    else if (f === 'sample-csv') downloadBlob(new Blob([Files.csvWrite([TEMPLATE_FIELDS, ...sampleRows()])], { type: 'text/csv' }), 'SH-102_sample.csv');
    else downloadBlob(new Blob([Files.xlsxWrite([{ name: 'Shipment', rows: [TEMPLATE_FIELDS, ...sampleRows()], headerRows: [0] }])], { type: FMT.xlsx.mime }), 'SH-102_sample.xlsx');
  },
  importView: el => { S.drafts.import.view = el.dataset.v; save(); render(); },
  importMode: el => { S.drafts.import.mode = el.dataset.v; save(); render(); },
  importStep: el => { const im = S.drafts.import; im.idx = Math.max(0, Math.min(im.rows.length - 1, (im.idx || 0) + Number(el.dataset.d))); save(); render(); },
  editRow: el => { const im = S.drafts.import; im.view = 'one'; im.idx = Number(el.dataset.i); save(); render(); },
  fixRow: el => { const im = S.drafts.import; fixDraft(im.rows[Number(el.dataset.i)]); save(); showToast(t('rowFixed')); render(); },
  confirmImport: () => confirmImport(false),
  showIn3d: el => { UI.viewer.selected = el.dataset.id; const pl = layoutFor(S.plan.mode).byId[el.dataset.id]; if (pl) { UI.viewer.hidden[pl.gcode] = false; if (UI.viewer.layer && pl.layer > UI.viewer.layer) UI.viewer.layer = 0; } go('viewer'); },
  approveData: () => { if (!S.inventoryApproved) { S.inventoryApproved = true; ensureDraftPlan(); addEvent('dataApproved'); } startGeneration(); go('results'); },
  keepInstant: () => keepInstant(),
  rerunOpt: () => { const p = S.plan; p.gen = { status: 'optimizing', startedAt: Date.now() }; p.mode = 'instant'; save(); render(); },
  planMode: el => { if (el.disabled) return; S.plan.mode = el.dataset.v; syncSaved(); save(); render(); Scenes.invalidate(); },
  approvePlan: () => { approvePlan(false); save(); showToast(t('toastApproved', { id: S.plan.id }), 'shield'); render(); },
  unloadInfo: () => openModal({ type: 'unloadInfo' }),
  toggleChecks: () => { UI.showChecks = !UI.showChecks; render(); },
  camMode: el => { Scenes.setMode('viewer', el.dataset.v); render(); },
  clearSel: () => { UI.viewer.selected = null; render(); },
  toggleGroup: el => { const c = el.dataset.code; UI.viewer.hidden[c] = !UI.viewer.hidden[c]; render(); Scenes.invalidate('viewer'); },
  expandU: el => { UI.expandUnplaced[el.dataset.k] = !UI.expandUnplaced[el.dataset.k]; render(); },
  stepMove: el => { stopSteps(); const N = stepsLayout().placements.length; UI.steps.i = Math.max(1, Math.min(N, UI.steps.i + Number(el.dataset.d))); stepUpdate(); },
  stepPlay: () => toggleSteps(),
  cmpMode: el => { const d = S.drafts.compare; d.mode = el.dataset.v; d.savedId = null; save(); render(); },
  pieBy: el => { UI.pieBy = el.dataset.v; render(); },
  opsTab: el => { UI.opsTab = el.dataset.v; render(); },
  copyText: async el => { try { await navigator.clipboard.writeText(el.dataset.v); showToast(t('copied')); } catch (e) { showToast(el.dataset.v, 'info'); } },
  openUnsaved: el => {
    const id = el.dataset.id;
    if (S.plan && S.plan.id === id) { ACT.openPlan(); return; }
    const x = S.unsaved.find(u => u.id === id); if (!x) return;
    archiveCurrent();
    S.unsaved = S.unsaved.filter(u => u.id !== id);
    S.shipment = { code: x.shipmentCode, groups: clone(x.groups), nextSeq: x.nextSeq || x.groups.length + 1 };
    S.container = x.container;
    const p = clone(x); ['groups', 'nextSeq', 'savedAt', 'current'].forEach(k => delete p[k]);
    S.plan = p; S.inventoryApproved = p.events.some(e => e.type === 'dataApproved'); S.drafts.compare = null; UI.viewer.selected = null;
    save(); showToast(t('toastReopened', { id }), 'eye');
    if (p.gen && p.gen.status !== 'none') go('results'); else go('shipment');
  },
  saveCompare: () => {
    const d = S.drafts.compare; if (!d) return;
    const r = buildComparison(d.mode); r.id = 'RPT-' + pad3(S.reportSeq++); S.reports.unshift(r); d.savedId = r.id;
    if (S.plan) { S.plan.reportIds.push(r.id); addEvent('compared'); }
    save(); showToast(t('toastSavedReport', { id: r.id }), 'report'); render();
  },
  reopenPlan: el => {
    const x = S.plans.find(p => p.id === el.dataset.id); if (!x) return;
    S.shipment = { code: x.shipmentCode, groups: clone(x.groups), nextSeq: x.nextSeq || x.groups.length + 1 };
    S.container = x.container; S.inventoryApproved = true;
    const p = clone(x); delete p.groups; delete p.util; delete p.loaded; delete p.total; delete p.nextSeq; delete p.shipmentCode; p.shipmentCode = x.shipmentCode;
    if (p.gen.status === 'optimizing') p.gen.status = 'done';
    S.plan = p; S.drafts.compare = null; UI.viewer.selected = null;
    save(); showToast(t('toastReopened', { id: x.id }), 'eye'); go('results');
  },
  exportFmt: el => { UI.exportFmt = el.dataset.v; render(); },
  previewExport: el => {
    try {
      const fmt = el.dataset.last && S.exportLast ? S.exportLast.fmt : UI.exportFmt;
      const D = exportData(); openModal({ type: 'preview', fmt, html: previewHtml(fmt, D) });
    } catch (e) { console.error(e); showToast(t('exportFailed'), 'warn'); }
  },
  doExport: () => {
    try {
      const fmt = UI.exportFmt; const ex = buildExport(fmt);
      UI.lastExport = ex; S.exportLast = { name: ex.name, fmt, size: ex.size, t: Date.now(), opts: clone(UI.exportOpts) };
      addEvent('exported'); notify('exported', 'exportDone', {}, { f: FMT[fmt].label });
      save(); go('exportDone', {}, { replace: false });
    } catch (e) { console.error(e); showToast(t('exportFailed'), 'warn'); }
  },
  downloadExport: () => { let e = UI.lastExport; if (!e && S.exportLast) { UI.exportFmt = S.exportLast.fmt; Object.assign(UI.exportOpts, S.exportLast.opts || {}); e = UI.lastExport = buildExport(S.exportLast.fmt); } if (e) downloadBlob(e.blob, e.name); },
  shareExport: async () => {
    let e = UI.lastExport; if (!e && S.exportLast) { UI.exportFmt = S.exportLast.fmt; e = UI.lastExport = buildExport(S.exportLast.fmt); } if (!e) return;
    const file = new File([e.blob], e.name, { type: e.mime });
    try {
      if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], title: e.name }); return; }
    } catch (err) { if (err && err.name === 'AbortError') return; }
    await downloadBlob(e.blob, e.name);
  },
  readAll: () => { S.notifications.forEach(n => n.read = true); save(); render(); },
  openNotif: el => { const n = S.notifications.find(x => x.id === el.dataset.id); if (!n) return; n.read = true; save(); go(n.route, n.params); },
  restoreDemo: () => confirmModal(t('restoreDemo'), t('restoreDemoText'), t('restore'), () => { S.shipment = { code: DEMO.code, groups: demoGroups(), nextSeq: 7 }; S.container = '20GP'; inputsChanged(); S.inventoryApproved = true; save(); showToast(t('toastRestored')); render(); }),
  signOut: () => { S.session = null; stopSteps(); save(); go('welcome', {}, { root: true }); },
  closeModal: () => closeModal(),
  modalBg: (el, ev) => { if (ev.target === el) closeModal(); },
  confirmYes: () => { const fn = UI.confirmFn; UI.confirmFn = null; closeModal(); if (fn) fn(); }
};
const CHANGE = {
  importFile: el => { const f = el.files && el.files[0]; if (f) readImportFile(f); el.value = ''; },
  labels: el => { UI.viewer.labels = el.checked; Scenes.invalidate('viewer'); },
  layer: el => { UI.viewer.layer = Number(el.value); render(); Scenes.invalidate('viewer'); },
  exportOpt: el => { UI.exportOpts[el.dataset.k] = el.checked; },
  pref: el => { S.prefs[el.dataset.k] = el.checked; save(); },
  notifPref: el => { S.prefs.notif[el.dataset.k] = el.checked; save(); }
};
const INPUT = {
  inside: el => { const c = Scenes.getCam('viewer'); c.insideT = Number(el.value) / 100; Scenes.invalidate('viewer'); },
  step: el => { stopSteps(); UI.steps.i = Number(el.value); stepUpdate(); }
};

/* delegated events */
document.addEventListener('click', ev => {
  const el = ev.target.closest('[data-act]'); if (!el) return;
  if (el.tagName === 'BUTTON' && el.disabled) return;
  const fn = ACT[el.dataset.act]; if (!fn) return;
  if (el.dataset.act !== 'modalBg') ev.preventDefault();
  fn(el, ev);
});
document.addEventListener('submit', ev => {
  const f = ev.target.closest('form[data-form]'); if (!f) return; ev.preventDefault();
  const k = f.dataset.form;
  if (k === 'box') saveBoxDraft(); else submitAuth(k);
});
document.addEventListener('input', ev => {
  const el = ev.target;
  if (el.dataset.actInput && INPUT[el.dataset.actInput]) return INPUT[el.dataset.actInput](el);
  if (el.dataset.ui) { setDeep(UI, el.dataset.ui, el.value); if (el.dataset.live) render(); return; }
  if (el.dataset.draft && el.tagName !== 'SELECT') {
    let v = el.value; if (el.dataset.num) { const n = Number(String(v).trim().replace(',', '.')); v = String(v).trim() === '' ? '' : isFinite(n) ? n : v; }
    setDeep(S.drafts, el.dataset.draft, v); save();
  }
});
document.addEventListener('change', ev => {
  const el = ev.target;
  if (el.dataset.actChange && CHANGE[el.dataset.actChange]) return CHANGE[el.dataset.actChange](el);
  if (el.dataset.ui) { setDeep(UI, el.dataset.ui, el.value); if (el.dataset.rerender) render(); return; }
  if (el.dataset.draftbool) {
    setDeep(S.drafts, el.dataset.draftbool, el.checked);
    const d = S.drafts.box; if (d && d.fragile) d.stackable = false;
    save(); render(); return;
  }
  if (el.dataset.draft) {
    let v = el.value; if (el.dataset.num) { const n = Number(String(v).trim().replace(',', '.')); v = String(v).trim() === '' ? '' : isFinite(n) ? n : v; }
    setDeep(S.drafts, el.dataset.draft, v); save();
    if (el.dataset.rerender || el.dataset.draft.startsWith('box.') || el.dataset.draft.startsWith('import.') || el.dataset.cmp) setTimeout(() => render(), 0);
  }
});
document.addEventListener('keydown', ev => { if (ev.key === 'Escape' && UI.modal) closeModal(); });

/* boot */
if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => Scenes.invalidate());
render(true);
