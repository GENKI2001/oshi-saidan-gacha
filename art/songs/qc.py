"""QC for generated songs: Whisper transcript vs lyrics (kana similarity), loudness, peak, silence.

  ~/tools/songgen/qc/bin/python art/songs/qc.py ~/tools/songgen/out/*.wav
"""
import difflib
import json
import os
import re
import sys

import numpy as np
import pykakasi
import pyloudnorm as pyln
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from songs import SONGS  # noqa: E402

KKS = pykakasi.kakasi()


def kana(s):
    s = re.sub(r"\[.*?\]", "", s)
    s = "".join(x["hira"] for x in KKS.convert(s))
    return re.sub(r"[^ぁ-ゟー]", "", s)


def lyric_cov(lyr_k, tr_k):
    """Fraction of lyric kana matched (in order) by transcript."""
    sm = difflib.SequenceMatcher(None, lyr_k, tr_k, autojunk=False)
    return sum(b.size for b in sm.get_matching_blocks()) / max(1, len(lyr_k))


def silence_stats(x, sr, thr_db=-45.0, win=0.05):
    mono = x.mean(axis=1) if x.ndim > 1 else x
    n = int(sr * win)
    frames = mono[: len(mono) // n * n].reshape(-1, n)
    rms = 20 * np.log10(np.sqrt((frames ** 2).mean(axis=1)) + 1e-9)
    quiet = rms < thr_db
    longest = cur = 0
    for q in quiet:
        cur = cur + 1 if q else 0
        longest = max(longest, cur)
    lead = int(np.argmax(~quiet)) if (~quiet).any() else len(quiet)
    return longest * win, lead * win


def main(paths):
    import mlx_whisper
    rows = []
    for p in paths:
        name = os.path.basename(p).split("__")[0]
        x, sr = sf.read(p, always_2d=True)
        lufs = pyln.Meter(sr).integrated_loudness(x)
        peak = 20 * np.log10(np.abs(x).max() + 1e-9)
        longest_sil, lead = silence_stats(x, sr)
        r = mlx_whisper.transcribe(p, path_or_hf_repo="mlx-community/whisper-large-v3-turbo",
                                   language="ja", condition_on_previous_text=False)
        text = "".join(seg["text"] for seg in r["segments"])
        cov = lyric_cov(kana(SONGS[name]["lyrics"]), kana(text)) if name in SONGS else None
        row = dict(file=os.path.basename(p), dur=round(len(x) / sr, 1), lufs=round(lufs, 1),
                   peak_db=round(peak, 2), longest_silence=round(longest_sil, 2),
                   lead_silence=round(lead, 2), lyric_cov=round(cov, 3) if cov is not None else None,
                   transcript=text)
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
    return rows


if __name__ == "__main__":
    main(sys.argv[1:])
