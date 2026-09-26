#!/usr/bin/env python3
"""Clip de salto (fondo verde) -> hoja de sprites del salto con los pies alineados.
La física del juego pone la altura; aquí solo interesa la pose (agacharse, encoger, aterrizar).
Uso: jump.py nombre   (lee raw/vid_<nombre>_jump.mp4, escribe assets/chars/<nombre>_jump.webp/.json)"""
import sys, os, json, glob, subprocess, pathlib, shutil
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from chroma import key, bbox, clean
import imageio_ffmpeg
ROOT = pathlib.Path(__file__).resolve().parent.parent
name = sys.argv[1]; N = int(sys.argv[2]) if len(sys.argv) > 2 else 12; H = 400
tmp = ROOT / 'raw' / f'fr_{name}_jump'; shutil.rmtree(tmp, ignore_errors=True); tmp.mkdir()
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-loglevel', 'error', '-i', str(ROOT / 'raw' / f'vid_{name}_jump.mp4'), str(tmp / '%03d.png')], check=True)
ims = [clean(key(Image.open(f))) for f in sorted(glob.glob(str(tmp / '*.png')))]
feet, tops = [], []
for im in ims:
    a = np.asarray(im)[..., 3] > 60; rows = np.nonzero(a.any(1))[0]
    feet.append(rows.max() if len(rows) else 0); tops.append(rows.min() if len(rows) else 0)
base = np.median(feet[:4]); air = [i for i, f in enumerate(feet) if f < base - 10]
if not air: sys.exit(f'{name}: no se detecta el salto')
# el primer despegue: bloque continuo de fotogramas en el aire
a0 = air[0]; a1 = a0
while a1 + 1 < len(feet) and feet[a1 + 1] < base - 10: a1 += 1
s0, s1 = max(0, a0 - 5), min(len(ims) - 1, a1 + 5)   # un poco de impulso y de aterrizaje
idx = [round(s0 + k * (s1 - s0) / (N - 1)) for k in range(N)]
# alinear: bajar cada fotograma para que sus pies toquen la línea base
shifted = []
for i in idx:
    im = ims[i]; dy = int(base - feet[i]); c = Image.new('RGBA', im.size); c.alpha_composite(im, (0, dy)); shifted.append(c)
x0, y0, x1, y1 = bbox(shifted); pad = 6
x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(shifted[0].width, x1 + pad), min(shifted[0].height, y1 + pad)
# misma escala que el ciclo de andar: la altura de referencia es la del personaje de pie
m = json.load(open(ROOT / 'assets' / 'chars' / f'{name}.json'))
stand = (base - tops[0])
s = (m['fh'] * m['foot'] * 0.97) / stand
fw, fh = round((x1 - x0) * s), round((y1 - y0) * s)
cols = min(6, N); rows = (N + cols - 1) // cols
sheet = Image.new('RGBA', (fw * cols, fh * rows))
for k, im in enumerate(shifted):
    sheet.paste(im.crop((x0, y0, x1, y1)).resize((fw, fh), Image.LANCZOS), ((k % cols) * fw, (k // cols) * fh))
out = ROOT / 'assets' / 'chars'
sheet.save(out / f'{name}_jump.webp', quality=88, method=6)
foot = (base - y0 + 1) / (y1 - y0)
# fotogramas del tramo en el aire dentro de la hoja
fa0 = min(range(N), key=lambda k: abs(idx[k] - a0)); fa1 = min(range(N), key=lambda k: abs(idx[k] - a1))
json.dump({'frames': N, 'cols': cols, 'fw': fw, 'fh': fh, 'foot': round(float(foot), 4), 'air0': fa0, 'air1': fa1, 'ref': round(m['fh'] * m['foot'] * 0.97, 1)}, open(out / f'{name}_jump.json', 'w'))
print(name, 'salto', s0, a0, a1, s1, '-> air', fa0, fa1, sheet.size)
