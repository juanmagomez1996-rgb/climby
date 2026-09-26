// Exporta html/data.js (fuente de verdad del contenido) a assets/data/life.json para Flutter.
const fs = require('fs'), vm = require('vm'), path = require('path');
const root = path.join(__dirname, '..'), ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(root, 'html/data.js'), 'utf8'), ctx);
fs.mkdirSync(path.join(root, 'assets/data'), { recursive: true });
fs.writeFileSync(path.join(root, 'assets/data/life.json'), JSON.stringify(ctx.window.LIFE));
const m = {}; for (const f of fs.readdirSync(path.join(root, 'assets/chars'))) if (f.endsWith('.json')) m[f.slice(0, -5)] = JSON.parse(fs.readFileSync(path.join(root, 'assets/chars', f)));
fs.writeFileSync(path.join(root, 'assets/data/chars.json'), JSON.stringify(m));
console.log('life.json:', ctx.window.LIFE.events.length, 'eventos; chars.json:', Object.keys(m).length, 'personajes');
