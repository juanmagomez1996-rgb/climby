"""Cut every separate silhouette out of the generated prop sheets."""
import json, sys
import numpy as np
from PIL import Image, ImageFilter
from collections import deque

OUT = sys.argv[1]
import os
ONLY = os.environ.get('ONLY')
SHEETS = {
    'l_props_forest2': ['stump', 'mushrooms', 'fern', 'deadBush', 'branch', 'sign', 'reeds', 'rockPile'],
    'l_props_grave': ['cross', 'tomb', 'crow', 'tireSwing', 'scarecrow', 'wheel', 'well', 'birdhouse'],
    'l_props_mine': ['cart', 'rail', 'barrels', 'ladder', 'planks', 'rootCurtain', 'crystals', 'pickaxe'],
    'l_props_town': ['lamp', 'pole', 'trashcan', 'fenceBroken', 'bicycle', 'doghouse', 'clothesline', 'steps'],
    'l_props_forest': ['treeTall', 'treeSmall', 'grass', 'thorns', 'log', 'rock', 'roots', 'fence'],
    'l_props_cave': ['stalL', 'stalM', 'stalS', 'mineFrame', 'stagL', 'stagM', 'chain', 'lantern'],
    'l_props_play': ['crate', 'trapOpen', 'trapShut', 'boulder', 'gate', 'lever', 'plate', 'rope'],
}
meta = {}
meta = json.load(open(f'{OUT}/props.json')) if os.path.exists(f'{OUT}/props.json') else {}
for sheet, names in SHEETS.items():
    if ONLY and sheet not in ONLY.split(','):
        continue
    im = Image.open(sheet + '.png').convert('RGBA')
    a = np.asarray(im)[..., 3] > 25
    # join thin parts (chain links, grass blades) before labelling
    m = Image.fromarray((a * 255).astype(np.uint8)).resize((im.width // 4, im.height // 4)).filter(ImageFilter.MaxFilter(9))
    g = np.asarray(m) > 0
    lab = np.zeros(g.shape, int); n = 0; boxes = []
    for y, x in zip(*np.nonzero(g)):
        if lab[y, x]:
            continue
        n += 1; q = deque([(y, x)]); lab[y, x] = n; ys = [y]; xs = [x]; cnt = 0
        while q:
            cy, cx = q.popleft(); cnt += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < g.shape[0] and 0 <= nx < g.shape[1] and g[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n; q.append((ny, nx)); ys.append(ny); xs.append(nx)
        if cnt > 60:
            boxes.append((min(xs) * 4, min(ys) * 4, max(xs) * 4 + 4, max(ys) * 4 + 4))
    # reading order: rows, then left to right
    boxes.sort(key=lambda b: (round((b[1] + b[3]) / 2 / (im.height / 2.2)), b[0]))
    print(sheet, len(boxes))
    for name, b in zip(names, boxes):
        crop = im.crop((max(0, b[0] - 6), max(0, b[1] - 6), min(im.width, b[2] + 6), min(im.height, b[3] + 6)))
        ca = np.asarray(crop)[..., 3]; ys, xs = np.where(ca > 20)
        crop = crop.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        s = min(1, 360 / max(crop.size))
        crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
        arr = np.asarray(crop).copy(); arr[..., :3] = 0          # pure black silhouettes
        Image.fromarray(arr).save(f'{OUT}/{name}.png', optimize=True)
        meta[name] = crop.size
json.dump(meta, open(f'{OUT}/props.json', 'w'), indent=1)
print(meta)
