"""Green-screen animation videos -> one sprite sheet + JSON atlas per character.

Modes
  idle   seamless loop picked from the whole clip, every 2nd frame
  loop   seamless loop picked from the second half (the cycle is established by then)
  once   the whole action, fixed anchor so the body's own motion survives
  hold   like once, and the atlas marks the tail to loop (e.g. crying)
  jump   like once, but each frame sits on its own feet; split into rise / fall / land
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
F = 160                    # square frame (px); anchor at bottom centre
MAXF = {'idle': 24, 'loop': 20, 'once': 28, 'hold': 32, 'jump': 30}


def frames(video, fps=24):
    d = f'tmp_{os.path.basename(video)}'
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    subprocess.run([FF, '-loglevel', 'error', '-i', video, '-vf', f'fps={fps}', f'{d}/%04d.png'], check=True)
    return [np.asarray(Image.open(os.path.join(d, f)).convert('RGB')).astype(np.float32) for f in sorted(os.listdir(d))]


def key(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dom = g - np.maximum(r, b)
    a = 1 - np.clip((dom - 20) / (55 - 20), 0, 1)
    a[(g > 140) & (g > r + 35) & (g > b + 35)] = 0      # lit green floor / gradient backdrop
    out = rgb.copy(); out[..., 1] = np.minimum(g, np.maximum(r, b) + 6)
    a[a < .06] = 0
    return np.dstack([out, a * 255]).astype(np.uint8)


def bbox(alpha, thr=40):
    ys, xs = np.where(alpha > thr)
    return (xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else None


def body_center(alpha, b):
    top, bot = b[1], b[3]
    band = alpha[top + int((bot - top) * .15): top + int((bot - top) * .55)] > 60
    xs = np.where(band)[1]
    return xs.mean() if len(xs) else (b[0] + b[2]) / 2


def best_loop(seq, lo, hi):
    small = [np.asarray(Image.fromarray(f).resize((64, 64))).astype(np.float32) for f in seq]
    best = (1e18, 0, lo)
    for i in range(0, max(1, len(small) // 3)):
        for j in range(i + lo, min(len(small), i + hi + 1)):
            d = np.abs(small[i] - small[j]).mean()
            if d < best[0]:
                best = (d, i, j)
    return best[1], best[2]


def thin(seq, n):
    if len(seq) <= n:
        return seq
    idx = np.linspace(0, len(seq) - 1, n).round().astype(int)
    return [seq[i] for i in idx]


def process(name, anims, scale_from='idle'):
    data = {}
    for anim, (video, mode) in anims.items():
        raw = [key(f) for f in frames(video)][3:]
        if mode == 'idle':
            i, j = best_loop(raw, 36, 90); seq = raw[i:j]
        elif mode == 'loop':
            raw = raw[len(raw) // 2:]; i, j = best_loop(raw, 10, 26); seq = raw[i:j]
        else:
            # drop the still start (the video's first image) so the action begins at once
            sm = [np.asarray(Image.fromarray(f).resize((48, 48))).astype(np.float32) for f in raw]
            start = next((i for i in range(len(sm)) if np.abs(sm[i] - sm[0]).mean() > 6), 0)
            seq = raw[max(0, start - 2):]
        seq = thin(seq, MAXF[mode])
        data[anim] = (seq, mode)
        print(name, anim, mode, len(seq))
    ref = data[scale_from][0]
    stand_h = np.median([b[3] - b[1] for b in (bbox(f[..., 3]) for f in ref) if b])
    scale = F * .8 / stand_h

    rows, meta = [], {}
    for anim, (seq, mode) in data.items():
        boxes = [bbox(f[..., 3]) for f in seq]
        ok = [b for b in boxes if b]
        ubot = max(b[3] for b in ok)
        cs = [body_center(f[..., 3], b) if b else 0 for f, b in zip(seq, boxes)]
        if mode in ('once', 'hold', 'jump'):
            cs = [float(np.mean(cs[:3]))] * len(cs)          # fixed anchor keeps the motion
        else:
            k = 5; cs = np.convolve(np.pad(cs, (k // 2, k // 2), mode='edge'), np.ones(k) / k, mode='valid')
        row, lifts = [], []
        for f, b, cx in zip(seq, boxes, cs):
            im = Image.fromarray(f); im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
            bottom = ((b[3] if (mode == 'jump' and b) else ubot)) * scale
            lifts.append(ubot - (b[3] if b else ubot))
            cell = Image.new('RGBA', (F, F), (0, 0, 0, 0))
            cell.alpha_composite(im, (int(F / 2 - cx * scale), int(F - 4 - bottom)))
            row.append(cell)
        rows.append((anim, row))
        m = {'row': len(rows) - 1, 'frames': len(row), 'mode': mode}
        if mode == 'jump':
            L = np.array(lifts, float); top = int(L.argmax()); air = np.where(L > L.max() * .35)[0]
            m['rise'] = [int(i) for i in air if i <= top]
            m['fall'] = [int(i) for i in air if i > top] or [top]
            m['land'] = [int(i) for i in range(air.max() + 1, min(len(L), air.max() + 4))]
            m['crouch'] = [int(i) for i in range(max(0, air.min() - 4), air.min())]
        if mode == 'hold':
            m['loopFrom'] = int(len(row) * .6)
        meta[anim] = m

    cols = max(len(r) for _, r in rows)
    sheet = Image.new('RGBA', (cols * F, len(rows) * F), (0, 0, 0, 0))
    for y, (anim, row) in enumerate(rows):
        for x, cell in enumerate(row):
            sheet.alpha_composite(cell, (x * F, y * F))
    first = rows[0][1][0]; a = np.asarray(first)[..., 3]; b = bbox(a)
    sheet.save(f'{OUT}/{name}.png', optimize=True)
    atlas = {'frameW': F, 'frameH': F, 'anchorX': F / 2, 'anchorY': F - 4, 'bodyH': int(b[3] - b[1]), 'anims': meta}
    json.dump(atlas, open(f'{OUT}/{name}.json', 'w'), indent=1)
    print(name, sheet.size, atlas['bodyH'])


if __name__ == '__main__':
    process('brother', {
        'idle': ('bro_idle_sad.mp4', 'idle'), 'look': ('bro_look.mp4', 'once'), 'walk': ('bro_walk_sad.mp4', 'loop'),
        'run': ('bro_run.mp4', 'loop'), 'jump': ('bro_jump.mp4', 'jump'), 'push': ('bro_push.mp4', 'loop'),
        'pull': ('bro_pull.mp4', 'loop'), 'climb': ('bro_climb.mp4', 'once'), 'fall': ('bro_fall.mp4', 'loop'),
        'collapse': ('bro_collapse.mp4', 'once'), 'kneel': ('bro_kneel.mp4', 'hold'), 'offer': ('bro_offer.mp4', 'once')})
    process('mother', {'idle': ('mom_idle_sad.mp4', 'idle'), 'walk': ('mom_walk.mp4', 'loop'), 'receive': ('mom_receive.mp4', 'hold')})
