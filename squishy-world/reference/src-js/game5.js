
// =====================================================================
// HUD helpers
// =====================================================================
function toast(msg, big = false, ms = 2600) {
  const t = document.createElement('div'); t.className = 'toast' + (big ? ' big' : ''); t.innerHTML = '<span>' + msg + '</span>'; $('toasts').appendChild(t);
  setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 400); }, ms);
  while ($('toasts').children.length > 4) $('toasts').firstChild.remove();
}
function updateHUD() {
  $('coins').textContent = fmt(S.coins); $('lvl').textContent = S.level;
  $('xpTxt').textContent = `${S.xp}/${xpNeed(S.level)} XP`; $('xpfill').style.width = (S.xp / xpNeed(S.level) * 100) + '%';
  $('muteBtn').textContent = S.muted ? '🔇' : '🔊';
  updateQuestCard();
}
function addCoins(n) { S.coins += n; $('coinPill').classList.remove('bump'); void $('coinPill').offsetWidth; $('coinPill').classList.add('bump'); updateHUD(); markDirty(); }
function addXP(n) {
  S.xp += n;
  while (S.xp >= xpNeed(S.level)) {
    S.xp -= xpNeed(S.level); S.level++;
    playSound('levelup'); toast(`¡Subiste de nivel! Ahora eres nivel ${S.level}`, true, 3200);
    for (const sp of SPECIES) if (!sp.famous && sp.unlockLevel === S.level) setTimeout(() => toast(`¡Nuevo molde desbloqueado: ${sp.name}!`, true, 3200), 900);
    for (const m of MACHINES) if (m.level === S.level) setTimeout(() => toast(`¡${m.name} (${m.sub}) ya está abierta!`, true, 3200), 1600);
    questEvent('level', S.level, true);
    refreshMachineLocks();
  }
  updateHUD(); markDirty();
}

// =====================================================================
// GUIDE MARKER (3D chevron + ground arrow)
// =====================================================================
const guide = { target: null, key: null };
const chevron = new THREE.Mesh(new THREE.ConeGeometry(1.4, 2.6, 4), new THREE.MeshBasicMaterial({ color: '#FF7BB5' }));
chevron.rotation.x = Math.PI; chevron.visible = false; scene.add(chevron);
const groundArrow = new THREE.Mesh(new THREE.ConeGeometry(0.7, 2.2, 3), new THREE.MeshBasicMaterial({ color: '#FF7BB5', transparent: true, opacity: 0.85 }));
groundArrow.rotation.x = Math.PI / 2; const arrowPivot = new THREE.Group(); arrowPivot.add(groundArrow); groundArrow.position.z = 4.2; arrowPivot.visible = false; scene.add(arrowPivot);
function zoneTarget(key) {
  if (key === 'machines') return world.machines[0].pos.clone().setY(13);
  if (key === 'shop') return world.shopCounter.pos.clone().setY(9);
  if (key === 'trading') return new THREE.Vector3(ZONES.trading.x, 10, ZONES.trading.z);
  if (key === 'collection') return world.idxBoard.pos.clone().setY(12);
  return null;
}
function guideTo(key, msg) { guide.key = key; guide.target = zoneTarget(key); if (msg) toast(msg); }
function updateGuide(t) {
  const tg = guide.target;
  if (!tg) { chevron.visible = arrowPivot.visible = false; return; }
  const d = Math.hypot(player.pos.x - tg.x, player.pos.z - tg.z);
  if (d < 12 && guide.key !== 'machines') { guide.target = null; guide.key = null; return; }
  chevron.visible = true; chevron.position.set(tg.x, tg.y + Math.sin(t * 3) * 0.8, tg.z); chevron.rotation.y = t * 2;
  arrowPivot.visible = d > 14; arrowPivot.position.set(player.pos.x, 0.4, player.pos.z); arrowPivot.rotation.y = Math.atan2(tg.x - player.pos.x, tg.z - player.pos.z);
  groundArrow.position.z = 4.2 + Math.sin(t * 5) * 0.4;
}

// =====================================================================
// INTERACTION
// =====================================================================
let nearest = null;
function findInteractable() {
  let best = null, bd = CONFIG.INTERACT_DIST;
  const check = (pos, obj, extra = 0) => { const d = Math.hypot(player.pos.x - pos.x, player.pos.z - pos.z) - extra; if (d < bd) { bd = d; best = obj; } };
  for (const m of world.machines) check(m.pos.clone().add(new THREE.Vector3(0, 0, -5)), { type: 'machine', m }, 1);
  check(world.shopCounter.pos, { type: 'shop' });
  check(world.idxBoard.pos, { type: 'index' }, 2);
  for (const n of npcs) check(n.pos, { type: 'npc', n }, 1.5);
  return best;
}
function updatePrompt() {
  if (UI.open) { $('prompt').classList.add('hidden'); return; }
  nearest = findInteractable();
  const p = $('prompt');
  if (!nearest) { p.classList.add('hidden'); return; }
  let txt = '', locked = false;
  if (nearest.type === 'machine') { const m = nearest.m; if (S.level < m.def.level) { txt = `${m.def.name} — requiere nivel ${m.def.level}`; locked = true; } else txt = `Usar ${m.def.id === 'm1' ? 'la Máquina Squishy' : m.def.name}`; }
  else if (nearest.type === 'shop') txt = 'Abrir la Tienda';
  else if (nearest.type === 'index') txt = 'Abrir el Índice Squishy';
  else if (nearest.type === 'npc') txt = `Hablar con ${nearest.n.def.name}`;
  $('promptTxt').textContent = txt; p.classList.toggle('locked', locked); p.classList.remove('hidden');
}
function interact() {
  if (!nearest) return;
  player.ch.play('interact-right', 0.15, true);
  if (nearest.type === 'machine') { if (S.level < nearest.m.def.level) { playSound('error'); toast(`Llega a nivel ${nearest.m.def.level} para usar la ${nearest.m.def.name}`); } else openMachine(nearest.m); }
  else if (nearest.type === 'shop') openShop();
  else if (nearest.type === 'index') openIndex();
  else if (nearest.type === 'npc') openNPC(nearest.n);
}
function openOverlay(id, key) { freeMouse(); UI.open = key; $(id).classList.remove('hidden'); playSound('open'); $('prompt').classList.add('hidden'); }
function closeUI() {
  const k = UI.open; if (!k) return;
  if (k === 'machine') { if (Fill.state === 'filling' || Fill.state === 'processing') return; $('machinePanel').classList.add('hidden'); cam.override = null; Fill.machine = null; clearMachineInside(); }
  if (k === 'inv') $('invWrap').classList.add('hidden');
  if (k === 'shop') $('shopWrap').classList.add('hidden');
  if (k === 'index') $('indexWrap').classList.add('hidden');
  if (k === 'npc') { $('npcWrap').classList.add('hidden'); if (Chat.n) Chat.n.talking = false; }
  if (k === 'trade') { $('tradeWrap').classList.add('hidden'); if (Trade.n) Trade.n.talking = false; }
  if (k === 'studio') { Studio.close(); return; }
  UI.open = null; playSound('close'); canvas.focus();
}
document.querySelectorAll('[data-close]').forEach(b => b.addEventListener('click', () => closeUI()));
document.querySelectorAll('.overlay').forEach(o => o.addEventListener('mousedown', (e) => { if (e.target === o) closeUI(); }));

// =====================================================================
// MACHINE + FILL FLOW
// =====================================================================
const Fill = { state: 'idle', machine: null, species: 'cat', filling: 'pink_foam', p: 0, holding: false, result: null, sq: null };
function refreshMachineLocks() { for (const m of world.machines) if (m.lockSign) m.lockSign.visible = S.level < m.def.level; }
function openMachine(m) {
  Fill.machine = m; Fill.state = 'idle'; Fill.p = 0; Fill.species = moldAvailable(S.lastMold) ? S.lastMold : 'cat';
  Fill.filling = S.fillings.includes(S.lastFill) ? S.lastFill : 'classic_foam';
  if (Tut.step <= 2) { Fill.species = 'cat'; Fill.filling = 'pink_foam'; }
  $('mTitle').textContent = m.def.id === 'm1' ? 'Crea un Squishy' : m.def.name;
  $('mInfo').textContent = `${m.def.name} · ${m.def.sub}` + (m.def.luck ? ` · +${Math.round(m.def.luck * 100)}% suerte` : '') + (m.def.mutX ? ' · más mutaciones' : '');
  renderMachinePanel(); openOverlay('machinePanel', 'machine');
  // camera frames the machine on the left of the screen
  const front = m.pos.clone().add(new THREE.Vector3(0, 0, -1));
  cam.override = { pos: new THREE.Vector3(m.pos.x + 8.5, 11, m.pos.z - 17), look: new THREE.Vector3(m.pos.x + 4.2, 6.5, m.pos.z) };
  player.pos.set(m.pos.x - 1.5, 0, m.pos.z - 7.5); player.yaw = 0;
  setMachineInside(); Tut.onMachineOpen();
}
function renderMachinePanel() {
  const locked = Fill.state !== 'idle';
  const moldBtn = sp => {
    const lock = !moldAvailable(sp.id);
    const tag = lock ? (sp.famous ? `<span class="lk">🛒 ${fmt(sp.price)}</span>` : `<span class="lk">Nv ${sp.unlockLevel}</span>`) : '';
    return `<button class="mold ${Fill.species === sp.id ? 'on' : ''} ${lock ? 'lock' : ''} ${sp.famous ? 'viral' : ''}" data-mold="${sp.id}" ${locked ? 'disabled' : ''}><img src="${Thumbs.get({ species: sp.id, variant: sp.famous ? 'original' : 'classic', mutation: 'normal' })}" alt="">${sp.name}${tag}</button>`;
  };
  $('molds').innerHTML = SPECIES.filter(sp => !sp.famous).map(moldBtn).join('');
  $('moldsViral').innerHTML = SPECIES.filter(sp => sp.famous).sort((a, b) => moldAvailable(b.id) - moldAvailable(a.id) || a.price - b.price).map(moldBtn).join('');
  $('fills').innerHTML = FILLINGS.map(f => {
    const own = S.fillings.includes(f.id);
    return `<button class="fill ${Fill.filling === f.id ? 'on' : ''} ${own ? '' : 'lock'}" data-fill="${f.id}" ${locked ? 'disabled' : ''}><span class="sw" style="background:${f.color}"></span>${f.name}${own ? (f.perUse ? ` <small>(${f.perUse})</small>` : '') : ' 🔒'}</button>`;
  }).join('');
  const L = totalLuck(Fill.machine, Fill.filling, null); const w = rarityWeights(L, Fill.filling); const tot = w.reduce((a, b) => a + b, 0);
  const Lp = totalLuck(Fill.machine, Fill.filling, 'perfect'); const wp = rarityWeights(Lp, Fill.filling); const totp = wp.reduce((a, b) => a + b, 0);
  $('odds').innerHTML = RARITIES.map((r, i) => `<span style="background:${r.color}" title="${r.name}: ${(w[i] / tot * 100).toFixed(2)}% (Perfect: ${(wp[i] / totp * 100).toFixed(2)}%)">${r.name.split(' ')[0].slice(0, 4)} ${(w[i] / tot * 100).toFixed(r.tier > 2 ? 1 : 0)}%</span>`).join('');
  const P = CONFIG.FILL; const g = $('gauge'); const span = P.pop;
  g.querySelectorAll('.z').forEach(z => z.remove());
  const zone = (a, b, col) => { const z = document.createElement('div'); z.className = 'z'; z.style.left = (a / span * 100) + '%'; z.style.width = ((b - a) / span * 100) + '%'; z.style.background = col; g.prepend(z); };
  zone(0, P.perfect[0], '#e9e4f2'); zone(P.perfect[0], P.perfect[1], '#9CE0CA'); zone(P.perfect[1], span * 0.97, '#ffd9a8'); zone(span * 0.97, span, '#ff9aa8');
  setGauge(Fill.p);
  $('holdBtn').disabled = Fill.state === 'processing' || Fill.state === 'reveal';
  $('holdBtn').textContent = Fill.state === 'filling' ? 'Llenando… ¡suelta!' : 'Mantén para llenar';
  const full = S.inventory.length >= capacity();
  if (full && Fill.state === 'idle') { $('fillResult').innerHTML = `<span style="color:#e0566b;font-size:15px;font-family:var(--body);font-weight:900">Inventario lleno (${capacity()}). Vende algunos squishies primero.</span>`; $('holdBtn').disabled = true; }
  else if (Fill.state === 'idle') $('fillResult').textContent = '';
}
function moldAvailable(id) { const sp = SP[id]; if (!sp) return false; return sp.famous ? S.molds.includes(id) : S.level >= sp.unlockLevel; }
function onMoldClick(e) {
  const b = e.target.closest('[data-mold]'); if (!b || Fill.state !== 'idle') return; const sp = SP[b.dataset.mold];
  if (!moldAvailable(sp.id)) { playSound('error'); toast(sp.famous ? `El molde ${sp.name} se compra en la Tienda (${fmt(sp.price)} monedas)` : `El molde ${sp.name} se desbloquea en el nivel ${sp.unlockLevel}`); return; }
  Fill.species = sp.id; S.lastMold = sp.id; playSound('click'); renderMachinePanel(); setMachineInside();
}
$('molds').addEventListener('click', onMoldClick); $('moldsViral').addEventListener('click', onMoldClick);
$('fills').addEventListener('click', (e) => {
  const b = e.target.closest('[data-fill]'); if (!b || Fill.state !== 'idle') return; const f = FIL[b.dataset.fill];
  if (!S.fillings.includes(f.id)) { playSound('error'); toast(`${f.name} se vende en la Tienda (${fmt(f.price)} monedas)`); return; }
  Fill.filling = f.id; S.lastFill = f.id; playSound('click'); renderMachinePanel(); setMachineInside();
});
function setGauge(p) { $('gNeedle').style.left = (clamp(p, 0, CONFIG.FILL.pop) / CONFIG.FILL.pop * 100) + '%'; $('gProg').style.width = (clamp(p, 0, CONFIG.FILL.pop) / CONFIG.FILL.pop * 100) + '%'; }
function setMachineInside() {
  const m = Fill.machine; if (!m) return; clearMachineInside();
  const f = FIL[Fill.filling];
  const sq = buildSquishy({ species: Fill.species, variant: 'white', rarity: 'common', mutation: 'normal', face: 'sleepy', size: 1 }, { noSparks: true });
  sq.fitK = 1.9 / Math.max(1.9, sq.dims.h, sq.dims.w * 0.9);
  sq.mat.color.set(f.color3 || (f.color.startsWith('#') ? f.color : '#ffd36e')); sq.mat.transparent = true; sq.mat.opacity = 0.55;
  sq.root.position.copy(m.domeWorld); sq.root.scale.setScalar(0.35 * sq.fitK); scene.add(sq.root);
  m.inside = sq; m.liquid.material = mat(f.color3 || (f.color.startsWith('#') ? f.color : '#ffd36e'), 0.3); m.stream.material.color.set(m.liquid.material.color); m.stream.material.emissive.set(m.liquid.material.color);
  setLiquid(m, 1);
}
function clearMachineInside() { for (const m of world.machines) if (m.inside) { scene.remove(m.inside.root); m.inside.dispose(); m.inside = null; m.stream.visible = false; } }
function setLiquid(m, level) { const h = Math.max(0.05, level * 5.6); m.liquid.scale.y = h; m.liquid.position.y = 12.4 + h / 2; }

const holdBtn = $('holdBtn');
holdBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); holdBtn.setPointerCapture && holdBtn.setPointerCapture(e.pointerId); holdStart(); });
holdBtn.addEventListener('pointerup', () => holdEnd());
holdBtn.addEventListener('pointercancel', () => holdEnd());
function holdStart() {
  if (UI.open !== 'machine' || holdBtn.disabled) return;
  if (Fill.state === 'idle') {
    const f = FIL[Fill.filling];
    if (S.inventory.length >= capacity()) { playSound('error'); return; }
    if (f.perUse) { if (S.coins < f.perUse) { playSound('error'); toast(`El relleno Misterio cuesta ${f.perUse} monedas por llenado`); return; } addCoins(-f.perUse); }
    Fill.state = 'filling'; Fill.p = 0; setMachineInside(); renderMachinePanel(); $('fillResult').textContent = '';
  }
  if (Fill.state !== 'filling') return;
  Fill.holding = true; holdBtn.classList.add('holding'); SFX.fillStart(); Fill.machine.stream.visible = true;
}
function holdEnd() {
  if (!Fill.holding) return; Fill.holding = false; holdBtn.classList.remove('holding'); SFX.fillStop(); if (Fill.machine) Fill.machine.stream.visible = false;
  if (Fill.state !== 'filling') return;
  if (Fill.p < CONFIG.FILL.minCommit) { $('fillResult').innerHTML = '<span style="color:#7a7f92">Sigue manteniendo…</span>'; return; }
  const P = CONFIG.FILL; const p = Fill.p;
  const res = p < P.perfect[0] ? 'under' : p <= P.perfect[1] ? 'perfect' : 'over';
  commitFill(res);
}
function commitFill(res) {
  Fill.result = res; Fill.state = 'processing'; renderMachinePanel();
  const label = { under: ['Le faltó', '#7a7f92'], perfect: ['¡PERFECTO!', '#35b889'], over: ['Se pasó', '#e59a3c'] }[res];
  $('fillResult').innerHTML = `<span style="color:${label[1]}">${label[0]}</span>`;
  if (res === 'perfect') { playSound('sparkle'); S.stats.perfect++; questEvent('perfect', 1); }
  const m = Fill.machine; m.shake = CONFIG.FILL.process; playSound('whirr');
  setTimeout(() => finishFill(), CONFIG.FILL.process * 1000);
}
function popFill() {
  Fill.holding = false; holdBtn.classList.remove('holding'); SFX.fillStop(); Fill.machine.stream.visible = false;
  Fill.state = 'processing'; playSound('pop'); cam.shake = 0.35;
  const m = Fill.machine; burst(m.domeWorld.clone().add(new THREE.Vector3(0, 1.5, 0)), FIL[Fill.filling].color3 || '#F7A7CD', 40);
  if (m.inside) { scene.remove(m.inside.root); m.inside.dispose(); m.inside = null; }
  $('fillResult').innerHTML = '<span style="color:#e0566b">¡POP! Se reventó — demasiado lleno.</span>';
  addXP(1); S.stats.fills++; markDirty();
  setTimeout(() => { Fill.state = 'idle'; Fill.p = 0; renderMachinePanel(); setMachineInside(); }, 1400);
}
function finishFill() {
  const m = Fill.machine; if (!m) return;
  let d;
  if (!S.firstDone) { S.firstDone = true; d = generateSquishy(Fill.species, Fill.filling, 0, { rarity: 'uncommon', variant: 'bubblegum', mutation: 'normal', face: 'happy' }); }
  else d = generateSquishy(Fill.species, Fill.filling, totalLuck(m, Fill.filling, Fill.result), { machine: m });
  S.stats.fills++; questEvent('fill', 1);
  const tier = R[d.rarity].tier;
  if (tier >= 1) questEvent('getUncommon', 1); if (tier >= 2) questEvent('getRare', 1); if (tier >= 3) questEvent('getEpic', 1);
  addXP(R[d.rarity].xp);
  m.lamp.material.emissive.set(R[d.rarity].color); m.lamp.material.emissiveIntensity = 1.4;
  setTimeout(() => { m.lamp.material.emissive.set('#ffe08a'); m.lamp.material.emissiveIntensity = 0.4; }, 3000);
  showReveal(d);
}

// =====================================================================
// PARTICLES (world bursts)
// =====================================================================
const bursts = [];
function burst(pos, color, n = 30) {
  const g = new THREE.BufferGeometry(); const arr = new Float32Array(n * 3); g.setAttribute('position', new THREE.BufferAttribute(arr, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({ color, size: 0.55, transparent: true, depthWrite: false }));
  const vel = []; for (let i = 0; i < n; i++) { arr.set([pos.x, pos.y, pos.z], i * 3); vel.push(new THREE.Vector3(rand(-1, 1), rand(0.3, 1.6), rand(-1, 1)).multiplyScalar(rand(6, 14))); }
  scene.add(pts); bursts.push({ pts, vel, life: 1.2 });
}
function updateBursts(dt) {
  for (let i = bursts.length - 1; i >= 0; i--) {
    const b = bursts[i]; b.life -= dt; const a = b.pts.geometry.attributes.position;
    for (let k = 0; k < b.vel.length; k++) { b.vel[k].y -= 20 * dt; a.setXYZ(k, a.getX(k) + b.vel[k].x * dt, Math.max(0.2, a.getY(k) + b.vel[k].y * dt), a.getZ(k) + b.vel[k].z * dt); }
    a.needsUpdate = true; b.pts.material.opacity = Math.max(0, b.life / 1.2);
    if (b.life <= 0) { scene.remove(b.pts); b.pts.geometry.dispose(); bursts.splice(i, 1); }
  }
}

// =====================================================================
// REVEAL SCREEN
// =====================================================================
const Rev = { renderer: null, scene: null, cam: null, sq: null, t: 0, data: null, fx: [], fxCtx: null, zoom: 0 };
function initReveal() {
  const c = $('revStage');
  Rev.renderer = new THREE.WebGLRenderer({ canvas: c, alpha: true, antialias: true });
  Rev.renderer.outputEncoding = THREE.sRGBEncoding; Rev.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  Rev.scene = new THREE.Scene(); Rev.scene.add(new THREE.HemisphereLight('#ffffff', '#b7a8d8', 0.95));
  const d = new THREE.DirectionalLight('#ffffff', 0.9); d.position.set(3, 5, 6); Rev.scene.add(d);
  const rim = new THREE.DirectionalLight('#ffd1f0', 0.5); rim.position.set(-4, 2, -3); Rev.scene.add(rim);
  Rev.cam = new THREE.PerspectiveCamera(32, 1, 0.1, 50);
  Rev.fxCtx = $('revealFx').getContext('2d');
}
function showReveal(d) {
  UI.open = 'reveal'; Fill.state = 'reveal';
  const tier = R[d.rarity].tier; const isNew = !S.discovered[idxKey(d)];
  const rv = $('reveal'); rv.className = ''; rv.classList.add(d.rarity);
  $('revGot').textContent = 'Te salió…'; $('revRarity').textContent = ''; $('revName').textContent = ''; $('revBadges').innerHTML = ''; $('revBtns').style.visibility = 'hidden';
  if (Rev.sq) { Rev.scene.remove(Rev.sq.root); Rev.sq.dispose(); }
  Rev.sq = buildSquishy(d, { noShadow: true }); Rev.sq.root.scale.set(0.001, 0.001, 0.001); Rev.scene.add(Rev.sq.root);
  Rev.data = d; Rev.t = 0; Rev.fx = []; Rev.zoom = d.rarity === 'legendary' ? 1 : 0;
  const s = Math.min(420, innerHeight * 0.6); Rev.renderer.setSize(s, s, false);
  const fc = $('revealFx'); fc.width = innerWidth; fc.height = innerHeight;
  if (d.rarity === 'secret') { const b = document.createElement('div'); b.className = 'blackout'; document.body.appendChild(b); setTimeout(() => b.remove(), 1000); playSound('secretSting'); }
  rv.classList.remove('hidden');
  const delay = d.rarity === 'secret' ? 900 : 650;
  setTimeout(() => {
    const r = R[d.rarity];
    $('revRarity').textContent = d.rarity === 'secret' ? '¡SECRETO ENCONTRADO!' : '¡' + r.name + '!'; $('revRarity').style.color = r.color; $('revRarity').classList.remove('pop'); void $('revRarity').offsetWidth; $('revRarity').classList.add('pop');
    $('revName').textContent = d.name;
    const badges = []; if (isNew) badges.push('<span class="badge new">¡Squishy nuevo descubierto!</span>');
    if (d.mutation !== 'normal') badges.push(`<span class="badge">${MUT[d.mutation].name}</span>`);
    if (SP[d.species] && SP[d.species].famous) badges.push('<span class="badge">✨ Viral</span>');
    badges.push(`<span class="badge">Vale ${fmt(d.value)} monedas</span>`);
    $('revBadges').innerHTML = badges.join('');
    $('revSell').textContent = `Vender +${fmt(d.value)}`;
    $('revKeep').disabled = S.inventory.length >= capacity();
    $('revBtns').style.visibility = 'visible';
    if (tier === 0) playSound('reward'); else if (tier === 1) { playSound('reward'); playSound('sparkle2'); } else if (tier === 2) { playSound('rare'); playSound('sparkle'); } else if (tier === 3) { playSound('epic'); playSound('sparkle'); } else if (tier === 4) { playSound('fanfare'); player.ch.play('emote-yes', 0.2, true); }
    spawnRevealFx(d.rarity);
  }, delay);
  if (isNew) { S.discovered[idxKey(d)] = 1; questEvent('index', Object.keys(S.discovered).length, true); }
  markDirty();
}
function spawnRevealFx(rar) {
  const W = innerWidth, H = innerHeight, cx = W / 2, cy = H * 0.45; const tier = R[rar].tier; if (tier < 2) return;
  const n = { rare: 40, epic: 80, legendary: 140, secret: 120 }[rar];
  const cols = { rare: ['#bfe0ff', '#ffffff', '#4C9BFF'], epic: ['#e2c6ff', '#A95CFF', '#ffffff'], legendary: ['#FFC83A', '#FF8FA3', '#8BE3A5', '#8BC7E8', '#ffffff', '#B999E8'], secret: ['#000000', '#ff2a6d', '#05d9e8'] }[rar];
  for (let i = 0; i < n; i++) {
    const a = rand(0, Math.PI * 2), sp = rand(2, rar === 'legendary' ? 13 : 8);
    Rev.fx.push({ x: cx, y: cy, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - (rar === 'legendary' ? 5 : 1), life: rand(1.2, 2.6), col: pick(cols), kind: rar === 'legendary' ? (i % 3 ? 'confetti' : 'star') : rar === 'secret' ? 'glitch' : 'spark', rot: rand(0, 6), s: rand(4, 9) });
  }
}
function updateReveal(dt) {
  if (UI.open !== 'reveal' || !Rev.sq) return;
  Rev.t += dt; const t = Rev.t;
  // scale 0 -> 1.15 -> 1 (after the "you got a" beat)
  const k = clamp((t - 0.55) / 0.55, 0, 1); const s = k < 0.6 ? lerp(0, 1.15, k / 0.6) : lerp(1.15, 1, (k - 0.6) / 0.4);
  const base = Rev.data.mutation === 'big' ? 1.3 : Rev.data.mutation === 'tiny' ? 0.7 : 1; Rev.sq.root.scale.setScalar(Math.max(0.001, s * base));
  Rev.sq.root.rotation.y = Math.sin(t * 0.9) * 0.5; Rev.sq.update(dt);
  const h = Math.max(2.0, Rev.sq.dims.h * 1.05, Rev.sq.dims.w * 0.9); const zk = h / 2.1; const z = (Rev.zoom ? lerp(7.4, 6.2, clamp((t - 0.6) / 1.2, 0, 1)) : 7.2) * zk;
  Rev.cam.position.set(0, h * 0.6, z); Rev.cam.lookAt(0, h * 0.42, 0);
  Rev.renderer.render(Rev.scene, Rev.cam);
  const g = Rev.fxCtx; g.clearRect(0, 0, g.canvas.width, g.canvas.height);
  for (let i = Rev.fx.length - 1; i >= 0; i--) {
    const p = Rev.fx[i]; p.life -= dt; if (p.life <= 0) { Rev.fx.splice(i, 1); continue; }
    p.vy += (p.kind === 'confetti' ? 9 : 2) * dt; p.vx *= 0.99; p.x += p.vx * 60 * dt; p.y += p.vy * 60 * dt; p.rot += dt * 5;
    g.globalAlpha = Math.min(1, p.life); g.fillStyle = p.col; g.save(); g.translate(p.x, p.y); g.rotate(p.rot);
    if (p.kind === 'confetti') g.fillRect(-p.s / 2, -p.s / 4, p.s, p.s / 2);
    else if (p.kind === 'star') { g.beginPath(); for (let k2 = 0; k2 < 10; k2++) { const a = k2 * Math.PI / 5, rr = k2 % 2 ? p.s * 0.45 : p.s; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } g.fill(); }
    else if (p.kind === 'glitch') g.fillRect(-p.s, -1.5, p.s * 2 * Math.random() + 2, 3);
    else { g.beginPath(); g.arc(0, 0, p.s / 3, 0, 7); g.fill(); }
    g.restore();
  }
  g.globalAlpha = 1;
}
$('revKeep').addEventListener('click', () => {
  const d = Rev.data; if (!d) return;
  S.inventory.push(d); playSound('keep'); toast(`${d.name} guardado en tu inventario`);
  if (Tut.step <= 3) Tut.advance(4);
  endReveal();
});
$('revSell').addEventListener('click', () => {
  const d = Rev.data; if (!d) return; addCoins(d.value); S.stats.sold++; playSound('coins');
  if (S.inventory.some(s => idxKey(s) === idxKey(d))) questEvent('sellDupe', 1);
  if (Tut.step <= 3) { toast('Tip: ¡guarda el primero para poder equiparlo!'); S.inventory.push(generateSquishy(d.species, d.filling, 0, { rarity: 'uncommon', variant: 'bubblegum', mutation: 'normal', face: 'happy' })); Tut.advance(4); }
  endReveal();
});
function endReveal() {
  $('reveal').classList.add('hidden'); Rev.fx = []; Rev.data = null; markDirty();
  UI.open = 'machine'; Fill.state = 'idle'; Fill.p = 0; setGauge(0);
  if (Fill.machine) { renderMachinePanel(); setMachineInside(); } else UI.open = null;
  if (pedestalsDirty !== undefined) pedestalsDirty = true;
  if (Tut.step === 4) { closeUI(); Tut.promptEquip(); }
}

// =====================================================================
// INVENTORY
// =====================================================================
const Inv = { filter: 'all', sel: null };
function openInventory() { renderInventory(); openOverlay('invWrap', 'inv'); if (Tut.step === 4) $('bInv').classList.remove('pulse'); }
function renderInventory() {
  const tabs = ['all', ...RARITIES.map(r => r.id), 'favorites'];
  $('invTabs').innerHTML = tabs.map(t => `<button class="tab ${Inv.filter === t ? 'on' : ''}" data-f="${t}">${t === 'all' ? 'Todos' : t === 'favorites' ? '★ Favoritos' : R[t].name}</button>`).join('');
  $('invCount').textContent = `${S.inventory.length}/${capacity()}`;
  let list = [...S.inventory].sort((a, b) => b.value - a.value || b.dateFound - a.dateFound);
  if (Inv.filter === 'favorites') list = list.filter(s => s.fav); else if (Inv.filter !== 'all') list = list.filter(s => s.rarity === Inv.filter);
  $('invGrid').innerHTML = list.length ? list.map(s => `<button class="card ${Inv.sel === s.id ? 'on' : ''}" data-id="${s.id}">${s.fav ? '<span class="fav">★</span>' : ''}${S.equipped === s.id ? '<span class="eq">Equipado</span>' : ''}<img src="${Thumbs.get(s)}" alt=""><div class="nm">${esc(s.name)}</div><span class="rr" style="background:${R[s.rarity].color}">${R[s.rarity].name}</span></button>`).join('')
    : `<div class="empty">${S.inventory.length ? 'Nada con este filtro.' : 'Aún no tienes squishies. ¡Ve a las Máquinas y llena el primero!'}</div>`;
  if (!Inv.sel || !S.inventory.find(s => s.id === Inv.sel)) Inv.sel = list[0] ? list[0].id : null;
  renderInvDetail();
}
function renderInvDetail() {
  const s = S.inventory.find(x => x.id === Inv.sel);
  if (!s) { $('invDetail').innerHTML = '<div class="empty" style="padding:20px">Elige un squishy para verlo aquí.</div>'; return; }
  const dupes = S.inventory.filter(x => idxKey(x) === idxKey(s)).length;
  $('invDetail').innerHTML = `<img src="${Thumbs.get(s)}" alt=""><div class="dn">${esc(s.name)}</div>
    <span class="rr" style="background:${R[s.rarity].color};color:#fff;border-radius:8px;padding:2px 10px;font-weight:900;align-self:flex-start">${R[s.rarity].name}</span>
    <div class="kv"><span>Encontrado</span><b>${new Date(s.dateFound).toLocaleDateString('es-CO', { day: 'numeric', month: 'short', year: 'numeric' })}</b></div>
    <div class="kv"><span>Valor</span><b>${fmt(s.value)} monedas</b></div>
    <div class="kv"><span>Relleno</span><b>${FIL[s.filling] ? FIL[s.filling].name : '—'}</b></div>
    <div class="kv"><span>Tamaño</span><b>${(s.size * (MUT[s.mutation].size || 1)).toFixed(2)}×</b></div>
    <div class="kv"><span>Copias</span><b>${dupes}</b></div>
    <button class="btn purple" id="dSquish">🖐️ Apachurrar</button>
    <div class="btnRow" style="margin-top:2px"><button class="btn mint" id="dEquip">${S.equipped === s.id ? 'Quitar' : 'Equipar'}</button><button class="btn" id="dFav">${s.fav ? '★ Quitar fav' : '☆ Favorito'}</button></div>
    <button class="btn yellow" id="dSell" ${s.fav || S.equipped === s.id ? 'disabled' : ''}>Vender por ${fmt(s.value)}</button>`;
  $('dSquish').onclick = () => { $('invWrap').classList.add('hidden'); UI.open = null; Studio.open(s, 'Tuyo'); };
  $('dEquip').onclick = () => { S.equipped = S.equipped === s.id ? null : s.id; refreshCompanion(); playSound('select'); if (S.equipped) { toast(`¡${s.name} te está siguiendo!`); if (Tut.step === 4) Tut.advance(5); } markDirty(); renderInventory(); };
  $('dFav').onclick = () => { s.fav = !s.fav; playSound('toggle'); markDirty(); renderInventory(); };
  $('dSell').onclick = () => sellItems([s]);
}
function sellItems(list) {
  let total = 0, dupe = false;
  for (const s of list) {
    if (s.fav || s.id === S.equipped) continue;
    if (S.inventory.filter(x => idxKey(x) === idxKey(s)).length > 1) dupe = true;
    S.inventory = S.inventory.filter(x => x.id !== s.id); total += s.value; S.stats.sold++;
  }
  if (!total) return;
  addCoins(total); playSound('coins'); toast(`Vendido por ${fmt(total)} monedas`);
  if (dupe) questEvent('sellDupe', 1);
  pedestalsDirty = true; markDirty(); renderInventory();
}
$('invTabs').addEventListener('click', (e) => { const b = e.target.closest('[data-f]'); if (!b) return; Inv.filter = b.dataset.f; playSound('click'); renderInventory(); });
$('invGrid').addEventListener('click', (e) => { const b = e.target.closest('[data-id]'); if (!b) return; Inv.sel = b.dataset.id; playSound('click'); renderInventory(); });
$('sellDupes').addEventListener('click', () => {
  const groups = {}; for (const s of S.inventory) (groups[idxKey(s)] = groups[idxKey(s)] || []).push(s);
  const sell = [];
  for (const g of Object.values(groups)) { if (g.length < 2) continue; g.sort((a, b) => (b.fav - a.fav) || ((b.id === S.equipped) - (a.id === S.equipped)) || b.value - a.value); sell.push(...g.slice(1).filter(s => !s.fav && s.id !== S.equipped)); }
  if (!sell.length) { toast('No tienes repetidos para vender'); playSound('error'); return; }
  if (confirm(`¿Vender ${sell.length} repetido${sell.length > 1 ? 's' : ''} por ${fmt(sell.reduce((a, s) => a + s.value, 0))} monedas? Te quedas con la mejor copia de cada uno.`)) sellItems(sell);
});

// =====================================================================
// SHOP
// =====================================================================
const Shop = { tab: 'fillings' };
function openShop() { renderShop(); openOverlay('shopWrap', 'shop'); }
function renderShop() {
  $('shopTabs').innerHTML = ['molds', 'fillings', 'upgrades'].map(t => `<button class="tab ${Shop.tab === t ? 'on' : ''}" data-t="${t}">${{ molds: '✨ Moldes Virales', fillings: 'Rellenos', upgrades: 'Mejoras' }[t]}</button>`).join('');
  if (Shop.tab === 'molds') {
    $('shopGrid').innerHTML = SPECIES.filter(sp => sp.famous).map(sp => {
      const own = S.molds.includes(sp.id);
      return `<div class="item"><div class="t"><img src="${Thumbs.get({ species: sp.id, variant: 'original', mutation: 'normal' })}" alt="" style="width:58px;height:58px;margin:-6px 0">${sp.name}</div><div class="d">${sp.desc}<br><b style="color:var(--ink)">Slow rise ${sp.rise}s · ${sp.soft >= 1.2 ? 'súper suave' : sp.soft >= 1 ? 'suave' : 'firme'}</b></div>
      <button class="btn ${own ? '' : 'pink'}" data-mold="${sp.id}" ${own || S.coins < sp.price ? 'disabled' : ''}>${own ? 'Tuyo' : `<span class="coin" style="display:inline-block;width:14px;height:14px;vertical-align:-2px"></span> ${fmt(sp.price)}`}</button></div>`;
    }).join('');
  } else if (Shop.tab === 'fillings') {
    $('shopGrid').innerHTML = FILLINGS.filter(f => f.price > 0).map(f => {
      const own = S.fillings.includes(f.id);
      return `<div class="item"><div class="t"><span class="fill" style="padding:0;background:none"><span class="sw" style="background:${f.color};width:26px;height:26px"></span></span>${f.name}</div><div class="d">${f.desc || ''}</div>
      <button class="btn ${own ? '' : 'pink'}" data-buy="${f.id}" ${own || S.coins < f.price ? 'disabled' : ''}>${own ? 'Tuyo' : `<span class="coin" style="display:inline-block;width:14px;height:14px;vertical-align:-2px"></span> ${fmt(f.price)}`}</button></div>`;
    }).join('');
  } else {
    $('shopGrid').innerHTML = Object.entries(UPGRADES).map(([k, u]) => {
      const lvl = k === 'fillSpeed' ? S.upgrades.fillSpeed - 1 : S.upgrades[k];
      const maxed = lvl >= u.costs.length; const cost = u.costs[lvl];
      const cur = k === 'storage' ? `Guarda ${u.caps[lvl]}${maxed ? '' : ` → ${u.caps[lvl + 1]}`}` : k === 'luck' ? `+${lvl * 6}% suerte${maxed ? '' : ` → +${(lvl + 1) * 6}%`}` : `Velocidad ${lvl + 1}${maxed ? '' : ` → ${lvl + 2}`}`;
      return `<div class="item"><div class="t">${u.name}</div><div class="d">${u.desc}<br><b style="color:var(--ink)">${cur}</b></div><div class="lv">${u.costs.map((_, i) => `<i class="${i < lvl ? 'f' : ''}"></i>`).join('')}</div>
      <button class="btn ${maxed ? '' : 'mint'}" data-up="${k}" ${maxed || S.coins < cost ? 'disabled' : ''}>${maxed ? 'Nivel máximo' : `<span class="coin" style="display:inline-block;width:14px;height:14px;vertical-align:-2px"></span> ${fmt(cost)}`}</button></div>`;
    }).join('');
  }
}
$('shopTabs').addEventListener('click', (e) => { const b = e.target.closest('[data-t]'); if (!b) return; Shop.tab = b.dataset.t; playSound('click'); renderShop(); });
$('shopGrid').addEventListener('click', (e) => {
  const b = e.target.closest('button'); if (!b || b.disabled) return;
  if (b.dataset.buy) { const f = FIL[b.dataset.buy]; if (S.coins < f.price) return; addCoins(-f.price); S.fillings.push(f.id); playSound('coins'); toast(`¡Relleno ${f.name} desbloqueado!`, true); }
  if (b.dataset.mold) { const sp = SP[b.dataset.mold]; if (S.coins < sp.price || S.molds.includes(sp.id)) return; addCoins(-sp.price); S.molds.push(sp.id); playSound('coins'); playSound('sparkle'); toast(`¡Molde viral ${sp.name} desbloqueado! Úsalo en cualquier máquina.`, true, 3200); }
  if (b.dataset.up) {
    const k = b.dataset.up, u = UPGRADES[k]; const lvl = k === 'fillSpeed' ? S.upgrades.fillSpeed - 1 : S.upgrades[k]; const cost = u.costs[lvl];
    if (cost == null || S.coins < cost) return; addCoins(-cost);
    if (k === 'fillSpeed') { S.upgrades.fillSpeed++; questEvent('upFill', 1); } else S.upgrades[k]++;
    playSound('levelup'); toast(`¡${u.name} mejorada!`, true);
  }
  markDirty(); renderShop();
});

// =====================================================================
// INDEX
// =====================================================================
const Idx = { sp: 'cat' };
const INDEX_TOTAL = SPECIES.reduce((a, sp) => a + variantsFor(sp.id).length, 0);
function openIndex() { renderIndex(); openOverlay('indexWrap', 'index'); }
function renderIndex() {
  const n = Object.keys(S.discovered).length;
  $('idxCount').textContent = `${n} / ${INDEX_TOTAL}`; $('idxSub').textContent = 'descubiertos — las siluetas siguen siendo un misterio';
  $('idxTabs').innerHTML = SPECIES.map(sp => { const vs = variantsFor(sp.id); const c = vs.filter(v => S.discovered[sp.id + '|' + v]).length; return `<button class="tab ${Idx.sp === sp.id ? 'on' : ''} ${sp.famous ? 'viral' : ''}" data-sp="${sp.id}">${sp.famous ? '✨ ' : ''}${sp.name} <span style="opacity:.6">${c}/${vs.length}</span></button>`; }).join('');
  const items = variantsFor(Idx.sp).map(v => VAR[v]);
  $('idxGrid').innerHTML = items.map(v => {
    const known = S.discovered[Idx.sp + '|' + v.id];
    return `<div class="idx ${known ? '' : 'unk'}" style="border-top-color:${R[v.rarity].color}"><img data-src="${Idx.sp}|${v.id}|${known ? 1 : 0}" alt=""><div class="nm">${known ? esc(squishyName({ species: Idx.sp, variant: v.id, mutation: 'normal' })) : '???'}</div></div>`;
  }).join('');
  // render thumbnails progressively (keeps UI responsive)
  const imgs = [...$('idxGrid').querySelectorAll('img[data-src]')]; let i = 0;
  const step = () => { const end = Math.min(imgs.length, i + 6); for (; i < end; i++) { const [sp, v, k] = imgs[i].dataset.src.split('|'); imgs[i].src = Thumbs.get({ species: sp, variant: v, mutation: 'normal', rarity: VAR[v].rarity }, k === '0'); } if (i < imgs.length && UI.open === 'index') requestAnimationFrame(step); };
  requestAnimationFrame(step);
}
$('idxTabs').addEventListener('click', (e) => { const b = e.target.closest('[data-sp]'); if (!b) return; Idx.sp = b.dataset.sp; playSound('click'); renderIndex(); });

// =====================================================================
// NPC CHAT
// =====================================================================
const Chat = { n: null, busy: false };
function openNPC(n) {
  Chat.n = n; n.talking = true; n.ch.play('emote-yes', 0.2, true);
  if (!n.chat.length) n.chat.push({ me: false, text: pick([`¡Holi! Soy ${n.def.name} 👋`, `¡Hola! ¡Mucho gusto!`, `¡Ey! ¿Quieres ver mi ${n.sqd.name}? Puedes apachurrarlo 😄`]) });
  $('npcName').textContent = n.def.name; $('npcSub').textContent = `Presumiendo: ${n.sqd.name} · ${R[n.sqd.rarity].name}`;
  $('npcAv').style.backgroundImage = `url(${Thumbs.get(n.sqd)})`;
  $('aiNote').textContent = AI.state === 'ready' ? 'Los jugadores de aquí funcionan con Claude: chatea, pide tips o negocia.' : 'Chat en modo offline (respuestas predefinidas).';
  renderChat(); openOverlay('npcWrap', 'npc'); setTimeout(() => $('chatIn').focus(), 50);
}
function renderChat() {
  const n = Chat.n; $('chatLog').innerHTML = n.chat.map(m => `<div class="msg ${m.me ? 'me' : 'them'}">${esc(m.text)}</div>`).join('') + (Chat.busy ? '<div class="msg them typing">escribiendo…</div>' : '');
  $('chatLog').scrollTop = 1e6;
}
async function sendChat() {
  const n = Chat.n; const text = $('chatIn').value.trim(); if (!n || !text || Chat.busy) return;
  $('chatIn').value = ''; n.chat.push({ me: true, text }); Chat.busy = true; renderChat(); playSound('click');
  let out;
  try { out = (AI.sample && !AI.denied) ? await npcAIReply(n, text) : scriptedReply(n, text); }
  catch (e) {
    if (e && (e.code === 'not_granted')) { AI.denied = true; $('aiNote').textContent = 'Chat con IA apagado (sin permiso). Usando respuestas predefinidas.'; }
    out = scriptedReply(n, text);
  }
  Chat.busy = false;
  const say = String(out.say || '…').slice(0, 220);
  n.chat.push({ me: false, text: say }); npcSay(n, say, 5); playSound('npc', { vol: 0.35 });
  if (out.emote === 'yes') n.ch.play('emote-yes', 0.2, true); else if (out.emote === 'no') n.ch.play('emote-no', 0.2, true); else if (out.emote === 'wave') n.ch.play('interact-right', 0.2, true);
  if (out.wantsTrade) { $('npcTradeBtn').classList.add('pulse'); setTimeout(() => $('npcTradeBtn').classList.remove('pulse'), 4000); }
  if (UI.open === 'npc' && Chat.n === n) renderChat();
}
$('chatSend').addEventListener('click', sendChat);
$('chatIn').addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); sendChat(); } e.stopPropagation(); });
$('npcTradeBtn').addEventListener('click', () => { const n = Chat.n; $('npcWrap').classList.add('hidden'); UI.open = null; openTrade(n); });
$('npcSquishBtn').addEventListener('click', () => { const n = Chat.n; $('npcWrap').classList.add('hidden'); UI.open = null; n.talking = false; Studio.open(squishDataOf(n.sq), 'De ' + n.def.name, n.sq); });

// =====================================================================
// TRADING (simulated)
// =====================================================================
const Trade = { n: null, mine: [], theirs: [], rerolls: 0 };
function openTrade(n) {
  Trade.n = n; n.talking = true; Trade.mine = []; Trade.theirs = []; Trade.rerolls = 0;
  $('trWho').textContent = n.def.name; $('trMsg').textContent = S.inventory.length ? 'Elige lo que quieres ofrecer.' : '¡Todavía no tienes nada para cambiar!';
  renderTrade(); openOverlay('tradeWrap', 'trade');
}
function npcOffer() {
  const myVal = Trade.mine.reduce((a, id) => a + (S.inventory.find(s => s.id === id) || { value: 0 }).value, 0);
  if (!myVal) { Trade.theirs = []; return; }
  const target = myVal * rand(0.85, 1.35);
  let best = null, bd = Infinity;
  for (let i = 0; i < 60; i++) {
    const rar = weightedPick(RARITIES, r => Math.abs(Math.log((SP.cat.baseValue * r.mult) / target)) < 1.6 ? 1 : 0.02).id;
    const d = generateSquishy(Math.random() < 0.5 ? Trade.n.def.fav : pick(SPECIES).id, 'classic_foam', 0, { rarity: rar });
    const diff = Math.abs(d.value - target); if (diff < bd) { bd = diff; best = d; }
  }
  Trade.theirs = [best];
}
function renderTrade() {
  const mineItems = Trade.mine.map(id => S.inventory.find(s => s.id === id)).filter(Boolean);
  const myVal = mineItems.reduce((a, s) => a + s.value, 0), theirVal = Trade.theirs.reduce((a, s) => a + s.value, 0);
  $('trMine').innerHTML = [0, 1, 2].map(i => mineItems[i] ? `<div class="slot filled" data-rm="${mineItems[i].id}"><img src="${Thumbs.get(mineItems[i])}" alt="">${esc(mineItems[i].name)}</div>` : '<div class="slot">Vacío</div>').join('');
  $('trTheirs').innerHTML = Trade.theirs.length ? Trade.theirs.map(s => `<div class="slot filled"><img src="${Thumbs.get(s)}" alt="">${esc(s.name)}<span style="color:${R[s.rarity].color}">${R[s.rarity].name}</span></div>`).join('') : '<div class="slot">Esperando tu oferta…</div>';
  $('trMyVal').textContent = myVal ? fmt(myVal) + ' 🪙' : ''; $('trTheirVal').textContent = theirVal ? fmt(theirVal) + ' 🪙' : '';
  const ratio = theirVal ? myVal / theirVal : 0; const pct = clamp(ratio / 1.5, 0, 1) * 100;
  $('trMeter').style.width = pct + '%'; $('trMeter').style.background = ratio >= 1.15 ? '#FFC83A' : ratio >= 0.8 ? '#9CE0CA' : '#ff9aa8';
  $('trHint').textContent = !theirVal ? '' : ratio >= 1.15 ? 'Súper trato para ellos: van a decir que sí.' : ratio >= 0.8 ? 'Cambio justo: seguramente aceptan.' : 'Quieren más. Agrega otro squishy.';
  const avail = S.inventory.filter(s => s.id !== S.equipped).sort((a, b) => b.value - a.value);
  $('trInv').innerHTML = avail.length ? avail.map(s => `<button class="mini ${Trade.mine.includes(s.id) ? 'in' : ''}" data-add="${s.id}"><img src="${Thumbs.get(s)}" alt="">${esc(s.name)}</button>`).join('') : '<div class="empty">No tienes squishies para ofrecer (el equipado se queda contigo).</div>';
  $('trAccept').disabled = !mineItems.length || !Trade.theirs.length;
  $('trReroll').disabled = !mineItems.length || Trade.rerolls >= 3;
}
$('trInv').addEventListener('click', (e) => {
  const b = e.target.closest('[data-add]'); if (!b) return; const id = b.dataset.add;
  if (Trade.mine.includes(id)) Trade.mine = Trade.mine.filter(x => x !== id); else if (Trade.mine.length < 3) Trade.mine.push(id); else { playSound('error'); return; }
  playSound('click'); npcOffer(); renderTrade();
  if (Trade.theirs[0]) $('trMsg').textContent = `${Trade.n.def.name}: "¿Qué tal mi ${Trade.theirs[0].name}?"`;
});
$('trMine').addEventListener('click', (e) => { const b = e.target.closest('[data-rm]'); if (!b) return; Trade.mine = Trade.mine.filter(x => x !== b.dataset.rm); npcOffer(); renderTrade(); });
$('trReroll').addEventListener('click', () => { Trade.rerolls++; npcOffer(); playSound('select'); renderTrade(); $('trMsg').textContent = `${Trade.n.def.name}: "Bueno, ¿y este?"`; });
$('trAccept').addEventListener('click', () => {
  const mineItems = Trade.mine.map(id => S.inventory.find(s => s.id === id)).filter(Boolean);
  const myVal = mineItems.reduce((a, s) => a + s.value, 0), theirVal = Trade.theirs.reduce((a, s) => a + s.value, 0);
  const n = Trade.n;
  if (myVal >= theirVal * 0.8) {
    S.inventory = S.inventory.filter(s => !Trade.mine.includes(s.id));
    for (const t of Trade.theirs) { t.id = uid(); t.dateFound = Date.now(); S.inventory.push(t); if (!S.discovered[idxKey(t)]) { S.discovered[idxKey(t)] = 1; toast(`Nuevo en tu Índice: ${t.name}`); } }
    S.stats.trades++; questEvent('trade', 1); questEvent('index', Object.keys(S.discovered).length, true);
    playSound('reward'); playSound('coins'); n.ch.play('emote-yes', 0.2, true); npcSay(n, pick(['¡Trato hecho! 🤝', '¡Un gusto cambiar contigo!', 'GG, ¡buen cambio!']), 4);
    toast(`¡Intercambio listo! Recibiste ${Trade.theirs.map(t => t.name).join(', ')}`, true);
    pedestalsDirty = true; markDirty(); closeUI();
  } else {
    playSound('error'); n.ch.play('emote-no', 0.2, true); $('trMsg').textContent = `${n.def.name}: "Mmm, eso no alcanza para mi ${Trade.theirs[0].name}."`;
  }
});

// =====================================================================
// QUESTS + TUTORIAL
// =====================================================================
function currentQuest() {
  const i = S.quest.i;
  if (i < QUESTS.length) return QUESTS[i];
  const k = i - QUESTS.length + 1; // endless repeatable chain
  return { id: 'loop' + k, title: `Llena ${5 + k * 5} squishies`, goal: 5 + k * 5, ev: 'fill', reward: 500 + k * 250, target: 'machines' };
}
function questEvent(ev, amount, absolute = false) {
  const q = currentQuest(); if (q.ev !== ev) return;
  S.quest.p = absolute ? Math.max(S.quest.p, amount) : S.quest.p + amount;
  if (S.quest.p >= q.goal) {
    setTimeout(() => { toast(`Misión completa: ${q.title} · +${fmt(q.reward)} monedas`, true, 3200); playSound('reward'); }, 400);
    S.coins += q.reward; S.quest.i++; S.quest.p = 0;
    const nq = currentQuest(); // auto-complete level/index quests already satisfied
    if (nq.ev === 'level') S.quest.p = S.level; if (nq.ev === 'index') S.quest.p = Object.keys(S.discovered).length;
    if (S.quest.p >= nq.goal) { const g = nq.goal; setTimeout(() => questEvent(nq.ev, g, true), 600); }
  }
  updateHUD(); markDirty();
}
function updateQuestCard() {
  const q = currentQuest(); const p = Math.min(S.quest.p, q.goal);
  $('questTitle').textContent = q.title; $('questFill').style.width = (p / q.goal * 100) + '%';
  $('questProg').textContent = `${p} / ${q.goal}`; $('questReward').textContent = `Premio: ${fmt(q.reward)} monedas`;
  $('questGuide').classList.toggle('hidden', !q.target);
}
$('questGuide').addEventListener('click', () => { const q = currentQuest(); if (q.target) guideTo(q.target); canvas.focus(); });

const Tut = {
  get step() { return S.tutorial; },
  advance(n) { if (S.tutorial >= n) return; S.tutorial = n; markDirty(); this.show(); },
  show() {
    const s = S.tutorial;
    if (s === 0) { toast('¡Bienvenido a Squishy World!', true, 3500); setTimeout(() => toast('Hagamos tu primer squishy. Sigue la flecha rosada hasta las Máquinas. 🖐️ Por el camino, mantén clic sobre los squishies de la Vitrina Viral para apachurrarlos.', false, 5500), 1200); guideTo('machines'); }
    if (s === 1) guideTo('machines');
    if (s === 5) { toast('Tu squishy ya te sigue. ¡Mantén clic encima para apachurrarlo, o presiona F para verlo de cerca!', false, 4500); setTimeout(() => toast('Las misiones de la derecha dan monedas. ¡A jugar!'), 2800); guide.target = null; }
  },
  onMachineOpen() { if (S.tutorial < 3) { S.tutorial = 3; guide.target = null; toast('El molde Gato y la Espuma Rosa están listos. ¡Mantén el botón y suelta en la zona verde Perfecto!', false, 5000); } },
  promptEquip() { toast('¡Squishy nuevo! Ahora equípalo.', true, 3200); setTimeout(() => toast('Abre tu Inventario (I) y presiona Equipar.'), 1400); $('bInv').classList.add('pulse'); },
};

// =====================================================================
// COLLECTION PEDESTALS
// =====================================================================
var pedestalsDirty = true;
function refreshPedestals() {
  pedestalsDirty = false;
  for (const p of world.pedestals) {
    const best = S.inventory.filter(s => s.rarity === p.rarity).sort((a, b) => b.value - a.value)[0];
    const key = best ? best.id : 'none';
    if (p.key === key) continue; p.key = key;
    if (p.sq) { scene.remove(p.sq.root); p.sq.dispose(); const i = clickables.indexOf(p.sq); if (i >= 0) clickables.splice(i, 1); p.sq = null; }
    if (p.holo) { scene.remove(p.holo); p.holo = null; }
    if (best) { p.sq = buildSquishy(best); p.sq.ownerLabel = 'Tu colección'; p.sq.root.position.copy(p.pos); p.sq.root.scale.multiplyScalar(1.1 * Math.min(1, 2.4 / Math.max(p.sq.dims.h, p.sq.dims.w * 0.9))); scene.add(p.sq.root); clickables.push(p.sq); }
    else {
      const h = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 2.4), new THREE.MeshBasicMaterial({ map: textTex([{ t: '?', size: 150, color: R[p.rarity].color }], { w: 200, h: 200, bg: 'rgba(255,255,255,0.0)' }), transparent: true, depthWrite: false }));
      h.position.copy(p.pos).add(new THREE.Vector3(0, 1.4, 0)); scene.add(h); p.holo = h;
    }
  }
}

// =====================================================================
// MAIN LOOP
// =====================================================================
let last = performance.now(), T = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000); last = now; T += dt;
  // fill progress
  if (Fill.state === 'filling' && Fill.machine) {
    if (Fill.holding) {
      const time = CONFIG.FILL.baseTime / (1 + 0.2 * (S.upgrades.fillSpeed - 1));
      Fill.p += dt / time * (1 + Fill.p * 0.35); SFX.fillSet(Fill.p); setGauge(Fill.p);
      if (Fill.p >= CONFIG.FILL.pop) popFill();
    }
    const m = Fill.machine; if (m.inside) { const s = 0.35 + Math.min(Fill.p, 1.2) * 0.6; m.inside.root.scale.setScalar(s * (m.inside.fitK || 1) * (1 + (Fill.holding ? Math.sin(T * 30) * 0.02 : 0))); m.inside.mat.opacity = 0.55 + Math.min(Fill.p, 1) * 0.45; if (Fill.holding && Math.random() < dt * 8) m.inside.squish(0.15); }
    setLiquid(m, 1 - Math.min(Fill.p, 1) * 0.8);
    m.stream.position.set(0, 6.05 + 3.6 / 2 + 1.1, 0); m.stream.scale.y = 3.6; m.stream.position.y = 7.8;
  }
  for (const m of world.machines) {
    if (m.shake > 0) { m.shake -= dt; m.group.position.x = m.pos.x + Math.sin(T * 60) * 0.12; m.group.rotation.z = Math.sin(T * 45) * 0.012; if (m.inside) m.inside.root.rotation.y += dt * 8; }
    else { m.group.position.x = m.pos.x; m.group.rotation.z = 0; }
    if (m.inside) m.inside.update(dt);
  }
  updatePlayer(dt); updateCompanion(dt, T); updateNPCs(dt, T); updateCamera(dt); updateGuide(T); updateBursts(dt);
  world.statue.update(dt); world.statue.root.rotation.y += dt * 0.25;
  for (const f of world.animated) f(T, dt);
  for (const p of world.pedestals) if (p.sq) { p.sq.update(dt); p.sq.root.rotation.y += dt * 0.6; } else if (p.holo) { p.holo.position.y = p.pos.y + 1.4 + Math.sin(T * 2) * 0.2; p.holo.quaternion.copy(camera.quaternion); }
  if (pedestalsDirty) refreshPedestals();
  updatePrompt(); updateLabels(); updateReveal(dt); updateSquishWorld(dt);
  if (saveTimer > 0) { saveTimer -= dt; if (saveTimer <= 0) saveGame(); }
  if (UI.open !== 'studio') renderer.render(scene, camera); window.__rinfo = { calls: renderer.info.render.calls, tris: renderer.info.render.triangles, geo: renderer.info.memory.geometries };
  adaptQuality(dt);
}
// Auto-quality: if the PC can't hold ~45 FPS, lower resolution first, then shadows.
const AQ = { acc: 0, n: 0, step: 0, pr: renderer.getPixelRatio() };
function adaptQuality(dt) {
  if (document.hidden) return;
  AQ.acc += dt; AQ.n++;
  if (AQ.acc < 3) return;
  const fps = AQ.n / AQ.acc; AQ.acc = 0; AQ.n = 0;
  if (fps < 45 && AQ.step < 3) {
    AQ.step++;
    if (AQ.step === 1) { AQ.pr = Math.max(1, AQ.pr * 0.75); renderer.setPixelRatio(AQ.pr); }
    else if (AQ.step === 2) { sun.shadow.mapSize.set(1024, 1024); if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; } renderer.shadowMap.type = THREE.PCFShadowMap; renderer.shadowMap.needsUpdate = true; }
    else { renderer.setPixelRatio(0.75); }
    renderer.setSize(innerWidth, innerHeight, false);
  }
}
addEventListener('resize', () => { renderer.setSize(innerWidth, innerHeight, false); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); });

// side menu
$('bInv').addEventListener('click', () => { if (!UI.open) openInventory(); });
$('bCol').addEventListener('click', () => { if (!UI.open) openIndex(); });
$('bShop').addEventListener('click', () => { if (!UI.open) openShop(); });
$('bTrade').addEventListener('click', () => { guideTo('trading', 'Sigue la flecha hasta la Plaza de Intercambio'); canvas.focus(); });
$('muteBtn').addEventListener('click', () => { S.muted = !S.muted; SFX.muted = S.muted; updateHUD(); markDirty(); canvas.focus(); });

// =====================================================================
// BOOT
// =====================================================================
async function boot() {
  try {
    await loadAssets();
    buildWorld(); initPlayer(); initNPCs(); initReveal(); refreshMachineLocks();
    const had = loadGame(); SFX.muted = S.muted;
    if (had && S.tutorial >= 1) { player.pos.set(0, 0, 18); }
    clickables.push(world.statue); refreshCompanion(); updateHUD();
    cam.pos.set(0, 12, 4); cam.look.set(0, 5, 20);
    requestAnimationFrame((t) => { last = t; frame(t); });
    $('loadTxt').textContent = had ? '¡Bienvenido de vuelta! Tu progreso está guardado.' : 'Llena squishies, colecciona los raros, apachúrralos y presúmelos.';
    $('introKeys').classList.remove('hidden'); $('playBtn').classList.remove('hidden'); $('playBtn').focus();
    window.__sw = { S, world, npcs, player, Fill, generateSquishy, openMachine, holdStart, holdEnd, cam, Thumbs, showReveal, openInventory, closeUI, UI, T: () => T, Studio, WorldPress, Aim, Tour: () => Tour, camera, pickSquishy, squishTargets, WAX_PIECES };
  } catch (e) {
    console.error(e); $('loadTxt').textContent = 'No se pudo iniciar el juego: ' + (e && e.message ? e.message : e);
  }
}
$('playBtn').addEventListener('click', async () => {
  $('intro').classList.add('hidden'); $('hud').classList.remove('hidden'); canvas.focus();
  SFX.init().then(() => playSound('open'));
  const begin = () => {
    if (S.tutorial === 0) Tut.show(); else { toast('¡Bienvenido de vuelta a Squishy World!', true); const q = currentQuest(); if (q.target && S.tutorial < 5) guideTo('machines'); }
    if (S.tutorial === 4) Tut.promptEquip();
  };
  // la primera vez: tour cinemático por todo el mundo (se puede repetir con el botón 🎬 Tour)
  if (!S.tourSeen) setTimeout(() => Tour.play(() => { S.tourSeen = 1; markDirty(); begin(); }), 350); else begin();
});

