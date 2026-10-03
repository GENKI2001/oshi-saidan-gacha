"""Cut the Codex sprite sheets (flat magenta or green background) into transparent PNGs.

  python3 art/slice.py
Only background that is connected to the sheet's edge (or an enclosed hole of
the pure key color) is removed, so purple and pink artwork inside a sticker's
white border is never keyed out. Each sticker goes to the grid cell holding its
centre, so stickers that lean over a cell border are still cut whole.
"""
import json

import numpy as np
from PIL import Image
from scipy import ndimage
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / 'art' / 'gen'
FIG = ROOT / 'assets' / 'figures'
UI = ROOT / 'assets' / 'ui'
FIG.mkdir(parents=True, exist_ok=True)
UI.mkdir(parents=True, exist_ok=True)

# goods and portraits as lossy WebP with alpha (a tenth of the PNG size); the rest of the UI stays PNG
EXT = {FIG: 'webp', UI: 'png'}
SAVE = {'webp': {'quality': 90, 'method': 6}, 'png': {}}
IDOLS = ['hinata', 'shizuku', 'koharu', 'yoru', 'momo']
# name: (cols, rows, out dir, ids, square size or None to keep the aspect (height))
SHEETS = {f'{k}': (4, 3, FIG, v, 256) for k, v in json.loads((GEN / 'sheets.json').read_text()).items()}
SHEETS.update({
    # つむぎ as the manager (edited from out_boss.png: staff hoodie, headset, pass)
    'boss_staff': (4, 1, UI, ['boss_0', 'boss_1', 'boss_2', 'boss_3'], None),
    'uikit': (4, 2, UI, ['ui_heart', 'ui_ribbon', 'ui_note', 'ui_mic', 'ui_penlight', 'ui_medal', 'ui_megaphone', 'ui_balloons'], 256),
    # one portrait per image (a sheet of five let the girls touch and bleed into each other)
    **{f'cut_{i}_{v}': (1, 1, UI, [f'cutin_{i}_{v}'], None) for i in IDOLS for v in 'ab'},
    'machine': (1, 1, UI, ['machine'], 512),
    # ★1..★4 and the 注意書き dud; split into halves below
    'capsules': (3, 2, UI, ['capsule_0', 'capsule_1', 'capsule_2', 'capsule_3', 'capsule_4'], None),
})


def keyness(a, green):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (g - np.maximum(r, b)) if green else (np.minimum(r, b) - g)


def key(img, green=False):
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    k = keyness(a, green)
    # background: strong key color touching the edge, plus enclosed holes of the pure key
    lab, _ = ndimage.label(k > 120)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    holes, n = ndimage.label(k > 200)
    sizes = ndimage.sum(np.ones_like(k), holes, range(1, n + 1))
    bg |= np.isin(holes, [i + 1 for i, s in enumerate(sizes) if s > 40])
    # a soft edge only in a thin band around the background
    band = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.ones_like(k)
    alpha[bg] = 0
    soft = 1 - np.clip((k - 30) / 200, 0, 1)
    alpha[band] = soft[band]
    keyc = np.array([0, 255, 0] if green else [255, 0, 255], np.float32)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha)[..., None] * keyc) / safe, 0, 255)
    rgb[alpha == 0] = 0
    return np.dstack([rgb, alpha * 255]).astype(np.uint8)


GREEN = {'uikit', 'capsules'}


def cut_sheet(name, cols, rows, out, ids, size):
    src = GEN / f'out_{name}.png'
    if not src.exists():
        print('skip', name, '(not generated yet)')
        return
    px = key(Image.open(src), green=name in GREEN)
    h, w = px.shape[:2]
    lab, _ = ndimage.label(px[..., 3] > 40)
    yy, xx = np.mgrid[0:h, 0:w]
    cellmap = np.minimum(yy * rows // h, rows - 1) * cols + np.minimum(xx * cols // w, cols - 1)
    owner = np.full((h, w), -1)
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        m = lab[sl] == k
        if m.sum() < 150:
            continue
        cells = cellmap[sl][m]
        counts = np.bincount(cells, minlength=cols * rows)
        if counts.max() >= 0.85 * m.sum():
            # one sticker leaning over a border: keep it whole in its main cell
            owner[sl][m] = counts.argmax()
        else:
            # two stickers touching (a string, a sparkle): split along the grid
            owner[sl][m] = cells
    boxes = {}
    for i in range(len(ids)):
        ys, xs = np.nonzero(owner == i)
        boxes[i] = None if len(ys) == 0 else (ys.min(), xs.min(), ys.max() + 1, xs.max() + 1)
    for i, fid in enumerate(ids):
        if boxes[i] is None:
            print('!! nothing in cell', i, 'for', fid)
            continue
        y0, x0, y1, x1 = boxes[i]
        part = px[y0:y1, x0:x1].copy()
        part[owner[y0:y1, x0:x1] != i, 3] = 0  # leave out the neighbours' pixels
        crop = Image.fromarray(part)
        if fid == 'ui_ribbon':
            # a banner keeps its own (wide) shape
            crop.resize((512, round(crop.height * 512 / crop.width)), Image.LANCZOS).save(out / f'{fid}.png')
        elif size:
            side = max(crop.size) + 8
            sq = Image.new('RGBA', (side, side))
            sq.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
            ext = 'png' if fid.startswith('ui_') else EXT[out]
            sq.resize((size, size), Image.LANCZOS).save(out / f'{fid}.{ext}', **SAVE[ext])
        elif name.startswith('cut'):
            # portraits on an exact 2:3 canvas (600x900), head at the top, so the app can crop faces by fraction
            w = max(crop.width, round(crop.height * 2 / 3))
            hgt = round(w * 3 / 2)
            canvas = Image.new('RGBA', (w, hgt))
            canvas.paste(crop, ((w - crop.width) // 2, 0))
            canvas.resize((600, 900), Image.LANCZOS).save(out / f'{fid}.webp', **SAVE['webp'])
        else:
            crop.resize((round(crop.width * 512 / crop.height), 512), Image.LANCZOS).save(out / f'{fid}.png')
        print(fid, crop.size)


for name, spec in SHEETS.items():
    cut_sheet(name, *spec)

# The title logo keeps its own aspect ratio (cropped to the art, 1024 wide).
# out_title3: the logo redone in the key visual's soft glossy style (out_title.png was a flat sticker)
if (GEN / 'out_title3.png').exists():
    px = key(Image.open(GEN / 'out_title3.png'), green=True)
    # despill: the logo has no green, so any green left (tiny lace holes, glow edges) is the key bleeding in
    rgbf = px[..., :3].astype(np.int16)
    cap = np.maximum(rgbf[..., 0], rgbf[..., 2])
    spill = rgbf[..., 1] > cap
    rgbf[..., 1] = np.where(spill, cap, rgbf[..., 1])
    px[..., :3] = rgbf.astype(np.uint8)
    # pixels that were pure key (small enclosed lace holes) become clear
    px[..., 3] = np.where(spill & (np.asarray(Image.open(GEN / 'out_title3.png').convert('RGB'))[..., 1].astype(np.int16) - cap > 120), 0, px[..., 3])
    ys, xs = np.nonzero(px[..., 3] > 40)
    logo = Image.fromarray(px[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    logo.resize((1024, round(logo.height * 1024 / logo.width)), Image.LANCZOS).save(UI / 'title.png')
    print('title', logo.size)

# Level UI parts (plaque, badge, gauge frame, gauge fill), stacked top to bottom.
if (GEN / 'out_levelui.png').exists():
    px = key(Image.open(GEN / 'out_levelui.png'), green=True)
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
        Image.fromarray(crop).save(UI / f'{name}.png')
        print(name, crop.shape[1], 'x', crop.shape[0])

# Full-bleed backgrounds as JPEG.
for name, w in (('title_bg', 1024), ('game_bg', 1024), ('venue0', 768), ('venue1', 768), ('venue2', 768), ('venue3', 768)):
    if (GEN / f'out_{name}.png').exists():
        im = Image.open(GEN / f'out_{name}.png').convert('RGB')
        out = name.replace('venue', 'venue_')
        im.resize((w, round(im.height * w / im.width)), Image.LANCZOS).save(UI / f'{out}.jpg', quality=86)
        print(name, im.size)

# Capsules open along their seam: cut each into a top and a bottom half where the
# white body starts (found per capsule, since the seam is not always at mid-height).
for k in range(5):
    f = UI / f'capsule_{k}.png'
    if not f.exists():
        continue
    im = np.asarray(Image.open(f).convert('RGBA')).astype(np.float32)
    h, w = im.shape[:2]
    # look beside the face (left and right of it), where the body is plain white
    side = np.concatenate([im[:, int(w * 0.2):int(w * 0.3)], im[:, int(w * 0.7):int(w * 0.8)]], axis=1)
    white = ((side[..., :3].min(axis=2) > 200) & (side[..., 3] > 200)).mean(axis=1)
    cut = next(y for y in range(int(h * 0.45), int(h * 0.8)) if white[y:y + 10].min() > 0.7)
    Image.fromarray(im[:cut].astype(np.uint8)).save(UI / f'capsule_{k}_top.png')
    Image.fromarray(im[cut:].astype(np.uint8)).save(UI / f'capsule_{k}_bot.png')
    f.unlink()
    print(f'capsule_{k} cut at {cut}/{h}')
