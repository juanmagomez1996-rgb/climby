#!/usr/bin/env python3
"""Viñetas de cartas (assets/ev), logo (assets/ui/logo.webp) y lápida (assets/bg/tomb.webp)."""
import sys, os, glob, pathlib
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from chroma import key, bbox, clean
ROOT = pathlib.Path(__file__).resolve().parent.parent
ev = ROOT / 'assets' / 'ev'; ev.mkdir(parents=True, exist_ok=True)
for f in sorted(glob.glob(str(ROOT / 'raw' / 'ev_*.png'))):
    im = Image.open(f).convert('RGB'); w, h = im.size
    # recorte 2:1 centrado (la carta muestra una franja panorámica)
    ch = int(w / 2); y0 = max(0, (h - ch) // 2); im = im.crop((0, y0, w, y0 + ch)).resize((720, 360), Image.LANCZOS)
    im.save(ev / (pathlib.Path(f).stem[3:] + '.webp'), quality=78, method=6)
ui = ROOT / 'assets' / 'ui'; ui.mkdir(parents=True, exist_ok=True)
lg = clean(key(Image.open(ROOT / 'raw' / 'logo.png')), 30); x0, y0, x1, y1 = bbox([lg], 40)
lg = lg.crop((x0 - 6, y0 - 6, x1 + 6, y1 + 6)); lg.thumbnail((900, 900), Image.LANCZOS); lg.save(ui / 'logo.webp', quality=90, method=6)
tb = Image.open(ROOT / 'raw' / 'tomb.png').convert('RGB'); tb = tb.resize((720, round(tb.height * 720 / tb.width)), Image.LANCZOS)
tb.save(ROOT / 'assets' / 'bg' / 'tomb.webp', quality=80, method=6)
print(len(os.listdir(ev)), 'viñetas; logo', lg.size, '; lápida', tb.size)
