"""Compare takes of one song on what was asked of it (run with the Irodori venv: mlx_whisper + librosa).

  <Irodori venv python> art/songs/pick.py bgm_pripare 41 42 ...
Needs each take's vocal split first (~/tools/svc/work/sep/htdemucs_ft/<take>/vocals.wav).

- かんせい: is 歓声 sung (and heard) as kansei
- 汗も/涙も: how far apart the two are in pitch (semitones; the ask was the same note)
- lift: how much louder the choruses are than the verses (dB, the full mix)
- cov: how much of the lyric Whisper heard
"""
import re
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

import librosa
import mlx_whisper
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from songs import SONGS  # noqa: E402

WORK = Path.home() / 'tools' / 'svc' / 'work'
OUT = Path.home() / 'tools' / 'songgen' / 'out_turbo'


def kana(s):
    s = unicodedata.normalize('NFKC', s)
    s = ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in s)
    return re.sub(r'[^ぁ-ゖ一-龯]', '', s)


def main(track, seeds):
    lyric = kana(re.sub(r'\[.*?\]|（.*?）', '', SONGS[track]['lyrics']))
    for seed in seeds:
        stem = f'{track}__acestep-v15-turbo__s{seed}'
        voc = WORK / 'sep' / 'htdemucs_ft' / stem / 'vocals.wav'
        r = mlx_whisper.transcribe(str(voc), path_or_hf_repo='mlx-community/whisper-large-v3-turbo', language='ja',
                                   condition_on_previous_text=False, word_timestamps=True)
        text = ''.join(s['text'] for s in r['segments'])
        words = [w for s in r['segments'] for w in s.get('words', [])]
        kansei = '歓声' in text or 'かんせい' in kana(text) or 'カンセイ' in text
        # pitch of 汗も and 涙も
        y, sr = librosa.load(voc, sr=22050, mono=True)

        def pitch(pat):
            for w in words:
                if re.search(pat, w['word']):
                    a, b = int(w['start'] * sr), int(w['end'] * sr)
                    f0, _, _ = librosa.pyin(y[a:b], fmin=150, fmax=1200, sr=sr)
                    f0 = f0[~np.isnan(f0)]
                    if len(f0):
                        return 12 * np.log2(np.median(f0) / 440) + 69
            return None
        p1, p2 = pitch(r'汗|あせ|アセ'), pitch(r'涙|なみだ|ナミダ')
        gap = None if p1 is None or p2 is None else abs(p1 - p2)
        # choruses vs verses on the full mix, by where the chorus lines were heard
        mix, _ = librosa.load(OUT / f'{stem}.wav', sr=22050, mono=True)
        rms = librosa.feature.rms(y=mix, hop_length=512)[0]
        t = librosa.frames_to_time(np.arange(len(rms)), sr=22050, hop_length=512)
        ch, vs = [], []
        for s in r['segments']:
            k = kana(s['text'])
            m = (t >= s['start']) & (t < s['end'])
            (ch if ('限界' in s['text'] or 'げんかい' in k or 'ヒート' in s['text']) else vs).append(rms[m])
        lift = None
        if ch and vs:
            lift = 20 * np.log10(np.concatenate(ch).mean() / np.concatenate(vs).mean())
        cov = SequenceMatcher(None, lyric, kana(text), autojunk=False).ratio()
        print(f"s{seed}  かんせい={'○' if kansei else '×'}  汗も/涙も={'?' if gap is None else f'{gap:.1f}'}半音  "
              f"lift={'?' if lift is None else f'{lift:+.1f}'}dB  cov={cov:.2f}  | {text[:70]}", flush=True)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])
