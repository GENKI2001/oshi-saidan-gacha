"""Finalize chosen takes into game-ready loops: assets/bgm/<name>.m4a

  python3 art/songs/finalize.py bgm_title=/path/take.wav bgm_select=/path/take.wav ...

- trims leading silence (< -50 dBFS) and trailing silence
- 1.5 s fade-out at the end, 10 ms fade-in at the start
- two-pass ffmpeg loudnorm to -16 LUFS integrated, -1.5 dBTP
- AAC-LC 128 kbps, 44.1 kHz stereo
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets" / "bgm"
FADE = 1.5


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def main(pairs):
    tmp = Path(tempfile.mkdtemp(prefix="songfin_"))
    for pair in pairs:
        name, src = pair.split("=", 1)
        trimmed = tmp / f"{name}_trim.wav"
        # trim leading + trailing silence
        run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af",
             "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.02,"
             "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse",
             "-ar", "44100", "-ac", "2", trimmed])
        dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                         "-of", "csv=p=0", trimmed]).stdout)
        fades = f"afade=t=in:d=0.01,afade=t=out:st={dur - FADE:.3f}:d={FADE}"
        # pass 1: measure
        r = subprocess.run(["ffmpeg", "-v", "info", "-i", trimmed, "-af",
                            fades + ",loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json",
                            "-f", "null", "-"], capture_output=True, text=True)
        m = json.loads(re.findall(r"\{[^{}]*\}", r.stderr)[-1])
        ln = (f"loudnorm=I=-16:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}"
              f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}"
              f":offset={m['target_offset']}:linear=true")
        dst = OUT / f"{name}.m4a"
        run(["ffmpeg", "-y", "-v", "error", "-i", trimmed, "-af", fades + "," + ln,
             "-ar", "44100", "-ac", "2", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", dst])
        print(f"{name}: {src} -> {dst} ({dur:.1f}s)")


if __name__ == "__main__":
    main(sys.argv[1:])
