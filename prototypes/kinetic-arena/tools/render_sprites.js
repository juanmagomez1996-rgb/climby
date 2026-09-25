// Renderiza los spritesheets del héroe y del dron con Chromium sin pantalla (Playwright).
// Uso: node tools/render_sprites.js
// Si no hay acceso a los CDN, define THREE_LOCAL=/ruta/con/three.min.js y examples/js/.
const http = require('http'), fs = require('fs'), path = require('path');
const { execSync } = require('child_process');
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require(path.join(execSync('npm root -g').toString().trim(), 'playwright'))); }

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'assets', 'sprites');
const LOCAL = process.env.THREE_LOCAL;
const types = { '.html': 'text/html', '.js': 'application/javascript', '.glb': 'model/gltf-binary', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const f = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(f, (err, data) => {
    if (err) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8766);

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage();
  page.on('pageerror', e => console.error('pageerror', e.message));
  if (LOCAL) {
    await page.route(/three\.min\.js/, r => r.fulfill({ path: path.join(LOCAL, 'three.min.js'), contentType: 'application/javascript' }));
    await page.route(/examples\/js\/(.*)$/, r => r.fulfill({ path: path.join(LOCAL, 'examples/js', r.request().url().match(/examples\/js\/(.*)$/)[1]), contentType: 'application/javascript' }));
  }
  await page.goto('http://localhost:8766/tools/render_sprites.html');
  await page.waitForFunction(() => document.title === 'DONE', null, { timeout: 600000 });
  const result = await page.evaluate(() => window.RESULT);
  if (result.error) throw new Error(result.error);
  for (const [name, v] of Object.entries(result)) {
    fs.writeFileSync(path.join(outDir, name + '.png'), Buffer.from(v.png.split(',')[1], 'base64'));
    fs.writeFileSync(path.join(outDir, name + '.json'), JSON.stringify(v.json, null, 1));
    console.log('ok', name, v.json.meta.size);
  }
  await browser.close();
  server.close();
})().catch(e => { console.error(e); process.exit(1); });
