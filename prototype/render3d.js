'use strict';
/* ============================================================
   render3d.js — Canvas 2D renderer with true 3D perspective
   projection, near-plane clipping, painter ordering of axis-aligned
   boxes by separating planes, and box IDs printed on box faces.
   ============================================================ */
const Scenes = (() => {
  const scenes = new Set();
  const cams = {};
  let raf = 0, lastT = 0;
  const RM = window.matchMedia ? matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };
  const MONO = "'IBM Plex Mono', ui-monospace, 'SFMono-Regular', Menlo, Consolas, monospace";
  const UI_FONT = "'IBM Plex Sans Arabic', 'Noto Sans Arabic', 'Segoe UI', Tahoma, sans-serif";

  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const mul = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const len = a => Math.hypot(a[0], a[1], a[2]);
  const norm = a => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  const rgbCache = {};
  function rgb(hex) {
    if (rgbCache[hex]) return rgbCache[hex];
    const h = hex.replace('#', '');
    const v = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
    rgbCache[hex] = v; return v;
  }
  function shadeColor(hex, f, boost) {
    const c = rgb(hex); const b = boost || 0;
    return `rgb(${Math.min(255, Math.round(c[0] * f + b))},${Math.min(255, Math.round(c[1] * f + b))},${Math.min(255, Math.round(c[2] * f + b))})`;
  }

  function defaultCam() { return { yaw: -0.62, pitch: 0.5, zoom: 1, mode: 'orbit', insideT: 0.1, lookYaw: Math.PI, lookPitch: -0.1 }; }
  function getCam(id) { return cams[id] || (cams[id] = defaultCam()); }

  function buildCamera(s, cw, ch, cont) {
    const cam = s.cam; let E, f, vfov, near;
    if (cam.mode === 'inside' && s.opts.allowInside) {
      vfov = 70 * Math.PI / 180; near = 35;
      const x = (cont.L - 150) - cam.insideT * (cont.L - 550);
      E = [x, cont.W / 2, Math.min(1600, cont.H - 220)];
      f = [Math.cos(cam.lookPitch) * Math.cos(cam.lookYaw), Math.cos(cam.lookPitch) * Math.sin(cam.lookYaw), Math.sin(cam.lookPitch)];
    } else {
      vfov = 36 * Math.PI / 180; near = 60;
      const T = [cont.L / 2, cont.W / 2, cont.H / 2];
      const R = 0.5 * Math.hypot(cont.L, cont.W, cont.H);
      const hfov = 2 * Math.atan(Math.tan(vfov / 2) * (cw / ch));
      const half = Math.min(vfov, hfov) / 2;
      const d = R / Math.sin(half) * (s.opts.framing || 1) * cam.zoom;
      const cp = Math.cos(cam.pitch);
      E = [T[0] + d * cp * Math.cos(cam.yaw), T[1] + d * cp * Math.sin(cam.yaw), T[2] + d * Math.sin(cam.pitch)];
      f = norm(sub(T, E));
    }
    let r = cross(f, [0, 0, 1]); if (len(r) < 1e-6) r = [0, 1, 0]; r = norm(r);
    const u = cross(r, f);
    const focal = (ch / 2) / Math.tan(vfov / 2);
    return { E, f, r, u, focal, near, cw, ch };
  }
  const toCam = (C, P) => { const d = sub(P, C.E); return [dot(d, C.r), dot(d, C.u), dot(d, C.f)]; };
  const proj = (C, v) => [C.cw / 2 + C.focal * v[0] / v[2], C.ch / 2 - C.focal * v[1] / v[2]];
  function clipNear(pts, n) {
    const out = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      const ain = a[2] >= n, bin = b[2] >= n;
      if (ain) out.push(a);
      if (ain !== bin) { const t = (n - a[2]) / (b[2] - a[2]); out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, n]); }
    }
    return out;
  }
  function screenPoly(C, verts) {
    const cv = clipNear(verts.map(v => toCam(C, v)), C.near);
    if (cv.length < 3) return null;
    return cv.map(v => proj(C, v));
  }
  function pathPoly(ctx, poly) { ctx.beginPath(); ctx.moveTo(poly[0][0], poly[0][1]); for (let i = 1; i < poly.length; i++) ctx.lineTo(poly[i][0], poly[i][1]); ctx.closePath(); }
  function seg(ctx, C, a, b) {
    let A = toCam(C, a), B = toCam(C, b);
    if (A[2] < C.near && B[2] < C.near) return;
    if (A[2] < C.near) { const t = (C.near - A[2]) / (B[2] - A[2]); A = [A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, C.near]; }
    if (B[2] < C.near) { const t = (C.near - B[2]) / (A[2] - B[2]); B = [B[0] + (A[0] - B[0]) * t, B[1] + (A[1] - B[1]) * t, C.near]; }
    const p = proj(C, A), q = proj(C, B);
    ctx.moveTo(p[0], p[1]); ctx.lineTo(q[0], q[1]);
  }

  function boxFaces(b) {
    const { x0, y0, z0, x1, y1, z1 } = b;
    return [
      { n: [-1, 0, 0], v: [[x0, y0, z0], [x0, y1, z0], [x0, y1, z1], [x0, y0, z1]], sh: 0.72 },
      { n: [1, 0, 0], v: [[x1, y0, z0], [x1, y0, z1], [x1, y1, z1], [x1, y1, z0]], sh: 0.8 },
      { n: [0, -1, 0], v: [[x0, y0, z0], [x0, y0, z1], [x1, y0, z1], [x1, y0, z0]], sh: 0.9 },
      { n: [0, 1, 0], v: [[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]], sh: 0.86 },
      { n: [0, 0, -1], v: [[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]], sh: 0.55 },
      { n: [0, 0, 1], v: [[x0, y0, z1], [x0, y1, z1], [x1, y1, z1], [x1, y0, z1]], sh: 1 }
    ];
  }

  /* painter order for non-overlapping AABBs using separating planes */
  function orderBoxes(C, boxes) {
    const n = boxes.length; if (n < 2) return boxes.slice();
    const E = C.E;
    const info = boxes.map(b => {
      const mn = [b.x0, b.y0, b.z0], mx = [b.x1, b.y1, b.z1];
      let minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity, behind = false;
      for (let i = 0; i < 8; i++) {
        const p = [(i & 1) ? mx[0] : mn[0], (i & 2) ? mx[1] : mn[1], (i & 4) ? mx[2] : mn[2]];
        const cv = toCam(C, p);
        if (cv[2] < C.near) { behind = true; continue; }
        const sp = proj(C, cv); minx = Math.min(minx, sp[0]); maxx = Math.max(maxx, sp[0]); miny = Math.min(miny, sp[1]); maxy = Math.max(maxy, sp[1]);
      }
      if (behind) { minx = -1e9; miny = -1e9; maxx = 1e9; maxy = 1e9; }
      const cx = (mn[0] + mx[0]) / 2, cy = (mn[1] + mx[1]) / 2, cz = (mn[2] + mx[2]) / 2;
      return { mn, mx, minx, miny, maxx, maxy, d: Math.hypot(cx - E[0], cy - E[1], cz - E[2]) };
    });
    const adj = Array.from({ length: n }, () => []); const indeg = new Int32Array(n);
    for (let i = 0; i < n; i++) {
      const A = info[i];
      for (let j = i + 1; j < n; j++) {
        const B = info[j];
        if (A.maxx < B.minx || B.maxx < A.minx || A.maxy < B.miny || B.maxy < A.miny) continue;
        let r = 0;
        for (let a = 0; a < 3 && !r; a++) {
          if (A.mx[a] <= B.mn[a] + 1) { const s = (A.mx[a] + B.mn[a]) / 2; r = E[a] > s ? -1 : 1; }
          else if (B.mx[a] <= A.mn[a] + 1) { const s = (B.mx[a] + A.mn[a]) / 2; r = E[a] > s ? 1 : -1; }
        }
        if (!r) r = A.d > B.d ? -1 : 1;
        if (r < 0) { adj[i].push(j); indeg[j]++; } else { adj[j].push(i); indeg[i]++; }
      }
    }
    const out = []; const used = new Uint8Array(n);
    let ready = []; for (let i = 0; i < n; i++) if (!indeg[i]) ready.push(i);
    while (out.length < n) {
      if (!ready.length) { // cycle: take farthest unused
        let k = -1; for (let i = 0; i < n; i++) if (!used[i] && (k < 0 || info[i].d > info[k].d)) k = i;
        ready.push(k); indeg[k] = 0;
      }
      ready.sort((a, b) => info[a].d - info[b].d);
      const i = ready.pop(); if (used[i]) continue;
      used[i] = 1; out.push(boxes[i]);
      for (const j of adj[i]) { if (!used[j] && --indeg[j] === 0) ready.push(j); }
    }
    return out;
  }

  function drawSticker(ctx, C, dpr, face, b, id, poly) {
    const n = face.n; const dims = [b.x1 - b.x0, b.y1 - b.y0, b.z1 - b.z0];
    const c = mul(face.v.reduce((s, v) => add(s, v), [0, 0, 0]), 0.25);
    const Cc = toCam(C, c); if (Cc[2] < C.near * 1.6) return;
    const P = proj(C, Cc);
    let v;
    if (n[2] !== 0) {
      let best = null, bd = Infinity;
      for (const cand of [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0]]) {
        const q = toCam(C, add(c, mul(cand, 100))); if (q[2] < C.near) continue;
        const dy = proj(C, q)[1] - P[1]; if (dy < bd) { bd = dy; best = cand; }
      }
      if (!best) return; v = best;
    } else v = [0, 0, 1];
    const u = cross(v, n);
    const ui = u.findIndex(x => Math.abs(x) > 0.5), vi = v.findIndex(x => Math.abs(x) > 0.5);
    const fu = dims[ui], fv = dims[vi];
    const parts = splitIdLocal(id);
    const s1 = Math.min(fu * 0.84 / (id.length * 0.62 + 0.9), fv * 0.62 / 1.45, 150);
    const s2 = Math.min(fu * 0.84 / (Math.max(parts[0].length, parts[1].length) * 0.62 + 0.9), fv * 0.74 / 2.6, 150);
    const two = s2 > s1 * 1.12;
    let s = two ? s2 : s1;
    const k = 120;
    const Cu = toCam(C, add(c, mul(u, k))), Cv = toCam(C, add(c, mul(v, k)));
    if (Cu[2] < C.near || Cv[2] < C.near) return;
    const PU = proj(C, Cu), PV = proj(C, Cv);
    const ax = (PU[0] - P[0]) / k, ay = (PU[1] - P[1]) / k, bx = -(PV[0] - P[0]) / k, by = -(PV[1] - P[1]) / k;
    // reject degenerate (edge-on) or mirrored mappings
    if (ax * by - ay * bx <= 1e-6) return;
    if (s * Math.hypot(bx, by) < 2.4) return;
    ctx.save();
    pathPoly(ctx, poly); ctx.clip();
    ctx.setTransform(dpr * ax, dpr * ay, dpr * bx, dpr * by, dpr * P[0], dpr * P[1]);
    ctx.direction = 'ltr';
    ctx.font = `700 ${s}px ${MONO}`;
    let tw = two ? Math.max(ctx.measureText(parts[0]).width, ctx.measureText(parts[1]).width) : ctx.measureText(id).width;
    const maxW = fu * 0.86 - s * 0.7;
    if (tw > maxW && maxW > 0) { s *= maxW / tw; ctx.font = `700 ${s}px ${MONO}`; tw = maxW; }
    const w = tw + s * 0.75, h = two ? s * 2.55 : s * 1.45, r = s * 0.28;
    ctx.beginPath();
    ctx.moveTo(-w / 2 + r, -h / 2); ctx.lineTo(w / 2 - r, -h / 2); ctx.quadraticCurveTo(w / 2, -h / 2, w / 2, -h / 2 + r);
    ctx.lineTo(w / 2, h / 2 - r); ctx.quadraticCurveTo(w / 2, h / 2, w / 2 - r, h / 2); ctx.lineTo(-w / 2 + r, h / 2);
    ctx.quadraticCurveTo(-w / 2, h / 2, -w / 2, h / 2 - r); ctx.lineTo(-w / 2, -h / 2 + r); ctx.quadraticCurveTo(-w / 2, -h / 2, -w / 2 + r, -h / 2);
    ctx.closePath();
    ctx.fillStyle = 'rgba(244,247,255,0.96)'; ctx.fill();
    ctx.lineWidth = s * 0.07; ctx.strokeStyle = 'rgba(11,23,57,0.35)'; ctx.stroke();
    ctx.fillStyle = '#0B1739'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    if (two) { ctx.fillText(parts[0], 0, -s * 0.6); ctx.fillText(parts[1], 0, s * 0.64); }
    else ctx.fillText(id, 0, s * 0.04);
    ctx.restore();
  }
  function splitIdLocal(id) { const k = id.indexOf('-'); return k < 0 ? [id, ''] : [id.slice(0, k + 1), id.slice(k + 1)]; }

  function render(s) {
    const canvas = s.canvas; const ctx = s.ctx;
    const dpr = s.fixed ? 1 : Math.min(2, window.devicePixelRatio || 1);
    const cw = s.fixed ? s.fixed.w : canvas.clientWidth, ch = s.fixed ? s.fixed.h : canvas.clientHeight;
    if (!cw || !ch) return;
    if (canvas.width !== Math.round(cw * dpr) || canvas.height !== Math.round(ch * dpr)) { canvas.width = Math.round(cw * dpr); canvas.height = Math.round(ch * dpr); }
    const d = s.opts.getData(); if (!d || !d.cont) return;
    const cont = d.cont;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cw, ch);
    if (s.opts.background) { ctx.fillStyle = s.opts.background; ctx.fillRect(0, 0, cw, ch); }
    const C = buildCamera(s, cw, ch, cont);
    s.C = C;
    const { L, W, H } = cont;
    const walls = [
      { k: 'floor', nin: [0, 0, 1], v: [[0, 0, 0], [L, 0, 0], [L, W, 0], [0, W, 0]] },
      { k: 'ceil', nin: [0, 0, -1], v: [[0, 0, H], [L, 0, H], [L, W, H], [0, W, H]] },
      { k: 'back', nin: [1, 0, 0], v: [[0, 0, 0], [0, W, 0], [0, W, H], [0, 0, H]] },
      { k: 'door', nin: [-1, 0, 0], v: [[L, 0, 0], [L, W, 0], [L, W, H], [L, 0, H]] },
      { k: 'left', nin: [0, 1, 0], v: [[0, 0, 0], [L, 0, 0], [L, 0, H], [0, 0, H]] },
      { k: 'right', nin: [0, -1, 0], v: [[0, W, 0], [L, W, 0], [L, W, H], [0, W, H]] }
    ];
    const light = s.opts.light;
    const far = [], nearW = [];
    for (const w of walls) (dot(sub(C.E, w.v[0]), w.nin) > 0 ? far : nearW).push(w);
    const drawWall = (w, isFar) => {
      const poly = screenPoly(C, w.v); if (!poly) return;
      pathPoly(ctx, poly);
      if (w.k === 'floor') ctx.fillStyle = isFar ? (light ? 'rgba(40,80,170,0.16)' : 'rgba(22,50,122,0.55)') : 'rgba(60,110,230,0.08)';
      else if (w.k === 'door') ctx.fillStyle = isFar ? 'rgba(40,80,190,0.10)' : 'rgba(99,231,255,0.035)';
      else ctx.fillStyle = isFar ? (light ? 'rgba(60,100,200,0.08)' : 'rgba(30,62,150,0.26)') : 'rgba(110,150,255,0.05)';
      ctx.fill();
      if (w.k === 'floor') drawGrid(isFar);
      ctx.beginPath();
      for (let i = 0; i < 4; i++) seg(ctx, C, w.v[i], w.v[(i + 1) % 4]);
      ctx.strokeStyle = isFar ? 'rgba(110,160,255,0.45)' : 'rgba(150,190,255,0.7)'; ctx.lineWidth = isFar ? 1 : 1.3; ctx.stroke();
      if (w.k === 'door') drawDoor();
    };
    const drawGrid = (isFar) => {
      ctx.beginPath();
      for (let x = 500; x < L; x += 500) seg(ctx, C, [x, 0, 0], [x, W, 0]);
      for (let y = 500; y < W; y += 500) seg(ctx, C, [0, y, 0], [L, y, 0]);
      ctx.strokeStyle = `rgba(99,231,255,${isFar ? 0.13 : 0.06})`; ctx.lineWidth = 3; ctx.stroke();
      ctx.strokeStyle = `rgba(99,231,255,${isFar ? 0.34 : 0.14})`; ctx.lineWidth = 0.9; ctx.stroke();
    };
    const drawDoor = () => {
      const y0 = (W - cont.doorW) / 2, y1 = y0 + cont.doorW, h = cont.doorH;
      ctx.beginPath();
      seg(ctx, C, [L, y0, 0], [L, y0, h]); seg(ctx, C, [L, y0, h], [L, y1, h]); seg(ctx, C, [L, y1, h], [L, y1, 0]); seg(ctx, C, [L, y1, 0], [L, y0, 0]);
      ctx.save(); ctx.shadowColor = '#63E7FF'; ctx.shadowBlur = 8; ctx.strokeStyle = '#63E7FF'; ctx.lineWidth = 2; ctx.stroke(); ctx.restore();
    };
    for (const w of far) drawWall(w, true);

    // boxes
    const boxes = d.boxes || [];
    const ordered = orderBoxes(C, boxes);
    const hits = [];
    const labels = d.labels !== false;
    for (const b of ordered) {
      const col = d.colorOf(b.gcode);
      const hl = d.highlightId === b.id || d.selectedId === b.id;
      for (const f of boxFaces(b)) {
        if (dot(sub(C.E, f.v[0]), f.n) <= 0) continue;
        const poly = screenPoly(C, f.v); if (!poly) continue;
        pathPoly(ctx, poly);
        ctx.fillStyle = shadeColor(col, f.sh * (hl ? 1.08 : 1), hl ? 28 : 0); ctx.fill();
        ctx.strokeStyle = 'rgba(6,12,34,0.5)'; ctx.lineWidth = 0.8; ctx.stroke();
        if (labels) drawSticker(ctx, C, dpr, f, b, b.id, poly);
        if (hl) { ctx.save(); pathPoly(ctx, poly); ctx.shadowColor = '#63E7FF'; ctx.shadowBlur = 10; ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 2.2; ctx.stroke(); ctx.restore(); }
        hits.push({ poly, id: b.id });
      }
    }
    for (const w of nearW) drawWall(w, false);
    s.hits = hits;
    // door marker
    const lp = toCam(C, [L, W / 2, Math.min(H, cont.doorH) + 160]);
    if (lp[2] > C.near && d.doorLabel) {
      const p = proj(C, lp);
      ctx.font = `600 10.5px ${UI_FONT}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      const tw = ctx.measureText(d.doorLabel).width + 12;
      ctx.fillStyle = 'rgba(8,12,28,0.72)'; ctx.fillRect(p[0] - tw / 2, p[1] - 9, tw, 18);
      ctx.strokeStyle = 'rgba(99,231,255,0.7)'; ctx.lineWidth = 1; ctx.strokeRect(p[0] - tw / 2, p[1] - 9, tw, 18);
      ctx.fillStyle = '#63E7FF'; ctx.fillText(d.doorLabel, p[0], p[1] + 0.5);
    }
  }

  function pointIn(poly, x, y) {
    let inside = false;
    for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      const xi = poly[i][0], yi = poly[i][1], xj = poly[j][0], yj = poly[j][1];
      if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) inside = !inside;
    }
    return inside;
  }

  function create(canvas, opts) {
    for (const s of scenes) if (s.canvas === canvas) return s;
    const s = { canvas, ctx: canvas.getContext('2d'), opts, cam: getCam(opts.id), dirty: true, lastInteract: 0, hits: [], pointers: new Map(), moved: 0, pinch: 0 };
    if (opts.interactive !== false) bind(s);
    scenes.add(s); kick();
    return s;
  }
  function bind(s) {
    const cv = s.canvas;
    const pos = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    cv.addEventListener('pointerdown', e => {
      cv.setPointerCapture && cv.setPointerCapture(e.pointerId);
      s.pointers.set(e.pointerId, pos(e)); s.moved = 0; s.lastInteract = performance.now();
      if (s.pointers.size === 2) { const p = [...s.pointers.values()]; s.pinch = Math.hypot(p[0][0] - p[1][0], p[0][1] - p[1][1]); }
    });
    cv.addEventListener('pointermove', e => {
      if (!s.pointers.has(e.pointerId)) return;
      const prev = s.pointers.get(e.pointerId), cur = pos(e);
      s.pointers.set(e.pointerId, cur); s.lastInteract = performance.now();
      if (s.pointers.size === 1) {
        const dx = cur[0] - prev[0], dy = cur[1] - prev[1];
        s.moved += Math.abs(dx) + Math.abs(dy);
        if (s.cam.mode === 'inside' && s.opts.allowInside) {
          s.cam.lookYaw -= dx * 0.006; s.cam.lookPitch = clamp(s.cam.lookPitch + dy * 0.005, -1.2, 1.2);
        } else {
          s.cam.yaw -= dx * 0.009; s.cam.pitch = clamp(s.cam.pitch + dy * 0.007, -1.35, 1.45);
        }
        s.dirty = true; kick();
      } else if (s.pointers.size === 2) {
        const p = [...s.pointers.values()]; const dd = Math.hypot(p[0][0] - p[1][0], p[0][1] - p[1][1]);
        if (s.pinch > 0 && dd > 0) zoomScene(s, s.pinch / dd);
        s.pinch = dd; s.moved += 10;
      }
    });
    const up = e => {
      if (!s.pointers.has(e.pointerId)) return;
      const single = s.pointers.size === 1; const p = pos(e);
      s.pointers.delete(e.pointerId);
      if (single && s.moved < 6 && e.type === 'pointerup' && s.opts.onPick) {
        let hit = null; for (let i = s.hits.length - 1; i >= 0; i--) if (pointIn(s.hits[i].poly, p[0], p[1])) { hit = s.hits[i].id; break; }
        s.opts.onPick(hit);
      }
    };
    cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
    cv.addEventListener('wheel', e => {
      e.preventDefault(); s.lastInteract = performance.now();
      if (s.cam.mode === 'inside' && s.opts.allowInside) { s.cam.insideT = clamp(s.cam.insideT + e.deltaY * 0.0008, 0, 1); s.opts.onInside && s.opts.onInside(s.cam.insideT); s.dirty = true; kick(); }
      else zoomScene(s, Math.exp(e.deltaY * 0.0012));
    }, { passive: false });
    cv.addEventListener('keydown', e => {
      const k = e.key; let used = true; s.lastInteract = performance.now();
      const inside = s.cam.mode === 'inside' && s.opts.allowInside;
      if (k === 'ArrowLeft') { if (inside) s.cam.lookYaw += 0.08; else s.cam.yaw += 0.12; }
      else if (k === 'ArrowRight') { if (inside) s.cam.lookYaw -= 0.08; else s.cam.yaw -= 0.12; }
      else if (k === 'ArrowUp') { if (inside) { s.cam.insideT = clamp(s.cam.insideT + 0.04, 0, 1); s.opts.onInside && s.opts.onInside(s.cam.insideT); } else s.cam.pitch = clamp(s.cam.pitch + 0.08, -1.35, 1.45); }
      else if (k === 'ArrowDown') { if (inside) { s.cam.insideT = clamp(s.cam.insideT - 0.04, 0, 1); s.opts.onInside && s.opts.onInside(s.cam.insideT); } else s.cam.pitch = clamp(s.cam.pitch - 0.08, -1.35, 1.45); }
      else if (k === '+' || k === '=') zoomScene(s, 1 / 1.15);
      else if (k === '-' || k === '_') zoomScene(s, 1.15);
      else used = false;
      if (used) { e.preventDefault(); s.dirty = true; kick(); }
    });
  }
  function zoomScene(s, f) {
    if (s.cam.mode === 'inside' && s.opts.allowInside) { s.cam.insideT = clamp(s.cam.insideT + (f < 1 ? 0.06 : -0.06), 0, 1); s.opts.onInside && s.opts.onInside(s.cam.insideT); s.dirty = true; kick(); return; }
    s.cam.zoom = clamp(s.cam.zoom * f, 0.32, 2.6); s.dirty = true; kick(); }

  function frame(t) {
    raf = 0; const dt = lastT ? Math.min(0.05, (t - lastT) / 1000) : 0; lastT = t;
    let any = false;
    for (const s of scenes) {
      if (!s.canvas.isConnected) { scenes.delete(s); continue; }
      any = true;
      if (s.opts.auto && !RM.matches && !document.hidden && performance.now() - s.lastInteract > 3500 && s.cam.mode !== 'inside') { s.cam.yaw += dt * 0.2; s.dirty = true; }
      if (s.dirty) { s.dirty = false; try { render(s); } catch (err) { console.error(err); } }
    }
    if (any) raf = requestAnimationFrame(frame); else lastT = 0;
  }
  function kick() { if (!raf) raf = requestAnimationFrame(frame); }
  function find(id) { for (const s of scenes) if (s.opts.id === id && s.canvas.isConnected) return s; return null; }

  return {
    create, getCam, kick,
    invalidate(id) { for (const s of scenes) if (!id || s.opts.id === id) s.dirty = true; kick(); },
    zoom(id, f) { const s = find(id); if (s) zoomScene(s, f); else { const c = getCam(id); c.zoom = clamp(c.zoom * f, 0.32, 2.6); } },
    reset(id) { const c = getCam(id); const m = c.mode; Object.assign(c, defaultCam(), { mode: m }); const s = find(id); if (s) { s.lastInteract = 0; s.dirty = true; kick(); } },
    setMode(id, mode) { getCam(id).mode = mode; const s = find(id); if (s) { s.dirty = true; kick(); } },
    snapshot(w, h, opts, camOverride) {
      const canvas = document.createElement('canvas');
      const s = { canvas, ctx: canvas.getContext('2d'), opts, cam: Object.assign(defaultCam(), camOverride || {}), fixed: { w, h }, hits: [] };
      render(s); return canvas;
    }
  };
})();
