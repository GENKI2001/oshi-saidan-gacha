"""The girls sing the songs themselves: each take's vocal is split off, sung again
in the members' own voices (the voices of the game, voice/render), and mixed
back over the backing track.

Steps (see art/songs/README.md):
  1. ~/tools/svc/work/convert_all.sh          demucs (htdemucs_ft) + Seed-VC singing conversion per member
  2. <Irodori venv python> art/songs/sing.py align TRACK...   where each sung line is (Whisper) → work/align/TRACK.json
  3. <Seed-VC venv python> art/songs/sing.py mix TRACK...     arrange the voices, mix → work/mixed/TRACK.wav
  4. python3 art/songs/finalize.py TRACK=~/tools/svc/work/mixed/TRACK.wav

Arranging: a solo song is sung by its member. In a duet or a unit song the
lines of the verses go round the members one at a time, and every chorus line
is sung by all of them together (panned apart, a few ms off each other, like a
real group).
"""
import json
import re
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
WORK = Path.home() / 'tools' / 'svc' / 'work'
SR = 44100

# track → (take, singers in the order their solo lines come round).
# bgm_title and bgm_shizumomo keep their original ACE-Step vocals (liked as they are);
# they get the members harmonising over them instead (harmony.py).
CAST = {
    'bgm_hinata': ('s11', ['hinata']),
    'bgm_koharu': ('s12', ['koharu']),
    'bgm_yoru': ('s12', ['yoru']),
    'bgm_select': ('s11', ['hinata', 'shizuku', 'koharu', 'yoru', 'momo']),
    'bgm_premium': ('s11', ['hinata', 'shizuku', 'koharu', 'yoru', 'momo']),
}
# where each voice sits in a group line (left -1 … right 1) and how late it comes in (ms)
PAN = {'hinata': 0.0, 'shizuku': -0.55, 'koharu': 0.3, 'yoru': -0.25, 'momo': 0.55}
LATE = {'hinata': 0, 'shizuku': 9, 'koharu': 4, 'yoru': 14, 'momo': 7}


def stem_dir(track):
    take, _ = CAST[track]
    return WORK / 'sep' / 'htdemucs_ft' / f'{track}__acestep-v15-turbo__{take}'


# ── 2. align ──
def align(track):
    import mlx_whisper
    r = mlx_whisper.transcribe(str(stem_dir(track) / 'vocals.wav'), path_or_hf_repo='mlx-community/whisper-large-v3-turbo', language='ja', condition_on_previous_text=False)
    segs = [{'start': s['start'], 'end': s['end'], 'text': s['text']} for s in r['segments'] if 'ご視聴' not in s['text']]
    (WORK / 'align').mkdir(exist_ok=True)
    (WORK / 'align' / f'{track}.json').write_text(json.dumps(segs, ensure_ascii=False, indent=1))
    print(track, len(segs), 'lines')


# ── 3. mix ──
def norm(s):
    s = unicodedata.normalize('NFKC', s)
    s = ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in s)  # katakana → hiragana
    return re.sub(r'[\s、。！？!?☆★・〜ー…「」]', '', s)


def lyric_lines(track):
    sys.path.insert(0, str(HERE))
    from songs import SONGS
    out, sec = [], ''
    for line in SONGS[track]['lyrics'].splitlines():
        line = line.strip()
        if line.startswith('['):
            sec = line.strip('[]').lower()
        elif line:
            out.append((sec, norm(line)))
    return out


def label(text, lines):
    """'group' for a chorus or outro line, 'solo' for the rest, None when Whisper heard nonsense."""
    t = norm(text)
    if not t:
        return None
    best = max(lines, key=lambda l: SequenceMatcher(None, t, l[1]).ratio())
    if SequenceMatcher(None, t, best[1]).ratio() < 0.35:
        return None
    sec = best[0]
    return 'group' if ('chorus' in sec and 'pre' not in sec) or 'outro' in sec else 'solo'


def plan(segs, lines):
    """Lines as (start, end, 'group' | 'solo'). A long stretch Whisper could not read
    (it hallucinates over intros) is sung in 4-second turns."""
    out = []
    for s in segs:
        lab = label(s['text'], lines)
        if lab is None and s['end'] - s['start'] > 6:
            t = s['start']
            while t < s['end'] - 0.5:
                out.append((t, min(t + 4, s['end']), 'solo'))
                t += 4
        else:
            out.append((s['start'], s['end'], lab or 'solo'))
    return out


def load(path):
    import soundfile as sf
    import librosa
    y, sr = sf.read(path, always_2d=True)
    if sr != SR:
        y = librosa.resample(y.T, orig_sr=sr, target_sr=SR).T
    return y


def fit(y, n):
    return y[:n] if len(y) >= n else np.concatenate([y, np.zeros((n - len(y),) + y.shape[1:])])


def smooth(x, ms):
    k = max(1, int(SR * ms / 1000))
    c = np.cumsum(np.concatenate([[0], x]))
    out = (c[k:] - c[:-k]) / k
    return np.concatenate([out, np.full(k - 1, out[-1])])


def reverb(x, secs=1.1, wet=0.16):
    """A soft hall: exponentially decaying noise as the impulse response."""
    from scipy.signal import fftconvolve
    rng = np.random.default_rng(3)
    n = int(SR * secs)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * secs / 6))
    ir[: int(SR * 0.02)] = 0  # a short pre-delay
    ir /= np.sqrt((ir ** 2).sum())
    return x + wet * np.stack([fftconvolve(x[:, c], ir)[: len(x)] for c in range(x.shape[1])], 1)


def mix(track):
    import soundfile as sf
    _, singers = CAST[track]
    orig = load(stem_dir(track) / 'vocals.wav')
    back = load(stem_dir(track) / 'no_vocals.wav')
    n = len(back)
    orig = fit(orig, n)
    conv = {who: fit(load(WORK / 'conv' / track / f'{who}.wav').mean(1), n) for who in singers}

    # who sings when: per-sample weights, ramped at the joins
    w = {who: np.zeros(n) for who in singers}
    segs = json.loads((WORK / 'align' / f'{track}.json').read_text()) if len(singers) > 1 else []
    if len(singers) == 1 or not segs:
        w[singers[0]][:] = 1
    else:
        parts = plan(segs, lyric_lines(track))
        k = 0
        bounds = [0] + [int(SR * (a[1] + b[0]) / 2) for a, b in zip(parts, parts[1:])] + [n]
        for i, part in enumerate(parts):
            a, b = bounds[i], bounds[i + 1]
            if part[2] == 'group':
                for who in singers:
                    w[who][a:b] = 1
            else:
                w[singers[k % len(singers)]][a:b] = 1
                k += 1
        for who in singers:
            w[who] = smooth(w[who], 60)

    # gate: only where the original singer was singing (the conversion hums in the gaps)
    env = smooth(np.abs(orig.mean(1)), 25)
    db = 20 * np.log10(env + 1e-9)
    gate = smooth(np.clip((db - (db.max() - 38)) / 8, 0, 1), 30)

    # a line sung by several at once is quieter per voice, so it doesn't jump out
    count = sum(w.values())
    out = np.zeros((n, 2))
    for who in singers:
        late = int(SR * LATE[who] / 1000) if len(singers) > 1 else 0
        v = np.roll(conv[who], late) * w[who] / np.sqrt(np.maximum(count, 1))
        pan = PAN[who] if len(singers) > 1 else 0.0
        out[:, 0] += v * np.sqrt((1 - pan) / 2) * np.sqrt(2)
        out[:, 1] += v * np.sqrt((1 + pan) / 2) * np.sqrt(2)
    out *= gate[:, None]
    # as loud as the original vocal where it sings
    act = gate > 0.5
    out *= np.sqrt((orig[act] ** 2).mean() / max((out[act] ** 2).mean(), 1e-12))
    out = reverb(out)
    song = back + out
    song /= max(1.0, np.abs(song).max() / 0.95)
    (WORK / 'mixed').mkdir(exist_ok=True)
    sf.write(WORK / 'mixed' / f'{track}.wav', song, SR)
    print(track, f'{n / SR:.1f}s', 'singers', singers)


if __name__ == '__main__':
    cmd, tracks = sys.argv[1], sys.argv[2:] or list(CAST)
    for t in tracks:
        {'align': align, 'mix': mix}[cmd](t)
