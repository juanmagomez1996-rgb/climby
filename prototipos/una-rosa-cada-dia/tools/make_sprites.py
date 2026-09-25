"""Turn green-screen animation videos into game sprite sheets + a JSON atlas.

For each character: extract frames, chroma-key the green, despill, pick a
loopable segment, align every frame on the feet, measure a body collider,
and pack all animations into one sheet (one row per animation).
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
os.makedirs(OUT, exist_ok=True)
FRAME_H = 200          # sprite frame height in px (drawn ~40 logical px in game, crisp on retina)


def frames(video, fps=24):
    d = f'tmp_{os.path.basename(video)}'
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    subprocess.run([FF, '-loglevel', 'error', '-i', video, '-vf', f'fps={fps}', f'{d}/%04d.png'], check=True)
    return [np.asarray(Image.open(os.path.join(d, f)).convert('RGB')).astype(np.float32) for f in sorted(os.listdir(d))]


def key(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dom = g - np.maximum(r, b)                 # how "green-screen" a pixel is
    a = 1 - np.clip((dom - 28) / (90 - 28), 0, 1)
    out = rgb.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b) + 6)   # despill green fringes
    a[a < .06] = 0
    return np.dstack([out, a * 255]).astype(np.uint8)


def bbox(alpha, thr=40):
    ys, xs = np.where(alpha > thr)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max(), ys.max()


def body_center(alpha, top, bot):
    band = alpha[top + int((bot - top) * .15): top + int((bot - top) * .55)] > 60
    xs = np.where(band)[1]
    return xs.mean() if len(xs) else alpha.shape[1] / 2


def best_loop(rgba, min_len, max_len):
    """Pick [i, j) so frame j looks most like frame i (seamless loop)."""
    small = [np.asarray(Image.fromarray(f).resize((64, 64))).astype(np.float32) for f in rgba]
    best = (1e18, 0, min_len)
    n = len(small)
    for i in range(0, max(1, n // 3)):
        for j in range(i + min_len, min(n, i + max_len + 1)):
            d = np.abs(small[i] - small[j]).mean()
            if d < best[0]:
                best = (d, i, j)
    return best[1], best[2]


def process(name, anims):
    """anims: {anim: (video, mode)} mode in loop|once|jump"""
    data = {}
    for anim, (video, mode) in anims.items():
        raw = [key(f) for f in frames(video)]
        raw = raw[3:]  # first frames are the static start image
        if mode == 'loop':
            raw = raw[len(raw) // 2:]          # skip the start, where they are still standing
            i, j = best_loop(raw, 10, 22)
            seq = raw[i:j]
        elif mode == 'idle':
            i, j = best_loop(raw, 30, 60)
            seq = raw[i:j:2]
        else:
            seq = raw[::4]
        data[anim] = (seq, mode)
        print(name, anim, 'frames', len(seq))

    # common scale from standing height (idle, union bbox)
    idle = data.get('idle')[0]
    hs = [bbox(f[..., 3]) for f in idle]
    stand_h = np.median([b[3] - b[1] for b in hs if b])
    scale = FRAME_H * .86 / stand_h
    fw = int(FRAME_H * .62)

    rows, meta = [], {}
    for anim, (seq, mode) in data.items():
        boxes = [bbox(f[..., 3]) for f in seq]
        ubot = max(b[3] for b in boxes if b)
        centers = [body_center(f[..., 3], b[1], b[3]) if b else 0 for f, b in zip(seq, boxes)]
        # smooth horizontal anchor so arms swinging do not jitter the body
        k = 5
        cs = np.convolve(np.pad(centers, (k // 2, k // 2), mode='edge'), np.ones(k) / k, mode='valid')
        row = []
        lifts = []
        for f, b, cx in zip(seq, boxes, cs):
            im = Image.fromarray(f)
            im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
            bottom = (b[3] if mode == 'jump' else ubot) * scale
            lifts.append(ubot - b[3])
            cell = Image.new('RGBA', (fw, FRAME_H), (0, 0, 0, 0))
            cell.alpha_composite(im, (int(fw / 2 - cx * scale), int(FRAME_H - 4 - bottom)))
            row.append(cell)
        rows.append((anim, row, mode, lifts))

    W = fw * max(len(r) for _, r, _, _ in rows)
    sheet = Image.new('RGBA', (W, FRAME_H * len(rows)), (0, 0, 0, 0))
    for y, (anim, row, mode, lifts) in enumerate(rows):
        for x, cell in enumerate(row):
            sheet.alpha_composite(cell, (x * fw, y * FRAME_H))
        m = {'row': y, 'frames': len(row), 'fps': {'idle': 8, 'loop': 16, 'jump': 14}[mode if mode != 'idle' else 'idle']}
        if mode == 'jump':  # split into takeoff / rising / falling / landing by the height in the video
            L = np.array(lifts, dtype=float)
            top = int(L.argmax())
            air = np.where(L > L.max() * .35)[0]
            m['rise'] = [int(i) for i in air if i <= top]
            m['fall'] = [int(i) for i in air if i > top] or [top]
            m['land'] = [int(i) for i in range(air.max() + 1, min(len(L), air.max() + 4))]
        meta[anim] = m

    # collider measured from the idle pose: torso width, full standing height
    first = rows[0][1][0]
    a = np.asarray(first)[..., 3]
    b = bbox(a)
    mid = a[b[1] + (b[3] - b[1]) // 3: b[1] + (b[3] - b[1]) * 2 // 3] > 80
    cols = np.where(mid.any(axis=0))[0]
    torso_w = int(np.percentile(np.where(mid)[1], 90) - np.percentile(np.where(mid)[1], 10))
    sheet.save(f'{OUT}/{name}.png', optimize=True)
    atlas = {'frameW': fw, 'frameH': FRAME_H, 'anchorX': fw / 2, 'anchorY': FRAME_H - 4,
             'bodyH': int(b[3] - b[1]), 'bodyW': torso_w, 'anims': meta}
    json.dump(atlas, open(f'{OUT}/{name}.json', 'w'), indent=1)
    # preview strip
    prev = Image.new('RGBA', sheet.size, (70, 70, 80, 255))
    prev.alpha_composite(sheet)
    prev.convert('RGB').save(f'{OUT}/{name}_preview.jpg', quality=80)
    print(name, atlas['bodyH'], atlas['bodyW'], sheet.size)


if __name__ == '__main__':
    process('brother', {'idle': ('bro_idle.mp4', 'idle'), 'run': ('bro_run.mp4', 'loop'), 'jump': ('bro_jump.mp4', 'jump')})
    process('mother', {'idle': ('mom_idle.mp4', 'idle'), 'walk': ('mom_walk.mp4', 'loop')})
