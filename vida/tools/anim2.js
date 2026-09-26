const { chromium } = require('playwright');
(async () => {
  const out = process.argv[2], b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 1.5 });
  await p.goto(`http://localhost:8765/?auto=1`); await p.waitForTimeout(1300);
  await p.evaluate(() => { const G = window.__vida.G; G.banners = []; G.npcT = 0.2; G.age = 1; G.yt = 0; });
  await p.waitForTimeout(900); await p.screenshot({ path: `${out}/an_bebe.png` });
  for (const [age, n] of [[25, 'salto'], [55, 'salto2']]) {
    await p.evaluate(a => { const V = window.__vida, G = V.G; G.age = a; G.stage = G.prevStage = a < 45 ? 2 : 3; G.card = null; G.lastEvent = 999; G.lastMoment = 999; G.banners = []; G.ents = []; G.npcT = 0; G.spawnT = 99; }, age);
    await p.waitForTimeout(700);
    await p.evaluate(() => window.__vida.jump()); await p.waitForTimeout(170);
    await p.screenshot({ path: `${out}/an_${n}.png` });
  }
  await b.close();
})();
