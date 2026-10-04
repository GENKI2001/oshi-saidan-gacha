"""The members sing harmonies at the key moments of a song, over the original
ACE-Step take (left untouched: its lead vocal is the one we like).

The vocal of each spot is sung again by Seed-VC in a member's voice, moved a
number of scale steps away in the song's key (+2 a third above, -2 a third
below, -5 a sixth below, 0 the same notes as a double): every pitch frame goes
to the scale note that many steps from the nearest one, so the thirds and sixths
are major or minor as the key wants.

  ~/tools/svc/seed-vc/.venv/bin/python art/songs/harmony.py convert TRACK   # → work/harmony/TRACK/<who><step>_<start>.wav
  ~/tools/svc/seed-vc/.venv/bin/python art/songs/harmony.py mix TRACK       # → work/harmony/TRACK/mix.wav
  python3 art/songs/finalize.py TRACK=$HOME/tools/svc/work/harmony/TRACK/mix.wav
"""
import os
import sys
import types
from pathlib import Path

import numpy as np

W = Path.home() / 'tools' / 'svc' / 'work'
SEED = Path.home() / 'tools' / 'svc' / 'seed-vc'
SR = 44100
PAD = 0.8   # converted around each spot, so the voice is settled when it comes in
EDGE = 0.15  # the harmony fades in this much before a spot and out after it
MAJOR = [0, 2, 4, 5, 7, 9, 11]

# per track: the take, its key, how loud each part is under the lead (dB, before
# dividing by √voices), where the voices sit, and the spots:
# (start, end, {who: scale steps}[, extra dB]) — times from Whisper word timestamps.
TRACKS = {
    'bgm_shizumomo': dict(
        take='s13', tonic=9,  # A major
        db={2: -7, -2: -7},
        pan={'momo': 0.45, 'shizuku': -0.45}, late={'momo': 7, 'shizuku': 11},
        spots=[
            (28.26, 31.76, {'momo': 2}),                 # となりで ふわり 笑ってる (Momo joins in "beside")
            (37.42, 41.42, {'momo': 2, 'shizuku': -2}),  # 並べば ちょうどいい
            (41.58, 57.98, {'momo': 2, 'shizuku': -2}),  # chorus 1
            (72.32, 75.38, {'shizuku': -2}),             # ちゃんと わかってるよ (Shizuku's quiet line)
            (76.48, 92.80, {'momo': 2, 'shizuku': -2}),  # chorus 2
            (93.10, 96.80, {'momo': 2, 'shizuku': -2}),  # ふたりで ひとつの メロディー
            (112.90, 118.00, {'momo': 2, 'shizuku': -2}),  # ふたりで ひとつの メロディー (last)
        ]),
    # The unit song, all five: Momo (highest voice) a third above, Hinata and Koharu
    # doubling the tune on either side, Shizuku a third below, Yoru (lowest) a sixth below.
    'bgm_title': dict(
        take='s11', tonic=4,  # E major
        db={0: -4, 2: -3, -2: -3, -5: -4},
        pan={'hinata': -0.35, 'koharu': 0.35, 'shizuku': -0.65, 'momo': 0.65, 'yoru': 0.0},
        late={'hinata': 12, 'koharu': 18, 'shizuku': 9, 'momo': 6, 'yoru': 15},
        spots=[
            (14.55, 18.10, {'momo': 2, 'shizuku': -2}),  # 五つの色が きらりと光る
            (26.08, 29.10, {'momo': 2, 'shizuku': -2}),  # せーので 手をつないで
            (29.40, 52.52, 'all'),                        # ステージへ ジャンプ + chorus 1
            (61.50, 65.26, 'all'),                        # ひとりじゃ出せない この輝きを
            (69.00, 100.94, 'all'),                       # せーので 声をあわせて 未来へ ジャンプ + chorus 2 + きらきら…
            (121.16, 126.40, 'all'),                      # きらきら 虹の向こうまで (last)
        ],
        all={'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
    # Solo songs: the lead stays the take's. 0 = on the tune with it, 2 = a third above, -2 = a third below;
    # every start sits in a breath measured on the vocal.
    'bgm_hinata': dict(
        take='s11', tonic=0,  # C major
        db={0: -4, 2: -6, -2: -7},
        pan={'hinata': 0.3}, late={'hinata': 10},
        # the verses are hers alone; she joins on the tune and the harmony changes line by line
        spots=[
            (0.20, 1.20, {'hinata': 0}),  # せーの
            (0.20, 1.20, {'hinata': 2}),
            (19.80, 22.60, {'hinata': 0}),  # もっと もっと あつくなれ (she comes in on the tune)
            (22.95, 25.54, {'hinata': 0}),  # ハートに 火をつけて (the third joins)
            (22.95, 25.54, {'hinata': 2}),
            (25.54, 30.00, {'hinata': 0}),  # ひなたサンシャイン キミを照らすよ
            (25.54, 30.00, {'hinata': 2}),
            (30.20, 33.15, {'hinata': 0}),  # くもりの日だって 晴れにしちゃう (below this time)
            (30.20, 33.15, {'hinata': -2}),
            (33.30, 36.20, {'hinata': 0}),  # ひなたサンシャイン 手をのばして
            (33.30, 36.20, {'hinata': 2}),
            (36.20, 42.10, {'hinata': 0}),  # いっしょに いちばん 高く飛ぼう (all three)
            (36.20, 42.10, {'hinata': 2}),
            (36.20, 42.10, {'hinata': -2}),
            (58.20, 61.20, {'hinata': 0}),  # chorus 2: the other way round
            (58.20, 61.20, {'hinata': -2}),
            (61.35, 64.30, {'hinata': 0}),
            (61.35, 64.30, {'hinata': 2}),
            (64.30, 67.45, {'hinata': 0}),
            (64.30, 67.45, {'hinata': 2}),
            (64.30, 67.45, {'hinata': -2}),
            (67.60, 71.36, {'hinata': 0}),
            (67.60, 71.36, {'hinata': 2}),
            (82.30, 90.50, {'hinata': 0}),  # last chorus
            (82.30, 90.50, {'hinata': 2}),
            (97.40, 104.10, {'hinata': 0}),  # ひなたサンシャイン 手をのばして (after ありがとう, which is hers alone)
            (97.40, 104.10, {'hinata': 2}),
            (97.40, 104.10, {'hinata': -2}),
            (106.90, 112.15, {'hinata': 0}),  # 高く飛ぼう
            (106.90, 112.15, {'hinata': 2}),
            (106.90, 112.15, {'hinata': -2}),
        ]),
    'bgm_koharu': dict(
        take='s12', tonic=7,  # G major
        db={0: -4, 2: -6, -2: -7},
        pan={'koharu': 0.3}, late={'koharu': 10},
        # the verses are hers alone; she joins on the tune and the harmony changes line by line
        spots=[
            (22.80, 27.40, {'koharu': 0}),  # ぜんぶ のせたら できあがり (she comes in on the tune)
            (28.05, 32.10, {'koharu': 0}),  # ふわふわ マシュマロ日和
            (28.05, 32.10, {'koharu': 2}),
            (32.40, 36.80, {'koharu': 0}),  # ほっぺも とろける しあわせ (below)
            (32.40, 36.80, {'koharu': -2}),
            (37.90, 40.75, {'koharu': 0}),  # ふわふわ マシュマロ日和
            (37.90, 40.75, {'koharu': 2}),
            (41.00, 45.75, {'koharu': 0}),  # キミにも ひとくち あげるね (all three)
            (41.00, 45.75, {'koharu': 2}),
            (41.00, 45.75, {'koharu': -2}),
            (59.70, 64.40, {'koharu': 0}),  # おしゃべり とまらない
            (59.70, 64.40, {'koharu': 2}),
            (64.90, 68.55, {'koharu': 0}),  # chorus 2: the other way round
            (64.90, 68.55, {'koharu': -2}),
            (68.80, 73.65, {'koharu': 0}),
            (68.80, 73.65, {'koharu': 2}),
            (74.20, 77.65, {'koharu': 0}),
            (74.20, 77.65, {'koharu': 2}),
            (74.20, 77.65, {'koharu': -2}),
            (77.90, 82.10, {'koharu': 0}),
            (77.90, 82.10, {'koharu': 2}),
            (82.25, 90.40, {'koharu': 2}),  # あまい においの ごごさんじ (only the third, airy; ごごさんじ after it is hers alone)
        ]),
    'bgm_yoru': dict(
        take='s12', tonic=5,  # D minor: the notes of F major
        db={0: -4, 2: -6, -2: -7},
        pan={'yoru': -0.3}, late={'yoru': 10},
        # the verses are hers alone; she joins on the tune and the harmony changes line by line
        spots=[
            (25.15, 28.70, {'yoru': 0}),  # ふふっ キミの夢の中へ (she comes in on the tune)
            (29.65, 34.20, {'yoru': 0}),  # こっそり しのびこむ (low and sly)
            (29.65, 34.20, {'yoru': -2}),
            (34.24, 38.24, {'yoru': 0}),  # こあくまミッドナイト
            (34.24, 38.24, {'yoru': 2}),
            (38.24, 42.10, {'yoru': 0}),  # むらさきの 星をあげる
            (38.24, 42.10, {'yoru': -2}),
            (42.25, 46.24, {'yoru': 0}),  # こあくまミッドナイト
            (42.25, 46.24, {'yoru': 2}),
            (46.24, 50.10, {'yoru': 0}),  # 夜があけても 離さない (all three)
            (46.24, 50.10, {'yoru': 2}),
            (46.24, 50.10, {'yoru': -2}),
            (80.20, 84.20, {'yoru': 0}),  # chorus 2 (from the breath at 79.9-80.2)
            (80.20, 84.20, {'yoru': -2}),
            (84.20, 87.90, {'yoru': 0}),
            (84.20, 87.90, {'yoru': 2}),
            (88.20, 94.20, {'yoru': 0}),  # 夜があけても 離さない; the good-night after it is hers alone
            (88.20, 94.20, {'yoru': 2}),
            (88.20, 94.20, {'yoru': -2}),
        ]),
    # The title song (the kana take, s26 / s27), all five: Momo on top, Hinata and Koharu in the middle,
    # Shizuku below and Yoru lowest. 0 = on the tune, ±2 a third, 4 a fifth above, -5 a sixth below, ±7 an octave.
    # Verses go round the members a line at a time, each chorus builds differently, the last one is all five.
    'bgm_title_s26': dict(
        song='~/tools/songgen/out_kana/bgm_title_kana__acestep-v15-turbo__s26.wav', tonic=4,  # E major
        db={0: -4, 2: -4, -2: -4, 4: -7, -5: -5, 7: -9, -7: -6},
        pan={'hinata': -0.35, 'koharu': 0.35, 'shizuku': -0.65, 'momo': 0.65, 'yoru': 0.0},
        late={'hinata': 12, 'koharu': 18, 'shizuku': 9, 'momo': 6, 'yoru': 15},
        prep=[
            (0.30, 120.65, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),
            (106.75, 110.50, {'hinata': -7}),
            (56.90, 59.70, {'koharu': 2}),
            (72.45, 76.30, {'koharu': 2}),
            (115.65, 120.65, {'koharu': 2}),
            (102.48, 106.50, {'koharu': 4}),
            (110.50, 114.10, {'koharu': 4}),
            (3.45, 7.30, {'momo': 2}),
            (30.40, 38.20, {'momo': 2}),
            (64.42, 72.45, {'momo': 2}),
            (98.85, 114.10, {'momo': 2}),
            (56.90, 59.70, {'momo': 4}),
            (72.45, 76.30, {'momo': 4}),
            (115.65, 120.65, {'momo': 4}),
            (115.65, 120.65, {'momo': 7}),
            (3.45, 7.30, {'shizuku': -2}),
            (26.30, 38.20, {'shizuku': -2}),
            (56.90, 59.70, {'shizuku': -2}),
            (64.42, 68.50, {'shizuku': -2}),
            (72.45, 76.30, {'shizuku': -2}),
            (98.85, 120.65, {'shizuku': -2}),
            (59.78, 64.40, {'yoru': -7}),
            (110.50, 120.65, {'yoru': -7}),
            (3.45, 7.30, {'yoru': -5}),
            (34.60, 38.20, {'yoru': -5}),
            (56.90, 59.70, {'yoru': -5}),
            (68.65, 76.30, {'yoru': -5}),
            (98.85, 120.65, {'yoru': -5}),
        ],
        spots=[
            (0.30, 3.30, {'hinata': 0, 'koharu': 0}),  # ラララ: two voices …
            (3.45, 7.30, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # … opening into all five
            (22.60, 26.30, {'hinata': 0, 'momo': 0}),  # chorus 1 builds: one more voice each line
            (26.30, 30.40, {'hinata': 0, 'momo': 0, 'shizuku': -2}),
            (30.40, 34.60, {'hinata': 0, 'momo': 2, 'koharu': 0, 'shizuku': -2}),
            (34.60, 38.20, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # 世界でいちばん かがやくよ: all five
            (38.85, 42.10, {'hinata': 0}),  # verse 2: a line each
            (42.20, 45.30, {'shizuku': 0}),
            (45.30, 49.20, {'koharu': 0}),
            (49.20, 53.50, {'momo': 0, 'yoru': 0}),
            (53.65, 56.80, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # せーので 声をあわせて: all five on the tune, as the words say
            (56.90, 59.70, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),  # 未来へ ジャンプ: and open out
            (59.78, 64.40, {'hinata': 0, 'koharu': 0, 'momo': 0, 'yoru': -7}),  # chorus 2: other colours (Yoru an octave below)
            (64.42, 68.50, {'hinata': 0, 'momo': 2, 'shizuku': -2}),
            (68.65, 72.45, {'koharu': 0, 'momo': 2, 'yoru': -5}),
            (72.45, 76.30, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),
            (98.85, 102.45, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # last chorus: all five from the start (虹の向こうまで before it is the lead alone)
            (102.48, 106.50, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (102.48, 106.50, {'koharu': 4}, -2),
            (106.75, 110.50, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (106.75, 110.50, {'hinata': -7}, -2),
            (110.50, 114.10, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (110.50, 114.10, {'yoru': -7, 'koharu': 4}, -1),
            (114.18, 115.65, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # きらきら: all on the tune …
            (115.65, 120.65, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),  # … 虹の向こうまで: the final chord
            (115.65, 120.65, {'momo': 7, 'yoru': -7}, -4),
        ]),
    'bgm_title_s27': dict(
        song='~/tools/songgen/out_kana/bgm_title_kana__acestep-v15-turbo__s27.wav', tonic=4,  # E major
        db={0: -4, 2: -4, -2: -4, 4: -7, -5: -5, 7: -9, -7: -6},
        pan={'hinata': -0.35, 'koharu': 0.35, 'shizuku': -0.65, 'momo': 0.65, 'yoru': 0.0},
        late={'hinata': 12, 'koharu': 18, 'shizuku': 9, 'momo': 6, 'yoru': 15},
        prep=[
            (8.05, 129.30, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),
            (116.45, 120.50, {'hinata': -7}),
            (27.65, 30.00, {'koharu': 2}),
            (69.95, 72.90, {'koharu': 2}),
            (85.40, 91.50, {'koharu': 2}),
            (126.25, 129.30, {'koharu': 2}),
            (112.60, 116.30, {'koharu': 4}),
            (120.54, 125.60, {'koharu': 4}),
            (11.88, 15.40, {'momo': 2}),
            (25.80, 27.45, {'momo': 2}),
            (38.45, 48.00, {'momo': 2}),
            (77.24, 85.38, {'momo': 2}),
            (108.65, 125.60, {'momo': 2}),
            (27.65, 30.00, {'momo': 4}),
            (69.95, 72.90, {'momo': 4}),
            (85.40, 91.50, {'momo': 4}),
            (126.25, 129.30, {'momo': 4}),
            (126.25, 129.30, {'momo': 7}),
            (11.88, 15.40, {'shizuku': -2}),
            (25.80, 30.00, {'shizuku': -2}),
            (34.20, 48.00, {'shizuku': -2}),
            (69.95, 72.90, {'shizuku': -2}),
            (77.24, 81.10, {'shizuku': -2}),
            (85.40, 91.50, {'shizuku': -2}),
            (108.65, 129.30, {'shizuku': -2}),
            (72.98, 77.20, {'yoru': -7}),
            (120.54, 129.30, {'yoru': -7}),
            (11.88, 15.40, {'yoru': -5}),
            (27.65, 30.00, {'yoru': -5}),
            (42.46, 48.00, {'yoru': -5}),
            (69.95, 72.90, {'yoru': -5}),
            (81.12, 91.50, {'yoru': -5}),
            (108.65, 129.30, {'yoru': -5}),
        ],
        spots=[
            (8.05, 8.80, {'hinata': 0}),  # 赤 青 黄色 紫 ピンク: each joins on her own colour
            (8.80, 9.25, {'hinata': 0, 'shizuku': 0}),
            (9.25, 9.95, {'hinata': 0, 'shizuku': 0, 'koharu': 0}),
            (9.95, 11.05, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0}),
            (11.05, 11.85, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),
            (11.88, 15.40, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # 五つの色が きらりと光る: five colours, five notes
            (16.00, 19.60, {'koharu': 0}),  # はじめましての ドキドキだって
            (19.70, 23.45, {'hinata': 0, 'momo': 0}),  # いっしょに 魔法に変えちゃおう
            (23.95, 25.45, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # せーので
            (25.80, 27.45, {'hinata': 0, 'momo': 2, 'shizuku': -2}),  # 手をつないで
            (27.65, 30.00, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),  # ステージへ ジャンプ
            (30.06, 34.20, {'hinata': 0, 'momo': 0}),  # chorus 1 builds
            (34.20, 38.25, {'hinata': 0, 'momo': 0, 'shizuku': -2}),
            (38.45, 42.40, {'hinata': 0, 'momo': 2, 'koharu': 0, 'shizuku': -2}),
            (42.46, 48.00, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (50.90, 54.80, {'shizuku': 0}),  # verse 2: a line each
            (54.84, 58.70, {'koharu': 0}),
            (58.72, 62.60, {'yoru': 0}),
            (62.85, 66.30, {'momo': 0, 'hinata': 0}),
            (66.85, 69.80, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # 声をあわせて
            (69.95, 72.90, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),  # 未来へ ジャンプ
            (72.98, 77.20, {'hinata': 0, 'koharu': 0, 'momo': 0, 'yoru': -7}),  # chorus 2: other colours
            (77.24, 81.10, {'hinata': 0, 'momo': 2, 'shizuku': -2}),
            (81.12, 85.38, {'koharu': 0, 'momo': 2, 'yoru': -5}),
            (85.40, 91.50, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),
            (108.65, 112.55, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # last chorus: all five (the bridge before it is the lead alone)
            (112.60, 116.30, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (112.60, 116.30, {'koharu': 4}, -2),
            (116.45, 120.50, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (116.45, 120.50, {'hinata': -7}, -2),
            (120.54, 125.60, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (120.54, 125.60, {'yoru': -7, 'koharu': 4}, -1),
            (125.65, 126.00, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # キラ…
            (126.25, 129.30, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),  # …キラ 虹の向こうまで: the final chord
            (126.25, 129.30, {'momo': 7, 'yoru': -7}, -4),
        ]),
    # The lobby song for ぷりパレガチャ (the tutorial plays it), all five, kept gentle: thirds and sixths,
    # hardly any octaves; verses a line each, the bridge blooms from Shizuku alone into four voices.
    'bgm_pripare_lobby': dict(
        song='~/tools/songgen/out_lobby/bgm_lobby_kana__acestep-v15-turbo__s14.wav', tonic=7,  # G major
        db={0: -4, 2: -4, -2: -4, 4: -8, -5: -5, -7: -7},
        pan={'hinata': -0.35, 'koharu': 0.35, 'shizuku': -0.65, 'momo': 0.65, 'yoru': 0.0},
        late={'hinata': 12, 'koharu': 18, 'shizuku': 9, 'momo': 6, 'yoru': 15},
        prep=[
            (0.95, 119.70, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),
            (105.00, 116.10, {'koharu': 4}),
            (0.95, 8.40, {'momo': 2}),
            (41.10, 49.30, {'momo': 2}),
            (64.35, 68.00, {'momo': 2}),
            (75.10, 88.70, {'momo': 2}),
            (91.75, 119.70, {'momo': 2}),
            (0.95, 8.40, {'shizuku': -2}),
            (24.95, 29.00, {'shizuku': -2}),
            (38.10, 49.30, {'shizuku': -2}),
            (77.55, 88.70, {'shizuku': -2}),
            (95.85, 119.70, {'shizuku': -2}),
            (111.35, 116.10, {'yoru': -7}),
            (43.50, 49.30, {'yoru': -5}),
            (77.55, 88.70, {'yoru': -5}),
            (95.85, 119.70, {'yoru': -5}),
        ],
        spots=[
            (0.95, 8.40, {'koharu': 0, 'momo': 2, 'shizuku': -2}, -3),  # the opening hums: a soft three-voice chord
            (11.45, 15.10, {'hinata': 0}),  # verse 1: a line each
            (15.30, 18.30, {'shizuku': 0}),
            (18.30, 21.35, {'koharu': 0}),
            (21.35, 24.90, {'yoru': 0}),
            (24.95, 29.00, {'momo': 0, 'hinata': 0, 'shizuku': -2}),  # どきどき 止まらない
            (31.00, 32.40, {'koharu': 0}),  # いくよ
            (33.30, 35.45, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # せーので: all five on the tune
            (35.65, 38.10, {'hinata': 0, 'koharu': 0, 'momo': 0}),  # chorus 1 builds
            (38.10, 41.10, {'hinata': 0, 'koharu': 0, 'momo': 0, 'shizuku': -2}),
            (41.10, 43.50, {'momo': 2, 'hinata': 0, 'shizuku': -2}),
            (43.50, 49.30, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # 好きが いっぱい つまってる: all five
            (50.75, 54.20, {'momo': 0}),  # verse 2: a line each
            (54.30, 57.70, {'yoru': 0}),
            (57.75, 60.70, {'hinata': 0}),
            (60.75, 64.30, {'shizuku': 0, 'koharu': 0}),
            (64.35, 68.00, {'koharu': 0, 'momo': 2}),  # もう一回 いいよね
            (70.85, 72.30, {'yoru': 0, 'shizuku': 0}),  # いくよ
            (72.30, 74.95, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),  # せーので
            (75.10, 77.55, {'hinata': 0, 'koharu': 0, 'momo': 2}),  # chorus 2: other colours
            (77.55, 80.45, {'hinata': 0, 'shizuku': -2, 'yoru': -5}),
            (80.50, 82.90, {'momo': 2, 'koharu': 0, 'shizuku': -2}),
            (82.90, 88.70, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (89.05, 91.70, {'shizuku': 0}, -1),  # bridge: ぱかっと あけたら (Shizuku, quiet) …
            (91.75, 95.55, {'shizuku': 0, 'momo': 2}),  # … 光が あふれて (the harmony blooms) …
            (95.85, 101.00, {'momo': 2, 'hinata': 0, 'shizuku': -2, 'yoru': -5}),  # … キミの いちばんに 会えたなら
            (102.50, 105.00, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # last chorus: all five
            (105.00, 108.40, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (105.00, 108.40, {'koharu': 4}, -3),
            (108.40, 111.20, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (111.35, 116.10, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (111.35, 116.10, {'koharu': 4, 'yoru': -7}, -3),
            (116.60, 119.70, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}, -1),  # また明日も まわしにくるね: a gentle five-voice close
        ]),
    # ぷりパレガチャ (s74 of the kana lyrics, ~172 BPM, G major), all five and all out: verses a line each,
    # pre-choruses build to all five, each chorus grows in 2-line blocks (a fifth above and Yoru an octave
    # below at the peaks), the bridge blooms from Shizuku alone. Every voice gets its own vibrato, scoops into
    # notes and a slight detune ('style'), breaths before the big entries, a spoken line before it starts.
    'bgm_lobby': dict(
        song='~/tools/songgen/out_lobby/bgm_lobby_kana__acestep-v15-turbo__s74.wav', tonic=7,  # G major
        db={0: -4, 2: -4, -2: -4, 4: -8, -5: -5, -7: -6},
        pan={'hinata': -0.35, 'koharu': 0.35, 'shizuku': -0.65, 'momo': 0.65, 'yoru': 0.0},
        late={'hinata': 12, 'koharu': 18, 'shizuku': 9, 'momo': 6, 'yoru': 15},
        # vib: vibrato depth (cents) on held notes; scoop: how flat a note starts before it slides up (cents);
        # detune: a constant offset (cents), so the five are not machine-tight
        style={'hinata': dict(vib=22, scoop=45, detune=6), 'shizuku': dict(vib=14, scoop=20, detune=4),
               'koharu': dict(vib=26, scoop=30, detune=-7), 'yoru': dict(vib=30, scoop=70, detune=8),
               'momo': dict(vib=34, scoop=35, detune=-5)},
        prep=[
            (0.70, 124.83, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}),
            (8.28, 124.83, {'momo': 2}),
            (10.76, 124.83, {'shizuku': -2}),
            (14.82, 124.83, {'yoru': -5}),
            (68.18, 124.83, {'yoru': -7}),
            (39.84, 124.83, {'koharu': 4}),
            (56.98, 65.67, {'koharu': 2}),
            (62.83, 65.67, {'momo': 4}),
        ],
        spots=[
            (0.70, 3.50, {'koharu': 0}),  # 願いを こめたら: verse 1 a line each
            (3.50, 5.80, {'momo': 0}),  # ときめき あつめて
            (5.80, 8.28, {'shizuku': 0}),  # 今日こそ 会いたい
            (8.28, 10.72, {'yoru': 0, 'momo': 2}),  # 大好きな あの子
            (10.76, 14.74, {'hinata': 0, 'shizuku': -2}),  # 胸の どきどき
            (14.82, 22.59, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # 止まらない 手を のばしたら: all five
            (22.66, 28.19, {'momo': 2, 'hinata': 0, 'shizuku': -2}),  # chorus 1 grows block by block
            (28.19, 33.95, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2}),
            (33.95, 39.84, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (39.84, 45.61, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (39.84, 45.61, {'koharu': 4}, -3),  # ピカピカ 光って 今日も ハッピー: a sparkle on top
            (45.61, 48.15, {'hinata': 0}),  # verse 2 a line each
            (48.15, 51.43, {'koharu': 0}),
            (51.43, 54.31, {'momo': 2, 'shizuku': -2}),
            (54.31, 56.98, {'hinata': 0, 'shizuku': 0, 'koharu': 0, 'yoru': 0, 'momo': 0}, -2),  # もっと 楽しい: all on the tune
            (56.98, 59.46, {'yoru': 0, 'koharu': 2}),  # 心 わくわく
            (59.46, 62.83, {'yoru': 0, 'koharu': 2, 'hinata': 0}),  # 止まらない
            (62.83, 65.67, {'momo': 4, 'hinata': 0, 'koharu': 2, 'shizuku': -2, 'yoru': -5}),  # 今 とびこもう: open out
            (68.18, 73.41, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -7}),  # chorus 2: all five, Yoru an octave below
            (73.41, 78.77, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (78.77, 85.03, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (85.03, 90.93, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (85.03, 90.93, {'koharu': 4, 'yoru': -7}, -3),
            (90.93, 93.23, {'shizuku': 0}, -1),  # bridge: そっと 目をあけて (Shizuku, quiet) …
            (93.23, 95.65, {'shizuku': 0, 'momo': 2}),  # … 光が あふれて
            (95.65, 98.86, {'shizuku': 0, 'momo': 2, 'hinata': 0, 'yoru': -5}),  # … キミに 会えたら
            (98.86, 103.34, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # … 最高 だよね: all five
            (98.86, 103.34, {'koharu': 4}, -3),
            (104.71, 110.12, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),  # last chorus: all five throughout
            (110.12, 116.00, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (110.12, 116.00, {'yoru': -7}, -3),
            (116.00, 121.72, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (116.00, 121.72, {'koharu': 4}, -3),
            (121.72, 124.83, {'momo': 2, 'hinata': 0, 'koharu': 0, 'shizuku': -2, 'yoru': -5}),
            (121.72, 124.83, {'koharu': 4, 'yoru': -7}, -2),
        ],
        # inhales just before the big entries (who breathes)
        breaths=[(14.55, ['hinata', 'momo']), (22.40, ['hinata', 'koharu', 'momo']), (62.55, ['momo', 'shizuku', 'yoru']),
                 (67.90, ['hinata', 'koharu', 'momo', 'shizuku', 'yoru']), (90.65, ['shizuku']),
                 (104.45, ['hinata', 'koharu', 'momo', 'shizuku', 'yoru'])],
        # a spoken line (voice/render_song/<name>.wav, Irodori-TTS) before the song starts
        intro=2.5,
        spoken=[(-2.35, 'hinata', 'lobby_intro')],
    ),
}


def spots(t):
    for s in t['spots']:
        a, b, who = s[:3]
        yield a, b, t['all'] if who == 'all' else who, (s[3] if len(s) > 3 else 0)


def song_path(track):
    """The take, or the take with some lines sung again (repaint.py splice) when the track names one."""
    t = TRACKS[track]
    return Path(t['song']).expanduser() if 'song' in t else \
        Path.home() / f"tools/songgen/out_turbo/{track}__acestep-v15-turbo__{t['take']}.wav"


def stem(track):
    return W / 'sep/htdemucs_ft' / song_path(track).stem


def fixes(track):
    """(spot, fix start, fix end) for every spot a repainted line falls in: there the
    voices are converted again from the new lead and crossfaded over the spot's own."""
    t = TRACKS[track]
    for fa, fb in t.get('fixes', []):
        for spot in spots(t):
            if spot[0] < fb and fa < spot[1]:
                yield spot, fa, fb


def clip_path(track, who, step, a):
    return W / 'harmony' / track / f'{who}{step:+d}_{a:.2f}.wav'


def find_clip(track, who, step, a, b):
    """The clip to use for a spot: its own, or a longer one already made that covers it
    (so a chorus can be split line by line without converting each line again).
    Returns (path, the start it was made for) or None."""
    own = clip_path(track, who, step, a)
    if own.exists():
        return own, a
    import soundfile as sf
    for p in sorted((W / 'harmony' / track).glob(f'{who}{step:+d}_*.wav')):
        a2 = float(p.stem.split('_')[-1])
        n = sf.info(p).frames / sf.info(p).samplerate
        if a2 - PAD <= a - EDGE and a2 - PAD + n >= b + EDGE:
            return p, a2
    return None


def full_double(track, who):
    """The whole song sung on the tune by sing.py's conversion (work/conv), if there is one."""
    p = W / 'conv' / track / f'{who}.wav'
    return p if p.exists() and p.stat().st_size > 0 else None


def steps_in(tonic, n, style=None):
    """Seed-VC's pitch shift, replaced by n steps along the scale. With a style (cents):
    vib — vibrato that grows in on held notes; scoop — each new note starts that much
    flat and slides up; detune — a constant offset. The f0 it gets is the voiced
    frames only (100 a second), so "a new note" is where the rounded pitch changes."""
    from scipy.signal import medfilt
    scale = np.array([m for m in range(24, 108) if (m - tonic) % 12 in MAJOR])
    st = style or {}

    def shift(f0, _semitones):
        import torch
        f = f0.detach().cpu().numpy().astype(np.float64)
        midi = 69 + 12 * np.log2(np.maximum(f, 1) / 440)
        idx = np.abs(midi[:, None] - scale[None, :]).argmin(1)
        step = scale[np.clip(idx + n, 0, len(scale) - 1)] - scale[idx]
        step = medfilt(step.astype(float), 11)  # no flicker on glides between notes
        cents = np.full(len(f), float(st.get('detune', 0)))
        if st.get('vib') or st.get('scoop'):
            note = medfilt(np.round(midi), 9)
            since = np.zeros(len(f))
            for i in range(1, len(f)):
                since[i] = 0 if abs(note[i] - note[i - 1]) >= 1 else since[i - 1] + 1
            k = np.arange(len(f))
            cents += st.get('vib', 0) * np.clip((since - 25) / 30, 0, 1) * np.sin(2 * np.pi * 5.6 * k / 100)
            cents -= st.get('scoop', 0) * np.exp(-since / 7)
        return torch.from_numpy(f * 2 ** (step / 12 + cents / 1200)).to(f0.device, f0.dtype)
    return shift


def convert(track):
    import shutil, glob
    import soundfile as sf
    t = TRACKS[track]
    sys.path.insert(0, str(SEED)); os.chdir(SEED)
    sys.argv = ['inference.py']
    import inference
    _load = inference.load_models
    cache = {}
    inference.load_models = lambda args: cache.setdefault('m', _load(args))
    (W / 'harmony' / track).mkdir(parents=True, exist_ok=True)
    if not (stem(track) / 'vocals.wav').exists():
        import subprocess
        subprocess.run([sys.executable, '-m', 'demucs', '--two-stems=vocals', '-n', 'htdemucs_ft', '-d', 'mps',
                        '-o', str(W / 'sep'), str(song_path(track))], check=True)
    y, sr = sf.read(stem(track) / 'vocals.wav', always_2d=True)
    # 'prep': long stretches converted up front (not mixed) so many short spots can be cut from them
    jobs = [(a, b, w, False) for a, b, w in t.get('prep', [])]
    jobs += [(a, b, who_steps, False) for a, b, who_steps, _ in spots(t)]
    jobs += [(fa, fb, spot[2], True) for spot, fa, fb in fixes(track)]
    for a, b, who_steps, is_fix in jobs:
        todo = [(w, s) for w, s in who_steps.items()
                if not (clip_path(track, w, s, a).exists() if is_fix else find_clip(track, w, s, a, b))
                and (is_fix or not (s == 0 and full_double(track, w)))]
        if not todo:
            continue
        clip = W / 'harmony' / track / f'src_{a:.2f}.wav'
        # a spot at the very start of the song gets its lead-in padded with silence
        s0 = int((a - PAD) * sr)
        part = y[max(0, s0):int((b + PAD) * sr)].mean(1)
        sf.write(clip, np.concatenate([np.zeros(max(0, -s0)), part]), sr)
        for who, n in todo:
            inference.adjust_f0_semitones = steps_in(t['tonic'], n, t.get('style', {}).get(who))
            tmp = W / 'harmony' / track / f'tmp_{who}'
            tmp.mkdir(exist_ok=True)
            inference.main(types.SimpleNamespace(
                source=str(clip), target=str(W / 'refs' / f'{who}.wav'), output=str(tmp),
                diffusion_steps=40 if len(who_steps) <= 2 else 30, length_adjust=1.0, inference_cfg_rate=0.7,
                f0_condition=True, auto_f0_adjust=False, semi_tone_shift=1,  # nonzero → our shift runs
                checkpoint=None, config=None, fp16=False))
            shutil.move(glob.glob(str(tmp / '*.wav'))[0], clip_path(track, who, n, a))
            tmp.rmdir()
            print('done', who, n, a, flush=True)
        clip.unlink()


def mix(track):
    import soundfile as sf
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from sing import load, fit, smooth, reverb
    t = TRACKS[track]
    song = load(song_path(track))
    n = len(song)
    lead = fit(load(stem(track) / 'vocals.wav'), n).mean(1)
    env = smooth(np.abs(lead), 25)
    db = 20 * np.log10(env + 1e-9)
    gate = smooth(np.clip((db - (db.max() - 38)) / 8, 0, 1), 30)  # only where the lead sings
    full = {}

    def placed(who, step, a, b=None):
        if b is not None and (found := find_clip(track, who, step, a, b)):
            path, a = found
        else:
            path = clip_path(track, who, step, a)
        c = load(path).mean(1)
        v = np.zeros(n)
        s = int((a - PAD) * SR)
        if s < 0:  # padded with silence before the song began
            c, s = c[-s:], 0
        v[s:s + len(c)] = c[:n - s]
        return v

    h = np.zeros((n, 2))
    for a, b, who_steps, extra in spots(t):
        window = np.zeros(n)
        window[max(0, int((a - EDGE) * SR)):int((b + EDGE) * SR)] = 1
        window = smooth(window, 120) * gate
        act = window > 0.5
        lead_rms = np.sqrt((lead[act] ** 2).mean())
        for who, step in who_steps.items():
            if find_clip(track, who, step, a, b):
                v = placed(who, step, a, b)
            else:
                if who not in full:
                    full[who] = fit(load(full_double(track, who)).mean(1), n)
                v = full[who].copy()
            for spot, fa, fb in fixes(track):
                if spot[0] == a:
                    wf = np.zeros(n)
                    wf[int(fa * SR):int(fb * SR)] = 1
                    wf = smooth(wf, 60)
                    v = v * (1 - wf) + placed(who, step, fa) * wf
            v = np.roll(v, int(SR * t['late'][who] / 1000)) * window
            gain = 10 ** ((t['db'][step] + extra) / 20) / np.sqrt(len(who_steps))
            v *= gain * lead_rms / max(np.sqrt((v[act] ** 2).mean()), 1e-9)
            pan = t['pan'][who]
            h[:, 0] += v * np.sqrt(1 - pan)
            h[:, 1] += v * np.sqrt(1 + pan)
    out = song + reverb(h, wet=0.22)
    out = extras(t, out, lead_rms_all=np.sqrt((lead[gate > 0.5] ** 2).mean()), reverb=reverb)
    out /= max(1.0, np.abs(out).max() / 0.95)
    sf.write(W / 'harmony' / track / 'mix.wav', out, SR)
    print(track, f'{n / SR:.1f}s', len(t['spots']), 'spots')


SPOKEN = Path(__file__).resolve().parents[2] / 'voice' / 'render_song'


def breath(who, seed):
    """A short inhale: noise shaped like an open "は", brighter for the higher voices."""
    from scipy.signal import butter, sosfilt
    rng = np.random.default_rng(seed)
    n = int(SR * 0.32)
    x = rng.standard_normal(n)
    lo, hi = {'momo': (1400, 7500), 'hinata': (1300, 7000), 'koharu': (1100, 6500), 'shizuku': (1000, 6000), 'yoru': (800, 5000)}[who]
    x = sosfilt(butter(2, [lo, hi], 'bandpass', fs=SR, output='sos'), x)
    tt = np.linspace(0, 1, n)
    x *= np.sin(np.pi * tt ** 0.7) ** 2  # swells in, cut off as the note starts
    return x / np.sqrt((x ** 2).mean())


def extras(t, out, lead_rms_all, reverb):
    """Breaths before the big entries, then the spoken lines, with room added before and after the song."""
    import soundfile as sf
    import librosa
    for k, (at, who_list) in enumerate(t.get('breaths', [])):
        for j, who in enumerate(who_list):
            b = breath(who, k * 10 + j) * lead_rms_all * 10 ** (-17 / 20) / np.sqrt(len(who_list))
            s = int((at + j * 0.012) * SR)
            pan = t['pan'][who]
            out[s:s + len(b), 0] += b[:len(out) - s] * np.sqrt(1 - pan)
            out[s:s + len(b), 1] += b[:len(out) - s] * np.sqrt(1 + pan)
    pre, post = int(t.get('intro', 0) * SR), int(t.get('outro', 0) * SR)
    out = np.concatenate([np.zeros((pre, 2)), out, np.zeros((post, 2))])
    talk = np.zeros_like(out)
    for at, who, name in t.get('spoken', []):
        y, sr = sf.read(SPOKEN / f'{name}.wav', always_2d=True)
        y = librosa.resample(y.mean(1), orig_sr=sr, target_sr=SR) if sr != SR else y.mean(1)
        y *= lead_rms_all * 10 ** (-1 / 20) / np.sqrt((y[np.abs(y) > 0.02] ** 2).mean())
        s = pre + int(at * SR)
        pan = t['pan'][who] * 0.5
        talk[s:s + len(y), 0] += y[:len(out) - s] * np.sqrt(1 - pan)
        talk[s:s + len(y), 1] += y[:len(out) - s] * np.sqrt(1 + pan)
    return out + reverb(talk, wet=0.12)


if __name__ == '__main__':
    {'convert': convert, 'mix': mix}[sys.argv[1]](sys.argv[2])
