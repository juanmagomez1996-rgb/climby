// Captura la versión Flutter (compilada para web): menú, partida y cartas.
const { chromium } = require('playwright');
(async () => {
  const out = process.env.OUT, b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 2, locale: 'es-ES' });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => m.type() === 'error' && errs.push(m.text()));
  await p.goto('http://localhost:8766/'); await p.waitForTimeout(9000);
  await p.screenshot({ path: out + '/f_menu.png' });
  await p.mouse.click(202, 565); await p.waitForTimeout(1500); // VIVIR
  for (let i = 0; i < 40; i++) {
    await p.mouse.click(200, 380); await p.waitForTimeout(700);
    if (i === 8 || i === 20 || i === 39) await p.screenshot({ path: `${out}/f_play_${i}.png` });
  }
  console.log('ERR:', errs.slice(0, 5).join('\n') || 'ninguno');
  await b.close();
})();
