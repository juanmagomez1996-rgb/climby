// Una Vida en 20 Minutos — minijuegos («momentos»).
// Cada momento define: dur, start(M), down/move/up(M, x, y), update(M, dt), result(M, ok), draw(M, t).
// El motor (game.js) llama a api.end(M, ok) para cerrarlo; result() aplica premios y mensajes.
window.makeMoments = api => {
  const { W, SY, SB, GY, PX, COLS } = api;
  const TAU = Math.PI * 2, rand = (a, b) => a + Math.random() * (b - a), clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const GREEN = '#6c9a3c', BROWN = '#8c6a4a', RED = '#e2574c', ACC = '#e0673c';
  const hitsObj = (M, x, y, r = 60) => M.objs.find(o => o.live && M.t >= (o.d || 0) && Math.hypot(x - o.x, y - o.y) < r);
  const win = (s, fx, col = GREEN, size = 34) => { api.float(s, W / 2, SY + 170, col, size); if (fx) api.apply(fx); api.sfx('good'); };
  const lose = (s, fx, col = BROWN, size = 30) => { api.float(s, W / 2, SY + 170, col, size); if (fx) api.apply(fx); api.sfx('bad'); };
  const dim = (a = 0.35) => { api.ctx.fillStyle = `rgba(43,29,20,${a})`; api.ctx.fillRect(0, SY, W, SB - SY); };

  const D = {
    // ---------------- los de siempre ----------------
    pelota: {
      dur: 3.2,
      start(M) { M.o = { x: W + 30, y: SY + 160, vx: -300, vy: -80, rot: 0 }; },
      down(M, x, y) { const o = M.o; if (!o.got && Math.hypot(x - o.x, y - o.y) < 80) { o.got = 1; api.burst(o.x, o.y, '#ffd35a', 20); api.sfx('good'); api.apply([2, 0, 5, 0]); api.float('¡La cogiste!', PX, GY - 250, GREEN); } },
      update(M, dt) {
        const o = M.o;
        if (!o.got) { o.x += o.vx * dt; o.vy += 220 * dt; o.y += o.vy * dt; o.rot -= dt * 6; if (o.x < -40 || o.y > SB) api.end(M, false); }
        else { o.x += (PX + 34 - o.x) * 0.3; o.y += (GY - api.curH() * 0.55 - o.y) * 0.3; if (M.t > M.dur) api.end(M, true); }
      },
      result(M, ok) { if (!ok) { api.float('Se te escapa', PX, GY - 250, BROWN); api.apply([0, 0, -3, 0]); } },
      draw(M) { api.item('ball', M.o.x, M.o.y, 64, { rot: M.o.rot }); },
    },
    monedas: {
      start(M) { M.objs = []; for (let i = 0; i < 5; i++) M.objs.push({ x: rand(80, W - 80), y: SB + 30, vy: -rand(620, 760), d: i * 0.32, live: 1 }); },
      down(M, x, y) { const o = hitsObj(M, x, y); if (o) { o.live = 0; M.got++; api.burst(o.x, o.y, COLS[1], 14); api.sfx('pick1'); api.apply([0, 3, 0, 0]); } },
      move(M, x, y) { this.down(M, x, y); },
      update(M, dt) {
        for (const o of M.objs) { if (!o.live || M.t < o.d) continue; o.vy += 900 * dt; o.y += o.vy * dt; if (o.y > SB + 40 && o.vy > 0) o.live = 0; }
        if (M.t > 0.5 && M.objs.every(o => !o.live)) api.end(M, M.got === M.objs.length);
      },
      result(M, ok) { if (ok) win('¡Perfecto!', [0, 5, 2, 0], GREEN, 38); },
      draw(M, t) { for (const o of M.objs) if (o.live && M.t >= o.d) api.item('coin', o.x, o.y, 72, { rot: Math.sin(t * 5 + o.d) * 0.2 }); },
    },
    corazones: {
      start(M) { M.objs = []; for (let i = 0; i < 4; i++) M.objs.push({ x: rand(80, W - 80), y: SB + 30, d: i * 0.45, live: 1 }); },
      down(M, x, y) { const o = hitsObj(M, x, y); if (o) { o.live = 0; M.got++; api.burst(o.x, o.y, COLS[0], 14); api.sfx('pick3'); api.apply([0, 0, 1, 3]); } },
      move(M, x, y) { this.down(M, x, y); },
      update(M, dt) {
        for (const o of M.objs) { if (!o.live || M.t < o.d) continue; o.y -= 200 * dt; o.x += Math.sin(M.t * 3 + o.d * 5) * 40 * dt; if (o.y < SY - 30) o.live = 0; }
        if (M.t > 0.5 && M.objs.every(o => !o.live)) api.end(M, M.got === M.objs.length);
      },
      result(M, ok) { if (ok) win('¡Perfecto!', [0, 0, 3, 3], GREEN, 38); },
      draw(M, t) { for (const o of M.objs) if (o.live && M.t >= o.d) api.item('heart', o.x, o.y, 72, { rot: Math.sin(t * 5 + o.d) * 0.2 }); },
    },
    ritmo: {
      dur: 4.6,
      start(M) { M.beats = [0, 1, 2, 3].map(i => ({ t: 0.7 + i * 0.95, hit: 0 })); },
      down(M) {
        const b = M.beats.find(b => !b.hit && Math.abs(M.t - b.t) < 0.45); if (!b) return;
        const d = Math.abs(M.t - b.t); b.hit = d < 0.13 ? 2 : d < 0.25 ? 1 : -1;
        if (b.hit > 0) { M.got += b.hit; api.burst(W / 2, SY + 300, RED, b.hit * 10); api.sfx('pick3'); api.float(b.hit === 2 ? '¡Perfecto!' : '¡Bien!', W / 2, SY + 180, ACC); }
        else { api.sfx('bad'); api.float('Pisotón', W / 2, SY + 180, BROWN); }
      },
      update(M) { for (const b of M.beats) if (!b.hit && M.t - b.t > 0.45) b.hit = -1; if (M.t > M.dur) api.end(M, M.got >= 6); },
      result(M, ok) { if (ok) win(M.title.includes('BATER') ? '¡Qué ritmo!' : '¡Bailas de maravilla!', [0, 0, 6, 8]); else if (M.got <= 2) lose('Pisas a todo el mundo', [0, 0, -3, -3]); },
      draw(M, t) {
        const c = api.ctx, cx = W / 2, cy = SY + 300, next = M.beats.find(b => !b.hit);
        api.item('heart', cx, cy, 90 + Math.sin(t * 10) * 4);
        if (next) { const k = clamp((next.t - M.t) / 0.9, 0, 1); c.strokeStyle = ACC; c.lineWidth = 8; c.globalAlpha = 1 - k * 0.6; c.beginPath(); c.arc(cx, cy, 48 + k * 150, 0, TAU); c.stroke(); c.globalAlpha = 1; }
        c.strokeStyle = 'rgba(255,248,236,.7)'; c.lineWidth = 3; c.setLineDash([8, 8]); c.beginPath(); c.arc(cx, cy, 48, 0, TAU); c.stroke(); c.setLineDash([]);
        M.beats.forEach((b, i) => api.item('heart', cx - 75 + i * 50, cy + 130, 32, { alpha: b.hit > 0 ? 1 : b.hit < 0 ? 0.2 : 0.45 }));
      },
    },
    informe: {
      dur: 3.4,
      start(M) { M.n = 16; },
      down(M) { M.got++; api.sfx('tap'); api.dust(rand(200, 340), SY + 420, 2); if (M.got >= M.n) api.end(M, true); },
      update(M) { if (M.t > M.dur) api.end(M, false); },
      result(M, ok) {
        const run = M.title.includes('MARAT');
        if (ok) win(run ? '¡Maratón terminada!' : '¡Entregado a tiempo!', run ? [10, 0, 5, 0] : [0, 10, -2, 0]);
        else lose(run ? 'Te retiras en el km 30' : 'Llega tarde. Otra vez.', run ? [-3, 0, -3, 0] : [0, -4, -4, 0]);
      },
      draw(M) {
        const k = M.got / M.n, run = M.title.includes('MARAT');
        for (let i = 0; i < Math.min(M.got, M.n); i++) api.item(run ? 'trophy' : 'bills', W / 2 + Math.sin(i * 7) * 8, SY + 470 - i * 9, run ? 44 : 60, { rot: Math.sin(i * 3) * 0.1 });
        api.rrect(110, SY + 520, 320, 26, 12, '#fff8ec', '#3b2416', 3); api.rrect(110, SY + 520, 320 * k, 26, 12, COLS[1]);
        api.text(`${M.got}/${M.n}`, W / 2, SY + 533, { size: 22 });
      },
    },
    equilibrio: {
      dur: 3.8, tilt: 1,
      start(M) { M.x = rand(-0.15, 0.15); M.v = 0; M.k = api.G.age > 60 ? 1.35 : 1; },
      down(M, x) { M.v += (x < W / 2 ? -1 : 1) * 0.55; },
      update(M, dt) {
        M.v += (M.x * 2.4 * M.k + rand(-2.6, 2.6) * M.k + api.keyPush() * 4) * dt; M.v *= 0.985; M.x += M.v * dt;
        if (Math.abs(M.x) >= 1) api.end(M, false); else if (M.t > M.dur) api.end(M, true);
      },
      result(M, ok) {
        const baby = M.id === 'bebe';
        if (ok) win(baby ? '¡Se ha dormido!' : '¡Equilibrio perfecto!', baby ? [0, 0, 5, 8] : [6, 0, 2, 0]);
        else { lose(baby ? 'Llora aún más fuerte' : '¡Te caes de culo!', null, RED, 32); api.apply(baby ? [-2, 0, -4, -2] : [-8, 0, -3, 0], 'una caída tonta'); api.stumble(); }
      },
      draw(M, t) {
        const y = SY + 170, c = api.ctx;
        api.rrect(120, y, 300, 20, 10, '#fff8ec', '#3b2416', 3);
        c.fillStyle = 'rgba(140,193,82,.6)'; c.fillRect(W / 2 - 60, y + 3, 120, 14);
        c.fillStyle = ACC; c.beginPath(); c.arc(W / 2 + M.x * 150, y + 10, 14, 0, TAU); c.fill();
        api.text('◀', 60, SY + 400, { size: 60, color: 'rgba(255,248,236,.6)' }); api.text('▶', W - 60, SY + 400, { size: 60, color: 'rgba(255,248,236,.6)' });
        if (M.id === 'bebe') { api.item('rattle', PX + 70, GY - api.curH() * 0.6, 50, { rot: Math.sin(t * 9) * 0.5 }); api.text('zZz', PX + 60, GY - api.curH() - 20 + Math.sin(t * 3) * 6, { size: 30, color: '#fff8ec', stroke: '#3b2416', sw: 5 }); }
      },
    },

    // ---------------- nuevos ----------------
    // Soplar las velas en los cumpleaños redondos: pasa el dedo por las llamas.
    velas: {
      dur: 5, hideRunner: 1,
      start(M) {
        const n = clamp(Math.floor(api.G.age / 10), 1, 9); M.objs = [];
        for (let i = 0; i < n; i++) M.objs.push({ x: W / 2 - (n - 1) * 24 + i * 48, y: SY + 330 + (i % 2) * 14, live: 1 });
        M.title = `¡${api.G.age} AÑOS! SOPLA LAS VELAS`;
      },
      down(M, x, y) { const o = M.objs.find(o => o.live && Math.abs(x - o.x) < 34 && Math.abs(y - (o.y - 40)) < 60); if (o) { o.live = 0; M.got++; api.puff(o.x, o.y - 44); api.sfx('tap'); if (M.got === M.objs.length) api.end(M, true); } },
      move(M, x, y) { this.down(M, x, y); },
      update(M) { if (M.t > M.dur) api.end(M, false); },
      result(M, ok) {
        if (ok) { win('¡Pide un deseo!', [2, 0, 6, 4], GREEN, 40); api.confetti(); }
        else lose(`Quedan ${M.objs.length - M.got} velas encendidas`, [0, 0, -2, 0]);
      },
      draw(M, t) {
        dim(0.5);
        api.item('bigcake', W / 2, SY + 420, 230);
        for (const o of M.objs) {
          api.item('candle', o.x, o.y, 70);
          if (o.live) { const c = api.ctx, f = 1 + Math.sin(t * 20 + o.x) * 0.12; c.fillStyle = 'rgba(255,200,80,.35)'; c.beginPath(); c.arc(o.x, o.y - 44, 18 * f, 0, TAU); c.fill(); }
        }
      },
    },
    // Encestar: arrastra la pelota hacia atrás y suelta (tirachinas).
    canasta: {
      dur: 10, hideRunner: 1,
      start(M) { M.shots = 3; M.hx = W - 120; M.hy = SY + 250; M.reset = () => { M.b = { x: 120, y: SY + 520, vx: 0, vy: 0, fly: 0, done: 0 }; }; M.reset(); },
      down(M, x, y) { if (!M.b.fly && M.shots > 0 && Math.hypot(x - M.b.x, y - M.b.y) < 90) M.aim = { x, y, cx: x, cy: y }; },
      move(M, x, y) { if (M.aim) { M.aim.cx = x; M.aim.cy = y; } },
      up(M) {
        if (!M.aim) return;
        const dx = M.aim.x - M.aim.cx, dy = M.aim.y - M.aim.cy; M.aim = null;
        if (Math.hypot(dx, dy) < 15) return;
        Object.assign(M.b, { vx: clamp(dx * 5.5, -1000, 1000), vy: clamp(dy * 5.5, -1350, 900), fly: 1 }); M.shots--; api.sfx('jump');
      },
      update(M, dt) {
        const b = M.b;
        if (b.fly) {
          const py = b.y; b.vy += 1100 * dt; b.x += b.vx * dt; b.y += b.vy * dt; b.rot = (b.rot || 0) + dt * 8;
          const rx0 = M.hx + 2, rx1 = M.hx + 64, ry = M.hy + 5;
          if (!b.done && b.vy > 0 && py < ry && b.y >= ry && b.x > rx0 && b.x < rx1) { b.done = 1; M.got++; api.burst(b.x, ry, '#ffd35a', 22); api.sfx('good'); api.float('¡Canasta!', M.hx - 40, M.hy - 40, GREEN, 36); api.apply([1, 0, 3, 1]); }
          if (b.y > SB + 40 || b.x > W + 40 || b.x < -40) { if (!b.done) { api.float('Fuera', W / 2, SY + 200, BROWN); } M.reset(); if (M.shots <= 0) api.end(M, M.got >= 2); }
        }
        if (M.t > M.dur && !b.fly) api.end(M, M.got >= 2);
      },
      result(M, ok) { if (ok) win(M.got === 3 ? '¡Tres de tres!' : '¡Buen tiro!', M.got === 3 ? [2, 0, 4, 3] : [0, 0, 2, 1]); else lose('Mejor el ajedrez', [0, 0, -2, 0]); },
      draw(M) {
        dim(0.4);
        const c = api.ctx, b = M.b;
        api.item('hoop', M.hx, M.hy, 190);
        if (M.aim) {
          const vx = (M.aim.x - M.aim.cx) * 5.5, vy = (M.aim.y - M.aim.cy) * 5.5; c.fillStyle = 'rgba(255,248,236,.8)';
          for (let i = 1; i < 9; i++) { const t = i * 0.07; c.beginPath(); c.arc(b.x + vx * t, b.y + vy * t + 550 * t * t, 5, 0, TAU); c.fill(); }
        }
        api.item('basketball', b.x, b.y, 58, { rot: b.rot || 0 });
        for (let i = 0; i < M.shots; i++) api.item('basketball', 40 + i * 34, SY + 600, 28, { alpha: 0.9 });
      },
    },
    // Penaltis: desliza desde el balón hacia la portería. El portero se tira a un lado;
    // las esquinas son casi imparables, pero si te pasas va fuera. single = un único tiro decisivo.
    penaltis: {
      dur: 12, hideRunner: 1,
      start(M) {
        M.dur = M.single ? 7 : 12; M.shots = M.single ? 1 : 3; M.need = M.single ? 1 : 2; M.miss = 0;
        M.gx = W / 2; M.gw = 440; M.gh = M.gw * 175 / 256; M.gy = SY + 150;            // portería (arriba-izquierda en gy)
        M.x0 = M.gx - M.gw * 0.44; M.x1 = M.gx + M.gw * 0.44; M.y0 = M.gy + M.gh * 0.08; M.y1 = M.gy + M.gh * 0.86;
        M.reset = () => { M.b = { x: W / 2, y: SY + 540, s: 64, fly: 0 }; M.k = { x: M.gx, dx: 0, lift: 0, rot: 0, dive: 0 }; M.wait = 0; };
        M.reset();
      },
      down(M, x, y) { if (!M.b.fly && !M.wait && M.shots > 0 && Math.hypot(x - M.b.x, y - M.b.y) < 110) M.aim = { x, y, cx: x, cy: y }; },
      move(M, x, y) { if (M.aim) { M.aim.cx = x; M.aim.cy = y; } },
      up(M) {
        if (!M.aim) return;
        const dx = M.aim.cx - M.aim.x, dy = M.aim.cy - M.aim.y; M.aim = null;
        if (dy > -30) return;
        const b = M.b, k = 1.9;
        b.tx = b.x + dx * k; b.ty = Math.max(SY + 60, b.y + dy * k); b.fly = 1; b.ft = 0; b.sx = b.x; b.sy = b.y; M.shots--;
        api.sfx('jump'); api.shake(3, 0.1);
        // el portero adivina el lado con un 40 % de acierto; si no, se tira al otro o se queda
        const side = Math.sign(b.tx - M.gx) || 1, guess = Math.random() < 0.4 ? side : Math.random() < 0.5 ? -side : 0;
        M.k.dive = guess; M.k.to = M.gx + guess * 115; M.k.lt = guess ? 40 + Math.random() * 60 : 0;
      },
      update(M, dt) {
        const b = M.b, k = M.k;
        if (!b.fly) { k.x = M.gx + Math.sin(M.t * 2.4) * 40; }
        else if (b.fly === 1) {
          b.ft += dt / 0.5; const f = Math.min(1, b.ft);
          b.x = b.sx + (b.tx - b.sx) * f; b.y = b.sy + (b.ty - b.sy) * f - Math.sin(f * Math.PI) * 40; b.s = 64 - 26 * f; b.rot = (b.rot || 0) + dt * 14;
          const kf = clamp(b.ft * 1.6, 0, 1); k.x += (k.to - k.x) * kf * 0.25; k.lift = k.lt * Math.sin(kf * Math.PI / 2); k.rot = k.dive * 1.1 * kf;
          if (f >= 1) {
            const inside = b.tx > M.x0 && b.tx < M.x1 && b.ty > M.y0 && b.ty < M.y1;
            // el portero cubre unos 90 px alrededor de sus manos (más si se tira bien)
            const hx = k.x + k.dive * 60, hy = M.y1 - 90 - k.lift, saved = inside && Math.abs(b.tx - hx) < (k.dive ? 85 : 70) && Math.abs(b.ty - hy) < 95;
            if (!inside) { b.fly = 3; M.miss++; api.float(b.ty <= M.y0 ? '¡Al larguero… y fuera!' : '¡Fuera!', W / 2, SY + 470, BROWN, 36); api.sfx('bad'); }
            else if (saved) { b.fly = 2; b.vx = (b.x - k.x) * 4 + rand(-80, 80); b.vy = 380; M.miss++; api.float('¡PARADÓN!', W / 2, SY + 470, RED, 40); api.sfx('hit'); api.shake(6, 0.2); }
            else { b.fly = 4; M.got++; api.float('¡GOOOL!', W / 2, SY + 470, GREEN, 50); api.sfx('good'); api.shake(8, 0.3); api.burst(b.x, b.y, '#fff', 24, 260); api.confetti(); }
            M.wait = 1.1;
          }
        } else {
          if (b.fly === 2) { b.vy += 900 * dt; b.x += b.vx * dt; b.y += b.vy * dt; b.rot += dt * 10; }
          if (b.fly === 3) { b.s = Math.max(10, b.s - dt * 30); }
          M.wait -= dt;
          if (M.wait <= 0) {
            if (M.got >= M.need) return api.end(M, true);
            if (M.shots <= 0 || M.got + M.shots < M.need) return api.end(M, false);
            M.reset();
          }
        }
        if (M.t > M.dur && !b.fly) api.end(M, M.got >= M.need);
      },
      result(M, ok) {
        if (M.single) return;   // la carta que lo lanzó decide qué pasa
        if (ok) win(M.got === 3 ? '¡Tres de tres, crack!' : '¡Ganas la tanda!', M.got === 3 ? [1, 0, 6, 2] : [0, 0, 3, 1]);
        else lose('El portero se ríe de ti', [0, 0, -2, 0]);
      },
      draw(M, t) {
        const c = api.ctx, b = M.b, k = M.k;
        // césped a rayas y área
        for (let i = 0; i < 8; i++) { c.fillStyle = i % 2 ? '#6fa845' : '#7cb552'; c.fillRect(0, SY + i * 81, W, 82); }
        c.strokeStyle = 'rgba(255,255,255,.85)'; c.lineWidth = 5;
        c.beginPath(); c.moveTo(0, M.gy + M.gh - 4); c.lineTo(W, M.gy + M.gh - 4); c.stroke();
        c.beginPath(); c.moveTo(24, M.gy + M.gh - 4); c.lineTo(6, SY + 630); c.moveTo(W - 24, M.gy + M.gh - 4); c.lineTo(W - 6, SY + 630); c.stroke();
        c.fillStyle = '#fff'; c.beginPath(); c.ellipse(W / 2, SY + 560, 9, 4, 0, 0, TAU); c.fill();
        const ripple = b.fly === 4 ? Math.sin(t * 40) * 3 * Math.max(0, M.wait - 0.4) : 0;
        api.item('goal', M.gx, M.gy + M.gh / 2 + ripple, M.gh);
        const behind = b.fly === 4;   // el balón entra y queda detrás del portero
        if (behind) api.item('soccerball', b.x, b.y, b.s, { rot: b.rot || 0 });
        c.save(); c.translate(k.x, M.gy + M.gh - 10 - k.lift); c.rotate(k.rot); api.shadow(0, 8 + k.lift, 40); api.item('keeper', 0, -85, 175); c.restore();
        if (M.aim) {
          const dx = (M.aim.cx - M.aim.x) * 1.9, dy = (M.aim.cy - M.aim.y) * 1.9; c.fillStyle = 'rgba(255,248,236,.85)';
          for (let i = 1; i < 8; i++) { const f = i / 8; c.beginPath(); c.arc(b.x + dx * f, b.y + dy * f - Math.sin(f * Math.PI) * 40, 9 - f * 4, 0, TAU); c.fill(); }
        }
        if (!behind) { if (!b.fly) api.shadow(b.x, b.y + b.s * 0.45, b.s * 0.45); api.item('soccerball', b.x, b.y, b.s, { rot: b.rot || 0 }); }
        for (let i = 0; i < M.shots; i++) api.item('soccerball', 40 + i * 34, SY + 610, 28, { alpha: 0.9 });
        for (let i = 0; i < M.got; i++) api.item('star', W - 40 - i * 34, SY + 610, 28);
      },
    },
    // Atrapar el ramo en la boda: arrastra a Ramón a izquierda y derecha.
    ramo: {
      dur: 6, hideRunner: 1, ownRamon: 1,
      start(M) { M.rx = W / 2; M.o = { x: rand(120, W - 120), y: SY - 20, t0: rand(0, 6) }; M.frame = 0; },
      down(M, x) { M.tx = x; }, move(M, x) { M.tx = x; },
      update(M, dt) {
        if (M.tx != null) { const d = M.tx - M.rx; M.rx += clamp(d, -520 * dt, 520 * dt); M.frame += Math.abs(d) > 4 ? dt * 14 : 0; }
        const o = M.o; o.y += 150 * dt; o.x += Math.sin(M.t * 2.2 + o.t0) * 120 * dt; o.x = clamp(o.x, 40, W - 40); o.rot = Math.sin(M.t * 3) * 0.4;
        if (o.y > GY - api.curH() * 0.95 && Math.abs(o.x - M.rx) < 60 && !M.got) { M.got = 1; api.burst(o.x, o.y, '#ffb3c6', 26); api.end(M, true); }
        if (o.y > GY + 10) api.end(M, false);
      },
      result(M, ok) { if (ok) { win('¡El ramo es tuyo!', [0, 0, 6, 8]); api.confetti(); } else lose('El ramo se lo lleva tu cuñado', [0, 0, -2, 0]); },
      draw(M) {
        api.shadow(M.rx, GY + 2, 32); api.sprite(api.spriteKey(), M.frame, M.rx, GY, api.curH());
        if (!M.got) api.item('bouquet', M.o.x, M.o.y, 80, { rot: M.o.rot });
      },
    },
    // Examen práctico: mantén pulsado para acelerar y suelta para frenar entre los conos.
    aparcar: {
      dur: 8, hideRunner: 1,
      start(M) { M.cx = 70; M.v = 0; M.moved = 0; M.z0 = 350; M.z1 = 450; },
      down(M) { M.hold = 1; }, up(M) { M.hold = 0; },
      update(M, dt) {
        if (M.hold) { M.v += 420 * dt; M.moved = 1; api.engine(M.v); } else M.v = Math.max(0, M.v - 300 * dt);
        M.v = Math.min(M.v, 420); M.cx += M.v * dt;
        if (M.cx > M.z1 + 45) { api.shake(10, 0.3); api.sfx('hit'); api.end(M, false); return; }
        if (M.moved && !M.hold && M.v === 0) api.end(M, M.cx > M.z0 && M.cx < M.z1);
        if (M.t > M.dur) api.end(M, false);
      },
      result(M, ok) { if (ok) win('¡Aparcado perfecto!', null, GREEN, 36); else lose(M.cx > M.z1 ? '¡Te comes el cono!' : 'Te quedas a medias', null, RED); },
      draw(M, t) {
        const c = api.ctx, y = SY + 470; dim(0.45);
        c.fillStyle = '#5b5b66'; c.fillRect(0, y + 10, W, 90); c.fillStyle = '#f6f0dc';
        for (let x = 0; x < W; x += 60) c.fillRect(x, y + 55, 34, 5);
        c.fillStyle = 'rgba(140,193,82,.45)'; c.fillRect(M.z0, y + 14, M.z1 - M.z0, 82);
        api.item('cone', M.z0 - 20, y + 20, 56); api.item('cone', M.z1 + 20, y + 20, 56);
        api.item('car', M.cx, y + 8 + (M.v > 0 ? Math.sin(t * 40) * 1.5 : 0), 90);
        if (!M.done) api.text(M.hold ? 'Acelerando…' : 'Mantén pulsado para acelerar', W / 2, y + 150, { size: 26, color: '#fff8ec', stroke: '#3b2416', sw: 5 });
      },
    },
    // Pesca de jubilado: espera a que el corcho se hunda y toca en ese momento.
    pesca: {
      dur: 13, hideRunner: 1,
      start(M) { M.tries = 3; M.next = () => { M.wait = rand(1.2, 3.2); M.bite = 0; }; M.next(); M.fishes = []; },
      down(M) {
        if (M.bite > 0) { M.got++; M.bite = 0; api.sfx('good'); api.burst(W / 2 + 60, SY + 430, '#bfe3ff', 20); api.float('¡Un pez!', W / 2, SY + 250, GREEN, 36); api.apply([1, 0, 3, 0]); M.fishes.push({ t: 0 }); M.tries--; M.tries > 0 ? M.next() : api.end(M, true); }
        else if (M.wait > 0) { api.float('¡Muy pronto!', W / 2, SY + 250, BROWN); api.sfx('bad'); M.next(); }
      },
      update(M, dt) {
        for (const f of M.fishes) f.t += dt;
        if (M.bite > 0) { M.bite -= dt; if (M.bite <= 0) { api.float('Se escapó…', W / 2, SY + 250, BROWN); M.tries--; M.tries > 0 ? M.next() : api.end(M, M.got > 0); } }
        else { M.wait -= dt; if (M.wait <= 0) { M.bite = 0.75; api.sfx('tap'); api.burst(W / 2 + 60, SY + 430, '#bfe3ff', 10, 150); } }
        if (M.t > M.dur) api.end(M, M.got > 0);
      },
      result(M, ok) { if (ok) win(M.got >= 3 ? '¡Cena para toda la familia!' : `${M.got} ${M.got === 1 ? 'pez' : 'peces'}`, [1, 1, 3, 1]); else lose('Hoy no pican', [0, 0, -1, 0]); },
      draw(M, t) {
        const c = api.ctx, wy = SY + 400; dim(0.25);
        const g = c.createLinearGradient(0, wy, 0, SB); g.addColorStop(0, '#6fa8c8'); g.addColorStop(1, '#2f5d7c'); c.fillStyle = g; c.fillRect(0, wy, W, SB - wy);
        c.strokeStyle = 'rgba(255,255,255,.35)'; c.lineWidth = 3;
        for (let i = 0; i < 6; i++) { c.beginPath(); const yy = wy + 30 + i * 45; for (let x = 0; x <= W; x += 20) c.lineTo(x, yy + Math.sin(x / 40 + t * 2 + i) * 4); c.stroke(); }
        api.item('boat', 120, wy + 10, 110);
        const bx = W / 2 + 60, by = wy + 28 + (M.bite > 0 ? 22 : Math.sin(t * 3) * 4);
        c.strokeStyle = 'rgba(40,25,15,.6)'; c.lineWidth = 2; c.beginPath(); c.moveTo(150, wy - 70); c.quadraticCurveTo(bx - 60, wy - 120, bx, by - 20); c.stroke();
        api.item('bobber', bx, by, 44);
        if (M.bite > 0) api.text('¡PICA!', bx, by - 60, { size: 40, color: '#fff8ec', stroke: '#3b2416', sw: 7, font: "'Chewy', cursive" });
        for (const f of M.fishes) if (f.t < 1.2) api.item('fish', bx - f.t * 60, by - Math.sin(f.t / 1.2 * Math.PI) * 180, 80, { rot: -0.6 + f.t });
        for (let i = 0; i < M.tries; i++) api.item('bobber', 30 + i * 30, SY + 600, 22);
      },
    },
    // Recuerdos: memoria por parejas con las ilustraciones de tu propia vida.
    recuerdos: {
      dur: 16, hideRunner: 1,
      start(M) {
        const lived = api.lived().filter(id => api.hasEv(id)); const pool = lived.length >= 3 ? lived : api.allEv();
        const three = pool.sort(() => Math.random() - 0.5).slice(0, 3); const deck = [...three, ...three].sort(() => Math.random() - 0.5);
        M.cards = deck.map((id, i) => ({ id, i, x: 40 + (i % 2) * 235, y: SY + 150 + Math.floor(i / 2) * 150, w: 225, h: 135, up: 0, flip: 0, done: 0 }));
        M.open = []; M.lock = 0;
      },
      down(M, x, y) {
        if (M.lock > 0) return;
        const c = M.cards.find(c => !c.up && !c.done && x > c.x && x < c.x + c.w && y > c.y && y < c.y + c.h); if (!c) return;
        c.up = 1; api.sfx('card'); M.open.push(c);
        if (M.open.length === 2) {
          const [a, b] = M.open;
          if (a.id === b.id) { a.done = b.done = 1; M.got++; M.open = []; api.sfx('good'); api.burst(b.x + b.w / 2, b.y + b.h / 2, '#ffd35a', 18); api.apply([0, 0, 2, 3]); if (M.got === 3) api.end(M, true); }
          else M.lock = 0.8;
        }
      },
      update(M, dt) {
        for (const c of M.cards) c.flip += ((c.up || c.done ? 1 : 0) - c.flip) * Math.min(1, dt * 12);
        if (M.lock > 0) { M.lock -= dt; if (M.lock <= 0) { M.open.forEach(c => { c.up = 0; }); M.open = []; } }
        if (M.t > M.dur) api.end(M, M.got >= 2);
      },
      result(M, ok) { if (ok) win(M.got === 3 ? 'Qué vida más bonita' : 'Casi todo lo recuerdas', [0, 0, 5, 3]); else lose('La memoria ya no es lo que era', [0, 0, -2, 0]); },
      draw(M) {
        dim(0.55);
        const c = api.ctx;
        for (const k of M.cards) {
          const s = Math.abs(Math.cos(k.flip * Math.PI)), face = k.flip > 0.5, cx = k.x + k.w / 2;
          c.save(); c.translate(cx, k.y + k.h / 2); c.scale(Math.max(0.02, s), 1);
          api.rrect(-k.w / 2 + 3, -k.h / 2 + 5, k.w, k.h, 12, 'rgba(0,0,0,.3)');
          if (face && api.IMG['ev_' + k.id]) { c.save(); c.beginPath(); c.roundRect(-k.w / 2, -k.h / 2, k.w, k.h, 12); c.clip(); c.drawImage(api.IMG['ev_' + k.id], -k.w / 2, -k.h / 2, k.w, k.h); c.restore(); api.rrect(-k.w / 2, -k.h / 2, k.w, k.h, 12, null, k.done ? '#8cc152' : '#3b2416', 4); }
          else { api.rrect(-k.w / 2, -k.h / 2, k.w, k.h, 12, '#f3e2c0', '#3b2416', 4); api.item('photo', 0, 0, 90, { alpha: 0.7 }); }
          c.restore();
        }
      },
    },
  };
  D.bebe = D.equilibrio;
  return D;
};
