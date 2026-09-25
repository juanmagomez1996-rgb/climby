
// =====================================================================
// SQUISHIES VIRALES (procedurales) + FÍSICA DE ESPUMA (slow rising)
// =====================================================================
TEXDRAW.strawberry = function (g, w, h) {
  const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#FF6B7A'); gr.addColorStop(1, '#E8324F'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  const r = seeded(17);
  for (let i = 0; i < 120; i++) { const x = r() * w, y = h * 0.08 + r() * h * 0.86; g.fillStyle = '#FFE58A'; g.beginPath(); g.ellipse(x, y, 1.6, 2.8, 0, 0, 7); g.fill(); g.fillStyle = 'rgba(160,20,40,.25)'; g.beginPath(); g.ellipse(x + 1, y + 2.5, 2.4, 1.2, 0, 0, 7); g.fill(); }
};
TEXDRAW.sesame = function (g, w, h) {
  const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#D98B37'); gr.addColorStop(0.5, '#EDAA5C'); gr.addColorStop(1, '#F4C98A'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  const r = seeded(29);
  for (let i = 0; i < 70; i++) { const x = r() * w, y = h * 0.05 + r() * h * 0.38; g.fillStyle = '#FFF4D6'; g.beginPath(); g.ellipse(x, y, 2.2, 3.8, r() * 3, 0, 7); g.fill(); }
};

const sgnPow = (v, p) => Math.sign(v) * Math.pow(Math.abs(v), p);
const smooth01 = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

// Grupos de vértices duplicados (costuras UV / polos) → normales sin rayas al deformar
function dupGroups(g) {
  const a = g.attributes.position, map = new Map();
  for (let i = 0; i < a.count; i++) {
    const k = Math.round(a.getX(i) * 1e4) + ',' + Math.round(a.getY(i) * 1e4) + ',' + Math.round(a.getZ(i) * 1e4);
    const l = map.get(k); if (l) l.push(i); else map.set(k, [i]);
  }
  const out = []; for (const l of map.values()) if (l.length > 1) out.push(l); return out;
}
function fixSeams(g, groups) {
  const n = g.attributes.normal; if (!n) return; const A = n.array;
  for (const l of groups) {
    let x = 0, y = 0, z = 0; for (const i of l) { x += A[i * 3]; y += A[i * 3 + 1]; z += A[i * 3 + 2]; }
    const L = Math.hypot(x, y, z) || 1; x /= L; y /= L; z /= L;
    for (const i of l) { A[i * 3] = x; A[i * 3 + 1] = y; A[i * 3 + 2] = z; }
  }
  n.needsUpdate = true;
}

/** Superelipsoide a partir de una esfera: p<1 = más cuadrado. fn(x,y,z,ox,oy,oz) puede devolver [x,y,z,[r,g,b]] */
function superGeo(key, sx, sy, sz, p, fn, opt = {}) {
  if (GEO[key]) return GEO[key];
  const pw = Array.isArray(p) ? p : [p, p, p];
  const boxy = Math.max(pw[0], pw[1], pw[2]) < 0.7;
  let g;
  if (boxy) {
    // caja redondeada con malla uniforme en las caras planas (así los hundimientos se ven en el centro)
    const n = opt.box || 26; g = new THREE.BoxGeometry(2, 2, 2, n, n, n);
  } else { const seg = opt.seg || [48, 32]; g = new THREE.SphereGeometry(1, seg[0], seg[1]); }
  const a = g.attributes.position;
  const rr = Math.min(pw[0], pw[1], pw[2]) * Math.min(sx, sy, sz) * 1.1;
  const cols = opt.colors ? new Float32Array(a.count * 3).fill(1) : null;
  for (let i = 0; i < a.count; i++) {
    let ox = a.getX(i), oy = a.getY(i), oz = a.getZ(i), x, y, z;
    if (boxy) {
      let X = ox * sx, Y = oy * sy, Z = oz * sz;
      const ix = clamp(X, -(sx - rr), sx - rr), iy = clamp(Y, -(sy - rr), sy - rr), iz = clamp(Z, -(sz - rr), sz - rr);
      let dx = X - ix, dy = Y - iy, dz = Z - iz; const L = Math.hypot(dx, dy, dz);
      if (L > 1e-6) { X = ix + dx / L * rr; Y = iy + dy / L * rr; Z = iz + dz / L * rr; }
      x = X; y = Y; z = Z;
      const u = Math.hypot(X / sx, Y / sy, Z / sz) || 1; ox = X / sx / u; oy = Y / sy / u; oz = Z / sz / u;
    } else { x = sgnPow(ox, pw[0]) * sx; y = sgnPow(oy, pw[1]) * sy; z = sgnPow(oz, pw[2]) * sz; }
    if (fn) { const r = fn(x, y, z, ox, oy, oz); if (r) { x = r[0]; y = r[1]; z = r[2]; if (r[3] && cols) cols.set(r[3], i * 3); } }
    a.setXYZ(i, x, y, z);
  }
  if (cols) g.setAttribute('color', new THREE.BufferAttribute(cols, 3));
  g.computeVertexNormals(); fixSeams(g, dupGroups(g)); g.computeBoundingSphere();
  return (GEO[key] = g);
}
function cachedGeo(key, make) { return GEO[key] || (GEO[key] = make()); }
const colArr = (hex) => { const c = new THREE.Color(hex); return [c.r, c.g, c.b]; };

// ---------- cara kawaii genérica: raycast sobre la superficie real de la pieza
const _faceRay = new THREE.Raycaster();
function placeFace(c, target, ox, oy, dir, scale, kind) {
  if (c.sil) return;
  c.root.updateMatrixWorld(true);
  const origin = dir === 'top' ? new THREE.Vector3(ox, 30, oy) : new THREE.Vector3(ox, oy, 30);
  const d = dir === 'top' ? new THREE.Vector3(0, -1, 0) : new THREE.Vector3(0, 0, -1);
  _faceRay.set(origin, d); const hits = _faceRay.intersectObject(target, false); if (!hits.length) return;
  const h = hits[0]; const n = h.face.normal.clone().transformDirection(target.matrixWorld);
  const up = dir === 'top' ? new THREE.Vector3(0, 0, -1) : new THREE.Vector3(0, 1, 0);
  const xA = new THREE.Vector3().crossVectors(up, n).normalize(); const yA = new THREE.Vector3().crossVectors(n, xA);
  const grp = new THREE.Group(); grp.position.copy(h.point).addScaledVector(n, 0.01);
  grp.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(xA, yA, n)); grp.scale.setScalar(scale); c.inner.add(grp);
  const put = (geo, mt, x, y, z, s, rz) => { const m = new THREE.Mesh(geo, mt); m.position.set(x, y, z); if (s) m.scale.set(s[0], s[1], s[2]); if (rz) m.rotation.z = rz; m.castShadow = false; grp.add(m); return m; };
  const fk = kind || c.data.face || 'happy';
  if (fk === 'frog') {
    put(G.wideSmile, MAT.mouth, 0, 0, 0.01, null, Math.PI);
    for (const s of [-1, 1]) put(G.blush, MAT.blush, 0.5 * s, -0.02, 0.01);
    return;
  }
  for (const s of [-1, 1]) {
    if (fk === 'sleepy' || (fk === 'wink' && s === 1)) put(G.lid, MAT.mouth, 0.28 * s, 0.07, 0.02, null, Math.PI);
    else { put(G.eye, MAT.eye, 0.28 * s, 0.07, -0.02, [1, 1.12, 0.6]); put(G.hi, MAT.white, 0.28 * s + 0.045, 0.13, 0.06); }
    put(G.blush, MAT.blush, 0.45 * s, -0.09, 0.005);
  }
  if (fk === 'surprised') put(G.oMouth, MAT.mouth, 0, -0.1, 0.01); else put(G.smile, MAT.mouth, 0, -0.08, 0.01, null, Math.PI);
}

// ---------- constructores de cada squishy viral (y=0 es el piso)
const FAMOUS_BUILD = {
  butter(c) {
    const body = c.add(superGeo('f_butter', 1.2, 0.62, 0.78, 0.3), c.main, 0, 0.62, 0);
    c.add(superGeo('f_butter_foil', 0.44, 0.665, 0.825, 0.3), c.M('#E9C766', 0.32, { metalness: 0.5 }), 0.84, 0.62, 0);
    c.add(superGeo('f_butter_band', 0.09, 0.672, 0.832, 0.3), c.M('#4F86E8', 0.5), 0.5, 0.62, 0);
    c.add(cachedGeo('f_butter_curl', () => new THREE.TorusGeometry(0.17, 0.075, 12, 26, Math.PI * 1.55)), c.accent, -0.5, 1.3, 0.05, { rot: [0.25, 0.5, 0] });
    placeFace(c, body, -0.32, 0.66, 'front', 1.0);
    return body;
  },
  toast(c) {
    const crust = colArr('#C98B4E'), crumb = colArr('#F8E1AE');
    const g = superGeo('f_toast', 1.0, 0.98, 0.3, [0.42, 0.5, 0.35], (x, y, z, ox, oy, oz) => {
      const t = Math.max(0, oy); x *= 1 + 0.2 * Math.sin(t * Math.PI * 0.85); y += 0.1 * t * t * t;
      const f = smooth01(0.4, 0.62, Math.abs(oz));
      return [x, y, z, [lerp(crust[0], crumb[0], f), lerp(crust[1], crumb[1], f), lerp(crust[2], crumb[2], f)]];
    }, { colors: true });
    if (!c.sil) c.main.vertexColors = true;
    const body = c.add(g, c.main, 0, 1.0, 0);
    c.add(superGeo('f_toast_pat', 0.33, 0.27, 0.1, 0.3), c.M('#FFE38F', 0.32), 0.22, 1.42, 0.33, { rot: [0, 0, 0.18] });
    placeFace(c, body, -0.08, 0.78, 'front', 0.95);
    return body;
  },
  cheese(c) {
    const r = seeded(21); const holes = [];
    while (holes.length < 11) { let x = r() * 2 - 1, y = r() * 2 - 1, z = r() * 2 - 1; const L = Math.hypot(x, y, z) || 1; x /= L; y /= L; z /= L; if (z > 0.55 && Math.abs(x) < 0.55 && y > -0.5 && y < 0.6) continue; holes.push([x, y, z, 0.025 + r() * 0.04]); }
    const g = superGeo('f_cheese', 1.25, 0.62, 0.95, 0.28, (x, y, z, ox, oy, oz) => {
      const taper = 0.2 + 0.8 * (oz + 1) / 2; x *= taper;
      let k = 0; for (const h of holes) { const d = 1 - (ox * h[0] + oy * h[1] + oz * h[2]); if (d < h[3]) k = Math.max(k, 1 - d / h[3]); }
      const s = 1 - 0.16 * k * k; const sh = 1 - 0.28 * k;
      return [x * s, y * s, z * s, [sh, sh * 0.96, sh * 0.85]];
    }, { colors: true, seg: [64, 44] });
    if (!c.sil) c.main.vertexColors = true;
    const body = c.add(g, c.main, 0, 0.62, 0);
    placeFace(c, body, 0, 0.62, 'front', 0.95);
    return body;
  },
  strawberry(c) {
    const body = c.add(superGeo('f_straw', 1, 1.12, 1, 1, (x, y, z, ox, oy) => {
      const t = (oy + 1) / 2; let w = t < 0.72 ? Math.pow(t / 0.72, 0.62) : 1 - 0.3 * ((t - 0.72) / 0.28) ** 2;
      w = Math.max(0.05, w); const top = oy > 0.85 ? (oy - 0.85) / 0.15 : 0;
      return [x * w * 1.06, y - 0.12 * top, z * w];
    }), c.main, 0, 1.12, 0);
    const leaf = c.M('#5BBF6A', 0.6);
    for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; c.add(cachedGeo('f_sleaf', () => new THREE.ConeGeometry(0.16, 0.6, 6)), leaf, Math.cos(a) * 0.32, 2.1, Math.sin(a) * 0.32, { rot: [Math.sin(a) * 1.35, 0, -Math.cos(a) * 1.35], s: [1, 1, 0.45] }); }
    c.add(cachedGeo('f_stem', () => new THREE.CylinderGeometry(0.05, 0.07, 0.34, 8)), c.M('#4E9A4C', 0.7), 0, 2.28, 0, { rot: [0, 0, 0.15] });
    placeFace(c, body, 0, 0.95, 'front', 0.95);
    return body;
  },
  icecube(c) {
    const body = c.add(superGeo('f_ice', 0.95, 0.95, 0.95, 0.22), c.main, 0, 0.95, 0);
    const bm = c.M('#ffffff', 0.1, { transparent: true, opacity: 0.55 }); const r = seeded(33);
    for (let i = 0; i < 6; i++) c.add(G.ball, bm, (r() - 0.5) * 1.1, 0.5 + r() * 0.9, (r() - 0.5) * 1.1, { s: [0.06 + r() * 0.05, 0.06 + r() * 0.05, 0.06 + r() * 0.05] });
    placeFace(c, body, 0, 1.0, 'front', 0.95);
    return body;
  },
  egg(c) {
    const white = c.add(superGeo('f_egg', 1.35, 0.15, 1.15, [0.9, 0.8, 0.9], (x, y, z, ox, oy, oz) => {
      const a = Math.atan2(oz, ox); const w = 1 + 0.09 * Math.sin(a * 5 + 0.5) + 0.06 * Math.sin(a * 3 + 2);
      if (oy < -0.2) y = -0.03 + (y + 0.03) * 0.3; return [x * w, y, z * w];
    }), c.main, 0, 0.15, 0);
    const yolk = c.add(superGeo('f_yolk', 0.56, 0.44, 0.56, 1, (x, y, z, ox, oy) => oy < 0 ? [x, y * 0.3, z] : null), c.M('#FFB320', 0.18), 0.12, 0.26, 0.08);
    placeFace(c, yolk, 0.12, 0.45, 'front', 0.62);
    return white;
  },
  dumpling(c) {
    const body = c.add(superGeo('f_dump', 1.15, 0.78, 1.15, 0.9, (x, y, z, ox, oy, oz) => {
      const a = Math.atan2(oz, ox); const t = Math.max(0, oy);
      const s = 1 - 0.55 * t ** 3 + 0.07 * Math.sin(a * 11) * t ** 1.4 * (1 - t ** 4);
      let yy = y; if (oy < -0.5) yy = (-0.5 + (oy + 0.5) * 0.35) * 0.78;
      yy += 0.14 * t ** 6; return [x * s, yy, z * s];
    }, { seg: [64, 40] }), c.main, 0, 0.64, 0);
    const bam = c.M('#D8B06A', 0.85, { side: THREE.DoubleSide }), band = c.M('#B8893F', 0.8);
    c.add(cachedGeo('f_steam_ring', () => new THREE.CylinderGeometry(1.52, 1.48, 0.46, 40, 1, true)), bam, 0, 0.23, 0, { noDeform: true });
    for (const y of [0.03, 0.46]) c.add(cachedGeo('f_steam_rim', () => new THREE.TorusGeometry(1.52, 0.055, 8, 48)), band, 0, y, 0, { rot: [Math.PI / 2, 0, 0], noDeform: true });
    c.add(cachedGeo('f_steam_floor', () => new THREE.CylinderGeometry(1.48, 1.48, 0.08, 40)), c.M('#C99A52', 0.9), 0, 0.05, 0, { noDeform: true });
    placeFace(c, body, 0, 0.85, 'front', 0.95);
    return body;
  },
  dango(c) {
    c.add(cachedGeo('f_dstick', () => new THREE.CylinderGeometry(0.06, 0.06, 3.05, 10)), c.M('#D6AE77', 0.8), 0, 1.58, 0, { noDeform: true });
    const bg = superGeo('f_dango', 0.52, 0.47, 0.52, 1);
    c.add(bg, c.M('#B6E3A0', 0.55), 0, 0.72, 0);
    const mid = c.add(bg, c.main, 0, 1.64, 0);
    c.add(bg, c.M('#FFB3C7', 0.55), 0, 2.56, 0);
    placeFace(c, mid, 0, 1.64, 'front', 0.8);
    return mid;
  },
  frogwell(c) {
    const body = c.add(superGeo('f_frog', 1.0, 0.78, 0.92, 0.85), c.main, 0, 0.95, 0);
    const eb = superGeo('f_frogeye', 0.3, 0.28, 0.28, 1);
    for (const s of [-1, 1]) {
      c.add(eb, c.main, 0.42 * s, 1.62, 0.2);
      if (!c.sil) { c.add(G.eye, MAT.eye, 0.42 * s, 1.68, 0.44, { s: [1.25, 1.25, 1.25] }); c.add(G.hi, MAT.white, 0.42 * s + 0.05, 1.75, 0.58); }
    }
    c.add(superGeo('f_frogbelly', 0.55, 0.4, 0.2, 1), c.M('#E3F6CF', 0.6), 0, 0.74, 0.74);
    const st = [c.M('#B8B0C8', 0.9), c.M('#D2CBDC', 0.9), c.M('#A9A1BA', 0.9)];
    const sg = cachedGeo('f_stone', () => new THREE.BoxGeometry(0.64, 0.34, 0.36));
    for (let row = 0; row < 2; row++) for (let i = 0; i < 12; i++) {
      const a = (i + row * 0.5) / 12 * Math.PI * 2;
      c.add(sg, st[(i + row) % 3], Math.cos(a) * 1.3, 0.17 + row * 0.34, Math.sin(a) * 1.3, { rot: [0, -a + Math.PI / 2, 0], noDeform: true });
    }
    placeFace(c, body, 0, 1.12, 'front', 1.0, 'frog');
    return body;
  },
  donut(c) {
    c.add(cachedGeo('f_dough', () => new THREE.TorusGeometry(0.75, 0.42, 22, 44)), c.M('#E3A86A', 0.75), 0, 0.42, 0, { rot: [-Math.PI / 2, 0, 0] });
    const ig = cachedGeo('f_icing', () => {
      const g = new THREE.TorusGeometry(0.75, 0.445, 22, 44); const a = g.attributes.position;
      for (let i = 0; i < a.count; i++) {
        const x = a.getX(i), y = a.getY(i), z = a.getZ(i); const u = Math.atan2(y, x); const cx = Math.cos(u) * 0.75, cy = Math.sin(u) * 0.75;
        const thr = -0.02 + 0.09 * Math.sin(u * 7) + 0.05 * Math.sin(u * 13 + 1);
        if (z < thr) a.setXYZ(i, cx + (x - cx) * 0.9, cy + (y - cy) * 0.9, z * 0.9);
      }
      g.computeVertexNormals(); return g;
    });
    const icing = c.add(ig, c.main, 0, 0.42, 0, { rot: [-Math.PI / 2, 0, 0] });
    const r = seeded(41); const sp = cachedGeo('f_sprinkle', () => new THREE.CylinderGeometry(0.03, 0.03, 0.17, 6));
    const cols = ['#FFFFFF', '#FFD65A', '#7FD6FF', '#9BE58A', '#B98CFF', '#FF6F91'].map(h => c.M(h, 0.5));
    for (let i = 0; i < 26; i++) {
      const u = r() * Math.PI * 2, v = 0.35 + r() * 2.4; const dist = 0.75 + 0.45 * Math.cos(v);
      c.add(sp, cols[i % cols.length], Math.cos(u) * dist, 0.42 + 0.45 * Math.sin(v), Math.sin(u) * dist, { rot: [Math.PI / 2 + (r() - 0.5) * 0.6, 0, r() * 6] });
    }
    placeFace(c, icing, 0, 0.55, 'front', 0.72);
    return icing;
  },
  grapes(c) {
    const gg = cachedGeo('f_grape', () => new THREE.SphereGeometry(1, 28, 20));
    const pts = [[0, 1.55, 0.2, 0.5], [-0.62, 1.6, -0.05, 0.4], [0.62, 1.6, -0.05, 0.4], [-0.3, 1.78, -0.55, 0.4], [0.32, 1.74, -0.55, 0.4], [-0.38, 1.0, 0.1, 0.4], [0.38, 1.0, 0.1, 0.4], [0, 1.05, -0.4, 0.4], [0, 0.45, 0.05, 0.4]];
    let front = null;
    pts.forEach((p, i) => { const m = c.add(gg, c.main, p[0], p[1], p[2], { s: [p[3], p[3] * 0.98, p[3]] }); if (i === 0) front = m; });
    c.add(cachedGeo('f_gstem', () => new THREE.CylinderGeometry(0.05, 0.07, 0.45, 8)), c.M('#7A5A3A', 0.8), 0, 2.2, -0.2, { rot: [-0.3, 0, 0] });
    c.add(superGeo('f_leaf', 0.45, 0.04, 0.3, 0.9), c.M('#78C267', 0.6), 0.35, 2.3, -0.3, { rot: [0, 0, -0.4] });
    placeFace(c, front, 0, 1.55, 'front', 0.75);
    return front;
  },
  burger(c) {
    c.add(superGeo('f_bunb', 1.15, 0.26, 1.15, [0.7, 0.6, 0.7], (x, y, z, ox, oy) => oy < 0 ? [x, y * 0.5, z] : null), c.M('#E2A459', 0.7), 0, 0.14, 0);
    c.add(superGeo('f_patty', 1.25, 0.17, 1.25, 0.6, (x, y, z, ox, oy, oz) => { const a = Math.atan2(oz, ox); const w = 1 + 0.03 * Math.sin(a * 9); return [x * w, y, z * w]; }), c.M('#6E4129', 0.85), 0, 0.5, 0);
    c.add(superGeo('f_cheese_s', 1.15, 0.045, 1.15, [0.22, 1, 0.22], (x, y, z, ox, oy, oz) => { const e = Math.max(0, Math.abs(ox) + Math.abs(oz) - 1.1) / 0.9; return [x, y - 0.3 * e * e, z]; }), c.M('#FFC53A', 0.45), 0, 0.69, 0, { rot: [0, Math.PI / 4, 0] });
    c.add(superGeo('f_lettuce', 1.35, 0.05, 1.35, 0.9, (x, y, z, ox, oy, oz) => { const a = Math.atan2(oz, ox), r = Math.hypot(ox, oz), w = 1 + 0.04 * Math.sin(a * 9); return [x * w, y + 0.07 * Math.sin(a * 14) * r * r, z * w]; }), c.M('#86CF57', 0.6), 0, 0.77, 0);
    const top = c.add(superGeo('f_bunt', 1.22, 0.72, 1.22, [0.85, 0.9, 0.85], (x, y, z, ox, oy) => oy < 0 ? [x, y * 0.22, z] : null), c.main, 0, 0.84, 0);
    placeFace(c, top, 0, 1.18, 'front', 0.9);
    return top;
  },
  catpaw(c) {
    const body = c.add(superGeo('f_paw', 1.1, 0.62, 1.0, [0.8, 0.85, 0.8], (x, y, z, ox, oy) => oy < -0.35 ? [x, -0.217 + (y + 0.217) * 0.3, z] : null), c.main, 0, 0.34, 0);
    const pink = c.M('#FF9EC4', 0.55);
    const surf = (x, z) => 0.34 + 0.62 * Math.sqrt(Math.max(0, 1 - (x / 1.1) ** 2 - (z / 1.0) ** 2));
    const toe = superGeo('f_toe', 0.2, 0.14, 0.22, 1);
    for (const [x, z] of [[-0.55, -0.3], [-0.2, -0.52], [0.2, -0.52], [0.55, -0.3]]) c.add(toe, pink, x, surf(x, z) - 0.03, z, { rot: [-z * 0.8, 0, x * 0.7] });
    c.add(superGeo('f_pad', 0.46, 0.2, 0.36, [0.8, 1, 0.8]), pink, 0, surf(0, 0.28) - 0.03, 0.28, { rot: [0.25, 0, 0] });
    return body;
  },
};

function buildFamousParts(spd, o) {
  const accentCol = o.look.c ? lighter(o.look.c, 0.35) : new THREE.Color('#FFF1B8');
  const c = {
    root: o.root, inner: o.inner, main: o.mat, sil: o.sil, data: o.data,
    accent: o.sil ? MAT.silhouette : new THREE.MeshStandardMaterial({ color: accentCol, roughness: 0.45 }),
    M(hex, r = 0.6, extra = {}) { return o.sil ? MAT.silhouette : new THREE.MeshStandardMaterial(Object.assign({ color: hex, roughness: r, metalness: 0 }, extra)); },
    add(geo, mt, x = 0, y = 0, z = 0, op = {}) {
      const m = new THREE.Mesh(geo, mt); m.position.set(x, y, z);
      if (op.rot) m.rotation.set(op.rot[0], op.rot[1], op.rot[2]); if (op.s) m.scale.set(op.s[0], op.s[1], op.s[2]);
      if (op.noDeform) m.userData.noDeform = true; m.castShadow = !o.noShadow; o.inner.add(m); return m;
    },
  };
  o.inner.position.y = 0;
  const b = (FAMOUS_BUILD[spd.id] || FAMOUS_BUILD.butter)(c);
  return b;
}

// =====================================================================
// FÍSICA DE ESPUMA v2
// - Cada dedo es una fuente gaussiana (hundir) o de jalón (estirar) en el espacio del squishy.
// - Rigidez progresiva: entre más hundido, más cuesta seguir hundiendo (la espuma se compacta).
// - Recuperación en 2 fases: un rebote rápido (~35%) y luego una cola larga (slow rise real).
// - Conservación de volumen: lo que hundes se infla en el resto; lo que estiras adelgaza el resto.
// - El fondo queda apoyado en la mesa; palma, apretón y torsión son "ejes" globales.
// =====================================================================
function deformInit(sq) {
  const inner = sq.inner; sq.root.updateMatrixWorld(true);
  const invInner = new THREE.Matrix4().copy(inner.matrixWorld).invert();
  const shared = new Set(Object.values(MAT));
  const meshes = []; const box = new THREE.Box3(); const v = new THREE.Vector3(); let area = 0;
  const ta = new THREE.Vector3(), tb = new THREE.Vector3(), tc = new THREE.Vector3();
  inner.traverse(o => {
    if (!o.isMesh || o.userData.noDeform || o.userData.isWax) return;
    if (!o.userData.ownGeo) { o.geometry = o.geometry.clone(); o.userData.ownGeo = true; }
    if (shared.has(o.material)) o.material = o.material.clone();
    const g = o.geometry, pos = g.attributes.position, n = pos.count;
    if (!g.attributes.normal) g.computeVertexNormals();
    const rel = new THREE.Matrix4().multiplyMatrices(invInner, o.matrixWorld);
    const nm = new THREE.Matrix3().getNormalMatrix(rel);
    const P = new Float32Array(n * 3), PN = new Float32Array(n * 3), N0 = g.attributes.normal.array;
    for (let i = 0; i < n; i++) {
      v.fromBufferAttribute(pos, i).applyMatrix4(rel); P[i * 3] = v.x; P[i * 3 + 1] = v.y; P[i * 3 + 2] = v.z; box.expandByPoint(v);
      v.set(N0[i * 3], N0[i * 3 + 1], N0[i * 3 + 2]).applyMatrix3(nm).normalize(); PN[i * 3] = v.x; PN[i * 3 + 1] = v.y; PN[i * 3 + 2] = v.z;
    }
    const idx = g.index ? g.index.array : null, tn = idx ? idx.length : n;
    for (let t = 0; t < tn; t += 3) {
      const a = idx ? idx[t] : t, b = idx ? idx[t + 1] : t + 1, c = idx ? idx[t + 2] : t + 2;
      ta.fromArray(P, a * 3); tb.fromArray(P, b * 3).sub(ta); tc.fromArray(P, c * 3).sub(ta); area += tb.cross(tc).length() * 0.5;
    }
    if (!g.attributes.color) g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(n * 3).fill(1), 3));
    o.material.vertexColors = true; o.material.needsUpdate = true;
    meshes.push({ o, g, P, PN, Q: P.slice(), B: pos.array.slice(), C0: g.attributes.color.array.slice(), N0: N0.slice(), relInv: rel.clone().invert(), dups: dupGroups(g) });
  });
  const center = box.getCenter(new THREE.Vector3()), size = box.getSize(new THREE.Vector3());
  const ax = () => ({ v: 0, f: 0, s: 0, hold: false, target: 1, rate: 4 });
  sq.def = { meshes, src: [], center, size, ymin: box.min.y, area: Math.max(0.5, area), ref: Math.max(0.6, Math.max(size.x, size.y, size.z) / 2),
    ax: { flat: ax(), pinch: ax(), twist: ax() }, flat: 0, pinch: 0, twist: 0, active: false, maxDepth: 0, stiff: null, moved: 0 };
}
function deformRestore(D) {
  for (const m of D.meshes) {
    m.g.attributes.position.array.set(m.B); m.g.attributes.position.needsUpdate = true;
    m.g.attributes.color.array.set(m.C0); m.g.attributes.color.needsUpdate = true;
    m.g.attributes.normal.array.set(m.N0); m.g.attributes.normal.needsUpdate = true; m.g.boundingSphere = null; m.Q.set(m.P);
  }
  D.moved++;
}
function deformUpdate(sq, dt) {
  const D = sq.def; if (!D) return;
  const tauS = Math.max(0.15, sq.rise / 3), tauF = 0.05 + sq.rise * 0.02;
  const kF = Math.min(1, dt / tauF), kS = Math.min(1, dt / tauS);
  let any = false, maxD = 0;
  for (let i = D.src.length - 1; i >= 0; i--) {
    const s = D.src[i];
    if (s.held) {
      s.t += dt;
      if (s.kind === 'dent') {
        const fill = s.target / s.max, st = D.stiff ? D.stiff(s) : 1;
        s.target = Math.min(s.max, s.target + dt * s.max * (2.8 * s.force * Math.pow(Math.max(0, 1 - fill), 1.25) + 0.05) * st);
      }
      s.depth = damp(s.depth, s.target, s.rate || (s.kind === 'pull' ? 18 : 14), dt); s.f = s.depth * 0.35; s.s = s.depth * 0.65;
    } else { s.f -= s.f * kF; s.s -= s.s * kS; s.depth = s.f + s.s; }
    if (!s.held && s.depth <= 0.002) { D.src.splice(i, 1); continue; }
    any = true; maxD = Math.max(maxD, s.depth / s.max);
  }
  let axAny = false;
  for (const k in D.ax) {
    const a = D.ax[k];
    if (a.hold) { a.v = damp(a.v, a.target, a.rate, dt); a.f = a.v * 0.35; a.s = a.v * 0.65; }
    else { a.f -= a.f * kF; a.s -= a.s * kS; a.v = a.f + a.s; if (Math.abs(a.v) < 0.002) a.v = a.f = a.s = 0; }
    if (a.v || a.hold) axAny = true;
  }
  D.flat = D.ax.flat.v; D.pinch = D.ax.pinch.v; D.twist = D.ax.twist.v;
  D.maxDepth = Math.max(maxD, D.flat, D.pinch, Math.abs(D.twist));
  if (!any && !axAny) { if (D.active) { deformRestore(D); D.active = false; } return; }
  D.active = true; deformApply(D); D.moved++;
}
function deformApply(D) {
  const C = D.center, ymin = D.ymin, H = Math.max(0.3, D.size.y), src = D.src;
  let vol = 0;
  for (const s of src) { s.re = s.r * (0.8 + 0.45 * Math.min(1, s.depth / s.max)); s.R2 = s.re * s.re; vol += (s.kind === 'pull' ? -0.7 : 1) * s.depth * s.R2 * 1.3; }
  const b0 = clamp(vol / D.area * 1.9, -0.08 * D.ref, 0.24 * D.ref);
  const flatK = D.flat * 0.62, pinchK = D.pinch * 0.62, tw = D.twist;
  vol += (flatK + pinchK * 0.8) * 0; // (la palma y el apretón ya redistribuyen volumen con su propio perfil)
  for (const m of D.meshes) {
    const pos = m.g.attributes.position.array, col = m.g.attributes.color.array, P = m.P, Q = m.Q, C0 = m.C0, e = m.relInv.elements;
    for (let i = 0, n = P.length / 3; i < n; i++) {
      const i3 = i * 3; let x = P[i3], y = P[i3 + 1], z = P[i3 + 2];
      let cx = x - C.x, cy = y - C.y, cz = z - C.z; const cl = Math.hypot(cx, cy, cz) || 1; cx /= cl; cy /= cl; cz /= cl;
      let dx = 0, dy = 0, dz = 0, dent = 0, pull = 0;
      for (let j = 0; j < src.length; j++) {
        const s = src[j]; const ex = x - s.c.x, ey = y - s.c.y, ez = z - s.c.z; const d2 = ex * ex + ey * ey + ez * ez;
        if (d2 > s.R2 * 9) continue;
        let g = cx * s.n.x + cy * s.n.y + cz * s.n.z; g = g < -0.2 ? 0 : g > 0.45 ? 1 : (g + 0.2) / 0.65; if (g <= 0) continue; g = g * g * (3 - 2 * g);
        const w = Math.exp(-d2 / s.R2);
        if (s.kind === 'pull') { const a = s.depth * w * g; dx += s.dir.x * a; dy += s.dir.y * a; dz += s.dir.z * a; pull += w * g * s.depth / s.max; }
        else {
          const w2 = Math.exp(-d2 / (s.R2 * 3.2)); const a = (-s.depth * w + s.depth * 0.18 * (w2 - w)) * g;
          dx += s.n.x * a; dy += s.n.y * a; dz += s.n.z * a; dent += s.depth * w * g / s.max;
        }
      }
      if (b0 !== 0) { const k = b0 * Math.max(0, 1 - dent * 1.4 - pull); dx += cx * k; dy += cy * k * 0.6; dz += cz * k; }
      x += dx; y += dy; z += dz;
      let shade = Math.min(0.42, dent * 0.4) - Math.min(0.12, pull * 0.12);
      if (flatK > 0) { const t = y - ymin; y = ymin + t * (1 - flatK); const s2 = 1 + flatK * 0.62 * Math.sin(clamp(t / H, 0, 1) * Math.PI * 0.9 + 0.15); x = C.x + (x - C.x) * s2; z = C.z + (z - C.z) * s2; shade += flatK * 0.2 * clamp(t / H, 0, 1); }
      if (pinchK > 0) { const t = y - ymin, mid = Math.sin(clamp(t / H, 0, 1) * Math.PI); x = C.x + (x - C.x) * (1 - pinchK * (0.75 + 0.25 * mid)); y = ymin + t * (1 + pinchK * 0.5); z = C.z + (z - C.z) * (1 + pinchK * (0.3 + 0.25 * mid)); shade += pinchK * 0.2 * (1 - Math.abs(cx)); }
      if (tw) { const t = clamp((y - ymin) / H, 0, 1), th = tw * t, cs = Math.cos(th), sn = Math.sin(th), rx = x - C.x, rz = z - C.z; x = C.x + rx * cs - rz * sn; z = C.z + rx * sn + rz * cs; shade += Math.abs(tw) * 0.1 * Math.sin(t * Math.PI); }
      if (y < ymin) y = ymin; // apoyado en la mesa: se desparrama, no atraviesa el piso
      Q[i3] = x; Q[i3 + 1] = y; Q[i3 + 2] = z;
      pos[i3] = e[0] * x + e[4] * y + e[8] * z + e[12]; pos[i3 + 1] = e[1] * x + e[5] * y + e[9] * z + e[13]; pos[i3 + 2] = e[2] * x + e[6] * y + e[10] * z + e[14];
      const sh = clamp(1 - shade, 0.52, 1.1);
      col[i3] = C0[i3] * sh; col[i3 + 1] = C0[i3 + 1] * sh; col[i3 + 2] = C0[i3 + 2] * sh;
    }
    m.g.attributes.position.needsUpdate = true; m.g.attributes.color.needsUpdate = true;
    m.g.computeVertexNormals(); fixSeams(m.g, m.dups); m.g.boundingSphere = null;
  }
}
function dentDispAt(D, p) {
  const out = new THREE.Vector3();
  for (const s of D.src) { const R2 = s.R2 || s.r * s.r; const w = Math.exp(-p.distanceToSquared(s.c) / R2); if (s.kind === 'pull') out.addScaledVector(s.dir, s.depth * w); else out.addScaledVector(s.n, -s.depth * w); }
  return out;
}
const _inv4 = new THREE.Matrix4();
/** hit (mundo) → punto + normal en el espacio del squishy, sobre la forma SIN deformar */
function squishLocal(sq, point, faceNormalWorld, rayDir) {
  if (!sq.def) deformInit(sq);
  sq.inner.updateMatrixWorld(true); _inv4.copy(sq.inner.matrixWorld).invert();
  const p = point.clone().applyMatrix4(_inv4);
  const n = faceNormalWorld.clone().multiplyScalar(0.55).addScaledVector(rayDir, -0.45).normalize().transformDirection(_inv4);
  p.sub(dentDispAt(sq.def, p));
  return { p, n };
}
function capSources(D) { while (D.src.length > 30) { const i = D.src.findIndex(x => !x.held); if (i < 0) break; D.src.splice(i, 1); } }
function squishPress(sq, id, point, normal, rayDir, force = 1) {
  const L = squishLocal(sq, point, normal, rayDir); const D = sq.def;
  const R = D.ref * (0.3 + 0.1 * sq.soft) * (sq.data.mutation === 'big' ? 1.1 : 1);
  const s = { id, kind: 'dent', c: L.p, n: L.n, dir: L.n.clone().negate(), r: R, max: Math.min(D.ref * 0.56 * sq.soft, Math.min(D.size.x, D.size.y, D.size.z) * 0.42), depth: 0, f: 0, s: 0, target: 0, held: true, force, t: 0 };
  D.src.push(s); capSources(D);
  if (sq.wax && typeof waxTap === 'function') waxTap(sq, s, force);
  sq.squish(0.16 * force); return s;
}
/** Estirar (pellizco): jala la superficie hacia donde arrastras */
function squishPull(sq, id, point, normal, rayDir) {
  const L = squishLocal(sq, point, normal, rayDir); const D = sq.def;
  const s = { id, kind: 'pull', c: L.p, n: L.n, dir: L.n.clone(), r: D.ref * (0.36 + 0.08 * sq.soft), max: D.ref * 0.75 * sq.soft, depth: 0, f: 0, s: 0, target: 0, held: true, force: 1, t: 0 };
  D.src.push(s); capSources(D); return s;
}
function squishPullTo(sq, id, dispInner) {
  const D = sq.def; if (!D) return; const s = D.src.find(x => x.id === id && x.held && x.kind === 'pull'); if (!s) return;
  const L = dispInner.length(); if (L < 1e-4) { s.target = 0; return; }
  s.dir.copy(dispInner).divideScalar(L).addScaledVector(s.n, 0.25).normalize();
  s.target = Math.min(s.max, L * 0.85) * (1 - 0.35 * Math.min(1, L / (s.max * 2)));
}
/** Arrastrar el dedo: si se movió bastante, suelta el hundimiento viejo (queda subiendo) y crea otro → rastro */
function squishDrag(sq, id, point, normal, rayDir) {
  const D = sq.def; if (!D) return false;
  const s = D.src.find(x => x.id === id && x.held && x.kind === 'dent'); if (!s) return false;
  const L = squishLocal(sq, point, normal, rayDir);
  if (L.p.distanceTo(s.c) < s.r * 0.42) { s.n.lerp(L.n, 0.2).normalize(); return false; }
  s.held = false;
  const ns = Object.assign({}, s, { c: L.p, n: L.n, dir: L.n.clone().negate(), depth: s.depth * 0.88, target: s.target * 0.9, held: true, t: 0 });
  D.src.push(ns); capSources(D);
  if (sq.wax && typeof waxTap === 'function') waxTap(sq, ns, 0.35);
  return true;
}
function squishRelease(sq, id) {
  const D = sq.def; if (!D) return; let deep = 0;
  for (const s of D.src) if (s.id === id && s.held) { s.held = false; deep = Math.max(deep, s.depth / s.max); }
  if (deep > 0.25) sq.squish(-0.1 * deep * clamp(2.6 / sq.rise, 0.25, 1.3)); // pequeño rebote al soltar (más en los rebotones)
}
function squishAxis(sq, axis, on, target = 1, rate = 4) {
  if (!sq.def) deformInit(sq); const a = sq.def.ax[axis]; a.hold = on;
  if (on) { a.target = target; a.rate = rate; } else if (axis !== 'twist' && a.v > 0.3) sq.squish(-0.12 * a.v * clamp(2.6 / sq.rise, 0.25, 1.3));
}
function squishHeld(sq) { const D = sq.def; return !!(D && (D.src.some(s => s.held) || D.ax.flat.hold || D.ax.pinch.hold || D.ax.twist.hold)); }
