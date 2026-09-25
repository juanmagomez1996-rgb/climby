"""Genera spritesheets de efectos (VFX) procedurales con transparencia.

Salida: assets/sprites/vfx_*.png + vfx_*.json (formato tipo TexturePacker "frames" + meta).
Uso: python3 tools/make_vfx_sheets.py
"""
import json, math, os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
rng = np.random.default_rng(7)


def grid(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    dx, dy = (x - c) / c, (y - c) / c
    return np.sqrt(dx * dx + dy * dy), np.arctan2(dy, dx)


def rgba(color, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.zeros(a.shape + (4,), np.float32)
    col = np.asarray(color, np.float32)
    # núcleo más blanco donde la intensidad es alta
    white = np.clip((a - 0.65) / 0.35, 0, 1)[..., None]
    img[..., :3] = col * (1 - white) + 255 * white
    img[..., 3] = a * 255
    return Image.fromarray(img.astype(np.uint8), 'RGBA')


def sheet(name, frames, size, fps, loop, cols=None):
    cols = cols or math.ceil(math.sqrt(len(frames)))
    rows = math.ceil(len(frames) / cols)
    img = Image.new('RGBA', (cols * size, rows * size))
    meta = {'frames': {}, 'animations': {name: []},
            'meta': {'image': f'{name}.png', 'size': {'w': cols * size, 'h': rows * size},
                     'frameSize': size, 'cols': cols, 'rows': rows, 'count': len(frames), 'fps': fps, 'loop': loop}}
    for i, f in enumerate(frames):
        x, y = (i % cols) * size, (i // cols) * size
        img.paste(f, (x, y))
        key = f'{name}_{i:02d}'
        meta['frames'][key] = {'frame': {'x': x, 'y': y, 'w': size, 'h': size}}
        meta['animations'][name].append(key)
    img.save(os.path.join(OUT, f'{name}.png'), optimize=True)
    with open(os.path.join(OUT, f'{name}.json'), 'w') as fh:
        json.dump(meta, fh, indent=1)
    print(name, img.size)


def shockwave(n=16, size=256):
    """Anillo de energía que se expande (visto desde arriba, para proyectar en el suelo)."""
    r, a = grid(size)
    noise = rng.random(64)
    out = []
    for i in range(n):
        t = (i + 1) / n
        radius = 0.08 + 0.88 * (1 - (1 - t) ** 2)
        width = 0.035 + 0.1 * t
        wob = 1 + 0.03 * np.interp((a + math.pi) / (2 * math.pi) * 63, np.arange(64), noise)
        ring = np.exp(-((r * wob - radius) / width) ** 2)
        inner = np.clip(1 - r / max(radius, 1e-3), 0, 1) ** 2 * 0.35
        alpha = (ring + inner) * (1 - t) ** 0.8 * 1.3
        out.append(rgba((139, 92, 255), alpha))
    sheet('vfx_shockwave', out, size, 30, False)


def impact(n=12, size=192):
    """Chispa de impacto con rayos radiales."""
    r, a = grid(size)
    rays = rng.random(24) * 0.6 + 0.4
    out = []
    for i in range(n):
        t = (i + 1) / n
        ray = np.interp((a + math.pi) / (2 * math.pi) * 23, np.arange(24), rays)
        spikes = np.clip(1 - r / (ray * (0.3 + 0.7 * t)), 0, 1) ** 3 * (np.cos(a * 12) * 0.5 + 0.5) ** 6
        core = np.exp(-(r / (0.12 + 0.25 * t)) ** 2)
        alpha = (spikes * 1.4 + core) * (1 - t) ** 1.2
        out.append(rgba((255, 90, 110), alpha))
    sheet('vfx_impact', out, size, 30, False)


def explosion(n=16, size=256):
    """Explosión del dron: bola de fuego rojo-naranja con humo."""
    r, a = grid(size)
    big = np.zeros((size, size), np.float32)
    for k, w in ((6, 0.5), (12, 0.3), (24, 0.2)):  # ruido fractal suave
        base = (rng.random((k, k)) * 255).astype(np.uint8)
        big += w * np.array(Image.fromarray(base).resize((size, size), Image.BICUBIC), np.float32) / 255
    out = []
    for i in range(n):
        t = (i + 1) / n
        rad = 0.3 + 0.62 * (1 - (1 - t) ** 3)
        body = np.clip((1 - r / rad) * 1.6 + (big - 0.5) * 0.9, 0, 1)
        fire = body ** (0.6 + 2.5 * t)
        heat = np.clip(1 - t * 1.4, 0, 1)
        img = np.zeros((size, size, 4), np.float32)
        img[..., 0] = 255 * (0.35 + 0.65 * heat) * fire + 70 * (1 - heat) * body
        img[..., 1] = (60 + 160 * fire * heat) * fire + 60 * (1 - heat) * body
        img[..., 2] = 70 * fire * heat + 70 * (1 - heat) * body
        img[..., 3] = np.clip(body * (1 - t ** 2) * 1.3, 0, 1) * 255
        out.append(Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGBA'))
    sheet('vfx_explosion', out, size, 24, False)


def aura(n=16, size=192):
    """Aura de energía en bucle (se muestra alrededor del héroe cuando está cargado)."""
    r, a = grid(size)
    out = []
    for i in range(n):
        ph = i / n * 2 * math.pi
        flick = 0.08 * np.sin(a * 5 + ph) + 0.05 * np.sin(a * 11 - ph * 2)
        rim = np.exp(-((r - (0.62 + flick)) / 0.12) ** 2)
        glow = np.exp(-(r / 0.75) ** 4) * 0.25
        out.append(rgba((139, 92, 255), (rim + glow) * (0.85 + 0.15 * math.sin(ph))))
    sheet('vfx_aura', out, size, 20, True)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    shockwave(); impact(); explosion(); aura()
