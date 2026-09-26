// Simula N vidas con un bot (salta obstáculos con un % de error) y resume el equilibrio.
// Uso: node sim.js [vidas] [habilidad 0..1]
const { chromium } = require('playwright');
(async () => {
  const N = +(process.argv[2] || 6), skill = +(process.argv[3] || 0.75);
  const b = await chromium.launch();
  const res = [];
  for (let k = 0; k < N; k++) {
    const p = await b.newPage({ viewport: { width: 270, height: 480 } });
    const errs = []; p.on('pageerror', e => errs.push(e.message));
    await p.goto('http://localhost:8765/?auto=1&fast=6' + (process.argv[4] ? '&flags=' + process.argv[4] : ''));
    await p.waitForTimeout(1500);
    await p.evaluate(skill => {
      const V = window.__vida, seen = new Set();
      window.__log = { events: 0, moments: 0, hits: 0 };
      setInterval(() => {
        const G = V.G; if (!G || G.dead) return;
        if (G.card) { window.__log.events++; V.choose(Math.floor(Math.random() * G.card.e.o.length)); return; }
        if (G.moment) {
          const M = G.moment; if (!seen.has(M)) { seen.add(M); window.__log.moments++; }
          if (Math.random() > skill) return;
          if (M.id === 'penaltis') { if (!M.b.fly && !M.wait && M.t > 0.4) { const b = M.b, tx = Math.random() < 0.5 ? 90 : 450, ty = 300 + Math.random() * 120; V.momentInput('down', b.x, b.y); V.momentInput('move', b.x + (tx - b.x) / 1.9, b.y + (ty - b.y) / 1.9); V.momentInput('up', 0, 0); } return; }
          if (M.id === 'pelota' && M.objs[0]) V.momentTap(M.objs[0].x, M.objs[0].y);
          else if (M.objs && M.objs.length && M.objs[0].x != null) { const o = M.objs.find(o => o.live && M.t >= (o.d || 0)); if (o) V.momentTap(o.x, o.y); }
          else if (M.id === 'ritmo') { const b = M.objs.find(b => !b.hit && Math.abs(M.t - b.t) < 0.1); if (b) V.momentTap(270, 400); }
          else if (M.id === 'informe') V.momentTap(270, 400);
          else V.momentTap(M.x > 0 ? 100 : 440, 400);
          return;
        }
        const h = G.ents.find(e => e.k === 'haz' && !e.air && e.x > V.PX && e.x - V.PX < 150 && !e.seen);
        if (h) { h.seen = 1; if (Math.random() < skill) setTimeout(() => V.jump(), 20); }
        const pk = G.ents.find(e => e.k === 'pick' && e.y < V.GY - 120 && e.x > V.PX && e.x - V.PX < 120 && !e.seen);
        if (pk) { pk.seen = 1; if (Math.random() < skill * 0.6) V.jump(); }
      }, 8);
    }, skill);
    let st;
    for (let t = 0; t < 200; t++) {
      await p.waitForTimeout(1000);
      st = await p.evaluate(() => { const G = window.__vida.G; return { age: G.age, dead: G.dead, st: G.st.map(Math.round), cause: G.cause, score: Math.round(G.score + G.age * 2), hits: G.hits, picked: G.picked, tags: G.tags.length, path: G.path, branch: G.branch, flags: Object.keys(G.flags).filter(k => G.flags[k]), log: window.__log }; });
      if (st.dead) break;
    }
    res.push(st); console.log(JSON.stringify(st)); if (errs.length) console.log('ERR', errs);
    await p.close();
  }
  const ages = res.map(r => r.age);
  console.log('edad media', (ages.reduce((a, b) => a + b, 0) / N).toFixed(1), 'min', Math.min(...ages), 'max', Math.max(...ages));
  await b.close();
})();
