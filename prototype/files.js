'use strict';
/* ============================================================
   files.js — CSV read/write, ZIP (store) writer + reader,
   XLSX read/write, PDF (canvas pages as JPEG), GLB writer.
   ============================================================ */
const Files = (() => {
  const enc = new TextEncoder();
  const dec = new TextDecoder();

  /* ---------- CSV ---------- */
  function csvCell(v) {
    if (v === null || v === undefined) return '';
    const s = String(v);
    return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }
  function csvWrite(rows) { return '﻿' + rows.map(r => r.map(csvCell).join(',')).join('\r\n') + '\r\n'; }
  function csvParse(text) {
    text = text.replace(/^﻿/, '');
    const first = text.split(/\r?\n/)[0] || '';
    const delim = (first.split(';').length > first.split(',').length) ? ';' : ',';
    const rows = []; let row = []; let cell = ''; let q = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (q) {
        if (ch === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; }
        else cell += ch;
      } else if (ch === '"') q = true;
      else if (ch === delim) { row.push(cell); cell = ''; }
      else if (ch === '\n' || ch === '\r') { if (ch === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; }
      else cell += ch;
    }
    if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
    return rows.filter(r => r.some(c => String(c).trim() !== ''));
  }

  /* ---------- ZIP ---------- */
  const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  function crc32(u8) { let c = 0xFFFFFFFF; for (let i = 0; i < u8.length; i++) c = CRC[(c ^ u8[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
  function zipStore(files) {
    const parts = []; const central = []; let offset = 0;
    const d = new Date(); const time = (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1);
    const date = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
    for (const f of files) {
      const name = enc.encode(f.name); const data = typeof f.data === 'string' ? enc.encode(f.data) : f.data;
      const crc = crc32(data);
      const lh = new DataView(new ArrayBuffer(30));
      lh.setUint32(0, 0x04034b50, true); lh.setUint16(4, 20, true); lh.setUint16(6, 0x0800, true); lh.setUint16(8, 0, true);
      lh.setUint16(10, time, true); lh.setUint16(12, date, true); lh.setUint32(14, crc, true); lh.setUint32(18, data.length, true); lh.setUint32(22, data.length, true);
      lh.setUint16(26, name.length, true); lh.setUint16(28, 0, true);
      parts.push(new Uint8Array(lh.buffer), name, data);
      const ch = new DataView(new ArrayBuffer(46));
      ch.setUint32(0, 0x02014b50, true); ch.setUint16(4, 20, true); ch.setUint16(6, 20, true); ch.setUint16(8, 0x0800, true); ch.setUint16(10, 0, true);
      ch.setUint16(12, time, true); ch.setUint16(14, date, true); ch.setUint32(16, crc, true); ch.setUint32(20, data.length, true); ch.setUint32(24, data.length, true);
      ch.setUint16(28, name.length, true); ch.setUint32(42, offset, true);
      central.push(new Uint8Array(ch.buffer), name);
      offset += 30 + name.length + data.length;
    }
    const cdSize = central.reduce((s, p) => s + p.length, 0);
    const eo = new DataView(new ArrayBuffer(22));
    eo.setUint32(0, 0x06054b50, true); eo.setUint16(8, files.length, true); eo.setUint16(10, files.length, true); eo.setUint32(12, cdSize, true); eo.setUint32(16, offset, true);
    return concat([...parts, ...central, new Uint8Array(eo.buffer)]);
  }
  function concat(arrs) { const n = arrs.reduce((s, a) => s + a.length, 0); const out = new Uint8Array(n); let o = 0; for (const a of arrs) { out.set(a, o); o += a.length; } return out; }
  async function unzip(buf) {
    const u8 = new Uint8Array(buf); const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
    let eocd = -1; for (let i = u8.length - 22; i >= Math.max(0, u8.length - 70000); i--) if (dv.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
    if (eocd < 0) throw new Error('zip');
    const count = dv.getUint16(eocd + 10, true); let p = dv.getUint32(eocd + 16, true);
    const out = {};
    for (let k = 0; k < count; k++) {
      if (dv.getUint32(p, true) !== 0x02014b50) throw new Error('zip');
      const method = dv.getUint16(p + 10, true), csize = dv.getUint32(p + 20, true);
      const nl = dv.getUint16(p + 28, true), xl = dv.getUint16(p + 30, true), cl = dv.getUint16(p + 32, true), lo = dv.getUint32(p + 42, true);
      const name = dec.decode(u8.subarray(p + 46, p + 46 + nl));
      const lnl = dv.getUint16(lo + 26, true), lxl = dv.getUint16(lo + 28, true);
      const start = lo + 30 + lnl + lxl; const raw = u8.subarray(start, start + csize);
      out[name] = { method, raw };
      p += 46 + nl + xl + cl;
    }
    return {
      names: Object.keys(out),
      async read(name) {
        const e = out[name]; if (!e) return null;
        if (e.method === 0) return e.raw;
        if (e.method === 8) {
          if (typeof DecompressionStream === 'undefined') throw new Error('deflate');
          const ab = await new Response(new Blob([e.raw]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer();
          return new Uint8Array(ab);
        }
        throw new Error('zip method');
      }
    };
  }

  /* ---------- XLSX ---------- */
  const xmlEsc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');
  const colName = i => { let s = ''; i++; while (i > 0) { const m = (i - 1) % 26; s = String.fromCharCode(65 + m) + s; i = Math.floor((i - 1) / 26); } return s; };
  function xlsxWrite(sheets) {
    const NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    const RNS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const files = [];
    files.push({ name: '[Content_Types].xml', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${sheets.map((s, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('')}</Types>` });
    files.push({ name: '_rels/.rels', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>` });
    files.push({ name: 'xl/workbook.xml', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="${NS}" xmlns:r="${RNS}"><sheets>${sheets.map((s, i) => `<sheet name="${xmlEsc(s.name.replace(/[\[\]:*?/\\]/g, ' ').slice(0, 31))}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('')}</sheets></workbook>` });
    files.push({ name: 'xl/_rels/workbook.xml.rels', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${sheets.map((s, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join('')}<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>` });
    files.push({ name: 'xl/styles.xml', data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="${NS}"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>` });
    sheets.forEach((s, i) => {
      const widths = [];
      s.rows.forEach(r => r.forEach((v, c) => { widths[c] = Math.max(widths[c] || 8, Math.min(60, String(v ?? '').length + 2)); }));
      const cols = widths.length ? `<cols>${widths.map((w, c) => `<col min="${c + 1}" max="${c + 1}" width="${w}" customWidth="1"/>`).join('')}</cols>` : '';
      const rowsXml = s.rows.map((r, ri) => `<row r="${ri + 1}">${r.map((v, ci) => {
        const ref = colName(ci) + (ri + 1); const st = (s.headerRows || []).includes(ri) ? ' s="1"' : '';
        if (v === null || v === undefined || v === '') return '';
        if (typeof v === 'number' && isFinite(v)) return `<c r="${ref}"${st}><v>${v}</v></c>`;
        if (typeof v === 'boolean') return `<c r="${ref}"${st} t="b"><v>${v ? 1 : 0}</v></c>`;
        return `<c r="${ref}"${st} t="inlineStr"><is><t xml:space="preserve">${xmlEsc(v)}</t></is></c>`;
      }).join('')}</row>`).join('');
      files.push({ name: `xl/worksheets/sheet${i + 1}.xml`, data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="${NS}" xmlns:r="${RNS}">${cols}<sheetData>${rowsXml}</sheetData></worksheet>` });
    });
    return zipStore(files);
  }
  async function xlsxRead(buf) {
    const z = await unzip(buf);
    const P = s => new DOMParser().parseFromString(s, 'application/xml');
    const txt = async n => { const d = await z.read(n); return d ? dec.decode(d) : null; };
    const wb = P(await txt('xl/workbook.xml'));
    const sh = wb.getElementsByTagNameNS('*', 'sheet')[0]; if (!sh) throw new Error('sheet');
    const rid = sh.getAttribute('r:id') || sh.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'id');
    let target = 'worksheets/sheet1.xml';
    const relsTxt = await txt('xl/_rels/workbook.xml.rels');
    if (relsTxt) { for (const r of P(relsTxt).getElementsByTagNameNS('*', 'Relationship')) if (r.getAttribute('Id') === rid) target = r.getAttribute('Target'); }
    target = target.replace(/^\/?xl\//, '').replace(/^\//, '');
    const shared = [];
    const ssTxt = await txt('xl/sharedStrings.xml');
    if (ssTxt) for (const si of P(ssTxt).getElementsByTagNameNS('*', 'si')) shared.push([...si.getElementsByTagNameNS('*', 't')].map(t => t.textContent).join(''));
    const sheet = P(await txt('xl/' + target));
    const rows = [];
    for (const r of sheet.getElementsByTagNameNS('*', 'row')) {
      const ri = (+r.getAttribute('r') || rows.length + 1) - 1; const row = [];
      for (const c of r.getElementsByTagNameNS('*', 'c')) {
        const ref = c.getAttribute('r') || ''; const letters = ref.replace(/\d+/g, '');
        let ci = 0; for (const ch of letters) ci = ci * 26 + (ch.charCodeAt(0) - 64); ci = letters ? ci - 1 : row.length;
        const t = c.getAttribute('t'); const vEl = c.getElementsByTagNameNS('*', 'v')[0]; const v = vEl ? vEl.textContent : '';
        let val;
        if (t === 's') val = shared[+v] ?? '';
        else if (t === 'inlineStr') val = [...c.getElementsByTagNameNS('*', 't')].map(x => x.textContent).join('');
        else if (t === 'b') val = v === '1' ? 'true' : 'false';
        else val = v;
        row[ci] = val;
      }
      rows[ri] = row;
    }
    return rows.filter(Boolean).map(r => Array.from(r, x => x ?? '')).filter(r => r.some(c => String(c).trim() !== ''));
  }

  /* ---------- PDF from canvas pages ---------- */
  function dataUrlBytes(url) { const b = atob(url.split(',')[1]); const u = new Uint8Array(b.length); for (let i = 0; i < b.length; i++) u[i] = b.charCodeAt(i); return u; }
  function pdfFromCanvases(canvases, title) {
    const W = 595.28, H = 841.89;
    const chunks = []; let off = 0; const offsets = [];
    const push = d => { const u = typeof d === 'string' ? enc.encode(d) : d; chunks.push(u); off += u.length; };
    push('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
    const n = canvases.length; const objCount = 3 + n * 3;
    const obj = (id, body) => { offsets[id] = off; push(`${id} 0 obj\n`); for (const b of [].concat(body)) push(b); push('\nendobj\n'); };
    obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    obj(2, `<< /Type /Pages /Count ${n} /Kids [${canvases.map((c, i) => `${4 + i * 3} 0 R`).join(' ')}] >>`);
    obj(3, `<< /Title (${String(title || 'Report').replace(/[^\x20-\x7E]/g, '').replace(/([()\\])/g, '\\$1')}) /Producer (Senior Project prototype) >>`);
    canvases.forEach((cv, i) => {
      const pid = 4 + i * 3, cid = pid + 1, iid = pid + 2;
      const jpg = dataUrlBytes(cv.toDataURL('image/jpeg', 0.9));
      const content = `q ${W} 0 0 ${H} 0 0 cm /Im${i} Do Q`;
      obj(pid, `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /XObject << /Im${i} ${iid} 0 R >> >> /Contents ${cid} 0 R >>`);
      obj(cid, [`<< /Length ${content.length} >>\nstream\n`, content, '\nendstream']);
      obj(iid, [`<< /Type /XObject /Subtype /Image /Width ${cv.width} /Height ${cv.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpg.length} >>\nstream\n`, jpg, '\nendstream']);
    });
    const xref = off;
    let x = `xref\n0 ${objCount + 1}\n0000000000 65535 f \n`;
    for (let i = 1; i <= objCount; i++) x += String(offsets[i]).padStart(10, '0') + ' 00000 n \n';
    push(x);
    push(`trailer\n<< /Size ${objCount + 1} /Root 1 0 R /Info 3 0 R >>\nstartxref\n${xref}\n%%EOF\n`);
    return concat(chunks);
  }

  /* ---------- GLB ---------- */
  function srgbToLinear(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
  function glbWrite({ cont, placements, colorOf, names, extrasFor, sceneExtras }) {
    // unit cube centered at origin (glTF Y-up). Mapping: X = x, Y = z, Z = -y
    const P = [], N = [], I = [];
    const faces = [[[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-1, 0, 0], [0, 1, 0], [0, 0, -1]], [[0, 1, 0], [0, 0, 1], [1, 0, 0]], [[0, -1, 0], [0, 0, -1], [1, 0, 0]], [[0, 0, 1], [1, 0, 0], [0, 1, 0]], [[0, 0, -1], [-1, 0, 0], [0, 1, 0]]];
    faces.forEach(([n, a, b]) => {
      const base = P.length / 3;
      for (const [sa, sb] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
        P.push(0.5 * (n[0] + sa * a[0] + sb * b[0]), 0.5 * (n[1] + sa * a[1] + sb * b[1]), 0.5 * (n[2] + sa * a[2] + sb * b[2]));
        N.push(...n);
      }
      // ensure CCW from outside
      const v0 = [P[base * 3], P[base * 3 + 1], P[base * 3 + 2]], v1 = [P[base * 3 + 3], P[base * 3 + 4], P[base * 3 + 5]], v2 = [P[base * 3 + 6], P[base * 3 + 7], P[base * 3 + 8]];
      const e1 = [v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2]], e2 = [v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2]];
      const cr = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
      if (cr[0] * n[0] + cr[1] * n[1] + cr[2] * n[2] > 0) I.push(base, base + 1, base + 2, base, base + 2, base + 3);
      else I.push(base, base + 2, base + 1, base, base + 3, base + 2);
    });
    const L = cont.L / 1000, Wd = cont.W / 1000, Hh = cont.H / 1000;
    const tx = x => x / 1000 - L / 2, tz = y => -(y / 1000 - Wd / 2);
    const LP = []; for (const x of [0, cont.L]) for (const y of [0, cont.W]) for (const z of [0, cont.H]) LP.push(tx(x), z / 1000, tz(y));
    const LI = [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7];
    const dy0 = (cont.W - cont.doorW) / 2, dy1 = dy0 + cont.doorW;
    const DP = [tx(cont.L), 0, tz(dy0), tx(cont.L), cont.doorH / 1000, tz(dy0), tx(cont.L), cont.doorH / 1000, tz(dy1), tx(cont.L), 0, tz(dy1)];
    const DI = [0, 1, 1, 2, 2, 3, 3, 0];
    const views = []; const parts = []; let boff = 0;
    const addView = (arr, target) => { const b = new Uint8Array(arr.buffer); const pad = (4 - (b.length % 4)) % 4; views.push({ buffer: 0, byteOffset: boff, byteLength: b.length, target }); parts.push(b); if (pad) parts.push(new Uint8Array(pad)); boff += b.length + pad; return views.length - 1; };
    const vP = addView(new Float32Array(P), 34962), vN = addView(new Float32Array(N), 34962), vI = addView(new Uint16Array(I), 34963);
    const vLP = addView(new Float32Array(LP), 34962), vLI = addView(new Uint16Array(LI), 34963);
    const vDP = addView(new Float32Array(DP), 34962), vDI = addView(new Uint16Array(DI), 34963);
    const mm = (arr) => { const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity]; for (let i = 0; i < arr.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], arr[i + k]); mx[k] = Math.max(mx[k], arr[i + k]); } return { min: mn, max: mx }; };
    const accessors = [
      { bufferView: vP, componentType: 5126, count: P.length / 3, type: 'VEC3', ...mm(P) },
      { bufferView: vN, componentType: 5126, count: N.length / 3, type: 'VEC3' },
      { bufferView: vI, componentType: 5123, count: I.length, type: 'SCALAR' },
      { bufferView: vLP, componentType: 5126, count: LP.length / 3, type: 'VEC3', ...mm(LP) },
      { bufferView: vLI, componentType: 5123, count: LI.length, type: 'SCALAR' },
      { bufferView: vDP, componentType: 5126, count: DP.length / 3, type: 'VEC3', ...mm(DP) },
      { bufferView: vDI, componentType: 5123, count: DI.length, type: 'SCALAR' }
    ];
    const codes = [...new Set(placements.map(p => p.gcode))];
    const materials = codes.map(c => { const h = colorOf(c).replace('#', ''); const v = [0, 2, 4].map(i => srgbToLinear(parseInt(h.slice(i, i + 2), 16))); return { name: 'group ' + c, pbrMetallicRoughness: { baseColorFactor: [...v, 1], metallicFactor: 0, roughnessFactor: 0.7 } }; });
    materials.push({ name: 'container', pbrMetallicRoughness: { baseColorFactor: [0.2, 0.55, 1, 1], metallicFactor: 0, roughnessFactor: 1 }, emissiveFactor: [0.1, 0.3, 0.8] });
    materials.push({ name: 'door', pbrMetallicRoughness: { baseColorFactor: [0.12, 0.8, 1, 1], metallicFactor: 0, roughnessFactor: 1 }, emissiveFactor: [0.12, 0.8, 1] });
    const meshes = codes.map((c, i) => ({ name: 'box ' + c, primitives: [{ attributes: { POSITION: 0, NORMAL: 1 }, indices: 2, material: i }] }));
    meshes.push({ name: 'container edges', primitives: [{ attributes: { POSITION: 3 }, indices: 4, mode: 1, material: codes.length }] });
    meshes.push({ name: 'door opening', primitives: [{ attributes: { POSITION: 5 }, indices: 6, mode: 1, material: codes.length + 1 }] });
    const nodes = placements.map((p, i) => {
      const node = {
        name: names ? p.id : 'box-' + (i + 1), mesh: codes.indexOf(p.gcode),
        translation: [tx((p.x0 + p.x1) / 2), (p.z0 + p.z1) / 2 / 1000, tz((p.y0 + p.y1) / 2)],
        scale: [p.dx / 1000, p.dz / 1000, p.dy / 1000]
      };
      const ex = extrasFor && extrasFor(p); if (ex) node.extras = ex;
      return node;
    });
    nodes.push({ name: 'container', mesh: codes.length });
    nodes.push({ name: 'door x=L', mesh: codes.length + 1 });
    const bin = concat(parts);
    const gltf = {
      asset: { version: '2.0', generator: 'Senior Project prototype', extras: { note: 'Illustrative geometry from the prototype preview routine, not the Dart engine arrangement. Units: metres. Back wall at -X, door at +X.' } },
      scene: 0, scenes: [{ name: 'Loading plan', nodes: nodes.map((n, i) => i), extras: sceneExtras || {} }],
      nodes, meshes, materials, accessors, bufferViews: views, buffers: [{ byteLength: bin.length }]
    };
    let json = enc.encode(JSON.stringify(gltf));
    const jpad = (4 - (json.length % 4)) % 4; if (jpad) json = concat([json, enc.encode(' '.repeat(jpad))]);
    const total = 12 + 8 + json.length + 8 + bin.length;
    const head = new DataView(new ArrayBuffer(12)); head.setUint32(0, 0x46546C67, true); head.setUint32(4, 2, true); head.setUint32(8, total, true);
    const jh = new DataView(new ArrayBuffer(8)); jh.setUint32(0, json.length, true); jh.setUint32(4, 0x4E4F534A, true);
    const bh = new DataView(new ArrayBuffer(8)); bh.setUint32(0, bin.length, true); bh.setUint32(4, 0x004E4942, true);
    return concat([new Uint8Array(head.buffer), new Uint8Array(jh.buffer), json, new Uint8Array(bh.buffer), bin]);
  }

  return { csvWrite, csvParse, zipStore, unzip, xlsxWrite, xlsxRead, pdfFromCanvases, glbWrite, crc32 };
})();
