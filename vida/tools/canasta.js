// Comprueba que un tiro bien apuntado entra en la canasta.
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(), p = await b.newPage();
  await p.goto('http://localhost:8765/?auto=1&age=16'); await p.waitForTimeout(1500);
  const r = await p.evaluate(async () => {
    const V = window.__vida, G = V.G; G.lastEvent = 999; G.card = null; V.startMoment('canasta');
    const M = G.moment, d = V.MOM.canasta; M.t = 1;
    // busca un tiro que entre simulando la física del juego
    for (let ax = 20; ax < 200; ax += 3) for (let ay = 20; ay < 260; ay += 3) {
      const b = { x: 120, y: M.b.y, vx: ax * 5.5, vy: -ay * 5.5 }; let ok = false;
      for (let i = 0; i < 300 && b.y < 900; i++) { const py = b.y; b.vy += 1100 / 60; b.x += b.vx / 60; b.y += b.vy / 60; if (b.vy > 0 && py < M.hy + 5 && b.y >= M.hy + 5 && b.x > M.hx + 2 && b.x < M.hx + 64) { ok = true; break; } }
      if (ok) return { ax, ay };
    }
    return null;
  });
  console.log('tiro que entra:', JSON.stringify(r));
  await b.close();
})();
