"""Synthesize every sound effect into assets/sfx/*.wav (license-free, no samples).

  python3 art/sfx.py              # game sounds -> assets/sfx/
  python3 art/sfx.py candidates   # also gacha candidates -> art/sfx_candidates/ (+ index.html to audition)

Physically-flavoured synthesis: modal resonators for plastic capsules, the
ratchet and the tray, inharmonic metal partials for koban coins and bells,
membrane modes for the taiko, Karplus-Strong for koto plucks, formant
"vowels" for the tanuki's babble, and a small synthetic room reverb.

Which gacha candidate the game uses is set by HANDLE / DROP below.
"""
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 32000
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'sfx'
CAND = ROOT / 'art' / 'sfx_candidates'
OUT.mkdir(parents=True, exist_ok=True)

# the gacha sounds the game uses (see `python3 art/sfx.py candidates`)
HANDLE = 'H'
DROP = 'C'

rng = np.random.default_rng(7)


# ── primitives ──
def t(d):
    return np.arange(int(SR * d)) / SR


def note(n):  # MIDI number -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def mix(parts, d=None):
    """Mix [(start_sec, signal), ...] into one buffer."""
    end = max(int(s * SR) + len(x) for s, x in parts)
    if d is not None:
        end = max(end, int(d * SR))
    out = np.zeros(end)
    for s, x in parts:
        i = int(s * SR)
        out[i:i + len(x)] += x
    return out


def pad(x, d):
    n = int(d * SR)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])


def sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def bp(x, lo, hi, order=2):
    return signal.sosfilt(sos('bandpass', [lo, min(hi, SR / 2 - 100)], order), x)


def lp(x, f, order=2):
    return signal.sosfilt(sos('lowpass', min(f, SR / 2 - 100), order), x)


def hp(x, f, order=2):
    return signal.sosfilt(sos('highpass', f, order), x)


def noise(d):
    return rng.standard_normal(int(SR * d))


def adsr(n, a=0.005, d=0.1, s=0.6, r=0.1, hold=0.0):
    x = np.arange(n) / SR
    e = np.interp(x, [0, a, a + d, a + d + hold, a + d + hold + r], [0, 1, s, s, 0], right=0)
    return e


def expenv(n, rate, a=0.0005):
    x = np.arange(n) / SR
    return np.minimum(x / a, 1) * np.exp(-x * rate)


def modes(freqs, rates, amps, d, a=0.0004):
    """Damped sinusoid bank: the ringing of a struck object."""
    x = t(d)
    y = np.zeros_like(x)
    for f, r, g in zip(freqs, rates, amps):
        if f >= SR / 2:
            continue
        y += g * np.sin(2 * np.pi * f * x + rng.uniform(0, 6.28)) * np.exp(-x * r)
    return y * np.minimum(x / a, 1)


def osc(f0, d, f1=None, curve=1.0, shape='sine'):
    x = t(d)
    f = f0 if f1 is None else f0 + (f1 - f0) * (x / d) ** curve
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(f, x.shape)) / SR
    if shape == 'sine':
        return np.sin(ph)
    if shape == 'tri':
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == 'square':
        return np.tanh(np.sin(ph) * 3)
    raise ValueError(shape)


def reverb(x, size=0.6, wet=0.25, bright=6000, pre=0.012):
    """Small synthetic room: decaying filtered noise IR plus a few early taps."""
    n = int(SR * size)
    ir = lp(rng.standard_normal(n), bright) * np.exp(-np.arange(n) / SR * (6.9 / size))
    for dl, g in [(0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.2)]:
        ir[int(dl * SR)] += g * 3
    ir = np.concatenate([np.zeros(int(pre * SR)), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
    out = np.zeros(len(y))
    out[: len(x)] += x * (1 - wet * 0.5)
    out += y * wet
    return out


def trim(x, thresh=1e-4):
    a = np.abs(x)
    idx = np.nonzero(a > thresh * a.max())[0]
    return x[: idx[-1] + 1] if len(idx) else x


def write(path, sig, vol=0.8):
    sig = trim(np.asarray(sig, float))
    sig = np.tanh(sig / (np.abs(sig).max() + 1e-9) * 1.15) / np.tanh(1.15) * vol
    fade = min(len(sig), int(SR * 0.012))
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype(np.int16)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def save(name, sig, vol=0.8):
    write(OUT / f'{name}.wav', sig, vol)


# ── instruments ──
def koban(f=2600, d=0.5, bright=1.0):
    """A small gold coin: inharmonic plate partials, quick metallic attack."""
    r = [1, 1.59, 2.14, 2.65, 3.42, 4.2]
    y = modes([f * k * rng.uniform(0.995, 1.005) for k in r], [9, 11, 14, 18, 24, 30],
              [1, 0.7 * bright, 0.55 * bright, 0.4, 0.3 * bright, 0.2], d)
    return mix([(0, y), (0, hp(noise(0.004), 4000) * expenv(int(SR * 0.004), 900) * 0.6)])


def chalin(f=2600, gap=0.055):
    """チャリン: two quick coin strikes."""
    return mix([(0, koban(f, 0.45) * 0.8), (gap, koban(f * 1.06, 0.6))])


def glock(f, d=0.8, decay=5.0):
    """Glockenspiel / metallophone bar."""
    bar = modes([f, f * 2.76, f * 5.40, f * 8.93], [decay, decay * 2.2, decay * 4, decay * 6], [1, 0.35, 0.15, 0.06], d)
    return mix([(0, bar), (0, hp(noise(0.003), 5000) * expenv(int(SR * 0.003), 1500) * 0.15)])


def furin(f, d=1.6):
    """Glass wind chime (風鈴): bright, long, slightly beating partials."""
    glass = modes([f, f * 1.003, f * 2.32, f * 3.17, f * 4.6], [2.2, 2.4, 4, 6, 9], [1, 0.6, 0.45, 0.3, 0.15], d)
    return mix([(0, glass), (0, hp(noise(0.002), 6000) * 0.2)])


def koto(f, d=1.4, bright=0.5, decay=0.996):
    """Karplus-Strong pluck, a little nasal like a koto."""
    n = int(SR / f)
    exc = np.zeros(int(SR * d))
    burst = lp(rng.uniform(-1, 1, n), 2000 + 7000 * bright)
    exc[:n] = burst
    a = np.zeros(n + 2)
    a[0] = 1
    a[n] = -decay * 0.5
    a[n + 1] = -decay * 0.5
    y = signal.lfilter([1], a, exc)
    y += 0.25 * hp(y, 1500)  # nasal pluck edge
    return y * np.minimum(t(d) / 0.002, 1)


def taiko(f=95, d=0.9, hit=1.0):
    """Taiko: membrane modes with a pitch drop, stick click and body."""
    x = t(d)
    drop = 1 + 0.35 * np.exp(-x * 30)
    y = np.zeros_like(x)
    for k, g, r in [(1, 1, 5.5), (1.59, 0.35, 9), (2.14, 0.22, 13), (2.65, 0.12, 18)]:
        ph = 2 * np.pi * np.cumsum(f * k * drop) / SR
        y += g * np.sin(ph) * np.exp(-x * r)
    y *= np.minimum(x / 0.002, 1)
    stick = bp(noise(0.03), 300, 2500) * expenv(int(SR * 0.03), 120) * 0.5 * hit
    return reverb(mix([(0, y), (0, stick)]), 0.9, 0.3, 3000)


def kane(f=780, d=1.2):
    """Small festival hand gong (鉦): bright clangy metal."""
    return modes([f, f * 1.49, f * 2.43, f * 2.97, f * 4.13, f * 5.2], [3, 4, 6, 7, 10, 14],
                 [1, 0.8, 0.6, 0.5, 0.3, 0.2], d)


def brass(n, d, vib=True):
    """Bright brass-ish note: harmonics whose brightness follows the envelope."""
    f = note(n)
    x = t(d)
    e = adsr(len(x), 0.025, 0.12, 0.75, 0.12, max(0, d - 0.3))
    fm = f * (1 + (0.006 * np.sin(2 * np.pi * 5.5 * x) * np.minimum(x / 0.25, 1) if vib else 0))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    y = np.zeros_like(x)
    for k in range(1, 12):
        if f * k > SR / 2:
            break
        y += np.sin(ph * k) / k * e ** (1 + 0.35 * k)
    return y


def plastic(f=1800, hard=1.0, d=0.06):
    """One hollow plastic capsule knock."""
    r = [1, 1.62, 2.33, 3.1, 4.4]
    y = modes([f * k * rng.uniform(0.97, 1.03) for k in r], [70, 95, 130, 170, 230], [1, 0.7, 0.5, 0.35, 0.2], d)
    click = hp(noise(0.003), 3000) * expenv(int(SR * 0.003), 1200) * 0.5 * hard
    return mix([(0, y), (0, click)])


def jostle(dur, rate=60, f=(1300, 2600), amp=0.5):
    """Capsules knocking around in the dome."""
    parts, s = [], 0.0
    while s < dur:
        parts.append((s, plastic(rng.uniform(*f), rng.uniform(0.3, 1)) * amp * rng.uniform(0.2, 1)))
        s += rng.exponential(1 / rate)
    return mix(parts, dur)


def tooth(f=2900, body=150, metal=1.0, weight=1.0):
    """One ratchet tooth: pawl click (metal), gear body thunk."""
    pawl = modes([f, f * 2.32, f * 4.25, f * 6.6], [160, 220, 300, 400], [1, 0.6, 0.35, 0.2], 0.05) * metal
    tick = bp(noise(0.006), 2500, 9000) * expenv(int(SR * 0.006), 700) * 0.8
    thunk = modes([body, body * 2.2, body * 3.7], [45, 70, 110], [1, 0.4, 0.2], 0.12) * 0.7 * weight
    return mix([(0, pawl * 0.6), (0, tick), (0, thunk)])


def clunk(body=110, weight=1.0):
    """The latch at the end of a turn: ガコン."""
    low = modes([body, body * 1.9, body * 3.1, body * 4.6], [22, 30, 45, 60], [1, 0.6, 0.35, 0.2], 0.35) * weight
    hit = bp(noise(0.02), 500, 6000) * expenv(int(SR * 0.02), 200)
    return mix([(0, low), (0, hit * 0.7), (0.004, tooth(2300, body * 1.3, 0.6, 0.5) * 0.6)])


def turn(times, f=2900, body=150, metal=1.0, weight=1.0, jit=0.012):
    return mix([(s + rng.uniform(-jit, jit) * (i > 0), tooth(f * rng.uniform(0.96, 1.04), body, metal, weight)
                 * rng.uniform(0.75, 1)) for i, s in enumerate(times)])


def roll(dur, speed=18, f=900, amp=0.5):
    """A capsule rolling down the chute: rumble pulsing with each revolution."""
    x = t(dur)
    rumble = bp(noise(dur), f * 0.4, f * 1.6) * (0.6 + 0.4 * np.sin(2 * np.pi * speed * x)) * amp
    ticks = mix([(s, plastic(rng.uniform(900, 1600), 0.3) * 0.25) for s in np.arange(0, dur, 1 / speed)], dur)
    return (rumble + ticks[: len(rumble)]) * adsr(len(x), 0.03, 0.05, 1, 0.08, dur - 0.16)


def land(f=520, bounces=2, bright=1.0, gap=0.11):
    """Capsule hitting the tray: コトン, then smaller bounces."""
    def hit(g):
        lowm = modes([f, f * 1.7, f * 2.6, f * 3.9], [40, 55, 80, 120], [1, 0.6, 0.4 * bright, 0.25 * bright], 0.25)
        shell = plastic(f * 3.2, 0.8 * bright, 0.08) * 0.5
        return (lowm + pad(shell, 0.25)[: len(lowm)]) * g
    parts, s, g = [(0, hit(1))], 0.0, 1.0
    for _ in range(bounces):
        s += gap
        g *= 0.45
        gap *= 0.62
        parts.append((s, hit(g)))
    return mix(parts)


def vowel_babble(pitch, n, spread, speed, seed):
    """The tanuki's babble: a buzzy glottal source through vowel formants."""
    r = np.random.default_rng(seed)
    formants = {'a': (800, 1200), 'i': (300, 2300), 'u': (350, 1250), 'e': (500, 1900), 'o': (500, 850)}
    parts, s = [], 0.0
    for _ in range(n):
        v = r.choice(list(formants))
        d = speed * r.uniform(0.8, 1.25)
        f0 = pitch * 2 ** (r.uniform(-spread, spread) / 12)
        x = t(d)
        f = f0 * (1 + 0.08 * (r.uniform() - 0.5) * x / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = sum(np.sin(ph * k) / k ** 0.9 for k in range(1, 30) if f0 * k < SR / 2)
        f1, f2 = formants[v]
        y = bp(src, f1 * 0.8, f1 * 1.25) + 0.6 * bp(src, f2 * 0.85, f2 * 1.2)
        parts.append((s, y * adsr(len(x), 0.008, 0.03, 0.8, 0.03, d - 0.07)))
        s += d * 0.92
    return mix(parts)


# ── gacha candidates ──
# Tuned against a real gashapon recording (pocket-se.info "ガチャガチャのレバーを回す音", analysed only,
# not shipped): light bright clicks decaying in 10-25 ms, resonances near 960 / 1840 / 2360 Hz with a
# broad 4-7 kHz edge, almost nothing below 400 Hz, in irregular bursts 25-90 ms apart.
REF_ONSETS = [0, .088, .124, .19, .223, .253, .297, .378, .417, .452, .565, .629, .82, .846, .872, .929, .955, .998]
REF_AMPS = [.74, .3, .73, 1, .41, .57, .53, .54, .37, .97, .28, .34, .55, .32, .31, .34, .82, .47]


def gclick(scale=1.0, bright=1.0, amp=1.0):
    """One light ratchet click of a capsule machine."""
    base = [960, 1840, 2360, 3880, 4520, 6120, 6840]
    y = modes([f * scale * rng.uniform(0.96, 1.04) for f in base], [110, 120, 105, 150, 170, 200, 230],
              [0.45, 0.4, 0.6, 0.45 * bright, 0.35 * bright, 0.4 * bright, 0.3 * bright], 0.04)
    edge = bp(noise(0.008), 2500, 10000) * expenv(int(SR * 0.008), 350) * 1.6 * bright
    tap = modes([200 * scale], [70], [0.15], 0.04)
    return mix([(0, y), (0, edge), (0, tap)]) * amp


def knock():
    """A capsule bumping another inside the dome (rings a bit longer)."""
    return plastic(rng.uniform(1200, 2300), 0.5, 0.09) * rng.uniform(0.15, 0.35)


def clicks(times, amps=None, scale=1.0, bright=1.0, jit=0.0):
    amps = amps or [rng.uniform(0.4, 1) for _ in times]
    return mix([(max(0, s + rng.uniform(-jit, jit)), gclick(scale, bright, a)) for s, a in zip(times, amps)])


def knocks(dur, n):
    return mix([(rng.uniform(0, dur), knock()) for _ in range(n)], dur)


def handle_cand(k):
    """Turning the crank. Light, bright, plastic-and-spring clicks."""
    global rng
    rng = np.random.default_rng(ord(k))
    one = REF_ONSETS[:10]  # the first burst of the real recording (one turn)
    if k == 'A':  # two turns, rhythm of the real thing
        y = mix([(0, clicks(REF_ONSETS[:12], REF_AMPS[:12])), (0, knocks(0.95, 6))])
    elif k == 'B':  # one turn, real rhythm
        y = mix([(0, clicks(one, REF_AMPS[:10])), (0, knocks(0.6, 4))])
    elif k == 'C':  # the full real rhythm (three bursts)
        y = mix([(0, clicks(REF_ONSETS, REF_AMPS)), (0, knocks(1.3, 8))])
    elif k == 'D':  # short and snappy
        y = mix([(0, clicks([0, .05, .09, .15, .2, .27], [.8, .5, .9, .6, .7, 1])), (0, knocks(0.35, 2))])
    elif k == 'E':  # one turn, capsules rattle more
        y = mix([(0, clicks(one, REF_AMPS[:10])), (0, knocks(0.65, 14) * 1.6)])
    elif k == 'F':  # one turn, smaller and brighter machine
        y = mix([(0, clicks(one, REF_AMPS[:10], 1.25, 1.3)), (0, knocks(0.6, 4))])
    elif k == 'G':  # one turn, bigger and softer machine
        y = mix([(0, clicks(one, REF_AMPS[:10], 0.82, 0.7)), (0, knocks(0.6, 5))])
    elif k == 'H':  # one turn, evenly spaced like a regular ratchet
        y = mix([(0, clicks(list(np.arange(10) * 0.05), [0.8] * 10, jit=0.004)), (0, knocks(0.55, 4))])
    else:
        raise KeyError(k)
    return reverb(y, 0.35, 0.12)


def drop_cand(k):
    """The capsule coming out: down the chute and into the plastic tray (light)."""
    global rng
    rng = np.random.default_rng(1000 + ord(k))
    if k == 'A':  # short roll, コトッ、コト
        y = mix([(0, roll(0.16, 20, 1100, 0.35)), (0.15, land(760, 2, 1.2))])
    elif k == 'B':  # straight drop, single ゴトッ
        y = land(620, 1, 1.0, 0.12)
    elif k == 'C':  # longer chute コロコロ… コトッ
        y = mix([(0, roll(0.36, 16, 1100, 0.4)), (0.34, land(740, 2, 1.2))])
    elif k == 'D':  # very light tray カコッ、カコ、カ
        y = mix([(0, roll(0.1, 24, 1400, 0.25)), (0.09, land(900, 3, 1.5, 0.09))])
    elif k == 'E':  # tapping the chute walls on the way down
        walls = mix([(s, plastic(rng.uniform(1300, 2000), 0.8, 0.05) * g) for s, g in [(0, .5), (.05, .7), (.1, .45), (.15, .8)]])
        y = mix([(0, walls), (0, roll(0.2, 22, 1200, 0.25)), (0.2, land(780, 2, 1.2))])
    elif k == 'F':  # soft ポスッ
        soft = bp(noise(0.05), 400, 2500) * expenv(int(SR * 0.05), 70) * 0.7
        y = mix([(0, roll(0.13, 18, 1000, 0.3)), (0.12, soft), (0.12, modes([520, 900], [40, 60], [0.6, 0.3], 0.15)),
                 (0.18, mix([(i * 0.06, plastic(1400, 0.3, 0.05) * 0.25 * 0.7 ** i) for i in range(3)]))])
    else:
        raise KeyError(k)
    return y


def rarity_layer(tier):
    """What a rarer capsule adds on landing: more sparkle, more fanfare."""
    if tier == 0:
        return np.zeros(1)
    if tier == 1:  # rare: a little twinkle
        return mix([(0, glock(note(96), 0.6) * 0.35), (0.06, glock(note(100), 0.8) * 0.35)])
    if tier == 2:  # epic: koto run up and a glass chord
        return mix([(i * 0.04, koto(note(n), 0.8, 0.7) * 0.5) for i, n in enumerate([79, 81, 84, 86, 88])]
                   + [(0.2, sum(furin(note(n), 1.4) for n in (91, 96, 100)) * 0.25)])
    # legend: gong, soft taiko, golden cascade and a short brass chord
    return mix([(0, kane(1400, 1.2) * 0.3), (0, taiko(90, 0.9) * 0.6),
                (0.08, (brass(79, 0.7) + brass(84, 0.7) + brass(88, 0.7)) * 0.25)]
               + [(0.05 + i * 0.035, glock(note(96 + [0, 2, 4, 7, 9][i % 5] + 12 * (i // 5)), 0.5) * 0.25) for i in range(10)])


LAND_AT = {'A': 0.15, 'B': 0.0, 'C': 0.34, 'D': 0.09, 'E': 0.2, 'F': 0.12}


def drop_tier(k, tier):
    return reverb(mix([(0, drop_cand(k)), (LAND_AT[k], rarity_layer(tier))]), 0.5, 0.15 + 0.05 * tier)


HANDLES = {
    'A': '実物のリズム・2回分（標準）',
    'B': '実物のリズム・1回分',
    'C': '実物のリズムそのまま・3回分',
    'D': '短くてキビキビ',
    'E': '1回分＋中のカプセルがよく鳴る',
    'F': '1回分・小さめで明るいマシン',
    'G': '1回分・大きめでやわらかい',
    'H': '1回分・等間隔の機械っぽい',
}
# when the last click has sounded: the capsule comes out right after this (seconds)
HANDLE_END = {'A': 0.72, 'B': 0.52, 'C': 1.05, 'D': 0.33, 'E': 0.52, 'F': 0.52, 'G': 0.52, 'H': 0.5}
DROPS = {
    'A': '短く転がって コトッ、コト（標準）',
    'B': 'まっすぐ落ちて ゴトッ',
    'C': '少し長い出口 コロコロ… コトッ',
    'D': 'とても軽い受け皿 カコッ、カコ、カ',
    'E': '出口の壁をたたきながら落ちる',
    'F': 'やわらかく ポスッ',
}
TIERS = ['ノーマル', 'レア', 'エピック', 'レジェンド']


def candidates():
    CAND.mkdir(parents=True, exist_ok=True)
    for f in CAND.glob('*.wav'):
        f.unlink()
    for k in HANDLES:
        write(CAND / f'handle_{k}.wav', handle_cand(k), 0.8)
    for k in DROPS:
        for tier in range(4):
            write(CAND / f'drop_{k}_{tier}.wav', drop_tier(k, tier), 0.8)
    rows_h = '\n'.join(f'<button data-h="{k}" data-end="{HANDLE_END[k]}"><b>{k}</b><span>{v}</span></button>'
                       for k, v in HANDLES.items())
    rows_d = '\n'.join(f'<button data-d="{k}"><b>{k}</b><span>{v}</span></button>' for k, v in DROPS.items())
    rows_t = ''.join(f'<button class="tier" data-t="{i}">{n}</button>' for i, n in enumerate(TIERS))
    (CAND / 'index.html').write_text(f"""<!doctype html><html lang="ja"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>ガチャ音の候補</title>
<style>
:root{{--bg:#fff8ef;--ink:#4a2e2a;--card:#fff;--pink:#ff6fa3;--mint:#2fb894;--gold:#e0a400;--line:#e6d3bd}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1f1830;--ink:#f6eadf;--card:#2c2342;--line:#4a3d63}}}}
body{{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,"Hiragino Maru Gothic ProN",sans-serif}}
main{{max-width:760px;margin:auto;padding:20px 16px 60px}}
h1{{font-size:22px;margin:0 0 4px}} h2{{font-size:17px;margin:26px 0 8px}} p{{margin:0 0 10px;opacity:.8}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:8px}}
button{{all:unset;cursor:pointer;background:var(--card);border:2px solid var(--line);border-radius:14px;padding:10px 12px;display:flex;gap:10px;align-items:center}}
button b{{font-size:20px;min-width:22px;color:var(--pink)}} button.on{{border-color:var(--pink)}}
[data-d] b{{color:var(--mint)}} [data-d].on{{border-color:var(--mint)}}
.tiers{{display:flex;gap:6px;flex-wrap:wrap}} .tier.on{{border-color:var(--gold);color:var(--gold);font-weight:700}}
.combo{{position:sticky;top:0;background:var(--bg);padding:10px 0;display:flex;gap:10px;align-items:center;flex-wrap:wrap;border-bottom:2px solid var(--line)}}
.combo #play{{background:var(--pink);color:#fff;border:0;font-weight:700;padding:10px 18px}}
</style><main>
<h1>ガチャ音の候補</h1>
<p>実物の録音（ポケットサウンド「ガチャガチャのレバーを回す音」）のカチ音の長さ・響き・間隔を測って寄せた合成音です。録音そのものは使っていません。</p>
<p>ハンドルと出てくる音を選び、レア度を切りかえて「組み合わせで聞く」と、ゲームと同じ流れで鳴ります。</p>
<div class="combo"><button id="play">▶ 組み合わせで聞く</button><div class="tiers">{rows_t}</div><span id="pick"></span></div>
<h2>ハンドルを回す音</h2><div class="grid">{rows_h}</div>
<h2>カプセルが出てくる音（レア度で豪華になる）</h2><div class="grid">{rows_d}</div>
<script>
let h='A',d='A',tr=0;const a=n=>{{const x=new Audio(n);x.play();return x}};
const names={TIERS!r};
const mark=()=>{{document.querySelectorAll('[data-h]').forEach(b=>b.classList.toggle('on',b.dataset.h===h));
document.querySelectorAll('[data-d]').forEach(b=>b.classList.toggle('on',b.dataset.d===d));
document.querySelectorAll('[data-t]').forEach(b=>b.classList.toggle('on',+b.dataset.t===tr));
document.getElementById('pick').textContent=`ハンドル ${{h}} ＋ 出てくる音 ${{d}}（${{names[tr]}}）`}};
document.querySelectorAll('[data-h]').forEach(b=>b.onclick=()=>{{h=b.dataset.h;mark();a(`handle_${{h}}.wav`)}});
document.querySelectorAll('[data-d]').forEach(b=>b.onclick=()=>{{d=b.dataset.d;mark();a(`drop_${{d}}_${{tr}}.wav`)}});
document.querySelectorAll('[data-t]').forEach(b=>b.onclick=()=>{{tr=+b.dataset.t;mark();a(`drop_${{d}}_${{tr}}.wav`)}});
document.getElementById('play').onclick=()=>{{a(`handle_${{h}}.wav`);
const end=+document.querySelector(`[data-h="${{h}}"]`).dataset.end;setTimeout(()=>a(`drop_${{d}}_${{tr}}.wav`),end*1000)}};mark();
</script></main></html>""")
    print('candidates ->', CAND)


# ── the money sounds, kept exactly as the first version (players liked them) ──
def _o_osc(f0, d, wave='sine', f1=None, curve=1.0):
    x = t(d)
    f = f0 if f1 is None else f0 + (f1 - f0) * (x / d) ** curve
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(f, x.shape)) / SR
    return np.tanh(np.sin(ph) * 4) * 0.7 if wave == 'square' else np.sin(ph)


def _o_env(sig, a=0.003, decay=8.0):
    x = np.arange(len(sig)) / SR
    return sig * np.where(x < a, x / max(a, 1e-6), np.exp(-np.maximum(x - a, 0) * decay))


def _o_coin(f, d=0.16):
    return mix([(0, _o_env(_o_osc(f, 0.05, 'square'), 0.001, 20)), (0.045, _o_env(_o_osc(f * 1.335, d, 'square'), 0.001, 14))])


def _o_bell(f, d=0.6, decay=6.0):
    s = _o_osc(f, d) + 0.45 * _o_osc(f * 2.01, d) + 0.25 * _o_osc(f * 3.98, d) + 0.12 * _o_osc(f * 5.4, d)
    return _o_env(s, 0.002, decay)


def _o_echo(sig, delay=0.09, fb=0.35, n=4):
    out = np.concatenate([sig, np.zeros(int(SR * delay * n))])
    for k in range(1, n + 1):
        i = int(SR * delay * k)
        out[i:i + len(sig)] += sig * fb ** k
    return out


def save_plain(name, sig, vol):
    """The first version's writer: plain peak normalise, 10 ms fade."""
    sig = np.asarray(sig, float)
    sig = sig / (np.abs(sig).max() + 1e-9) * vol
    fade = min(len(sig), int(SR * 0.01))
    sig[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((sig * 32767).astype(np.int16).tobytes())


def money_sounds():
    penta = [0, 2, 4, 7, 9]
    for i in range(15):  # rising coin blips for each scoring beat
        save_plain(f'tick_{i:02d}', _o_coin(note(79 + 12 * (i // 5) + penta[i % 5])), 0.5)
    save_plain('total_small', mix([(i * 0.07, _o_coin(note(n))) for i, n in enumerate([84, 88, 91])]), 0.6)
    save_plain('total_big', _o_echo(mix([(i * 0.035, _o_coin(note(84 + penta[i % 5] + 12 * ((i // 5) % 2))) * 0.7) for i in range(22)]
                                        + [(0.8, _o_bell(note(84), 1.2, 2.5) + _o_bell(note(88), 1.2, 2.5) + _o_bell(note(91), 1.2, 2.5))]),
                                    0.09, 0.25), 0.8)


# ── game sounds ──
def build():
    global rng
    # UI
    rng = np.random.default_rng(1)
    save('tap', modes([1250, 2900, 4300], [90, 140, 220], [1, 0.4, 0.15], 0.08) + pad(hp(noise(0.003), 3000) * 0.3, 0.08), 0.5)
    save('toggle', mix([(0, plastic(2600, 0.8, 0.05) * 0.7), (0.045, plastic(3300, 1, 0.06))]), 0.5)

    # machine
    save('handle', handle_cand(HANDLE), 0.8)
    for tier in range(4):  # the capsule coming out gets fancier with its rarity
        save(f'drop_{tier}', drop_tier(DROP, tier), 0.8)
    rng = np.random.default_rng(2)
    save('rattle', reverb(mix([(0, knocks(0.3, 8) * 2), (0.03, gclick(1, 1, 0.5))]), 0.35, 0.12), 0.5)
    rng = np.random.default_rng(3)
    # capsule pops open: a plastic snap and a little air
    snap = mix([(0, plastic(2100, 1.2, 0.07)), (0.012, plastic(1600, 0.8, 0.09) * 0.7)])
    air = bp(noise(0.12), 1500, 7000) * expenv(int(SR * 0.12), 35) * 0.3
    save('open', reverb(mix([(0, snap), (0.01, air), (0.03, glock(note(96), 0.3, 9) * 0.25)]), 0.4, 0.15), 0.8)
    # something rare inside: shimmering rising chord with tremolo
    x = t(1.3)
    shim = sum(osc(f, 1.3, f * 2, 1.6) for f in (note(72), note(76), note(79)))
    shim *= (0.6 + 0.4 * np.sin(2 * np.pi * 13 * x)) * adsr(len(x), 0.3, 0.2, 0.8, 0.4, 0.4)
    sparkle = mix([(0.3 + i * 0.07, glock(note(96 + [0, 4, 7, 12][i % 4]), 0.4) * 0.2) for i in range(12)], 1.3)
    save('omen', reverb(shim * 0.4 + sparkle[: len(shim)], 1.2, 0.35), 0.55)

    # reveals by rarity: normal / rare / epic / legend
    rng = np.random.default_rng(4)
    save('reveal_0', reverb(mix([(0, glock(note(84))), (0.07, glock(note(88), 0.9))]), 0.6, 0.2), 0.55)
    save('reveal_1', reverb(mix([(i * 0.06, glock(note(n), 0.9)) for i, n in enumerate([84, 88, 91, 96])]), 0.8, 0.25), 0.6)
    save('reveal_2', reverb(mix([(i * 0.05, koto(note(n), 1.2, 0.7)) for i, n in enumerate([74, 76, 79, 81, 84, 86, 88])]
                                + [(0.36, sum(furin(note(n), 1.6) for n in (91, 96, 100)) * 0.35)]), 1.0, 0.3), 0.75)
    save('reveal_3', reverb(mix([
        (0.00, taiko(90, 1.0)), (0.00, brass(72, 0.16)), (0.17, brass(72, 0.12)), (0.29, brass(76, 0.12)),
        (0.44, brass(79, 1.1) + brass(84, 1.1) + brass(76, 1.1)), (0.44, taiko(80, 1.2)), (0.44, kane(1500, 1.0) * 0.25),
    ] + [(0.5 + i * 0.045, glock(note(96 + [0, 2, 4, 7, 9][i % 5]), 0.5) * 0.3) for i in range(14)]), 1.2, 0.3), 0.85)

    # shelf / scoring
    rng = np.random.default_rng(5)
    save('place', mix([(0, modes([420, 980, 1700], [40, 60, 90], [1, 0.45, 0.2], 0.18)), (0, plastic(2000, 0.5, 0.05) * 0.4)]), 0.65)
    penta = [0, 2, 4, 7, 9]
    money_sounds()
    x = t(0.4)
    boing = osc(520, 0.4, 170, 0.7, 'tri') * (1 + 0.35 * np.sin(2 * np.pi * 18 * x)) * adsr(len(x), 0.005, 0.1, 0.6, 0.2, 0.05)
    save('minus', reverb(boing, 0.4, 0.15), 0.6)
    save('buff', reverb(mix([(i * 0.04, glock(note(n), 0.4, 8)) for i, n in enumerate([88, 91, 96])]), 0.5, 0.2), 0.5)
    rise = osc(300, 0.24, 1600, 0.5, 'tri') * adsr(int(SR * 0.24), 0.01, 0.2, 0.5, 0.03) * 0.3
    save('mult', reverb(mix([(0, rise), (0.18, glock(note(91), 0.8) + glock(note(95), 0.8) * 0.8 + glock(note(98), 0.8) * 0.6),
                             (0.18, chalin(2800) * 0.4)]), 0.7, 0.25), 0.75)
    whoosh = bp(noise(0.4), 400, 5000) * np.linspace(0, 1, int(SR * 0.4)) ** 2 * 0.5
    save('mult_big', reverb(mix([(0, whoosh), (0, osc(200, 0.4, 2000, 0.4, 'tri') * adsr(int(SR * 0.4), 0.01, 0.3, 0.6, 0.05) * 0.3),
                                 (0.38, taiko(85, 1.0)), (0.38, kane(1300, 1.2) * 0.3),
                                 (0.38, sum(glock(note(n), 1.4, 3) for n in (84, 88, 91, 96)))]), 1.0, 0.3), 0.85)
    # cork gun at the shooting gallery: ポン
    cork = bp(noise(0.04), 600, 3000) * expenv(int(SR * 0.04), 90)
    save('shoot', reverb(mix([(0, cork), (0, osc(900, 0.06, 250) * expenv(int(SR * 0.06), 50) * 0.8),
                              (0.09, plastic(1800, 1, 0.06) * 0.6)]), 0.5, 0.2), 0.8)
    # water balloon / soap pop
    save('pop', mix([(0, osc(500, 0.05, 1600, 0.6) * expenv(int(SR * 0.05), 60)), (0.02, bp(noise(0.03), 1500, 6000) * expenv(int(SR * 0.03), 140) * 0.5)]), 0.65)
    save('spawn', reverb(mix([(i * 0.045, glock(note(96 + [0, 4, 7, 12, 16, 12, 7][i]), 0.35, 9) * 0.7) for i in range(7)]), 0.6, 0.25), 0.5)

    # payday
    rng = np.random.default_rng(6)
    save('payday', mix([(0, taiko(92)), (0.2, taiko(92, 0.8, 0.8) * 0.75), (0.56, taiko(84, 1.2) * 1.1), (0.56, kane(900, 0.8) * 0.15)]), 0.85)
    jara = mix([(rng.uniform(0, 0.18), koban(rng.uniform(2300, 3500), 0.25) * rng.uniform(0.3, 0.8)) for _ in range(18)], 0.3)
    save('pay_ok', reverb(mix([(0, jara), (0.12, glock(note(96), 0.6)), (0.2, glock(note(100), 1.0))]), 0.7, 0.25), 0.7)
    save('pay_fail', reverb(mix([(0, taiko(70, 1.0) * 0.8)] + [(0.1 + i * 0.3, koto(note(n), 0.9 if i < 3 else 1.6, 0.4, 0.993))
                                                             for i, n in enumerate([67, 66, 65, 62])]), 0.9, 0.3), 0.7)

    # boss babble per mood (neutral / pleased / delighted / angry)
    save('boss_0', vowel_babble(190, 6, 3, 0.075, 10), 0.5)
    save('boss_1', vowel_babble(240, 7, 4, 0.065, 11), 0.5)
    save('boss_2', vowel_babble(300, 6, 6, 0.06, 12), 0.5)
    save('boss_3', vowel_babble(140, 6, 2, 0.09, 13), 0.55)

    # shop / meta
    rng = np.random.default_rng(8)
    save('shop', reverb(mix([(i * 0.11, furin(note(n), 1.4)) for i, n in enumerate([91, 88, 96])]), 1.0, 0.3), 0.5)
    save('buy', reverb(mix([(0, chalin(2700)), (0.12, glock(note(96), 0.5) * 0.4)]), 0.5, 0.2), 0.6)
    tiles = mix([(i * 0.028, plastic(rng.uniform(900, 1600), 0.7, 0.05) * (0.4 + 0.6 * i / 10)) for i in range(11)])
    save('reroll', reverb(tiles, 0.4, 0.15), 0.5)
    save('new', reverb(mix([(i * 0.05, glock(note(n), 0.5)) for i, n in enumerate([96, 100, 103, 108])]), 0.8, 0.3), 0.5)
    save('unlock', reverb(mix([(i * 0.1, brass(n, 0.17)) for i, n in enumerate([72, 76, 79])] +
                              [(0.3, brass(84, 0.9) + brass(79, 0.9)), (0.3, kane(1400, 0.9) * 0.2)]), 0.9, 0.3), 0.7)
    save('clear', reverb(mix([
        (0.0, taiko(92)), (0.0, brass(72, 0.2)), (0.2, brass(72, 0.15)), (0.35, brass(74, 0.15)), (0.5, brass(76, 0.2)),
        (0.7, brass(79, 0.25)), (0.95, brass(84, 1.4) + brass(79, 1.4) + brass(76, 1.4)), (0.95, taiko(80, 1.2)),
        (0.95, kane(1500, 1.2) * 0.25),
    ] + [(1.0 + i * 0.05, glock(note(96 + penta[i % 5]), 0.5) * 0.3) for i in range(16)]), 1.2, 0.3), 0.85)
    save('over', reverb(mix([(i * 0.24, koto(note(n), 0.8 if i < 3 else 1.8, 0.45)) for i, n in enumerate([76, 72, 69, 64])]), 1.0, 0.3), 0.6)
    save('jingle', reverb(mix([(i * 0.09, koto(note(n), 1.0, 0.6)) for i, n in enumerate([76, 79, 81, 84])]
                              + [(0.36, furin(note(96), 1.2) * 0.3)]), 0.9, 0.3), 0.55)

    # the game waits this long between the handle and the drop (lib/ui/sfx.dart)
    dart = ROOT / 'lib' / 'ui' / 'sfx_timing.dart'
    dart.write_text('// Generated by art/sfx.py: when the chosen handle sound has finished turning.\n'
                    f'const handleMs = {round(HANDLE_END[HANDLE] * 1000)};\n')
    print('\n'.join(sorted(p.name for p in OUT.glob('*.wav'))))
    print(sum(p.stat().st_size for p in OUT.glob('*.wav')) // 1024, 'KB')


if __name__ == '__main__':
    if 'candidates' in sys.argv[1:]:
        candidates()
    build()
