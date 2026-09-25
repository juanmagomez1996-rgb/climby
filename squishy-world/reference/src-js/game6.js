
// =====================================================================
// APLASTAR EN EL MUNDO v2
// - Modo apuntar (clic derecho sostenido o Q): cámara al hombro, retícula con imán que se pega al
//   squishy más cercano (aunque vaya caminando con su dueño) y ayuda de puntería.
// - Al apachurrar, el dedo queda PEGADO a la superficie del squishy (se mueve con él) y el dueño se
//   detiene mientras lo apachurras.
// =====================================================================
const NPC_SQUISH_LINES = ['¡Jajaja, qué suave!', 'Oye, ¡ese es mío! 😆', 'Apachúrralo con cariño 💕', '¿Viste lo lento que sube?', '¡Dale, es antiestrés!', 'Jaja, me dio cosquillas 🤭', 'Espérate que me quedo quieto 😂'];
const NPC_WAX_LINES = ['¡Nooo, mi cera! 😂', '¡Ese crack sonó brutal!', 'Jajaja rómpela toda', 'Suena como galleta 🍪'];
function squishTargets() {
  const out = []; for (const s of clickables) if (s.root.parent) out.push(s);
  for (const s of world.vitrina) out.push(s); return out;
}
const _pr = new THREE.Raycaster(); const _ndc = new THREE.Vector2(); const _c3 = new THREE.Vector3(), _s3 = new THREE.Vector3(), _pv = new THREE.Vector3();
function hitInfo(hits) {
  for (const h of hits) {
    if (!h.object.isMesh || !h.face) continue;
    let o = h.object; while (o && !(o.userData && o.userData.sq)) o = o.parent;
    if (!o) continue;
    return { sq: o.userData.sq, point: h.point.clone(), normal: h.face.normal.clone().transformDirection(h.object.matrixWorld), ray: _pr.ray.direction.clone() };
  }
  return null;
}
function pickSquishy(sx, sy, cam3, list, W = innerWidth, H = innerHeight) {
  _ndc.set(sx / W * 2 - 1, -(sy / H) * 2 + 1); _pr.setFromCamera(_ndc, cam3);
  return hitInfo(_pr.intersectObjects(list.map(s => s.root), true));
}
function sqCenter(sq, out) { const s = sq.root.getWorldScale(_s3).x; sq.root.getWorldPosition(out); out.y += sq.dims.h * 0.5 * s; return s; }
function rayToCenter(sq) { sqCenter(sq, _c3); _pr.set(camera.position, _c3.clone().sub(camera.position).normalize()); return hitInfo(_pr.intersectObject(sq.root, true)); }
function toScreen(v) { _pv.copy(v).project(camera); return [(_pv.x + 1) / 2 * innerWidth, (1 - _pv.y) / 2 * innerHeight, _pv.z]; }
function ownerReact(sq, lines = NPC_SQUISH_LINES) {
  const n = sq.owner; if (!n || !n.def) return;
  if ((n.reactT || 0) > 0) return; n.reactT = 9;
  npcSay(n, pick(lines), 3.5); n.ch.play(pick(['emote-yes', 'interact-right']), 0.2, true);
}
function countSquish() { S.stats.squishes = (S.stats.squishes || 0) + 1; if (S.stats.squishes % 15 === 0) addXP(2); markDirty(); }
function persistWax(sq) {
  const d = sq && sq.data; if (!d || !S.inventory.includes(d)) return;
  const w = waxSave(sq); if (w) d.wax = w; else delete d.wax;
  markDirty();
}
function onWaxDoneWorld(sq) {
  S.stats.waxCracked = (S.stats.waxCracked || 0) + 1; addXP(4); playSound('reward');
  if (sq.owner && sq.owner.def) { const n = sq.owner; npcSay(n, '¡Le quitaste toda la cera! 😂 Ahorita le echo más', 4); n.rewaxT = 25; }
  else toast('¡Toda la cera fuera! 🕯️💥 +4 XP');
  persistWax(sq);
}

// ---------- retícula / modo apuntar
const Aim = { on: false, btnOn: false, keyOn: false, target: null, rx: innerWidth / 2, ry: innerHeight / 2, ring: null };
function aimRef() { return input.locked ? [innerWidth / 2, innerHeight / 2] : [input.mouseX, input.mouseY]; }
function findAimTarget(magnet) {
  const [rx, ry] = aimRef(); let best = null, bs = Infinity; const tanF = Math.tan(camera.fov * Math.PI / 360);
  for (const sq of squishTargets()) {
    const sc = sqCenter(sq, _c3);
    if (Math.hypot(player.pos.x - _c3.x, player.pos.z - _c3.z) > 34) continue;
    const [px, py, pz] = toScreen(_c3); if (pz > 1) continue;
    const dist = camera.position.distanceTo(_c3);
    const rad = Math.max(sq.dims.h, sq.dims.w) * 0.5 * sc / (dist * tanF) * innerHeight / 2;
    const d = Math.hypot(px - rx, py - ry);
    if (d > rad + magnet) continue;
    const score = Math.max(0, d - rad * 0.6) + dist * 1.2 + (sq === Aim.target ? -45 : 0) + (sq === world.statue ? 60 : 0);
    if (score < bs) { bs = score; best = sq; }
  }
  return best;
}
function updateAim(dt) {
  Aim.on = (Aim.btnOn || Aim.keyOn) && !UI.open;
  cam.aimK = damp(cam.aimK || 0, Aim.on ? 1 : 0, 7, dt);
  // cualquier personaje (tú o el dueño) que tape lo que quieres apachurrar se vuelve clarito (fantasma)
  const tgt = WorldPress.active ? WorldPress.sq : Aim.target;
  if (tgt) sqCenter(tgt, _c3);
  const tc = tgt ? _c3.clone() : null;
  const chars = [{ ch: player.ch, pos: player.pos, me: true }];
  for (const n of npcs) if (tgt && (n.sq === tgt || n.pos.distanceTo(tc) < 9)) chars.push({ ch: n.ch, pos: n.pos });
  for (const c of chars) {
    let want = c.me ? 1 - 0.62 * cam.aimK : 1;
    if (tc) {
      const a = camera.position, ab = tc.clone().sub(a), L2 = ab.lengthSq() || 1;
      for (const hgt of [1.4, 3.2, 4.8]) {
        const P = new THREE.Vector3(c.pos.x, hgt, c.pos.z); const tt = clamp(P.clone().sub(a).dot(ab) / L2, 0, 1);
        if (tt < 0.97 && P.distanceTo(a.clone().addScaledVector(ab, tt)) < 2.3) { want = Math.min(want, 0.2); break; }
      }
    }
    if (camera.position.distanceTo(new THREE.Vector3(c.pos.x, 3, c.pos.z)) < 4.5) want = Math.min(want, 0.25);
    fadeChar(c.ch, want, dt);
  }
  for (const n of npcs) if (n.ch.fadeOp !== undefined && n.ch.fadeOp < 1 && !chars.some(c => c.ch === n.ch)) fadeChar(n.ch, 1, dt);
  const ret = $('reticle'), hint = $('sqHint');
  if (UI.open) { ret.classList.add('hidden'); hint.classList.add('hidden'); if (Aim.ring) Aim.ring.visible = false; return; }
  if (!WorldPress.active) Aim.target = input.dragging && !input.locked && !Aim.on ? null : findAimTarget(Aim.on ? 120 : 22);
  const t = WorldPress.active ? WorldPress.sq : Aim.target;
  let tx, ty;
  if (WorldPress.active) { tx = WorldPress.sx; ty = WorldPress.sy; }
  else if (t) { sqCenter(t, _c3); [tx, ty] = toScreen(_c3); }
  else [tx, ty] = aimRef();
  const k = t ? 16 : 30; Aim.rx = damp(Aim.rx, tx, k, dt); Aim.ry = damp(Aim.ry, ty, k, dt);
  // ayuda de puntería: si vas apuntando y el squishy camina, la cámara lo sigue un poquito
  if (Aim.on && t && input.locked && !WorldPress.active) {
    sqCenter(t, _c3); const want = Math.atan2(_c3.x - camera.position.x, _c3.z - camera.position.z);
    let d = want - cam.yaw; d = Math.atan2(Math.sin(d), Math.cos(d)); if (Math.abs(d) < 0.5) cam.yaw += d * Math.min(1, dt * 2.2);
  }
  const showRet = (Aim.on || t) && !WorldPress.active; // amasando: sin retícula para ver las manos
  ret.classList.toggle('hidden', !showRet); ret.classList.toggle('lock', !!t); ret.classList.toggle('press', WorldPress.active);
  ret.style.left = Aim.rx + 'px'; ret.style.top = Aim.ry + 'px';
  $('retLabel').innerHTML = t && !WorldPress.active ? `<b>${esc(t.data && t.data.name ? t.data.name : squishyName(squishDataOf(t)))}</b><span>${esc(t.ownerLabel || '')}${t.wax && !t.wax.done ? ' · 🕯️ encerado' : ''}</span>` : '';
  // anillo en el piso bajo el objetivo
  if (!Aim.ring) { Aim.ring = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 40), new THREE.MeshBasicMaterial({ color: '#FF7BB5', transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide })); Aim.ring.rotation.x = -Math.PI / 2; scene.add(Aim.ring); }
  Aim.ring.visible = !!t;
  if (t) { const sc = t.root.getWorldScale(_s3).x; t.root.getWorldPosition(_c3); Aim.ring.position.set(_c3.x, _c3.y + 0.06, _c3.z); Aim.ring.scale.setScalar(t.dims.w * 0.62 * sc * (1 + Math.sin(T * 6) * 0.06)); }
  // pista abajo
  const near = t || nearestSquishy(10);
  if (WorldPress.active) { hint.innerHTML = '🖐️ Mueve el mouse <b>a los lados</b> para girar · <b>arriba/abajo</b> para mover las manos por el borde · rueda = zoom' + (t && t.wax && !t.wax.done ? ' · ¡apretar fuerte rompe la cera!' : ''); hint.classList.remove('hidden'); }
  else if (near) {
    const nm = near.data && near.data.name ? near.data.name : squishyName(squishDataOf(near));
    hint.innerHTML = (t ? (Aim.on ? '🎯 <b>Clic</b> para apachurrar · ' : '🖐️ <b>Mantén clic</b> para apachurrar · <b>clic derecho / Q</b> apuntar · ') : '<b>Clic derecho / Q</b> apuntar · ') + `<span class="key">F</span> de cerca: <b>${esc(nm)}</b> <span class="own">${esc(near.ownerLabel || '')}</span>`;
    hint.classList.remove('hidden');
  } else if (Aim.on) { hint.innerHTML = '🎯 Apunta a cualquier squishy (el tuyo, el de tus amigos o la vitrina)'; hint.classList.remove('hidden'); }
  else hint.classList.add('hidden');
  canvas.style.cursor = t && !input.locked ? 'pointer' : '';
}
function fadeChar(ch, want, dt) {
  const cur = ch.fadeOp === undefined ? 1 : ch.fadeOp; const op = damp(cur, want, 10, dt);
  if (Math.abs(op - cur) > 0.003 || (op < 1 && ch.fadeOp === undefined)) {
    if (!ch.fadeMats) { ch.fadeMats = []; ch.group.traverse(o => { if (o.isMesh && o.material) { o.material = o.material.clone(); o.material.transparent = true; ch.fadeMats.push(o.material); } }); }
    const v = op > 0.995 ? 1 : op; for (const m of ch.fadeMats) { m.opacity = v; m.depthWrite = v > 0.95; }
  }
  ch.fadeOp = op;
}
function nearestSquishy(maxD) {
  let best = null, bd = maxD;
  for (const s of squishTargets()) { if (s === world.statue) continue; const p = s.root.position; const d = Math.hypot(player.pos.x - p.x, player.pos.z - p.z); if (d < bd) { bd = d; best = s; } }
  return best;
}
function squishDataOf(sq) {
  const d = sq.data || {}; const out = Object.assign({ species: 'cat', variant: 'classic', rarity: 'common', mutation: 'normal', face: 'happy', size: 1, filling: 'classic_foam' }, d);
  out.name = d.name || squishyName(out);
  const w = sq.wax ? waxSave(sq) : null; if (w) out.wax = w; else delete out.wax;
  return out;
}

// ---------- AMASAR con las dos manos en el mundo: las manos agarran el squishy por los lados y los
// pulgares lo amasan alternados. Quedan pegados a la superficie aunque el squishy se mueva, y la
// cámara se acerca para que el personaje no tape.
function makeMitten() {
  // mano kawaii: palma redondita, dedos cortos y gorditos, pulgar corto que es el que aprieta
  const g = new THREE.Group(), model = new THREE.Group(); g.add(model);
  const m = new THREE.MeshStandardMaterial({ color: SKIN, roughness: 0.62, transparent: true, opacity: 1 });
  model.add(new THREE.Mesh(superGeo('mit_palm', 0.4, 0.42, 0.2, 0.85), m));
  const stub = cachedGeo('mit_stub', () => new THREE.SphereGeometry(0.13, 14, 10));
  const fingers = [];
  [-0.27, -0.09, 0.09, 0.27].forEach((x, i) => { const f = new THREE.Mesh(stub, m); f.scale.set(1, [1.25, 1.45, 1.4, 1.15][i], 1); f.position.set(x, 0.46, 0.04); model.add(f); fingers.push(f); });
  const thumb = new THREE.Mesh(stub, m); thumb.scale.set(1.1, 1.45, 1.1); thumb.position.set(0.4, 0.04, 0.13); thumb.rotation.set(0.7, 0, -0.85); model.add(thumb);
  const cuff = new THREE.Mesh(cachedGeo('mit_cuff', () => new THREE.CylinderGeometry(0.34, 0.36, 0.22, 20)), new THREE.MeshStandardMaterial({ color: '#F7A7CD', roughness: 0.8, transparent: true, opacity: 1 }));
  cuff.position.y = -0.5; cuff.scale.z = 0.62; model.add(cuff);
  g.userData = { model, fingers, thumb, tip: new THREE.Vector3(0.52, 0.12, 0.27), mats: [m, cuff.material] };
  g.traverse(o => { if (o.isMesh) o.castShadow = true; }); g.visible = false;
  return g;
}
const _F = new THREE.Vector3(), _R = new THREE.Vector3(), _U = new THREE.Vector3(), _UP = new THREE.Vector3(0, 1, 0), _m4b = new THREE.Matrix4();
// Las manos RODEAN la geometría: se calcula el contorno real del squishy (visto desde la cámara) y
// cada mano se desliza por ese contorno apretando. Rectangular → va por los bordes y dobla la
// esquina; redondo → va haciendo un arco. Los dedos se curvan según la curvatura del borde.
const WorldPress = {
  active: false, sq: null, sx: 0, sy: 0, t: 0, lastDepth: 0, speed: 0, lmx: 0, lmy: 0, camDir: null, vis: 0, hs: null, leaving: 0,
  path: null, a: 0, aUser: 0, orb: 0, orbT: 0, zoom: 1,
  thumbs: [{ id: 'wL', phase: 0 }, { id: 'wR', phase: Math.PI }],
  hands: null,
  build() { this.hands = [makeMitten(), makeMitten()]; for (const o of this.hands) scene.add(o); },
  frame(sq) {
    const sW = sqCenter(sq, _c3); _F.copy(_c3).sub(camera.position).normalize(); _R.crossVectors(_F, _UP).normalize(); _U.crossVectors(_R, _F);
    return { C: _c3.clone(), sW, halfW: sq.dims.w * 0.5 * sW * 0.88 };
  },
  kneadCam(sq) { // cámara de amasar: gira alrededor del squishy (arrastrar a los lados) y hace zoom (rueda)
    const F = this.frame(sq); const dist = Math.max(3.4, (sq.dims.h + sq.dims.w) * 0.5 * F.sW * 2.3 + 1.2) * this.zoom;
    const dir = this.camDir.clone().applyAxisAngle(_UP, this.orb);
    return { F, pos: F.C.clone().addScaledVector(dir, dist).add(new THREE.Vector3(0, dist * 0.55, 0)), look: F.C.clone().add(new THREE.Vector3(0, -0.1 * F.sW, 0)) };
  },
  // Silueta del squishy vista desde la cámara ACTUAL, calculada con los puntos del modelo (barato,
  // se hace cada frame): en cada dirección de la pantalla se toma el punto más lejano del centro.
  // Así al girar, el contorno se actualiza solo y las manos se van deslizando al nuevo borde.
  silhouette(sq) {
    const D = sq.def || (deformInit(sq), sq.def); this.frame(sq);
    const inv = new THREE.Matrix4().copy(sq.inner.matrixWorld).invert();
    const Ri = _R.clone().transformDirection(inv), Ui = _U.clone().transformDirection(inv), c = D.center;
    const NB = 72, best = new Float32Array(NB).fill(-1), bm = new Int32Array(NB), bi = new Int32Array(NB);
    D.meshes.forEach((m, mi) => {
      const P = m.Q; // forma YA deformada (apretada/hundida), para que el borde sea el real
      for (let i = 0; i < P.length; i += 3) {
        const dx = P[i] - c.x, dy = P[i + 1] - c.y, dz = P[i + 2] - c.z;
        const x = dx * Ri.x + dy * Ri.y + dz * Ri.z, y = dx * Ui.x + dy * Ui.y + dz * Ui.z, r = x * x + y * y;
        const b = Math.floor((Math.atan2(y, x) + Math.PI) / (Math.PI * 2) * NB) % NB;
        if (r > best[b]) { best[b] = r; bm[b] = mi; bi[b] = i / 3; }
      }
    });
    const pts = [];
    for (let deg = -35; deg <= 215; deg += 5) {
      const th = deg * Math.PI / 180, tt = Math.atan2(Math.sin(th), Math.cos(th));
      const b = Math.floor((tt + Math.PI) / (Math.PI * 2) * NB) % NB; if (best[b] < 0) continue;
      const m = D.meshes[bm[b]], j = bi[b] * 3;
      const radial = Ri.clone().multiplyScalar(Math.cos(th)).addScaledVector(Ui, Math.sin(th));
      pts.push({ th, p: new THREE.Vector3(m.Q[j], m.Q[j + 1], m.Q[j + 2]), n: new THREE.Vector3(m.PN[j], m.PN[j + 1], m.PN[j + 2]).multiplyScalar(0.4).addScaledVector(radial, 0.6).normalize() });
    }
    if (pts.length < 4) return null;
    for (let i = 0; i < pts.length; i++) { const a = pts[Math.max(0, i - 2)].n, b = pts[Math.min(pts.length - 1, i + 2)].n; pts[i].k = Math.acos(clamp(a.dot(b), -1, 1)); }
    return pts;
  },
  pathAt(th) {
    const P = this.path; if (th <= P[0].th) return P[0]; if (th >= P[P.length - 1].th) return P[P.length - 1];
    let i = 0; while (i < P.length - 2 && P[i + 1].th < th) i++;
    const A = P[i], B = P[i + 1], t = (th - A.th) / Math.max(1e-5, B.th - A.th);
    return { p: A.p.clone().lerp(B.p, t), n: A.n.clone().lerp(B.n, t).normalize(), k: lerp(A.k, B.k, t) };
  },
  tryStart(sx, sy) {
    // primero lo que está justo bajo el mouse; si apuntas (clic derecho/Q), el objetivo de la mira
    const t = Aim.target; let r = null;
    if (Aim.on && t) r = pickSquishy(Aim.rx, Aim.ry, camera, [t]) || rayToCenter(t);
    if (!r) r = pickSquishy(sx, sy, camera, squishTargets());
    if (!r && t) r = pickSquishy(Aim.rx, Aim.ry, camera, [t]) || rayToCenter(t);
    if (!r) return false;
    if (Math.hypot(player.pos.x - r.point.x, player.pos.z - r.point.z) > 34) return false;
    const sq = r.sq; sq.root.updateMatrixWorld(true);
    this.camDir = camera.position.clone().sub(sqCenter(sq, new THREE.Vector3()) && _c3.clone()).setY(0).normalize();
    const path = this.silhouette(sq); if (!path) return false;
    if (this.leaving > 0) this.finishLeave();
    this.active = true; this.sq = sq; this.path = path; this.t = 0; this.vis = 0; this.hs = null; this.lmx = sx; this.lmy = sy; this.aUser = 0; this.aUserT = 0; this.orb = this.orbT = 0; this.zoom = 1;
    for (const th of this.thumbs) { th.started = false; th.sp = null; th.sn = null; }
    sq.heldBy = 'player';
    squishAxis(sq, 'pinch', true, 0.3, 2);
    playSound('squishy', { pitch: sq === world.statue ? 0.6 : rand(0.9, 1.15), vol: 0.6 });
    ownerReact(sq, sq.wax && !sq.wax.done ? NPC_WAX_LINES : NPC_SQUISH_LINES); countSquish();
    if (!S.tipSquish) { S.tipSquish = 1; toast('¡Eso! Las manos le van dando la vuelta al squishy. Mueve el mouse a los lados para guiarlas. Clic derecho = apuntar · F = de cerca.', false, 5200); }
    if (!this.hands) this.build();
    return true;
  },
  move(e) {
    const dx = input.locked ? e.movementX : e.clientX - this.lmx, dy = input.locked ? e.movementY : e.clientY - this.lmy;
    this.lmx = e.clientX; this.lmy = e.clientY;
    this.orbT += dx * 0.0055; this.aUserT = clamp(this.aUserT - dy * 0.006, -0.9, 0.9); this.speed += Math.abs(dx) * 0.3 + Math.abs(dy);
  },
  // ángulo de cada mano sobre el contorno: van de los lados hacia arriba y vuelven (ida y vuelta lenta)
  angles() {
    const lo = -25 * Math.PI / 180, hi = 62 * Math.PI / 180, mid = (lo + hi) / 2, amp = (hi - lo) / 2;
    const a = clamp(mid + amp * Math.sin(this.t * 0.55 - Math.PI / 2) + this.aUser * amp, lo, hi);
    return [Math.PI - a, a];
  },
  update(dt) {
    if (!this.active) { this.updateLeave(dt); return; }
    const sq = this.sq; if (UI.open || !sq.root.parent) { this.end(); return; }
    const D = sq.def || (deformInit(sq), sq.def); this.t += dt; this.vis = Math.min(1, this.vis + dt * 3.2);
    this.orb = damp(this.orb, this.orbT, 5, dt); this.aUser = damp(this.aUser, this.aUserT, 5, dt);
    const KC = this.kneadCam(sq); cam.override = { pos: KC.pos, look: KC.look, knead: true, k: 6 };
    const sil = this.silhouette(sq); if (sil) this.path = sil;
    const F = this.frame(sq); const ang = this.angles();
    const hsT = F.sW * 0.88; this.hs = this.hs == null ? hsT : damp(this.hs, hsT, 6, dt); const hs = this.hs * (0.75 + 0.25 * this.vis);
    const k = 1 - Math.exp(-7 * dt), kq = 1 - Math.exp(-5.5 * dt);
    let sx = 0, sy = 0; const tg = [];
    this.thumbs.forEach((th, i) => {
      const c = this.pathAt(ang[i]);
      const pw = sq.inner.localToWorld(c.p.clone()), nw = c.n.clone().transformDirection(sq.inner.matrixWorld);
      // superficie real (ya hundida) en ese punto del contorno
      // la mano llega al borde en diagonal desde tu lado → siempre cae en la parte que ves
      const rd = nw.clone().multiplyScalar(-0.65).addScaledVector(_F, 0.55).normalize();
      _pr.set(pw.clone().addScaledVector(rd, -2 * F.sW), rd);
      const h = hitInfo(_pr.intersectObject(sq.root, true)); const ok = h && h.sq === sq;
      const surf = ok ? h.point : pw, sn = ok ? h.normal.clone().multiplyScalar(0.5).addScaledVector(nw, 0.5).normalize() : nw;
      th.sp = th.sp ? th.sp.lerp(surf, k) : surf.clone(); th.sn = th.sn ? th.sn.lerp(sn, k).normalize() : sn.clone();
      // la palma aprieta el borde: hundimiento que viaja por el contorno y deja rastro
      const ray = th.sn.clone().negate();
      if (!th.started) { const s = squishPress(sq, th.id, th.sp, th.sn, ray, 0.6); s.rate = 4; th.started = true; }
      else if (squishDrag(sq, th.id, th.sp, th.sn, ray)) { if (Math.random() < 0.35) SFX.crinkle(0.35); if (i === 0 && Math.random() < 0.3) countSquish(); }
      const s = D.src.find(x => x.id === th.id && x.held);
      if (s) { s.rate = 4; const st = D.stiff ? D.stiff(s) : 1, ramp = Math.min(1, this.t / 1.2); s.target = s.max * (0.5 + 0.16 * Math.sin(this.t * 2.2 + th.phase)) * ramp * Math.min(1, 0.3 + st); }
      // mano abrazando el borde: palma contra la superficie, pulgar hacia adelante, dedos siguiendo el contorno
      const h2 = this.hands[i], mir = i ? 1 : -1;
      const Z = th.sn.clone().negate(), X = _F.clone().multiplyScalar(-mir); X.addScaledVector(Z, -X.dot(Z)).normalize();
      const Y = new THREE.Vector3().crossVectors(Z, X);
      const q = new THREE.Quaternion().setFromRotationMatrix(_m4b.makeBasis(X, Y, Z));
      const pos = th.sp.clone().addScaledVector(th.sn, (0.2 + 0.9 * (1 - this.vis)) * hs).addScaledVector(_F, -0.32 * hs); // un poquito hacia la cámara: se ven completas
      h2.visible = true; h2.userData.model.scale.x = mir; h2.scale.setScalar(hs);
      tg.push({ h: h2, pos, q });
      h2.userData.mats.forEach(m => m.opacity = Math.min(1, this.vis * 1.3));
      const curl = 0.2 + clamp(c.k * 1.4, 0, 0.9); // borde recto = dedos estirados; esquina o curva = dedos doblados
      h2.userData.fingers.forEach((f, j) => { f.rotation.x = damp(f.rotation.x, curl + 0.08 * Math.sin(this.t * 2.2 + th.phase + j * 0.35), 6, dt); });
      const [px, py] = toScreen(th.sp); sx += px; sy += py;
    });
    // que nunca se monten una encima de la otra (sobre todo cuando llegan arriba)
    if (tg.length === 2) {
      const d = tg[1].pos.clone().sub(tg[0].pos), dl = d.length(), minSep = 1.0 * hs;
      if (dl < minSep) { const dir = dl > 1e-4 ? d.divideScalar(dl) : _R.clone(); const fix = (minSep - dl) * 0.5; tg[0].pos.addScaledVector(dir, -fix); tg[1].pos.addScaledVector(dir, fix); }
    }
    for (const t of tg) { if (!t.h.userData.init) { t.h.position.copy(t.pos); t.h.quaternion.copy(t.q); t.h.userData.init = true; } else { t.h.position.lerp(t.pos, k); t.h.quaternion.slerp(t.q, kq); } }
    this.sx = sx / 2; this.sy = sy / 2;
    // cámara de amasar: se acerca desde tu lado
    $('pressDot').classList.add('hidden');
    const md = D.maxDepth; const lvl = clamp(Math.abs(md - this.lastDepth) / Math.max(dt, 1e-3) * 1.0 + this.speed * 0.003, 0, 1); this.lastDepth = md; this.speed *= 0.7;
    SFX.foamSet(lvl, 0.55);
  },
  finishLeave() { this.leaving = 0; if (this.hands) for (const h of this.hands) { h.visible = false; h.userData.init = false; } },
  updateLeave(dt) {
    if (!(this.leaving > 0) || !this.hands) return;
    this.leaving -= dt; const a = Math.max(0, this.leaving / 0.4);
    this.hands.forEach((h) => { const out = h.position.clone().sub(this.lastC || h.position).setY(0); if (out.lengthSq() > 1e-6) out.normalize(); h.position.addScaledVector(out, dt * 2.5 * h.scale.x).addScaledVector(_F, -dt * 1.5 * h.scale.x); h.userData.mats.forEach(m => m.opacity = a); });
    if (this.leaving <= 0) this.finishLeave();
  },
  end() {
    if (!this.active) return; this.active = false;
    const sq = this.sq; this.lastC = sqCenter(sq, new THREE.Vector3()) && _c3.clone();
    for (const th of this.thumbs) squishRelease(sq, th.id);
    squishAxis(sq, 'pinch', false); sq.heldBy = null; SFX.foamSet(0);
    if (cam.override && cam.override.knead) cam.override = null;
    if (this.hands) this.leaving = 0.4;
    if (sq.def && sq.def.maxDepth > 0.5) SFX.crinkle(0.5);
    if (sq.wax) persistWax(sq);
    this.sq = null; this.path = null;
  },
};
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
canvas.addEventListener('wheel', (e) => { if (WorldPress.active) WorldPress.zoom = clamp(WorldPress.zoom + e.deltaY * 0.0012, 0.65, 1.7); }, { passive: true });
canvas.addEventListener('mousedown', (e) => {
  if (e.button !== 2 || UI.open) return; Aim.btnOn = true;
  if (!input.locked && canvas.requestPointerLock && !input.lockFailed) { try { const p = canvas.requestPointerLock(); if (p && p.catch) p.catch(() => { input.lockFailed = true; }); } catch (err) { input.lockFailed = true; } }
});
addEventListener('mouseup', (e) => { if (e.button === 2) Aim.btnOn = false; });
addEventListener('keydown', (e) => {
  if (isTyping() || e.repeat) return;
  const k = e.key.toLowerCase();
  if (UI.open === 'studio') { Studio.key(k, true, e); return; }
  if (UI.open) return;
  if (k === 'q') Aim.keyOn = true;
  if (k === 'f') {
    const sq = Aim.target || nearestSquishy(10);
    if (sq) Studio.open(squishDataOf(sq), sq.ownerLabel || '', sq);
    else { toast('Acércate a un squishy (tuyo, de otro jugador o de la Vitrina Viral) y presiona F'); playSound('error'); }
  }
});
addEventListener('keyup', (e) => { const k = e.key.toLowerCase(); if (k === 'q') Aim.keyOn = false; if (UI.open === 'studio') Studio.key(k, false, e); });

// =====================================================================
// ESTUDIO SQUISH v2 — modos: Dedo, Estirar, Torcer, Golpe + Palma, Apretar y 🕯️ Cera de vela
// =====================================================================
const SKIN = '#F4C7A1';
function makeFingerMesh() {
  const g = new THREE.Group(); const m = new THREE.MeshStandardMaterial({ color: SKIN, roughness: 0.65, transparent: true, opacity: 1 });
  const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.18, 0.42, 16), m); shaft.position.y = 0.21; g.add(shaft);
  // puño: el dedo sale de una mano de verdad (no un palito)
  const fist = new THREE.Mesh(superGeo('fist', 0.34, 0.3, 0.27, 0.75), m); fist.position.set(0, 0.68, 0.04); fist.scale.setScalar(1.15); g.add(fist);
  const bump = new THREE.SphereGeometry(0.11, 12, 8);
  [-0.17, 0, 0.17].forEach((x, i) => { const k = new THREE.Mesh(bump, m); k.scale.set(1, 0.9, 1.1); k.position.set(x, 0.42 - i * 0.02, -0.14); g.add(k); });
  const thumb = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.11, 0.42, 12), m); thumb.position.set(0.34, 0.5, 0.1); thumb.rotation.set(0.3, 0, 0.6); thumb.scale.set(1.1, 0.8, 1.1); g.add(thumb);
  const wrist = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.26, 0.5, 16), m); wrist.position.set(0, 1.12, 0.04); g.add(wrist);
  const tip = new THREE.Mesh(new THREE.SphereGeometry(0.17, 16, 12), m); g.add(tip);
  const nail = new THREE.Mesh(new THREE.SphereGeometry(0.1, 12, 8), new THREE.MeshStandardMaterial({ color: '#FBE3D6', roughness: 0.3, transparent: true, opacity: 1 }));
  nail.scale.set(1.1, 1.2, 0.35); nail.position.set(0, 0.12, -0.14); g.add(nail);
  const knuckle = new THREE.Mesh(new THREE.TorusGeometry(0.15, 0.012, 6, 16), new THREE.MeshStandardMaterial({ color: '#E5AE88', roughness: 0.8, transparent: true, opacity: 1 })); knuckle.rotation.x = Math.PI / 2; knuckle.position.y = 0.3; knuckle.scale.setScalar(1.15); g.add(knuckle);
  g.userData.mats = [m, nail.material, knuckle.material];
  g.traverse(o => { if (o.isMesh) o.castShadow = true; });
  return g;
}
function makeHandMesh() {
  const g = new THREE.Group(); const m = new THREE.MeshStandardMaterial({ color: SKIN, roughness: 0.65, transparent: true, opacity: 1 });
  const palm = new THREE.Mesh(superGeo('hand_palm', 0.62, 0.15, 0.62, 0.55), m); g.add(palm);
  const fg = new THREE.CylinderGeometry(0.12, 0.13, 0.75, 12); const tg = new THREE.SphereGeometry(0.12, 12, 8);
  [-0.42, -0.14, 0.14, 0.42].forEach((x, i) => { const L = i === 0 ? 0.6 : i === 3 ? 0.65 : 0.8; const f = new THREE.Mesh(fg, m); f.rotation.x = Math.PI / 2; f.position.set(x, 0, -0.6 - L * 0.5 + 0.1); f.scale.y = L / 0.75; g.add(f); const t = new THREE.Mesh(tg, m); t.position.set(x, 0, -0.6 - L + 0.12); g.add(t); });
  const th = new THREE.Mesh(fg, m); th.rotation.set(Math.PI / 2, 0, -0.9); th.position.set(0.72, 0, 0.05); th.scale.y = 0.75; g.add(th);
  g.userData.mats = [m]; g.traverse(o => { if (o.isMesh) o.castShadow = true; }); g.visible = false;
  return g;
}
function makeCandle(col) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.32, 1.2, 24), new THREE.MeshStandardMaterial({ color: col, roughness: 0.4 })); body.position.y = -0.6; g.add(body);
  const pool = new THREE.Mesh(new THREE.CylinderGeometry(0.27, 0.27, 0.05, 20), new THREE.MeshStandardMaterial({ color: col, roughness: 0.05, emissive: '#ff9a4a', emissiveIntensity: 0.25 })); pool.position.y = 0.01; g.add(pool);
  const wick = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.16, 6), new THREE.MeshStandardMaterial({ color: '#3a2a20' })); wick.position.y = 0.09; g.add(wick);
  const flame = new THREE.Mesh(new THREE.SphereGeometry(0.07, 12, 10), new THREE.MeshBasicMaterial({ color: '#FFB347' })); flame.scale.set(1, 2.2, 1); flame.position.y = 0.26; g.add(flame);
  const core = new THREE.Mesh(new THREE.SphereGeometry(0.04, 10, 8), new THREE.MeshBasicMaterial({ color: '#FFF3C4' })); core.scale.set(1, 2, 1); core.position.y = 0.22; g.add(core);
  g.userData = { body, pool, flame }; g.visible = false; return g;
}

const Studio = {
  inited: false, renderer: null, scene: null, cam: null, sq: null, data: null, src: null, invRef: null,
  yaw: 0.35, pitch: 0.42, dist: 7, fit: 1, fingers: new Map(), hover: null, spin: false, mode: 'dedo',
  palm: null, hands: null, palmVis: 0, squeezeVis: 0, rising: false, riseT0: 0, t: 0, lastDepth: 0, orbit: null, shake: 0, slap: 0,
  wax: { color: 'rosa', pour: 0, candle: null, stream: null, drips: [], steam: [], panel: false, announced: false }, twist: null, golpeT: -1,
  init() {
    const c = $('stCanvas');
    this.renderer = new THREE.WebGLRenderer({ canvas: c, antialias: true, alpha: true });
    this.renderer.outputEncoding = THREE.sRGBEncoding; this.renderer.shadowMap.enabled = true; this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
    this.scene = new THREE.Scene();
    this.scene.add(new THREE.HemisphereLight('#ffffff', '#c9b8e6', 0.85));
    const d = new THREE.DirectionalLight('#fff4ea', 0.85); d.position.set(3, 7, 5); d.castShadow = true; d.shadow.mapSize.set(1024, 1024);
    Object.assign(d.shadow.camera, { left: -5, right: 5, top: 5, bottom: -5, near: 1, far: 20 }); d.shadow.bias = -0.0008; this.scene.add(d);
    const rim = new THREE.DirectionalLight('#ffd6f2', 0.45); rim.position.set(-4, 3, -4); this.scene.add(rim);
    const plate = new THREE.Mesh(new THREE.CylinderGeometry(3.3, 3.5, 0.26, 64), new THREE.MeshStandardMaterial({ color: '#FFF4FA', roughness: 0.7 })); plate.position.y = -0.13; plate.receiveShadow = true; this.scene.add(plate);
    const rimM = new THREE.Mesh(new THREE.TorusGeometry(3.32, 0.07, 10, 80), new THREE.MeshStandardMaterial({ color: '#F7A7CD', roughness: 0.5 })); rimM.rotation.x = Math.PI / 2; this.scene.add(rimM);
    this.cam = new THREE.PerspectiveCamera(36, 1, 0.1, 60);
    this.palm = makeHandMesh(); this.scene.add(this.palm);
    this.hands = [makeHandMesh(), makeHandMesh()]; this.hands.forEach(h => this.scene.add(h));
    this.hover = makeFingerMesh(); this.hover.visible = false; this.hover.userData.mats.forEach(m => m.opacity = 0.35); this.scene.add(this.hover);
    this.pinch = [makeFingerMesh(), makeFingerMesh()]; this.pinch.forEach(f => { f.visible = false; f.scale.setScalar(0.85); this.scene.add(f); });
    this.wax.candle = makeCandle('#FFC3DA'); this.scene.add(this.wax.candle);
    this.wax.stream = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.05, 1, 10), new THREE.MeshStandardMaterial({ color: '#FFC3DA', roughness: 0.05, emissive: '#ff9a4a', emissiveIntensity: 0.3, transparent: true, opacity: 0.92 }));
    this.wax.stream.visible = false; this.scene.add(this.wax.stream);
    this.wax.dripGeo = new THREE.SphereGeometry(0.05, 8, 6);
    c.addEventListener('pointerdown', (e) => this.pDown(e));
    c.addEventListener('pointermove', (e) => this.pMove(e));
    c.addEventListener('pointerup', (e) => this.pUp(e)); c.addEventListener('pointercancel', (e) => this.pUp(e)); c.addEventListener('pointerleave', () => { this.hover.visible = false; });
    c.addEventListener('contextmenu', (e) => e.preventDefault());
    c.addEventListener('wheel', (e) => { this.dist = clamp(this.dist + e.deltaY * 0.004, 4.2, 11); e.preventDefault(); }, { passive: false });
    const holdBtn = (id, kind) => { const b = $(id); b.addEventListener('pointerdown', (e) => { e.preventDefault(); try { b.setPointerCapture(e.pointerId); } catch (err) { } this.hold(kind, true); }); for (const ev of ['pointerup', 'pointercancel']) b.addEventListener(ev, () => this.hold(kind, false)); };
    holdBtn('stPalm', 'palm'); holdBtn('stSqueeze', 'squeeze');
    $('stModes').addEventListener('click', (e) => { const b = e.target.closest('[data-mode]'); if (b) this.setMode(b.dataset.mode); });
    $('stSpin').addEventListener('click', () => { this.spin = !this.spin; $('stSpin').classList.toggle('on', this.spin); playSound('toggle'); });
    $('stClose').addEventListener('click', () => this.close());
    $('stWaxBtn').addEventListener('click', () => { this.wax.panel = !this.wax.panel; $('stWax').classList.toggle('hidden', !this.wax.panel); $('stWaxBtn').classList.toggle('on', this.wax.panel); playSound('click'); this.renderWax(); });
    $('stWaxColors').addEventListener('click', (e) => { const b = e.target.closest('[data-wc]'); if (!b) return; this.wax.color = b.dataset.wc; playSound('select'); this.renderWax(); });
    $('stPour').addEventListener('click', () => this.pour());
    $('stWaxOff').addEventListener('click', () => { if (this.sq && this.sq.wax) { waxRemove(this.sq); playSound('close'); this.renderWax(); } });
    this.inited = true;
  },
  open(data, ownerLabel, worldSq) {
    if (!this.inited) this.init();
    freeMouse(); WorldPress.end(); Aim.btnOn = Aim.keyOn = false;
    if (this.sq) { this.scene.remove(this.sq.root); this.sq.dispose(); }
    this.data = data; this.src = worldSq || null; this.invRef = S.inventory.includes(data) ? data : null;
    this.sq = buildSquishy(Object.assign({}, data, { size: 1, mutation: data.mutation === 'big' || data.mutation === 'tiny' ? 'normal' : data.mutation }), { noSparks: false });
    const dm = this.sq.dims; this.fit = 2.7 / Math.max(dm.h, dm.w * 0.95); this.sq.root.scale.setScalar(this.fit);
    this.sq.root.traverse(o => { if (o.isMesh) o.castShadow = true; }); this.sq.inStudio = true;
    this.sq.onWaxDone = () => { S.stats.waxCracked = (S.stats.waxCracked || 0) + 1; addXP(5); playSound('reward'); playSound('sparkle'); toast('¡Toda la cera fuera! 🕯️💥 +5 XP', true); this.renderWax(); };
    this.scene.add(this.sq.root); this.yaw = 0.3; this.pitch = 0.4; this.dist = 7.2; this.spin = false; $('stSpin').classList.remove('on');
    this.rising = false; this.t = 0; this.golpeT = -1; this.wax.pour = 0; this.wax.announced = !!(this.sq.wax);
    const sp = SP[data.species] || SP.cat, fil = FIL[data.filling];
    $('stName').textContent = data.name || squishyName(data); $('stOwner').textContent = ownerLabel || '';
    $('stRar').textContent = R[data.rarity] ? R[data.rarity].name : ''; $('stRar').style.background = R[data.rarity] ? R[data.rarity].color : '#aaa';
    const soft = this.sq.soft, bars = clamp(Math.round(soft * 3.3), 1, 5);
    $('stStats').innerHTML = `<div class="kv"><span>Suavidad</span><b>${'●'.repeat(bars)}<i>${'●'.repeat(5 - bars)}</i></b></div>
      <div class="kv"><span>Slow rise</span><b>${this.sq.rise.toFixed(1)} s</b></div>
      <div class="kv"><span>Relleno</span><b>${fil ? fil.name : '—'}</b></div>
      ${sp.famous ? '<div class="kv"><span>Tipo</span><b>✨ Viral</b></div>' : ''}
      <div class="kv"><span>Apachurrones</span><b id="stCount">${fmt(S.stats.squishes || 0)}</b></div>
      <div class="kv"><span>Cera</span><b id="stWaxStat">—</b></div>`;
    $('stRise').textContent = ''; $('stRise').className = '';
    this.setMode('dedo', true); this.renderWax();
    UI.open = 'studio'; $('studio').classList.remove('hidden'); $('sqHint').classList.add('hidden'); $('prompt').classList.add('hidden'); $('reticle').classList.add('hidden');
    this.resize(); playSound('open');
    if (worldSq && worldSq.owner) setTimeout(() => ownerReact(worldSq), 300);
  },
  close() {
    for (const [id] of [...this.fingers]) this.releaseFinger(id);
    this.hold('palm', false); this.hold('squeeze', false); this.endTwist(); SFX.foamStop();
    if (this.invRef) {
      const w = this.sq && waxSave(this.sq);
      if (w) this.invRef.wax = w; else delete this.invRef.wax;
      if (S.equipped === this.invRef.id) refreshCompanion(); pedestalsDirty = true; markDirty();
    }
    $('studio').classList.add('hidden'); UI.open = null; playSound('close'); canvas.focus();
  },
  resize() { const w = innerWidth, h = innerHeight; this.renderer.setSize(w, h, false); this.cam.aspect = w / h; this.cam.updateProjectionMatrix(); },
  key(k, down, e) {
    if (down && !e.repeat) {
      if (k === 'escape') { this.close(); return; }
      if (k === ' ') { e.preventDefault(); this.hold('palm', true); }
      if (k === 'q') this.hold('squeeze', true);
      if (k === '1') this.setMode('dedo'); if (k === '2') this.setMode('estirar'); if (k === '3') this.setMode('torcer'); if (k === '4') this.setMode('golpe');
      if (k === 'c') $('stWaxBtn').click();
    } else if (!down) { if (k === ' ') this.hold('palm', false); if (k === 'q') this.hold('squeeze', false); }
  },
  setMode(m, silent) {
    this.mode = m; document.querySelectorAll('#stModes [data-mode]').forEach(b => b.classList.toggle('on', b.dataset.mode === m));
    $('stHelp').innerHTML = {
      dedo: '👆 <b>Clic y mantén</b> para hundir el dedo · <b>arrastra</b> para dejar huellas · varios dedos en táctil',
      estirar: '🤏 <b>Agarra y jala</b> para estirar la espuma (tipo NeeDoh) · suelta y mira cómo vuelve',
      torcer: '🌀 <b>Arrastra a los lados</b> para torcerlo como toalla · suelta para que se destuerza lento',
      golpe: '💥 <b>Clic</b> = golpe con la palma (aplasta de una) · ideal para reventar la cera',
    }[m] + '<br>Clic derecho = girar · rueda = zoom · <b>Espacio</b> palma · <b>Q</b> apretar · <b>1-4</b> modos · <b>C</b> cera';
    this.hover.visible = false; if (!silent) playSound('select');
  },
  hold(kind, on) {
    if (!this.sq) return; if (!this.sq.def) deformInit(this.sq); const D = this.sq.def;
    const ax = kind === 'palm' ? D.ax.flat : D.ax.pinch;
    if (on === ax.hold) return;
    if (on) { playSound('squishy', { pitch: kind === 'palm' ? 0.75 : 0.9, vol: 0.8 }); countSquish(); this.bump(); this.rising = false; }
    squishAxis(this.sq, kind === 'palm' ? 'flat' : 'pinch', on, 1, 4);
    $(kind === 'palm' ? 'stPalm' : 'stSqueeze').classList.toggle('holding', on);
    if (!on) this.checkRiseStart();
  },
  bump() { const el = $('stCount'); if (el) el.textContent = fmt(S.stats.squishes || 0); },
  pickEv(e) { const r = this.renderer.domElement.getBoundingClientRect(); return pickSquishy(e.clientX - r.left, e.clientY - r.top, this.cam, [this.sq], r.width, r.height); },
  planeHit(e, point) {
    const r = this.renderer.domElement.getBoundingClientRect(); _ndc.set((e.clientX - r.left) / r.width * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    _pr.setFromCamera(_ndc, this.cam); const n = this.cam.getWorldDirection(new THREE.Vector3()); const pl = new THREE.Plane().setFromNormalAndCoplanarPoint(n, point);
    return _pr.ray.intersectPlane(pl, new THREE.Vector3());
  },
  pDown(e) {
    if (!this.sq) return; e.preventDefault();
    try { this.renderer.domElement.setPointerCapture(e.pointerId); } catch (err) { /* puntero sintético */ }
    if (e.button === 2 || e.button === 1) { this.orbit = { id: e.pointerId, x: e.clientX, y: e.clientY }; return; }
    if (this.mode === 'torcer') { this.twist = { id: e.pointerId, x0: e.clientX, last: 0 }; squishAxis(this.sq, 'twist', true, 0, 10); playSound('squishy', { pitch: 1.1, vol: 0.5 }); countSquish(); this.bump(); this.rising = false; return; }
    if (this.mode === 'golpe') { this.golpe(); return; }
    const r = this.pickEv(e);
    if (!r) { this.orbit = { id: e.pointerId, x: e.clientX, y: e.clientY }; return; }
    const id = 'f' + e.pointerId;
    if (this.mode === 'estirar') {
      squishPull(this.sq, id, r.point, r.normal, r.ray);
      this.fingers.set(id, { id, kind: 'pull', grab: r.point.clone(), x: e.clientX, y: e.clientY, speed: 0, last: 0 });
      playSound('squishy', { pitch: 1.25, vol: 0.4 });
    } else {
      squishPress(this.sq, id, r.point, r.normal, r.ray, 1);
      let f = this.fingers.get(id); if (!f) { f = { mesh: makeFingerMesh(), id, kind: 'dent' }; this.scene.add(f.mesh); this.fingers.set(id, f); }
      f.x = e.clientX; f.y = e.clientY; f.dirty = true; f.speed = 0; f.mesh.visible = true;
      playSound('squishy', { pitch: rand(0.95, 1.2), vol: 0.5 });
    }
    countSquish(); this.bump(); this.rising = false; $('stRise').textContent = '';
  },
  pMove(e) {
    if (this.orbit && this.orbit.id === e.pointerId) { this.yaw -= (e.clientX - this.orbit.x) * 0.008; this.pitch = clamp(this.pitch + (e.clientY - this.orbit.y) * 0.006, -0.1, 1.2); this.orbit.x = e.clientX; this.orbit.y = e.clientY; return; }
    if (this.twist && this.twist.id === e.pointerId) {
      const tg = clamp((e.clientX - this.twist.x0) * 0.006, -1.4, 1.4); squishAxis(this.sq, 'twist', true, tg, 10);
      if (Math.abs(tg - this.twist.last) > 0.12) { SFX.squeak(0.7); this.twist.last = tg; } return;
    }
    const f = this.fingers.get('f' + e.pointerId);
    if (f) {
      f.speed += Math.abs(e.clientX - f.x) + Math.abs(e.clientY - f.y); f.x = e.clientX; f.y = e.clientY; f.dirty = true;
      if (f.kind === 'pull') {
        const h = this.planeHit(e, f.grab); if (h) { const d = this.sq.inner.worldToLocal(h.clone()).sub(this.sq.inner.worldToLocal(f.grab.clone())); squishPullTo(this.sq, f.id, d); if (Math.abs(d.length() - f.last) > 0.12) { SFX.creak(0.8); f.last = d.length(); } }
      }
      return;
    }
    if (e.pointerType === 'mouse' && this.mode !== 'torcer' && this.mode !== 'golpe') { const r = this.pickEv(e); if (r) { this.hover.visible = true; this.placeFinger(this.hover, r.point, r.normal, 0.18, 0.03); } else this.hover.visible = false; }
  },
  pUp(e) {
    if (this.orbit && this.orbit.id === e.pointerId) { this.orbit = null; return; }
    if (this.twist && this.twist.id === e.pointerId) { this.endTwist(); return; }
    this.releaseFinger('f' + e.pointerId);
  },
  endTwist() { if (!this.twist) return; this.twist = null; if (this.sq) { squishAxis(this.sq, 'twist', false); SFX.squeak(0.5); this.checkRiseStart(); } },
  golpe() {
    if (this.golpeT >= 0 && this.t - this.golpeT < 0.18) return; this.golpeT = this.t;
    squishAxis(this.sq, 'flat', true, 0.95, 32); this.slap = 0.12; this.shake = 0.18;
    playSound('squishy', { pitch: 0.62, vol: 1 }); if (SFX.ctx && !SFX.muted) SFX.tone(95, 0.12, 'sine', 0.22, 0, 0.5); countSquish(); this.bump(); this.rising = false;
    if (this.sq.wax) waxSmash(this.sq, 1);
    if (navigator.vibrate) { try { navigator.vibrate(20); } catch (err) { } }
  },
  releaseFinger(id) {
    const f = this.fingers.get(id); if (!f) return;
    squishRelease(this.sq, id); if (f.mesh) this.scene.remove(f.mesh); this.fingers.delete(id);
    if (f.kind === 'pull') { SFX.creak(0.5); playSound('squishy', { pitch: 1.4, vol: 0.35 }); }
    if (this.sq.def && this.sq.def.maxDepth > 0.55) SFX.crinkle(0.6);
    this.checkRiseStart();
  },
  checkRiseStart() { const D = this.sq && this.sq.def; if (!D) return; if (!squishHeld(this.sq) && D.maxDepth > 0.08) { this.rising = true; this.riseT0 = this.t; $('stRise').className = 'live'; } },
  placeFinger(mesh, point, normal, lift, dt) {
    const n = normal.clone().normalize(), p = point.clone().addScaledVector(n, 0.17 + lift), q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), n);
    if (!dt || !mesh.userData.placed) { mesh.position.copy(p); mesh.quaternion.copy(q); mesh.userData.placed = true; return; }
    mesh.position.lerp(p, 1 - Math.exp(-16 * dt)); mesh.quaternion.slerp(q, 1 - Math.exp(-10 * dt));
  },
  // ---- cera de vela
  renderWax() {
    if (!this.inited) return; const W = this.sq && this.sq.wax;
    $('stWaxColors').innerHTML = WAX_COLORS.map(w => `<button class="wc ${this.wax.color === w.id ? 'on' : ''}" data-wc="${w.id}" title="${w.name}" style="background:${w.c || 'linear-gradient(135deg,#ffb3c7,#ffe38a,#bfefdc,#bfe0ff,#dccbff)'}"></button>`).join('');
    const st = W ? waxState(this.sq) : null; const layers = st && !st.done ? st.layers : 0;
    $('stPour').disabled = layers >= WAX_MAX || this.wax.pour > 0;
    $('stPour').textContent = layers >= WAX_MAX ? `🕯️ Ya tiene ${WAX_MAX} capas` : `🕯️ Echar capa ${layers + 1}${layers ? ' encima' : ''}`;
    $('stWaxOff').classList.toggle('hidden', !W);
    $('stWaxLayers').innerHTML = st && !st.done ? st.list.map((L, i) => `<i style="background:${WAXC[L.c].c || 'linear-gradient(90deg,#ffb3c7,#ffe38a,#bfefdc,#bfe0ff)'}" title="Capa ${i + 1}"></i>`).reverse().join('') : '';
    $('stWaxInfo').textContent = !W ? 'Cada vertida es una capa nueva encima. Mezcla colores: al romperla se ven las capas de adentro.' : st.done ? '¡Limpio! Échale otra capa si quieres.' : st.grow < 1 ? 'Echando cera…' : st.hot > 0.25 ? 'Enfriando… 🌬️' : 'Lista: dedo, golpe, palma o apretón para romperla 💥';
  },
  pour() {
    if (!this.sq || this.wax.pour > 0) return;
    const L = waxAddLayer(this.sq, this.wax.color, { pourTime: 1.8 }); if (!L) return;
    this.wax.pour = 1.8; this.wax.announced = false;
    const col = WAXC[this.wax.color].c || '#FFD6E8';
    this.wax.candle.userData.body.material.color.set(col); this.wax.candle.userData.pool.material.color.set(col); this.wax.stream.material.color.set(col);
    this.wax.candle.visible = true; this.wax.stream.visible = true; playSound('open'); if (SFX.ctx && !SFX.muted) SFX.noise(1.6, 900, 0.05, 0, 0.6, 1.4);
    this.renderWax();
  },
  updateWax(dt) {
    const Wx = this.wax, sq = this.sq, W = sq.wax;
    const h = sq.dims.h * this.fit, w = sq.dims.w * this.fit;
    if (Wx.pour > 0) {
      Wx.pour -= dt; const p = 1 - Wx.pour / 1.8, a = p * Math.PI * 3.2;
      const cx = Math.cos(a) * w * 0.28, cz = Math.sin(a) * w * 0.22;
      const C = Wx.candle; C.position.set(cx + 0.55, h + 1.25, cz); C.rotation.set(0, 0, 2.2); C.updateMatrixWorld(true);
      const lip = new THREE.Vector3(0, 0.02, 0.0).applyMatrix4(C.matrixWorld);
      _pr.set(new THREE.Vector3(lip.x, h + 4, lip.z), new THREE.Vector3(0, -1, 0));
      const hi = _pr.intersectObject(sq.root, true).find(x => x.object.isMesh);
      const landY = hi ? hi.point.y : 0.02; const len = Math.max(0.05, lip.y - landY);
      Wx.stream.position.set(lip.x, landY + len / 2, lip.z); Wx.stream.scale.set(1, len, 1); Wx.stream.visible = true;
      if (Math.random() < dt * 25) { const d = new THREE.Mesh(Wx.dripGeo, Wx.stream.material); d.position.set(lip.x, landY, lip.z); this.scene.add(d); Wx.drips.push({ m: d, v: new THREE.Vector3(rand(-1, 1), rand(0.5, 1.6), rand(-1, 1)).multiplyScalar(0.8), life: 0 }); }
      Wx.candle.userData.flame.scale.set(1, 2.2 + Math.sin(this.t * 30) * 0.3, 1);
      if (Wx.pour <= 0) { Wx.candle.visible = false; Wx.stream.visible = false; this.renderWax(); }
    }
    for (let i = Wx.drips.length - 1; i >= 0; i--) { const d = Wx.drips[i]; d.life += dt; d.v.y -= 9 * dt; d.m.position.addScaledVector(d.v, dt); if (d.life > 0.35) { this.scene.remove(d.m); Wx.drips.splice(i, 1); } }
    // vapor mientras se enfría
    const ws = W ? waxState(sq) : null;
    if (ws && ws.grow >= 1 && ws.hot > 0.25 && Math.random() < dt * 14) {
      const s = new THREE.Mesh(new THREE.SphereGeometry(rand(0.08, 0.16), 8, 6), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.5, depthWrite: false }));
      s.position.set(rand(-w, w) * 0.35, h * rand(0.6, 1.0), rand(-w, w) * 0.3); this.scene.add(s); Wx.steam.push({ m: s, life: 0 });
    }
    for (let i = Wx.steam.length - 1; i >= 0; i--) { const s = Wx.steam[i]; s.life += dt; s.m.position.y += dt * 0.7; s.m.scale.setScalar(1 + s.life * 1.5); s.m.material.opacity = Math.max(0, 0.5 - s.life * 0.45); if (s.life > 1.1) { this.scene.remove(s.m); s.m.geometry.dispose(); s.m.material.dispose(); Wx.steam.splice(i, 1); } }
    if (ws && !ws.done && ws.grow >= 1 && ws.hot <= 0.25 && !Wx.announced) { Wx.announced = true; playSound('sparkle2'); this.renderWax(); toast('🕯️ ¡La cera ya está dura! Apriétala o dale golpes para que haga CRACK', false, 3200); }
    if (ws && ws.hot > 0.25 && Math.random() < dt * 2) this.renderWax();
    const st = $('stWaxStat'); if (st) st.textContent = ws ? (ws.done ? 'rota ✓' : `${ws.layers} capa${ws.layers > 1 ? 's' : ''} · ${ws.total - ws.remaining}/${ws.total}`) : '—';
  },
  update(dt) {
    if (UI.open !== 'studio' || !this.sq) return;
    this.t += dt; const sq = this.sq;
    if (this.spin && !this.fingers.size) this.yaw += dt * 0.6;
    const h = sq.dims.h * this.fit; const target = new THREE.Vector3(0, h * 0.45, 0);
    const cp = Math.cos(this.pitch); this.cam.position.set(Math.sin(this.yaw) * cp * this.dist, target.y + Math.sin(this.pitch) * this.dist, Math.cos(this.yaw) * cp * this.dist);
    if (this.shake > 0) { this.shake -= dt; this.cam.position.x += rand(-0.06, 0.06); this.cam.position.y += rand(-0.06, 0.06); }
    this.cam.lookAt(target);
    if (this.slap > 0) { this.slap -= dt; if (this.slap <= 0) { squishAxis(sq, 'flat', false); this.checkRiseStart(); } }
    sq.update(dt);
    const rect = this.renderer.domElement.getBoundingClientRect(); let spd = 0;
    const D = sq.def;
    let pinchShown = false;
    for (const f of this.fingers.values()) {
      if (f.kind === 'pull') {
        const s = D && D.src.find(x => x.id === f.id && x.held);
        if (s) {
          const tip = sq.inner.localToWorld(s.c.clone().addScaledVector(s.dir, s.depth));
          const nW = s.dir.clone().transformDirection(sq.inner.matrixWorld); const side = new THREE.Vector3().crossVectors(nW, this.cam.getWorldDirection(new THREE.Vector3())).normalize();
          this.pinch.forEach((pf, i) => { pf.visible = true; const sg = i ? 1 : -1; pf.position.copy(tip).addScaledVector(side, sg * 0.13).addScaledVector(nW, 0.05); pf.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), nW.clone().addScaledVector(side, sg * 0.9).normalize()); });
          pinchShown = true;
        }
        spd += f.speed; f.speed *= 0.6; continue;
      }
      const r = pickSquishy(f.x - rect.left, f.y - rect.top, this.cam, [sq], rect.width, rect.height);
      if (r) { if (f.dirty && squishDrag(sq, f.id, r.point, r.normal, r.ray)) { SFX.crinkle(0.7); if (Math.random() < 0.3) countSquish(); } this.placeFinger(f.mesh, r.point, r.normal, 0, dt); }
      f.dirty = false; spd += f.speed; f.speed *= 0.6;
    }
    if (!pinchShown) this.pinch.forEach(pf => pf.visible = false);
    // manos: palma arriba (también en golpe y torsión), apretón a los lados
    const flat = D ? D.flat : 0, pinch = D ? D.pinch : 0, tw = D ? D.twist : 0;
    const palmOn = D && (D.ax.flat.hold || D.ax.twist.hold);
    this.palmVis = damp(this.palmVis, palmOn ? 1 : flat > 0.05 ? 0.4 : 0, this.slap > 0 ? 30 : 8, dt);
    this.palm.visible = this.palmVis > 0.02; this.palm.userData.mats.forEach(m => m.opacity = Math.min(1, this.palmVis * 1.2));
    const top = h * (1 - flat * 0.62); this.palm.position.set(0, top + 0.17 + (1 - this.palmVis) * 1.2, 0.1); this.palm.rotation.set(0, tw, 0);
    this.squeezeVis = damp(this.squeezeVis, D && D.ax.pinch.hold ? 1 : pinch > 0.05 ? 0.4 : 0, 8, dt);
    const halfW = (D ? D.size.x / 2 : sq.dims.w / 2) * this.fit;
    this.hands.forEach((hm, i) => {
      const s = i ? 1 : -1; hm.visible = this.squeezeVis > 0.02; hm.userData.mats.forEach(m => m.opacity = Math.min(1, this.squeezeVis * 1.2));
      hm.rotation.set(0, 0, s < 0 ? Math.PI / 2 : -Math.PI / 2);
      hm.position.set(s * (halfW * (1 - pinch * 0.62) + 0.17 + (1 - this.squeezeVis) * 1.2), h * 0.5 * (1 + pinch * 0.2), 0.1);
    });
    this.updateWax(dt);
    const md = D ? D.maxDepth : 0;
    const lvl = clamp(Math.abs(md - this.lastDepth) / Math.max(dt, 1e-3) * 1.4 + spd * 0.004 + (D && (D.ax.flat.hold || D.ax.pinch.hold) ? 0.06 : 0), 0, 1); this.lastDepth = md;
    SFX.foamSet(lvl, D && D.ax.pinch.hold ? 0.35 : 0.7);
    if (this.rising) {
      const el = $('stRise');
      if (squishHeld(sq)) { this.rising = false; el.textContent = ''; }
      else if (md < 0.03) {
        this.rising = false; const tt = this.t - this.riseT0; const rec = tt > (S.stats.bestRise || 0);
        if (rec) S.stats.bestRise = +tt.toFixed(1);
        el.className = 'done'; el.innerHTML = `Volvió a su forma en <b>${tt.toFixed(1)} s</b>` + (tt >= 6 ? ' · ¡slow rise brutal! 🐢✨' : tt >= 3.5 ? ' · ¡bien slow! ✨' : ' · rebotón 😄') + (rec ? '<br><small>¡Nuevo récord de slow rise!</small>' : '');
        if (rec) playSound('sparkle'); markDirty();
      } else el.innerHTML = `Subiendo… <b>${(this.t - this.riseT0).toFixed(1)} s</b>`;
    }
    this.renderer.render(this.scene, this.cam);
  },
};
addEventListener('resize', () => { if (Studio.inited) Studio.resize(); });

// actualización por frame del mundo (se llama desde el loop principal)
function updateSquishWorld(dt) {
  for (const s of world.vitrina) s.update(dt);
  for (const n of npcs) {
    if (n.reactT > 0) n.reactT -= dt;
    if (!n.sq.onWaxDone) n.sq.onWaxDone = onWaxDoneWorld;
    if (n.rewaxT > 0) { n.rewaxT -= dt; if (n.rewaxT <= 0) { waxRemove(n.sq); const k = 1 + ((Math.random() * 3) | 0); for (let i = 0; i < k; i++) waxAddLayer(n.sq, pick(['blanca', 'rosa', 'lila', 'miel', 'menta', 'cielo', 'arcoiris']), { pourTime: 1 + i * 0.5 }); npcSay(n, `Listo, le eché ${k} capa${k > 1 ? 's' : ''} de cera 🕯️ ¡Rómpela!`, 4); } }
  }
  if (companion && !companion.onWaxDone) companion.onWaxDone = onWaxDoneWorld;
  WorldPress.update(dt); updateAim(dt); Studio.update(dt); updateWaxPieces(dt);
}
