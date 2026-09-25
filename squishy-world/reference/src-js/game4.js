
// =====================================================================
// STATE + SAVE
// =====================================================================
function freshState() {
  return {
    v: 1, coins: CONFIG.START.coins, xp: 0, level: CONFIG.START.level,
    inventory: [], discovered: {}, equipped: null,
    upgrades: { fillSpeed: 1, luck: 0, storage: 0 },
    fillings: ['classic_foam', 'pink_foam', 'blue_foam'],
    quest: { i: 0, p: 0 }, stats: { fills: 0, perfect: 0, sold: 0, trades: 0, squishes: 0, bestRise: 0 },
    molds: ['butter'],
    tutorial: 0, lastMold: 'cat', lastFill: 'pink_foam', muted: false,
  };
}
let S = freshState();
let storageOK = true;
function saveGame() {
  if (!storageOK) return;
  try { localStorage.setItem(CONFIG.SAVE_KEY, JSON.stringify(S)); } catch (e) { storageOK = false; }
}
function loadGame() {
  try {
    const raw = localStorage.getItem(CONFIG.SAVE_KEY);
    if (raw) {
      const d = JSON.parse(raw); S = Object.assign(freshState(), d); S.upgrades = Object.assign(freshState().upgrades, d.upgrades || {}); S.stats = Object.assign(freshState().stats, d.stats || {});
      if (!Array.isArray(S.molds)) S.molds = ['butter']; if (!S.molds.includes('butter')) S.molds.push('butter');
      // migración: nombres en español y datos viejos
      for (const q of S.inventory) { if (!SP[q.species]) q.species = 'cat'; if (!VAR[q.variant]) q.variant = 'classic'; q.name = squishyName(q); }
      return true;
    }
  } catch (e) { storageOK = false; }
  return false;
}
function resetGame() { try { localStorage.removeItem(CONFIG.SAVE_KEY); } catch (e) { } S = freshState(); saveGame(); location.reload(); }
let saveTimer = 0; function markDirty() { saveTimer = 0.4; }

const capacity = () => UPGRADES.storage.caps[S.upgrades.storage];
const xpNeed = (lvl) => 50 + (lvl - 1) * 30;
function totalLuck(machine, filling, fillResult) {
  let L = S.upgrades.luck * 0.06 + (machine ? machine.def.luck : 0) + (FIL[filling].luck || 0);
  if (fillResult === 'perfect') L += 0.25; else if (fillResult === 'under') L -= 0.15; else if (fillResult === 'over') L -= 0.1;
  return Math.max(0, L);
}
function rarityWeights(L, filling) {
  return RARITIES.map(r => r.p * (1 + L * LUCK_TIER_BOOST[r.tier]) * (r.id === 'secret' && FIL[filling].secretX ? FIL[filling].secretX : 1));
}

// =====================================================================
// GENERATION
// =====================================================================
let forceLegendary = false;
function generateSquishy(species, filling, L, opts = {}) {
  let rarity;
  if (opts.rarity) rarity = opts.rarity;
  else { const w = rarityWeights(L, filling); const tot = w.reduce((a, b) => a + b, 0); let r = Math.random() * tot; rarity = RARITIES[RARITIES.length - 1].id; for (let i = 0; i < w.length; i++) { r -= w[i]; if (r <= 0) { rarity = RARITIES[i].id; break; } } }
  if (forceLegendary) { rarity = 'legendary'; forceLegendary = false; }
  const pool = VARIANTS[rarity]; const f = FIL[filling] || {};
  let variant = opts.variant;
  if (!variant && SP[species] && SP[species].famous && rarity === 'common') variant = 'original';
  if (!variant) { const biased = pool.filter(v => (f.bias || []).includes(v.id)); variant = (biased.length && Math.random() < 0.55 ? pick(biased) : pick(pool)).id; }
  let mutation = opts.mutation;
  if (!mutation) {
    const mx = (opts.machine && opts.machine.def.mutX) || 1;
    mutation = weightedPick(MUTATIONS, m => m.id === 'normal' ? m.p : m.p * mx * ((f.mut && f.mut[m.id]) || 1)).id;
  }
  const d = { id: uid(), species, rarity, variant, filling, mutation, face: opts.face || pick(['happy', 'happy', 'happy', 'wink', 'sleepy', 'surprised']), size: +(rand(0.95, 1.08)).toFixed(2), dateFound: Date.now(), fav: false };
  d.value = squishyValue(d); d.name = squishyName(d);
  return d;
}

// =====================================================================
// PLAYER + CAMERA + INPUT
// =====================================================================
const keys = {};
const input = { locked: false, dragging: false, dragMoved: 0, lastX: 0, lastY: 0, mouseX: innerWidth / 2, mouseY: innerHeight / 2 };
const cam = { yaw: 0, pitch: CONFIG.CAM.pitch, dist: CONFIG.CAM.dist, override: null, pos: new THREE.Vector3(), look: new THREE.Vector3(), shake: 0, zoom: 0 };
let player = null; let companion = null;
const UI = { open: null }; // current modal: 'machine'|'inv'|'shop'|'index'|'npc'|'trade'|'reveal'

function initPlayer() {
  const ch = makeCharacter('c');
  player = { ch, pos: new THREE.Vector3(0, 0, 20), vel: new THREE.Vector3(), yaw: 0, busy: false };
  ch.group.position.copy(player.pos); scene.add(ch.group);
}
function isTyping() { const a = document.activeElement; return a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA'); }

addEventListener('keydown', (e) => {
  if (isTyping()) { if (e.key === 'Escape') document.activeElement.blur(); return; }
  const k = e.key.toLowerCase(); keys[k] = true; keys[e.code] = true;
  if (['arrowleft', 'arrowright', 'arrowup', 'arrowdown', ' '].includes(k)) e.preventDefault();
  if (e.repeat) return;
  if (k === 'escape') { if (UI.open && UI.open !== 'reveal') closeUI(); return; }
  if (UI.open === 'machine' && k === ' ') { holdStart(); return; }
  if (UI.open) return;
  if (k === 'e') interact();
  else if (k === 'i') openInventory();
  else if (k === 'c') openIndex();
  else if (k === 'b') openShop();
  else if (k === 't') guideTo('trading', 'Ve a la Plaza de Intercambio');
  else if (CONFIG.DEBUG && k === 'k') { addCoins(1000); toast('Debug: +1000 monedas'); }
  else if (CONFIG.DEBUG && k === 'l') { forceLegendary = true; toast('Debug: el siguiente llenado es Legendario'); }
  else if (CONFIG.DEBUG && k === 'r') { if (confirm('¿Borrar todo el progreso de Squishy World?')) resetGame(); }
});
addEventListener('keyup', (e) => { const k = e.key.toLowerCase(); keys[k] = false; keys[e.code] = false; if (k === ' ' && UI.open === 'machine') holdEnd(); });
addEventListener('blur', () => { for (const k in keys) keys[k] = false; holdEnd(); });

canvas.addEventListener('mousedown', (e) => {
  input.dragging = true; input.dragMoved = 0; input.lastX = e.clientX; input.lastY = e.clientY;
  if (!UI.open && e.button === 0 && WorldPress.tryStart(input.locked ? innerWidth / 2 : e.clientX, input.locked ? innerHeight / 2 : e.clientY)) { input.dragging = false; return; }
  if (!UI.open && !input.locked && e.button === 0 && canvas.requestPointerLock && !input.lockFailed) {
    try { const p = canvas.requestPointerLock(); if (p && p.catch) p.catch(() => { input.lockFailed = true; }); } catch (err) { input.lockFailed = true; }
  }
});
addEventListener('mouseup', (e) => {
  if (WorldPress.active) { WorldPress.end(); input.dragging = false; return; }
  if (input.dragging && input.dragMoved < 6 && e.target === canvas) clickWorld(input.locked ? innerWidth / 2 : e.clientX, input.locked ? innerHeight / 2 : e.clientY);
  input.dragging = false;
});
addEventListener('mousemove', (e) => {
  input.mouseX = e.clientX; input.mouseY = e.clientY;
  if (WorldPress.active) { WorldPress.move(e); return; }
  if (input.locked) { rotateCam(e.movementX, e.movementY); input.dragMoved += 0; return; }
  if (input.dragging && !UI.open && !Aim.on) { const dx = e.clientX - input.lastX, dy = e.clientY - input.lastY; input.dragMoved += Math.abs(dx) + Math.abs(dy); rotateCam(dx, dy); input.lastX = e.clientX; input.lastY = e.clientY; }
});
document.addEventListener('pointerlockchange', () => { input.locked = document.pointerLockElement === canvas; });
document.addEventListener('pointerlockerror', () => { input.lockFailed = true; });
canvas.addEventListener('wheel', (e) => { if (!UI.open) cam.dist = clamp(cam.dist + e.deltaY * 0.01, CONFIG.CAM.min, CONFIG.CAM.max); }, { passive: true });
function rotateCam(dx, dy) { cam.yaw -= dx * CONFIG.CAM.sens; cam.pitch = clamp(cam.pitch + dy * CONFIG.CAM.sens, CONFIG.CAM.pitchMin, CONFIG.CAM.pitchMax); }
function freeMouse() { if (document.pointerLockElement) document.exitPointerLock(); }

const _v = new THREE.Vector3(), _v2 = new THREE.Vector3();
function updatePlayer(dt) {
  if (keys['arrowleft']) cam.yaw += CONFIG.CAM.keyTurn * dt;
  if (keys['arrowright']) cam.yaw -= CONFIG.CAM.keyTurn * dt;
  const canMove = !UI.open || UI.open === 'npc_far';
  let fx = 0, fz = 0;
  if (canMove) {
    const f = (keys['w'] || keys['arrowup'] ? 1 : 0) - (keys['s'] || keys['arrowdown'] ? 1 : 0);
    const s = (keys['d'] ? 1 : 0) - (keys['a'] ? 1 : 0);
    const sy = Math.sin(cam.yaw), cy = Math.cos(cam.yaw);
    fx = sy * f + (-cy) * s; fz = cy * f + sy * s;
  }
  const len = Math.hypot(fx, fz);
  const running = keys['shift'];
  const speed = running ? CONFIG.PLAYER.run : CONFIG.PLAYER.walk;
  if (len > 0.01) {
    fx /= len; fz /= len;
    player.pos.x += fx * speed * dt; player.pos.z += fz * speed * dt;
    const target = Math.atan2(fx, fz);
    let d = target - player.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
    player.yaw += d * Math.min(1, CONFIG.PLAYER.turn * dt);
    player.ch.base = running ? 'sprint' : 'walk'; if (!player.ch.onceBusy) player.ch.play(player.ch.base);
    player.moving = running ? 2 : 1;
    if (Tut.step === 0 && Math.hypot(player.pos.x, player.pos.z - 20) > 4) Tut.advance(1);
  } else { player.ch.base = 'idle'; if (!player.ch.onceBusy) player.ch.play('idle'); player.moving = 0; }
  resolveCollision(player.pos, CONFIG.PLAYER.radius);
  player.ch.group.position.copy(player.pos);
  player.ch.group.rotation.y = player.yaw;
  player.ch.mixer.update(dt);
}

function updateCamera(dt) {
  const C = CONFIG.CAM;
  let targetPos, targetLook;
  if (cam.override) { targetPos = cam.override.pos; targetLook = cam.override.look; }
  else {
    // modo apuntar: cámara más cerca y sobre el hombro derecho
    const ak = cam.aimK || 0;
    const look = _v.set(player.pos.x - Math.cos(cam.yaw) * 3.0 * ak, player.pos.y + C.lookH - ak * 0.4, player.pos.z + Math.sin(cam.yaw) * 3.0 * ak);
    const cp = Math.cos(cam.pitch), sp = Math.sin(cam.pitch);
    const off = _v2.set(-Math.sin(cam.yaw) * cp, sp, -Math.cos(cam.yaw) * cp).multiplyScalar(lerp(cam.dist, 9, ak));
    targetPos = look.clone().add(off); if (targetPos.y < 1.2) targetPos.y = 1.2;
    targetLook = look;
  }
  const k = cam.override ? (cam.override.k || 4) : 14;
  cam.pos.x = damp(cam.pos.x, targetPos.x, k, dt); cam.pos.y = damp(cam.pos.y, targetPos.y, k, dt); cam.pos.z = damp(cam.pos.z, targetPos.z, k, dt);
  cam.look.x = damp(cam.look.x, targetLook.x, k, dt); cam.look.y = damp(cam.look.y, targetLook.y, k, dt); cam.look.z = damp(cam.look.z, targetLook.z, k, dt);
  camera.position.copy(cam.pos);
  if (cam.shake > 0) { cam.shake -= dt; camera.position.x += rand(-0.15, 0.15); camera.position.y += rand(-0.15, 0.15); }
  camera.lookAt(cam.look);
  // shadow follows player
  sun.position.set(player.pos.x + 40, 70, player.pos.z + 30); sun.target.position.set(player.pos.x, 0, player.pos.z); sun.target.updateMatrixWorld();
}

// ---------- world clicks: squish anything squishy
const raycaster = new THREE.Raycaster(); const clickables = [];
function clickWorld(x, y) {
  if (UI.open) return;
  raycaster.setFromCamera(new THREE.Vector2(x / innerWidth * 2 - 1, -(y / innerHeight) * 2 + 1), camera);
  const roots = clickables.filter(s => s.root.parent);
  const hits = raycaster.intersectObjects(roots.map(s => s.root), true);
  if (hits.length) {
    let o = hits[0].object; while (o && !o.userData.sq) o = o.parent;
    if (o && o.userData.sq) { o.userData.sq.squish(1); playSound('squishy', { pitch: o.userData.sq === world.statue ? 0.6 : 1 }); }
  }
}

// ---------- companion (equipped squishy follows player)
function refreshCompanion() {
  if (companion) { scene.remove(companion.root); companion.dispose(); const i = clickables.indexOf(companion); if (i >= 0) clickables.splice(i, 1); companion = null; }
  const d = S.inventory.find(s => s.id === S.equipped);
  if (!d) { S.equipped = null; return; }
  companion = buildSquishy(d); companion.root.scale.multiplyScalar(0.95); companion.owner = null; companion.ownerLabel = 'Tuyo';
  const side = new THREE.Vector3(-Math.cos(player.yaw), 0, Math.sin(player.yaw)).multiplyScalar(CONFIG.COMPANION.offset);
  companion.root.position.copy(player.pos).add(side);
  companion.hop = 0; scene.add(companion.root); clickables.push(companion);
}
function updateCompanion(dt, t) {
  if (!companion) return;
  if (companion.heldBy) { companion.update(dt, 0); return; } // quieto mientras lo apachurras
  const behind = new THREE.Vector3(Math.sin(player.yaw), 0, Math.cos(player.yaw)).multiplyScalar(-1.6);
  const side = new THREE.Vector3(-Math.cos(player.yaw), 0, Math.sin(player.yaw)).multiplyScalar(CONFIG.COMPANION.offset);
  const target = player.pos.clone().add(side).add(behind);
  const r = companion.root; const prev = r.position.clone();
  r.position.x = damp(r.position.x, target.x, CONFIG.COMPANION.lerp, dt); r.position.z = damp(r.position.z, target.z, CONFIG.COMPANION.lerp, dt);
  const sp = prev.distanceTo(r.position) / Math.max(dt, 1e-4);
  const hopH = sp > 3 ? Math.abs(Math.sin(t * (player.moving === 2 ? 13 : 9))) * (player.moving === 2 ? 1.1 : 0.6) : Math.sin(t * 4) * 0.08 + 0.08;
  r.position.y = hopH;
  const face = sp > 1 ? Math.atan2(r.position.x - prev.x, r.position.z - prev.z) : Math.atan2(camera.position.x - r.position.x, camera.position.z - r.position.z);
  r.rotation.y += Math.atan2(Math.sin(face - r.rotation.y), Math.cos(face - r.rotation.y)) * Math.min(1, dt * 6);
  companion.update(dt, sp > 3 ? 1 : 0);
}

// =====================================================================
// NPCs (Kenney blocky, wander, bubbles, AI chat via `sample`)
// =====================================================================
const npcs = [];
const labelsEl = $('labels');
function initNPCs() {
  NPC_DEFS.forEach((def, i) => {
    const ch = makeCharacter(def.skin);
    const home = ZONES[def.home];
    const pos = new THREE.Vector3(home.x + rand(-10, 10), 0, home.z + rand(-10, 10));
    resolveCollision(pos, 1.3);
    ch.group.position.copy(pos); scene.add(ch.group);
    // their own companion to show off
    const rr = weightedPick(RARITIES.slice(0, 5), r => [0.3, 0.3, 0.25, 0.1, 0.05][r.tier]).id;
    // la mitad de los jugadores anda presumiendo un squishy viral
    const spc = (i % 2 === 0 && def.famousFav) ? def.famousFav : (Math.random() < 0.6 ? def.fav : pick(['cat', 'bear', 'frog', 'bunny']));
    const sqd = generateSquishy(spc, pick(['classic_foam', 'pink_foam', 'cloud', 'honey']), 0, { rarity: rr });
    if (i % 3 === 1) sqd.wax = { list: Array.from({ length: 1 + (i % 3) }, () => ({ c: pick(['blanca', 'rosa', 'lila', 'miel', 'menta', 'cielo', 'arcoiris']), s: (Math.random() * 1e9) | 0 })) }; // algunos andan con su squishy encerado
    const sq = buildSquishy(sqd); sq.root.scale.multiplyScalar(0.9); scene.add(sq.root); clickables.push(sq);
    const tag = document.createElement('div'); tag.className = 'tag'; tag.textContent = def.name; labelsEl.appendChild(tag);
    const bub = document.createElement('div'); bub.className = 'bubble hidden'; labelsEl.appendChild(bub);
    const npc = { def, ch, pos, home, target: pos.clone(), wait: rand(1, 4), yaw: rand(0, 6), sq, sqd, tag, bub, bubT: rand(2, 9), bubHide: 0, talking: false, chat: [], trades: 0, reactT: 0 };
    sq.owner = npc; sq.ownerLabel = 'De ' + def.name; npcs.push(npc);
  });
}
function npcSay(n, text, dur = 4) { n.bub.textContent = text; n.bub.classList.remove('hidden'); n.bubHide = dur; }
function updateNPCs(dt, t) {
  for (const n of npcs) {
    const toP = Math.hypot(player.pos.x - n.pos.x, player.pos.z - n.pos.z);
    if (n.talking || toP < 7 || n.sq.heldBy) {
      const face = Math.atan2(player.pos.x - n.pos.x, player.pos.z - n.pos.z);
      n.yaw += Math.atan2(Math.sin(face - n.yaw), Math.cos(face - n.yaw)) * Math.min(1, dt * 5);
      n.ch.base = 'idle'; if (!n.ch.onceBusy) n.ch.play('idle');
    } else {
      const dx = n.target.x - n.pos.x, dz = n.target.z - n.pos.z, d = Math.hypot(dx, dz);
      if (d > 0.6) {
        const sp = 5; n.pos.x += dx / d * sp * dt; n.pos.z += dz / d * sp * dt; resolveCollision(n.pos, 1.3);
        const face = Math.atan2(dx, dz); n.yaw += Math.atan2(Math.sin(face - n.yaw), Math.cos(face - n.yaw)) * Math.min(1, dt * 6);
        n.ch.base = 'walk'; n.ch.play('walk');
        n.stuck = (n.stuck || 0) + dt; if (n.stuck > 6) { n.target.copy(n.pos); n.stuck = 0; }
      } else {
        n.ch.base = 'idle'; n.ch.play('idle'); n.wait -= dt; n.stuck = 0;
        if (n.wait < 0) { n.wait = rand(3, 8); n.target.set(n.home.x + rand(-15, 15), 0, n.home.z + rand(-15, 15)); if (Math.random() < 0.25) n.ch.play(pick(['emote-yes', 'interact-right', 'pick-up']), 0.2, true); }
      }
    }
    n.ch.group.position.copy(n.pos); n.ch.group.rotation.y = n.yaw; n.ch.mixer.update(dt);
    // companion follows
    const side = new THREE.Vector3(-Math.cos(n.yaw), 0, Math.sin(n.yaw)).multiplyScalar(2.8);
    const tp = n.pos.clone().add(side); const r = n.sq.root;
    if (!n.sq.heldBy) { r.position.x = damp(r.position.x, tp.x, 4, dt); r.position.z = damp(r.position.z, tp.z, 4, dt); r.position.y = damp(r.position.y, Math.abs(Math.sin(t * 5 + n.yaw)) * 0.3, 12, dt); r.rotation.y = n.yaw; }
    else r.position.y = damp(r.position.y, 0, 10, dt);
    n.sq.update(dt, 0);
    // ambient bubbles
    n.bubT -= dt; if (n.bubT < 0) { n.bubT = rand(...CONFIG.NPC_BUBBLE_EVERY); if (!n.talking && toP < 60 && Math.random() < 0.7) npcSay(n, pick(n.def.lines)); }
    if (n.bubHide > 0) { n.bubHide -= dt; if (n.bubHide <= 0) n.bub.classList.add('hidden'); }
  }
}
const _proj = new THREE.Vector3();
function updateLabels() {
  for (const n of npcs) {
    _proj.set(n.pos.x, n.pos.y + 6.3, n.pos.z).project(camera);
    const d = camera.position.distanceTo(n.pos);
    const vis = _proj.z < 1 && d < 70;
    const x = (_proj.x * 0.5 + 0.5) * innerWidth, y = (-_proj.y * 0.5 + 0.5) * innerHeight;
    n.tag.style.display = vis ? '' : 'none'; n.tag.style.left = x + 'px'; n.tag.style.top = y + 'px';
    if (!n.bub.classList.contains('hidden')) { n.bub.style.display = vis ? '' : 'none'; n.bub.style.left = x + 'px'; n.bub.style.top = (y - 22) + 'px'; }
  }
}

// ---------- AI (Claude via artifact `sample` capability; scripted fallback)
const AI = { sample: null, state: 'pending', denied: false };
(async () => {
  try { if (window.claude && window.claude.use) { AI.sample = await window.claude.use('sample'); } } catch (e) { AI.sample = null; }
  AI.state = AI.sample ? 'ready' : 'off';
})();
function collectionSummary() {
  const top = [...S.inventory].sort((a, b) => b.value - a.value).slice(0, 5).map(s => `${s.name} (${R[s.rarity].name})`);
  const eq = S.inventory.find(s => s.id === S.equipped);
  return { top: top.join(', ') || 'nothing yet', equipped: eq ? eq.name : 'none', count: S.inventory.length, level: S.level };
}
async function npcAIReply(n, text) {
  const cs = collectionSummary();
  const rules = `You are ${n.def.name}, another player hanging out in the lobby of "Squishy World", a cute kid-friendly game about filling squishy toys in machines and collecting them. Personality: ${n.def.persona}. Favorite mold: ${n.def.fav}. Your companion right now: ${n.sqd.name} (${R[n.sqd.rarity].name}).
Game facts (the game UI is in Spanish, use these names): molds Gato, Oso, Rana (nivel 3), Conejo (nivel 5), Blob (nivel 8), plus viral molds bought in the Tienda: Barra de Mantequilla (free, super slow rising), Tostada con Mantequilla, Queso Suizo, Fresa Jumbo, Cubo de Hielo, Huevo Frito, Dumpling al Vapor, Dango, Rana en el Pozo, Dona Glaseada, Uvas Jumbo, Hamburguesa, Pata de Gato. Rarities Común, Poco común, Raro, Épico, Legendario, Secreto. Fillings from the Tienda: Espuma Rosa, Bolitas, Escarcha, Nube, Miel (slowest rise), Neón, Arcoíris, Cristal, Galaxia, Misterio. Stopping the gauge in the PERFECT zone boosts luck. Máquina 02 opens at level 5, Máquina 03 at level 10. Trades happen in the Plaza de Intercambio. Players can squish any squishy (theirs or others') by holding click on it, or press F for close-up squishing; slow rising = how slowly it recovers.
The player you are talking to: level ${cs.level}, ${cs.count} squishies, best ones: ${cs.top}; equipped: ${cs.equipped}.
Rules: stay in character as a friendly kid-safe player. Reply in 1-2 short casual sentences (max 30 words), emojis allowed. Never ask for or share personal information (real names, age, school, address, photos, passwords, contact info) and never suggest meeting or chatting outside the game. Never mention real money, real brands or other games. If the player says something unkind or unsafe, gently change the subject back to squishies. Reply in Spanish (casual, Latin American kid style) unless the player clearly writes in another language.
Reply ONLY with JSON: {"say":"<your line>","emote":"yes"|"no"|"wave"|"none","wantsTrade":true|false}`;
  const turns = [{ role: 'user', content: rules + '\n\nThe player walks up to you.' }, { role: 'assistant', content: JSON.stringify({ say: n.chat[0] ? n.chat[0].text : '¡Holi!', emote: 'wave', wantsTrade: false }) }];
  for (const m of n.chat.slice(1).slice(-10)) turns.push({ role: m.me ? 'user' : 'assistant', content: m.me ? m.text : JSON.stringify({ say: m.text, emote: 'none', wantsTrade: false }) });
  if (turns[turns.length - 1].role !== 'user') turns.push({ role: 'user', content: text });
  for (let i = turns.length - 1; i > 0; i--) if (turns[i].role === turns[i - 1].role) { turns[i - 1].content += '\n' + turns[i].content; turns.splice(i, 1); }
  const out = await AI.sample.json(turns, { modelTier: CONFIG.AI_TIER, cache: false });
  return out && typeof out.say === 'string' ? out : { say: String(out && out.say || '...'), emote: 'none', wantsTrade: false };
}
function scriptedReply(n, text) {
  const t = text.toLowerCase();
  const en = /\b(hi|hello|hey|trade|want|how|what|you|your|the|is|are|thanks)\b/.test(t) && !/[ñáéíóú¿¡]/.test(t);
  const es = !en;
  const L = (en, sp) => es ? sp : en;
  if (/trade|cambi|interc/.test(t)) return { say: L(`Sure! Let's see what you've got 👀`, '¡Dale! Muéstrame qué tienes 👀'), emote: 'yes', wantsTrade: true };
  if (/aplast|apachurr|squish|slow|suav|sube/.test(t)) return { say: L('Hold click on any squishy to squish it — press F for close-up!', '¡Mantén clic sobre cualquier squishy para apachurrarlo, o presiona F para verlo de cerca! Los de Miel suben lentííísimo 🍯'), emote: 'yes', wantsTrade: false };
  if (/mantequilla|butter|viral|famos/.test(t)) return { say: L('The butter one is the best, it rises sooo slow 🧈', '¡La Barra de Mantequilla es la mejor, sube lentííísimo! 🧈 Los demás virales están en la Tienda.'), emote: 'yes', wantsTrade: false };
  if (/perfect|tip|how|consejo|truco|cómo|como/.test(t)) return { say: L('Tip: let go right inside the green Perfect zone, it boosts your luck!', 'Truco: suelta justo en la zona verde Perfect, ¡te sube la suerte!'), emote: 'yes', wantsTrade: false };
  if (/legend|secret|secreto/.test(t)) return { say: L('Legendaries are super rare… Mystery filling helps a tiny bit ✨', 'Los legendarios son rarísimos… el relleno Mystery ayuda un poquito ✨'), emote: 'none', wantsTrade: false };
  if (new RegExp(n.def.fav).test(t)) return { say: L(`${SP[n.def.fav].name}s are my favorite!! Got any?`, `¡Los ${SP[n.def.fav].name} son mis favoritos! ¿Tienes alguno?`), emote: 'yes', wantsTrade: true };
  if (es) return { say: pick(['¡Qué buen compañero tienes!', '¿Ya probaste la Máquina 02?', '¿Quieres cambiar?', '¡Me encanta esta plaza!']), emote: pick(['none', 'yes']), wantsTrade: Math.random() < 0.3 };
  return { say: pick(n.def.lines.concat(['Nice companion!', 'Have you tried Machine 02?', 'Want to trade?'])), emote: pick(['none', 'yes']), wantsTrade: Math.random() < 0.3 };
}
