#!/usr/bin/env python3
"""Panorámicas -> fondos enlazables (assets/bg/bg_N.webp).
raw/roll_bg_N = original desplazado media anchura (la unión queda en el centro);
raw/seam_bg_N = la misma imagen con el centro repintado por Nano Banana.
Se pega solo la franja central (con bordes difuminados), así los extremos casan exactamente."""
import pathlib
import numpy as np
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parent.parent
H = 720
out = ROOT / 'assets' / 'bg'; out.mkdir(parents=True, exist_ok=True)
import sys
NAMES = sys.argv[1:] or [f'bg_{i}' for i in range(5)]
# fondos sin texto cuya unión no se pudo repintar bien: se enlazan con su reflejo (original + espejo)
MIRROR = {'bgf_barrio'}
from PIL import ImageOps
for i in NAMES:
    if i in MIRROR:
        o = Image.open(ROOT / 'raw' / f'{i}.png').convert('RGB'); o = o.resize((round(o.width * H / o.height), H), Image.LANCZOS)
        img = Image.new('RGB', (o.width * 2, H)); img.paste(o, (0, 0)); img.paste(ImageOps.mirror(o), (o.width, 0))
        img.save(out / f'{i}.webp', quality=80, method=6); print(i, img.size, 'espejo'); continue
    a = np.asarray(Image.open(ROOT / 'raw' / f'roll_{i}.png').convert('RGB')).astype(np.float32)
    s = Image.open(ROOT / 'raw' / f'seam_{i}.png').convert('RGB').resize((a.shape[1], a.shape[0]), Image.LANCZOS)
    s = np.asarray(s).astype(np.float32)
    W = a.shape[1]; x = np.arange(W)[None, :, None] / W
    m = np.clip((0.33 - np.abs(x - 0.5)) / 0.08, 0, 1)   # 1 en el centro, 0 fuera del 50 % central
    m = m * m * (3 - 2 * m)
    img = Image.fromarray((a * (1 - m) + s * m).clip(0, 255).astype(np.uint8))
    img = img.resize((round(img.width * H / img.height), H), Image.LANCZOS)
    img.save(out / f'{i}.webp', quality=82, method=6); print(i, img.size)
if sys.argv[1:]: sys.exit()
im = Image.open(ROOT / 'raw' / 'titlefix.png').convert('RGB'); im = im.resize((720, round(im.height * 720 / im.width)), Image.LANCZOS)
im.save(out / 'title.webp', quality=82, method=6); print('title', im.size)
