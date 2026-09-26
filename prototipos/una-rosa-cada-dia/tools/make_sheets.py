"""Green-screen animation videos -> one sprite sheet + JSON atlas per character.

Every clip keeps its real 24 fps timing (up to MAXF frames; longer clips are thinned and
the atlas stores the matching playback fps).

Kinds
  cycle     seamless loop picked where the motion is established (walk, run, push...)
  pingpong  a calm stretch played forth and back, so it never restarts (idle breathing)
  clip      a one-shot action, still start and still end trimmed (look back, climb, collapse)
  hold      a clip whose last part plays forth and back afterwards (kneel and cry, receive)
  start     the first steps out of standing still (from a walk/run video)
  stop      the last steps into standing still
  jump      a whole jump, each frame on its own feet, split into crouch / rise / fall / land
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
F = 160          # square frame (px); anchor at bottom centre, with head-room for raised arms
MAXF = 48
FPS = 24
_cache = {}


def frames(video):
    if video in _cache:
        return _cache[video]
    d = f'tmp_{os.path.basename(video)}'
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    subprocess.run([FF, '-loglevel', 'error', '-i', video, '-vf', f'fps={FPS}', f'{d}/%04d.png'], check=True)
    out = [key(np.asarray(Image.open(os.path.join(d, f)).convert('RGB').resize((512, 512), Image.LANCZOS)).astype(np.float32)) for f in sorted(os.listdir(d))][2:]
    _cache.clear(); _cache[video] = out     # keep only the clip in use (memory)
    return out


def key(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dom = g - np.maximum(r, b)
    a = 1 - np.clip((dom - 20) / (55 - 20), 0, 1)
    a[(g > 140) & (g > r + 35) & (g > b + 35)] = 0      # lit green floor / gradient backdrop
    out = rgb.copy(); out[..., 1] = np.minimum(g, np.maximum(r, b) + 6)
    a[a < .06] = 0
    return np.dstack([out, a * 255]).astype(np.uint8)


def small(f):
    return np.asarray(Image.fromarray(f).resize((48, 48))).astype(np.float32)


def motion_span(raw, thr=5.5):
    s = [small(f) for f in raw]
    start = next((i for i in range(len(s)) if np.abs(s[i] - s[0]).mean() > thr), 0)
    end = next((i for i in range(len(s) - 1, -1, -1) if np.abs(s[i] - s[-1]).mean() > thr), len(s) - 1)
    return max(0, start - 1), min(len(s), end + 3)


def best_loop(seq, lo, hi, first=0):
    s = [small(f) for f in seq]
    best = (1e18, first, first + lo)
    for i in range(first, max(first + 1, len(s) - hi)):
        for j in range(i + lo, min(len(s), i + hi + 1)):
            d = np.abs(s[i] - s[j]).mean() + .15 * np.abs(s[i + 1] - s[j]).mean() if j < len(s) else 1e9
            if d < best[0]:
                best = (d, i, j)
    return best[1], best[2]


def bbox(alpha, thr=40):
    ys, xs = np.where(alpha > thr)
    return (xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else None


def body_center(alpha, b):
    band = alpha[b[1] + int((b[3] - b[1]) * .15): b[1] + int((b[3] - b[1]) * .55)] > 60
    xs = np.where(band)[1]
    return xs.mean() if len(xs) else (b[0] + b[2]) / 2


def pick(spec):
    raw = frames(spec['video']); kind = spec['kind']
    a, e = motion_span(raw)
    if kind == 'cycle':
        first = int(len(raw) * spec.get('from', .45))
        i, j = best_loop(raw, spec['lo'], spec['hi'], first)
        return raw[i:j]
    if kind == 'pingpong':
        n = spec.get('n', 40); s0 = min(max(a, int(len(raw) * .2)), len(raw) - n)
        return raw[s0:s0 + n]
    if kind == 'start':
        return raw[a:a + spec.get('n', 14)]
    if kind == 'stop':
        return raw[max(0, e - spec.get('n', 22)):e]
    return raw[a:e]           # clip, hold, jump


def uncut(seq):
    """Replace frames where the video cropped the figure (touches the top/side edge) with the nearest clean one."""
    bad = []
    for f in seq:
        a = f[..., 3] > 60
        bad.append(a[:3].any() or a[:, :3].any() or a[:, -3:].any())
    if not any(bad) or all(bad):
        return seq
    good = [i for i, b in enumerate(bad) if not b]
    return [seq[i] if not bad[i] else seq[min(good, key=lambda g: abs(g - i))] for i in range(len(seq))]


def ground_speed(row, fps):
    """Treadmill speed of a gait cycle in sheet px per second: a cycle is two steps,
    and a step is how far the feet spread apart (widest leg span minus narrowest)."""
    ws = []
    for cell in row:
        a = np.asarray(cell)[..., 3] > 80
        ys = np.where(a.any(axis=1))[0]
        if not len(ys):
            continue
        band = a[ys.max() - int((ys.max() - ys.min()) * .12): ys.max() + 1]
        xs = np.where(band.any(axis=0))[0]; ws.append(xs.max() - xs.min())
    return 2 * (max(ws) - min(ws)) / (len(row) / fps) if ws else 0.0


def thin(seq):
    if len(seq) <= MAXF:
        return seq, FPS
    idx = np.linspace(0, len(seq) - 1, MAXF).round().astype(int)
    return [seq[i] for i in idx], FPS * MAXF / len(seq)


def process(name, specs):
    data = []
    for anim, spec in specs.items():
        seq, fps = thin(uncut(pick(spec)))
        data.append((anim, spec, seq, fps))
        print(name, anim, spec['kind'], len(seq), round(fps, 1))
    ref = next(s for a, sp, s, f in data if a == 'idle')
    stand_h = np.median([b[3] - b[1] for b in (bbox(f[..., 3]) for f in ref) if b])
    scale = F * .8 / stand_h

    rows, meta = [], {}
    for anim, spec, seq, fps in data:
        kind = spec['kind']
        boxes = [bbox(f[..., 3]) for f in seq]
        ok = [b for b in boxes if b]
        ubot = max(b[3] for b in ok)
        cs = [body_center(f[..., 3], b) if b else 0 for f, b in zip(seq, boxes)]
        if kind in ('clip', 'hold', 'jump', 'start', 'stop'):
            ref_c = cs[-3:] if kind == 'stop' else cs[:3]
            cs = [float(np.mean(ref_c))] * len(cs)            # fixed anchor keeps the body's own motion
        else:
            k = 7; cs = np.convolve(np.pad(cs, (k // 2, k // 2), mode='wrap' if kind == 'cycle' else 'edge'), np.ones(k) / k, mode='valid')
        row, lifts = [], []
        for f, b, cx in zip(seq, boxes, cs):
            im = Image.fromarray(f); im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
            bottom = ((b[3] if (kind == 'jump' and b) else ubot)) * scale
            lifts.append(ubot - (b[3] if b else ubot))
            cell = Image.new('RGBA', (F, F), (0, 0, 0, 0))
            cell.alpha_composite(im, (int(F / 2 - cx * scale), int(F - 3 - bottom)))
            row.append(cell)
        rows.append(row)
        m = {'row': len(rows) - 1, 'frames': len(row), 'kind': kind, 'fps': round(fps, 2)}
        if kind == 'jump':
            L = np.array(lifts, float); top = int(L.argmax()); air = np.where(L > L.max() * .12)[0]
            m['crouch'] = [int(i) for i in range(max(0, air.min() - 6), air.min())]
            m['rise'] = [int(i) for i in air if i <= top]
            m['fall'] = [int(i) for i in air if i > top] or [top]
            m['land'] = [int(i) for i in range(air.max() + 1, min(len(L), air.max() + 9))]
        if kind == 'hold':
            m['loopFrom'] = int(len(row) * .62)
        if kind == 'cycle':
            m['ground'] = round(ground_speed(row, fps), 2)
        meta[anim] = m

    cols = max(len(r) for r in rows)
    sheet = Image.new('RGBA', (cols * F, len(rows) * F), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            sheet.alpha_composite(cell, (x * F, y * F))
    a = np.asarray(rows[0][0])[..., 3]; b = bbox(a)
    sheet.save(f'{OUT}/{name}.png', optimize=True)
    atlas = {'frameW': F, 'frameH': F, 'anchorX': F / 2, 'anchorY': F - 3, 'bodyH': int(b[3] - b[1]), 'anims': meta}
    json.dump(atlas, open(f'{OUT}/{name}.json', 'w'), indent=1)
    print(name, sheet.size, atlas['bodyH'])


if __name__ == '__main__':
    process('brother', {
        'idle': {'video': 'bro_idle_sad.mp4', 'kind': 'pingpong', 'n': 44},
        'look': {'video': 'bro_look.mp4', 'kind': 'clip'},
        'walk': {'video': 'bro_walk_grief.mp4', 'kind': 'cycle', 'lo': 20, 'hi': 40},
        'walk_start': {'video': 'bro_walk_grief.mp4', 'kind': 'start', 'n': 16},
        'walk_stop': {'video': 'bro_walk_stop.mp4', 'kind': 'stop', 'n': 22},
        'run': {'video': 'bro_run_flee.mp4', 'kind': 'cycle', 'lo': 12, 'hi': 28},
        'run_start': {'video': 'bro_run_flee.mp4', 'kind': 'start', 'n': 12},
        'run_stop': {'video': 'bro_run_stop.mp4', 'kind': 'stop', 'n': 22},
        'turn': {'video': 'bro_turn.mp4', 'kind': 'clip'},
        'jump': {'video': 'bro_jump2.mp4', 'kind': 'jump'},
        'push': {'video': 'bro_push.mp4', 'kind': 'cycle', 'lo': 14, 'hi': 36},
        'pull': {'video': 'bro_pull.mp4', 'kind': 'cycle', 'lo': 14, 'hi': 36},
        'climb': {'video': 'bro_climb.mp4', 'kind': 'clip'},
        'fall': {'video': 'bro_fall.mp4', 'kind': 'cycle', 'lo': 10, 'hi': 30},
        'collapse': {'video': 'bro_collapse.mp4', 'kind': 'clip'},
        'kneel': {'video': 'bro_kneel.mp4', 'kind': 'hold'},
        'offer': {'video': 'bro_offer.mp4', 'kind': 'hold'},
    })
    process('mother', {
        'idle': {'video': 'mom_idle_sad.mp4', 'kind': 'pingpong', 'n': 44},
        'walk': {'video': 'mom_walk.mp4', 'kind': 'cycle', 'lo': 20, 'hi': 44},
        'walk_start': {'video': 'mom_walk.mp4', 'kind': 'start', 'n': 16},
        'walk_stop': {'video': 'mom_walk_stop.mp4', 'kind': 'stop', 'n': 22},
        'receive': {'video': 'mom_receive.mp4', 'kind': 'hold'},
    })
