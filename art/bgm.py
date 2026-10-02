"""Synthesize the background loops into assets/bgm/*.wav (no samples).

  python3 art/bgm.py

bgm_title    : calm, 84 BPM — koto arpeggios and a soft flute
bgm_select   : choosing a machine, 104 BPM — bouncy marimba, koto bass, shaker
bgm_ennichi  : 縁日ガチャ, matsuri-bayashi, 112 BPM — shinobue, shamisen, taiko, chanchiki
bgm_mizu     : 水まつりガチャ, 92 BPM — flowing koto, water drops, wind chime, soft flute
bgm_kuishinbo: 食いしん坊ガチャ, 128 BPM — chindon-ya: oom-pah tuba, clarinet, sizzling hats
bgm_engi     : 縁起ガチャ, 80 BPM — shrine gagaku: sho drone, hichiriki, tsuzumi, suzu bells
bgm_ayashii  : 妖しいガチャ, 70 BPM — "in" scale, low drone, bending flute, hyoshigi, temple bell
bgm_kinpika  : 金ぴかガチャ, 138 BPM — brassy lead, glockenspiel sparkle, driving taiko

They use Japanese pentatonics (yo: D E G A B; in: D Eb G A Bb) and are rendered
as exact seamless loops: the reverb tail past the loop point is folded back onto
the start. WAV keeps the loop gapless on every platform.
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

finish('bgm_ennichi', buf, L)

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


# ════ more instruments ════
def tone(f, dur, harm=((1, 1),), att=0.01, rel=0.08, vib=0.0, vib_hz=5.5, bend=0.0):
    """A note from a list of (harmonic, amplitude). [bend] glides in from that many semitones."""
    t = np.arange(int(SR * dur)) / SR
    glide = 2 ** (bend * np.exp(-t * 14) / 12) if bend else 1
    fr = f * glide * (1 + vib * np.sin(2 * np.pi * vib_hz * t) * np.clip((t - 0.1) / 0.2, 0, 1))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    s = sum(a * np.sin(k * ph) for k, a in harm)
    env = np.clip(t / att, 0, 1) * np.clip((dur - t) / rel, 0, 1)
    return s * env


def marimba(n, vol=0.35):
    t = np.arange(int(SR * 0.6)) / SR
    f = hz(n)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 7) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 30)
    return s * np.clip(t / 0.003, 0, 1) * vol


def glock(n, vol=0.18):
    t = np.arange(int(SR * 0.9)) / SR
    f = hz(n)
    s = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
    return s * np.exp(-t * 4.5) * np.clip(t / 0.002, 0, 1) * vol


def furin(vol=0.10):
    """Wind chime: a glassy, slightly inharmonic ring."""
    t = np.arange(int(SR * 2.2)) / SR
    s = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((2093, 1), (3215, 0.5), (4410, 0.3), (5980, 0.15)))
    return s * np.exp(-t * 2.2) * vol


def drop(n, vol=0.22):
    """A water drop: a short upward pitch blip."""
    t = np.arange(int(SR * 0.16)) / SR
    f = hz(n) * (1 + 1.2 * t / 0.16)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 28) * vol


def tuba(n, dur, vol=0.5):
    return tone(hz(n), dur, ((1, 1), (2, 0.45), (3, 0.15)), att=0.012, rel=0.05) * vol


def clarinet(n, dur, vol=0.22, bend=0.0):
    return tone(hz(n), dur, ((1, 1), (3, 0.45), (5, 0.25), (7, 0.12)), att=0.02, rel=0.05, vib=0.004, bend=bend) * vol


def brass(n, dur, vol=0.2):
    return tone(hz(n), dur, tuple((k, 1 / k) for k in range(1, 9)), att=0.025, rel=0.06, vib=0.003) * vol


def hichiriki(n, dur, vol=0.2, bend=-1.5):
    """Nasal double reed that slides up into each note."""
    return tone(hz(n), dur, ((1, 1), (2, 0.7), (3, 0.6), (4, 0.35), (5, 0.25)), att=0.05, rel=0.1, vib=0.008, vib_hz=4.5, bend=bend) * vol


def sho(ns, dur, vol=0.07):
    """Mouth-organ cluster: slow swell, holds, fades."""
    t = np.arange(int(SR * dur)) / SR
    s = sum(np.sin(2 * np.pi * hz(n) * (1 + 0.0015 * k) * t) + 0.3 * np.sin(4 * np.pi * hz(n) * t) for k, n in enumerate(ns))
    env = np.clip(t / 0.8, 0, 1) * np.clip((dur - t) / 0.6, 0, 1)
    return s * env * vol


def drone(n, dur, vol=0.18):
    t = np.arange(int(SR * dur)) / SR
    s = np.sin(2 * np.pi * hz(n) * t) + 0.6 * np.sin(2 * np.pi * hz(n) * 1.004 * t) + 0.2 * np.sin(2 * np.pi * hz(n + 12) * t)
    env = np.clip(t / 1.5, 0, 1) * np.clip((dur - t) / 1.5, 0, 1)
    return s * env * vol


def eerie(n, dur, vol=0.2):
    """A flute that sags and wavers."""
    t = np.arange(int(SR * dur)) / SR
    fr = hz(n) * (1 + 0.012 * np.sin(2 * np.pi * 3.2 * t)) * (1 - 0.02 * np.clip((t - dur * 0.6) / (dur * 0.4), 0, 1))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    s = np.sin(ph) + 0.12 * np.sin(2 * ph) + rng.standard_normal(len(t)) * 0.04
    env = np.clip(t / 0.15, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    return s * env * vol


def temple(vol=0.25):
    """Distant temple bell (bonsho)."""
    t = np.arange(int(SR * 4.0)) / SR
    s = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((98, 1), (196.7, 0.6), (267, 0.45), (393, 0.25), (530, 0.15)))
    s *= 1 + 0.25 * np.sin(2 * np.pi * 1.3 * t)  # the slow beating "wow"
    return s * np.exp(-t * 0.9) * np.clip(t / 0.01, 0, 1) * vol


def hyoshigi(vol=0.5):
    """Two wooden clappers: a hard, high clack."""
    t = np.arange(int(SR * 0.12)) / SR
    s = (np.sin(2 * np.pi * 1850 * t) + 0.5 * np.sin(2 * np.pi * 2790 * t)) * np.exp(-t * 55)
    return (s + rng.standard_normal(len(t)) * np.exp(-t * 200) * 0.4) * vol


def tsuzumi(vol=0.45):
    """Kotsuzumi "pon": a hand drum whose pitch drops."""
    t = np.arange(int(SR * 0.35)) / SR
    f = 420 * np.exp(-t * 9) + 260
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11) * vol


def suzu(vol=0.08):
    """A shake of shrine bells."""
    out = np.zeros(int(SR * 0.6))
    for k in range(7):
        b = kane(1)[: int(SR * 0.2)]
        i = int(SR * (k * 0.045 + rng.uniform(0, 0.015)))
        out[i:i + len(b)] += b * (1 - k / 9)
    return out * vol


def shaker(vol=0.08):
    t = np.arange(int(SR * 0.07)) / SR
    s = rng.standard_normal(len(t))
    s = np.append(s[0], s[1:] - 0.95 * s[:-1])
    return s * np.clip(t / 0.01, 0, 1) * np.exp(-t * 60) * vol


def sizzle(vol=0.07):
    t = np.arange(int(SR * 0.09)) / SR
    s = rng.standard_normal(len(t))
    s = np.append(s[0], s[1:] - 0.97 * s[:-1])
    return s * np.exp(-t * 45) * vol


def wood(vol=0.3):
    t = np.arange(int(SR * 0.08)) / SR
    return np.sin(2 * np.pi * 1200 * t) * np.exp(-t * 70) * vol


def play_line(buf, text, e8, inst):
    pos = 0
    for n, d in melody(text):
        if n is not None:
            add(buf, pos * e8, inst(n, d * e8))
        pos += d
    return pos


def loop_buf(bpm, bars, tail=3):
    e8 = 60 / bpm / 2
    length = bars * 8 * e8
    return e8, length, np.zeros(int(SR * (length + tail)))


# ── select: picking a machine ──
E8, L, buf = loop_buf(104, 8)
n = play_line(buf, '''
74:1 r:1 76:1 79:1 r:1 76:1 74:2   71:1 r:1 74:1 76:2 r:2 r:1
79:1 r:1 81:1 83:1 r:1 81:1 79:2   76:2 74:2 76:4
74:1 r:1 76:1 79:1 r:1 81:1 83:2   86:1 r:1 83:1 81:2 r:3
79:1 81:1 79:1 76:1 74:1 76:1 71:2   74:6 r:2
''', E8, lambda n, d: marimba(n, 0.34) + marimba(n + 12, 0.06))
assert n == 64, n
for b, r in enumerate([50, 55, 57, 50, 50, 55, 57, 50]):
    for q, iv in enumerate((0, 7, 12, 7)):
        add(buf, (b * 8 + q * 2) * E8, pluck(r + iv - 12, E8 * 1.6, 0.30, 0.55, 0.994))
    for e in range(8):
        add(buf, (b * 8 + e) * E8, shaker(0.07 if e % 2 else 0.1))
    add(buf, (b * 8 + 3) * E8, wood(0.18))
    add(buf, (b * 8 + 7) * E8, wood(0.14))
finish('bgm_select', buf, L, 0.6)

# ── 水まつり: water and wind chimes ──
E8, L, buf = loop_buf(92, 16, 5)
arp = [[62, 69, 74, 76], [59, 66, 71, 74], [55, 62, 67, 71], [57, 64, 69, 76]]
for b in range(16):
    ch = arp[(b // 2) % 4]
    for e in range(8):
        add(buf, (b * 8 + e) * E8, pluck(ch[(e if e < 4 else 7 - e)] , 1.4, 0.2, 0.7, 0.9985))
n = play_line(buf, '''
r:8   81:4 79:2 76:2   74:6 76:2   r:8
r:8   83:4 81:2 79:2   81:6 76:2   r:8
r:4 86:4   83:4 81:4   79:4 81:2 79:2   76:8
r:4 79:4   81:2 79:2 76:4   74:8   r:8
''', E8, lambda n, d: flute(n, d * 0.97, 0.18))
assert n == 128, n
drops = [74, 79, 81, 83, 86, 88, 91]
for b in range(16):
    for k in range(2):
        add(buf, (b * 8 + rng.choice([1, 3, 5, 6, 7]) + rng.uniform(0, 0.4)) * E8, drop(rng.choice(drops), 0.2))
    if b % 2 == 0:
        add(buf, (b * 8 + 4.5) * E8, furin(0.09))
    add(buf, b * 8 * E8, taiko(0.35))
finish('bgm_mizu', reverb(buf, ((0.11, 0.3), (0.23, 0.2), (0.37, 0.12))), L, 0.6)

# ── 食いしん坊: chindon-ya street band ──
E8, L, buf = loop_buf(128, 16)
n = play_line(buf, '''
74:1 74:1 76:1 79:1 81:2 79:2   76:1 74:1 76:1 79:1 74:4
71:1 71:1 74:1 76:1 79:2 76:2   74:1 71:1 69:2 r:4
74:1 74:1 76:1 79:1 81:2 83:2   86:1 83:1 81:1 79:1 81:4
79:1 81:1 79:1 76:1 74:2 71:2   74:6 r:2
83:1 r:1 83:1 81:1 79:2 81:2   83:1 86:1 83:1 81:1 79:4
76:1 r:1 76:1 79:1 81:2 79:2   76:1 74:1 76:1 79:1 76:4
83:1 r:1 83:1 81:1 79:2 81:2   83:1 86:1 88:1 86:1 83:4
81:1 79:1 76:1 79:1 74:2 76:1 74:1   74:6 r:2
''', E8, lambda n, d: clarinet(n, d * 0.8, 0.24))
assert n == 128, n
for b, r in enumerate([50, 50, 55, 57, 50, 50, 55, 50, 55, 55, 50, 50, 55, 55, 57, 50]):
    for e, iv in ((0, 0), (4, 7)):
        add(buf, (b * 8 + e) * E8, tuba(r - 12 + iv, E8 * 1.5, 0.5))
    for e in (2, 6):  # the "pah"
        add(buf, (b * 8 + e) * E8, pluck(r + 12, E8 * 0.9, 0.22, 0.4, 0.99) + pluck(r + 16 if r == 50 else r + 14, E8 * 0.9, 0.15, 0.4, 0.99))
    for e in range(8):
        add(buf, (b * 8 + e) * E8, sizzle(0.08 if e % 2 else 0.05))
    add(buf, (b * 8 + 0) * E8, taiko(0.6))
    add(buf, (b * 8 + 4) * E8, rim(0.3))
    for e in (1, 5):
        add(buf, (b * 8 + e) * E8, kane(0.1))
finish('bgm_kuishinbo', buf, L)

# ── 縁起: the shrine on a festival morning ──
E8, L, buf = loop_buf(80, 16, 4)
for b in range(0, 16, 2):
    ch = [[62, 69, 76, 81], [67, 74, 79, 83], [69, 76, 81, 86], [62, 69, 74, 79]][(b // 2) % 4]
    add(buf, b * 8 * E8, sho(ch, 16 * E8 + 0.6))
n = play_line(buf, '''
74:4 76:4   79:6 76:2   74:4 71:4   74:8
76:4 79:4   81:6 79:2   76:4 74:2 76:2   71:8
79:4 81:4   83:6 81:2   79:4 76:4   81:8
79:4 76:2 74:2   71:4 74:4   76:6 74:2   74:8
''', E8, lambda n, d: hichiriki(n - 12, d * 0.96, 0.19))
assert n == 128, n
for b in range(16):
    add(buf, (b * 8 + 0) * E8, tsuzumi(0.4))
    add(buf, (b * 8 + 3) * E8, rim(0.22))
    if b % 2:
        add(buf, (b * 8 + 5) * E8, tsuzumi(0.3))
    if b % 4 == 3:
        add(buf, (b * 8 + 6) * E8, suzu(0.12))
finish('bgm_engi', buf, L, 0.62)

# ── 妖しい: something in the woods behind the stalls ──
E8, L, buf = loop_buf(70, 16, 5)
for b in range(0, 16, 4):
    add(buf, b * 8 * E8, drone(38, 32 * E8 + 1.5, 0.2))
    add(buf, (b * 8 + 1) * E8, temple(0.22))
n = play_line(buf, '''
r:8   74:6 75:2   74:4 70:4   69:8
r:8   69:4 70:4   74:6 70:2   69:8
r:4 79:4   75:6 74:2   70:4 69:4   67:8
r:4 70:2 69:2   67:4 63:4   62:8   r:8
''', E8, lambda n, d: eerie(n, d * 0.98, 0.2))
assert n == 128, n
for b in range(16):
    if b % 2 == 1:
        add(buf, (b * 8 + 6) * E8, hyoshigi(0.35))
        add(buf, (b * 8 + 6.5) * E8, hyoshigi(0.25))
    for e in (0, 3, 5):
        add(buf, (b * 8 + e) * E8, pluck([50, 51, 55, 57, 58][(b + e) % 5] - 12, 1.0, 0.18, 0.45, 0.993))
finish('bgm_ayashii', reverb(buf, ((0.15, 0.32), (0.29, 0.22), (0.43, 0.14), (0.61, 0.08))), L, 0.62)

# ── 金ぴか: everything is gold ──
E8, L, buf = loop_buf(138, 16)
n = play_line(buf, '''
74:2 79:1 81:1 83:2 86:2   83:1 81:1 79:1 81:1 83:4
81:2 79:1 76:1 74:2 76:2   79:6 r:2
74:2 79:1 81:1 83:2 86:2   88:1 86:1 83:1 86:1 88:4
86:2 83:1 81:1 79:2 81:2   79:6 r:2
91:2 88:1 86:1 88:2 86:2   83:1 81:1 83:2 86:4
88:2 86:1 83:1 81:2 83:2   86:6 r:2
91:2 88:1 86:1 88:2 91:2   93:1 91:1 88:1 86:1 88:4
86:2 83:1 81:1 79:2 81:1 83:1   79:6 r:2
''', E8, lambda n, d: brass(n - 12, d * 0.92, 0.2))
assert n == 128, n
roots = [55, 55, 52, 50, 55, 55, 57, 55, 55, 52, 57, 57, 55, 52, 50, 55]
for b, r in enumerate(roots):
    for e in range(8):
        add(buf, (b * 8 + e) * E8, glock([r + 24, r + 28, r + 31, r + 36][e % 4] if r != 50 else [74, 78, 81, 86][e % 4], 0.08))
    for q, iv in enumerate((0, 12, 7, 12)):
        add(buf, (b * 8 + q * 2) * E8, pluck(r - 12 + iv, E8 * 1.8, 0.38, 0.55, 0.993))
    for e, c in enumerate('DkDkDkDD' if b % 4 == 3 else 'D.k.Dkk.'):
        if c == 'D':
            add(buf, (b * 8 + e) * E8, taiko(0.75))
        elif c == 'k':
            add(buf, (b * 8 + e) * E8, rim(0.3))
    for e in range(8):
        add(buf, (b * 8 + e) * E8, kane(0.07 if e % 2 else 0.04))
finish('bgm_kinpika', buf, L)
