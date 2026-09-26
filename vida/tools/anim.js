const { chromium } = require('playwright');
(async () => {
  const out = process.argv[2], b = await chromium.launch();
  const shot = async (name, age, prep, wait) => {
    const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 1.5 });
    p.on('pageerror', e => console.log('ERR', e.message));
    await p.goto(`http://localhost:8765/?auto=1&age=${age}`); await p.waitForTimeout(1500);
    await p.evaluate(prep); await p.waitForTimeout(wait);
    await p.screenshot({ path: `${out}/an_${name}.png` }); await p.close();
  };
  const base = `const V = window.__vida, G = V.G; G.banners = []; G.lastEvent = 999; G.lastMoment = 999; G.npcT = 0; G.ambT = 0;`;
  await shot('bebe', 1, new Function(base + `G.age = 1;`), 2500);
  await shot('salto', 15, new Function(base + `setTimeout(() => V.jump(), 1850);`), 2000);
  await shot('familia50', 52, new Function(base + `G.flags = { pareja: 1, hija: 1, perro: 1 }; G.partner = 'Marga'; G.hijaAge = 37; G.perroAge = 40; setInterval(() => { if (G.card) V.choose(0); G.lastEvent = 999; }, 50); window.__vida.G.followers.length = 0;`), 3500);
  await shot('familia70', 72, new Function(base + `G.flags = { pareja: 1, hija: 1, perro: 1 }; G.partner = 'Lucía'; G.hijaAge = 30; G.perroAge = 70; setInterval(() => { if (G.card) V.choose(0); G.lastEvent = 999; }, 50);`), 3500);
  await b.close();
})();
