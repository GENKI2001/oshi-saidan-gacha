"""Seed-VC singing conversion for every (track, singer), loading the models once.
  ~/tools/svc/seed-vc/.venv/bin/python ~/tools/svc/work/convert_batch.py
"""
import os, sys, glob, shutil, types
from pathlib import Path
SEED = Path.home() / 'tools/svc/seed-vc'
W = Path.home() / 'tools/svc/work'
sys.path.insert(0, str(SEED)); os.chdir(SEED)
sys.argv = ['inference.py']
import inference
_cache = {}
_load = inference.load_models
inference.load_models = lambda args: _cache.setdefault('m', _load(args))

JOBS = [
    ('bgm_yoru', 's12', ['yoru']),
    ('bgm_select', 's11', ['hinata', 'shizuku', 'koharu', 'yoru', 'momo']),
    ('bgm_premium', 's11', ['hinata', 'shizuku', 'koharu', 'yoru', 'momo']),
]
for track, take, singers in JOBS:
    for who in singers:
        out = W / 'conv' / track / f'{who}.wav'
        if out.exists():
            continue
        tmp = W / 'conv' / track / f'tmp_{who}'
        tmp.mkdir(parents=True, exist_ok=True)
        args = types.SimpleNamespace(
            source=str(W / 'sep/htdemucs_ft' / f'{track}__acestep-v15-turbo__{take}' / 'vocals.wav'),
            target=str(W / 'refs' / f'{who}.wav'), output=str(tmp),
            diffusion_steps=40 if len(singers) <= 2 else 30, length_adjust=1.0, inference_cfg_rate=0.7,
            f0_condition=True, auto_f0_adjust=False, semi_tone_shift=0, checkpoint=None, config=None, fp16=False)
        inference.main(args)
        shutil.move(glob.glob(str(tmp / '*.wav'))[0], out)
        tmp.rmdir()
        print('done', track, who, flush=True)
print('ALL DONE', flush=True)
