"""Batch-render Mio's voice with Irodori-TTS (https://github.com/Aratako/Irodori-TTS).

Run from inside an Irodori-TTS checkout:
    uv run --no-sync python /path/to/voice_batch.py jobs.json

jobs.json is a list of {"out": "...wav", "text": "...", "caption": "...",
"ref": "...wav" (optional), "seed": 1, "duration_scale": 1.0 (below 1 is
faster)}. The model is loaded once and every job
is rendered in turn; existing outputs are skipped so a run can resume.

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


def _plain(text: str) -> str:
    return "".join(ch for ch in text if ch.isalnum())


def says_the_line(path: Path, text: str) -> bool:
    """Transcribe the take (when mlx-whisper is installed) and reject one
    that drifts far from the script."""
    try:
        import mlx_whisper
    except ImportError:
        return True
    heard = mlx_whisper.transcribe(str(path), path_or_hf_repo=WHISPER, language="ja")["text"]
    return SequenceMatcher(None, _plain(heard), _plain(text)).ratio() >= 0.5


def opens_cleanly(audio, sample_rate: int) -> bool:
    """True when the first 30 ms are near-silent, i.e. no cut-off onset."""
    head = audio.detach().float().abs().reshape(-1)[: int(sample_rate * 0.03)]
    return bool(head.numel() == 0 or head.max().item() < 0.1)


def main() -> None:
    jobs = json.loads(Path(sys.argv[1]).read_text())
    runtime = InferenceRuntime.from_key(
        RuntimeKey(
            checkpoint=download_hf_checkpoint(CHECKPOINT),
            model_device="mps",
            codec_repo="Aratako/Semantic-DACVAE-Japanese-32dim",
            model_precision="fp32",
            codec_device="mps",
            codec_precision="fp32",
            codec_deterministic_encode=True,
            codec_deterministic_decode=True,
            compile_model=False,
            compile_dynamic=False,
        )
    )
    for index, job in enumerate(jobs, start=1):
        out = Path(job["out"])
        if out.exists():
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        ref = job.get("ref")
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
