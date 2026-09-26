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
  rootclip  a traversal (step up, climb, hang and pull up): each frame on its own lowest point,
            plus the body's extent per frame and hand-marked anchor keys, so the game can move
            the body along the real obstacle (the video's camera follows the boy, so its own
            motion can't be measured from the frame)
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
OUT = sys.argv[1] if len(sys.argv) > 1 else 'sheets_tmp'
os.makedirs(OUT, exist_ok=True)
F = 160          # square frame (px); anchor at bottom centre, with head-room for raised arms
MAXF = 48
FPS = 24
_cache = {}


def frames(video, strict=False):
    if (video, strict) in _cache:
        return _cache[(video, strict)]
    d = f'tmp_{os.path.basename(video)}'
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    subprocess.run([FF, '-loglevel', 'error', '-i', video, '-vf', f'fps={FPS}', f'{d}/%04d.png'], check=True)
    out = [key(np.asarray(Image.open(os.path.join(d, f)).convert('RGB').resize((512, 512), Image.LANCZOS)).astype(np.float32), strict) for f in sorted(os.listdir(d))][2:]
    _cache.clear(); _cache[(video, strict)] = out     # keep only the clip in use (memory)
    return out


def key(rgb, strict=False):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dom = g - np.maximum(r, b)
    a = 1 - np.clip((dom - 20) / (55 - 20), 0, 1) if not strict else 1 - np.clip((dom - 4) / 10, 0, 1)   # strict: green props in shade too
    a[(g > 140) & (g > r + 35) & (g > b + 35)] = 0      # lit green floor / gradient backdrop
    out = rgb.copy(); out[..., 1] = np.minimum(g, np.maximum(r, b) + 6)
    a[a < .06] = 0
    return np.dstack([out, a * 255]).astype(np.uint8)


def only_body(f):
    """Drop what isn't the boy (grey prop edges the key left): keep pixels near his dark clothes."""
    from PIL import ImageFilter
    rgb = f[..., :3].astype(np.float32); lum = rgb.mean(axis=2)
    dark = ((lum < 80) & (f[..., 3] > 100)).astype(np.uint8) * 255
    m = Image.fromarray(dark).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MaxFilter(29))
    out = f.copy(); out[..., 3] = (f[..., 3] * (np.asarray(m) > 0)).astype(np.uint8)
    return out


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


def solid_bbox(alpha, thr=40, minrow=6):
    """bbox ignoring stray specks: rows need a few solid pixels."""
    m = alpha > thr; rows = np.where(m.sum(axis=1) >= minrow)[0]
    if not len(rows): return bbox(alpha, thr)
    y0, y1 = rows.min(), rows.max(); xs = np.where(m[y0:y1 + 1].any(axis=0))[0]
    return (xs.min(), y0, xs.max(), y1)


def body_center(alpha, b):
    band = alpha[b[1] + int((b[3] - b[1]) * .15): b[1] + int((b[3] - b[1]) * .55)] > 60
    xs = np.where(band)[1]
    return xs.mean() if len(xs) else (b[0] + b[2]) / 2


def pick(spec):
    raw = frames(spec['video'], spec.get('clean', False)); kind = spec['kind']
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
    if kind == 'leap':   # keep only the leap itself: the stretch around the highest point, plus take-off and landing
        bots = np.array([(bbox(f[..., 3]) or (0, 0, 0, 0))[3] for f in raw], float)
        lift = np.percentile(bots, 90) - bots; top = int(lift.argmax()); thr = lift.max() * .3
        i0 = top; i1 = top
        while i0 > 0 and lift[i0 - 1] > thr: i0 -= 1
        while i1 < len(raw) - 1 and lift[i1 + 1] > thr: i1 += 1
        return raw[max(0, i0 - 7): min(len(raw), i1 + 9)]
    if kind == 'rootclip':
        r0, r1 = spec['raw']; skip = spec.get('skip', [])
        ridx = [i for i in range(r0, min(r1, len(raw))) if not any(p <= i < q for p, q in skip)]
        spec['_ridx'] = ridx; spec['_h0'] = bbox(raw[0][..., 3])
        return [only_body(raw[i]) if spec.get('clean') else raw[i] for i in ridx]
    seg = raw[a:e]           # clip, hold, jump, leap
    return seg[int(len(seg) * spec.get('from', 0)):]


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
        seq = uncut(pick(spec))
        if '_ridx' in spec and len(seq) > MAXF:
            idx = np.linspace(0, len(seq) - 1, MAXF).round().astype(int); spec['_ridx'] = [spec['_ridx'][i] for i in idx]
        seq, fps = thin(seq)
        data.append((anim, spec, seq, fps))
        print(name, anim, spec['kind'], len(seq), round(fps, 1))
    ref = next(s for a, sp, s, f in data if a == 'idle')
    stand_h = np.median([b[3] - b[1] for b in (bbox(f[..., 3]) for f in ref) if b])
    scale = F * .8 / stand_h

    rows, meta = [], {}
    for anim, spec, seq, fps in data:
        kind = spec['kind']
        if kind == 'rootclip':   # nothing below the feet
            seq = [f.copy() for f in seq]
            for f in seq:
                b = solid_bbox(f[..., 3]); f[b[3] + 2:, :, 3] = 0; f[:, :max(0, b[0] - 30), 3] = 0; f[:, b[2] + 30:, 3] = 0
        boxes = [solid_bbox(f[..., 3]) if kind == 'rootclip' else bbox(f[..., 3]) for f in seq]
        sc = scale
        if 'height' in spec:   # expected silhouette height relative to standing (e.g. arms raised)
            hs = [b[3] - b[1] for b in boxes if b]
            sc = F * .8 * spec['height'] / np.median(hs)
        if kind == 'rootclip':   # same scale as standing, measured on the video's first (standing) frame
            h0 = spec['_h0']; sc = F * .8 / (h0[3] - h0[1])
        ok = [b for b in boxes if b]
        ubot = max(b[3] for b in ok)
        cs = [body_center(f[..., 3], b) if b else 0 for f, b in zip(seq, boxes)]
        if kind in ('leap', 'rootclip'):
            k = 5; cs = np.convolve(np.pad(cs, (k // 2, k // 2), mode='edge'), np.ones(k) / k, mode='valid')
        elif kind in ('clip', 'hold', 'jump', 'start', 'stop'):
            ref_c = cs[-3:] if kind == 'stop' else cs[:3]
            cs = [float(np.mean(ref_c))] * len(cs)            # fixed anchor keeps the body's own motion
        else:
            k = 7; cs = np.convolve(np.pad(cs, (k // 2, k // 2), mode='wrap' if kind == 'cycle' else 'edge'), np.ones(k) / k, mode='valid')
        row, lifts, exts, bys = [], [], [], []
        for f, b, cx in zip(seq, boxes, cs):
            im = Image.fromarray(f); im = im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)
            bottom = ((b[3] if (kind in ('jump', 'leap', 'rootclip') and b) else ubot)) * sc
            if kind == 'rootclip':   # lowest point on the cell's ground line; a body taller than the cell keeps its hands
                ext = (b[3] - b[1]) * sc; by = F - 3 if ext < F - 6 else 3 + ext
                exts.append(round(float(ext), 1)); bys.append(round(float(by), 1))
                cell = Image.new('RGBA', (F, F), (0, 0, 0, 0)); cell.alpha_composite(im, (int(F / 2 - cx * sc), int(by - bottom)))
                row.append(cell); continue
            lifts.append(ubot - (b[3] if b else ubot))
            cell = Image.new('RGBA', (F, F), (0, 0, 0, 0))
            cell.alpha_composite(im, (int(F / 2 - cx * sc), int(F - 3 - bottom)))
            row.append(cell)
        rows.append(row)
        m = {'row': len(rows) - 1, 'frames': len(row), 'kind': kind, 'fps': round(fps, 2)}
        if kind in ('jump', 'leap'):
            L = np.array(lifts, float); top = int(L.argmax()); thr = L.max() * .25
            i0 = top; i1 = top
            while i0 > 0 and L[i0 - 1] > thr: i0 -= 1
            while i1 < len(L) - 1 and L[i1 + 1] > thr: i1 += 1
            air = np.arange(i0, i1 + 1)
            m['crouch'] = [int(i) for i in range(max(0, air.min() - 6), air.min())]
            m['rise'] = [int(i) for i in air if i <= top]
            m['fall'] = [int(i) for i in air if i > top] or [top]
            m['land'] = [int(i) for i in range(air.max() + 1, min(len(L), air.max() + 9))]
        if 'split' in spec:   # phases marked by eye when the clip fools the detection
            for ph, (a0, a1) in spec['split'].items(): m[ph] = list(range(a0, min(a1, len(row))))
        if kind == 'rootclip':
            R = spec['_ridx']; near = lambda r: int(np.argmin([abs(x - r) for x in R]))
            m['ext'] = exts; m['by'] = bys
            m['keys'] = [[near(r), mode] for r, mode in spec['keys']]
            m['fwd'] = [[near(r), v] for r, v in spec['fwd']]
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
    poses = {}
    for (anim, spec, seq, fps), row in zip(data, rows):
        poses[anim] = [''.join('0123456789abcdef'[min(15, int(v / 16))] for v in np.asarray(cell.getchannel('A').resize((16, 16), Image.BOX)).flatten()) for cell in row]
    atlas['poses'] = poses
    json.dump(atlas, open(f'{OUT}/{name}.json', 'w'))
    print(name, sheet.size, atlas['bodyH'])


if __name__ == '__main__':
    ONLY = os.environ.get('ONLY', '')
    if ONLY != 'mother': process('brother', {
        'idle': {'video': 'bro_idle_sad.mp4', 'kind': 'pingpong', 'n': 44},
        'look': {'video': 'bro_look.mp4', 'kind': 'clip'},
        'walk': {'video': 'bro_walk_grief.mp4', 'kind': 'cycle', 'lo': 20, 'hi': 40},
        'walk_start': {'video': 'bro_walk_grief.mp4', 'kind': 'start', 'n': 16},
        'walk_stop': {'video': 'bro_walk_stop.mp4', 'kind': 'stop', 'n': 22},
        'run': {'video': 'bro_run_flee.mp4', 'kind': 'cycle', 'lo': 12, 'hi': 28},
        'run_start': {'video': 'bro_run_flee.mp4', 'kind': 'start', 'n': 12},
        'run_stop': {'video': 'bro_run_stop.mp4', 'kind': 'stop', 'n': 22},
        'jump': {'video': 'bro_jump2.mp4', 'kind': 'jump'},
        'push': {'video': 'bro_push.mp4', 'kind': 'cycle', 'lo': 14, 'hi': 36},
        'pull': {'video': 'bro_pull.mp4', 'kind': 'cycle', 'lo': 14, 'hi': 36},
        'climb': {'video': 'bro_climb.mp4', 'kind': 'clip'},
        # traversals by obstacle height; raw = source frame range (24 fps), keys = where the body rests
        # (g0 start ground, hand = hanging from the ledge, g1 on top), fwd = share of the way across
        'stepup': {'video': 'bro_stepup.mp4', 'kind': 'rootclip', 'clean': True, 'raw': [18, 84], 'keys': [[46, 'g0'], [62, 'g1']], 'fwd': [[44, 0], [66, 1]]},
        'vault': {'video': 'bro_climb2.mp4', 'kind': 'rootclip', 'clean': True, 'raw': [46, 88], 'keys': [[62, 'g0'], [86, 'g1']], 'fwd': [[64, 0], [88, 1]]},
        'hang': {'video': 'bro_hang.mp4', 'kind': 'rootclip', 'clean': True, 'raw': [14, 104], 'skip': [[44, 56]], 'keys': [[18, 'g0'], [32, 'hand'], [62, 'hand'], [86, 'g1']], 'fwd': [[18, 0], [34, .1], [62, .18], [88, 1]]},
        'fall': {'video': 'bro_fall3.mp4', 'kind': 'cycle', 'lo': 12, 'hi': 36, 'height': 1.22},
        'leap': {'video': 'bro_leap.mp4', 'kind': 'leap', 'split': {'crouch': [0, 5], 'rise': [5, 11], 'fall': [11, 15], 'land': [15, 21]}},
        'land': {'video': 'bro_land.mp4', 'kind': 'clip', 'from': .5},
        'collapse': {'video': 'bro_collapse.mp4', 'kind': 'clip'},
        'kneel': {'video': 'bro_kneel.mp4', 'kind': 'hold'},
        'offer': {'video': 'bro_offer.mp4', 'kind': 'hold'},
    })
    if ONLY != 'brother': process('mother', {
        'idle': {'video': 'mom_idle_sad.mp4', 'kind': 'pingpong', 'n': 44},
        'walk': {'video': 'mom_walk.mp4', 'kind': 'cycle', 'lo': 20, 'hi': 44},
        'walk_start': {'video': 'mom_walk.mp4', 'kind': 'start', 'n': 16},
        'walk_stop': {'video': 'mom_walk_stop.mp4', 'kind': 'stop', 'n': 22},
        'receive': {'video': 'mom_receive.mp4', 'kind': 'hold'},
    })
