"""Synthesize the two background loops into assets/bgm/*.wav (no samples).

  python3 art/bgm.py

bgm_game : festival (matsuri-bayashi) feel, 112 BPM, 16 bars —
           shinobue flute melody, shamisen bass, taiko, chanchiki bell
bgm_title: calm, 84 BPM, 8 bars — koto arpeggios and a soft flute

Both use the Japanese "yo" pentatonic (D E G A B) and are rendered as exact
seamless loops: the reverb tail past the loop point is folded back onto the
start. WAV keeps the loop gapless on every platform.
"""
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'bgm'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(3)


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def add(buf, at, sig):
    i = int(at * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[:end - i]


def flute(n, dur, vol=0.32):
    """Shinobue-ish: breathy sine with a delayed vibrato."""
    d = dur + 0.08
    t = np.arange(int(SR * d)) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) / 0.15, 0, 1)
    ph = 2 * np.pi * np.cumsum(hz(n) * vib) / SR
    s = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    breath = rng.standard_normal(len(t)) * 0.05 * np.exp(-t * 18)
    env = np.clip(t / 0.025, 0, 1) * np.clip((d - t) / 0.07, 0, 1)
    return (s + breath) * env * vol


def pluck(n, dur, vol=0.5, bright=0.5, decay=0.996):
    """Karplus-Strong string: shamisen (bright, short) or koto (softer, long)."""
    f = hz(n)
    p = max(2, int(SR / f))
    total = int(SR * dur)
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(total)
    for i in range(total):
        j = i % p
        nxt = buf[(j + 1) % p]
        out[i] = buf[j]
        buf[j] = decay * (bright * buf[j] + (1 - bright) * nxt) if bright < 1 else decay * buf[j]
    env = np.clip((dur - np.arange(total) / SR) / 0.05, 0, 1)
    return out * env * vol


def taiko(vol=0.9):
    t = np.arange(int(SR * 0.45)) / SR
    f = 95 * np.exp(-t * 6) + 55
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    s += rng.standard_normal(len(t)) * np.exp(-t * 60) * 0.25
    return s * vol


def rim(vol=0.35):
    t = np.arange(int(SR * 0.05)) / SR
    s = rng.standard_normal(len(t)) * np.exp(-t * 120)
    s = np.append(s[0], s[1:] - 0.85 * s[:-1])  # high-pass: a dry "ka"
    return s * vol


def kane(vol=0.12):
    """Chanchiki: a tiny bright metal bell."""
    t = np.arange(int(SR * 0.25)) / SR
    s = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((2630, 1), (3970, 0.6), (5410, 0.35)))
    return s * np.exp(-t * 22) * vol


def reverb(x, taps=((0.083, 0.28), (0.131, 0.2), (0.197, 0.14), (0.271, 0.09))):
    y = x.copy()
    for d, g in taps:
        i = int(SR * d)
        y[i:] += x[:-i] * g
    return y


def finish(name, buf, loop_len, vol=0.7):
    buf = reverb(buf)
    n = int(SR * loop_len)
    loop = buf[:n].copy()
    tail = buf[n:]
    loop[:len(tail)] += tail  # fold the tail onto the start → seamless
    loop = loop / (np.abs(loop).max() + 1e-9) * vol
    data = (loop * 32767).astype(np.int16)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f'{loop_len:.1f}s', (OUT / f'{name}.wav').stat().st_size // 1024, 'KB')


def melody(text):
    """'74:2 76:1 r:1 ...' → [(note|None, eighths)]"""
    out = []
    for tok in text.split():
        n, d = tok.split(':')
        out.append((None if n == 'r' else int(n), int(d)))
    return out


# ── game: matsuri ──
BPM = 112
E8 = 60 / BPM / 2  # one eighth note
BARS = 16
L = BARS * 8 * E8
buf = np.zeros(int(SR * (L + 2)))

tune = melody('''
74:2 76:1 79:1 81:2 79:2   76:1 74:1 76:2 71:4
69:2 71:1 74:1 76:2 74:1 71:1   69:6 r:2
74:2 76:1 79:1 81:2 83:2   81:1 79:1 81:2 76:4
79:2 76:1 74:1 71:2 69:1 71:1   74:6 r:2
86:1 83:1 81:2 83:1 81:1 79:2   81:1 79:1 76:2 79:4
76:1 79:1 81:1 83:1 86:2 83:2   81:6 r:2
79:2 81:1 79:1 76:2 74:2   71:1 74:1 76:2 74:4
69:2 71:1 74:1 76:1 74:1 71:1 69:1   74:6 r:2
''')
pos = 0
for n, d in tune:
    if n is not None:
        add(buf, pos * E8, flute(n, d * E8 * 0.95))
    pos += d
assert pos == BARS * 8, pos

roots = [50, 50, 55, 57, 50, 50, 55, 50, 55, 55, 57, 57, 55, 50, 57, 50]  # D G A in octave 3
for b, r in enumerate(roots):
    for q, iv in enumerate((0, 7, 12, 7)):  # root, fifth, octave, fifth
        add(buf, (b * 8 + q * 2) * E8, pluck(r + iv - 12, E8 * 1.8, 0.42, 0.5, 0.993))

for b in range(BARS):
    fill = b % 4 == 3
    pat = 'DDkDDkDD' if fill else 'D.kkD.k.'
    for e, c in enumerate(pat):
        at = (b * 8 + e) * E8
        if c == 'D':
            add(buf, at, taiko(0.8 if e else 1.0))
        elif c == 'k':
            add(buf, at, rim())
    for e in (1, 3, 5, 7):  # chan-chiki on the off-beats
        add(buf, (b * 8 + e) * E8, kane())

finish('bgm_game', buf, L)

# ── title: calm koto ──
BPM = 84
E8 = 60 / BPM / 2
BARS = 8
L = BARS * 8 * E8
buf = np.zeros(int(SR * (L + 3)))
chords = [  # yo-scale arpeggios, 8 eighths per bar
    [62, 69, 74, 76, 79, 76, 74, 69],
    [55, 62, 67, 71, 74, 71, 67, 62],
    [57, 64, 69, 71, 76, 71, 69, 64],
    [62, 69, 74, 79, 81, 79, 74, 69],
    [59, 66, 71, 74, 78, 74, 71, 66],
    [55, 62, 67, 71, 74, 71, 67, 62],
    [57, 64, 69, 74, 76, 74, 69, 64],
    [62, 69, 74, 76, 81, 76, 74, 69],
]
for b, ns in enumerate(chords):
    for e, n in enumerate(ns):
        add(buf, (b * 8 + e) * E8, pluck(n, 1.6, 0.30, 0.65, 0.9985))
calm = melody('''
r:4 81:4   79:6 76:2   76:4 74:4   r:8
r:4 86:2 83:2   81:6 79:2   76:4 79:2 76:2   74:8
''')
pos = 0
for n, d in calm:
    if n is not None:
        add(buf, pos * E8, flute(n, d * E8 * 0.97, 0.22))
    pos += d
assert pos == BARS * 8, pos
finish('bgm_title', buf, L, 0.6)
