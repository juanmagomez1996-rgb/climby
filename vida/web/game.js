// Una Vida en 20 Minutos — runner de una vida entera. Lienzo lógico 540×960.
(() => {
'use strict';
const L = window.LIFE, META = window.CHAR_META || {};
const W = 540, H = 960, SY = 96, SH = 644, SB = SY + SH, GY = SY + Math.round(SH * 0.885), PX = 170;
const COLS = ['#e2574c', '#e9b43a', '#8cc152', '#5d9cec'], ICON = ['apple', 'coin', 'star', 'heart'];
const TAU = Math.PI * 2;
const rand = (a, b) => a + Math.random() * (b - a), randi = (a, b) => Math.floor(rand(a, b + 1));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v)), lerp = (a, b, t) => a + (b - a) * t;
const pick = a => a[Math.floor(Math.random() * a.length)];
const wpick = o => { let s = 0; for (const k in o) s += o[k]; let r = Math.random() * s; for (const k in o) if ((r -= o[k]) < 0) return k; return Object.keys(o)[0]; };
const $ = id => document.getElementById(id);

// ---------------- Guardado ----------------
const SAVE_KEY = 'vida20.v1';
let save = { best: 0, lives: 0, music: true, sfx: true, vib: true, history: [] };
try { Object.assign(save, JSON.parse(localStorage.getItem(SAVE_KEY) || '{}')); } catch (e) {}
const persist = () => { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) {} };

// ---------------- Lienzo y escala ----------------
const stage = $('stage'), cv = $('cv'), ctx = cv.getContext('2d');
let scale = 1;
function fit() {
  const s = Math.min(innerWidth / W, innerHeight / H), dpr = Math.min(devicePixelRatio || 1, 3);
  scale = s;
  stage.style.transform = `translate(${(innerWidth - W * s) / 2}px, ${(innerHeight - H * s) / 2}px) scale(${s})`;
  cv.width = Math.round(W * s * dpr); cv.height = Math.round(H * s * dpr);
  ctx.setTransform(cv.width / W, 0, 0, cv.height / H, 0, 0);
}
addEventListener('resize', fit); fit();

// ---------------- Recursos ----------------
const IMG = {};
function loadImg(key, src) {
  return new Promise(res => { const im = new Image(); im.onload = () => { IMG[key] = im; res(); }; im.onerror = () => res(); im.src = src; });
}
const CHARS = ['ramon0', 'ramon1', 'ramon2', 'ramon3', 'ramon4', 'lucia', 'lucia_old', 'marga', 'marga_old', 'alba', 'alba_adult', 'dog'];
const ITEMS = [...Object.keys(L.pickups), ...Object.keys(L.hazards)];
async function loadAll() {
  const jobs = [];
  L.stages.forEach(s => jobs.push(loadImg(s.bg, `assets/bg/${s.bg}.webp`)));
  jobs.push(loadImg('title', 'assets/bg/title.webp'));
  CHARS.forEach(c => META[c] && jobs.push(loadImg(c, `assets/chars/${c}.webp`)));
  ITEMS.forEach(i => jobs.push(loadImg(i, `assets/items/${i}.webp`)));
  jobs.push(document.fonts.load("30px 'Chewy'"), document.fonts.load("30px 'Patrick Hand'"));
  await Promise.all(jobs.map(j => j.catch ? j.catch(() => {}) : j));
}

// ---------------- Audio ----------------
let AC = null, master = null, musicEl = null;
function audio() {
  if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); master = AC.createGain(); master.gain.value = 0.5; master.connect(AC.destination); } catch (e) {} }
  if (AC && AC.state === 'suspended') AC.resume();
  return AC;
}
function tone(f, d = 0.12, type = 'triangle', v = 0.2, slide = 0, delay = 0) {
  if (!save.sfx || !audio()) return;
  const t = AC.currentTime + delay, o = AC.createOscillator(), g = AC.createGain();
  o.type = type; o.frequency.setValueAtTime(f, t); if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, f + slide), t + d);
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(v, t + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t + d);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + d + 0.02);
}
function noise(d = 0.15, v = 0.2, hp = 800) {
  if (!save.sfx || !audio()) return;
  const b = AC.createBuffer(1, Math.floor(AC.sampleRate * d), AC.sampleRate), a = b.getChannelData(0);
  for (let i = 0; i < a.length; i++) a[i] = (Math.random() * 2 - 1) * (1 - i / a.length);
  const s = AC.createBufferSource(), f = AC.createBiquadFilter(), g = AC.createGain();
  f.type = 'highpass'; f.frequency.value = hp; g.gain.value = v; s.buffer = b; s.connect(f); f.connect(g); g.connect(master); s.start();
}
const SFX = {
  jump: () => tone(420, 0.16, 'triangle', 0.18, 380),
  jump2: () => tone(620, 0.14, 'triangle', 0.16, 500),
  land: () => noise(0.06, 0.08, 1500),
  pick: i => { const b = [523, 587, 659, 784][i] || 660; tone(b, 0.1, 'triangle', 0.18); tone(b * 1.5, 0.12, 'triangle', 0.14, 0, 0.06); },
  treat: () => { tone(700, 0.08, 'square', 0.08); tone(500, 0.14, 'square', 0.07, -100, 0.07); },
  hit: () => { noise(0.2, 0.3, 300); tone(160, 0.25, 'sawtooth', 0.12, -90); },
  card: () => { noise(0.18, 0.12, 2500); tone(330, 0.12, 'triangle', 0.1); },
  choose: () => { tone(660, 0.08); tone(990, 0.12, 'triangle', 0.16, 0, 0.07); },
  stage: () => [523, 659, 784, 1046].forEach((f, i) => tone(f, 0.22, 'triangle', 0.16, 0, i * 0.09)),
  bad: () => { tone(300, 0.2, 'triangle', 0.15, -120); tone(220, 0.3, 'triangle', 0.13, -80, 0.15); },
  good: () => [659, 784, 988].forEach((f, i) => tone(f, 0.16, 'triangle', 0.15, 0, i * 0.07)),
  tick: () => tone(900, 0.03, 'square', 0.04),
  death: () => [523, 440, 392, 262].forEach((f, i) => tone(f, 0.5, 'triangle', 0.14, 0, i * 0.3)),
  bday: () => [523, 523, 587, 523, 698, 659].forEach((f, i) => tone(f, 0.18, 'square', 0.06, 0, i * 0.15)),
};
const vib = ms => { if (save.vib && navigator.vibrate) try { navigator.vibrate(ms); } catch (e) {} };
function setMusic(on) {
  if (!musicEl) { musicEl = new Audio('assets/audio/music.mp3'); musicEl.loop = true; musicEl.volume = 0.45; }
  if (on && save.music) musicEl.play().catch(() => {}); else musicEl.pause();
}

// ---------------- Dibujo básico ----------------
function text(s, x, y, o = {}) {
  ctx.save();
  ctx.font = `${o.size || 28}px ${o.font || "'Patrick Hand', cursive"}`;
  ctx.textAlign = o.align || 'center'; ctx.textBaseline = o.base || 'middle';
  if (o.alpha != null) ctx.globalAlpha = o.alpha;
  if (o.stroke) { ctx.lineJoin = 'round'; ctx.lineWidth = o.sw || 6; ctx.strokeStyle = o.stroke; ctx.strokeText(s, x, y); }
  ctx.fillStyle = o.color || '#3b2416'; ctx.fillText(s, x, y);
  ctx.restore();
}
function wrapLines(s, maxW, size, font) {
  ctx.font = `${size}px ${font || "'Patrick Hand', cursive"}`;
  const out = []; let cur = '';
  for (const w of s.split(' ')) { const t = cur ? cur + ' ' + w : w; if (ctx.measureText(t).width > maxW && cur) { out.push(cur); cur = w; } else cur = t; }
  out.push(cur); return out;
}
function rrect(x, y, w, h, r, fill, stroke, lw = 3) {
  ctx.beginPath(); ctx.roundRect(x, y, w, h, r);
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.lineWidth = lw; ctx.strokeStyle = stroke; ctx.stroke(); }
}
function paperBox(x, y, w, h, a = 1) {
  ctx.save(); ctx.globalAlpha = a;
  rrect(x + 3, y + 6, w, h, 16, 'rgba(59,36,22,.35)');
  rrect(x, y, w, h, 16, '#fbf1dc', '#3b2416', 3);
  ctx.restore();
}
function sprite(key, frame, x, feet, h, o = {}) {
  const im = IMG[key], m = META[key];
  if (!im || !m) return false;
  const f = ((Math.floor(frame) % m.frames) + m.frames) % m.frames;
  const sx = (f % m.cols) * m.fw, sy = Math.floor(f / m.cols) * m.fh;
  const s = h / (m.fh * m.foot), w = m.fw * s, hh = m.fh * s;
  ctx.save(); ctx.translate(x, feet);
  if (o.rot) ctx.rotate(o.rot);
  ctx.scale((o.flip ? -1 : 1) * (o.sx || 1), o.sy || 1);
  if (o.alpha != null) ctx.globalAlpha = o.alpha;
  if (o.filter) ctx.filter = o.filter;
  ctx.drawImage(im, sx, sy, m.fw, m.fh, -w / 2, -hh * m.foot, w, hh);
  ctx.restore();
  return true;
}
function item(key, x, y, h, o = {}) {
  const im = IMG[key]; if (!im) { ctx.fillStyle = '#c33'; ctx.beginPath(); ctx.arc(x, y, h / 2, 0, TAU); ctx.fill(); return; }
  const w = im.width * h / im.height;
  ctx.save(); ctx.translate(x, y); if (o.rot) ctx.rotate(o.rot); if (o.alpha != null) ctx.globalAlpha = o.alpha;
  ctx.scale(o.sx || 1, o.sy || 1);
  ctx.drawImage(im, -w / 2, -h / 2, w, h); ctx.restore();
}
function shadow(x, y, w) { ctx.save(); ctx.fillStyle = 'rgba(40,25,15,.22)'; ctx.beginPath(); ctx.ellipse(x, y, w, w * 0.18, 0, 0, TAU); ctx.fill(); ctx.restore(); }

// ---------------- Efectos ----------------
let parts = [], floats = [], shakeT = 0, shakeA = 0;
function burst(x, y, col, n = 14, sp = 260, up = 0) {
  for (let i = 0; i < n; i++) { const a = rand(0, TAU), v = rand(sp * 0.3, sp); parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - up, r: rand(3, 7), life: rand(0.4, 0.9), col, g: 600 }); }
}
function dust(x, y, n = 4) { for (let i = 0; i < n; i++) parts.push({ x: x + rand(-10, 10), y, vx: rand(-80, -20), vy: rand(-60, -10), r: rand(4, 9), life: rand(0.3, 0.6), col: 'rgba(230,215,190,.8)', g: 0, puff: 1 }); }
function float(s, x, y, col = '#3b2416', size = 30) { floats.push({ s, x, y, col, size, life: 1.2 }); }
function shake(a, t) { shakeA = Math.max(shakeA, a); shakeT = Math.max(shakeT, t); }

// ---------------- Estado de la partida ----------------
let G = null, mode = 'loading', paused = false;
const stageOf = a => { let k = 0; L.stages.forEach((s, i) => { if (a >= s.from) k = i; }); return k; };
const yearDur = a => a < 4 ? 0.8 : 2.0;
const tr = s => s.replaceAll('{p}', G.partner || 'tu pareja').replaceAll('{h}', 'Alba').replaceAll('{a}', G.age);

function newLife() {
  G = {
    age: 0, yt: 0, st: L.start.slice(), flags: {}, partner: null, partnerSprite: null, later: [], tags: [], done: new Set(),
    stage: 0, prevStage: 0, fade: 1, dist: 0, speedMul: 1, spawnT: 1.5, ents: [],
    p: { y: GY, vy: 0, ground: true, jumps: 0, stumble: 0, inv: 0, frame: 0, land: 0 },
    followers: [], hijaAge: 0,
    card: null, moment: null, lastEvent: -5, lastMoment: 0, banners: [], stageBanner: 0,
    score: 0, picked: 0, hits: 0, dead: false, deathT: 0, cause: '', lastHurt: '', flash: [0, 0, 0, 0], shown: [0, 0, 0, 0],
  };
  G.shown = G.st.slice();
  parts = []; floats = [];
}

function apply(fx, cause, silent) {
  if (!fx) return;
  fx.forEach((v, i) => {
    if (!v) return;
    const dv = Math.round(v * rand(0.8, 1.2)) || Math.sign(v);
    G.st[i] = clamp(G.st[i] + dv, 0, 100); G.flash[i] = 1;
    if (!silent) float((dv > 0 ? '+' : '') + dv, 506, 790 + i * 42, COLS[i], 26);
    if (i === 0 && dv < 0 && cause) G.lastHurt = cause;
  });
  if (G.st[0] <= 0) die();
}
function banner(head, t, col = '#e0673c') { G.banners.push({ head, t: tr(t), col, time: 0 }); }

function die(cause) {
  if (G.dead) return;
  G.dead = true; G.deathT = 0; G.card = null; G.moment = null; hideCard();
  G.cause = cause || (G.lastHurt ? 'por ' + G.lastHurt : 'por no cuidarse');
  shake(8, 0.5); SFX.death(); vib([60, 80, 120]);
}

// ---------------- Seguidores (familia) ----------------
function syncFollowers() {
  const want = [];
  if (G.flags.pareja) {
    const old = G.age >= 62, base = G.partner === 'Marga' ? 'marga' : 'lucia';
    let key = old ? base + '_old' : base;
    if (!META[key]) key = old ? 'lucia_old' : 'lucia';
    want.push({ id: 'pareja', key, x: 92, h: G.age >= 62 ? 178 : 192 });
  }
  if (G.flags.hija) {
    const ha = G.age - G.hijaAge;
    want.push({ id: 'hija', key: ha < 16 ? 'alba' : 'alba_adult', x: 34, h: ha < 16 ? clamp(70 + ha * 7, 70, 165) : 180 });
  }
  if (G.flags.perro) want.push({ id: 'perro', key: 'dog', x: 262, h: 62 });
  for (const w of want) {
    const f = G.followers.find(f => f.id === w.id);
    if (f) { if (f.key !== w.key) { f.key = w.key; burst(f.x, GY - 80, '#fff', 16, 160); } f.tx = w.x; f.h = w.h; }
    else G.followers.push({ ...w, tx: w.x, x: -60, y: GY, vy: 0, frame: rand(0, 16), enter: 1 });
  }
  for (const f of G.followers) if (!want.find(w => w.id === f.id)) f.leave = 1;
}

// ---------------- Año a año ----------------
function yearTick() {
  G.age++;
  const s = G.st, a = G.age;
  if (a > 40) s[0] -= 0.5; if (a > 60) s[0] -= 0.9; if (a > 75) s[0] -= 0.8; if (s[2] < 20) s[0] -= 1;
  if (a >= 19 && a < 65) s[1] += 0.6; else if (a >= 65) s[1] -= 0.4;
  if (!G.flags.pareja && a > 30) s[3] -= 0.4;
  if (s[3] > 70) s[2] += 0.3;
  for (let i = 0; i < 4; i++) s[i] = clamp(s[i], 0, 100);
  G.score += (s[2] + s[3] + s[0] * 0.5 + s[1] * 0.3) / 10;
  SFX.tick();
  if (a % 10 === 0 && a <= 90) { SFX.bday(); burst(PX, GY - 200, '#ffd35a', 24, 300, 200); float(`¡${a} AÑOS!`, PX, GY - 250, '#e0673c', 34); }

  const sg = stageOf(a);
  if (sg !== G.stage) { G.prevStage = G.stage; G.stage = sg; G.fade = 0; G.stageBanner = 2.6; SFX.stage(); burst(PX, GY - 100, '#fff', 30, 220, 80); }

  for (const c of G.later.filter(c => c.at === a)) {
    banner('CONSECUENCIA · ' + a + ' AÑOS', c.t, '#9b59b6'); apply(c.fx, c.cause);
    if (c.unflag) G.flags[c.unflag] = 0;
    (c.fx || []).reduce((x, y) => x + y, 0) >= 0 ? SFX.good() : SFX.bad();
  }
  G.later = G.later.filter(c => c.at !== a);
  syncFollowers();
  if (G.dead) return;
  if (s[0] <= 0) return die();
  if (a >= 100 || (a >= 68 && Math.random() < (a - 66) * 0.012 + (100 - s[0]) / 900)) return die(a >= 95 ? 'de viejísimo' : 'de viejo, en su cama');

  // eventos automáticos
  for (const e of L.events) {
    if (!e.auto || G.done.has(e.id) || a < e.ages[0] || a > e.ages[1] || !condOk(e)) continue;
    if (a === e.ages[1] || Math.random() < 0.35) {
      G.done.add(e.id); banner('A LOS ' + a + ' AÑOS', e.auto.t, '#9b59b6'); apply(e.auto.fx); SFX.bad();
      if (e.auto.unflag) G.flags[e.auto.unflag] = 0; syncFollowers(); return;
    }
  }
  // decisiones
  const cands = L.events.filter(e => !e.auto && !G.done.has(e.id) && a >= e.ages[0] && a <= e.ages[1] && condOk(e));
  const urgent = cands.filter(e => e.key && (a === e.ages[1] || Math.random() < 0.55));
  let ev = urgent[0];
  if (!ev && a - G.lastEvent >= 2) {
    const pool = cands.filter(e => !e.key || a === e.ages[1]);
    if (pool.length && Math.random() < 0.55) ev = pick(pool);
  }
  if (ev) { G.done.add(ev.id); openCard(ev); return; }
  // momento de acción
  if (a >= 4 && a - G.lastMoment >= 4 && a - G.lastEvent >= 1 && Math.random() < 0.5) startMoment();
}
const condOk = e => (!e.need || e.need.every(f => G.flags[f])) && (!e.not || e.not.every(f => !G.flags[f]));

// ---------------- Cartas ----------------
function openCard(e) {
  G.card = { e, t: 0, dur: 10 }; G.lastEvent = G.age; SFX.card(); vib(15);
  $('card-age').textContent = `A LOS ${G.age} AÑOS`;
  $('card-q').textContent = tr(e.q);
  const box = $('card-opts'); box.innerHTML = '';
  e.o.forEach((o, i) => {
    const b = document.createElement('button'); b.className = 'opt'; b.textContent = tr(o.t);
    b.addEventListener('pointerdown', ev => { ev.stopPropagation(); choose(i); });
    box.appendChild(b);
  });
  $('card').classList.remove('hidden');
  $('card').style.animation = 'none'; void $('card').offsetWidth; $('card').style.animation = '';
}
function hideCard() { $('card').classList.add('hidden'); }
function outcome(r, silentTag) {
  if (!r) return;
  if (r.fx) apply(r.fx, r.cause);
  if (r.flag) G.flags[r.flag] = 1;
  if (r.unflag) G.flags[r.unflag] = 0;
  if (r.partner) G.partner = r.partner;
  if (r.flag === 'hija') G.hijaAge = G.age;
  if (r.later) G.later.push({ ...r.later, at: r.later.at != null ? r.later.at : G.age + r.later.in });
  if (r.m) banner('', r.m, '#3b2416');
  if (r.cause && r.fx && r.fx[0] < 0) G.lastHurt = r.cause;
}
function choose(i, auto) {
  if (!G.card) return;
  const o = G.card.e.o[i]; G.card = null; hideCard(); SFX.choose(); vib(10);
  if (auto) banner('LA VIDA DECIDE POR TI', o.t, '#8c6a4a');
  if (o.tag) G.tags.push({ a: G.age, t: tr(o.tag) });
  outcome(o);
  if (o.chance) {
    const c = o.chance, p = c.p + (c.stat != null ? (G.st[c.stat] - 50) / 250 : 0);
    const ok = Math.random() < p; outcome(ok ? c.ok : c.ko); ok ? SFX.good() : SFX.bad();
  }
  if (o.risk && Math.random() < o.risk.p) {
    banner('¡AY!', o.risk.t, '#e2574c'); apply(o.risk.fx, o.risk.cause); shake(12, 0.35); SFX.hit(); vib(80);
    G.p.stumble = 0.7;
  }
  syncFollowers();
}

// ---------------- Momentos (minijuegos) ----------------
function startMoment() {
  const a = G.age, list = L.moments.filter(m => a >= m.ages[0] && a <= m.ages[1] && (!m.need || m.need.every(f => G.flags[f])));
  if (!list.length) return;
  const m = pick(list), M = { id: m.id, title: m.title, hint: m.hint, t: 0, dur: 4, objs: [], got: 0, n: 0, x: 0, v: 0, done: 0, res: 0 };
  G.lastMoment = a;
  if (m.id === 'pelota') { M.dur = 3.2; M.objs.push({ x: W + 30, y: SY + 160, vx: -300, vy: -80, r: 34 }); }
  if (m.id === 'monedas') for (let i = 0; i < 5; i++) M.objs.push({ x: rand(80, W - 80), y: SB + 30, vy: -rand(620, 760), d: i * 0.32, live: 1, r: 34 });
  if (m.id === 'corazones') for (let i = 0; i < 4; i++) M.objs.push({ x: rand(80, W - 80), y: SB + 30, d: i * 0.45, live: 1, r: 36 });
  if (m.id === 'ritmo') { M.dur = 4.6; for (let i = 0; i < 4; i++) M.objs.push({ t: 0.7 + i * 0.95, hit: 0 }); }
  if (m.id === 'informe') { M.dur = 3.4; M.n = 16; }
  if (m.id === 'equilibrio' || m.id === 'bebe') { M.dur = 3.8; M.x = rand(-0.15, 0.15); M.k = a > 60 ? 1.35 : 1; }
  G.moment = M; tone(990, 0.06, 'square', 0.08); tone(1320, 0.1, 'square', 0.08, 0, 0.07); vib(20);
}
function momentTap(x, y) {
  const M = G.moment; if (!M || M.t < 0.35 || M.done) return;
  const hitObj = r => M.objs.find(o => o.live && M.t >= (o.d || 0) && Math.hypot(x - o.x, y - o.y) < (o.r || 34) + 26);
  if (M.id === 'pelota') { const o = M.objs[0]; if (!o.got && Math.hypot(x - o.x, y - o.y) < 80) { o.got = 1; burst(o.x, o.y, '#ffd35a', 20); SFX.good(); apply([2, 0, 5, 0]); float('¡La cogiste!', PX, GY - 250, '#6c9a3c'); M.res = 1; } }
  else if (M.id === 'monedas' || M.id === 'corazones') {
    const o = hitObj(); if (o) { o.live = 0; M.got++; const coin = M.id === 'monedas'; burst(o.x, o.y, coin ? '#e9b43a' : '#e2574c', 14); SFX.pick(coin ? 1 : 3); apply(coin ? [0, 3, 0, 0] : [0, 0, 1, 3]); }
  } else if (M.id === 'ritmo') {
    const b = M.objs.find(o => !o.hit && Math.abs(M.t - o.t) < 0.45);
    if (b) { const d = Math.abs(M.t - b.t); b.hit = d < 0.13 ? 2 : d < 0.25 ? 1 : -1;
      if (b.hit > 0) { M.got += b.hit; burst(W / 2, SY + 300, '#e2574c', b.hit * 10); SFX.pick(3); float(b.hit === 2 ? '¡Perfecto!' : '¡Bien!', W / 2, SY + 180, '#e0673c'); }
      else { SFX.bad(); float('Pisotón', W / 2, SY + 180, '#8c6a4a'); } }
  } else if (M.id === 'informe') { M.got++; tone(500 + M.got * 30, 0.04, 'square', 0.06); dust(rand(200, 340), SY + 420, 2); if (M.got >= M.n) endMoment(1); }
  else if (M.id === 'equilibrio' || M.id === 'bebe') M.v += (x < W / 2 ? -1 : 1) * 0.55;
}
function endMoment(ok) {
  const M = G.moment; if (!M || M.done) return; M.done = 1; M.endT = 0.7;
  if (M.id === 'pelota' && !M.res) { float('Se te escapa', PX, GY - 250, '#8c6a4a'); apply([0, 0, -3, 0]); }
  if (M.id === 'monedas' || M.id === 'corazones') { if (M.got === M.objs.length) { float('¡Perfecto!', W / 2, SY + 170, '#6c9a3c', 38); SFX.good(); apply(M.id === 'monedas' ? [0, 5, 2, 0] : [0, 0, 3, 3]); } }
  if (M.id === 'ritmo') { if (M.got >= 6) { float('¡Bailas de maravilla!', W / 2, SY + 170, '#6c9a3c', 34); apply([0, 0, 6, 8]); SFX.good(); } else if (M.got <= 2) { float('Pisas a todo el mundo', W / 2, SY + 170, '#8c6a4a', 30); apply([0, 0, -3, -3]); } }
  if (M.id === 'informe') { if (ok) { float('¡Entregado a tiempo!', W / 2, SY + 170, '#6c9a3c', 34); apply([0, 10, -2, 0]); SFX.good(); } else { float('Llega tarde. Otra vez.', W / 2, SY + 170, '#8c6a4a', 30); apply([0, -4, -4, 0]); SFX.bad(); } }
  if (M.id === 'equilibrio' || M.id === 'bebe') {
    const baby = M.id === 'bebe';
    if (ok) { float(baby ? '¡Se ha dormido!' : '¡Equilibrio perfecto!', W / 2, SY + 170, '#6c9a3c', 34); apply(baby ? [0, 0, 5, 8] : [6, 0, 2, 0]); SFX.good(); }
    else { float(baby ? 'Llora aún más fuerte' : '¡Te caes de culo!', W / 2, SY + 170, '#e2574c', 32); apply(baby ? [-2, 0, -4, -2] : [-8, 0, -3, 0], 'una caída tonta'); shake(10, 0.3); SFX.hit(); G.p.stumble = 0.7; }
  }
}
function updateMoment(dt) {
  const M = G.moment; M.t += dt;
  if (M.done) { M.endT -= dt; if (M.endT <= 0) G.moment = null; return; }
  if (M.id === 'pelota') { const o = M.objs[0]; if (!o.got) { o.x += o.vx * dt; o.vy += 220 * dt; o.y += o.vy * dt; o.rot = (o.rot || 0) - dt * 6; if (o.x < -40 || o.y > SB) endMoment(0); } else { o.x = lerp(o.x, PX + 34, 0.3); o.y = lerp(o.y, GY - curH() * 0.55, 0.3); if (M.t > M.dur) endMoment(1); } }
  else if (M.id === 'monedas' || M.id === 'corazones') {
    const coin = M.id === 'monedas';
    for (const o of M.objs) { if (!o.live || M.t < o.d) continue; if (coin) { o.vy += 900 * dt; o.y += o.vy * dt; if (o.y > SB + 40 && o.vy > 0) o.live = 0; } else { o.y -= 200 * dt; o.x += Math.sin(M.t * 3 + o.d * 5) * 40 * dt; if (o.y < SY - 30) o.live = 0; } }
    if (M.t > 0.5 && M.objs.every(o => !o.live)) endMoment(1);
  } else if (M.id === 'ritmo') { for (const b of M.objs) if (!b.hit && M.t - b.t > 0.45) { b.hit = -1; } if (M.t > M.dur) endMoment(1); }
  else if (M.id === 'informe') { if (M.t > M.dur) endMoment(0); }
  else if (M.id === 'equilibrio' || M.id === 'bebe') {
    let push = 0; if (keys.ArrowLeft) push = -1; if (keys.ArrowRight) push = 1;
    M.v += (M.x * 2.4 * M.k + rand(-2.6, 2.6) * M.k + push * 4) * dt; M.v *= 0.985; M.x += M.v * dt;
    if (Math.abs(M.x) >= 1) endMoment(0); else if (M.t > M.dur) endMoment(1);
  }
}

// ---------------- Runner ----------------
const curStage = () => L.stages[G.stage];
function curH() { const a = G.age; return a < 13 ? 118 + a * 4.2 : a < 20 ? 188 : a < 45 ? 206 : a < 65 ? 200 : 186; }
function spriteKey() { const s = curStage().sprite; return META[s] ? s : (G.stage <= 1 ? 'ramon0' : 'ramon2'); }
function jump() {
  const P = G.p, st = curStage();
  if (P.ground) { P.vy = -st.jump; P.ground = false; P.jumps = 1; SFX.jump(); dust(PX, GY, 5); vib(8); }
  else if (st.dbl && P.jumps < 2) { P.vy = -st.jump * 0.82; P.jumps = 2; SFX.jump2(); burst(PX, P.y, '#fff', 8, 120); }
}
function spawn() {
  const sp = L.spawn[G.stage], x = W + 80, r = Math.random();
  const addHaz = (id, dx = 0) => { const h = L.hazards[id]; G.ents.push({ k: 'haz', id, x: x + dx, y: h.air ? GY - rand(215, 260) : GY, w: h.w, h: h.h, air: h.air, bob: rand(0, 6) }); };
  const addPick = (id, dx, y) => G.ents.push({ k: 'pick', id, x: x + dx, y, s: 50, bob: rand(0, 6) });
  if (r < 0.45) { const id = wpick(sp.haz); addHaz(id); if (!L.hazards[id].air && Math.random() < 0.6) for (let i = -1; i <= 1; i++) addPick(wpick(sp.pick), i * 55, GY - 190 + Math.abs(i) * 30); }
  else if (r < 0.62) { const id = wpick(sp.pick); for (let i = 0; i < 3; i++) addPick(id, i * 62, GY - 45); }
  else if (r < 0.78) { addPick(wpick(sp.pick), 0, GY - rand(190, 300)); if (Math.random() < 0.5) addHaz(wpick(sp.haz), 170); }
  else { const hz = Object.keys(sp.haz).filter(k => L.hazards[k].air); if (hz.length) { addHaz(pick(hz)); addPick(wpick(sp.pick), 0, GY - 45); } else addHaz(wpick(sp.haz)); }
  const sc = G.age > 70 ? 1.2 : 1;
  G.spawnT = rand(sp.gap[0], sp.gap[1]) * sc;
}
function updateRunner(dt) {
  const P = G.p, st = curStage(), h = curH();
  const speed = st.speed * G.speedMul;
  G.speedMul = lerp(G.speedMul, P.stumble > 0 ? 0.55 : 1, 0.06);
  G.dist += speed * dt;
  P.frame += dt * 13 * (speed / 220);
  // física
  if (!P.ground) {
    P.vy += 2700 * dt; P.y += P.vy * dt;
    if (P.y >= GY) { P.y = GY; P.vy = 0; P.ground = true; P.jumps = 0; P.land = 0.15; dust(PX, GY, 6); SFX.land(); }
  }
  if (P.land > 0) P.land -= dt; if (P.stumble > 0) P.stumble -= dt; if (P.inv > 0) P.inv -= dt;
  if (P.ground && Math.floor(P.frame) % 8 === 0 && Math.random() < 0.3) dust(PX - 12, GY, 1);
  // entidades
  G.spawnT -= dt; if (G.spawnT <= 0 && !G.dead) spawn();
  for (const e of G.ents) e.x -= speed * dt * (e.air ? 1.25 : 1);
  G.ents = G.ents.filter(e => e.x > -120 && !e.gone);
  const top = P.y - h * 0.86, bot = P.y - 6;
  for (const e of G.ents) {
    if (e.k === 'pick') {
      if (Math.abs(e.x - PX) < 42 && e.y > top - 20 && e.y < bot + 10) {
        e.gone = 1; const pk = L.pickups[e.id]; apply(pk.fx, null, true); G.picked++; G.score += 3;
        const main = pk.fx.reduce((b, v, i) => v > pk.fx[b] ? i : b, 0);
        burst(e.x, e.y, COLS[main], 12, 200); pk.treat ? SFX.treat() : SFX.pick(main);
        float(`+${pk.fx[main]}`, e.x, e.y - 30, COLS[main], 28);
        if (pk.treat) float(`${pk.fx[0]}`, e.x + 30, e.y - 5, COLS[0], 22);
      }
    } else if (P.inv <= 0) {
      const hw = e.w * 0.32, htop = e.air ? e.y - e.h * 0.35 : e.y - e.h * 0.8, hbot = e.air ? e.y + e.h * 0.35 : e.y;
      if (Math.abs(e.x - PX) < hw + 16 && bot > htop && top < hbot) {
        const hz = L.hazards[e.id]; apply(hz.fx, hz.msg.toLowerCase().replace(/[¡!]/g, '')); G.hits++;
        P.stumble = 0.6; P.inv = 1.3; shake(9, 0.25); SFX.hit(); vib(40); burst(PX + 20, P.y - h * 0.5, '#fff', 10, 180);
        float(hz.msg, PX, P.y - h - 20, '#e2574c', 30); e.hitT = 0.5;
      }
    }
  }
  // seguidores: saltan al pasar un obstáculo
  for (const f of G.followers) {
    f.x = lerp(f.x, f.leave ? -140 : f.tx, dt * 1.5); f.frame += dt * 13 * (speed / 220);
    if (f.y >= GY && G.ents.some(e => e.k === 'haz' && !e.air && e.x > f.x && e.x - f.x < 70)) f.vy = -760;
    if (f.vy || f.y < GY) { f.vy += 2700 * dt; f.y += f.vy * dt; if (f.y >= GY) { f.y = GY; f.vy = 0; } }
  }
  G.followers = G.followers.filter(f => !(f.leave && f.x < -120));
}

// ---------------- Bucle ----------------
const keys = {};
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (mode === 'play' && !paused) update(dt);
  fx(dt); draw(); requestAnimationFrame(frame);
}
function fx(dt) {
  for (const p of parts) { p.x += p.vx * dt; p.y += p.vy * dt; p.vy += p.g * dt; p.life -= dt; if (p.puff) p.r += dt * 14; }
  parts = parts.filter(p => p.life > 0);
  for (const f of floats) { f.y -= 55 * dt; f.life -= dt * 0.85; }
  floats = floats.filter(f => f.life > 0);
  if (shakeT > 0) shakeT -= dt; else shakeA = 0;
}
function update(dt) {
  for (let i = 0; i < 4; i++) { G.flash[i] = Math.max(0, G.flash[i] - dt * 2); G.shown[i] = lerp(G.shown[i], G.st[i], Math.min(1, dt * 6)); }
  G.fade = Math.min(1, G.fade + dt / 1.4);
  if (G.stageBanner > 0) G.stageBanner -= dt;
  if (G.banners.length) { G.banners[0].time += dt; if (G.banners[0].time > 3.2) G.banners.shift(); }
  if (G.dead) {
    G.deathT += dt; G.speedMul = lerp(G.speedMul, 0, 0.04);
    updateRunner(dt * clamp(1 - G.deathT, 0, 1));
    if (G.deathT > 3.2 && !G.endShown) { G.endShown = 1; showEnd(); }
    return;
  }
  if (G.card) {
    G.card.t += dt; $('card-timer').style.transform = `scaleX(${1 - G.card.t / G.card.dur})`;
    if (G.card.t > G.card.dur) choose(randi(0, G.card.e.o.length - 1), true);
    return;
  }
  if (G.moment) { updateMoment(dt); return; }
  updateRunner(dt);
  G.yt += dt / yearDur(G.age);
  if (G.yt >= 1) { G.yt -= 1; yearTick(); }
}

// ---------------- Dibujo ----------------
function drawBg(key, alpha) {
  const im = IMG[key]; if (!im) return;
  const s = SH / im.height, w = im.width * s, off = (G.dist * 1) % w;
  ctx.save(); ctx.globalAlpha = alpha;
  for (let x = -off; x < W; x += w) ctx.drawImage(im, x, SY, w + 1, SH);
  ctx.restore();
}
function draw() {
  ctx.save();
  ctx.fillStyle = '#2b1d14'; ctx.fillRect(0, 0, W, H);
  if (mode === 'menu' || mode === 'loading') { drawMenu(); ctx.restore(); return; }
  if (shakeA) ctx.translate(rand(-shakeA, shakeA), rand(-shakeA, shakeA));
  // escena
  ctx.save(); ctx.beginPath(); ctx.rect(0, SY, W, SH); ctx.clip();
  if (G.fade < 1) drawBg(L.stages[G.prevStage].bg, 1);
  drawBg(curStage().bg, G.fade);
  const P = G.p, h = curH(), t = performance.now() / 1000;
  // entidades
  for (const e of G.ents) {
    if (e.k === 'haz') {
      if (!e.air) shadow(e.x, GY + 2, e.w * 0.45);
      const wob = e.air ? Math.sin(t * 8 + e.bob) * 6 : 0, hit = e.hitT > 0 ? (e.hitT -= 1 / 60) : 0;
      item(e.id, e.x, e.air ? e.y + wob : e.y - e.h / 2, e.h * (e.air ? 1 : 1.05), { rot: hit ? Math.sin(t * 40) * 0.2 : 0 });
    } else {
      const bob = Math.sin(t * 4 + e.bob) * 5;
      if (e.y > GY - 60) shadow(e.x, GY + 2, 18);
      item(e.id, e.x, e.y + bob, e.s, { sx: 1 + Math.sin(t * 6 + e.bob) * 0.04 });
    }
  }
  // familia detrás
  for (const f of G.followers) { shadow(f.x, GY + 2, f.id === 'perro' ? 26 : 30); sprite(f.key, f.frame, f.x, f.y, f.h); }
  // Ramón
  drawRamon(P, h, t);
  // partículas
  for (const p of parts) { ctx.globalAlpha = clamp(p.life / 0.4, 0, 1); ctx.fillStyle = p.col; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, TAU); ctx.fill(); }
  ctx.globalAlpha = 1;
  if (G.moment) drawMoment(t);
  if (G.card) { ctx.fillStyle = 'rgba(43,29,20,.35)'; ctx.fillRect(0, SY, W, SH); }
  if (G.dead) { ctx.fillStyle = `rgba(20,12,30,${clamp(G.deathT / 3, 0, 0.6)})`; ctx.fillRect(0, SY, W, SH); }
  drawBanners();
  ctx.restore();
  for (const f of floats) text(f.s, f.x, f.y, { size: f.size, color: f.col, stroke: '#fff8ec', sw: 6, alpha: clamp(f.life, 0, 1), font: "'Chewy', cursive" });
  drawHud(t);
  ctx.restore();
}
function drawRamon(P, h, t) {
  const key = spriteKey();
  let rot = 0, sx = 1, sy = 1, alpha = 1, y = P.y, frame = P.frame, x = PX;
  if (!P.ground) { frame = 4; rot = clamp(P.vy / 3000, -0.15, 0.2); sx = 0.95; sy = 1.06; }
  if (P.land > 0) { sx = 1.1; sy = 0.9; }
  if (P.stumble > 0) { rot = Math.sin(P.stumble * 18) * 0.12 + 0.18; }
  if (P.inv > 0 && Math.floor(t * 14) % 2) alpha = 0.55;
  if (G.card || (G.moment && !['equilibrio', 'bebe'].includes(G.moment.id))) { frame = 0; sy = 1 + Math.sin(t * 3) * 0.012; }
  if (G.moment && ['equilibrio', 'bebe'].includes(G.moment.id)) { frame = 0; rot = G.moment.x * 0.7; }
  if (G.dead) {
    const d = G.deathT; frame = 0; alpha = clamp(1 - d / 2.4, 0, 1);
    sprite(key, frame, x, y, h, { alpha: clamp(d / 1.2, 0, 1) * 0.8 * clamp(3 - d, 0, 1), filter: 'brightness(2.2) saturate(0)' , sy: 1 });
    // alma que sube
    ctx.save(); ctx.globalAlpha = clamp(d / 1.2, 0, 1) * clamp(3.2 - d, 0, 1);
    sprite(key, 0, x, y - d * 70, h, { filter: 'brightness(2.5) saturate(0) opacity(.7)' });
    ctx.strokeStyle = '#ffd35a'; ctx.lineWidth = 5; ctx.beginPath(); ctx.ellipse(x + 8, y - d * 70 - h * 1.02, 30, 9, 0, 0, TAU); ctx.stroke();
    ctx.restore();
  }
  shadow(x, GY + 2, 32 * (1 - clamp((GY - y) / 400, 0, 0.6)));
  if (!G.dead) sprite(key, frame, x, y, h, { rot, sx, sy, alpha });
  else sprite(key, 0, x, y, h, { alpha, rot: clamp(G.deathT, 0, 1) * -0.05 });
}
function drawBanners() {
  if (G.stageBanner > 0) {
    const a = clamp(G.stageBanner, 0, 1) * clamp((2.6 - G.stageBanner) * 3, 0, 1), y = SY + 200;
    paperBox(70, y - 55, 400, 110, a);
    text('NUEVA ETAPA', W / 2, y - 22, { size: 22, color: '#e0673c', alpha: a, font: "'Chewy', cursive" });
    text(curStage().name, W / 2, y + 16, { size: 50, alpha: a, font: "'Chewy', cursive" });
  }
  const b = G.banners[0]; if (!b || G.card) return;
  const a = clamp(b.time * 4, 0, 1) * clamp((3.2 - b.time) * 3, 0, 1);
  const lines = wrapLines(b.t, 440, 28), hh = 30 + lines.length * 32 + (b.head ? 26 : 0), y = SY + 24;
  ctx.save(); ctx.translate(0, (1 - a) * -30);
  paperBox(34, y, 472, hh, a);
  let yy = y + 26;
  if (b.head) { text(b.head, W / 2, yy, { size: 20, color: b.col, alpha: a, font: "'Chewy', cursive" }); yy += 28; }
  lines.forEach((l, i) => text(l, W / 2, yy + i * 32, { size: 28, alpha: a }));
  ctx.restore();
}
function drawMoment(t) {
  const M = G.moment, a = clamp(M.t * 4, 0, 1) * (M.done ? clamp(M.endT / 0.3, 0, 1) : 1);
  ctx.fillStyle = `rgba(43,29,20,${0.25 * a})`; ctx.fillRect(0, SY, W, SH);
  text(M.title, W / 2, SY + 60, { size: 42, color: '#fff8ec', stroke: '#3b2416', sw: 8, alpha: a, font: "'Chewy', cursive" });
  if (M.t < 1.6 && !M.done) text(M.hint, W / 2, SY + 104, { size: 26, color: '#fff8ec', stroke: '#3b2416', sw: 6, alpha: a * clamp(1.6 - M.t, 0, 1) });
  // barra de tiempo
  if (!M.done) { rrect(120, SY + 128, 300, 12, 6, '#fff8ec', '#3b2416', 2); rrect(120, SY + 128, 300 * clamp(1 - M.t / M.dur, 0, 1), 12, 6, '#e0673c'); }
  if (M.id === 'pelota') { const o = M.objs[0]; item('ball', o.x, o.y, 64, { rot: o.rot }); }
  if (M.id === 'monedas' || M.id === 'corazones') for (const o of M.objs) if (o.live && M.t >= o.d) item(M.id === 'monedas' ? 'coin' : 'heart', o.x, o.y, 72, { rot: Math.sin(t * 5 + o.d) * 0.2 });
  if (M.id === 'ritmo') {
    const cx = W / 2, cy = SY + 300, next = M.objs.find(b => !b.hit);
    item('heart', cx, cy, 90 + Math.sin(t * 10) * 4);
    if (next) { const k = clamp((next.t - M.t) / 0.9, 0, 1), r = 48 + k * 150; ctx.strokeStyle = '#e0673c'; ctx.lineWidth = 8; ctx.globalAlpha = 1 - k * 0.6; ctx.beginPath(); ctx.arc(cx, cy, r, 0, TAU); ctx.stroke(); ctx.globalAlpha = 1; }
    ctx.strokeStyle = 'rgba(255,248,236,.7)'; ctx.lineWidth = 3; ctx.setLineDash([8, 8]); ctx.beginPath(); ctx.arc(cx, cy, 48, 0, TAU); ctx.stroke(); ctx.setLineDash([]);
    M.objs.forEach((b, i) => item('heart', cx - 75 + i * 50, cy + 130, 32, { alpha: b.hit > 0 ? 1 : b.hit < 0 ? 0.2 : 0.45 }));
  }
  if (M.id === 'informe') {
    const k = M.got / M.n;
    for (let i = 0; i < Math.min(M.got, M.n); i++) item('bills', W / 2 + Math.sin(i * 7) * 8, SY + 470 - i * 9, 60, { rot: Math.sin(i * 3) * 0.1 });
    rrect(110, SY + 520, 320, 26, 12, '#fff8ec', '#3b2416', 3); rrect(110, SY + 520, 320 * k, 26, 12, '#e9b43a');
    text(`${M.got}/${M.n}`, W / 2, SY + 533, { size: 22 });
  }
  if (M.id === 'equilibrio' || M.id === 'bebe') {
    const x0 = 120, x1 = 420, y = SY + 170;
    rrect(x0, y, x1 - x0, 20, 10, '#fff8ec', '#3b2416', 3);
    ctx.fillStyle = 'rgba(140,193,82,.6)'; ctx.fillRect(W / 2 - 60, y + 3, 120, 14);
    ctx.fillStyle = '#e0673c'; ctx.beginPath(); ctx.arc(W / 2 + M.x * 150, y + 10, 14, 0, TAU); ctx.fill(); ctx.stroke();
    text('◀', 60, SY + 400, { size: 60, color: 'rgba(255,248,236,.6)' }); text('▶', W - 60, SY + 400, { size: 60, color: 'rgba(255,248,236,.6)' });
    if (M.id === 'bebe') { text('zZz', PX + 60, GY - curH() - 20 + Math.sin(t * 3) * 6, { size: 30, color: '#fff8ec', stroke: '#3b2416', sw: 5 }); }
  }
}
function drawHud(t) {
  // barra superior
  ctx.fillStyle = '#2b1d14'; ctx.fillRect(0, 0, W, SY);
  text('RAMÓN', 22, 30, { size: 22, color: '#e8c9a0', align: 'left', font: "'Chewy', cursive" });
  text(`${G.age} ${G.age === 1 ? 'año' : 'años'}`, 22, 66, { size: 40, color: '#fff8ec', align: 'left', font: "'Chewy', cursive" });
  text(curStage().name, 175, 30, { size: 22, color: '#e8c9a0', align: 'left', font: "'Chewy', cursive" });
  text(`${Math.round(G.score)} pts`, 452, 30, { size: 26, color: '#ffd35a', align: 'right', font: "'Chewy', cursive" });
  // regla de la vida
  const rx = 175, rw = 280, ry = 62;
  L.stages.forEach((s, i) => { const a = s.from, b = (L.stages[i + 1] || { from: 100 }).from; rrect(rx + rw * a / 100, ry, rw * (b - a) / 100, 10, 0, ['#8fd3ff', '#ff9eb3', '#7d8fc0', '#c79ae0', '#f0a45a'][i]); });
  rrect(rx, ry, rw, 10, 5, null, '#fff8ec', 2);
  const px = rx + rw * clamp((G.age + G.yt) / 100, 0, 1);
  ctx.fillStyle = '#fff8ec'; ctx.beginPath(); ctx.moveTo(px, ry - 2); ctx.lineTo(px - 7, ry - 12); ctx.lineTo(px + 7, ry - 12); ctx.fill();
  // panel inferior
  ctx.fillStyle = '#3b2416'; ctx.fillRect(0, SB, W, H - SB);
  ctx.fillStyle = '#4a2f1d'; ctx.fillRect(0, SB, W, 6);
  for (let i = 0; i < 4; i++) {
    const y = SB + 50 + i * 42, v = G.shown[i], fl = G.flash[i];
    item(ICON[i], 40, y, 36 + fl * 10);
    text(L.stats[i], 70, y, { size: 24, color: '#f4e2c4', align: 'left' });
    rrect(190, y - 12, 270, 24, 12, '#2b1d14', '#f4e2c4', 2);
    if (v > 0.5) rrect(192, y - 10, 266 * v / 100, 20, 10, COLS[i]);
    if (v < 20 && Math.floor(t * 4) % 2) rrect(190, y - 12, 270, 24, 12, null, '#e2574c', 3);
    text(String(Math.round(v)), 476, y, { size: 24, color: '#fff8ec', align: 'left', font: "'Chewy', cursive" });
  }
}
function drawMenu() {
  const im = IMG.title;
  if (im) { const s = Math.max(W / im.width, H / im.height); ctx.drawImage(im, (W - im.width * s) / 2, (H - im.height * s) / 2, im.width * s, im.height * s); }
  ctx.fillStyle = 'rgba(43,29,20,.18)'; ctx.fillRect(0, 0, W, H);
}

// ---------------- Pantalla final ----------------
function epitaph() {
  const s = G.st, a = G.age;
  const best = [[2, 'Fue feliz, que no es poco.'], [1, 'Tenía mucho dinero. Ahora lo tiene otro.'], [3, 'Nunca comió solo.'], [0, 'Murió sanísimo, curiosamente.']].sort((x, y) => s[y[0]] - s[x[0]])[0][1];
  let low;
  if (s[2] < 25) low = 'No sonreía ni en las fotos.';
  else if (s[3] < 25) low = G.flags.planta ? 'A su entierro fue su planta.' : 'A su entierro fueron cuatro, pero puntuales.';
  else if (s[1] < 12) low = 'Debe tres euros a medio barrio.';
  else if (a < 40) low = 'Se fue demasiado pronto, con la tele encendida.';
  else if (G.flags.hija) low = 'Alba aún guarda su jersey feo.';
  else if (G.flags.perro) low = 'Tornillo sigue esperándole en la puerta.';
  else if (G.partner && G.flags.pareja) low = tr('{p} dice que roncaba, y que lo echa de menos.');
  else low = 'Hizo lo que pudo con lo que le tocó.';
  return `«Aquí yace Ramón. ${best} ${low}»`;
}
function showEnd() {
  const s = G.st, score = Math.round(G.score + G.age * 2), rec = score > save.best;
  save.best = Math.max(save.best, score); save.lives++;
  save.history = [{ age: G.age, score }, ...(save.history || [])].slice(0, 10); persist();
  $('end-name').textContent = `Ramón (0 – ${G.age})`;
  $('end-epitaph').textContent = epitaph();
  $('end-cause').textContent = `Murió a los ${G.age} años, ${G.cause}.`;
  const tags = G.tags.length > 5 ? [0, 1, 2, 3, 4].map(i => G.tags[Math.round(i * (G.tags.length - 1) / 4)]) : G.tags;
  $('end-moments').innerHTML = tags.length ? tags.map(t => `<li>A los ${t.a}, ${t.t}.</li>`).join('') : '<li>No tomó ninguna decisión memorable.</li>';
  $('end-stats').textContent = `Salud ${Math.round(s[0])} · Dinero ${Math.round(s[1])} · Felicidad ${Math.round(s[2])} · Relaciones ${Math.round(s[3])}`;
  $('end-score').textContent = `${score} pts`;
  $('end-record').innerHTML = (rec ? '<b>¡La mejor vida hasta ahora!</b> ' : '') + `Récord: ${save.best} · Vidas vividas: ${save.lives}`;
  $('end').classList.remove('hidden'); $('btn-pause').classList.add('hidden');
}

// ---------------- Pantallas y entrada ----------------
function toMenu() {
  mode = 'menu'; ['end', 'settings', 'card', 'loading'].forEach(i => $(i).classList.add('hidden'));
  $('menu').classList.remove('hidden'); $('btn-pause').classList.add('hidden');
  $('menu-best').textContent = save.best ? `Récord: ${save.best} pts · ${save.lives} vidas vividas` : 'Una vida entera en unos minutos.';
}
function play() {
  audio(); setMusic(true); newLife(); mode = 'play'; paused = false;
  ['menu', 'end', 'settings'].forEach(i => $(i).classList.add('hidden')); $('btn-pause').classList.remove('hidden');
  banner('', 'Toca para saltar. Recoge lo bueno, esquiva lo malo.', '#3b2416');
}
function openSettings() {
  $('set-music').checked = save.music; $('set-sfx').checked = save.sfx; $('set-vib').checked = save.vib;
  $('settings').classList.remove('hidden');
  if (mode === 'play') paused = true;
}
$('btn-play').onclick = play; $('btn-again').onclick = play; $('btn-menu').onclick = toMenu;
$('btn-settings').onclick = openSettings; $('btn-pause').onclick = e => { e.stopPropagation(); openSettings(); };
$('btn-close').onclick = () => { $('settings').classList.add('hidden'); paused = false; last = performance.now(); };
$('set-music').onchange = e => { save.music = e.target.checked; persist(); setMusic(mode === 'play'); };
$('set-sfx').onchange = e => { save.sfx = e.target.checked; persist(); };
$('set-vib').onchange = e => { save.vib = e.target.checked; persist(); };
$('btn-reset').onclick = () => { save.best = 0; save.lives = 0; save.history = []; persist(); $('btn-reset').textContent = 'Borrado'; };
$('btn-pause').addEventListener('pointerdown', e => e.stopPropagation());

function toLocal(e) { const r = stage.getBoundingClientRect(); return { x: (e.clientX - r.left) / scale, y: (e.clientY - r.top) / scale }; }
stage.addEventListener('pointerdown', e => {
  if (mode !== 'play' || paused || !G || G.dead || G.card) return;
  if (e.target.closest('button')) return;
  const p = toLocal(e);
  if (G.moment) momentTap(p.x, p.y); else jump();
});
addEventListener('keydown', e => {
  keys[e.key] = true;
  if (mode !== 'play' || paused || !G || G.dead) return;
  if (G.card) { const n = +e.key; if (n >= 1 && n <= G.card.e.o.length) choose(n - 1); return; }
  if (e.key === ' ' || e.key === 'ArrowUp') { e.preventDefault(); if (G.moment) momentTap(W / 2, SY + 300); else jump(); }
});
addEventListener('keyup', e => { keys[e.key] = false; });
document.addEventListener('visibilitychange', () => { if (document.hidden && mode === 'play') { paused = true; if (musicEl) musicEl.pause(); openSettings(); } });

// Depuración: ?age=40 empieza a esa edad; ?fast=3 acelera el tiempo
const Q = new URLSearchParams(location.search);
window.__vida = { get G() { return G; }, play, jump, choose, startMoment };

loadAll().then(() => {
  toMenu();
  if (Q.get('auto')) { play(); if (Q.get('age')) { G.age = +Q.get('age'); G.stage = G.prevStage = stageOf(G.age); } }
});
requestAnimationFrame(frame);
})();
