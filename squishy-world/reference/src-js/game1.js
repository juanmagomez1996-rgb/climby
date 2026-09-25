'use strict';
/* =====================================================================
   SQUISHY WORLD PROTOTYPE
   Single-file three.js (r147 UMD) prototype.
   Assets (CC0): Kenney Blocky Characters 2.0, Kenney Nature Kit, Kenney Interface Sounds.
   DEBUG keys (only when CONFIG.DEBUG): K = +1000 coins, L = force legendary next fill,
   R = reset save (asks first). Not shown on the HUD.
   ===================================================================== */

// ------------------------------------------------------------ CONFIG
const CONFIG = {
  DEBUG: true,
  SAVE_KEY: 'squishyWorldSave',
  START: { coins: 500, level: 1, storage: 20 },
  PLAYER: { scale: 2, walk: 13, run: 22, radius: 1.3, turn: 12 },
  CAM: { dist: 14, min: 7, max: 24, lookH: 5.2, pitch: 0.28, pitchMin: -0.25, pitchMax: 1.05, sens: 0.0026, keyTurn: 2.2 },
  WORLD: { radius: 92 },
  FILL: { baseTime: 3.2, perfect: [0.8, 0.9], over: 1.0, pop: 1.16, minCommit: 0.35, process: 2.1 },
  INTERACT_DIST: 9,
  COMPANION: { offset: 3.2, lerp: 5 },
  NPC_BUBBLE_EVERY: [7, 15],
  AI_TIER: 'quick',
};

// ------------------------------------------------------------ DATA
const RARITIES = [
  { id: 'common',    name: 'Común',      p: 0.65,  mult: 1,   color: '#A9ADB8', xp: 5 },
  { id: 'uncommon',  name: 'Poco común', p: 0.22,  mult: 2.5, color: '#5CC46C', xp: 10 },
  { id: 'rare',      name: 'Raro',       p: 0.08,  mult: 7.5, color: '#4C9BFF', xp: 25 },
  { id: 'epic',      name: 'Épico',      p: 0.035, mult: 25,  color: '#A95CFF', xp: 80 },
  { id: 'legendary', name: 'Legendario', p: 0.014, mult: 125, color: '#FFC83A', xp: 250 },
  { id: 'secret',    name: 'Secreto',    p: 0.001, mult: 750, color: '#FF4F86', xp: 1000 },
];
const R = Object.fromEntries(RARITIES.map((r, i) => [r.id, Object.assign(r, { tier: i })]));
const LUCK_TIER_BOOST = [0, 0.5, 1, 1.5, 2, 2.5];

const SPECIES = [
  { id: 'cat',   name: 'Gato',   baseValue: 20, unlockLevel: 1 },
  { id: 'bear',  name: 'Oso',    baseValue: 22, unlockLevel: 1 },
  { id: 'frog',  name: 'Rana',   baseValue: 30, unlockLevel: 3 },
  { id: 'bunny', name: 'Conejo', baseValue: 40, unlockLevel: 5 },
  { id: 'blob',  name: 'Blob',   baseValue: 50, unlockLevel: 8 },
];
// Squishies virales (moldes famosos). Se compran en la Tienda; la Mantequilla viene gratis.
// rise = segundos que tarda en volver a su forma (slow rising), soft = qué tan hondo se hunde.
const FAMOUS = [
  { id: 'butter',     name: 'Barra de Mantequilla',    baseValue: 45, price: 0,    rise: 7.5, soft: 1.15, orig: { c: '#FFE38F', r: 0.42 }, desc: 'La reina de TikTok. Sube lentíiisimo.' },
  { id: 'toast',      name: 'Tostada con Mantequilla', baseValue: 40, price: 600,  rise: 4.5, soft: 1.0,  orig: { c: '#FFFFFF', r: 0.8 },  desc: 'Pan tostadito con su cuadrito de mantequilla.' },
  { id: 'cheese',     name: 'Queso Suizo',             baseValue: 45, price: 900,  rise: 5,   soft: 1.05, orig: { c: '#FFCF3F', r: 0.55 }, desc: 'Con huequitos de verdad.' },
  { id: 'strawberry', name: 'Fresa Jumbo',             baseValue: 40, price: 800,  rise: 4,   soft: 1.0,  orig: { tex: 'strawberry', r: 0.5 },  desc: 'Jumbo, con semillitas.' },
  { id: 'icecube',    name: 'Cubo de Hielo',           baseValue: 35, price: 700,  rise: 1.8, soft: 0.75, orig: { c: '#BFF0FF', r: 0.06, opacity: 0.72 }, desc: 'Gel transparente, rebota rápido.' },
  { id: 'egg',        name: 'Huevo Frito',             baseValue: 40, price: 1000, rise: 3.5, soft: 1.05, orig: { c: '#FFFFFF', r: 0.35 }, desc: 'La yema se hunde deliciosa.' },
  { id: 'dumpling',   name: 'Dumpling al Vapor',       baseValue: 50, price: 1200, rise: 5,   soft: 1.25, orig: { c: '#FBF3E4', r: 0.5 },  desc: 'Viene en su vaporera de bambú.' },
  { id: 'dango',      name: 'Dango',                   baseValue: 45, price: 1400, rise: 4,   soft: 1.1,  orig: { c: '#FFFFFF', r: 0.55 }, desc: 'Tres bolitas de mochi en palito.' },
  { id: 'frogwell',   name: 'Rana en el Pozo',         baseValue: 55, price: 1500, rise: 3.5, soft: 1.1,  orig: { c: '#8FD47A', r: 0.5 },  desc: 'La ranita que se asoma del pozo.' },
  { id: 'donut',      name: 'Dona Glaseada',           baseValue: 50, price: 1600, rise: 4,   soft: 1.0,  orig: { c: '#FF8FC0', r: 0.3 },  desc: 'Glaseado rosado y chispitas.' },
  { id: 'grapes',     name: 'Uvas Jumbo',              baseValue: 50, price: 1800, rise: 3,   soft: 0.95, orig: { c: '#9C6ADE', r: 0.28 }, desc: 'Un racimo entero para apachurrar.' },
  { id: 'burger',     name: 'Hamburguesa',             baseValue: 60, price: 2000, rise: 4.5, soft: 1.05, orig: { tex: 'sesame', r: 0.55 }, desc: 'Pan, carne, queso y lechuga.' },
  { id: 'catpaw',     name: 'Pata de Gato',            baseValue: 70, price: 2500, rise: 6,   soft: 1.4,  orig: { c: '#FFF7F3', r: 0.7 },  desc: 'La taba squishy: suavecita y con almohadillas.' },
];
for (const f of FAMOUS) SPECIES.push(Object.assign({ famous: true, unlockLevel: 1 }, f));
const SP = Object.fromEntries(SPECIES.map(s => [s.id, s]));

// Visual look of each variant. c=color, r=roughness, m=metalness, tex=procedural texture, e=emissive strength
const VARIANTS = {
  common: [
    { id: 'classic', name: 'Crema', c: '#F3E3CC' }, { id: 'pink', name: 'Rosa', c: '#F7A7CD' },
    { id: 'blue', name: 'Azul', c: '#8BC7E8' }, { id: 'yellow', name: 'Limón', c: '#F4D982' },
    { id: 'green', name: 'Verde', c: '#A6DB8E' }, { id: 'purple', name: 'Lila', c: '#B999E8' },
    { id: 'orange', name: 'Naranja', c: '#F8B27C' }, { id: 'white', name: 'Nieve', c: '#F8F6F2' },
  ],
  uncommon: [
    { id: 'mint', name: 'Menta', c: '#9CE0CA', accent: '#fff' }, { id: 'chocolate', name: 'Chocolate', c: '#8A5A44', tex: 'drizzle' },
    { id: 'bubblegum', name: 'Chicle', c: '#FF8FC8', r: 0.38 }, { id: 'cotton_candy', name: 'Algodón de Azúcar', tex: 'cotton' },
    { id: 'lavender', name: 'Lavanda', c: '#CDB8F2' },
  ],
  rare: [
    { id: 'strawberry', name: 'Fresa', c: '#FF6F91', tex: 'seeds', topper: 'leaf' },
    { id: 'watermelon', name: 'Sandía', tex: 'melon' },
    { id: 'cloud', name: 'Nube', c: '#FFFFFF', r: 0.95, extra: 'puffs' },
    { id: 'ice', name: 'Hielo', c: '#BDEBFF', r: 0.12, opacity: 0.86 },
    { id: 'honey', name: 'Miel', c: '#F2B33D', r: 0.22, topper: 'drip' },
  ],
  epic: [
    { id: 'neon', name: 'Neón', c: '#39FF9A', e: 0.85, anim: 'neon' },
    { id: 'crystal', name: 'Cristal', c: '#A8E6FF', r: 0.04, m: 0.1, opacity: 0.74, flat: true },
    { id: 'galaxy', name: 'Galaxia', tex: 'galaxy', e: 0.55 },
    { id: 'lava', name: 'Lava', tex: 'lava', e: 1 },
  ],
  legendary: [
    { id: 'golden', name: 'Oro', c: '#FFC93C', m: 0.8, r: 0.26 },
    { id: 'rainbow', name: 'Arcoíris', tex: 'rainbow' },
    { id: 'celestial', name: 'Celestial', c: '#EEF5FF', tex: 'stars', e: 0.35, extra: 'halo' },
  ],
  secret: [
    { id: 'glitched', name: 'Glitch', tex: 'glitch', anim: 'glitch', e: 0.4 },
    { id: 'void', name: 'Vacío', c: '#15121f', r: 0.3, extra: 'aura' },
    { id: 'developer', name: 'Dev', tex: 'checker', e: 0.15 },
  ],
};
const VAR = {};
for (const [rar, list] of Object.entries(VARIANTS)) for (const v of list) VAR[v.id] = Object.assign(v, { rarity: rar });
// 'original' = el look clásico de cada squishy viral (solo para moldes famosos, rareza común)
VAR.original = { id: 'original', name: 'Original', rarity: 'common', famousOnly: true };
function variantsFor(spId) {
  const sp = SP[spId];
  if (sp && sp.famous) return ['original', ...['uncommon', 'rare', 'epic', 'legendary', 'secret'].flatMap(r => VARIANTS[r].map(v => v.id))];
  return Object.keys(VAR).filter(v => !VAR[v].famousOnly);
}

const MUTATIONS = [
  { id: 'normal', name: '', p: 0.9, mult: 1 },
  { id: 'shiny', name: 'Brillante', p: 0.04, mult: 2 },
  { id: 'big', name: 'Gigante', p: 0.03, mult: 1.5, size: 1.3 },
  { id: 'tiny', name: 'Mini', p: 0.03, mult: 1.3, size: 0.7 },
];
const MUT = Object.fromEntries(MUTATIONS.map(m => [m.id, m]));

// riseMul / softMul: cómo cambia la espuma (tiempo de slow rise y qué tan blandito es)
const FILLINGS = [
  { id: 'classic_foam', name: 'Espuma Clásica', color: '#F3E3CC', price: 0, riseMul: 1, softMul: 1, bias: ['classic', 'white', 'chocolate'] },
  { id: 'pink_foam', name: 'Espuma Rosa', color: '#F7A7CD', price: 0, riseMul: 1, softMul: 1, bias: ['pink', 'bubblegum', 'strawberry', 'cotton_candy', 'watermelon'] },
  { id: 'blue_foam', name: 'Espuma Azul', color: '#8BC7E8', price: 0, riseMul: 1, softMul: 1, bias: ['blue', 'ice', 'cloud', 'lavender'] },
  { id: 'beads', name: 'Bolitas', color: '#F8B27C', price: 750, luck: 0.05, riseMul: 0.45, softMul: 0.8, mut: { big: 2.5 }, desc: 'Rebotonas. Más squishies Gigantes.' },
  { id: 'glitter', name: 'Escarcha', color: '#E7C8FF', price: 1500, riseMul: 0.9, softMul: 1, mut: { shiny: 3 }, bias: ['crystal', 'celestial', 'purple'], desc: 'Triple probabilidad de Brillante.' },
  { id: 'cloud', name: 'Nube', color: '#FFFFFF', price: 2500, riseMul: 1.5, softMul: 1.35, bias: ['cloud', 'white', 'celestial', 'cotton_candy'], desc: 'Súper blandita. Variantes de nube y cielo.' },
  { id: 'honey', name: 'Miel', color: '#F2B33D', price: 3000, riseMul: 2.2, softMul: 1.1, bias: ['honey', 'yellow', 'golden', 'chocolate'], desc: 'El slow rise más lento. Miel y Oro.' },
  { id: 'neon', name: 'Neón', color: '#39FF9A', price: 4000, luck: 0.03, riseMul: 0.8, softMul: 0.9, bias: ['neon', 'green', 'lava'], desc: 'Brilla. Variantes Neón y Lava.' },
  { id: 'rainbow', name: 'Arcoíris', color: 'linear-gradient(90deg,#ff8fa3,#ffd36e,#8be3a5,#8bc7e8,#b999e8)', color3: '#ffd36e', price: 5000, luck: 0.05, riseMul: 1.2, softMul: 1.1, bias: ['rainbow', 'cotton_candy', 'mint'], desc: 'Variantes arcoíris + un poquito de suerte.' },
  { id: 'crystal', name: 'Cristal', color: '#A8E6FF', price: 6000, riseMul: 0.6, softMul: 0.8, mut: { shiny: 2 }, bias: ['crystal', 'ice'], desc: 'Transparente y brillante.' },
  { id: 'galaxy', name: 'Galaxia', color: '#3b2a78', price: 8000, luck: 0.08, riseMul: 1.4, softMul: 1.2, bias: ['galaxy', 'void', 'celestial'], desc: 'Cósmica. Galaxia y Vacío.' },
  { id: 'mystery', name: 'Misterio', color: '#282D3A', price: 1200, perUse: 100, luck: 0.3, secretX: 2, riseMul: 1.3, softMul: 1.1, mut: { shiny: 2, big: 2, tiny: 2 }, desc: 'Cuesta 100 por llenado. Resultados raros, mejores chances.' },
];
const FIL = Object.fromEntries(FILLINGS.map(f => [f.id, f]));

const MACHINES = [
  { id: 'm1', name: 'Máquina 01', sub: 'Llenadora Básica', level: 1, luck: 0, color: '#F7A7CD' },
  { id: 'm2', name: 'Máquina 02', sub: 'Llenadora Brillante', level: 5, luck: 0.15, color: '#8BC7E8' },
  { id: 'm3', name: 'Máquina 03', sub: 'Mega Llenadora', level: 10, luck: 0.3, mutX: 1.8, color: '#B999E8' },
];

const UPGRADES = {
  fillSpeed: { name: 'Velocidad', desc: 'Los squishies se llenan más rápido.', costs: [300, 700, 1500, 3000, 6000], max: 6 },
  luck:      { name: 'Suerte', desc: '+6% de probabilidad de rarezas altas por nivel.', costs: [400, 1000, 2500, 6000, 12000], max: 5, start: 0 },
  storage:   { name: 'Espacio', desc: 'Guarda más squishies.', costs: [500, 1200, 3000, 7000, 15000], caps: [20, 30, 50, 75, 100, 150], max: 6 },
};

const QUESTS = [
  { id: 'fill3', title: 'Llena 3 squishies', goal: 3, ev: 'fill', reward: 250, target: 'machines' },
  { id: 'unc', title: 'Descubre un squishy Poco común', goal: 1, ev: 'getUncommon', reward: 150, target: 'machines' },
  { id: 'dupe', title: 'Vende un repetido', goal: 1, ev: 'sellDupe', reward: 150, target: null },
  { id: 'speed', title: 'Mejora la Velocidad en la Tienda', goal: 1, ev: 'upFill', reward: 200, target: 'shop' },
  { id: 'perfect', title: 'Consigue 3 llenados Perfectos', goal: 3, ev: 'perfect', reward: 300, target: 'machines' },
  { id: 'lvl3', title: 'Llega a nivel 3 para desbloquear la Rana', goal: 3, ev: 'level', reward: 250, target: 'machines' },
  { id: 'rare', title: 'Descubre un squishy Raro', goal: 1, ev: 'getRare', reward: 500, target: 'machines' },
  { id: 'trade', title: 'Haz un intercambio en la Plaza', goal: 1, ev: 'trade', reward: 400, target: 'trading' },
  { id: 'idx15', title: 'Descubre 15 squishies en el Índice', goal: 15, ev: 'index', reward: 800, target: 'collection' },
  { id: 'epic', title: 'Descubre un squishy Épico', goal: 1, ev: 'getEpic', reward: 1500, target: 'machines' },
];

const NPC_DEFS = [
  { name: 'SquishyMaya', skin: 'e', home: 'trading', fav: 'bunny', famousFav: 'strawberry', persona: 'cheerful and bubbly, loves pastel colors and bunnies, always hypes other players up', lines: ['¿Cambiamos?', '¡Busco raros!', 'Solo squishies pastel 💕', '¿Alguien tiene un conejo?'] },
  { name: 'FrogKid22', skin: 'b', home: 'trading', fav: 'frog', famousFav: 'frogwell', persona: 'hyper-energetic frog superfan who turns every topic into frogs, uses lots of exclamation marks', lines: ['¿Alguien tiene una rana?', '¡RANAS RANAS RANAS!', '¡¡Cambio por ranas!!', 'Croac 🐸'] },
  { name: 'SoftBunny', skin: 'c', home: 'collection', fav: 'bunny', famousFav: 'catpaw', persona: 'shy, sweet and a little sleepy, dreams about Cloud squishies, speaks softly and briefly', lines: ['qué suavecito...', 'amo los de nube ☁️', 'holi :)', 'mi colección es chiquita pero linda'] },
  { name: 'PixelNoah', skin: 'g', home: 'trading', fav: 'blob', famousFav: 'icecube', persona: 'techy gamer who talks about builds and odds, loves Neon and Glitched squishies, says GG a lot', lines: ['GG', 'Neón > todo', 'Llenado Perfect = +suerte', 'Cambio épicos'] },
  { name: 'MochiStar', skin: 'f', home: 'center', fav: 'cat', famousFav: 'butter', persona: 'confident and a bit show-offy, brags about legendaries but is secretly kind and gives tips, obsessed with the viral butter squishy', lines: ['¡Me salió un legendario!', 'Oro o nada ✨', 'Mira mi mantequilla 🧈', 'Supera mi colección jaja'] },
  { name: 'CatCollector', skin: 'k', home: 'trading', fav: 'cat', famousFav: 'dumpling', persona: 'chill veteran trader who only cares about cats, calm and funny, speaks like a friendly shopkeeper', lines: ['Solo gatos, porfa', '¿Tienes gatos raros?', 'Aquí cambios justos', 'Miau-ravillosos tratos'] },
  { name: 'LilyLoops', skin: 'a', home: 'machines', fav: 'blob', famousFav: 'donut', persona: 'curious newbie asking questions about how filling works, very polite and excited', lines: ['¿Cómo saco Perfect?', '¡¡Mi primer épico!!', '¿El relleno de miel es bueno?', 'La Máquina 02 se ve brutal'] },
];

// ------------------------------------------------------------ UTILS
const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const fmt = (n) => Math.round(n).toLocaleString('es-CO');
const uid = () => 'sq_' + Math.random().toString(36).slice(2, 9);
const damp = (a, b, k, dt) => lerp(a, b, 1 - Math.exp(-k * dt));
function weightedPick(items, weightFn) {
  let tot = 0; for (const it of items) tot += weightFn(it);
  let r = Math.random() * tot;
  for (const it of items) { r -= weightFn(it); if (r <= 0) return it; }
  return items[items.length - 1];
}
function b64ToBuf(b64) { const s = atob(b64); const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return u.buffer; }
function esc(s) { return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }

// ------------------------------------------------------------ AUDIO (Kenney CC0 + WebAudio synth)
const SFX = {
  ctx: null, buffers: {}, muted: false, master: null, fillOsc: null,
  map: { click: 'click_002', open: 'open_001', close: 'close_002', reward: 'confirmation_002', rare: 'maximize_006', epic: 'confirmation_004',
    sparkle: 'glass_002', sparkle2: 'glass_005', glitch: 'glitch_003', keep: 'drop_002', squish: 'pluck_001', squish2: 'pluck_002',
    error: 'error_004', select: 'select_003', coin: 'bong_001', levelup: 'switch_002', npc: 'question_001', toggle: 'toggle_002' },
  async init() {
    if (this.ctx) return;
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.master = this.ctx.createGain(); this.master.gain.value = 0.7; this.master.connect(this.ctx.destination);
      const sfx = (window.SW_ASSETS && SW_ASSETS.sfx) || {};
      await Promise.all(Object.entries(sfx).map(async ([k, b64]) => {
        try { this.buffers[k] = await this.ctx.decodeAudioData(b64ToBuf(b64)); } catch (e) { /* ignore broken clip */ }
      }));
    } catch (e) { this.ctx = null; }
  },
  play(name, opt = {}) {
    if (!this.ctx || this.muted) return;
    if (this.synth[name]) return this.synth[name].call(this, opt);
    const buf = this.buffers[this.map[name] || name]; if (!buf) return;
    const src = this.ctx.createBufferSource(); src.buffer = buf; src.playbackRate.value = opt.rate || 1;
    const g = this.ctx.createGain(); g.gain.value = opt.vol == null ? 0.8 : opt.vol;
    src.connect(g); g.connect(this.master); src.start();
  },
  tone(freq, dur, type = 'sine', vol = 0.2, when = 0, slide = 0) {
    const t = this.ctx.currentTime + when;
    const o = this.ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq * slide), t + dur);
    const g = this.ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.015); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.master); o.start(t); o.stop(t + dur + 0.05);
  },
  noise(dur, freq = 800, vol = 0.3, when = 0, q = 1, slide = 0.3) {
    const t = this.ctx.currentTime + when; const n = Math.floor(this.ctx.sampleRate * dur);
    const b = this.ctx.createBuffer(1, n, this.ctx.sampleRate); const d = b.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    const s = this.ctx.createBufferSource(); s.buffer = b;
    const f = this.ctx.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = q; f.frequency.setValueAtTime(freq, t); f.frequency.exponentialRampToValueAtTime(freq * slide, t + dur);
    const g = this.ctx.createGain(); g.gain.value = vol; s.connect(f); f.connect(g); g.connect(this.master); s.start(t);
  },
  synth: {
    squishy(o) { this.noise(0.22, 1400, 0.35 * (o.vol || 1), 0, 4, 0.25); this.tone(420 * (o.pitch || 1), 0.18, 'sine', 0.15, 0, 0.55); this.play('squish', { rate: (o.pitch || 1) * rand(0.9, 1.1), vol: 0.5 }); },
    pop() { this.noise(0.35, 2500, 0.6, 0, 0.8, 0.1); this.tone(180, 0.3, 'triangle', 0.25, 0, 0.3); },
    whirr() { for (let i = 0; i < 6; i++) this.tone(220 + i * 40, 0.25, 'square', 0.03, i * 0.3, 1.4); this.noise(1.9, 300, 0.12, 0, 2, 3); },
    fanfare() { [523, 659, 784, 1046, 784, 1046, 1318].forEach((f, i) => this.tone(f, i > 4 ? 0.6 : 0.2, 'triangle', 0.16, i * 0.11)); this.play('epic', { vol: 0.8 }); },
    secretSting() { [220, 207, 196, 185].forEach((f, i) => this.tone(f, 0.5, 'sawtooth', 0.06, i * 0.18)); this.play('glitch', { rate: 0.6 }); this.play('glitch', { rate: 1.3 }); },
    coins() { this.play('coin', { rate: 1.3, vol: 0.6 }); this.tone(1318, 0.12, 'square', 0.04, 0.05); this.tone(1760, 0.18, 'square', 0.04, 0.12); },
  },
  fillStart() {
    if (!this.ctx || this.muted || this.fillOsc) return;
    const o = this.ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = 90;
    const lfo = this.ctx.createOscillator(); lfo.frequency.value = 9; const lg = this.ctx.createGain(); lg.gain.value = 18; lfo.connect(lg); lg.connect(o.frequency);
    const f = this.ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 500; f.Q.value = 6;
    const g = this.ctx.createGain(); g.gain.value = 0.0001; g.gain.exponentialRampToValueAtTime(0.09, this.ctx.currentTime + 0.08);
    o.connect(f); f.connect(g); g.connect(this.master); o.start(); lfo.start();
    this.fillOsc = { o, lfo, f, g };
  },
  fillSet(p) { if (this.fillOsc) { this.fillOsc.o.frequency.value = 90 + p * 160; this.fillOsc.f.frequency.value = 400 + p * 1600; } },
  fillStop() {
    if (!this.fillOsc) return; const { o, lfo, g } = this.fillOsc; const t = this.ctx.currentTime;
    g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(g.gain.value, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.1);
    o.stop(t + 0.12); lfo.stop(t + 0.12); this.fillOsc = null;
  },
  // ---- espuma: loop de ruido filtrado que suena mientras apachurras (más fuerte = más rápido/hondo)
  foam: null,
  foamSet(level, bright = 1) {
    if (!this.ctx || this.muted) return;
    if (!this.foam) {
      if (level < 0.02) return;
      const n = this.ctx.sampleRate * 2, b = this.ctx.createBuffer(1, n, this.ctx.sampleRate), d = b.getChannelData(0);
      let last = 0; for (let i = 0; i < n; i++) { const w = Math.random() * 2 - 1; last = last * 0.55 + w * 0.45; d[i] = (Math.random() < 0.004 ? w * 3 : last); }
      const src = this.ctx.createBufferSource(); src.buffer = b; src.loop = true;
      const f = this.ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1400; f.Q.value = 0.8;
      const f2 = this.ctx.createBiquadFilter(); f2.type = 'lowshelf'; f2.frequency.value = 300; f2.gain.value = 6;
      const g = this.ctx.createGain(); g.gain.value = 0.0001;
      src.connect(f); f.connect(f2); f2.connect(g); g.connect(this.master); src.start();
      this.foam = { src, f, g, idle: 0 };
    }
    const t = this.ctx.currentTime, F = this.foam;
    F.g.gain.setTargetAtTime(Math.min(0.55, level * 0.5), t, 0.05);
    F.f.frequency.setTargetAtTime(700 + 1500 * bright + level * 900, t, 0.08);
    if (level < 0.02) { F.idle += 1; if (F.idle > 90) this.foamStop(); } else F.idle = 0;
  },
  foamStop() { if (!this.foam) return; const F = this.foam; const t = this.ctx.currentTime; F.g.gain.setTargetAtTime(0.0001, t, 0.05); F.src.stop(t + 0.3); this.foam = null; },
  // cera: transiente seco agudo + cuerpo medio + golpecito grave (más capas = más duro y fuerte)
  waxCrack(v = 1, layers = 1) {
    if (!this.ctx || this.muted) return; const L = 0.75 + layers * 0.25;
    this.noise(0.012 + 0.02 * v, rand(3800, 7000), 0.3 * v * L, 0, 1.2, 0.55);
    this.noise(0.05 + 0.03 * layers, rand(1100, 1900), 0.13 * v * L, 0.004, 2.2, 0.45);
    if (v > 0.55) this.tone(rand(85, 150), 0.07, 'sine', 0.1 * v * L, 0, 0.5);
  },
  waxTink(v = 1) { if (!this.ctx || this.muted) return; this.tone(rand(1700, 3300), 0.08, 'triangle', 0.045 * v, 0, 0.72); this.noise(0.018, 5200, 0.05 * v, 0, 3, 0.8); },
  // estirar: crujido gomoso con vibrato; torcer: chillidito
  creak(v = 1) { if (!this.ctx || this.muted) return; const f = rand(180, 320); this.tone(f, 0.16, 'sawtooth', 0.025 * v, 0, 1.35); this.noise(0.12, 700, 0.06 * v, 0, 5, 1.6); },
  squeak(v = 1) { if (!this.ctx || this.muted) return; this.tone(rand(700, 1100), 0.12, 'sine', 0.05 * v, 0, rand(1.2, 1.6)); },
  crinkle(v = 1) { if (!this.ctx || this.muted) return; this.noise(0.03 + Math.random() * 0.04, rand(2600, 5200), 0.05 * v, 0, 3, 0.8); },
};
function playSound(n, o) { SFX.play(n, o); }
