#!/usr/bin/env python3
"""Trocea las láminas 4x4 de objetos (fondo verde) en sprites RGBA recortados."""
import sys, os, pathlib
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from chroma import key, bbox, clean
ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEETS = {
 'items_coll': ['apple', 'coin', 'star', 'heart', 'bill', 'balloon', 'letter', 'carrot',
                'lollipop', 'ball', 'book', 'trophy', 'flowers', 'cake', 'burger', 'clock'],
 'items_mini': ['hoop', 'basketball', 'car', 'bigcake', 'candle', 'bouquet', 'fish', 'bobber',
                'butterfly', 'bird', 'leaf', 'petal', 'photo', 'kite', 'rattle', 'boat'],
 'items_obst': ['puddle', 'rock', 'goose', 'homework', 'skate', 'cone', 'bills', 'coffee',
                'briefcase', 'banana', 'pigeon', 'wetfloor', 'cactus', 'storm', 'plane', 'duck'],
}
out = ROOT / 'assets' / 'items'; out.mkdir(parents=True, exist_ok=True)
for sheet, names in SHEETS.items():
    im = key(Image.open(ROOT / 'raw' / f'{sheet}.png'))
    c = im.width // 4
    for i, n in enumerate(names):
        cell = clean(im.crop(((i % 4) * c, (i // 4) * c, (i % 4 + 1) * c, (i // 4 + 1) * c)), 40)
        x0, y0, x1, y1 = bbox([cell], 60)
        spr = cell.crop((max(0, x0 - 4), max(0, y0 - 4), min(c, x1 + 4), min(c, y1 + 4)))
        spr.thumbnail((256, 256), Image.LANCZOS)
        spr.save(out / f'{n}.webp', quality=90, method=6)
print(sorted(os.listdir(out)))
