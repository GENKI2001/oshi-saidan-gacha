"""Batch-render Mio's voice with Irodori-TTS (https://github.com/Aratako/Irodori-TTS).

Usually run through voice/irodori.py (sets up Irodori-TTS on any PC):
    python3 voice/irodori.py render voice/jobs.json

jobs.json is a list of {"out": "...wav", "text": "...", "caption": "...",
"ref": "...wav" (optional), "seed": 1, "duration_scale": 1.0 (below 1 is
faster)}; relative paths are read from the folder of jobs.json. The model is
loaded once and every job is rendered in turn; existing outputs are skipped so
a run can resume. A job whose "asset" (the file the app plays) exists is skipped
too, so a fresh PC only records new lines. Runs on CUDA, Apple MPS or the CPU, whichever is there.

The model now and then starts a clip mid-syllable, swallowing the first
sound, mostly on short openers like 「あっ」「えっ」. Each take is checked
and re-rolled with the next seed until it opens on silence; after two
misses the text is led by 「。」, which gives the model a breath first.
"""

from __future__ import annotations

import json
import sys
from difflib import SequenceMatcher
from pathlib import Path

from irodori_tts.inference_runtime import (
    InferenceRuntime,
    RuntimeKey,
    SamplingRequest,
    download_hf_checkpoint,
    save_wav,
)

CHECKPOINT = "Aratako/Irodori-TTS-v4.1-Small"
TAKES = 6
WHISPER = "mlx-community/whisper-large-v3-turbo"
# off a Mac (no mlx): the same model through transformers, which Irodori-TTS already needs
WHISPER_HF = "openai/whisper-large-v3-turbo"
_asr = None


def device() -> str:
    import torch

    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def transcribe(path: Path) -> str:
    global _asr
    try:
        import mlx_whisper

        return mlx_whisper.transcribe(str(path), path_or_hf_repo=WHISPER, language="ja")["text"]
    except ImportError:
        pass
    if _asr is None:
        from transformers import pipeline

        # not on MPS: there it hears only "!"
        _asr = pipeline("automatic-speech-recognition", model=WHISPER_HF,
                        device="cuda" if device() == "cuda" else "cpu")
    return _asr(str(path), generate_kwargs={"language": "ja", "task": "transcribe"})["text"]


def _plain(text: str) -> str:
    return "".join(ch for ch in text if ch.isalnum())


def says_the_line(path: Path, text: str) -> bool:
    """Transcribe the take (Whisper) and reject one that drifts far from the script."""
    heard = transcribe(path)
    return SequenceMatcher(None, _plain(heard), _plain(text)).ratio() >= 0.5


def opens_cleanly(audio, sample_rate: int) -> bool:
    """True when the first 30 ms are near-silent, i.e. no cut-off onset."""
    head = audio.detach().float().abs().reshape(-1)[: int(sample_rate * 0.03)]
    return bool(head.numel() == 0 or head.max().item() < 0.1)


def main() -> None:
    jobs_file = Path(sys.argv[1]).resolve()
    jobs = json.loads(jobs_file.read_text())
    dev = device()
    print(f"device: {dev}", flush=True)
    runtime = InferenceRuntime.from_key(
        RuntimeKey(
            checkpoint=download_hf_checkpoint(CHECKPOINT),
            model_device=dev,
            codec_repo="Aratako/Semantic-DACVAE-Japanese-32dim",
            model_precision="fp32",
            codec_device=dev,
            codec_precision="fp32",
            codec_deterministic_encode=True,
            codec_deterministic_decode=True,
            compile_model=False,
            compile_dynamic=False,
        )
    )
    for index, job in enumerate(jobs, start=1):
        out = jobs_file.parent / job["out"]
        if out.exists() or job.get("asset") and (jobs_file.parent / job["asset"]).exists():
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        ref = job.get("ref") and str(jobs_file.parent / job["ref"])
        seed = int(job.get("seed", 1))
        for take in range(TAKES):
            result = runtime.synthesize(
                SamplingRequest(
                    text=job["text"] if take < 2 else "。" + job["text"],
                    caption=job.get("caption"),
                    ref_wav=ref,
                    no_ref=ref is None,
                    seed=seed + take,
                    duration_scale=float(job.get("duration_scale", 1.0)),
                ),
                log_fn=None,
            )
            save_wav(str(out), result.audio, result.sample_rate)
            if not job.get("check", True) or (opens_cleanly(result.audio, result.sample_rate) and says_the_line(
                out, job["text"]
            )):
                break
        print(f"[{index}/{len(jobs)}] {out.name} (take {take + 1})", flush=True)


if __name__ == "__main__":
    main()
