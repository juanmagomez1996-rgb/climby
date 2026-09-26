// Capturas 1080×1920 para Google Play a partir del prototipo HTML (mismo arte).
const { chromium } = require('playwright');
(async () => {
  const out = process.argv[2], b = await chromium.launch();
  const shot = async (name, url, prep, wait = 2500) => {
    const p = await b.newPage({ viewport: { width: 540, height: 960 }, deviceScaleFactor: 2 });
    await p.goto('http://localhost:8765/' + url); await p.waitForTimeout(1800);
    if (prep) await p.evaluate(prep);
    await p.waitForTimeout(wait);
    await p.screenshot({ path: `${out}/${name}.png` }); await p.close();
  };
  await shot('1_menu', '', null, 500);
  await shot('2_infancia', '?auto=1&age=6', () => { const V = window.__vida, G = V.G; G.banners = []; setInterval(() => { const h = G.ents.find(e => e.k === 'haz' && e.x > V.PX && e.x - V.PX < 130); if (h && G.p.ground) V.jump(); if (G.card) V.choose(0); }, 30); }, 3200);
  await shot('3_carta', '?auto=1&age=16', () => { const V = window.__vida, G = V.G; G.banners = []; G.flags.pareja = 0; G.done = new Set(); G.age = 17; window.__open = true; }, 400);
  await shot('4_familia', '?auto=1&age=38', () => { const V = window.__vida, G = V.G; G.banners = []; G.flags = { pareja: 1, hija: 1, perro: 1, casado: 1 }; G.partner = 'Lucía'; G.hijaAge = 31; G.lastEvent = 99; G.lastMoment = 99; setInterval(() => { if (G.card) V.choose(0); const h = G.ents.find(e => e.k === 'haz' && e.x > V.PX && e.x - V.PX < 130); if (h && G.p.ground) V.jump(); }, 30); }, 4200);
  await shot('5_minijuego', '?auto=1&age=17', () => { const V = window.__vida, G = V.G; G.banners = []; G.lastMoment = -9; G.age = 18; const orig = Math.random; V.startMoment(); let i = 0; while (G.moment && G.moment.id !== 'ritmo' && i++ < 40) { G.moment = null; G.lastMoment = -9; V.startMoment(); } }, 1600);
  await shot('6_vejez', '?auto=1&age=74', () => { const V = window.__vida, G = V.G; G.banners = []; G.flags = { pareja: 1, perro: 1 }; G.partner = 'Lucía'; G.lastEvent = 99; G.lastMoment = 99; setInterval(() => { if (G.card) V.choose(0); const h = G.ents.find(e => e.k === 'haz' && e.x > V.PX && e.x - V.PX < 110); if (h && G.p.ground) V.jump(); }, 30); }, 4200);
  await b.close();
})();
