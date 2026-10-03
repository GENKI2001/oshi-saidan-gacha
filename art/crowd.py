"""The live crowd, mixed from TTS fan shouts (voice/crowd/*.wav) and synthesized noise.

  python3 art/crowd.py
Writes to assets/sfx/:
- cheer_s<0-2>_<v>.wav : short cheers (a few fans → many) played while hearts are counted;
  the app picks the size from the gain and the hype (lib/ui/crowd.dart)
- cheer_big.wav  : a swell of cheers (a big turn)
- cheer_song.wav : the roar and applause at the end of a song
- call_<idol>_<n>.wav : a fan or two calling that idol's name (when her goods come out)
The shouts come from voice/crowd_jobs.json (Irodori-TTS, several fan voices).
"""
import wave
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'voice' / 'crowd'
OUT = ROOT / 'assets' / 'sfx'
SR = 22050
rng = np.random.default_rng(11)


def load(path):
    sr, y = wavfile.read(path)
    y = y.astype(np.float64) / (32768.0 if y.dtype == np.int16 else 1.0)
    if y.ndim > 1:
        y = y.mean(1)
    y = signal.resample_poly(y, SR, sr)
    # trim silence at both ends
    idx = np.nonzero(np.abs(y) > 0.02)[0]
    y = y[idx[0]:idx[-1] + 1] if len(idx) else y
    return y / (np.abs(y).max() + 1e-9)


SHOUTS = {p.stem: load(p) for p in sorted(SRC.glob('*.wav'))}
NAMES = {'hinata': 'hinata', 'shizuku': 'shizuku', 'koharu': 'koharu', 'yoru': 'yoru', 'momo': 'momo'}
GENERIC = [k for k in SHOUTS if k.split('_')[0] in ('kawaii', 'saikou', 'wa', 'kya', 'fu', 'iei', 'pripare')]


def pitch(y, f):
    """Resample to shift pitch/speed together (crowd voices vary)."""
    n = int(len(y) / f)
    return signal.resample(y, n)


def room(y, wet=0.35, far=0.0):
    """A hall: a few echoes and a low-pass for distance."""
    out = y.copy()
    for d, g in ((0.031, 0.5), (0.057, 0.4), (0.089, 0.3), (0.13, 0.22), (0.19, 0.15), (0.27, 0.1)):
        i = int(SR * d)
        out[i:] += y[:-i] * g * wet
    if far > 0:
        b, a = signal.butter(2, max(800, 5000 * (1 - far)) / (SR / 2))
        out = signal.lfilter(b, a, out)
    return out


def noise_bed(sec, level, bright):
    """Crowd roar: band-passed noise with a slow, uneven swell."""
    n = int(SR * sec)
    x = rng.standard_normal(n)
    b, a = signal.butter(2, [250 / (SR / 2), (1500 + 2500 * bright) / (SR / 2)], btype='band')
    x = signal.lfilter(b, a, x)
    t = np.arange(n) / SR
    env = 1 + 0.25 * np.sin(2 * np.pi * 0.21 * t + 1) + 0.18 * np.sin(2 * np.pi * 0.47 * t)
    x *= env
    return x / (np.abs(x).max() + 1e-9) * level


def claps(sec, rate, level):
    """Applause: lots of short bright noise bursts at random times."""
    n = int(SR * sec)
    out = np.zeros(n + SR)
    hp_b, hp_a = signal.butter(2, 900 / (SR / 2), btype='high')
    for _ in range(int(sec * rate)):
        L = int(SR * rng.uniform(0.008, 0.02))
        c = rng.standard_normal(L) * np.exp(-np.arange(L) / (L * 0.25))
        at = rng.integers(0, n)
        out[at:at + L] += c * rng.uniform(0.2, 1)
    out = signal.lfilter(hp_b, hp_a, out)[:n]
    return out / (np.abs(out).max() + 1e-9) * level


def sprinkle(buf, keys, count, gain, far, spread=(0.88, 1.12), start=0.0, end=None):
    end = end or len(buf) / SR
    for _ in range(count):
        y = SHOUTS[keys[rng.integers(len(keys))]]
        y = pitch(y, rng.uniform(*spread))
        y = room(y, 0.4, far + rng.uniform(0, 0.25)) * gain * rng.uniform(0.5, 1)
        at = int(SR * rng.uniform(start, max(start, end - len(y) / SR)))
        e = min(len(buf), at + len(y))
        buf[at:e] += y[:e - at]


def swell(sec, rise, lo):
    n = int(SR * sec)
    k = int(SR * rise)
    return np.concatenate([np.linspace(lo, 1, k), np.ones(n - k)])


def save(name, y, vol=0.8, loop=False, fade_in=0.0, fade_out=0.0):
    y = y.copy()
    if fade_in:
        k = int(SR * fade_in)
        y[:k] *= np.linspace(0, 1, k)
    if fade_out:
        k = int(SR * fade_out)
        y[-k:] *= np.linspace(1, 0, k)
    y = y / (np.abs(y).max() + 1e-9) * vol
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())
    print(name, f'{len(y) / SR:.1f}s', (OUT / f'{name}.wav').stat().st_size // 1024, 'KB')


def looped(sec, fill):
    """Renders [sec + 3] seconds and folds the tail onto the start → a seamless loop."""
    buf = np.zeros(int(SR * (sec + 3)))
    fill(buf)
    n = int(SR * sec)
    loop = buf[:n].copy()
    tail = buf[n:]
    # crossfade the overlap so nothing clicks at the seam
    k = len(tail)
    loop[:k] = loop[:k] + tail
    return loop


all_names = [k for k in SHOUTS if k.split('_')[0] in NAMES or k.startswith('pripare')]

# ── short cheers while hearts are counted (a few voices → a crowd) ──
for n, (sec, shouts, roar, clap) in enumerate(((1.1, 3, 0.12, 120), (1.4, 6, 0.22, 300), (1.8, 10, 0.32, 600))):
    for v in range(3):
        b = np.zeros(int(SR * sec))
        b += noise_bed(sec, roar, 0.6 + 0.2 * n) * swell(sec, 0.12, 0.2)
        b += claps(sec, clap, 0.1 + 0.05 * n)
        sprinkle(b, GENERIC, shouts, 0.45, 0.25, end=sec * 0.8)
        save(f'cheer_s{n}_{v}', b, 0.75, fade_in=0.03, fade_out=sec * 0.45)

# ── one-shots ──
b = np.zeros(int(SR * 2.8))
b += noise_bed(2.8, 0.4, 0.9) * swell(2.8, 0.5, 0.2)
b += claps(2.8, 600, 0.2)
sprinkle(b, GENERIC, 14, 0.5, 0.1, end=2.4)
save('cheer_big', b, 0.85, fade_out=0.9)

b = np.zeros(int(SR * 4.5))
b += noise_bed(4.5, 0.45, 1.0) * swell(4.5, 0.4, 0.3)
b += claps(4.5, 1400, 0.3)
sprinkle(b, GENERIC + all_names, 26, 0.5, 0.1, end=4.0)
save('cheer_song', b, 0.9, fade_out=1.5)

# a fan (sometimes two) calling her name
for idol in NAMES:
    keys = [k for k in SHOUTS if k.startswith(idol + '_')]
    for n, k in enumerate(keys):
        y = room(pitch(SHOUTS[k], rng.uniform(0.95, 1.05)), 0.45, 0.2)
        other = keys[(n + 1) % len(keys)]
        y2 = room(pitch(SHOUTS[other], rng.uniform(0.9, 1.1)), 0.5, 0.35) * 0.55
        off = int(SR * rng.uniform(0.12, 0.3))
        out = np.zeros(max(len(y), off + len(y2)) + int(SR * 0.3))
        out[:len(y)] += y
        out[off:off + len(y2)] += y2
        save(f'call_{idol}_{n}', out, 0.7, fade_out=0.25)
