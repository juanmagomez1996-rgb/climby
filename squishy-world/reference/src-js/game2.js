
// =====================================================================
// SQUISHY FACTORY — procedural kawaii squishies
// =====================================================================
const TEX = {};
function canvasTex(key, w, h, draw) {
  if (TEX[key]) return TEX[key];
  const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d');
  draw(g, w, h);
  const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; t.wrapS = THREE.RepeatWrapping; t.anisotropy = 4;
  TEX[key] = t; return t;
}
function seeded(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
const TEXDRAW = {
  seeds(g, w, h) { g.fillStyle = '#FF6F91'; g.fillRect(0, 0, w, h); const r = seeded(7);
    for (let i = 0; i < 90; i++) { const x = r() * w, y = h * 0.12 + r() * h * 0.8; g.fillStyle = '#FFE9A8'; g.beginPath(); g.ellipse(x, y, 2.2, 3.6, 0, 0, 7); g.fill(); } },
  melon(g, w, h) { g.fillStyle = '#7BCB6A'; g.fillRect(0, 0, w, h); g.fillStyle = '#3F8F47';
    for (let i = 0; i < 12; i++) { const x0 = i * w / 12; g.beginPath(); g.moveTo(x0, 0); for (let y = 0; y <= h; y += 8) g.lineTo(x0 + Math.sin(y * 0.2 + i) * 4 + 6, y); for (let y = h; y >= 0; y -= 8) g.lineTo(x0 + Math.sin(y * 0.2 + i) * 4, y); g.fill(); }
    g.fillStyle = '#FF7B8A'; g.fillRect(0, h * 0.84, w, h * 0.16); },
  drizzle(g, w, h) { g.fillStyle = '#8A5A44'; g.fillRect(0, 0, w, h); g.strokeStyle = '#E9C8A8'; g.lineWidth = 4; g.lineCap = 'round';
    for (let k = 0; k < 4; k++) { g.beginPath(); for (let x = 0; x <= w; x += 4) g.lineTo(x, h * (0.12 + k * 0.07) + Math.sin(x * 0.09 + k * 2) * 5); g.stroke(); } },
  cotton(g, w, h) { const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#FFC4E1'); gr.addColorStop(0.5, '#D9C9FF'); gr.addColorStop(1, '#AEE3FF'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    const r = seeded(3); for (let i = 0; i < 40; i++) { g.fillStyle = r() > 0.5 ? 'rgba(255,196,225,.55)' : 'rgba(174,227,255,.55)'; g.beginPath(); g.arc(r() * w, r() * h, 6 + r() * 14, 0, 7); g.fill(); } },
  galaxy(g, w, h) { g.fillStyle = '#1b1240'; g.fillRect(0, 0, w, h); const r = seeded(11);
    for (let i = 0; i < 14; i++) { const x = r() * w, y = r() * h, rad = 20 + r() * 40; const gr = g.createRadialGradient(x, y, 0, x, y, rad); gr.addColorStop(0, pick(['rgba(186,110,255,.65)', 'rgba(90,140,255,.6)', 'rgba(255,110,190,.5)'])); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, h); }
    for (let i = 0; i < 160; i++) { g.fillStyle = `rgba(255,255,255,${0.4 + r() * 0.6})`; const s = r() < 0.08 ? 2.4 : 1.1; g.fillRect(r() * w, r() * h, s, s); } },
  lava(g, w, h) { g.fillStyle = '#2b1a1a'; g.fillRect(0, 0, w, h); g.strokeStyle = '#FF7A1A'; g.lineWidth = 3; g.shadowColor = '#FFB347'; g.shadowBlur = 8; const r = seeded(5);
    for (let i = 0; i < 22; i++) { g.beginPath(); let x = r() * w, y = r() * h; g.moveTo(x, y); for (let k = 0; k < 5; k++) { x += (r() - 0.5) * 40; y += (r() - 0.5) * 30; g.lineTo(x, y); } g.stroke(); } },
  rainbow(g, w, h) { const cols = ['#FF8FA3', '#FFB27A', '#FFE07A', '#8BE3A5', '#8BC7E8', '#A99CF0', '#E6A2F2']; const bh = h / cols.length;
    cols.forEach((c, i) => { g.fillStyle = c; g.fillRect(0, i * bh, w, bh + 1); }); },
  stars(g, w, h) { g.fillStyle = '#EEF5FF'; g.fillRect(0, 0, w, h); const r = seeded(9); g.fillStyle = '#FFD65A';
    for (let i = 0; i < 26; i++) { const x = r() * w, y = h * 0.1 + r() * h * 0.8, s = 3 + r() * 4; g.beginPath(); for (let k = 0; k < 10; k++) { const a = k * Math.PI / 5, rr = k % 2 ? s * 0.45 : s; g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); } g.fill(); } },
  glitch(g, w, h) { g.fillStyle = '#20202a'; g.fillRect(0, 0, w, h); const r = seeded(13);
    for (let i = 0; i < 60; i++) { g.fillStyle = pick(['#ff2a6d', '#05d9e8', '#d1f7ff', '#7cff6b', '#20202a']); g.fillRect(r() * w, r() * h, 6 + r() * 60, 2 + r() * 10); } },
  checker(g, w, h) { const n = 8; for (let y = 0; y < n / 2; y++) for (let x = 0; x < n; x++) { g.fillStyle = (x + y) % 2 ? '#FF00DC' : '#111'; g.fillRect(x * w / n, y * h / (n / 2), w / n + 1, h / (n / 2) + 1); } },
};

// ---------- shared geometry
const GEO = {};
function bodyGeo(species, flat) {
  const key = species + (flat ? '_f' : '');
  if (GEO[key]) return GEO[key];
  const sx = { cat: 1.08, bear: 1.1, frog: 1.28, bunny: 1.0, blob: 0.98 }[species];
  const sy = { cat: 0.92, bear: 0.96, frog: 0.76, bunny: 0.98, blob: 1.0 }[species];
  const sz = { cat: 1.0, bear: 1.02, frog: 1.06, bunny: 0.98, blob: 0.98 }[species];
  const g = flat ? new THREE.IcosahedronGeometry(1, 2) : new THREE.SphereGeometry(1, 40, 28);
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) {
    let x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    if (species === 'blob' && y > 0) { const k = y * y; y *= 1 + 0.45 * k; x *= 1 - 0.38 * k; z *= 1 - 0.38 * k; }
    if (y < -0.5) { y = -0.5 + (y + 0.5) * 0.35; }           // flat mochi bottom
    x *= sx; y *= sy; z *= sz;
    x *= 1 + 0.06 * Math.max(0, -y);                           // chubby base
    z *= 1 + 0.06 * Math.max(0, -y);
    p.setXYZ(i, x, y, z);
  }
  g.computeVertexNormals();
  g.userData = { sx, sy, sz };
  return (GEO[key] = g);
}
const G = {
  eye: new THREE.SphereGeometry(0.13, 16, 12),
  hi: new THREE.SphereGeometry(0.045, 8, 6),
  blush: new THREE.CircleGeometry(0.11, 16),
  smile: new THREE.TorusGeometry(0.075, 0.022, 6, 14, Math.PI),
  wideSmile: new THREE.TorusGeometry(0.2, 0.025, 6, 20, Math.PI),
  lid: new THREE.TorusGeometry(0.09, 0.025, 6, 14, Math.PI),
  oMouth: new THREE.TorusGeometry(0.045, 0.02, 6, 14),
  catEar: new THREE.ConeGeometry(0.3, 0.5, 18), catEarIn: new THREE.ConeGeometry(0.17, 0.3, 14),
  ball: new THREE.SphereGeometry(1, 20, 14),
  tail: new THREE.TorusGeometry(0.28, 0.07, 8, 16, Math.PI * 1.1),
  curl: new THREE.TorusGeometry(0.16, 0.07, 8, 16, Math.PI * 1.5),
  leaf: new THREE.ConeGeometry(0.12, 0.34, 6),
  halo: new THREE.TorusGeometry(0.55, 0.05, 8, 40),
};
const MAT = {
  eye: new THREE.MeshStandardMaterial({ color: '#1f1b24', roughness: 0.18 }),
  white: new THREE.MeshBasicMaterial({ color: '#ffffff' }),
  blush: new THREE.MeshBasicMaterial({ color: '#ff8fb1', transparent: true, opacity: 0.55, depthWrite: false }),
  mouth: new THREE.MeshBasicMaterial({ color: '#3a2630' }),
  leaf: new THREE.MeshStandardMaterial({ color: '#5BBF6A', roughness: 0.6 }),
  halo: new THREE.MeshBasicMaterial({ color: '#FFE38A' }),
  aura: new THREE.MeshBasicMaterial({ color: '#7B3CFF', transparent: true, opacity: 0.28, side: THREE.BackSide, depthWrite: false }),
  silhouette: new THREE.MeshBasicMaterial({ color: '#c9c3d8' }),
};
function bodyMaterial(look, mutation) {
  const m = new THREE.MeshStandardMaterial({ color: look.c || '#ffffff', roughness: look.r != null ? look.r : 0.55, metalness: look.m || 0, flatShading: !!look.flat });
  if (look.tex) { m.map = canvasTex(look.tex, 256, 128, TEXDRAW[look.tex]); m.color.set('#ffffff'); }
  if (look.e) { m.emissive = new THREE.Color(look.c || '#ffffff'); m.emissiveIntensity = look.e * 0.6; if (look.tex) { m.emissiveMap = m.map; m.emissive.set('#ffffff'); m.emissiveIntensity = look.e * 0.7; } }
  if (look.opacity) { m.transparent = true; m.opacity = look.opacity; }
  if (mutation === 'shiny') { m.roughness *= 0.35; m.metalness = Math.min(1, m.metalness + 0.25); }
  return m;
}
function lighter(hex, k = 0.45) { const c = new THREE.Color(hex); c.lerp(new THREE.Color('#ffffff'), k); return c; }

// place a face element on ellipsoid surface
function onSurface(obj, x, y, geo, push = 0.0) {
  const { sx, sy, sz } = geo.userData;
  const zz = sz * Math.sqrt(Math.max(0.02, 1 - (x / sx) ** 2 - (y / sy) ** 2));
  obj.position.set(x, y, zz + push);
  const n = new THREE.Vector3(x / (sx * sx), y / (sy * sy), zz / (sz * sz)).normalize();
  obj.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), n);
  return obj;
}

/** Build a 3D squishy from its data. Returns a wrapper with update()/squish(). */
function buildSquishy(data, opts = {}) {
  const species = data.species; const spd = SP[species] || SP.cat; const famous = !!spd.famous;
  const look = famous && (data.variant === 'original' || !VAR[data.variant]) ? Object.assign({ id: 'original' }, spd.orig) : (VAR[data.variant] && !VAR[data.variant].famousOnly ? VAR[data.variant] : VAR.classic);
  const root = new THREE.Group(); root.name = 'squishy';
  const inner = new THREE.Group(); root.add(inner);       // squash/stretch pivot at bottom
  const geo = famous ? null : bodyGeo(species, !!look.flat);
  const mat = opts.silhouette ? MAT.silhouette : bodyMaterial(look, data.mutation);
  const accentCol = look.accent ? new THREE.Color(look.accent) : lighter(look.c || '#ffffff', 0.5);
  const accMat = opts.silhouette ? MAT.silhouette : new THREE.MeshStandardMaterial({ color: accentCol, roughness: 0.6 });
  const pinkIn = opts.silhouette ? MAT.silhouette : new THREE.MeshStandardMaterial({ color: '#FFB8CF', roughness: 0.6 });
  let body = null;
  const add = (m, parent = inner) => { m.castShadow = !opts.noShadow; parent.add(m); return m; };
  if (famous) {
    body = buildFamousParts(spd, { root, inner, mat, accMat, sil: !!opts.silhouette, noShadow: !!opts.noShadow, data, look });
  } else {
  body = new THREE.Mesh(geo, mat); body.castShadow = true; inner.add(body);
  const bottomY = -geo.userData.sy * 0.5 - 0.18;
  inner.position.y = -bottomY; // sit on y=0
  const ball = (mt, sx, sy, sz, x, y, z) => { const b = new THREE.Mesh(G.ball, mt); b.scale.set(sx, sy, sz); b.position.set(x, y, z); return add(b); };

  // ---- species parts
  let eyeY = 0.08, eyeX = 0.32, face = true;
  if (species === 'cat') {
    for (const s of [-1, 1]) {
      const e = add(new THREE.Mesh(G.catEar, mat)); e.position.set(0.5 * s, 0.8, -0.05); e.rotation.z = -0.38 * s;
      const ei = add(new THREE.Mesh(G.catEarIn, pinkIn)); ei.position.set(0.5 * s, 0.76, 0.06); ei.rotation.z = -0.38 * s; ei.rotation.x = -0.1;
    }
    const t = add(new THREE.Mesh(G.tail, mat)); t.position.set(0.55, -0.15, -0.8); t.rotation.set(0, Math.PI / 2, 0.4);
  } else if (species === 'bear') {
    for (const s of [-1, 1]) { ball(mat, 0.3, 0.3, 0.2, 0.64 * s, 0.7, -0.05); ball(accMat, 0.17, 0.17, 0.1, 0.64 * s, 0.7, 0.07); }
    const sn = ball(accMat, 0.3, 0.22, 0.2, 0, -0.15, 0.93); ball(MAT.eye, 0.09, 0.065, 0.06, 0, -0.08, 1.1);
    ball(mat, 0.16, 0.16, 0.16, 0, -0.3, -0.98); eyeY = 0.16;
  } else if (species === 'frog') {
    for (const s of [-1, 1]) {
      ball(mat, 0.34, 0.3, 0.3, 0.46 * s, 0.6, 0.18);
      const ey = new THREE.Mesh(G.eye, MAT.eye); ey.scale.setScalar(1.25); ey.position.set(0.46 * s, 0.64, 0.44); add(ey);
      const hi = new THREE.Mesh(G.hi, MAT.white); hi.position.set(0.46 * s + 0.05, 0.71, 0.58); add(hi);
    }
    face = 'frog';
  } else if (species === 'bunny') {
    for (const s of [-1, 1]) {
      const ear = ball(mat, 0.2, 0.62, 0.13, 0.3 * s, 1.35, -0.05); ear.rotation.z = -0.14 * s;
      const ein = ball(pinkIn, 0.11, 0.46, 0.06, 0.31 * s, 1.33, 0.05); ein.rotation.z = -0.14 * s;
    }
    ball(opts.silhouette ? MAT.silhouette : new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 0.9 }), 0.22, 0.22, 0.22, 0, -0.25, -0.98);
  } else if (species === 'blob') {
    const c = add(new THREE.Mesh(G.curl, mat)); c.position.set(0.06, 1.48, 0); c.rotation.z = 0.6;
    eyeY = 0.18; eyeX = 0.28;
  }

  // ---- face
  if (!opts.silhouette) {
    const faceKind = data.face || 'happy';
    if (face === true) {
      for (const s of [-1, 1]) {
        if ((faceKind === 'sleepy') || (faceKind === 'wink' && s === 1)) {
          const l = new THREE.Mesh(G.lid, MAT.mouth); onSurface(l, eyeX * s, eyeY, geo, 0.01); l.rotateZ(Math.PI); inner.add(l);
        } else {
          const e = new THREE.Mesh(G.eye, MAT.eye); onSurface(e, eyeX * s, eyeY, geo, -0.05); e.scale.set(1, 1.12, 0.6); inner.add(e);
          const h = new THREE.Mesh(G.hi, MAT.white); onSurface(h, eyeX * s + 0.045, eyeY + 0.06, geo, 0.03); inner.add(h);
        }
        const b = new THREE.Mesh(G.blush, MAT.blush); onSurface(b, (eyeX + 0.17) * s, eyeY - 0.17, geo, 0.012); inner.add(b);
      }
      const mouth = new THREE.Mesh(faceKind === 'surprised' ? G.oMouth : G.smile, MAT.mouth);
      onSurface(mouth, 0, species === 'bear' ? -0.3 : eyeY - 0.14, geo, species === 'bear' ? 0.12 : 0.005);
      if (faceKind !== 'surprised') mouth.rotateZ(Math.PI);
      if (species === 'bear') { mouth.position.z += 0.03; }
      inner.add(mouth);
    } else if (face === 'frog') {
      const m = new THREE.Mesh(G.wideSmile, MAT.mouth); onSurface(m, 0, 0.12, geo, 0.005); m.rotateZ(Math.PI); inner.add(m);
      for (const s of [-1, 1]) { const b = new THREE.Mesh(G.blush, MAT.blush); onSurface(b, 0.62 * s, 0.02, geo, 0.012); inner.add(b); }
    }
  }

  // ---- toppers & extras
  if (!opts.silhouette) {
    if (look.topper === 'leaf') for (let i = 0; i < 5; i++) { const l = add(new THREE.Mesh(G.leaf, MAT.leaf)); const a = i / 5 * Math.PI * 2; l.position.set(Math.cos(a) * 0.12, geo.userData.sy + 0.02, Math.sin(a) * 0.12); l.rotation.set(Math.sin(a) * 1.2, 0, -Math.cos(a) * 1.2); }
    if (look.topper === 'drip') { const dm = new THREE.MeshStandardMaterial({ color: '#FFB21E', roughness: 0.15 }); for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; ball(dm, 0.12, 0.2, 0.12, Math.cos(a) * 0.7, 0.45, Math.sin(a) * 0.7); } }
    if (look.extra === 'puffs') { const pm = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 1 }); for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; ball(pm, 0.3, 0.22, 0.3, Math.cos(a) * 0.95, -0.42, Math.sin(a) * 0.9); } }
    if (look.extra === 'halo') { const h = add(new THREE.Mesh(G.halo, MAT.halo)); h.rotation.x = Math.PI / 2; h.position.y = geo.userData.sy + (species === 'bunny' ? 1.1 : 0.55); root.userData.halo = h; }
    if (look.extra === 'aura') { const a = new THREE.Mesh(geo, MAT.aura); a.scale.setScalar(1.14); inner.add(a); }
  }
  } // end normal species
  // medidas reales (para encuadrar cámaras con cualquier forma)
  root.updateMatrixWorld(true);
  const bb = new THREE.Box3().setFromObject(inner); const dims = { h: Math.max(0.5, bb.max.y), w: Math.max(bb.max.x - bb.min.x, bb.max.z - bb.min.z), minY: bb.min.y };
  if (famous && !opts.silhouette) {
    if (look.extra === 'halo') { const h = add(new THREE.Mesh(G.halo, MAT.halo)); h.rotation.x = Math.PI / 2; h.position.y = dims.h + 0.35; root.userData.halo = h; }
  }

  const size = (data.size || 1) * (MUT[data.mutation] && MUT[data.mutation].size || 1);
  root.scale.setScalar(size);

  // sparkles for shiny / high rarity
  let sparks = null;
  if (!opts.silhouette && !opts.noSparks && (data.mutation === 'shiny' || R[data.rarity].tier >= 2)) {
    const n = data.mutation === 'shiny' ? 14 : 4 + R[data.rarity].tier * 2;
    const pg = new THREE.BufferGeometry(); pg.setAttribute('position', new THREE.Float32BufferAttribute(new Float32Array(n * 3), 3));
    sparks = new THREE.Points(pg, new THREE.PointsMaterial({ color: data.mutation === 'shiny' ? '#ffffff' : R[data.rarity].color, size: 0.12, transparent: true, opacity: 0.9, depthWrite: false }));
    sparks.userData.seeds = Array.from({ length: n }, () => [Math.random() * 6.28, rand(0.9, 1.5), rand(-0.3, 1.6), rand(0.6, 1.6)]);
    root.add(sparks);
  }

  const fil = FIL[data.filling] || {};
  const sq = {
    root, inner, body, mat, data, look, sparks, dims, def: null,
    rise: (famous ? spd.rise : 3.2) * (fil.riseMul || 1) * (data.mutation === 'big' ? 1.15 : 1),
    soft: (famous ? spd.soft : 1) * (fil.softMul || 1),
    sy: 1, vy: 0, t: Math.random() * 10, glitchT: 0,
    squish(power = 1) { this.sy = 1 - 0.38 * power; this.vy = -1.5 * power; },
    update(dt, moving = 0) {
      this.t += dt;
      // spring toward 1 (squash & stretch)
      const k = 180, c = 11; this.vy += (k * (1 - this.sy) - c * this.vy) * dt; this.sy += this.vy * dt;
      const idle = Math.sin(this.t * 3.2) * 0.025 + moving * Math.abs(Math.sin(this.t * 10)) * 0.08;
      const y = this.sy + idle; const xz = 1 + (1 - y) * 0.55;
      inner.scale.set(xz, y, xz);
      inner.rotation.z = Math.sin(this.t * 2.1) * 0.03;
      if (look.anim === 'neon' && mat.emissive) mat.emissive.setHSL((this.t * 0.15) % 1, 0.9, 0.55);
      if (look.anim === 'glitch') { this.glitchT -= dt; if (this.glitchT < 0) { this.glitchT = rand(0.05, 0.4); inner.position.x = Math.random() < 0.3 ? rand(-0.08, 0.08) : 0; if (mat.map) mat.map.offset.x = Math.random(); if (mat.emissive) mat.emissiveIntensity = Math.random() < 0.2 ? 1.2 : 0.3; } }
      if (root.userData.halo) root.userData.halo.rotation.z += dt;
      if (this.def) deformUpdate(this, dt);
      if (this.wax) waxUpdate(this, dt);
      if (sparks) {
        const a = sparks.geometry.attributes.position;
        sparks.userData.seeds.forEach((s, i) => { const ang = s[0] + this.t * s[3]; a.setXYZ(i, Math.cos(ang) * s[1], s[2] + Math.sin(this.t * 2 + i) * 0.15, Math.sin(ang) * s[1]); });
        a.needsUpdate = true;
      }
    },
    dispose() { if (this.wax) waxRemove(this); root.traverse(o => { if (o.userData && o.userData.ownGeo && o.geometry) o.geometry.dispose(); if (o.material && o.material !== MAT.silhouette && !Object.values(MAT).includes(o.material) && !o.material.userData.shared) { if (o.material.dispose) o.material.dispose(); } }); },
  };
  root.userData.sq = sq;
  if (data.wax && !opts.silhouette && !opts.noWax) waxApply(sq, Object.assign({ instant: true }, data.wax));
  return sq;
}

function squishyName(d) {
  const sp = SP[d.species] || SP.cat, v = VAR[d.variant], m = MUT[d.mutation];
  let n = sp.name; if (!(sp.famous && d.variant === 'original') && v) n += ' ' + v.name;
  if (m && m.name) n += ' ' + m.name; return n;
}
function squishyValue(d) { return Math.round(SP[d.species].baseValue * R[d.rarity].mult * (MUT[d.mutation] ? MUT[d.mutation].mult : 1) * (d.size || 1)); }
function idxKey(d) { return d.species + '|' + d.variant; }

// =====================================================================
// THUMBNAIL STUDIO (separate renderer)
// =====================================================================
const Thumbs = {
  cache: {}, renderer: null, scene: null, cam: null, size: 160,
  init() {
    const c = document.createElement('canvas');
    this.renderer = new THREE.WebGLRenderer({ canvas: c, alpha: true, antialias: true, preserveDrawingBuffer: true });
    this.renderer.setSize(this.size, this.size, false); this.renderer.outputEncoding = THREE.sRGBEncoding;
    this.scene = new THREE.Scene();
    this.scene.add(new THREE.HemisphereLight('#ffffff', '#c8bde0', 0.9));
    const d = new THREE.DirectionalLight('#ffffff', 0.9); d.position.set(2, 4, 5); this.scene.add(d);
    this.cam = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
  },
  get(d, silhouette = false) {
    const key = `${d.species}|${d.variant}|${d.mutation || 'normal'}|${d.face || 'happy'}|${silhouette ? 's' : ''}`;
    if (this.cache[key]) return this.cache[key];
    if (!this.renderer) this.init();
    const sq = buildSquishy(Object.assign({}, d, { size: 1, mutation: d.mutation === 'big' || d.mutation === 'tiny' ? 'normal' : d.mutation }), { silhouette, noSparks: true, noShadow: true, noWax: true });
    sq.update(0);
    this.scene.add(sq.root);
    const h = sq.dims.h, w = sq.dims.w; const dist = Math.max(h * 1.1, w * 0.95) * 2.0 + 0.6;
    this.cam.position.set(dist * 0.26, h * 0.55 + dist * 0.22, dist); this.cam.lookAt(0, h * 0.45, 0);
    this.renderer.render(this.scene, this.cam);
    const url = this.renderer.domElement.toDataURL('image/png');
    this.scene.remove(sq.root); sq.dispose();
    return (this.cache[key] = url);
  },
};
