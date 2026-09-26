// Prueba cada minijuego: lo arranca, simula entrada y hace capturas.
const { chromium } = require('playwright');
(async () => {
  const out = process.argv[2], b = await chromium.launch();
  const cases = [
    ['velas', 40, async p => { for (let i = 0; i < 6; i++) await p.evaluate(i => { const M = window.__vida.G.moment; const o = M.objs[i]; if (o) window.__vida.momentInput('move', o.x, o.y - 40); }, i); }],
    ['canasta', 16, async p => { await p.evaluate(() => { const V = window.__vida; V.momentInput('down', 120, 616); V.momentInput('move', 20, 740); }); }],
    ['ramo', 29, async p => { await p.evaluate(() => { const V = window.__vida; V.momentInput('down', 300, 600); }); }],
    ['aparcar', 18, async p => { await p.evaluate(() => window.__vida.momentInput('down', 270, 500)); }],
    ['pesca', 66, null],
    ['recuerdos', 75, async p => { await p.evaluate(() => { const V = window.__vida, M = V.G.moment; const c = M.cards[0]; V.momentInput('down', c.x + 20, c.y + 20); const d = M.cards.find(k => k !== c && k.id === c.id); V.momentInput('down', d.x + 20, d.y + 20); const e = M.cards.find(k => !k.done); V.momentInput('down', e.x + 10, e.y + 10); }); }],
  ];
  const errs = [];
  for (const [id, age, act] of cases) {
    const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 1.5 });
    p.on('pageerror', e => errs.push(id + ': ' + e.message));
    await p.goto(`http://localhost:8765/?auto=1&age=${age}`); await p.waitForTimeout(1500);
    await p.evaluate(id => { const V = window.__vida, G = V.G; G.banners = []; G.lastEvent = 999; G.lastMoment = 999; G.card = null; G.seen = ['cole', 'perro', 'boda', 'lucia', 'tardes']; V.startMoment(id); }, id);
    await p.waitForTimeout(700);
    if (act) await act(p);
    await p.waitForTimeout(id === 'pesca' ? 2500 : id === 'aparcar' ? 900 : 500);
    await p.screenshot({ path: `${out}/mom_${id}.png` });
    await p.close();
  }
  console.log('ERR:', errs.join('\n') || 'ninguno');
  await b.close();
})();
