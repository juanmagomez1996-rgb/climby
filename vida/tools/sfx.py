#!/usr/bin/env python3
"""Efectos de sonido (los mismos que sintetiza la versión HTML) -> assets/audio/sfx_*.wav"""
import numpy as np, wave, pathlib
SR = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'audio'
rng = np.random.default_rng(3)
def tone(f, d=0.12, typ='triangle', v=0.2, slide=0, delay=0):
    n = int((d + delay) * SR); t = np.arange(int(d * SR)) / SR
    fr = f * (1 + (slide / f) * t / d) if slide else np.full_like(t, f)
    fr = np.maximum(40, fr); ph = 2 * np.pi * np.cumsum(fr) / SR
    w = {'sine': np.sin(ph), 'square': np.sign(np.sin(ph)), 'sawtooth': 2 * ((ph / (2 * np.pi)) % 1) - 1,
         'triangle': 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1}[typ]
    e = np.minimum(1, t / 0.01) * np.exp(-t / (d / 4.5))
    d0 = int(delay * SR); out = np.zeros(d0 + len(t)); out[d0:] = w * e * v; return out
def noise(d=0.15, v=0.2, hp=800):
    n = int(d * SR); x = rng.uniform(-1, 1, n) * (1 - np.arange(n) / n)
    a = np.exp(-2 * np.pi * hp / SR); y = np.zeros(n); prev = 0
    for i in range(1, n): y[i] = a * (y[i - 1] + x[i] - x[i - 1])
    return y * v
def mix(*parts):
    n = max(len(p) for p in parts); o = np.zeros(n)
    for p in parts: o[:len(p)] += p
    return o
def save(name, s):
    s = s / max(1e-9, np.max(np.abs(s))) * 0.85 if np.max(np.abs(s)) > 0.85 else s
    s = np.concatenate([s, np.zeros(int(0.02 * SR))])
    with wave.open(str(OUT / f'sfx_{name}.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((s * 32767).astype(np.int16).tobytes())
S = {
 'jump': tone(420, .16, 'triangle', .5, 380), 'jump2': tone(620, .14, 'triangle', .45, 500), 'land': noise(.06, .25, 1500),
 'hit': mix(noise(.2, .8, 300), tone(160, .25, 'sawtooth', .35, -90)),
 'treat': mix(tone(700, .08, 'square', .2), tone(500, .14, 'square', .18, -100, .07)),
 'card': mix(noise(.18, .35, 2500), tone(330, .12, 'triangle', .3)),
 'choose': mix(tone(660, .08, 'triangle', .45), tone(990, .12, 'triangle', .45, 0, .07)),
 'stage': mix(*[tone(f, .22, 'triangle', .4, 0, i * .09) for i, f in enumerate([523, 659, 784, 1046])]),
 'bad': mix(tone(300, .2, 'triangle', .4, -120), tone(220, .3, 'triangle', .35, -80, .15)),
 'good': mix(*[tone(f, .16, 'triangle', .4, 0, i * .07) for i, f in enumerate([659, 784, 988])]),
 'tick': tone(900, .03, 'square', .1),
 'death': mix(*[tone(f, .5, 'triangle', .4, 0, i * .3) for i, f in enumerate([523, 440, 392, 262])]),
 'bday': mix(*[tone(f, .18, 'square', .15, 0, i * .15) for i, f in enumerate([523, 523, 587, 523, 698, 659])]),
 'moment': mix(tone(990, .06, 'square', .2), tone(1320, .1, 'square', .2, 0, .07)),
 'tap': tone(700, .04, 'square', .15),
}
for i, b in enumerate([523, 587, 659, 784]): S[f'pick{i}'] = mix(tone(b, .1, 'triangle', .45), tone(b * 1.5, .12, 'triangle', .35, 0, .06))
for k, v in S.items(): save(k, v)
print(len(S), 'efectos')
