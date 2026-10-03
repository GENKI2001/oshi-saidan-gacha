"""Launch screens: the key visual with the logo (iOS fills the screen; Android centers the logo).

  python3 art/launch.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
bg = Image.open(ROOT / 'art' / 'gen' / 'out_title_bg.png').convert('RGBA')
logo = Image.open(ROOT / 'assets' / 'ui' / 'title.png').convert('RGBA')
w = int(bg.width * 0.84)
logo = logo.resize((w, round(logo.height * w / logo.width)), Image.LANCZOS)
art = bg.copy()
art.alpha_composite(logo, ((bg.width - w) // 2, int(bg.height * 0.1)))
art = art.convert('RGB')
ios = ROOT / 'ios' / 'Runner' / 'Assets.xcassets' / 'LaunchImage.imageset'
for name, scale in (('LaunchImage.png', 1), ('LaunchImage@2x.png', 2), ('LaunchImage@3x.png', 3)):
    art.resize((341 * scale, 512 * scale), Image.LANCZOS).save(ios / name)
res = ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / 'drawable-nodpi'
res.mkdir(parents=True, exist_ok=True)
logo.resize((720, round(logo.height * 720 / logo.width)), Image.LANCZOS).save(res / 'launch_logo.png')
print('launch screens written')
