// Prueba automática: juega un rato y hace capturas. Uso: node shot.js [segundos] [edad]
const { chromium } = require('playwright');
(async () => {
  const secs = +(process.argv[2] || 12), age = process.argv[3] || '';
  const out = process.env.OUT || '/tmp';
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 2 });
  const errs = [], shotted = {}; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => m.type() === 'error' && errs.push(m.text()));
  await p.goto(`http://localhost:8765/?auto=1${age ? '&age=' + age : ''}`);
  await p.waitForTimeout(2500);
  for (let i = 0; i < secs; i++) {
    // salta a veces, elige la primera carta si aparece
    const st = await p.evaluate(() => { const G = window.__vida.G; return G ? { card: !!G.card, mom: G.moment && G.moment.id, age: G.age, st: G.st.map(Math.round), dead: G.dead } : null; });
    if (st && (st.card || st.mom) && !shotted[st.card ? 'c' + st.age : st.mom]) { shotted[st.card ? 'c' + st.age : st.mom] = 1; await p.waitForTimeout(700); await p.screenshot({ path: `${out}/shot_${age || 0}_${st.card ? 'card' : st.mom}_${i}.png` }); }
    if (st && st.card) await p.evaluate(() => window.__vida.choose(0));
    else await p.mouse.click(200, 400);
    await p.waitForTimeout(1000);
    if (i % 8 === 7) await p.screenshot({ path: `${out}/shot_${age || 0}_${i}.png` });
    console.log(i, JSON.stringify(st));
  }
  console.log('ERRORES:', errs.length ? errs.join('\n') : 'ninguno');
  await b.close();
})();
