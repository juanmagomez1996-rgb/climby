#!/usr/bin/env python3
"""Música original de «Una Vida en 20 Minutos», sintetizada con numpy.
Un tema en bucle por etapa (music_0..4) y uno para el epitafio (music_end).
Uso: music.py  -> assets/audio/music_*.mp3"""
import numpy as np, subprocess, pathlib, wave
import imageio_ffmpeg

SR = 44100
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'audio'; OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)
NOTE = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
def hz(m): return 440 * 2 ** ((m - 69) / 12)
def midi(n, o): return 12 * (o + 1) + NOTE[n]

def env(n, a=0.005, d=0.3, s=0.0, r=0.05):
    t = np.arange(n) / SR
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / max(d, 1e-3)))
    rl = int(r * SR)
    if rl and n > rl: e[-rl:] *= np.linspace(1, 0, rl)
    return e

# ---- instrumentos ----
def musicbox(f, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4.01 * t) * np.exp(-t * 9) + 0.15 * np.sin(2 * np.pi * f * 6.2 * t) * np.exp(-t * 14)
    return s * env(n, 0.002, 0.45) * 0.5

def pluck(f, dur, bright=0.5):
    n = int(dur * SR); p = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, p); out = np.zeros(n); k = 0.5 + 0.49 * bright
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = k * buf[i % p] + (1 - k) * buf[(i + 1) % p] if i >= p else buf[i % p]
        if i >= p: buf[i % p] = 0.996 * 0.5 * (out[i] + buf[(i + 1) % p])
    return out * env(n, 0.001, dur, 0, 0.03) * 0.6

def ks(f, dur, damp=0.996):
    """Karplus-Strong rápido con numpy (guitarra/arpa)."""
    n = int(dur * SR); p = max(2, int(round(SR / f)))
    y = np.zeros(n + p); y[:p] = rng.uniform(-1, 1, p)
    y[:p] = np.convolve(y[:p], np.ones(3) / 3, 'same')
    for start in range(p, n + p, p):
        seg = y[start - p:start]
        nxt = damp * 0.5 * (seg + np.roll(seg, -1))
        y[start:start + p] = nxt[:len(y[start:start + p])]
    return y[p:p + n] * env(n, 0.001, dur * 2, 0, 0.02) * 0.55

def epiano(f, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * t) * 1.2 * np.exp(-t * 3)
    s = np.sin(2 * np.pi * f * t + mod) + 0.2 * np.sin(2 * np.pi * 2 * f * t)
    return s * env(n, 0.004, 0.9, 0.0, 0.08) * 0.32

def bass(f, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6)
    return s * env(n, 0.006, 0.35, 0.25, 0.06) * 0.5

def accordion(f, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    s = sum(np.sin(k * ph) / k ** 1.3 for k in range(1, 8)) + 0.6 * sum(np.sin(k * ph * 1.004) / k ** 1.3 for k in range(1, 6))
    return s * env(n, 0.04, 1.0, 0.8, 0.08) * 0.13

def bell(f, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t + 2 * np.sin(2 * np.pi * f * 3.5 * t) * np.exp(-t * 4))
    return s * env(n, 0.002, 1.2) * 0.22

def pad(f, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * f * d * t) for d in (1, 1.003, 0.997, 2.001)) / 4
    a = np.minimum(1, t / 0.4) * np.minimum(1, (dur - t) / 0.4)
    return s * a * 0.12

def shaker(dur):
    n = int(dur * SR); x = rng.uniform(-1, 1, n); x = np.diff(x, prepend=0)
    return x * env(n, 0.003, 0.04) * 0.08

def kick(dur):
    n = int(dur * SR); t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.18) * 0.55

def snap(dur):
    n = int(dur * SR); x = rng.uniform(-1, 1, n)
    return x * env(n, 0.001, 0.05) * 0.18

# ---- acordes ----
CH = {'I': [0, 4, 7], 'ii': [2, 5, 9], 'iii': [4, 7, 11], 'IV': [5, 9, 12], 'V': [7, 11, 14], 'vi': [9, 12, 16], 'V7': [7, 11, 14, 17], 'IVm': [5, 8, 12]}
SCALE = [0, 2, 4, 5, 7, 9, 11]

def melody_line(prog, beats_per_chord, key, seed, octave=5, rhythm=None):
    """Melodía por motivos: repite y varía un motivo de 4 notas sobre los acordes."""
    r = np.random.default_rng(seed)
    motif = r.choice([0, 1, 2, 3, 4], 4)
    notes = []
    for i, c in enumerate(prog):
        chord = CH[c]
        base_deg = SCALE.index(chord[0] % 12) if chord[0] % 12 in SCALE else 0
        mot = motif if i % 4 != 3 else r.choice([0, 1, 2, 3, 4], 4)
        rh = rhythm or [1] * beats_per_chord
        pos = 0
        for j, d in enumerate(rh):
            deg = base_deg + int(mot[j % 4]) - (1 if j % 4 == 3 and i % 2 else 0)
            semis = SCALE[deg % 7] + 12 * (deg // 7)
            if r.random() < 0.12 and j > 0: notes.append((None, d)); continue
            notes.append((midi(key, octave) + semis, d))
            pos += d
    return notes

def render(bpm, prog, key, parts, beats=4, bars_per_chord=1, name='x', seed=1, meter_swing=0.0):
    beat = 60 / bpm
    total_beats = len(prog) * beats * bars_per_chord
    n = int(total_beats * beat * SR) + SR * 3
    mix = np.zeros(n)
    def put(sig, t, gain=1.0):
        i = int(t * SR); e = min(n, i + len(sig)); mix[i:e] += sig[:e - i] * gain
    for p in parts:
        p(put, beat, prog, key, beats * bars_per_chord)
    L = int(total_beats * beat * SR)
    # cola que vuelve al principio para un bucle sin corte
    tail = mix[L:]; mix = mix[:L]; mix[:len(tail)] += tail
    mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.8
    # reverb barata (ecos filtrados)
    rev = np.zeros_like(mix)
    for d, g in ((0.043, .30), (0.071, .24), (0.113, .18), (0.167, .12), (0.241, .08)):
        k = int(d * SR); rev[k:] += mix[:-k] * g
    mix = mix + np.convolve(rev, np.ones(8) / 8, 'same') * 0.6
    mix = np.tanh(mix * 1.1) * 0.85
    st = np.stack([mix, np.roll(mix, int(0.011 * SR))], 1)
    pcm = (st * 32767).astype(np.int16)
    wav = OUT / f'{name}.wav'
    with wave.open(str(wav), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-loglevel', 'error', '-y', '-i', str(wav), '-b:a', '112k', str(OUT / f'{name}.mp3')], check=True)
    wav.unlink(); print(name, round(L / SR, 1), 's')

# ---- partes reutilizables ----
def p_bass(inst=bass, pattern=(0, 2), octave=2, fifth=True):
    def f(put, beat, prog, key, bpc):
        for i, c in enumerate(prog):
            root = midi(key, octave) + CH[c][0]
            for b in range(0, bpc):
                if b % len(pattern) == 0 or b in pattern:
                    pass
            for k, b in enumerate(range(0, bpc, 2 if len(pattern) == 2 else 1)):
                note = root + (7 if (fifth and k % 2) else 0)
                put(inst(hz(note), beat * 1.6), (i * bpc + b) * beat)
    return f

def p_chords(inst, octave=4, every=2, gain=1.0, arp=0.0):
    def f(put, beat, prog, key, bpc):
        for i, c in enumerate(prog):
            for b in range(0, bpc, every):
                for k, s in enumerate(CH[c]):
                    put(inst(hz(midi(key, octave) + s), beat * every * 1.1), (i * bpc + b) * beat + k * arp, gain)
    return f

def p_arp(inst, octave=4, step=0.5, gain=1.0, pat=(0, 1, 2, 1)):
    def f(put, beat, prog, key, bpc):
        for i, c in enumerate(prog):
            ch = CH[c] + [CH[c][0] + 12]
            for k in range(int(bpc / step)):
                s = ch[pat[k % len(pat)]]
                put(inst(hz(midi(key, octave) + s), beat * step * 2), (i * bpc + k * step) * beat, gain)
    return f

def p_melody(inst, seed, octave=5, rhythm=None, gain=1.0, start_chord=0):
    def f(put, beat, prog, key, bpc):
        t = 0
        line = melody_line(prog, bpc, key, seed, octave, rhythm)
        for i, c in enumerate(prog):
            pass
        for m, d in line:
            if m is not None and t / bpc >= start_chord: put(inst(hz(m), beat * d * 1.4), t * beat, gain)
            t += d
    return f

def p_drums(kick_beats=(0, 2), snap_beats=(1, 3), shake=True, gain=1.0):
    def f(put, beat, prog, key, bpc):
        for i in range(len(prog)):
            for b in range(bpc):
                t = (i * bpc + b) * beat
                if b % 4 in kick_beats: put(kick(0.3), t, gain)
                if b % 4 in snap_beats: put(snap(0.1), t, gain)
                if shake: put(shaker(0.1), t + beat / 2, gain); put(shaker(0.1), t, gain * 0.6)
    return f

if __name__ == '__main__':
    P1 = ['I', 'vi', 'IV', 'V', 'I', 'vi', 'ii', 'V', 'IV', 'I', 'ii', 'V', 'I', 'IV', 'V', 'I']
    # 0 Infancia: caja de música saltarina
    render(118, P1, 'C', [p_bass(bass), p_chords(pluck if False else ks, 4, 2, 0.5), p_melody(musicbox, 3, 6, [1, 0.5, 0.5, 1, 1]), p_drums((0,), (2,), True, 0.6)], name='music_0')
    # 1 Adolescencia: guitarra punteada y palmas
    P2 = ['vi', 'IV', 'I', 'V', 'vi', 'IV', 'I', 'V', 'ii', 'IV', 'vi', 'V', 'IV', 'V', 'I', 'I']
    render(126, P2, 'D', [p_bass(bass, (0, 2)), p_arp(ks, 4, 0.5, 0.8, (0, 2, 1, 3, 2, 1)), p_melody(epiano, 11, 5, [1.5, 0.5, 1, 1]), p_drums((0, 2), (1, 3), True, 0.9)], name='music_1')
    # 2 Vida adulta: piano y bajo andante
    P3 = ['I', 'iii', 'vi', 'IV', 'ii', 'V', 'I', 'V7', 'IV', 'I', 'ii', 'V', 'vi', 'IV', 'V', 'I']
    render(112, P3, 'F', [p_bass(bass, (0, 1, 2, 3)), p_chords(epiano, 4, 1, 0.55), p_melody(epiano, 23, 5, [1, 1, 0.5, 0.5, 1]), p_drums((0, 2), (1, 3), True, 0.7)], name='music_2')
    # 3 Madurez: guitarra cálida y campanitas
    P4 = ['I', 'IV', 'I', 'V', 'vi', 'IV', 'ii', 'V', 'I', 'IV', 'vi', 'V', 'IV', 'IVm', 'I', 'I']
    render(96, P4, 'D', [p_bass(bass), p_arp(ks, 3, 0.5, 0.9, (0, 1, 2, 3)), p_melody(bell, 5, 5, [2, 1, 1]), p_drums((0,), (2,), True, 0.4)], name='music_3')
    # 4 Vejez: vals con acordeón
    P5 = ['I', 'I', 'V', 'V', 'V7', 'V7', 'I', 'I', 'IV', 'IV', 'I', 'vi', 'ii', 'V', 'I', 'I']
    def waltz_bass(put, beat, prog, key, bpc):
        for i, c in enumerate(prog):
            put(bass(hz(midi(key, 2) + CH[c][0]), beat * 1.2), (i * bpc) * beat)
            for b in (1, 2):
                for s in CH[c]: put(ks(hz(midi(key, 4) + s), beat * 0.8) * 0.5, (i * bpc + b) * beat)
    render(92, P5, 'G', [waltz_bass, p_melody(accordion, 17, 5, [1.5, 0.5, 1])], beats=3, name='music_4')
    # Epitafio: caja de música lenta
    P6 = ['I', 'vi', 'IV', 'V', 'I', 'IV', 'V', 'I']
    render(64, P6, 'C', [p_chords(pad, 4, 4, 1.0), p_melody(musicbox, 29, 6, [1, 1, 2]), p_bass(bass)], name='music_end')
