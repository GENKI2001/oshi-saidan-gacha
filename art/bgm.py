"""Synthesize the background loops into assets/bgm/*.wav (no samples).

  python3 art/bgm.py

All tracks are bright J-pop / anime-idol style: four-on-the-floor kick, claps on
2 and 4, offbeat open hats, side-chain-pumped pads, plucky arps, octave bass,
a soft singable lead and a little "kirakira" chime at phrase ends.

bgm_title     : title screen, 120 BPM, D major, 16 bars — IV-V-iii-vi hook, soft lead, pluck arp, glock in the B half
bgm_select    : choosing a machine, 110 BPM, G major, 8 bars — sparse marimba + bell tune, light kick/snap, low density
bgm_pripare   : ぷりパレガチャ, 128 BPM, E major, 16 bars — the unit's theme song: verse + chorus, 16th arps, chant claps
bgm_shizumomo : しずももガチャ, 118 BPM, A major, 12 bars — maj7/m7 chords, electric piano comping, glassy bell lead, airy reverb
bgm_koharu    : こはる推しガチャ, 100 BPM, F major, 12 bars — swung shuffle, toy piano lead, marimba offbeats, oom-pah bass
bgm_hinata    : ひなた推しガチャ, 140 BPM, C major, 16 bars — full drive: 16th hats, brass stabs, "hai! hai!" claps, snare fills
bgm_yoru      : よるの真夜中ガチャ, 112 BPM, D minor, 12 bars — harmonic minor (E7), harpsichord arps, staccato lead, celesta
bgm_premium   : プレミアムガチャ, 132 BPM, Bb major, 16 bars — brassy stabs, big 16th glockenspiel, fanfare lead, crash + rolls

Everything is written in C major / A minor and transposed by the song's `key`.
Each loop is an exact number of bars: the reverb/release tail past the loop point
is folded back onto the start, so the WAV loops gaplessly. Levels are
RMS-normalized with a gentle soft limiter, so all tracks sit at a similar
loudness under the voice lines. Partials above TOP Hz are dropped to keep the
highs soft.
"""
import re
import time
import wave
from pathlib import Path

import numpy as np

SR = 22050
TOP = 7000  # no partials above this: keeps the highs soft under voice lines
TARGET_RMS = 0.11
FADE = int(SR * 0.0015)  # every onset gets a 1.5 ms fade-in
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'bgm'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def add(buf, at, sig):
    i = int(round(at * SR))
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    sig = sig[:end - i].copy()
    k = min(len(sig), FADE)
    sig[:k] *= np.linspace(0, 1, k, endpoint=False)  # no hard onsets (keeps the loop seam click-free too)
    buf[i:end] += sig


def mix(*sigs):
    """Sum signals of different lengths."""
    out = np.zeros(max(len(x) for x in sigs))
    for x in sigs:
        out[:len(x)] += x
    return out


def _t(dur):
    return np.arange(max(1, int(SR * dur))) / SR


def gate(t, dur, att, rel):
    return np.clip(t / att, 0, 1) * np.clip((dur - t) / rel, 0, 1)


def osc(f, t, partials, vib=0.0, vib_hz=5.5, vib_delay=0.15, bend=0.0, phase=0.0):
    """Sum of partials (ratio, amp, decay/s). Partials above TOP are skipped."""
    fr = np.full(len(t), f)
    if bend:
        fr = fr * 2 ** (bend * np.exp(-t * 25) / 12)
    if vib:
        fr = fr * (1 + vib * np.sin(2 * np.pi * vib_hz * t) * np.clip((t - vib_delay) / 0.2, 0, 1))
    ph = 2 * np.pi * np.cumsum(fr) / SR + phase
    s = np.zeros(len(t))
    for k, a, d in partials:
        if k * f >= TOP:
            continue
        s += a * np.sin(k * ph) * (np.exp(-t * d) if d else 1)
    return s


def noise(n):
    return rng.standard_normal(n)


def highpass(x, a=0.9):
    return np.append(x[0], x[1:] - a * x[:-1])


def smooth(x):
    return np.convolve(x, [0.25, 0.5, 0.25], 'same')


# ════ instruments (n = MIDI note, dur = seconds) ════
def lead(n, dur, vol=0.17, bright=0.3):
    """Soft square-ish synth lead with a little detuned double and delayed vibrato."""
    dur = max(dur, 0.06)
    t = _t(dur)
    p = [(1, 1, 0), (2, 0.16, 0), (3, 0.28, 0), (4, 0.06, 0), (5, 0.12, 0), (7, 0.05, 0),
         (3, bright * 0.25, 7), (5, bright * 0.2, 9), (6, bright * 0.12, 12)]
    s = osc(hz(n), t, p, vib=0.005) + 0.5 * osc(hz(n) * 1.0035, t, p[:4], vib=0.005, phase=1.3)
    return s * gate(t, dur, 0.012, 0.05) * (1 + 0.35 * np.exp(-t * 18)) * vol


def bell(n, vol=0.12, length=1.3):
    t = _t(length)
    s = osc(hz(n), t, [(1, 1, 2.2), (2, 0.3, 4), (3, 0.08, 6), (4.2, 0.16, 8), (5.4, 0.07, 13)])
    return s * np.clip(t / 0.002, 0, 1) * vol


def glock(n, vol=0.1, length=1.0):
    t = _t(length)
    s = osc(hz(n), t, [(1, 1, 4.5), (2.76, 0.3, 10), (5.4, 0.1, 20)])
    return s * np.clip(t / 0.002, 0, 1) * vol


def chime(n, vol=0.08):
    """Pure, glassy kirakira tone."""
    t = _t(0.9)
    s = osc(hz(n), t, [(1, 1, 5), (2, 0.15, 9)])
    return s * np.clip(t / 0.002, 0, 1) * vol


def pluck(n, vol=0.12, length=0.34):
    """Synth pluck: saw whose upper partials die quickly (a closing filter)."""
    t = _t(length)
    s = osc(hz(n), t, [(k, 1 / k, 5 + 6 * k) for k in range(1, 11)])
    return s * np.clip(t / 0.002, 0, 1) * np.clip((length - t) / 0.04, 0, 1) * vol


def epiano(n, dur, vol=0.1):
    """FM electric piano with a slow tremolo."""
    t = _t(dur + 0.25)
    ph = 2 * np.pi * hz(n) * t
    idx = 1.1 * np.exp(-t * 3) + 0.15
    s = np.sin(ph + idx * np.sin(ph)) + 0.12 * np.sin(2 * ph) * np.exp(-t * 6)
    env = np.exp(-t * 1.3) * gate(t, dur + 0.25, 0.003, 0.25)
    return s * env * (1 + 0.12 * np.sin(2 * np.pi * 4.8 * t)) * vol


def toy(n, vol=0.14):
    """Toy piano: struck metal rods, slightly odd partials."""
    t = _t(0.9)
    s = osc(hz(n), t, [(1, 1, 4), (3.01, 0.22, 10), (5.98, 0.08, 22), (2.0, 0.12, 14)])
    return (s + highpass(noise(len(t))) * np.exp(-t * 400) * 0.08) * np.clip(t / 0.001, 0, 1) * vol


def marimba(n, vol=0.2):
    t = _t(0.6)
    s = osc(hz(n), t, [(1, 1, 7), (4, 0.25, 30), (10, 0.05, 60)])
    return s * np.clip(t / 0.003, 0, 1) * vol


def harpsi(n, dur, vol=0.1):
    """Harpsichord-ish: bright plucked partials, damped at note end."""
    length = dur + 0.08
    t = _t(length)
    s = osc(hz(n), t, [(k, abs(np.sin(np.pi * k * 0.18)) / k, 1.5 + 0.8 * k) for k in range(1, 15)])
    return s * np.clip(t / 0.0015, 0, 1) * np.clip((length - t) / 0.06, 0, 1) * vol


def brass(n, dur, vol=0.1):
    """Brassy synth stab: bright blat that mellows, a tiny scoop up."""
    dur = max(dur, 0.06)
    t = _t(dur)
    f = hz(n)
    fr = f * 2 ** (-0.4 * np.exp(-t * 30) / 12)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    bright = 0.35 + 0.65 * np.exp(-t * 6)
    s = np.zeros(len(t))
    for k in range(1, 11):
        if k * f >= TOP:
            break
        s += np.sin(k * ph) / k * (1 if k < 3 else bright)
    return s * gate(t, dur, 0.018, 0.06) * vol


def pad(ns, dur, vol=0.05):
    """Detuned saw-stack chord (supersaw-lite)."""
    t = _t(dur)
    s = np.zeros(len(t))
    for n in ns:
        for det in (-0.08, 0.0, 0.08):
            s += osc(hz(n + det), t, [(k, 1 / k ** 1.5, 0) for k in range(1, 13)], phase=rng.uniform(0, 6.28))
    return s * gate(t, dur, 0.06, 0.3) * vol


def bass(n, dur, vol=0.3):
    dur = max(dur, 0.05)
    t = _t(dur)
    s = osc(hz(n), t, [(1, 1, 0), (2, 0.5, 6), (3, 0.3, 10), (4, 0.18, 14), (5, 0.1, 18)])
    return s * np.exp(-t * 2) * gate(t, dur, 0.003, 0.03) * vol


def kick(vol=0.8):
    t = _t(0.32)
    f = 48 + 120 * np.exp(-t * 32)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    s += highpass(noise(len(t))) * np.exp(-t * 300) * 0.12
    return np.tanh(1.4 * s) * vol


def snare(vol=0.3):
    t = _t(0.2)
    s = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 22) * 0.6
    s += smooth(highpass(noise(len(t)), 0.7)) * np.exp(-t * 20)
    return s * vol


def clap(vol=0.3):
    t = _t(0.25)
    n = smooth(highpass(noise(len(t)), 0.8))
    env = sum(np.exp(-np.clip(t - o, 0, None) * 180) * (t >= o) for o in (0, 0.011, 0.022))
    env = env + 0.6 * np.exp(-np.clip(t - 0.03, 0, None) * 20) * (t >= 0.03)
    return n * env * vol * 0.6


def snap(vol=0.25):
    t = _t(0.08)
    s = smooth(highpass(noise(len(t)), 0.6)) * np.exp(-t * 90) + np.sin(2 * np.pi * 1600 * t) * np.exp(-t * 70) * 0.4
    return s * vol


def hat(vol=0.06, open_=False):
    t = _t(0.28 if open_ else 0.05)
    s = smooth(highpass(highpass(noise(len(t)), 0.95), 0.95))
    return s * np.exp(-t * (13 if open_ else 75)) * vol


def shaker(vol=0.04):
    t = _t(0.07)
    s = smooth(highpass(noise(len(t)), 0.95))
    return s * np.clip(t / 0.01, 0, 1) * np.exp(-t * 60) * vol


def crash(vol=0.07):
    t = _t(2.2)
    s = smooth(highpass(highpass(noise(len(t)), 0.9), 0.9))
    return s * np.exp(-t * 2.3) * np.clip(t / 0.003, 0, 1) * vol


def wood(vol=0.12):
    t = _t(0.08)
    return np.sin(2 * np.pi * 1200 * t) * np.exp(-t * 70) * vol


def reverb(x, taps=((0.029, 0.30), (0.047, 0.25), (0.071, 0.22), (0.097, 0.18), (0.131, 0.15),
                    (0.173, 0.11), (0.229, 0.08), (0.293, 0.06), (0.37, 0.04), (0.46, 0.025))):
    y = np.zeros_like(x)
    for d, g in taps:
        i = int(SR * d)
        y[i:] += x[:-i] * g
    return smooth(smooth(y))  # darker tail


# ════ notation ════
PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
QUAL = {'': (0, 4, 7), 'm': (0, 3, 7), '7': (0, 4, 7, 10), 'maj7': (0, 4, 7, 11), 'm7': (0, 3, 7, 10),
        'sus4': (0, 5, 7), 'add9': (0, 4, 7, 14), 'dim': (0, 3, 6), '6': (0, 4, 7, 9)}


def pitch_class(name):
    return (PC[name[0]] + name[1:].count('#') - name[1:].count('b')) % 12


def note(tok):
    """'C5' / 'F#4' / 'Bb5' / '74' → MIDI number."""
    if tok.lstrip('-').isdigit():
        return int(tok)
    m = re.fullmatch(r'([A-G][#b]?)(-?\d)', tok)
    return 12 * (int(m.group(2)) + 1) + pitch_class(m.group(1))


def melody(text):
    """'E5:2 G5:1 r:1 | ...' → [(note|None, eighths)]; each '|'-bar must be 8 eighths."""
    out = []
    for b, bar in enumerate(text.split('|')):
        tot = 0
        for tok in bar.split():
            n, d = tok.split(':')
            out.append((None if n == 'r' else note(n), float(d)))
            tot += float(d)
        assert tot == 8, f'bar {b + 1} has {tot} eighths: {bar}'
    return out


def voice(pcs, lo):
    return sorted(lo + (pc - lo) % 12 for pc in pcs)


class Song:
    def __init__(self, bpm, bars, key=0, swing=0.0, tail=3.0):
        self.e8 = 60 / bpm / 2
        self.bars = bars
        self.L = bars * 8 * self.e8
        self.key = key
        self.swing = swing
        n = int(SR * (self.L + tail))
        self.music = np.zeros(n)  # gets reverb
        self.pad = np.zeros(n)  # gets side-chain pump + reverb
        self.dry = np.zeros(n)  # kick and bass: no reverb

    def at(self, pos):
        """Position in eighths → seconds (with swing on the off-eighths)."""
        beat, u = divmod(pos, 2.0)
        s = self.swing
        if s:
            u = u * (1 + s) if u < 1 else (1 + s) + (u - 1) * (1 - s)
        return (beat * 2 + u) * self.e8

    def put(self, pos, sig, bus='music'):
        add(getattr(self, bus), self.at(pos), sig)

    def prog(self, text):
        """'F | G | Em7 Am7 | ...' → [(pos, eighths, pcs, bass_pc)], transposed by key."""
        out = []
        bars = text.split('|')
        assert len(bars) == self.bars, (len(bars), self.bars)
        for b, bar in enumerate(bars):
            syms = bar.split()
            ln = 8 / len(syms)
            for i, sym in enumerate(syms):
                sym, _, slash = sym.partition('/')
                m = re.fullmatch(r'([A-G][#b]?)(.*)', sym)
                root = (pitch_class(m.group(1)) + self.key) % 12
                pcs = [(root + iv) % 12 for iv in QUAL[m.group(2)]]
                bpc = (pitch_class(slash) + self.key) % 12 if slash else root
                out.append((b * 8 + i * ln, ln, pcs, bpc))
        return out

    def line(self, text, inst, shift=0, bus='music'):
        pos = 0
        for n, d in melody(text):
            if n is not None:
                self.put(pos, inst(n + self.key + shift, self.at(pos + d) - self.at(pos)), bus)
            pos += d
        assert pos == self.bars * 8, (pos, self.bars * 8)

    def pads(self, chords, vol=0.045, lo=55):
        for pos, ln, pcs, _ in chords:
            self.put(pos, pad(voice(pcs, lo), ln * self.e8 + 0.3, vol), 'pad')

    def arp(self, chords, inst, step=1.0, order=(0, 1, 2, 3, 4, 3, 2, 1), lo=64, bus='pad', vol=1.0):
        for pos, ln, pcs, _ in chords:
            tones = voice(pcs[:3], lo) + [x + 12 for x in voice(pcs[:3], lo)]
            k = 0
            p = pos
            while p < pos + ln - 1e-9:
                self.put(p, inst(tones[order[k % len(order)] % len(tones)]) * vol, bus)
                p += step
                k += 1

    def bassline(self, chords, vol=0.3, pattern='octave', lo=33):
        for pos, ln, _, bpc in chords:
            r = lo + (bpc - lo) % 12
            if pattern == 'octave':  # bouncy root / octave eighths
                for e in range(int(ln)):
                    self.put(pos + e, bass(r + (12 if e % 2 else 0), self.e8 * 0.85, vol * (0.8 if e % 2 else 1)), 'dry')
            elif pattern == 'offbeat':  # root on the beat, octave pops on the &
                for e in range(int(ln)):
                    self.put(pos + e, bass(r + (12 if e % 2 else 0), self.e8 * (1.6 if e % 2 == 0 else 0.6), vol * (1 if e % 2 == 0 else 0.6)), 'dry')
            elif pattern == 'oompah':  # root and fifth on beats 1 and 3
                for e in range(0, int(ln), 4):
                    self.put(pos + e, bass(r, self.e8 * 1.6, vol), 'dry')
                    self.put(pos + e + 2, bass(r + 7, self.e8 * 1.4, vol * 0.8), 'dry')
            elif pattern == 'staccato':
                for e in range(int(ln)):
                    if e in (0, 3, 4, 6):
                        self.put(pos + e, bass(r + (12 if e in (3, 6) else 0), self.e8 * 0.5, vol), 'dry')

    def drum(self, bar, steps, sound, bus='music'):
        """steps: 16 chars per bar (16ths); 'x' full, 'o' soft."""
        for i, c in enumerate(steps):
            if c in 'xo':
                sig = sound() * (1 if c == 'x' else 0.55)
                self.put(bar * 8 + i * 0.5, sig, bus)

    def kira(self, pos, vol=0.07, ivs=(0, 2, 4, 7, 9, 12, 14, 16), gap=0.045):
        """The little sparkle at a phrase end: a fast rising chime run."""
        pc = self.key % 12
        base = 84 + pc if pc < 6 else 72 + pc
        t0 = self.at(pos)
        for i, iv in enumerate(ivs):
            add(self.music, t0 + i * gap, chime(base + iv, vol * (1 - 0.05 * i)))

    def finish(self, name, pump=0.45, wet=0.3, rms=TARGET_RMS):
        t = np.arange(len(self.pad)) / SR
        tb = t % (2 * self.e8)
        g = 1 - pump * np.exp(-tb / 0.09) * np.clip(tb / 0.006, 0, 1)
        bus = self.music + self.pad * g
        mix = self.dry + bus + wet * reverb(bus)
        n = int(round(SR * self.L))
        loop = mix[:n].copy()
        tail = mix[n:]
        while len(tail):  # fold everything past the loop point back onto the start → seamless
            k = min(n, len(tail))
            loop[:k] += tail[:k]
            tail = tail[k:]
        loop *= rms / np.sqrt(np.mean(loop ** 2))
        loop = 0.95 * np.tanh(loop / 0.95)  # gentle soft limit for the drum peaks
        data = np.round(loop * 32767).astype(np.int16)
        with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        print(f'{name:14s} {self.L:5.1f}s {(OUT / f"{name}.wav").stat().st_size // 1024:5d} KB')


FOUR = 'x...x...x...x...'
TWO_FOUR = '....x.......x...'
OFFHAT = '..x...x...x...x.'
ROLL = '............xxxx'


def title():
    s = Song(120, 16, key=2)
    ch = s.prog('F | G | Em | Am | F | G | C | C | F | G | Em | Am | Dm | Em | F | G')
    tune = '''
    A4:1 C5:1 F5:1 E5:1 F5:2 G5:2 | G5:3 A5:1 G5:1 F5:1 E5:1 D5:1 | E5:2 B4:1 E5:1 G5:2 A5:1 G5:1 | E5:4 r:2 C5:1 D5:1 |
    E5:1 F5:1 A5:2 A5:1 G5:1 F5:1 G5:1 | G5:2 D5:1 G5:1 B5:2 A5:1 G5:1 | C6:2 B5:1 G5:1 A5:1 G5:1 E5:1 D5:1 | C5:4 r:4 |
    C6:2 A5:1 G5:1 A5:2 C6:2 | B5:2 G5:1 D5:1 G5:2 A5:1 B5:1 | B5:1 C6:1 B5:1 G5:1 E5:2 G5:1 A5:1 | A5:4 r:2 E5:1 G5:1 |
    A5:2 F5:1 E5:1 D5:2 F5:1 A5:1 | G5:2 E5:1 D5:1 B4:2 E5:1 G5:1 | A5:1 G5:1 F5:1 E5:1 F5:2 A5:2 | B4:1 D5:1 G5:4 r:2'''
    s.line(tune, lambda n, d: lead(n, d * 0.92, 0.16))
    b_half = tune.split('|')
    s.line('|'.join(['r:8'] * 8 + b_half[8:]), lambda n, d: glock(n, 0.05))
    s.pads(ch, 0.04)
    s.arp(ch[:8], lambda n: pluck(n, 0.09), step=1.0)
    s.arp(ch[8:], lambda n: pluck(n, 0.08), step=0.5)
    s.bassline(ch, 0.28)
    for b in range(16):
        s.drum(b, FOUR, lambda: kick(0.8), 'dry')
        s.drum(b, TWO_FOUR, lambda: clap(0.3))
        s.drum(b, OFFHAT, lambda: hat(0.05, True))
        if b >= 8:
            s.drum(b, 'o.o.o.o.o.o.o.o.', lambda: hat(0.035))
    s.put(0, crash(0.05))
    s.put(64, crash(0.06))
    for pos in (28, 60, 92, 124):
        s.kira(pos + 4, 0.06 if pos in (60, 124) else 0.04)
    s.finish('bgm_title', pump=0.4)


def select():
    s = Song(110, 8, key=-5)
    ch = s.prog('C | G | Am | F | C | G | F | G')
    tune = '''
    E5:2 G5:1 E5:1 r:2 D5:1 C5:1 | D5:2 G4:2 r:4 | C5:2 E5:1 C5:1 r:2 B4:1 A4:1 | C5:4 r:4 |
    E5:2 G5:1 A5:1 G5:2 E5:1 G5:1 | B5:2 G5:1 D5:1 r:4 | A5:2 G5:1 F5:1 E5:2 D5:1 C5:1 | D5:4 r:4'''
    s.line(tune, lambda n, d: mix(marimba(n, 0.2), bell(n + 12, 0.025, 0.8)))
    s.pads(ch, 0.025)
    s.arp(ch, lambda n: pluck(n, 0.06), step=2.0, order=(0, 2, 1, 2))
    s.bassline(ch, 0.24, 'offbeat')
    for b in range(8):
        s.drum(b, 'x.......x.......', lambda: kick(0.6), 'dry')
        s.drum(b, TWO_FOUR, lambda: snap(0.16))
        s.drum(b, OFFHAT, lambda: hat(0.03, True))
        s.drum(b, 'oooooooooooooooo', lambda: shaker(0.025))
        s.drum(b, '......x.......x.', lambda: wood(0.05))
    s.kira(28 + 4, 0.04)
    s.kira(60 + 4, 0.05)
    s.finish('bgm_select', pump=0.25, rms=0.10)


def pripare():
    s = Song(128, 16, key=4)
    ch = s.prog('C | G | Am | Em | F | C | F | G | F | G | Em | Am | F | G | C | G')
    tune = '''
    G4:1 C5:1 E5:1 G5:2 E5:1 D5:1 C5:1 | D5:2 B4:1 D5:2 G5:2 r:1 | A4:1 C5:1 E5:1 A5:2 G5:1 E5:1 C5:1 | B4:3 G4:1 B4:2 r:2 |
    A4:1 C5:1 F5:1 A5:2 G5:1 F5:1 E5:1 | E5:2 G5:1 E5:2 C5:2 r:1 | F5:1 E5:1 F5:1 G5:2 A5:1 G5:1 F5:1 | G5:4 r:2 G5:1 A5:1 |
    C6:2 A5:1 G5:2 F5:1 G5:1 A5:1 | G5:2 D5:1 G5:2 A5:1 B5:2 | B5:1 C6:1 B5:1 A5:1 G5:2 E5:1 G5:1 | A5:3 E5:1 A5:2 B5:1 C6:1 |
    C6:2 A5:1 C6:2 A5:1 G5:1 F5:1 | G5:2 F5:1 E5:1 D5:2 E5:1 F5:1 | E5:1 G5:1 C6:3 B5:1 A5:1 G5:1 | G5:4 r:4'''
    s.line(tune, lambda n, d: lead(n, d * 0.85, 0.15, bright=0.4))
    s.line('|'.join(['r:8'] * 8 + tune.split('|')[8:]), lambda n, d: bell(n, 0.04, 0.7))
    s.pads(ch, 0.042)
    s.arp(ch[:8], lambda n: pluck(n, 0.085), step=1.0, order=(0, 2, 1, 3, 2, 4, 3, 1))
    s.arp(ch[8:], lambda n: pluck(n, 0.075), step=0.5)
    s.bassline(ch, 0.3)
    for b in range(16):
        chorus = b >= 8
        s.drum(b, FOUR, lambda: kick(0.85), 'dry')
        s.drum(b, '....x.......x.o.' if chorus else TWO_FOUR, lambda: clap(0.32))
        s.drum(b, OFFHAT, lambda: hat(0.05, True))
        if chorus:
            s.drum(b, 'o.o.o.o.o.o.o.o.', lambda: hat(0.035))
        if b in (7, 15):
            s.drum(b, ROLL, lambda: snare(0.2))
    s.put(0, crash(0.05))
    s.put(64, crash(0.07))
    s.kira(28 + 4, 0.04)
    s.kira(60 + 4, 0.06)
    s.kira(124 + 4, 0.06)
    s.finish('bgm_pripare', pump=0.5)


def shizumomo():
    s = Song(118, 12, key=-3, tail=4)
    ch = s.prog('Fmaj7 | G | Em7 | Am7 | Fmaj7 | G | Em7 A7 | Dm7 | Fmaj7 | G | Em7 Am7 | Dm7 G')
    tune = '''
    A5:3 G5:1 E5:2 C5:2 | D5:3 E5:1 G5:4 | G5:2 B5:2 A5:1 G5:1 E5:1 D5:1 | E5:6 r:2 |
    A5:3 G5:1 E5:2 A5:1 C6:1 | B5:3 A5:1 G5:2 D5:2 | G5:2 B5:2 A5:3 G5:1 | A5:4 F5:2 E5:1 D5:1 |
    E5:2 F5:2 A5:2 C6:2 | B5:3 D6:1 B5:2 G5:2 | G5:2 B5:2 C6:3 B5:1 | A5:2 F5:2 G5:4'''
    s.line(tune, lambda n, d: bell(n, 0.13, 1.4))
    s.line(tune, lambda n, d: lead(n, d * 0.95, 0.05, bright=0.0))
    s.pads(ch, 0.032, lo=57)
    for pos, ln, pcs, _ in ch:  # syncopated e-piano comping
        v = voice(pcs, 60)
        for off, d in ((0, 1.5), (3, 1.0), (6, 1.5)):
            if off < ln:
                for k, n in enumerate(v):
                    s.put(pos + off, epiano(n, d * s.e8, 0.05), 'music')
    s.arp(ch, lambda n: pluck(n + 12, 0.035, 0.25), step=0.5, order=(0, 1, 2, 4, 3, 2, 1, 2))
    s.bassline(ch, 0.26, 'offbeat')
    for b in range(12):
        s.drum(b, FOUR, lambda: kick(0.65), 'dry')
        s.drum(b, TWO_FOUR, lambda: clap(0.22))
        s.drum(b, OFFHAT, lambda: hat(0.035, True))
        s.drum(b, 'oooooooooooooooo', lambda: shaker(0.02))
    s.put(0, crash(0.04))
    for pos in (28, 60, 92):
        s.kira(pos + 4, 0.05)
    s.finish('bgm_shizumomo', pump=0.35, wet=0.45)


def koharu():
    s = Song(100, 12, key=-7, swing=1 / 3)
    ch = s.prog('C | Am | F | G | C | Am | Dm | G | F | G | Em A7 | Dm G')
    tune = '''
    E5:1 G5:1 E5:1 C5:1 D5:2 E5:2 | C5:1 E5:1 A5:2 G5:2 E5:2 | F5:1 A5:1 G5:1 F5:1 E5:2 D5:2 | D5:2 G4:2 B4:2 D5:2 |
    E5:1 G5:1 E5:1 C5:1 D5:2 E5:2 | C5:1 E5:1 A5:2 B5:2 C6:2 | A5:1 G5:1 F5:1 E5:1 D5:2 F5:2 | G5:4 r:4 |
    A5:2 C6:2 A5:1 G5:1 F5:2 | G5:2 B5:2 G5:1 F5:1 D5:2 | E5:1 G5:1 B5:2 A5:2 G5:2 | F5:2 A5:1 F5:1 D5:2 B4:1 D5:1'''
    s.line(tune, lambda n, d: mix(toy(n + 12, 0.13), marimba(n, 0.07)))
    s.pads(ch, 0.018, lo=57)
    for pos, ln, pcs, _ in ch:  # marimba chords on the swung offbeats
        v = voice(pcs[:3], 62)
        for off in (1, 3, 5, 7):
            if off < ln:
                for n in v:
                    s.put(pos + off, marimba(n, 0.055))
    s.bassline(ch, 0.3, 'oompah', lo=36)
    for b in range(12):
        s.drum(b, 'x.......x.......', lambda: kick(0.55), 'dry')
        s.drum(b, TWO_FOUR, lambda: snap(0.18))
        for e in range(8):  # swung shaker
            s.put(b * 8 + e, shaker(0.04 if e % 2 else 0.025))
        s.put(b * 8 + 7, wood(0.06))
    for pos in (28, 60, 92):
        s.kira(pos + 4, 0.05)
    s.finish('bgm_koharu', pump=0.15, wet=0.3)


def hinata():
    s = Song(140, 16, key=0)
    ch = s.prog('C | G | Am | F | C | G | F | G | F | G | Em | Am | Dm | Em | F | G')
    tune = '''
    C5:1 E5:1 G5:1 C6:1 r:1 G5:1 A5:1 G5:1 | D5:1 G5:1 B5:2 A5:1 G5:1 D5:2 | C5:1 E5:1 A5:1 C6:1 r:1 B5:1 A5:1 G5:1 | A5:2 F5:1 C5:1 F5:2 G5:2 |
    E5:1 G5:1 C6:2 B5:1 C6:1 D6:2 | D6:2 B5:1 G5:1 B5:2 D6:2 | C6:1 A5:1 F5:1 A5:1 G5:1 F5:1 E5:1 F5:1 | G5:4 r:2 G5:1 G5:1 |
    A5:2 C6:2 A5:1 G5:1 A5:1 C6:1 | D6:2 B5:2 G5:2 A5:1 B5:1 | B5:2 G5:1 E5:1 B4:2 E5:1 G5:1 | A5:3 B5:1 C6:2 E5:2 |
    F5:1 A5:1 D6:2 C6:1 A5:1 F5:2 | E5:1 G5:1 B5:2 A5:1 G5:1 E5:2 | F5:1 A5:1 C6:2 D6:1 C6:1 A5:2 | D5:1 G5:1 B5:1 D6:3 r:2'''
    s.line(tune, lambda n, d: lead(n, d * 0.85, 0.15, bright=0.5))
    s.pads(ch, 0.045)
    s.arp(ch, lambda n: pluck(n, 0.075), step=0.5, order=(0, 1, 2, 3, 4, 3, 2, 1))
    s.bassline(ch, 0.3)
    for pos, ln, pcs, _ in ch[8:]:  # brass stabs in the chorus: da — da-da
        v = voice(pcs[:3], 60)
        for off, d in ((0, 1.2), (3, 0.8), (6, 0.8)):
            for n in v:
                s.put(pos + off, brass(n, d * s.e8, 0.035))
    for b in range(16):
        s.drum(b, FOUR, lambda: kick(0.9), 'dry')
        s.drum(b, TWO_FOUR, lambda: clap(0.3))
        s.drum(b, TWO_FOUR, lambda: snare(0.18))
        s.drum(b, OFFHAT, lambda: hat(0.05, True))
        s.drum(b, 'o.o.o.o.o.o.o.o.'.replace('.', 'o') if b >= 8 else 'o.o.o.o.o.o.o.o.', lambda: hat(0.03))
        if b in (7, 15):  # "hai! hai!" chant claps
            s.drum(b, '........x.x.x.x.', lambda: clap(0.3))
        if b == 15:
            s.drum(b, '........oooxxxxx', lambda: snare(0.2))
    s.put(0, crash(0.06))
    s.put(64, crash(0.07))
    s.kira(60 + 4, 0.06)
    s.kira(124 + 4, 0.06)
    s.finish('bgm_hinata', pump=0.55)


def yoru():
    s = Song(112, 12, key=-7, tail=4)
    ch = s.prog('Am | F | Dm | E7 | Am | F | Dm | E7 | F | G | E7 Am | Dm E7')
    tune = '''
    E5:1 r:1 E5:1 F5:1 E5:1 r:1 C5:1 A4:1 | F5:1 r:1 F5:1 G5:1 A5:2 F5:2 | D5:1 F5:1 A5:1 G#5:1 A5:2 F5:1 D5:1 | E5:2 G#5:2 B5:2 r:2 |
    C6:1 r:1 B5:1 A5:1 G#5:1 A5:1 E5:2 | F5:1 A5:1 C6:1 A5:1 F5:2 r:2 | D5:1 E5:1 F5:1 G#5:1 A5:2 D6:2 | B5:3 A5:1 G#5:4 |
    A5:1 r:1 C6:1 r:1 A5:1 G5:1 F5:2 | G5:1 r:1 B5:1 r:1 G5:1 F5:1 D5:2 | E5:1 G#5:1 B5:1 D6:1 C6:2 A5:2 | F5:1 A5:1 G#5:1 F5:1 E5:4'''
    s.line(tune, lambda n, d: lead(n, min(d, 0.25 + d * 0.5), 0.14, bright=0.2))
    s.line(tune, lambda n, d: glock(n + 12, 0.03, 0.6))
    s.pads(ch, 0.028, lo=50)
    s.arp(ch, lambda n: harpsi(n, s.e8 * 0.9, 0.07), step=1.0, order=(0, 2, 1, 2, 0, 2, 1, 2), lo=57, bus='music')
    s.bassline(ch, 0.3, 'staccato')
    for b in range(12):
        s.drum(b, 'x.......x.x.....', lambda: kick(0.7), 'dry')
        s.drum(b, TWO_FOUR, lambda: snap(0.2))
        s.drum(b, 'o.o.o.o.o.o.o.o.', lambda: hat(0.03))
        s.drum(b, '..............x.', lambda: hat(0.04, True))
        s.drum(b, '...x.......x....' if b % 2 else '', lambda: wood(0.06))
    minor_run = (0, 3, 7, 10, 12, 15, 19, 22)  # spooky-cute: a minor-seventh sparkle
    for pos in (28, 60, 92):
        s.kira(pos + 4, 0.045, ivs=minor_run)
    s.finish('bgm_yoru', pump=0.3, wet=0.4)


def premium():
    s = Song(132, 16, key=-2)
    ch = s.prog('C | G/B | Am | Em/G | F | C/E | Dm | G | F | G | Em | Am | Dm | G | C | G')
    tune = '''
    G4:1 C5:1 E5:1 G5:3 E5:1 G5:1 | B5:3 A5:1 G5:2 D5:2 | E5:1 A5:1 C6:3 B5:1 A5:2 | G5:3 E5:1 B4:2 r:2 |
    A4:1 C5:1 F5:1 A5:3 G5:1 F5:1 | G5:3 E5:1 C5:2 E5:2 | F5:1 E5:1 D5:1 F5:1 A5:2 C6:2 | B5:4 r:4 |
    C6:3 A5:1 F5:2 A5:2 | B5:3 G5:1 D5:2 G5:2 | B5:2 C6:1 B5:1 G5:2 E5:2 | A5:4 E5:2 A5:1 B5:1 |
    C6:3 A5:1 F5:2 D6:2 | D6:3 B5:1 G5:2 B5:2 | C6:4 B5:1 C6:1 D6:2 | G5:4 r:4'''
    s.line(tune, lambda n, d: lead(n, d * 0.9, 0.14, bright=0.4))
    s.line('|'.join(['r:8'] * 8 + tune.split('|')[8:]), lambda n, d: brass(n - 12, d * 0.9, 0.06))
    s.pads(ch, 0.042)
    for pos, ln, pcs, _ in ch:  # brass stabs: daan — da-dan
        v = voice(pcs[:3], 58)
        for off, d in ((0, 1.5), (3, 1.0), (6, 1.0)):
            for n in v:
                s.put(pos + off, brass(n, d * s.e8, 0.03))
    s.arp(ch, lambda n: glock(n + 12, 0.045, 0.7), step=0.5, order=(0, 1, 2, 3, 4, 5, 4, 3), lo=60, bus='music')
    s.bassline(ch, 0.3)
    for b in range(16):
        s.drum(b, FOUR, lambda: kick(0.9), 'dry')
        s.drum(b, TWO_FOUR, lambda: clap(0.3))
        s.drum(b, TWO_FOUR, lambda: snare(0.16))
        s.drum(b, OFFHAT, lambda: hat(0.05, True))
        s.drum(b, 'o.o.o.o.o.o.o.o.', lambda: hat(0.03))
        if b in (7, 15):
            s.drum(b, '........ooooxxxx', lambda: snare(0.2))
    s.put(0, crash(0.07))
    s.put(64, crash(0.07))
    s.kira(28 + 4, 0.05)
    s.kira(60 + 4, 0.07, gap=0.035)
    s.kira(92 + 4, 0.05)
    s.kira(124 + 4, 0.07, gap=0.035)
    s.finish('bgm_premium', pump=0.45)


if __name__ == '__main__':
    t0 = time.time()
    for fn in (title, select, pripare, shizumomo, koharu, hinata, yoru, premium):
        fn()
    print(f'done in {time.time() - t0:.1f}s')
