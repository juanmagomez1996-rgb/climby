
// =====================================================================
// SCENE
// =====================================================================
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
renderer.setSize(innerWidth, innerHeight, false);
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene();
scene.fog = new THREE.Fog('#d8ecfa', 110, 230);
const camera = new THREE.PerspectiveCamera(58, innerWidth / innerHeight, 0.3, 500);

// sky dome
{
  const sky = new THREE.Mesh(new THREE.SphereGeometry(400, 32, 16), new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { top: { value: new THREE.Color('#8fc8f0') }, bot: { value: new THREE.Color('#fbe9f3') } },
    vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }',
    fragmentShader: 'uniform vec3 top; uniform vec3 bot; varying vec3 vP; void main(){ float h = clamp(vP.y*1.6+0.15,0.0,1.0); gl_FragColor = vec4(mix(bot, top, h),1.0); }',
  }));
  scene.add(sky);
  // soft low-poly clouds
  const cm = new THREE.MeshLambertMaterial({ color: '#ffffff', emissive: '#ffffff', emissiveIntensity: 0.35, flatShading: true });
  for (let i = 0; i < 14; i++) {
    const g = new THREE.Group(); const a = i / 14 * Math.PI * 2 + rand(-0.2, 0.2), r = rand(170, 240);
    for (let k = 0; k < 4; k++) { const s = new THREE.Mesh(new THREE.IcosahedronGeometry(rand(8, 14), 0), cm); s.position.set(k * 11 - 16, rand(-2, 3), rand(-4, 4)); g.add(s); }
    g.position.set(Math.cos(a) * r, rand(55, 90), Math.sin(a) * r); g.lookAt(0, g.position.y, 0); scene.add(g);
  }
}
const hemi = new THREE.HemisphereLight('#f4f0ff', '#a9b99a', 0.62); scene.add(hemi);
scene.add(new THREE.AmbientLight('#ffffff', 0.08));
const sun = new THREE.DirectionalLight('#fff1e0', 0.85);
sun.position.set(40, 70, 30); sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, { left: -60, right: 60, top: 60, bottom: -60, near: 1, far: 200 });
sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.03;
scene.add(sun); scene.add(sun.target);

// ---------- simple material helpers
const M = {};
function mat(hex, rough = 0.85, extra = {}) { const k = hex + rough + JSON.stringify(extra); return M[k] || (M[k] = new THREE.MeshStandardMaterial(Object.assign({ color: hex, roughness: rough, metalness: 0 }, extra))); }
function box(w, h, d, m, x, y, z, parent = scene, shadow = true) { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), typeof m === 'string' ? mat(m) : m); o.position.set(x, y, z); o.castShadow = shadow; o.receiveShadow = true; parent.add(o); return o; }
function cyl(rt, rb, h, m, x, y, z, seg = 24, parent = scene) { const o = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), typeof m === 'string' ? mat(m) : m); o.position.set(x, y, z); o.castShadow = true; o.receiveShadow = true; parent.add(o); return o; }
function textTex(lines, opt = {}) {
  const w = opt.w || 512, h = opt.h || 160; const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d');
  g.fillStyle = opt.bg || '#FFFCF8'; const r = opt.radius != null ? opt.radius : 36;
  g.beginPath(); g.roundRect ? g.roundRect(0, 0, w, h, r) : g.rect(0, 0, w, h); g.fill();
  if (opt.border) { g.lineWidth = 10; g.strokeStyle = opt.border; g.beginPath(); g.roundRect ? g.roundRect(5, 5, w - 10, h - 10, r - 4) : g.rect(5, 5, w - 10, h - 10); g.stroke(); }
  g.textAlign = 'center'; g.textBaseline = 'middle';
  lines.forEach((ln, i) => { g.fillStyle = ln.color || opt.color || '#282D3A'; g.font = `${ln.size || 64}px ${ln.font || "'Lilita One', 'Arial Rounded MT Bold', sans-serif"}`; g.fillText(ln.t, w / 2, ln.y != null ? ln.y * h : h / 2); });
  const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; t.anisotropy = 4; return t;
}
function signBoard(lines, w, h, x, y, z, rotY, opt = {}) {
  const t = textTex(lines, opt);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshStandardMaterial({ map: t, roughness: 0.9, transparent: true }));
  m.position.set(x, y, z); m.rotation.y = rotY || 0; scene.add(m); return m;
}

// =====================================================================
// COLLISION
// =====================================================================
const colliders = []; // {type:'c',x,z,r} | {type:'b',x0,x1,z0,z1}
function colC(x, z, r) { colliders.push({ type: 'c', x, z, r }); }
function colB(cx, cz, w, d) { colliders.push({ type: 'b', x0: cx - w / 2, x1: cx + w / 2, z0: cz - d / 2, z1: cz + d / 2 }); }
function resolveCollision(p, r) {
  for (const c of colliders) {
    if (c.type === 'c') {
      const dx = p.x - c.x, dz = p.z - c.z, d = Math.hypot(dx, dz), m = c.r + r;
      if (d < m && d > 1e-4) { p.x = c.x + dx / d * m; p.z = c.z + dz / d * m; }
    } else {
      const qx = clamp(p.x, c.x0, c.x1), qz = clamp(p.z, c.z0, c.z1); const dx = p.x - qx, dz = p.z - qz, d = Math.hypot(dx, dz);
      if (d < r) {
        if (d > 1e-4) { p.x = qx + dx / d * r; p.z = qz + dz / d * r; }
        else { // inside: push out along smallest axis
          const pens = [[p.x - c.x0 + r, -1, 0], [c.x1 - p.x + r, 1, 0], [p.z - c.z0 + r, 0, -1], [c.z1 - p.z + r, 0, 1]].sort((a, b) => a[0] - b[0])[0];
          p.x += pens[1] * pens[0]; p.z += pens[2] * pens[0];
        }
      }
    }
  }
  const d = Math.hypot(p.x, p.z); if (d > CONFIG.WORLD.radius) { p.x *= CONFIG.WORLD.radius / d; p.z *= CONFIG.WORLD.radius / d; }
}

// =====================================================================
// ASSETS: Kenney GLBs
// =====================================================================
const Models = {};
const Skins = {};
function parseGLB(b64) { return new Promise((res, rej) => new THREE.GLTFLoader().parse(b64ToBuf(b64), '', res, rej)); }
async function loadAssets() {
  const A = window.SW_ASSETS;
  Models.blocky = await parseGLB(A.blocky);
  await Promise.all(Object.entries(A.nature).map(async ([k, v]) => { try { Models[k] = await parseGLB(v); } catch (e) { console.warn('model fail', k, e); } }));
  const tl = new THREE.TextureLoader();
  await Promise.all(Object.entries(A.skins).map(([k, url]) => new Promise(res => {
    tl.load(url, t => { t.flipY = false; t.encoding = THREE.sRGBEncoding; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.magFilter = THREE.LinearFilter; Skins[k] = t; res(); }, undefined, () => res());
  })));
}
function placeModel(name, x, z, height, rotY = 0, y = 0) {
  const src = Models[name]; if (!src) return null;
  const o = src.scene.clone(true);
  const bb = new THREE.Box3().setFromObject(o); const h = bb.max.y - bb.min.y || 1;
  const s = height / h; o.scale.setScalar(s); o.position.set(x, y - bb.min.y * s, z); o.rotation.y = rotY;
  o.traverse(m => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; if (m.material) { m.material.roughness = 0.9; m.material.metalness = 0; } } });
  scene.add(o); return o;
}

// ---------- Blocky characters (Kenney Blocky Characters 2.0: 6 rigid parts, 27 clips)
function makeCharacter(skinKey) {
  const src = Models.blocky;
  const o = src.scene.clone(true);
  const m = new THREE.MeshLambertMaterial({ map: Skins[skinKey] || Skins.a });
  o.traverse(n => { if (n.isMesh) { n.material = m; n.castShadow = true; n.receiveShadow = false; } });
  o.scale.setScalar(CONFIG.PLAYER.scale);
  const group = new THREE.Group(); group.add(o);
  const mixer = new THREE.AnimationMixer(o);
  const clips = {}; for (const c of src.animations) clips[c.name] = c;
  const ch = {
    group, model: o, mixer, clips, current: null, actions: {},
    play(name, fade = 0.18, once = false) {
      if (this.onceBusy && !once) return;
      if (this.current === name && !once) return;
      const clip = clips[name]; if (!clip) return;
      const a = this.actions[name] || (this.actions[name] = mixer.clipAction(clip));
      a.reset(); a.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat); a.clampWhenFinished = once; a.enabled = true; a.setEffectiveWeight(1);
      const prev = this.current && this.actions[this.current];
      a.play(); if (prev && prev !== a) prev.crossFadeTo(a, fade, false);
      this.current = name;
      if (once) { this.onceBusy = true; const back = () => { mixer.removeEventListener('finished', back); this.onceBusy = false; if (this.current === name) { this.current = null; this.play(this.base || 'idle', 0.25); } }; mixer.addEventListener('finished', back); }
    },
    base: 'idle',
  };
  ch.play('idle');
  return ch;
}

// =====================================================================
// WORLD BUILD
// =====================================================================
const ZONES = {
  center: { x: 0, z: 0 },
  machines: { x: 0, z: 58, label: 'Máquinas', color: '#F7A7CD' },
  collection: { x: 0, z: -58, label: 'Colección', color: '#B999E8' },
  shop: { x: -58, z: 0, label: 'Tienda', color: '#F4D982' },
  trading: { x: 58, z: 0, label: 'Plaza de Intercambio', color: '#8BC7E8' },
};
const world = { vitrina: [], machines: [], pedestals: [], statue: null, fountainWater: null, shopCounter: null, idxBoard: null, animated: [] };

function buildWorld() {
  // ground
  const gTex = canvasTex('grass', 256, 256, (g, w, h) => { g.fillStyle = '#b6dd9a'; g.fillRect(0, 0, w, h); const r = seeded(21); for (let i = 0; i < 900; i++) { g.fillStyle = r() > 0.5 ? 'rgba(150,205,120,.55)' : 'rgba(200,235,170,.5)'; g.fillRect(r() * w, r() * h, 3, 3); } });
  gTex.repeat.set(26, 26); gTex.wrapT = THREE.RepeatWrapping;
  const ground = new THREE.Mesh(new THREE.CircleGeometry(260, 64), new THREE.MeshStandardMaterial({ map: gTex, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; scene.add(ground);

  // plaza tiles
  const tTex = canvasTex('tiles', 256, 256, (g, w, h) => { g.fillStyle = '#eadfd2'; g.fillRect(0, 0, w, h); g.strokeStyle = '#d6c7b6'; g.lineWidth = 6; for (let i = 0; i <= 4; i++) { g.beginPath(); g.moveTo(i * 64, 0); g.lineTo(i * 64, h); g.stroke(); g.beginPath(); g.moveTo(0, i * 64); g.lineTo(w, i * 64); g.stroke(); } });
  tTex.repeat.set(10, 10); tTex.wrapT = THREE.RepeatWrapping;
  const tileMat = new THREE.MeshStandardMaterial({ map: tTex, roughness: 0.95 });
  const plaza = new THREE.Mesh(new THREE.CircleGeometry(30, 48), tileMat); plaza.rotation.x = -Math.PI / 2; plaza.position.y = 0.04; plaza.receiveShadow = true; scene.add(plaza);
  const ring = new THREE.Mesh(new THREE.RingGeometry(29.5, 31.5, 64), mat('#e7b9d3')); ring.rotation.x = -Math.PI / 2; ring.position.y = 0.05; scene.add(ring);
  // paths
  for (const k of ['machines', 'collection', 'shop', 'trading']) {
    const z = ZONES[k]; const len = 40; const p = new THREE.Mesh(new THREE.PlaneGeometry(12, len), tileMat);
    p.rotation.x = -Math.PI / 2; p.rotation.z = Math.atan2(z.x, z.z); p.position.set(z.x * 0.52, 0.03, z.z * 0.52); p.receiveShadow = true; scene.add(p);
    const pad = new THREE.Mesh(new THREE.CircleGeometry(26, 48), tileMat); pad.rotation.x = -Math.PI / 2; pad.position.set(z.x, 0.035, z.z); pad.receiveShadow = true; scene.add(pad);
    const pr = new THREE.Mesh(new THREE.RingGeometry(25.4, 26.6, 64), mat(z.color)); pr.rotation.x = -Math.PI / 2; pr.position.set(z.x, 0.045, z.z); scene.add(pr);
  }

  buildCenter(); buildMachinesZone(); buildCollectionZone(); buildShopZone(); buildTradingZone(); buildNature();
}

function arch(zoneKey) {
  const z = ZONES[zoneKey]; const ang = Math.atan2(z.x, z.z); const d = 30; // entrance between center ring and zone
  const cx = Math.sin(ang) * (Math.hypot(z.x, z.z) - 26), cz = Math.cos(ang) * (Math.hypot(z.x, z.z) - 26);
  const g = new THREE.Group(); g.position.set(cx, 0, cz); g.rotation.y = ang; scene.add(g);
  const colM = mat(z.color, 0.7);
  for (const s of [-1, 1]) { const p = cyl(0.9, 1.1, 13, colM, s * 8, 6.5, 0, 16, g); const b = cyl(1.6, 1.6, 0.8, mat('#ffffff'), s * 8, 0.4, 0, 16, g); colC(cx + Math.cos(ang) * s * 8, cz - Math.sin(ang) * s * 8, 1.3); }
  const beam = box(19, 2.6, 1.6, mat('#ffffff', 0.7), 0, 13.3, 0, g);
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(15, 2.4), new THREE.MeshStandardMaterial({ map: textTex([{ t: z.label, size: 92 }], { w: 900, h: 144, bg: z.color, radius: 30 }), roughness: 0.8 }));
  sign.position.set(0, 13.3, 0.82); g.add(sign);
  const sign2 = sign.clone(); sign2.position.z = -0.82; sign2.rotation.y = Math.PI; g.add(sign2);
}

function buildCenter() {
  // fountain
  const stone = mat('#f6f1ea', 0.8), pink = mat('#f7c6dc', 0.7);
  cyl(10, 10.6, 1.6, stone, 0, 0.8, 0, 40);
  const water = new THREE.Mesh(new THREE.CircleGeometry(9.2, 40), new THREE.MeshStandardMaterial({ color: '#9fd8f2', roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.85 }));
  water.rotation.x = -Math.PI / 2; water.position.y = 1.45; scene.add(water); world.fountainWater = water;
  cyl(3.2, 3.8, 4.5, pink, 0, 3.4, 0, 24);
  cyl(4.2, 4.2, 0.7, stone, 0, 5.9, 0, 24);
  colC(0, 0, 10.8);
  // giant squishy statue
  const statue = buildSquishy({ species: 'cat', variant: 'pink', rarity: 'rare', mutation: 'normal', face: 'happy', size: 1 }, { noSparks: true });
  statue.root.scale.setScalar(3.4); statue.root.position.set(0, 6.25, 0); scene.add(statue.root);
  statue.ownerLabel = 'Estatua de la plaza'; world.statue = statue;
  buildVitrina();
  // water jets (animated spheres)
  const jm = new THREE.MeshStandardMaterial({ color: '#c6ecff', transparent: true, opacity: 0.75, roughness: 0.1 });
  for (let i = 0; i < 8; i++) { const j = new THREE.Mesh(new THREE.SphereGeometry(0.35, 8, 6), jm); scene.add(j); world.animated.push((t) => { const a = i / 8 * Math.PI * 2, ph = (t * 0.8 + i / 8) % 1; j.position.set(Math.cos(a) * (4.3 + ph * 3.5), 1.6 + Math.sin(ph * Math.PI) * 4, Math.sin(a) * (4.3 + ph * 3.5)); }); }
  // floating logo
  const logo = new THREE.Mesh(new THREE.PlaneGeometry(22, 5.5), new THREE.MeshBasicMaterial({ map: textTex([{ t: 'Squishy World', size: 120, color: '#ffffff' }], { w: 1024, h: 256, bg: 'rgba(0,0,0,0)' }), transparent: true, depthWrite: false }));
  logo.position.set(0, 24, 0); scene.add(logo);
  world.animated.push((t) => { logo.position.y = 24 + Math.sin(t) * 0.5; logo.quaternion.copy(camera.quaternion); });
  const logoBack = new THREE.Mesh(new THREE.PlaneGeometry(22.8, 6.2), new THREE.MeshBasicMaterial({ map: textTex([{ t: 'Squishy World', size: 120, color: '#E57AAE' }], { w: 1024, h: 256, bg: 'rgba(0,0,0,0)' }), transparent: true, depthWrite: false }));
  logo.add(logoBack); logoBack.position.set(0.25, -0.25, -0.05);
  // benches around plaza
  for (let i = 0; i < 8; i++) { if (i % 2 === 0) continue; const a = i / 8 * Math.PI * 2; bench(Math.sin(a) * 22, Math.cos(a) * 22, a + Math.PI); }
}
function bench(x, z, rot) {
  const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = rot; scene.add(g);
  const wood = mat('#e8b98a', 0.9), leg = mat('#8a7fa8', 0.7);
  box(6, 0.5, 1.8, wood, 0, 1.6, 0, g); box(6, 1.6, 0.4, wood, 0, 2.8, -0.8, g);
  for (const s of [-1, 1]) box(0.5, 1.6, 1.6, leg, s * 2.5, 0.8, 0, g);
  colC(x, z, 2.6);
}

// ---------- MACHINES
function buildMachine(def, x, z) {
  const g = new THREE.Group(); g.position.set(x, 0, z); scene.add(g); // front (local -z) faces the plaza
  const body = mat(def.color, 0.55), white = mat('#ffffff', 0.5), dark = mat('#3a4154', 0.5);
  cyl(4.6, 5, 1.2, white, 0, 0.6, 0, 32, g);
  const base = cyl(4, 4.3, 4.5, body, 0, 3.4, 0, 32, g);
  cyl(4.3, 4.3, 0.5, white, 0, 5.8, 0, 32, g);
  // glass dome
  const dome = new THREE.Mesh(new THREE.SphereGeometry(3.7, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({ color: '#e8f6ff', roughness: 0.05, metalness: 0.1, transparent: true, opacity: 0.28, depthWrite: false }));
  dome.position.y = 6.05; g.add(dome);
  // back tower with tank
  box(3.4, 12, 3.4, body, 0, 6, 5.2, g);
  const tank = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.6, 6, 24, 1, true), new THREE.MeshStandardMaterial({ color: '#ffffff', transparent: true, opacity: 0.35, roughness: 0.1, side: THREE.DoubleSide, depthWrite: false }));
  tank.position.set(0, 15.2, 5.2); g.add(tank);
  const liquid = cyl(1.45, 1.45, 1, mat('#F7A7CD', 0.3), 0, 12.7, 5.2, 24, g);
  cyl(1.8, 1.8, 0.5, white, 0, 18.4, 5.2, 24, g); cyl(1.8, 1.8, 0.5, white, 0, 12.1, 5.2, 24, g);
  // arm + nozzle
  box(1, 1, 5.4, dark, 0, 12.4, 2.3, g);
  const nozzle = cyl(0.5, 0.25, 2.8, dark, 0, 10.6, 0, 12, g);
  const stream = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 1, 10), new THREE.MeshStandardMaterial({ color: '#F7A7CD', emissive: '#F7A7CD', emissiveIntensity: 0.3, roughness: 0.3 }));
  stream.visible = false; g.add(stream);
  // lamp
  const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.7, 16, 12), new THREE.MeshStandardMaterial({ color: '#fff', emissive: '#ffe08a', emissiveIntensity: 0.4 }));
  lamp.position.set(0, 18.9, 5.2); g.add(lamp);
  // front panel buttons
  for (let i = 0; i < 3; i++) { const b = cyl(0.35, 0.35, 0.3, mat(['#FF7B8A', '#F4D982', '#9CE0CA'][i], 0.4), -1.1 + i * 1.1, 3.8, -4.15, 12, g); b.rotation.x = Math.PI / 2; }
  // name plate
  const plate = new THREE.Mesh(new THREE.PlaneGeometry(6, 1.9), new THREE.MeshStandardMaterial({ map: textTex([{ t: def.name, size: 58, y: 0.36 }, { t: def.sub, size: 34, y: 0.74, font: "800 34px Nunito, sans-serif" }], { w: 512, h: 160 }), roughness: 0.8 }));
  plate.position.set(0, 2.3, -4.35); plate.rotation.y = Math.PI; g.add(plate);
  // lock sign
  let lockSign = null;
  if (def.level > 1) {
    lockSign = new THREE.Mesh(new THREE.PlaneGeometry(6, 2), new THREE.MeshBasicMaterial({ map: textTex([{ t: '🔒 Requiere nivel ' + def.level, size: 50, color: '#fff' }], { w: 600, h: 200, bg: '#282D3A' }), transparent: true }));
    lockSign.position.set(0, 9, -0.5); lockSign.rotation.y = Math.PI; g.add(lockSign);
  }
  colC(x, z, 5.2); colB(x, z + 5.2, 3.6, 3.6);
  const m = { def, group: g, dome, liquid, nozzle, stream, lamp, lockSign, pos: new THREE.Vector3(x, 0, z), domeWorld: new THREE.Vector3(x, 6.05, z), shake: 0, inside: null };
  world.machines.push(m); return m;
}
function buildMachinesZone() {
  arch('machines');
  const Z = ZONES.machines;
  // factory hall: back wall, pillars, roof
  const wall = mat('#fff5fa', 0.9);
  box(64, 16, 2, wall, Z.x, 8, Z.z + 22);
  for (const s of [-1, 1]) box(2, 16, 26, wall, Z.x + s * 31, 8, Z.z + 10);
  colB(Z.x, Z.z + 22, 64, 2); colB(Z.x - 31, Z.z + 10, 2, 26); colB(Z.x + 31, Z.z + 10, 2, 26);
  for (let i = 0; i < 5; i++) { const rx = Z.x - 24 + i * 12; const r = box(12.4, 1, 28, mat(i % 2 ? '#F7A7CD' : '#ffffff', 0.7), rx, 21, Z.z + 9); r.rotation.z = i % 2 ? 0.18 : -0.18; }
  for (const s of [-1, 1]) for (const zz of [-3, 21]) { cyl(0.8, 0.8, 21, mat('#B999E8', 0.6), Z.x + s * 30, 10.5, Z.z + zz, 12); }
  // pipes on wall
  for (let i = 0; i < 4; i++) { const p = cyl(0.6, 0.6, 60, mat(['#8BC7E8', '#9CE0CA', '#F4D982', '#B999E8'][i], 0.4), Z.x, 4 + i * 2.6, Z.z + 20.6, 12); p.rotation.z = Math.PI / 2; }
  // conveyor
  box(40, 1.5, 4, mat('#3a4154', 0.6), Z.x, 0.75, Z.z + 16); colB(Z.x, Z.z + 16, 40, 4);
  for (let i = 0; i < 6; i++) { const crate = box(2.4, 2.4, 2.4, mat(['#F7A7CD', '#F4D982', '#9CE0CA'][i % 3], 0.8), Z.x - 16 + i * 6.5, 2.7, Z.z + 16); world.animated.push((t, dt) => { crate.position.x += dt * 2; if (crate.position.x > Z.x + 19) crate.position.x = Z.x - 19; }); }
  buildMachine(MACHINES[0], Z.x, Z.z + 2);
  buildMachine(MACHINES[1], Z.x - 17, Z.z + 4);
  buildMachine(MACHINES[2], Z.x + 17, Z.z + 4);
}

// ---------- COLLECTION
function buildCollectionZone() {
  arch('collection');
  const Z = ZONES.collection;
  // pavilion floor + back wall + columns (Kenney statue columns)
  cyl(22, 22.5, 1, mat('#f0e9fb', 0.8), Z.x, 0.5, Z.z - 4, 48);
  box(46, 14, 2, mat('#efe6fb', 0.9), Z.x, 7, Z.z - 20); colB(Z.x, Z.z - 20, 46, 2);
  for (let i = 0; i < 6; i++) placeModel('statue_column', Z.x - 20 + i * 8, Z.z - 18, 12);
  // index board
  const board = new THREE.Mesh(new THREE.PlaneGeometry(16, 7), new THREE.MeshStandardMaterial({ map: textTex([{ t: 'Índice Squishy', size: 80, y: 0.36 }, { t: 'Presiona E para abrir tu álbum', size: 36, y: 0.72, font: "800 36px Nunito, sans-serif" }], { w: 800, h: 350, bg: '#B999E8', color: '#fff' }), roughness: 0.8 }));
  board.position.set(Z.x, 8, Z.z - 18.9); scene.add(board);
  world.idxBoard = { pos: new THREE.Vector3(Z.x, 0, Z.z - 14) };
  // pedestals by rarity in arc
  RARITIES.forEach((r, i) => {
    const a = (i - 2.5) / 5 * 2.2; const x = Z.x + Math.sin(a) * 13, z = Z.z - 4 - Math.cos(a) * 9 + 6;
    cyl(2.2, 2.6, 3.2, mat('#ffffff', 0.6), x, 2.6, z, 24);
    const rim = cyl(2.3, 2.3, 0.4, mat(r.color, 0.5, { emissive: r.color, emissiveIntensity: 0.25 }), x, 4.25, z, 24);
    const label = new THREE.Mesh(new THREE.PlaneGeometry(3.4, 0.9), new THREE.MeshStandardMaterial({ map: textTex([{ t: r.name, size: 66, color: '#fff' }], { w: 400, h: 106, bg: r.color, radius: 26 }), roughness: 0.8 }));
    label.position.set(x, 2.2, z + 2.45); scene.add(label); label.lookAt(x, 2.2, z + 10);
    const glass = new THREE.Mesh(new THREE.CylinderGeometry(2.1, 2.1, 4.6, 24, 1, true), new THREE.MeshStandardMaterial({ color: '#eef8ff', transparent: true, opacity: 0.18, roughness: 0.05, depthWrite: false, side: THREE.DoubleSide }));
    glass.position.set(x, 6.75, z); scene.add(glass);
    colC(x, z, 2.7);
    world.pedestals.push({ rarity: r.id, pos: new THREE.Vector3(x, 4.45, z), sq: null, holo: null });
  });
}

// ---------- SHOP
function buildShopZone() {
  arch('shop');
  const Z = ZONES.shop;
  const g = new THREE.Group(); g.position.set(Z.x - 6, 0, Z.z); g.rotation.y = Math.PI / 2; scene.add(g);
  // kiosk
  box(22, 4, 5, mat('#9CE0CA', 0.7), 0, 2, 0, g); box(23, 0.6, 6, mat('#ffffff', 0.6), 0, 4.3, 0.2, g);
  box(22, 14, 1.5, mat('#fff8e6', 0.9), 0, 7, -6, g);
  for (const s of [-1, 1]) cyl(0.5, 0.5, 13, mat('#ffffff'), s * 10.5, 6.5, -1.8, 10, g);
  // striped awning
  const aw = canvasTex('awning', 256, 64, (c, w, h) => { for (let i = 0; i < 8; i++) { c.fillStyle = i % 2 ? '#ffffff' : '#F4D982'; c.fillRect(i * w / 8, 0, w / 8 + 1, h); } });
  const awning = new THREE.Mesh(new THREE.BoxGeometry(24, 0.5, 8), [mat('#F4D982'), mat('#F4D982'), new THREE.MeshStandardMaterial({ map: aw, roughness: 0.9 }), mat('#F4D982'), mat('#F4D982'), mat('#F4D982')]);
  awning.position.set(0, 13.3, -1.6); awning.rotation.x = 0.22; awning.castShadow = true; g.add(awning);
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(12, 3), new THREE.MeshStandardMaterial({ map: textTex([{ t: 'Rellenos, Moldes y Mejoras', size: 50 }], { w: 640, h: 160, bg: '#FFFCF8', border: '#F4D982' }), roughness: 0.8 }));
  sign.position.set(0, 16, -3); g.add(sign);
  // shelves with filling jars
  for (let r = 0; r < 3; r++) { box(18, 0.4, 1.4, mat('#e8b98a'), 0, 5.8 + r * 2.6, -5, g); for (let i = 0; i < 7; i++) { const f = FILLINGS[(i + r * 4) % FILLINGS.length]; const jar = cyl(0.55, 0.55, 1.6, mat(f.color3 || (f.color.startsWith('#') ? f.color : '#ffd36e'), 0.35), -7.5 + i * 2.5, 6.8 + r * 2.6, -5, 12, g); cyl(0.6, 0.6, 0.3, mat('#ffffff'), -7.5 + i * 2.5, 7.7 + r * 2.6, -5, 12, g); } }
  colB(Z.x - 6, Z.z, 6, 23); colB(Z.x - 12, Z.z, 2, 23);
  world.shopCounter = { pos: new THREE.Vector3(Z.x - 2, 0, Z.z) };
}

// ---------- TRADING
function buildTradingZone() {
  arch('trading');
  const Z = ZONES.trading;
  const board = new THREE.Mesh(new THREE.PlaneGeometry(14, 5), new THREE.MeshStandardMaterial({ map: textTex([{ t: 'Intercambios', size: 80, y: 0.38 }, { t: 'Habla con los jugadores: [E]', size: 40, y: 0.74, font: "800 40px Nunito, sans-serif" }], { w: 700, h: 250, bg: '#8BC7E8', color: '#fff' }), roughness: 0.8 }));
  board.position.set(Z.x + 19, 7, Z.z); board.rotation.y = -Math.PI / 2; scene.add(board);
  for (const s of [-1, 1]) cyl(0.5, 0.5, 9, mat('#ffffff'), Z.x + 19.2, 4.5, Z.z + s * 6.5, 10);
  colB(Z.x + 19.2, Z.z, 1.2, 14);
  // trade tables
  for (const [dx, dz] of [[-6, -10], [-6, 10], [8, -12], [8, 12]]) {
    cyl(2.4, 2.4, 0.4, mat('#ffffff', 0.6), Z.x + dx, 3, Z.z + dz, 20); cyl(0.4, 0.6, 3, mat('#8BC7E8'), Z.x + dx, 1.5, Z.z + dz, 10);
    const umb = new THREE.Mesh(new THREE.ConeGeometry(4.5, 2, 8), mat(pick(['#F7A7CD', '#8BC7E8', '#F4D982', '#9CE0CA']), 0.8)); umb.position.set(Z.x + dx, 9.5, Z.z + dz); umb.castShadow = true; scene.add(umb);
    cyl(0.18, 0.18, 7, mat('#ffffff'), Z.x + dx, 6.2, Z.z + dz, 8);
    colC(Z.x + dx, Z.z + dz, 2.6);
  }
  bench(Z.x + 14, Z.z - 18, Math.PI * 0.2); bench(Z.x + 14, Z.z + 18, Math.PI * 0.8);
}

// ---------- NATURE (Kenney Nature Kit)
function buildNature() {
  const trees = ['tree_default', 'tree_oak', 'tree_fat', 'tree_detailed'];
  const r = seeded(42);
  // ring of trees around the edge
  for (let i = 0; i < 46; i++) {
    const a = i / 46 * Math.PI * 2 + r() * 0.05; const d = 98 + r() * 22;
    placeModel(trees[i % 4], Math.cos(a) * d, Math.sin(a) * d, 14 + r() * 9, r() * 6);
  }
  // fence ring
  for (let i = 0; i < 60; i++) { const a = i / 60 * Math.PI * 2; const o = placeModel('fence_simple', Math.cos(a) * 94, Math.sin(a) * 94, 2.6, -a + Math.PI / 2); if (o) o.scale.x *= 1.9; }
  // trees & bushes between zones
  for (let q = 0; q < 4; q++) {
    const a = Math.PI / 4 + q * Math.PI / 2;
    for (let k = 0; k < 3; k++) { const d = 44 + k * 15; const x = Math.cos(a) * d + (r() - 0.5) * 6, z = Math.sin(a) * d + (r() - 0.5) * 6; placeModel(trees[(q + k) % 4], x, z, 13 + r() * 6, r() * 6); colC(x, z, 1.4); }
    for (let k = 0; k < 7; k++) { const aa = a + (r() - 0.5) * 0.5, d = 36 + r() * 45; const x = Math.cos(aa) * d, z = Math.sin(aa) * d; placeModel(r() > 0.5 ? 'plant_bushLarge' : 'plant_bushDetailed', x, z, 2.6 + r() * 1.6, r() * 6); }
    for (let k = 0; k < 10; k++) { const aa = a + (r() - 0.5) * 0.7, d = 33 + r() * 50; placeModel(['flower_redA', 'flower_yellowA', 'flower_purpleA'][k % 3], Math.cos(aa) * d, Math.sin(aa) * d, 1.4 + r() * 0.6, r() * 6); }
    const ra = a + 0.12, rd = 70; placeModel('rock_largeA', Math.cos(ra) * rd, Math.sin(ra) * rd, 4, r() * 6); colC(Math.cos(ra) * rd, Math.sin(ra) * rd, 3);
  }
  // pots around the plaza ring
  for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2 + Math.PI / 8; const x = Math.sin(a) * 30, z = Math.cos(a) * 30; placeModel('pot_large', x, z, 2.2); placeModel('plant_bushDetailed', x, z, 2.4, 0, 1.7); colC(x, z, 1.5); }
  placeModel('log_stack', ZONES.shop.x + 4, ZONES.shop.z + 16, 2.6, 0.4); colC(ZONES.shop.x + 4, ZONES.shop.z + 16, 2.2);
  placeModel('sign', 18, 26, 4, Math.PI * 0.8);
}

// =====================================================================
// VITRINA VIRAL — los squishies famosos en pedestales para que cualquiera los apachurre
// =====================================================================
function buildVitrina() {
  const cols = ['#F7A7CD', '#8BC7E8', '#F4D982', '#B999E8', '#9CE0CA', '#F8B27C'];
  const list = SPECIES.filter(s => s.famous); const R0 = 15.6;
  list.forEach((sp, i) => {
    const a = (i + 0.5) / list.length * Math.PI * 2; const x = Math.sin(a) * R0, z = Math.cos(a) * R0;
    const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = a; scene.add(g);
    cyl(1.25, 1.4, 1.3, mat('#FFFCF8', 0.8), 0, 0.65, 0, 24, g); cyl(1.35, 1.35, 0.18, mat(cols[i % cols.length], 0.6), 0, 1.36, 0, 24, g);
    const plate = new THREE.Mesh(new THREE.PlaneGeometry(2.3, 0.62), new THREE.MeshStandardMaterial({ map: textTex([{ t: sp.name, size: sp.name.length > 16 ? 30 : 38, font: "900 " + (sp.name.length > 16 ? 30 : 38) + "px Nunito, sans-serif" }], { w: 380, h: 100, bg: '#FFFCF8', border: cols[i % cols.length], radius: 24 }), roughness: 0.9 }));
    plate.position.set(0, 0.7, 1.33); g.add(plate);
    colC(x, z, 1.5);
    const sq = buildSquishy({ species: sp.id, variant: 'original', rarity: 'common', mutation: 'normal', face: 'happy', size: 1, filling: 'classic_foam' }, { noSparks: true });
    const sc = Math.min(1.05, 2.4 / Math.max(sq.dims.h, sq.dims.w * 0.9));
    sq.root.scale.setScalar(sc); sq.root.position.set(x, 1.45, z); sq.root.rotation.y = a; scene.add(sq.root);
    sq.ownerLabel = 'Vitrina Viral'; sq.vitrina = true; world.vitrina.push(sq);
  });
  // letrero
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(9, 1.8), new THREE.MeshStandardMaterial({ map: textTex([{ t: '✨ Vitrina Viral ✨', size: 64 }], { w: 640, h: 128, bg: '#FFFCF8', border: '#F7A7CD' }), roughness: 0.9, transparent: true }));
  sign.position.set(0, 2.55, 10.75); scene.add(sign);
}
