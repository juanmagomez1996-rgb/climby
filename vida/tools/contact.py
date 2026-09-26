#!/usr/bin/env python3
"""Hoja de contactos de raw/<prefijo>*.png -> scratchpad. Uso: contact.py prefijo salida.jpg [alto]"""
import sys, glob, pathlib
from PIL import Image
RAW = pathlib.Path(__file__).resolve().parent.parent / 'raw'
files = sorted(glob.glob(str(RAW / (sys.argv[1] + '*.png'))))
h = int(sys.argv[3]) if len(sys.argv) > 3 else 360
ims = [Image.open(f).convert('RGB') for f in files]
ims = [i.resize((int(i.width * h / i.height), h)) for i in ims]
per = max(1, int(1800 // (ims[0].width + 8)))
rows = [ims[i:i + per] for i in range(0, len(ims), per)]
W = max(sum(i.width + 8 for i in r) for r in rows)
out = Image.new('RGB', (W, len(rows) * (h + 8)), (40, 40, 40))
for y, r in enumerate(rows):
    x = 0
    for i in r: out.paste(i, (x, y * (h + 8))); x += i.width + 8
out.save(sys.argv[2], quality=80); print([pathlib.Path(f).name for f in files])
