"""Rendered WAVs → app m4a (trim the head, 1.12x tempo, short lead-in).

    python3 voice/convert_voice.py   # → assets/voice/*.m4a (prunes files no longer used)
"""
import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / 'assets' / 'voice'
TEMPO = 1.12
# per speaker (つむぎ asked to talk a bit faster)
TEMPO_OF = {'つむぎ': 1.25}
LEAD_MS = 120


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    keep = set()
    for j in json.loads((HERE / 'jobs.json').read_text()):
        if j.get('kind') == 'scene':
            continue  # シチュエーションボイス are mixed into tracks by art/asmr.py
        src = Path(j['out'])
        keep.add(src.stem)
        dst = OUT / f'{src.stem}.m4a'
        if not src.exists():
            print('missing', src.stem, j['text'])
            continue
        tempo = TEMPO_OF.get(j.get('who'), TEMPO)
        stamp = OUT / f'.{src.stem}.tempo'
        if dst.exists() and dst.stat().st_mtime > src.stat().st_mtime and stamp.exists() and stamp.read_text() == str(tempo):
            continue
        subprocess.run(
            ['ffmpeg', '-loglevel', 'error', '-y', '-i', str(src), '-filter:a',
             f'silenceremove=start_periods=1:start_threshold=-50dB,atempo={tempo},adelay={LEAD_MS},loudnorm=I=-16:TP=-1.5',
             '-ac', '1', '-ar', '44100', '-c:a', 'aac', '-b:a', '64k', str(dst)],
            check=True)
        stamp.write_text(str(tempo))
    for stale in OUT.glob('*.m4a'):
        if stale.stem not in keep:
            stale.unlink()
    for stale in OUT.glob('.*.tempo'):
        if stale.stem.lstrip('.') not in keep:
            stale.unlink()
    print(f'{len(keep)} voice files in {OUT}')


if __name__ == '__main__':
    main()
