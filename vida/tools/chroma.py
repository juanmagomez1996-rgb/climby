#!/usr/bin/env python3
"""Utilidades de croma verde para los assets de Una Vida en 20 Minutos."""
import numpy as np
from PIL import Image

def key(im):
    """RGB(A) con fondo verde -> RGBA con alfa y sin halo verde."""
    a = np.asarray(im.convert('RGB')).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.maximum(r, b)
    gd = g - m                               # cuánto domina el verde
    alpha = 1 - np.clip((gd - 25) / 70, 0, 1)
    # despill: limita el verde a max(r,b) en los bordes
    spill = np.clip(gd, 0, None) > 0
    g2 = np.where(spill, np.minimum(g, m + 8), g)
    out = np.dstack([r, g2, b, alpha * 255]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

def bbox(ims, thr=24):
    """Caja común (x0,y0,x1,y1) de varias RGBA."""
    x0 = y0 = 10**9; x1 = y1 = 0
    for im in ims:
        al = np.asarray(im)[..., 3] > thr
        ys, xs = np.nonzero(al)
        if len(xs) == 0: continue
        x0, y0 = min(x0, xs.min()), min(y0, ys.min())
        x1, y1 = max(x1, xs.max() + 1), max(y1, ys.max() + 1)
    return x0, y0, x1, y1

def clean(im, thr=24):
    """Quita motas sueltas de alfa baja."""
    a = np.asarray(im).copy()
    a[..., 3][a[..., 3] < thr] = 0
    return Image.fromarray(a, 'RGBA')
