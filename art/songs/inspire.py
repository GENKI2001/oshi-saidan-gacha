"""Let ACE-Step 1.5 write a song on its own ("Simple Mode"): from a short request
its language model writes the caption, the lyrics, the tempo and key, then the
song is made from those.

Run with the ACE-Step venv:
  cd ~/tools/songgen/ACE-Step-1.5
  .venv/bin/python <project>/art/songs/inspire.py --name bgm_pripare --n 6 --out ~/tools/songgen/out_inspire
Each take: <name>__i<k>.wav and .json (what the model wrote).
"""
import argparse
import json
import os
import sys
import time

ACE_ROOT = os.path.expanduser("~/tools/songgen/ACE-Step-1.5")
sys.path.insert(0, ACE_ROOT)

QUERY = (
    "An explosive, euphoric Japanese idol group anthem for the very climax of a live concert: five girls singing in Japanese, "
    "fast tempo, a thick powerful wall of sound, the crowd shouting calls, a huge chorus that explodes, everyone at peak excitement."
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", default="bgm_pripare")
    ap.add_argument("--n", type=int, default=6)
    ap.add_argument("--query", default=QUERY)
    ap.add_argument("--out", default=os.path.expanduser("~/tools/songgen/out_inspire"))
    args = ap.parse_args()

    from acestep.handler import AceStepHandler
    from acestep.llm_inference import LLMHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music, create_sample

    dit = AceStepHandler()
    print("DiT:", dit.initialize_service(project_root=ACE_ROOT, config_path="acestep-v15-turbo", device="auto")[1], flush=True)
    llm = LLMHandler()
    print("LM:", llm.initialize(checkpoint_dir=os.path.join(ACE_ROOT, "checkpoints"), lm_model_path="acestep-5Hz-lm-1.7B",
                                backend="mlx", device="auto")[1], flush=True)
    os.makedirs(args.out, exist_ok=True)
    for k in range(1, args.n + 1):
        t0 = time.time()
        s = create_sample(llm, args.query, vocal_language="ja", temperature=0.9)
        if not s.success:
            print("FAIL sample", k, s.status_message, flush=True)
            continue
        dur = min(max(float(s.duration or 140), 110.0), 150.0)
        params = GenerationParams(
            caption=s.caption, lyrics=s.lyrics, vocal_language="ja", bpm=s.bpm, keyscale=s.keyscale,
            timesignature=s.timesignature or "4", duration=dur, inference_steps=8, guidance_scale=1.0, shift=3.0,
            seed=100 + k, thinking=True,
        )
        cfg = GenerationConfig(batch_size=1, use_random_seed=False, seeds=[100 + k], audio_format="wav")
        tag = f"{args.name}__i{k}"
        res = generate_music(dit, llm, params, cfg, save_dir=os.path.join(args.out, tag))
        if not res.success:
            print("FAIL", tag, res.error, flush=True)
            continue
        os.replace(res.audios[0]["path"], os.path.join(args.out, tag + ".wav"))
        with open(os.path.join(args.out, tag + ".json"), "w") as f:
            json.dump(dict(caption=s.caption, lyrics=s.lyrics, bpm=s.bpm, keyscale=s.keyscale, duration=dur), f, ensure_ascii=False, indent=1)
        print(f"OK {tag} bpm={s.bpm} key={s.keyscale} ({time.time() - t0:.0f}s)", flush=True)


if __name__ == "__main__":
    main()
