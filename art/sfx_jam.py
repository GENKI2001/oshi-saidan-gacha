"""Sounds for the 妨害 (the scalper barging in) -> assets/sfx/*.wav.

  python3 art/sfx_jam.py
Kept apart from art/sfx.py so the other sounds are not rebuilt; uses its primitives.
"""
import numpy as np

from sfx import SR, t, mix, lp, hp, bp, noise, adsr, expenv, osc, reverb, save, brass, glock, note, taiko, koto, plastic


def siren(d=1.6, lo=620, hi=1180, rate=2.2):
    """A wailing two-tone siren: the pitch sweeps up and down."""
    tt = t(d)
    f = lo + (hi - lo) * (0.5 - 0.5 * np.cos(2 * np.pi * rate * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(ph)) * 0.35 + np.sin(ph) * 0.5 + np.sin(2 * ph) * 0.15
    x = lp(x, 4200) * adsr(len(tt), 0.04, 0.1, 1.0, 0.25)
    return x


def push(seed):
    """One shove when まもれ！ is tapped: a soft thump with a little cloth swish."""
    r = np.random.default_rng(seed)
    thump = osc(170 + r.uniform(-20, 20), 0.12, 70) * expenv(int(SR * 0.12), 28)
    swish = bp(noise(0.08), 900, 3500) * expenv(int(SR * 0.08), 40) * 0.5
    return mix([(0, thump), (0.005, swish)])


def main():
    save('siren', reverb(siren(), 0.5, 0.18), 0.6)
    save('push', push(3), 0.7)
    # fended off: a bright fanfare; he got away: a sad little slide down
    save('jam_win', reverb(mix([(i * 0.08, brass(n, 0.14)) for i, n in enumerate([72, 76, 79])]
                               + [(0.26, brass(84, 0.7) + brass(79, 0.7))]
                               + [(0.3 + i * 0.04, glock(note(96 + k), 0.4) * 0.3) for i, k in enumerate([0, 4, 7, 12])]), 0.8, 0.3), 0.7)
    save('jam_lose', reverb(mix([(i * 0.18, koto(note(n), 0.6 if i < 2 else 1.4, 0.4)) for i, n in enumerate([71, 67, 62])]
                                + [(0, taiko(80, 0.7) * 0.6)]), 0.8, 0.3), 0.6)


if __name__ == '__main__':
    main()
