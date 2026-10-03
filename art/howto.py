"""Crop the real game screenshots in art/howto/ into the あそびかた pictures.
Ring boxes can be added per page (left empty: plain screenshots read clearer).

  python3 art/howto.py
Screenshots are 1206x2622 (iPhone 17 Pro simulator); boxes are in those pixels.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'art' / 'howto'
OUT = ROOT / 'assets' / 'howto'
OUT.mkdir(parents=True, exist_ok=True)

# name: (crop box, [ring boxes in screenshot pixels])
PAGES = {
    'spin': ((0, 150, 1206, 1300), []),
    'reveal': ((0, 300, 1206, 2420), []),
    'shelf': ((0, 150, 1206, 1800), []),
    'payday': ((0, 820, 1206, 1880), []),
    'shop': ((0, 350, 1206, 2300), []),
    'result': ((0, 350, 1206, 2000), []),
}

# which store-screenshot moment each page is cut from (tool/screenshots.sh → art/howto/shots)
FROM = {'spin': 'h_spin', 'reveal': '5_pull', 'shelf': '4_scoring', 'payday': '6_payday', 'shop': '8_shop', 'result': 'h_result'}

for name, (box, rings) in PAGES.items():
    im = Image.open(SRC / 'shots' / f'{FROM[name]}.png').convert('RGB')
    d = ImageDraw.Draw(im)
    for x0, y0, x1, y1 in rings:
        d.rounded_rectangle((x0, y0, x1, y1), radius=60, outline='white', width=22)
        d.rounded_rectangle((x0, y0, x1, y1), radius=60, outline=(255, 64, 110), width=12)
    im = im.crop(box)
    im = im.resize((640, round(im.height * 640 / im.width)), Image.LANCZOS)
    im.save(OUT / f'{name}.jpg', quality=86)
    print(name, im.size)
