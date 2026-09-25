
// =====================================================================
// CERA DE VELA v2 — capas que se ACUMULAN (cada vertida es una capa nueva encima, de cualquier color)
// Referentes: videos "wax covered squishy cracking ASMR" (más capas = crack más duro y crujiente),
// apps "Wax Cracking Squishy" / "Wax Pop Ball" (mantener presionado agrieta, los toques botan pedazos).
// Cada capa se parte en pedazos tipo Voronoi sobre la superficie real. Las capas de afuera se rompen
// primero y dejan ver las de adentro. Sin contornos: la grieta se ve como el pedazo que se blanquea
// (blanqueo por estrés, como la cera real) y se levanta.
// =====================================================================
const WAX_COLORS = [
  { id: 'blanca', name: 'Blanca', c: '#F6EFE3' }, { id: 'rosa', name: 'Rosa', c: '#FFC3DA' }, { id: 'lila', name: 'Lila', c: '#DCCBFF' },
  { id: 'menta', name: 'Menta', c: '#BFEFDC' }, { id: 'miel', name: 'Miel', c: '#FFD27A' }, { id: 'cielo', name: 'Cielo', c: '#BFE0FF' },
  { id: 'arcoiris', name: 'Arcoíris', c: null },
];
const WAXC = Object.fromEntries(WAX_COLORS.map(w => [w.id, w]));
const WAX_MAX = 6, WAX_THICK = 0.04;
const WAX_PIECES = [];
const _wv1 = new THREE.Vector3(), _wv2 = new THREE.Vector3();

/** Carga la cera guardada (formato nuevo {list:[{c,s,b}]} o el viejo {layers,color,seed,broken}) */
function waxApply(sq, spec = {}) {
  let list = spec.list;
  if (!list) { const n = clamp(spec.layers || 1, 1, WAX_MAX); list = Array.from({ length: n }, (_, i) => ({ c: spec.color || 'blanca', s: ((spec.seed || 1) + i * 7919) | 0, b: i === n - 1 ? (spec.broken || []) : [] })); }
  waxRemove(sq);
  for (const L of list) waxAddLayer(sq, L.c, { instant: spec.instant !== false, seed: L.s, broken: L.b, pourTime: spec.pourTime });
  return sq.wax;
}
function waxRemove(sq) {
  const WX = sq.wax; if (!WX) return;
  for (const L of WX.list) { for (const sh of L.shards) if (sh.state < 3) sh.mesh.geometry.dispose(); L.mat.dispose(); }
  if (WX.group.parent) WX.group.parent.remove(WX.group);
  if (sq.def) sq.def.stiff = null; sq.wax = null;
}
/** Echa una capa nueva ENCIMA de las que ya hay */
function waxAddLayer(sq, color, opt = {}) {
  if (!sq.def) deformInit(sq);
  let WX = sq.wax;
  if (WX && WX.done) { waxRemove(sq); WX = null; }
  if (!WX) {
    WX = sq.wax = { list: [], done: false, ev: { s: 0, b: 0, t: 0 }, sndT: 0, group: new THREE.Group() };
    WX.group.userData.isWax = true; sq.inner.add(WX.group); sq.def.stiff = (s) => waxStiff(sq, s);
  }
  if (WX.list.length >= WAX_MAX) return null;
  const base = WX.list.reduce((a, L) => a + L.thick, 0);
  const L = waxBuildLayer(sq, WX, WXC(color), opt, base);
  // cada pedazo de las capas de adentro queda "tapado" por el pedazo más cercano de la capa nueva
  for (const P of WX.list) for (const sh of P.shards) {
    if (sh.state >= 3) continue; let best = null, bd = Infinity;
    for (const o of L.shards) { const d = o.cen.distanceToSquared(sh.cen); if (d < bd) { bd = d; best = o; } }
    if (best) sh.covers.push(best);
  }
  WX.list.push(L); WX.done = false;
  return L;
}
function WXC(c) { return WAXC[c] ? c : 'blanca'; }
function waxBuildLayer(sq, WX, colId, opt, base) {
  const D = sq.def, seed = opt.seed || ((Math.random() * 1e9) | 0);
  const L = { color: colId, seed, broken: new Set(opt.broken || []), shards: [], group: new THREE.Group(), thick: D.ref * WAX_THICK, base,
    grow: opt.instant ? 1 : 0, hot: opt.instant ? 0 : 1, pourTime: opt.pourTime || 1.6, total: 0, remaining: 0, dirty: true, lastMoved: -1 };
  L.mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.2, metalness: 0, transparent: true, opacity: 0.9, side: THREE.DoubleSide, emissive: new THREE.Color('#ff9a4a'), emissiveIntensity: 0 });
  L.group.userData.isWax = true; WX.group.add(L.group);
  // triángulos de la superficie (espacio del squishy, forma sin deformar), con área acumulada
  const tris = [], cum = []; let tot = 0;
  D.meshes.forEach((m, mi) => {
    const idx = m.g.index ? m.g.index.array : null, n = idx ? idx.length : m.P.length / 3, P = m.P;
    for (let t = 0; t < n; t += 3) {
      const a = idx ? idx[t] : t, b = idx ? idx[t + 1] : t + 1, c = idx ? idx[t + 2] : t + 2;
      _wv1.set(P[b * 3] - P[a * 3], P[b * 3 + 1] - P[a * 3 + 1], P[b * 3 + 2] - P[a * 3 + 2]);
      _wv2.set(P[c * 3] - P[a * 3], P[c * 3 + 1] - P[a * 3 + 1], P[c * 3 + 2] - P[a * 3 + 2]);
      const ar = _wv1.cross(_wv2).length() * 0.5; if (ar < 1e-7) continue;
      tris.push({ mi, a, b, c, x: (P[a * 3] + P[b * 3] + P[c * 3]) / 3, y: (P[a * 3 + 1] + P[b * 3 + 1] + P[c * 3 + 1]) / 3, z: (P[a * 3 + 2] + P[b * 3 + 2] + P[c * 3 + 2]) / 3, s: 0 });
      tot += ar; cum.push(tot);
    }
  });
  if (!tris.length) return L;
  const rng = seeded(seed); const K = Math.round(clamp(D.area * 15, 24, 64));
  const seeds = [];
  for (let k = 0; k < K; k++) { const r = rng() * tot; let lo = 0, hi = cum.length - 1; while (lo < hi) { const mid = (lo + hi) >> 1; if (cum[mid] < r) lo = mid + 1; else hi = mid; } const t = tris[lo]; seeds.push([t.x, t.y, t.z, 0.75 + rng() * 0.5]); }
  for (const t of tris) { let best = 0, bd = Infinity; for (let k = 0; k < K; k++) { const s = seeds[k]; const d = ((t.x - s[0]) ** 2 + (t.y - s[1]) ** 2 + (t.z - s[2]) ** 2) * s[3]; if (d < bd) { bd = d; best = k; } } t.s = best; }
  // bordes por posición (las costuras UV no cuentan) → paredes de grosor y vecinos para la cascada
  const pk = (mi, i) => { const P = D.meshes[mi].P; return mi + ':' + Math.round(P[i * 3] * 600) + ',' + Math.round(P[i * 3 + 1] * 600) + ',' + Math.round(P[i * 3 + 2] * 600); };
  const edges = new Map();
  for (const t of tris) {
    const ks = [pk(t.mi, t.a), pk(t.mi, t.b), pk(t.mi, t.c)], vs = [t.a, t.b, t.c];
    for (let e = 0; e < 3; e++) {
      const k1 = ks[e], k2 = ks[(e + 1) % 3]; if (k1 === k2) continue;
      const key = k1 < k2 ? k1 + '|' + k2 : k2 + '|' + k1; const E = edges.get(key);
      if (!E) edges.set(key, { s: t.s, o: -1, cnt: 1, mi: t.mi, u: vs[e], v: vs[(e + 1) % 3] });
      else { E.cnt++; if (E.s !== t.s) E.o = t.s; }
    }
  }
  const byShard = Array.from({ length: K }, () => ({ tris: [], edges: [], nb: new Set() }));
  for (const t of tris) byShard[t.s].tris.push(t);
  for (const E of edges.values()) {
    if (E.o >= 0) { byShard[E.s].edges.push(E); byShard[E.o].edges.push(E); byShard[E.s].nb.add(E.o); byShard[E.o].nb.add(E.s); }
    else if (E.cnt === 1) byShard[E.s].edges.push(E);
  }
  const baseCol = WAXC[colId].c ? new THREE.Color(WAXC[colId].c) : null;
  byShard.forEach((B, id) => {
    if (!B.tris.length) return;
    const col = baseCol ? baseCol.clone() : new THREE.Color().setHSL(rng(), 0.75, 0.82);
    const side = col.clone().lerp(new THREE.Color('#ffffff'), 0.1); // grosor casi del mismo color: sin bordes marcados
    const vm = [], vi = [], vf = [], cols = [], nrm = new THREE.Vector3(), cen = new THREE.Vector3();
    const push = (mi, i, f, c) => { vm.push(mi); vi.push(i); vf.push(f); cols.push(c.r, c.g, c.b); };
    for (const t of B.tris) {
      push(t.mi, t.a, 1, col); push(t.mi, t.b, 1, col); push(t.mi, t.c, 1, col);
      const PN = D.meshes[t.mi].PN; nrm.x += PN[t.a * 3]; nrm.y += PN[t.a * 3 + 1]; nrm.z += PN[t.a * 3 + 2]; cen.x += t.x; cen.y += t.y; cen.z += t.z;
    }
    // cáscara de una sola superficie (doble cara): al partirse no deja bordes ni paredes visibles
    cen.divideScalar(B.tris.length); nrm.normalize();
    const n = vm.length, g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(n * 3), 3));
    const na = new Float32Array(n * 3); for (let j = 0; j < n; j++) { const PN = D.meshes[vm[j]].PN, i3 = vi[j] * 3; na[j * 3] = PN[i3]; na[j * 3 + 1] = PN[i3 + 1]; na[j * 3 + 2] = PN[i3 + 2]; }
    g.setAttribute('normal', new THREE.BufferAttribute(na, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
    const mesh = new THREE.Mesh(g, L.mat); mesh.castShadow = true; mesh.userData.isWax = true;
    const tan = new THREE.Vector3(rng() - 0.5, rng() - 0.5, rng() - 0.5).cross(nrm).normalize();
    const sh = { id, mesh, vm: Uint16Array.from(vm), vi: Uint32Array.from(vi), vf: Float32Array.from(vf), col0: Float32Array.from(cols), nb: [...B.nb], cen, nrm, tan, integ: 1, state: 0, off: 0, tint: 0, covers: [], layer: L };
    L.shards.push(sh); L.total++;
    if (L.broken.has(id)) { sh.state = 3; g.dispose(); return; }
    L.group.add(mesh); L.remaining++;
  });
  waxLayerGeo(sq, L, true);
  return L;
}
function waxShardGeo(L, D, sh) {
  const pos = sh.mesh.geometry.attributes.position.array, th = L.thick * L.grow, b = L.base;
  const ox = sh.nrm.x * sh.off + sh.tan.x * sh.off * 0.5, oy = sh.nrm.y * sh.off + sh.tan.y * sh.off * 0.5, oz = sh.nrm.z * sh.off + sh.tan.z * sh.off * 0.5;
  for (let j = 0, n = sh.vm.length; j < n; j++) {
    const m = D.meshes[sh.vm[j]], i3 = sh.vi[j] * 3, f = b + sh.vf[j] * th, Q = m.Q, PN = m.PN;
    pos[j * 3] = Q[i3] + PN[i3] * f + ox; pos[j * 3 + 1] = Q[i3 + 1] + PN[i3 + 1] * f + oy; pos[j * 3 + 2] = Q[i3 + 2] + PN[i3 + 2] * f + oz;
  }
  sh.mesh.geometry.attributes.position.needsUpdate = true; sh.mesh.geometry.boundingSphere = null;
}
function waxLayerGeo(sq, L, force) {
  const D = sq.def; if (!force && !L.dirty && L.lastMoved === D.moved) return;
  for (const sh of L.shards) if (sh.state < 3) waxShardGeo(L, D, sh);
  L.dirty = false; L.lastMoved = D.moved;
}
function waxTint(sh, k) { // blanqueo por estrés (sin contornos)
  const c = sh.mesh.geometry.attributes.color.array, c0 = sh.col0;
  for (let i = 0; i < c.length; i++) c[i] = c0[i] + (1 - c0[i]) * k;
  sh.mesh.geometry.attributes.color.needsUpdate = true;
}
function waxExposure(sh) { for (const o of sh.covers) if (o.state < 3) return 0.22; return 1; }
function waxLayerReady(L) { return L.grow >= 1 && L.hot < 0.25; }
/** qué tanto frena la cera al dedo: cada capa sana encima multiplica la dureza */
function waxStiff(sq, s) {
  const WX = sq.wax; if (!WX || WX.done) return 1;
  let st = 1;
  for (const L of WX.list) {
    if (!waxLayerReady(L)) { st *= 0.7; continue; }
    let bd = Infinity, stt = 3;
    for (const sh of L.shards) { if (sh.state >= 3) continue; const d = sh.cen.distanceToSquared(s.c); if (d < bd) { bd = d; stt = sh.state; } }
    if (bd < (s.r * 1.1) ** 2) st *= [0.2, 0.45, 0.78, 1][stt];
  }
  return Math.max(0.02, st);
}
function waxTap(sq, s, force = 1) {
  const WX = sq.wax; if (!WX || WX.done) return;
  const R2 = (s.r * 1.35) ** 2;
  for (const L of WX.list) {
    if (!waxLayerReady(L)) continue; const k = 0.3 * force;
    for (const sh of L.shards) { if (sh.state >= 3) continue; const d2 = sh.cen.distanceToSquared(s.c); if (d2 < R2) sh.integ -= (k * (1 - d2 / R2) + 0.04) * waxExposure(sh); }
  }
}
function waxSmash(sq, power = 1) {
  const WX = sq.wax; if (!WX || WX.done) return; const D = sq.def;
  for (const L of WX.list) { if (!waxLayerReady(L)) continue; for (const sh of L.shards) if (sh.state < 3) sh.integ -= power * (0.07 + 0.2 * clamp((sh.cen.y - D.ymin) / D.size.y, 0, 1)) * rand(0.6, 1.4) * waxExposure(sh); }
}
function waxDetach(sq, WX, L, sh) {
  const D = sq.def; sh.state = 3; L.broken.add(sh.id); L.remaining--; WX.ev.t++;
  waxShardGeo(L, D, sh);
  for (const nb of sh.nb) { const o = L.shards.find(x => x.id === nb); if (o && o.state < 3) o.integ -= 0.07; }
  const parent = sq.root.parent;
  if (!parent || WAX_PIECES.length > 160) { L.group.remove(sh.mesh); sh.mesh.geometry.dispose(); return; }
  const g = sh.mesh.geometry; g.computeBoundingBox(); const c = g.boundingBox.getCenter(new THREE.Vector3()); g.translate(-c.x, -c.y, -c.z); sh.mesh.position.copy(c);
  sh.mesh.material = L.mat.clone(); sh.mesh.material.emissiveIntensity = 0;
  sq.root.updateMatrixWorld(true); parent.attach(sh.mesh);
  const sW = sq.root.getWorldScale(new THREE.Vector3()).x;
  const v = sh.nrm.clone().transformDirection(sq.inner.matrixWorld).multiplyScalar(rand(1.0, 2.6) * sW); v.y += rand(0.8, 2.4) * sW;
  WAX_PIECES.push({ mesh: sh.mesh, v, ax: new THREE.Vector3(rand(-1, 1), rand(-1, 1), rand(-1, 1)).normalize(), w: rand(3, 10), floor: sq.root.getWorldPosition(new THREE.Vector3()).y, life: 0, sW });
}
function waxUpdate(sq, dt) {
  const WX = sq.wax, D = sq.def; if (!WX || !D) return;
  const src = D.src, nL = WX.list.length;
  for (const L of WX.list) {
    if (L.grow < 1) { L.grow = Math.min(1, L.grow + dt / L.pourTime); L.dirty = true; }
    else if (L.hot > 0) L.hot = Math.max(0, L.hot - dt / 2.4);
    L.mat.opacity = 0.3 + 0.6 * L.grow; L.mat.emissiveIntensity = L.hot * 0.3; L.mat.roughness = 0.05 + 0.17 * (1 - L.hot);
    if (!waxLayerReady(L) || WX.done) continue;
    for (const sh of L.shards) {
      if (sh.state >= 3) continue;
      let st = 0, gl = 0;
      for (const s of src) { const R2 = s.r * s.r * 2.0, d2 = sh.cen.distanceToSquared(s.c); if (d2 < R2 * 5) st += (0.25 + s.depth / s.max) * Math.exp(-d2 / R2) * (s.held ? 1 : 0.35) * (s.kind === 'pull' ? 1.3 : 1); }
      if (D.flat) gl += D.flat * 0.35 * clamp((sh.cen.y - D.ymin) / D.size.y + 0.15, 0, 1.15);
      if (D.pinch) gl += D.pinch * 0.6 * clamp(Math.abs(sh.cen.x - D.center.x) / (D.size.x * 0.5) + 0.1, 0, 1.1);
      if (D.twist) gl += Math.abs(D.twist) * 0.5;
      const ex = waxExposure(sh);
      if (st > 0.05) sh.integ -= st * dt * 4.2 * ex;
      if (gl > 0.05) sh.integ -= gl * dt * 2.0 * ex;
      if (sh.state === 0 && sh.integ < 0.78) { sh.state = 1; WX.ev.s++; L.dirty = true; }
      if (sh.state === 1 && sh.integ < 0.4) { sh.state = 2; WX.ev.b++; L.dirty = true; }
      if (sh.integ <= 0) waxDetach(sq, WX, L, sh);
    }
  }
  if (!WX.done && WX.list.length && WX.list.every(L => L.remaining <= 0)) { WX.done = true; if (sq.onWaxDone) sq.onWaxDone(sq); }
  for (const L of WX.list) {
    for (const sh of L.shards) {
      if (sh.state >= 3) continue;
      const tgt = (sh.state === 1 ? 0.004 : sh.state === 2 ? 0.02 : 0) * D.ref;
      if (Math.abs(tgt - sh.off) > 1e-4) { sh.off += (tgt - sh.off) * Math.min(1, dt * 12); L.dirty = true; }
      const tt = sh.state === 1 ? 0.14 : sh.state === 2 ? 0.3 : 0;
      if (Math.abs(tt - sh.tint) > 0.01) { sh.tint += (tt - sh.tint) * Math.min(1, dt * 10); waxTint(sh, sh.tint); }
    }
    waxLayerGeo(sq, L, false);
  }
  WX.sndT -= dt;
  if (WX.sndT <= 0 && (WX.ev.s || WX.ev.b || WX.ev.t)) {
    const big = WX.ev.b + WX.ev.t;
    SFX.waxCrack(Math.min(1, 0.35 + WX.ev.s * 0.12 + big * 0.2), Math.min(3, nL));
    if (WX.ev.t) SFX.waxTink(Math.min(1, 0.4 + WX.ev.t * 0.2));
    if (navigator.vibrate && (sq.inStudio || sq === WorldPress.sq)) { try { navigator.vibrate(big ? 16 : 7); } catch (e) { } }
    WX.ev.s = WX.ev.b = WX.ev.t = 0; WX.sndT = 0.035 + Math.random() * 0.03;
  }
}
/** física de los pedazos que se cayeron (en el mundo o en el estudio) */
function updateWaxPieces(dt) {
  for (let i = WAX_PIECES.length - 1; i >= 0; i--) {
    const p = WAX_PIECES[i], m = p.mesh; p.life += dt;
    p.v.y -= 19.6 * p.sW * dt; m.position.addScaledVector(p.v, dt); m.rotateOnAxis(p.ax, p.w * dt);
    const fl = p.floor + 0.03 * p.sW;
    if (m.position.y < fl) {
      m.position.y = fl; if (p.v.y < 0) p.v.y *= -0.26; p.v.x *= 0.7; p.v.z *= 0.7; p.w *= 0.55;
      if (!p.landed) { p.landed = true; if (Math.random() < 0.5) SFX.waxTink(0.25); }
    }
    if (p.life > 3) m.material.opacity = Math.max(0, 0.9 * (1 - (p.life - 3) / 1.2));
    if (p.life > 4.2 || !m.parent) { if (m.parent) m.parent.remove(m); m.geometry.dispose(); m.material.dispose(); WAX_PIECES.splice(i, 1); }
  }
}
function waxState(sq) {
  const WX = sq.wax; if (!WX) return null; const out = WX.list[WX.list.length - 1];
  return { list: WX.list.map(L => ({ c: L.color, s: L.seed, b: [...L.broken] })), layers: WX.list.length, done: WX.done,
    total: WX.list.reduce((a, L) => a + L.total, 0), remaining: WX.list.reduce((a, L) => a + L.remaining, 0), hot: out ? out.hot : 0, grow: out ? out.grow : 1 };
}
function waxSave(sq) { const w = waxState(sq); return w && !w.done ? { list: w.list } : null; }
