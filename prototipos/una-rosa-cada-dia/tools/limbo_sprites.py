"""Turn the realistic sprite sheets into LIMBO-style silhouettes:
pure black body, one small white eye found per frame, the rose kept red."""
import json, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
for name, rose in [('brother', True), ('mother', False)]:
    atlas = json.load(open(f'{SRC}/{name}.json'))
    im = np.asarray(Image.open(f'{SRC}/{name}.png').convert('RGBA')).astype(np.int32)
    r, g, b, a = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
    red = ((r > 100) & (g < r * .42) & (b < r * .5) & (a > 60)) if rose else np.zeros_like(a, bool)
    fw0, fh0, H0 = atlas['frameW'], atlas['frameH'], atlas['bodyH']
    if rose:  # the rose is never in the head: drop red specks in the top of each figure
        for anim, m in atlas['anims'].items():
            for f in range(m['frames']):
                x0, y0 = f * fw0, m['row'] * fh0
                cell = a[y0:y0 + fh0, x0:x0 + fw0] > 80
                ys = np.where(cell.any(axis=1))[0]
                if len(ys): red[y0:y0 + ys.min() + int(H0 * .2), x0:x0 + fw0] = False
    out = np.zeros_like(im)
    out[..., 3] = np.where(a > 30, np.minimum(255, a * 1.15), 0)
    out[red, 0] = np.clip(r[red] * 1.1, 0, 255); out[red, 1] = g[red] * .5; out[red, 2] = b[red] * .6
    sheet = Image.fromarray(out.astype(np.uint8))
    draw = ImageDraw.Draw(sheet)
    fw, fh, H = atlas['frameW'], atlas['frameH'], atlas['bodyH']
    eyes = Image.new('RGBA', sheet.size, (0, 0, 0, 0)); ed = ImageDraw.Draw(eyes)
    for anim, m in atlas['anims'].items():
        if anim in ('collapse',):
            continue  # the eye goes out when he dies
        for f in range(m['frames']):
            x0, y0 = f * fw, m['row'] * fh
            cell = out[y0:y0 + fh, x0:x0 + fw, 3] > 80
            ys = np.where(cell.any(axis=1))[0]
            if not len(ys):
                continue
            top = ys.min()
            row = top + int(H * .075)
            xs = np.where(cell[row])[0]
            if not len(xs):
                continue
            ex, ey, rad = x0 + xs.max() - H * .05, y0 + row, max(1.3, H * .0085)
            ed.ellipse([ex - rad * 1.25, ey - rad, ex + rad * 1.25, ey + rad], fill=(255, 255, 255, 255))
    glow = eyes.filter(ImageFilter.GaussianBlur(1.4))
    sheet.alpha_composite(glow); sheet.alpha_composite(eyes)
    sheet.save(f'{OUT}/{name}.png', optimize=True)
    if rose:   # the same sheet with empty hands, for when the rose is left on the ground
        gone = np.asarray(Image.fromarray((red * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
        nr = out.copy(); nr[gone, 3] = 0
        nrs = Image.fromarray(nr.astype(np.uint8)); nrs.alpha_composite(glow); nrs.alpha_composite(eyes)
        nrs.save(f'{OUT}/{name}_nr.png', optimize=True)
    # traversal clips: how far the body reaches forward, row band by row band, so the game can keep
    # every part below a ledge's top out of the wall (he climbs its face, not through it)
    alpha = np.asarray(sheet)[..., 3]
    for anim, m in atlas['anims'].items():
        if m.get('kind') != 'rootclip':
            continue
        prof = []
        for f in range(m['frames']):
            cell = alpha[m['row'] * fh:(m['row'] + 1) * fh, f * fw:(f + 1) * fw] > 90
            row = []
            for b0 in range(0, fh, 8):
                xs = np.where(cell[b0:b0 + 8].any(axis=0))[0]
                row.append(int(xs.max() - fw / 2) if len(xs) else -99)
            prof.append(row)
        m['prof'] = prof; m['profBin'] = 8
    json.dump(atlas, open(f'{OUT}/{name}.json', 'w'), indent=1)
    prev = Image.new('RGBA', sheet.size, (190, 190, 190, 255)); prev.alpha_composite(sheet)
    prev.convert('RGB').save(f'{OUT}/../{name}_sil_prev.jpg', quality=80)
    print(name, sheet.size)
