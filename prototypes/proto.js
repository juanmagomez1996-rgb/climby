// Proto: motor mínimo compartido por los prototipos.
// Lienzo lógico vertical 540x960 escalado a pantalla, entrada táctil/ratón/teclado,
// botones en canvas, partículas, sonido WebAudio y pantallas de inicio/fin.
(function () {
  const C = {
    bg: '#1A1424', bg2: '#251C33', panel: '#2E2340', ink: '#F2E9D8', dim: '#A99BB8',
    gold: '#FFB23E', teal: '#53D8C3', pink: '#FF5C7A', blue: '#6FA8FF', lime: '#B6E36A',
  };
  const FONT = '"Bowlby One", "Arial Black", Impact, sans-serif';
  const BODY = '"Atkinson Hyperlegible", "Segoe UI", system-ui, sans-serif';

  const rand = (a, b) => a + Math.random() * (b - a);
  const randi = (a, b) => Math.floor(rand(a, b + 1));
  const pick = arr => arr[Math.floor(Math.random() * arr.length)];
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);

  function injectChrome(opts) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=Bowlby+One&display=swap';
    document.head.appendChild(link);
    const st = document.createElement('style');
    st.textContent = `
      html,body{height:100%;margin:0;background:${C.bg};color:${C.ink};font-family:${BODY};overflow:hidden;
        -webkit-user-select:none;user-select:none;touch-action:none;color-scheme:dark}
      #stage{position:fixed;inset:0;display:grid;place-items:center}
      canvas{display:block;background:${C.bg2};border-radius:6px;box-shadow:0 0 0 1px #ffffff14}
      .pbar{position:fixed;top:calc(8px + env(safe-area-inset-top,0px));left:8px;z-index:5;display:flex;gap:8px}
      .pbar a,.pbar button{font:700 13px ${BODY};color:${C.ink};background:#00000066;border:1px solid #ffffff22;
        border-radius:999px;padding:6px 12px;text-decoration:none;cursor:pointer}
      .pbar a:focus-visible,.pbar button:focus-visible,.ov button:focus-visible{outline:2px solid ${C.gold};outline-offset:2px}
      .ov{position:fixed;inset:0;z-index:4;display:grid;place-items:center;background:#120d1acc;padding:16px}
      .ov .card{box-sizing:border-box;max-width:420px;width:100%;background:${C.panel};border:2px solid ${C.gold};border-radius:14px;
        padding:22px 20px;display:flex;flex-direction:column;gap:12px}
      .ov h1{font:400 32px/1.05 ${FONT};margin:0;color:${C.gold};text-wrap:balance}
      .ov .sub{margin:0;color:${C.teal};font-weight:700;font-size:13px;letter-spacing:.08em;text-transform:uppercase}
      .ov p,.ov li{margin:0;font-size:15px;line-height:1.45}
      .ov ul{margin:0;padding-left:18px;display:flex;flex-direction:column;gap:4px}
      .ov .big{font:400 44px ${FONT};color:${C.ink}}
      .ov button{font:400 20px ${FONT};background:${C.gold};color:${C.bg};border:0;border-radius:10px;padding:12px;cursor:pointer}
    `;
    document.head.appendChild(st);
    const bar = document.createElement('div');
    bar.className = 'pbar';
    bar.innerHTML = `<a href="index.html">← Prototipos</a><button type="button" id="p-restart">Reiniciar</button>`;
    document.body.appendChild(bar);
  }

  function create(opts) {
    injectChrome(opts);
    const W = opts.width || 540, H = opts.height || 960;
    const stage = document.createElement('div');
    stage.id = 'stage';
    const canvas = document.createElement('canvas');
    stage.appendChild(canvas);
    document.body.appendChild(stage);
    const ctx = canvas.getContext('2d');
    let scale = 1;
    function resize() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      scale = Math.min(window.innerWidth / W, window.innerHeight / H);
      canvas.style.width = W * scale + 'px';
      canvas.style.height = H * scale + 'px';
      canvas.width = Math.round(W * scale * dpr);
      canvas.height = Math.round(H * scale * dpr);
      G.pxScale = scale * dpr;
    }

    const G = {
      W, H, canvas, ctx, C, FONT, BODY, rand, randi, pick, clamp, lerp, dist,
      t: 0, paused: true, state: 'menu',
      pointer: { x: W / 2, y: H / 2, down: false, pressed: false, released: false, dx: 0, dy: 0 },
      keys: new Set(), _kp: new Set(), _kr: new Set(),
      particles: [], shakeT: 0, shakeA: 0, floaters: [],
    };
    window.addEventListener('resize', resize);
    resize();

    // --- Entrada ---
    function toLocal(e) {
      const r = canvas.getBoundingClientRect();
      return { x: (e.clientX - r.left) / scale, y: (e.clientY - r.top) / scale };
    }
    canvas.addEventListener('pointerdown', e => {
      canvas.setPointerCapture?.(e.pointerId);
      const p = toLocal(e);
      Object.assign(G.pointer, p, { down: true, pressed: true, sx: p.x, sy: p.y });
      G.unlockAudio();
    });
    canvas.addEventListener('pointermove', e => {
      const p = toLocal(e);
      G.pointer.dx += p.x - G.pointer.x; G.pointer.dy += p.y - G.pointer.y;
      G.pointer.x = p.x; G.pointer.y = p.y;
    });
    const up = e => { if (G.pointer.down) { G.pointer.down = false; G.pointer.released = true; } };
    canvas.addEventListener('pointerup', up);
    canvas.addEventListener('pointercancel', up);
    window.addEventListener('keydown', e => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' '].includes(e.key)) e.preventDefault();
      if (!G.keys.has(e.key)) G._kp.add(e.key);
      G.keys.add(e.key); G.unlockAudio();
    });
    window.addEventListener('keyup', e => { G.keys.delete(e.key); G._kr.add(e.key); });
    G.key = k => G.keys.has(k);
    G.keyPressed = k => G._kp.has(k);
    G.keyReleased = k => G._kr.has(k);

    // --- Audio ---
    let ac = null;
    G.unlockAudio = () => {
      if (ac) return;
      try { ac = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { ac = null; }
    };
    G.beep = (freq = 440, dur = 0.08, type = 'square', vol = 0.06, slide = 0) => {
      if (!ac) return;
      try {
        const o = ac.createOscillator(), g = ac.createGain(), t0 = ac.currentTime;
        o.type = type; o.frequency.setValueAtTime(freq, t0);
        if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t0 + dur);
        g.gain.setValueAtTime(vol, t0); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
        o.connect(g).connect(ac.destination); o.start(t0); o.stop(t0 + dur + 0.02);
      } catch (e) { }
    };

    // --- Persistencia ---
    G.best = (key, value) => {
      const k = 'proto-best-' + key;
      let cur = null;
      try { cur = JSON.parse(localStorage.getItem(k)); } catch (e) { }
      if (value !== undefined && (cur === null || value > cur)) {
        try { localStorage.setItem(k, JSON.stringify(value)); } catch (e) { }
        return value;
      }
      return cur;
    };

    // --- Efectos ---
    G.shake = (a = 8, t = 0.25) => { G.shakeA = Math.max(G.shakeA, a); G.shakeT = Math.max(G.shakeT, t); };
    G.burst = (x, y, color = C.gold, n = 14, speed = 260, size = 5) => {
      for (let i = 0; i < n; i++) {
        const a = rand(0, Math.PI * 2), s = rand(speed * 0.3, speed);
        G.particles.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rand(0.4, 0.9), max: 0.9, r: rand(size * 0.5, size), color });
      }
    };
    G.float = (text, x, y, color = C.ink, size = 26) => G.floaters.push({ text, x, y, color, size, life: 1 });

    // --- Dibujo ---
    G.text = (str, x, y, o = {}) => {
      ctx.save();
      ctx.font = `${o.weight || 400} ${o.size || 24}px ${o.body ? BODY : FONT}`;
      ctx.textAlign = o.align || 'left';
      ctx.textBaseline = o.baseline || 'alphabetic';
      if (o.shadow !== false) { ctx.fillStyle = '#00000088'; ctx.fillText(str, x + 2, y + 3); }
      ctx.fillStyle = o.color || C.ink;
      ctx.fillText(str, x, y);
      ctx.restore();
    };
    G.rrect = (x, y, w, h, r, fill, stroke, lw = 3) => {
      ctx.beginPath(); ctx.roundRect(x, y, w, h, r);
      if (fill) { ctx.fillStyle = fill; ctx.fill(); }
      if (stroke) { ctx.lineWidth = lw; ctx.strokeStyle = stroke; ctx.stroke(); }
    };
    G.circle = (x, y, r, fill, stroke, lw = 3) => {
      ctx.beginPath(); ctx.arc(x, y, Math.max(0, r), 0, Math.PI * 2);
      if (fill) { ctx.fillStyle = fill; ctx.fill(); }
      if (stroke) { ctx.lineWidth = lw; ctx.strokeStyle = stroke; ctx.stroke(); }
    };
    G.inRect = (px, py, x, y, w, h) => px >= x && px <= x + w && py >= y && py <= y + h;
    // Botón en canvas: dibuja y devuelve true si se ha tocado este frame.
    G.button = (x, y, w, h, label, o = {}) => {
      const hover = G.inRect(G.pointer.x, G.pointer.y, x, y, w, h);
      const active = hover && G.pointer.down;
      const fill = o.disabled ? '#3a3048' : (o.color || C.gold);
      G.rrect(x, y + (active ? 3 : 0), w, h, o.r ?? 12, fill, o.stroke || null);
      G.text(label, x + w / 2, y + h / 2 + (active ? 3 : 0), { size: o.size || 20, align: 'center', baseline: 'middle', color: o.textColor || C.bg, shadow: false, body: o.body, weight: o.body ? 700 : 400 });
      return !o.disabled && G.pointer.pressed && G.inRect(G.pointer.sx, G.pointer.sy, x, y, w, h);
    };
    G.bar = (x, y, w, h, frac, color, back = '#00000055') => {
      G.rrect(x, y, w, h, h / 2, back);
      if (frac > 0) G.rrect(x, y, Math.max(h, w * clamp(frac, 0, 1)), h, h / 2, color);
    };

    // --- Pantallas ---
    let ov = null;
    G.screen = ({ title, sub, html, big, button = 'Jugar', onClick }) => {
      if (ov) ov.remove();
      ov = document.createElement('div');
      ov.className = 'ov';
      ov.innerHTML = `<div class="card">${sub ? `<p class="sub">${sub}</p>` : ''}<h1>${title}</h1>${big ? `<div class="big">${big}</div>` : ''}${html || ''}<button type="button" id="p-go">${button}</button></div>`;
      document.body.appendChild(ov);
      G.paused = true;
      const btn = ov.querySelector('#p-go');
      btn.focus();
      btn.addEventListener('click', () => { G.unlockAudio(); ov.remove(); ov = null; G.paused = false; resetInput(); onClick && onClick(); });
    };
    G.hideScreen = () => { if (ov) { ov.remove(); ov = null; } G.paused = false; };

    function resetInput() {
      G.pointer.pressed = G.pointer.released = false; G.pointer.down = false;
      G._kp.clear(); G._kr.clear();
    }

    // --- Bucle ---
    G.run = (update, draw) => {
      let last = performance.now();
      function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000);
        last = now;
        if (!G.paused) { G.t += dt; update(dt); }
        // efectos
        for (const p of G.particles) { p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 500 * dt; p.vx *= 0.98; p.life -= dt; }
        G.particles = G.particles.filter(p => p.life > 0);
        for (const f of G.floaters) { f.y -= 50 * dt; f.life -= dt * 0.9; }
        G.floaters = G.floaters.filter(f => f.life > 0);
        if (G.shakeT > 0) G.shakeT -= dt; else G.shakeA = 0;

        const s = G.pxScale;
        ctx.setTransform(s, 0, 0, s, 0, 0);
        ctx.clearRect(0, 0, W, H);
        if (G.shakeA) ctx.translate(rand(-G.shakeA, G.shakeA), rand(-G.shakeA, G.shakeA));
        draw(ctx);
        for (const p of G.particles) { ctx.globalAlpha = clamp(p.life / 0.5, 0, 1); G.circle(p.x, p.y, p.r, p.color); }
        ctx.globalAlpha = 1;
        for (const f of G.floaters) { ctx.globalAlpha = clamp(f.life, 0, 1); G.text(f.text, f.x, f.y, { size: f.size, align: 'center', color: f.color }); }
        ctx.globalAlpha = 1;
        G.pointer.pressed = G.pointer.released = false; G.pointer.dx = G.pointer.dy = 0;
        G._kp.clear(); G._kr.clear();
        requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
    };

    document.getElementById('p-restart').addEventListener('click', () => opts.onRestart && opts.onRestart());
    return G;
  }

  window.Proto = { create, C, rand, randi, pick, clamp, lerp, dist };
})();
