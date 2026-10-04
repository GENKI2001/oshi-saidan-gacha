"""Sing one stretch of an adopted take again with ACE-Step's repaint, the rest untouched.

ACE-Step mumbles some kanji lines (bgm_title's 赤 青 黄色 紫 ピンク came out as
"あか おう そいろ さき"), so the line is given in kana or romaji for the repaint.

  cd ~/tools/songgen/ACE-Step-1.5
  .venv/bin/python <project>/art/songs/repaint.py bgm_title --start 9.0 --end 14.5 \
      --line "赤 青 黄色 紫 ピンク=あか あお きいろ むらさき ピンク" --seeds 1 2 3

Then put the chosen repaints into the take (each only inside its own stretch, 80 ms crossfades):
  python3 art/songs/repaint.py splice bgm_title ~/tools/songgen/out_repaint/bgm_title__fixed.wav \
      9.0:14.5:~/tools/songgen/out_repaint/bgm_title__kana__s1.wav ...
"""
import argparse
import os
import sys
import time

ACE_ROOT = os.path.expanduser("~/tools/songgen/ACE-Step-1.5")
sys.path.insert(0, ACE_ROOT)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from songs import SONGS  # noqa: E402

TAKES = {"bgm_title": "s11"}


def splice(track, out, picks):
    import numpy as np
    import soundfile as sf
    song, sr = sf.read(os.path.expanduser(f"~/tools/songgen/out_turbo/{track}__acestep-v15-turbo__{TAKES[track]}.wav"))
    k = int(sr * 0.08)
    for pick in picks:
        a, b, path = pick.split(":", 2)
        y, sr2 = sf.read(os.path.expanduser(path))
        assert sr2 == sr and len(y) >= len(song)
        i, j = int(float(a) * sr), int(float(b) * sr)
        w = np.zeros(len(song))
        w[i:j] = 1
        w[i:i + k] = np.linspace(0, 1, k)
        w[j - k:j] = np.linspace(1, 0, k)
        song = song * (1 - w[:, None]) + y[:len(song)] * w[:, None]
    sf.write(os.path.expanduser(out), song, sr)
    print("spliced", out, len(picks), "lines")


def main():
    if sys.argv[1] == "splice":
        return splice(sys.argv[2], sys.argv[3], sys.argv[4:])
    ap = argparse.ArgumentParser()
    ap.add_argument("track")
    ap.add_argument("--start", type=float, required=True)
    ap.add_argument("--end", type=float, required=True)
    ap.add_argument("--line", action="append", default=[], help="old=new, a lyric line rewritten for the repaint")
    ap.add_argument("--seeds", nargs="+", type=int, default=[1])
    ap.add_argument("--tag", default="fix")
    ap.add_argument("--dit", default="acestep-v15-turbo")
    ap.add_argument("--steps", type=int, default=None)
    ap.add_argument("--guidance", type=float, default=None)
    ap.add_argument("--out", default=os.path.expanduser("~/tools/songgen/out_repaint"))
    args = ap.parse_args()

    from acestep.handler import AceStepHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music

    s = SONGS[args.track]
    lyrics = s["lyrics"].strip()
    for pair in args.line:
        old, new = pair.split("=", 1)
        assert old in lyrics, old
        lyrics = lyrics.replace(old, new)
    src = os.path.expanduser(f"~/tools/songgen/out_turbo/{args.track}__acestep-v15-turbo__{TAKES[args.track]}.wav")

    dit = AceStepHandler()
    msg, ok = dit.initialize_service(project_root=ACE_ROOT, config_path=args.dit, device="auto")
    print("DiT:", ok, msg[:200], flush=True)
    turbo = "turbo" in args.dit
    os.makedirs(args.out, exist_ok=True)
    for seed in args.seeds:
        t0 = time.time()
        params = GenerationParams(
            task_type="repaint", src_audio=src,
            repainting_start=args.start, repainting_end=args.end, chunk_mask_mode="explicit",
            caption=s["caption"], lyrics=lyrics, vocal_language="ja",
            bpm=s["bpm"], keyscale=s["keyscale"], timesignature="4", duration=float(s["duration"]),
            inference_steps=args.steps or (8 if turbo else 50), guidance_scale=args.guidance or (1.0 if turbo else 7.0), shift=3.0, seed=seed, thinking=False,
        )
        cfg = GenerationConfig(batch_size=1, use_random_seed=False, seeds=[seed], audio_format="wav")
        name = f"{args.track}__{args.tag}__s{seed}"
        res = generate_music(dit, None, params, cfg, save_dir=os.path.join(args.out, name))
        if not res.success:
            print("FAIL", name, res.error, flush=True)
            continue
        dst = os.path.join(args.out, name + ".wav")
        os.replace(res.audios[0]["path"], dst)
        print(f"OK {dst} ({time.time() - t0:.0f}s)", flush=True)


if __name__ == "__main__":
    main()
