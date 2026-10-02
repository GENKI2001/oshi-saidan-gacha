"""Turn the Codex app icon (art/gen/out_icon.png) into every platform size.

  python3 art/icon.py
iOS icons must be opaque, so the image is flattened onto its own colours.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
src = Image.open(ROOT / 'art' / 'gen' / 'out_icon.png').convert('RGB')
side = min(src.size)
src = src.crop(((src.width - side) // 2, (src.height - side) // 2, (src.width + side) // 2, (src.height + side) // 2))


def put(path, px):
    path.parent.mkdir(parents=True, exist_ok=True)
    src.resize((px, px), Image.LANCZOS).save(path)


# iOS: every file listed in the asset catalog
ios = ROOT / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
for img in json.loads((ios / 'Contents.json').read_text())['images']:
    if 'filename' not in img:
        continue
    pt = float(img['size'].split('x')[0])
    scale = int(img['scale'].rstrip('x'))
    put(ios / img['filename'], round(pt * scale))

# Android launcher icons
for folder, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    put(ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / f'mipmap-{folder}' / 'ic_launcher.png', px)

# web
for name, px in {'Icon-192.png': 192, 'Icon-512.png': 512, 'Icon-maskable-192.png': 192, 'Icon-maskable-512.png': 512}.items():
    put(ROOT / 'web' / 'icons' / name, px)
put(ROOT / 'web' / 'favicon.png', 32)
print('icons written')
