#!/usr/bin/env python3
"""Empaqueta web/ en dist/vida.html (formato artifact: sin <html>/<head>, CSS y JS en línea)
y escribe dist/files.json con el mapa de assets para publicarlos al lado."""
import re, json, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
web = ROOT / 'web'; dist = ROOT / 'dist'; dist.mkdir(exist_ok=True)
html = (web / 'index.html').read_text()
body = re.search(r'<body>(.*)</body>', html, re.S).group(1)
body = re.sub(r'<script src="[^"]+"></script>\s*', '', body)
js = ''.join(f'<script>\n{(web / n).read_text()}\n</script>\n' for n in ['data.js', 'meta.js', 'game.js'])
css = (web / 'style.css').read_text()
out = f'<title>Una Vida en 20 Minutos</title>\n<meta name="theme-color" content="#2b1d14">\n<style>\n{css}</style>\n{body}\n{js}'
(dist / 'vida.html').write_text(out)
files = {str(p.relative_to(ROOT)): str(p.relative_to(ROOT.parent)) for p in sorted((ROOT / 'assets').rglob('*')) if p.is_file() and p.suffix in ('.webp', '.ttf', '.mp3', '.ogg')}
(dist / 'files.json').write_text(json.dumps(files, indent=0))
print(len(out) // 1024, 'KB html,', len(files), 'files')
