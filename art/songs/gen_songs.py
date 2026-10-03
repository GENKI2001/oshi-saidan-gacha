"""Generate idol songs with ACE-Step 1.5.

Run with the ACE-Step venv:
  cd ~/tools/songgen/ACE-Step-1.5
  .venv/bin/python <project>/art/songs/gen_songs.py --tracks bgm_title --seeds 1 2 --out ~/tools/songgen/out
"""
import argparse
import json
import os
import sys
import time

ACE_ROOT = os.path.expanduser("~/tools/songgen/ACE-Step-1.5")
sys.path.insert(0, ACE_ROOT)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from songs import SONGS  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tracks", nargs="+", default=list(SONGS))
    ap.add_argument("--seeds", nargs="+", type=int, default=[1])
    ap.add_argument("--out", default=os.path.expanduser("~/tools/songgen/out"))
    ap.add_argument("--dit", default="acestep-v15-turbo")
    ap.add_argument("--lm", default="acestep-5Hz-lm-1.7B")
    ap.add_argument("--lm-backend", default="mlx")
    ap.add_argument("--steps", type=int, default=None)
    ap.add_argument("--guidance", type=float, default=None)
    ap.add_argument("--shift", type=float, default=3.0)
    ap.add_argument("--no-think", action="store_true")
    args = ap.parse_args()

    from acestep.handler import AceStepHandler
    from acestep.llm_inference import LLMHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music

    t0 = time.time()
    dit = AceStepHandler()
    msg, ok = dit.initialize_service(project_root=ACE_ROOT, config_path=args.dit, device="auto")
    print("DiT:", ok, msg[:300], flush=True)
    llm = LLMHandler()
    msg, ok = llm.initialize(checkpoint_dir=os.path.join(ACE_ROOT, "checkpoints"),
                             lm_model_path=args.lm, backend=args.lm_backend, device="auto")
    print("LM:", ok, msg[:300], flush=True)
    print(f"init {time.time()-t0:.1f}s", flush=True)

    turbo = "turbo" in args.dit
    steps = args.steps or (8 if turbo else 50)
    guidance = args.guidance or (1.0 if turbo else 7.0)
    os.makedirs(args.out, exist_ok=True)
    for name in args.tracks:
        s = SONGS[name]
        for seed in args.seeds:
            t1 = time.time()
            params = GenerationParams(
                caption=s["caption"], lyrics=s["lyrics"].strip(),
                vocal_language="ja", bpm=s["bpm"], keyscale=s["keyscale"],
                timesignature="4", duration=float(s["duration"]),
                inference_steps=steps, guidance_scale=guidance, shift=args.shift,
                seed=seed, thinking=not args.no_think,
            )
            cfg = GenerationConfig(batch_size=1, use_random_seed=False, seeds=[seed],
                                   audio_format="wav")
            tag = f"{name}__{args.dit}__s{seed}"
            sub = os.path.join(args.out, tag)
            res = generate_music(dit, llm, params, cfg, save_dir=sub)
            dt = time.time() - t1
            if not res.success:
                print(f"FAIL {tag}: {res.error}", flush=True)
                continue
            for a in res.audios:
                dst = os.path.join(args.out, tag + ".wav")
                os.replace(a["path"], dst)
                print(f"OK {tag} -> {dst} ({dt:.1f}s)", flush=True)
            with open(os.path.join(args.out, tag + ".json"), "w") as f:
                json.dump(dict(track=name, seed=seed, dit=args.dit, lm=args.lm, steps=steps,
                               guidance=guidance, shift=args.shift, secs=dt,
                               status=res.status_message), f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
