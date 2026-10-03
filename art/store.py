"""Store images from the 6.9" screenshots (store/ios_6.9, made by tool/screenshots.sh).

  python3 art/store.py
- store/android_phone/: the same shots padded to within 2:1 (Google Play's limit)
- store/android/feature_graphic_1024x500.png: key visual + logo
- store/android/icon_512.png
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
IOS, PHONE, AND = ROOT / 'store' / 'ios_6.9', ROOT / 'store' / 'android_phone', ROOT / 'store' / 'android'
PHONE.mkdir(parents=True, exist_ok=True)
AND.mkdir(parents=True, exist_ok=True)

for f in sorted(IOS.glob('*.png')):
    im = Image.open(f).convert('RGB')
    w = max(im.width, (im.height + 1) // 2 + 2)
    canvas = Image.new('RGB', (w, im.height), (246, 200, 234))
    canvas.paste(im, ((w - im.width) // 2, 0))
    canvas.save(PHONE / f.name)

bg = Image.open(ROOT / 'art' / 'gen' / 'out_title_bg.png').convert('RGBA')
# the idols' faces sit around 40% of the key visual's height
band = bg.crop((0, int(bg.height * 0.33), bg.width, int(bg.height * 0.33) + round(bg.width * 500 / 1024)))
fg = band.resize((1024, 500), Image.LANCZOS)
logo = Image.open(ROOT / 'assets' / 'ui' / 'title.png').convert('RGBA')
lw = 470
logo = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
fg.alpha_composite(logo, (1024 - lw - 16, 500 - logo.height - 14))
fg.convert('RGB').save(AND / 'feature_graphic_1024x500.png')
Image.open(ROOT / 'art' / 'gen' / 'out_icon.png').convert('RGB').resize((512, 512), Image.LANCZOS).save(AND / 'icon_512.png')
print('store images written')
