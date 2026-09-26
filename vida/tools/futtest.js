// Prueba el camino del fútbol: penaltis, escenarios de cada etapa y finales. Uso: node futtest.js carpeta
const { chromium } = require('playwright');
(async () => {
  const out = process.argv[2], b = await chromium.launch(), errs = [];
  const page = async (q) => {
    const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 1.5 });
    p.on('pageerror', e => errs.push(q + ': ' + e.message));
    await p.goto(`http://localhost:8765/?auto=1&${q}`); await p.waitForTimeout(1500);
    await p.evaluate(() => { const G = window.__vida.G; G.banners = []; G.lastEvent = 999; G.lastMoment = 999; });
    return p;
  };
  // penaltis: apuntar a la escuadra izquierda y al centro
  for (const [n, tx, ty] of [['esquina', 80, 360], ['centro', 270, 400]]) {
    const p = await page('age=20&path=futbol');
    await p.evaluate(() => window.__vida.startMoment('penaltis'));
    await p.waitForTimeout(600);
    await p.evaluate(([tx, ty]) => { const V = window.__vida, b = V.G.moment.b; V.momentInput('down', b.x, b.y); V.momentInput('move', b.x + (tx - b.x) / 1.9, b.y + (ty - b.y) / 1.9); }, [tx, ty]);
    await p.screenshot({ path: `${out}/pen_aim_${n}.png` });
    await p.evaluate(() => window.__vida.momentInput('up', 0, 0));
    await p.waitForTimeout(450);
    await p.screenshot({ path: `${out}/pen_${n}.png` });
    await p.close();
  }
  // etapas del camino
  for (const [q, n] of [['age=14&path=futbol', 'cantera'], ['age=26&path=futbol&flags=pareja', 'estadio'], ['age=50&path=futbol&branch=leyenda', 'tv'], ['age=50&path=futbol&branch=entrenador', 'barrio'], ['age=50&path=futbol&branch=juerga', 'bar']]) {
    const p = await page(q);
    if (q.includes('pareja')) await p.evaluate(() => { window.__vida.G.partner = 'Vanesa'; });
    await p.waitForTimeout(3200);
    await p.screenshot({ path: `${out}/stage_${n}.png` });
    await p.close();
  }
  // carta del ojeador y pantalla de caminos
  const p = await page('age=12&flags=futbolin');
  await p.evaluate(() => { const V = window.__vida; V.G.age = 11; V.G.lastEvent = -5; });
  await p.waitForTimeout(6000);
  await p.screenshot({ path: `${out}/ojeador.png` });
  await p.evaluate(() => { const V = window.__vida; if (V.G.card) V.choose(0); });
  await p.waitForTimeout(800);
  await p.screenshot({ path: `${out}/nuevo_camino.png` });
  await p.evaluate(() => window.__vida.openPaths());
  await p.waitForTimeout(400);
  await p.screenshot({ path: `${out}/caminos.png` });
  console.log('ERR:', errs.join('\n') || 'ninguno');
  await b.close();
})();
