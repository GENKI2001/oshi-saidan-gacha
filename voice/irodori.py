"""Set up Irodori-TTS on this PC and render the members' voices with it.

  python3 voice/irodori.py setup                  # once: clone + install (needs git and uv)
  python3 voice/irodori.py render [voice/jobs.json]
  python3 voice/irodori.py run art/asmr.py        # any script that wants the Irodori venv

Irodori-TTS goes to ~/tools/Irodori-TTS, or to $IRODORI_DIR when it is set (e.g. an
existing checkout). The commit is pinned to the one the game's voices were made with.
The models (TTS, codec, Whisper) download from Hugging Face on the first render.

The members' voices come from voice/candidates/*.wav (the reference takes in
make_voice_jobs.py), which are in the repo, so a fresh PC sounds the same.
"""
from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = 'https://github.com/Aratako/Irodori-TTS.git'
COMMIT = '89f9d8f'
DIR = Path(os.environ.get('IRODORI_DIR', Path.home() / 'tools' / 'Irodori-TTS')).expanduser()
MAC = sys.platform == 'darwin'


def python() -> Path:
    return DIR / '.venv' / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')


def need(tool: str) -> None:
    if not shutil.which(tool):
        sys.exit(f'{tool} が見つかりません。' + (
            '  uv: https://docs.astral.sh/uv/getting-started/installation/' if tool == 'uv' else ''))


def setup(extra: str | None) -> None:
    need('git'), need('uv')
    if not DIR.exists():
        DIR.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', REPO, str(DIR)], check=True)
        subprocess.run(['git', 'checkout', COMMIT], cwd=DIR, check=True)
    # cu128 with an NVIDIA GPU; otherwise cpu (on a Mac that is the PyPI torch, which has MPS)
    extra = extra or ('cu128' if not MAC and shutil.which('nvidia-smi') else 'cpu')
    subprocess.run(['uv', 'sync', '--extra', extra], cwd=DIR, check=True)
    # librosa/scipy: art/asmr.py and art/songs/*; mlx-whisper: the take check on Apple silicon
    # (elsewhere voice_batch.py uses Whisper through transformers)
    more = ['librosa', 'scipy'] + (['mlx-whisper'] if MAC and platform.machine() == 'arm64' else [])
    subprocess.run(['uv', 'pip', 'install', '--python', str(python()), *more], cwd=DIR, check=True)
    print(f'ok: {DIR}')


def run(script: str, *args: str) -> None:
    if not python().exists():
        sys.exit(f'Irodori-TTS がまだありません（{DIR}）。先に: python3 voice/irodori.py setup')
    env = dict(os.environ, PYTHONPATH=str(DIR))
    sys.exit(subprocess.run([str(python()), str(Path(script).resolve()), *args], env=env).returncode)


def main() -> None:
    cmd, *rest = sys.argv[1:] or ['help']
    if cmd == 'setup':
        setup(rest[0] if rest else None)  # optional: cu128 / cpu / rocm / xpu
    elif cmd == 'render':
        run(str(HERE / 'voice_batch.py'), str(Path(rest[0] if rest else HERE / 'jobs.json').resolve()))
    elif cmd == 'run' and rest:
        run(*rest)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
