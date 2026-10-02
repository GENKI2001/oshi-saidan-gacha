"""Cut the Codex sprite sheets (magenta background) into transparent PNGs.

  python3 art/slice.py
Each sticker goes to the grid cell holding its centroid, so stickers that
lean over a cell border are still cut whole.
"""
import numpy as np
from PIL import Image
from scipy import ndimage
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / 'art' / 'gen'

SHEETS = {
    'figs1': (4, 3, 'figures', ['koban', 'maneki', 'daruma', 'tanuki', 'kitsune', 'kingyo',
                                'poi', 'yoyo', 'wataame', 'takoyaki', 'ringoame', 'ramune']),
    'figs2': (4, 3, 'figures', ['shateki', 'garagara', 'chochin', 'hanabi', 'taiko', 'kuji',
                                'saisen', 'daikoku', 'kannushi', 'maigo', 'meishi', 'kincap']),
    'figs3': (4, 3, 'figures', ['yakisoba', 'kakigori', 'yakitori', 'chocoban', 'hyottoko', 'kazaguruma',
                                'uchiwa', 'suzu', 'kame', 'superball', 'yataioji', 'wanage']),
    'figs4': (4, 3, 'figures', ['omikuji', 'kinchaku', 'senkou', 'kamifusen', 'yukata', 'kingyobachi',
                                'mikoshi', 'shishimai', 'kumade', 'yagura', 'benzaiten', 'ebisu']),
    'figs5': (4, 3, 'figures', ['ikayaki', 'jagabata', 'menko', 'demekin', 'katanuki', 'tengu', 'karaage', 'kendama', 'hiyoko', 'wagasa', 'dango', 'tanabata']),
    'figs6': (4, 3, 'figures', ['mizuame', 'fue', 'usagi', 'sukuiya', 'hanabishi', 'hotei', 'tomorokoshi', 'shabondama', 'hotaru', 'okame', 'taikoboy', 'bishamon']),
    'figs7': (4, 3, 'figures', ['ichigoame', 'mizudeppo', 'kabuto', 'ranchu', 'omamori', 'fujin', 'crepe', 'otedama', 'suzumushi', 'toro', 'miko', 'raijin']),
    'figs8': (4, 3, 'figures', ['kushikatsu', 'darumaotoshi', 'inari', 'ninja', 'hozuki', 'kirin', 'ougonkingyo', 'takarabune', 'ryu', 'kinmaneki', 'hannya', 'kintaro']),
    'boss': (4, 1, 'ui', ['boss_0', 'boss_1', 'boss_2', 'boss_3']),
    'machine': (1, 1, 'ui', ['machine']),
}


def key(img):
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(r, b) - g  # magenta strength: 255 on the key, ~0 on art
    alpha = 1 - np.clip((m - 30) / 200, 0, 1)
    safe = np.maximum(alpha, 1e-3)[..., None]
    mag = np.array([255, 0, 255], np.float32)
    rgb = np.clip((a - (1 - alpha)[..., None] * mag) / safe, 0, 255)
    return np.dstack([rgb, alpha * 255]).astype(np.uint8)


for name, (cols, rows, out, ids) in SHEETS.items():
    if not (GEN / f'out_{name}.png').exists():
        print('skip', name, '(not generated yet)')
        continue
    px = key(Image.open(GEN / f'out_{name}.png'))
    h, w = px.shape[:2]
    lab, n = ndimage.label(px[..., 3] > 40)
    boxes = {i: None for i in range(len(ids))}
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        ys, xs = sl
        area = (lab[sl] == k).sum()
        if area < 150:
            continue
        cy, cx = (ys.start + ys.stop) / 2, (xs.start + xs.stop) / 2
        cell = int(cy // (h / rows)) * cols + int(cx // (w / cols))
        b = boxes[cell]
        boxes[cell] = (ys.start, xs.start, ys.stop, xs.stop) if b is None else (
            min(b[0], ys.start), min(b[1], xs.start), max(b[2], ys.stop), max(b[3], xs.stop))
    for i, fid in enumerate(ids):
        y0, x0, y1, x1 = boxes[i]
        crop = Image.fromarray(px[y0:y1, x0:x1])
        side = max(crop.size) + 8
        sq = Image.new('RGBA', (side, side))
        sq.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
        size = 512 if out == 'ui' else 256
        sq.resize((size, size), Image.LANCZOS).save(ROOT / 'assets' / out / f'{fid}.png')
        print(fid, crop.size)

# The title logo keeps its own aspect ratio (cropped to the art, 1024 wide).
px = key(Image.open(GEN / 'out_title.png'))
ys, xs = np.nonzero(px[..., 3] > 40)
logo = Image.fromarray(px[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
logo.resize((1024, round(logo.height * 1024 / logo.width)), Image.LANCZOS).save(ROOT / 'assets' / 'ui' / 'title.png')
print('title', logo.size)

# Level UI parts (signboard, badge, gauge frame, gauge fill), stacked top to bottom.
if (GEN / 'out_levelui.png').exists():
    px = key(Image.open(GEN / 'out_levelui.png'))
    rows = np.nonzero((px[..., 3] > 40).any(axis=1))[0]
    bands, start = [], rows[0]
    for a, b in zip(rows, rows[1:]):
        if b - a > 6:
            bands.append((start, a + 1))
            start = b
    bands.append((start, rows[-1] + 1))
    for name, (y0, y1) in zip(['lv_plaque', 'lv_badge', 'lv_gauge', 'lv_fill'], bands):
        cols = np.nonzero((px[y0:y1, :, 3] > 40).any(axis=0))[0]
        crop = px[y0:y1, cols[0]:cols[-1] + 1]
        Image.fromarray(crop).save(ROOT / 'assets' / 'ui' / f'{name}.png')
        print(name, crop.shape[1], 'x', crop.shape[0])
