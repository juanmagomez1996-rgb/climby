#!/usr/bin/env python3
"""Vídeo de ciclo (fondo verde) -> hoja de sprites RGBA + JSON.
Uso: sheet.py nombre [--frames N] [--height H]
Lee raw/vid_<nombre>.mp4 y escribe assets/chars/<nombre>.webp y .json"""
import sys, json, glob, os, subprocess, argparse, pathlib, shutil
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from chroma import key, bbox, clean
import imageio_ffmpeg

ROOT = pathlib.Path(__file__).resolve().parent.parent
ap = argparse.ArgumentParser()
ap.add_argument('name'); ap.add_argument('--frames', type=int, default=16)
ap.add_argument('--height', type=int, default=400); ap.add_argument('--cols', type=int, default=8)
ap.add_argument('--period', type=int, default=0)
a = ap.parse_args()
tmp = ROOT / 'raw' / ('fr_' + a.name)
shutil.rmtree(tmp, ignore_errors=True); tmp.mkdir()
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-loglevel', 'error', '-i', str(ROOT / 'raw' / f'vid_{a.name}.mp4'), str(tmp / '%03d.png')], check=True)
fs = sorted(glob.glob(str(tmp / '*.png')))
small = [np.asarray(Image.open(f).convert('L').resize((96, 128))).astype(np.float32) for f in fs]
n = len(fs)
# periodo: el fotograma (>=18) más parecido al primero; si no hay uno claro, todo el clip
d = [np.abs(small[i] - small[0]).mean() for i in range(n)]
if a.period: p = a.period
else:
    cand = range(18, n - 1)
    p = min(cand, key=lambda i: d[i])
    if d[p] > 1.6 * min(d[1:4]) + 1.5: p = n - 1
print(a.name, 'frames', n, 'period', p, 'diff', round(d[p], 2))
idx = [round(i * p / a.frames) for i in range(a.frames)]
ims = [clean(key(Image.open(fs[i]))) for i in idx]
x0, y0, x1, y1 = bbox(ims)
pad = 6
x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
x1, y1 = min(ims[0].width, x1 + pad), min(ims[0].height, y1 + pad)
s = a.height / (y1 - y0)
fw, fh = round((x1 - x0) * s), a.height
cols = min(a.cols, len(ims)); rows = (len(ims) + cols - 1) // cols
sheet = Image.new('RGBA', (fw * cols, fh * rows))
for k, im in enumerate(ims):
    fr = im.crop((x0, y0, x1, y1)).resize((fw, fh), Image.LANCZOS)
    sheet.paste(fr, ((k % cols) * fw, (k // cols) * fh))
out = ROOT / 'assets' / 'chars'; out.mkdir(parents=True, exist_ok=True)
sheet.save(out / f'{a.name}.webp', quality=88, method=6)
# pies: fila más baja con alfa en el primer fotograma (relativa a la altura)
al = np.asarray(ims[0].crop((x0, y0, x1, y1)))[..., 3] > 60
foot = (np.nonzero(al.any(1))[0].max() + 1) / (y1 - y0)
json.dump({'frames': len(ims), 'cols': cols, 'fw': fw, 'fh': fh, 'foot': round(float(foot), 4)}, open(out / f'{a.name}.json', 'w'))
print('->', out / f'{a.name}.webp', sheet.size, os.path.getsize(out / f'{a.name}.webp') // 1024, 'KB')
