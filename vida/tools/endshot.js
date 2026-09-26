const { chromium } = require('playwright');
(async () => {
  const out = process.env.OUT, b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 2 });
  await p.goto('http://localhost:8765/'); await p.waitForTimeout(1500);
  await p.screenshot({ path: out + '/m_menu.png' });
  await p.goto('http://localhost:8765/?auto=1&age=88&fast=4'); await p.waitForTimeout(1500);
  await p.evaluate(() => { const G = window.__vida.G; G.tags = [{ a: 6, t: 'se sentó con el niño raro' }, { a: 24, t: 'adoptó a Tornillo' }, { a: 41, t: 'corrió una maratón' }]; });
  for (let i = 0; i < 60; i++) { const d = await p.evaluate(() => { const G = window.__vida.G; if (G.card) window.__vida.choose(0); if (G.age > 90) G.st[0] = 0; return G.endShown; }); if (d) break; await p.waitForTimeout(500); }
  await p.waitForTimeout(1500); await p.screenshot({ path: out + '/m_end.png' });
  await b.close();
})();
