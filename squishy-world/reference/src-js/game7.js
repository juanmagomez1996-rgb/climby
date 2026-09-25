
// =====================================================================
// TOUR DE BIENVENIDA — vuelo cinemático por todo Squishy World
// Muestra qué hay que hacer, a dónde ir (rutas brillantes en el piso), los otros jugadores y los
// retos (mapa desde arriba con pines). Termina bajando hasta tu personaje, que saluda, y te deja
// en tu cámara SIN salto: el último punto del vuelo es exactamente la pose de tu cámara normal.
// =====================================================================
const Tour = {
  active: false, t: 0, total: 0, onDone: null, keys: null, posCurve: null, lookCurve: null, times: null,
  routes: null, cards: null, cardIdx: -1, pins: [], waved: false, endPose: null,

  followPose() { // igual que updateCamera (modo normal) → aterrizaje exacto
    const C = CONFIG.CAM, look = new THREE.Vector3(player.pos.x, player.pos.y + C.lookH, player.pos.z);
    const cp = Math.cos(cam.pitch), sp = Math.sin(cam.pitch);
    const pos = look.clone().add(new THREE.Vector3(-Math.sin(cam.yaw) * cp, sp, -Math.cos(cam.yaw) * cp).multiplyScalar(cam.dist)); if (pos.y < 1.2) pos.y = 1.2;
    return { pos, look };
  },
  build() {
    const P = player.pos, Z = ZONES, V = (x, y, z) => new THREE.Vector3(x, y, z);
    const end = this.followPose(); this.endPose = end;
    // [tiempo, posición cámara, hacia dónde mira]
    const K = [
      [0, V(0, 105, 165), V(0, 8, 0)],
      [4.5, V(46, 46, 78), V(0, 7, 0)],
      [8.5, V(-18, 16, 34), V(Z.machines.x, 4, Z.machines.z)],
      [13, V(15, 13, 40), V(Z.machines.x, 4, Z.machines.z)],
      [16.5, V(24, 10, 12), V(0, 2.5, 0)],
      [19, V(25, 9.5, -5), V(0, 2.5, 0)],
      [21.5, V(15, 10, -20), V(0, 2.5, 0)],
      [25, V(-22, 14, -9), V(Z.shop.x, 3, Z.shop.z)],
      [28.5, V(-37, 12, 11), V(Z.shop.x, 3, Z.shop.z)],
      [32, V(-10, 15, -30), V(Z.collection.x, 3, Z.collection.z)],
      [35.5, V(9, 12, -40), V(Z.collection.x, 3, Z.collection.z)],
      [39, V(30, 14, -17), V(Z.trading.x, 3, Z.trading.z)],
      [43, V(44, 11, -10), V(Z.trading.x + 2, 3, Z.trading.z)],
      [47, V(12, 118, 38), V(0, 0, 4)],
      [52, V(4, 112, 30), V(0, 0, 2)],
      [56, V(P.x + 4, P.y + 22, P.z + 26), V(P.x, P.y + 3, P.z)],
      [59, V(P.x + 2, P.y + 9, P.z + 11), V(P.x, P.y + 3.2, P.z)],
      [61.5, end.pos.clone(), end.look.clone()],
    ];
    this.times = K.map(k => k[0]); this.total = K[K.length - 1][0];
    this.posCurve = new THREE.CatmullRomCurve3(K.map(k => k[1]), false, 'centripetal');
    this.lookCurve = new THREE.CatmullRomCurve3(K.map(k => k[2]), false, 'centripetal');
    // tarjetas de texto: [desde, hasta, número, título, texto, ruta a resaltar]
    this.cards = [
      [0.8, 7.6, '', 'SQUISHY WORLD', 'Llena, colecciona y apachurra los squishies más suaves del mundo ✨', null, true],
      [8.6, 15.4, '1', 'Las Máquinas', 'Aquí nacen tus squishies: mantén el botón y suelta en la zona <b>PERFECTO</b>. La Máquina 02 abre en nivel 5 y la Mega Llenadora en nivel 10.', 'machines'],
      [16.4, 23.6, '2', 'La Vitrina Viral', 'Los 13 squishies virales (mantequilla, queso, dumpling…). <b>Mantén clic</b> sobre cualquiera y tus manos lo amasan. <b>F</b> = verlo de cerca.', 'vitrina'],
      [25, 30.8, '3', 'La Tienda', 'Rellenos (la <b>Miel</b> tiene el slow rise más lento), moldes virales y mejoras para tu máquina.', 'shop'],
      [32, 37.8, '4', 'Tu Colección', 'Tus mejores squishies se lucen en los pedestales. Completa el Índice: <b>413</b> por descubrir.', 'collection'],
      [39, 45.8, '5', 'Los otros jugadores', 'Chatea, intercambia y apachúrrales su squishy. Ojo 👀 algunos andan con squishies de <b>cera</b>: ¡rómpesela!', 'trading'],
      [47, 55, '6', 'Tus retos', '', 'all'],
      [56.5, 62, '', 'Y este eres tú 👋', 'Tu aventura empieza ahora. ¡A llenar squishies!', 'me', true],
    ];
  },
  // rutas brillantes con flechitas que avanzan, desde la plaza hasta cada zona
  arrowTex() {
    const c = document.createElement('canvas'); c.width = 64; c.height = 64; const g = c.getContext('2d');
    g.fillStyle = 'rgba(255,255,255,0.0)'; g.fillRect(0, 0, 64, 64);
    g.strokeStyle = '#ffffff'; g.lineWidth = 9; g.lineCap = 'round'; g.lineJoin = 'round';
    g.beginPath(); g.moveTo(20, 12); g.lineTo(42, 32); g.lineTo(20, 52); g.stroke();
    const t = new THREE.CanvasTexture(c); t.wrapS = THREE.RepeatWrapping; t.wrapT = THREE.ClampToEdgeWrapping; t.encoding = THREE.sRGBEncoding; return t;
  },
  buildRoutes() {
    if (this.routes) return; this.routes = {};
    const mk = (key, from, to, color) => {
      const d = to.clone().sub(from), L = d.length(), grp = new THREE.Group();
      const tex = this.arrowTex(); tex.repeat.set(L / 2.2, 1);
      const strip = new THREE.Mesh(new THREE.PlaneGeometry(L, 2.2), new THREE.MeshBasicMaterial({ map: tex, transparent: true, opacity: 0, depthWrite: false, color: '#ffffff' }));
      const glow = new THREE.Mesh(new THREE.PlaneGeometry(L, 3.4), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0, depthWrite: false }));
      for (const m of [glow, strip]) { m.rotation.x = -Math.PI / 2; grp.add(m); }
      strip.position.y = 0.02; grp.position.copy(from).add(to).multiplyScalar(0.5); grp.position.y = 0.14; grp.rotation.y = Math.atan2(-d.z, d.x);
      scene.add(grp); this.routes[key] = { grp, strip, glow, tex, op: 0 };
    };
    const V = (x, z) => new THREE.Vector3(x, 0, z), s = 18, e = 48;
    mk('machines', V(0, s), V(0, e), '#F7A7CD'); mk('collection', V(0, -s), V(0, -e), '#B999E8');
    mk('shop', V(-s, 0), V(-e, 0), '#F4D982'); mk('trading', V(s, 0), V(e, 0), '#8BC7E8');
    // anillo de la vitrina
    const ring = new THREE.Mesh(new THREE.RingGeometry(14.2, 17, 64), new THREE.MeshBasicMaterial({ color: '#FFE38A', transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide }));
    ring.rotation.x = -Math.PI / 2; ring.position.y = 0.13; scene.add(ring); this.routes.vitrina = { ring, op: 0 };
  },
  play(onDone) {
    if (this.active) return;
    this.onDone = onDone || null; this.active = true; this.t = 0; this.cardIdx = -1; this.waved = false;
    WorldPress.end(); freeMouse(); UI.open = 'tour';
    this.build(); this.buildRoutes();
    // arranca desde donde está la cámara ahora (sin corte brusco)
    cam.pos.copy(this.posCurve.getPoint(0)); cam.look.copy(this.lookCurve.getPoint(0));
    document.body.classList.add('cine'); $('tour').classList.remove('hidden');
    requestAnimationFrame(() => $('tour').classList.add('on'));
    $('tourDots').innerHTML = this.cards.filter(c => c[2]).map(c => `<i data-n="${c[2]}"></i>`).join('');
    this.chord([523, 659, 784, 1047]);
  },
  chord(fs, vol = 0.07) { if (!SFX.ctx || SFX.muted) return; fs.forEach((f, i) => SFX.tone(f, 0.5, 'sine', vol, i * 0.09, 1)); },
  timeToU(t) {
    const T = this.times, n = T.length; if (t <= 0) return 0; if (t >= T[n - 1]) return 1;
    let i = 0; while (i < n - 2 && T[i + 1] <= t) i++;
    const l = (t - T[i]) / (T[i + 1] - T[i]); const e = l * l * (3 - 2 * l) * 0.35 + l * 0.65; // velocidad pareja, suave en cada punto
    return (i + e) / (n - 1);
  },
  update(dt) {
    if (!this.active) return;
    this.t += dt;
    const u = this.timeToU(this.t);
    const pos = this.posCurve.getPoint(u), look = this.lookCurve.getPoint(u);
    // último tramo: se mezcla con la pose en vivo de tu cámara → aterrizaje exacto
    const land = clamp((this.t - (this.total - 2.5)) / 2.5, 0, 1);
    if (land > 0) { const f = this.followPose(), k = land * land * (3 - 2 * land); pos.lerp(f.pos, k); look.lerp(f.look, k); }
    cam.override = { pos, look, k: 30 };
    // tarjetas
    const ci = this.cards.findIndex(c => this.t >= c[0] && this.t < c[1]);
    if (ci !== this.cardIdx) { this.cardIdx = ci; this.showCard(ci); }
    // rutas y anillo
    const act = ci >= 0 ? this.cards[ci][5] : null;
    for (const [key, r] of Object.entries(this.routes)) {
      const on = act === key || act === 'all'; r.op = damp(r.op, on ? 1 : 0, 3, dt);
      if (r.strip) { r.strip.material.opacity = 0.95 * r.op; r.glow.material.opacity = 0.45 * r.op; r.tex.offset.x -= dt * 1.4; }
      if (r.ring) r.ring.material.opacity = 0.55 * r.op * (0.8 + 0.2 * Math.sin(this.t * 4));
    }
    this.updatePins(act);
    if (act === 'me' && !this.waved && this.t > 58.5) { this.waved = true; player.ch.play('emote-yes', 0.25, true); playSound('pop'); }
    if (this.t >= this.total) this.finish();
  },
  showCard(i) {
    const el = $('tourCard'); el.classList.remove('in');
    document.querySelectorAll('#tourDots i').forEach(d => d.classList.toggle('on', i >= 0 && d.dataset.n === this.cards[i][2]));
    $('tourRetos').classList.toggle('show', i >= 0 && this.cards[i][5] === 'all');
    if (i < 0) return;
    const c = this.cards[i];
    setTimeout(() => {
      el.className = c[6] ? ('big' + (c[5] === 'me' ? ' top' : '')) : '';
      el.innerHTML = (c[2] ? `<span class="num">${c[2]}</span>` : '') + `<div><h2>${c[3]}</h2>${c[4] ? `<p>${c[4]}</p>` : ''}</div>`;
      el.classList.add('in');
    }, 180);
    if (c[5] === 'all') this.renderRetos();
    this.chord(c[6] ? [659, 784, 988] : [784, 988], 0.05); playSound('select');
  },
  renderRetos() {
    const q = currentQuest(), odds = RARITIES.map(r => `<span style="background:${r.color}">${r.name}</span>`).join('<b>›</b>');
    $('tourRetos').innerHTML = `<h3>🎯 Tus retos</h3>
      <div class="rt"><i>📜</i><div><b>Misión actual:</b> ${esc(q.title)} <small>(premio ${fmt(q.reward)} monedas)</small></div></div>
      <div class="rt"><i>🌈</i><div><b>Rarezas</b><div class="rar">${odds}</div><small>El Secreto sale 1 de cada 1.000 llenados</small></div></div>
      <div class="rt"><i>🏆</i><div><b>Meta:</b> llegar a nivel 10, abrir la Mega Llenadora, encontrar un <b>Secreto</b> y completar el Índice</div></div>
      <div class="rt"><i>🕯️</i><div><b>Extra:</b> romperles la cera a los squishies encerados y batir tu récord de slow rise</div></div>`;
  },
  updatePins(act) {
    const box = $('tourPins');
    if (!this.pins.length) {
      const P = [['🏭', 'Máquinas', () => new THREE.Vector3(ZONES.machines.x, 6, ZONES.machines.z)], ['✨', 'Vitrina Viral', () => new THREE.Vector3(-11, 5, -11)],
        ['🛍️', 'Tienda', () => new THREE.Vector3(ZONES.shop.x, 6, ZONES.shop.z)], ['🏆', 'Colección', () => new THREE.Vector3(ZONES.collection.x, 6, ZONES.collection.z)],
        ['🤝', 'Jugadores', () => new THREE.Vector3(ZONES.trading.x, 6, ZONES.trading.z)], ['⭐', 'Tú', () => new THREE.Vector3(player.pos.x, player.pos.y + 6, player.pos.z), 'me']];
      for (const p of P) { const d = document.createElement('div'); d.className = 'pin' + (p[3] ? ' me' : ''); d.innerHTML = `<i><b>${p[0]}</b></i><span>${p[1]}</span>`; box.appendChild(d); this.pins.push({ el: d, pos: p[2], me: !!p[3] }); }
    }
    for (const p of this.pins) {
      const show = act === 'all';
      p.el.classList.toggle('show', show);
      if (show) { const [x, y, z] = toScreen(p.pos()); p.el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -100%)`; p.el.style.visibility = z > 1 ? 'hidden' : 'visible'; }
    }
  },
  skip() { if (!this.active) return; playSound('click'); this.t = Math.max(this.t, this.total - 2.6); this.cardIdx = -2; },
  finish() {
    if (!this.active) return; this.active = false;
    const f = this.followPose(); cam.pos.copy(f.pos); cam.look.copy(f.look); cam.override = null;
    for (const r of Object.values(this.routes)) { if (r.strip) { r.strip.material.opacity = 0; r.glow.material.opacity = 0; } if (r.ring) r.ring.material.opacity = 0; }
    for (const p of this.pins) p.el.classList.remove('show');
    $('tour').classList.remove('on'); setTimeout(() => $('tour').classList.add('hidden'), 700);
    document.body.classList.remove('cine'); if (UI.open === 'tour') UI.open = null; canvas.focus();
    const cb = this.onDone; this.onDone = null; if (cb) cb();
  },
};
// teclas: Esc / Enter / Espacio saltan el tour
addEventListener('keydown', (e) => { if (!Tour.active) return; if (['Escape', 'Enter', ' '].includes(e.key)) { e.preventDefault(); e.stopImmediatePropagation(); Tour.skip(); } }, true);
$('tourSkip').addEventListener('click', () => Tour.skip());
$('bTour').addEventListener('click', () => { if (!UI.open) Tour.play(); });
// engancharlo al loop principal
{ const base = updateSquishWorld; updateSquishWorld = function (dt) { base(dt); Tour.update(dt); }; }

boot();
