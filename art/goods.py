"""The goods (駒) of 推し祭壇ガチャ: one row per figure.

Each row keeps the effect numbers of the matching ぽんぽこガチャ縁日 figure
(already balanced by tool/sim.dart) and gives it a new id, name, emoji, tags
and the English description used in the Codex image prompts.

  python3 art/goods.py figures   # rewrites lib/logic/figures.dart from the 縁日 source
  python3 art/goods.py prompts   # writes art/gen/goods*.txt (12 per sheet) and art/gen/sheets.json
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT.parent / 'gacha_rogue' / 'lib' / 'logic' / 'figures.dart'

# 縁日 tag → 推し祭壇 tag. Tags that are members are the 推し; the rest are kinds of goods.
TAGS = {
    '縁起': 'ひなた', '水': 'しずく', '食べ物': 'こはる', '飾り': 'よる', '動物': 'もも',
    '人': 'ファン', 'お金': '', 'おもちゃ': 'ぱれにゃん', '道具': '応援', 'のろい': 'のろい',
}

# old id: (new id, name, emoji, look)
G = {
    'koban': ('coin', 'ハートのメダル', '🪙', 'a shiny gold coin with a pink heart engraved in the middle and a tiny happy face'),
    'daruma': ('hinata_badge', 'ひなたの缶バッジ', '🔴', 'a round tin can badge (pin button) printed with chibi HINATA smiling and doing a peace sign, red-orange rim'),
    'tanuki': ('momo_badge', 'ももの缶バッジ', '🩷', 'a round tin can badge printed with chibi MOMO winking with a heart hand, pink rim'),
    'kingyo': ('shizumomo_strap', 'しずもものラバスト', '🫧', 'a soft rubber keychain strap of chibi SHIZUKU and chibi MOMO hugging, with a small metal ring'),
    'poi': ('trade_file', '交換用バインダー', '📒', 'a clear plastic trading-card binder with pastel heart stickers on the cover, a few cards peeking out'),
    'yoyo': ('aqua_balloon', 'しずく色のバルーン', '🎈', 'a light-blue foil balloon shaped like the face of PARENYAN (the round white cat mascot), on a string'),
    'wataame': ('koharu_badge', 'こはるの缶バッジ', '🟡', 'a round tin can badge printed with chibi KOHARU eating pink cotton candy, yellow rim'),
    'takoyaki': ('koharu_keyholder', 'こはるのアクキー', '🍩', 'an acrylic keychain of chibi KOHARU holding a big donut, with a metal ring'),
    'ramune': ('collab_drink', 'コラボカフェのドリンク', '🥤', 'a collab-cafe drink cup with blue soda and a lemon slice, a straw, and a round coaster printed with chibi KOHARU and SHIZUKU'),
    'chochin': ('yoru_badge', 'よるの缶バッジ', '🟣', 'a round tin can badge printed with chibi YORU with little bat wings and a fang grin, purple rim'),
    'maigo': ('shinki', '新規のオタク', '😰', 'a chibi nervous young male fan (newbie) in a plain t-shirt, holding a tiny event map, big sweat drop, cute and comedic'),
    'kakigori': ('collab_kakigori', 'コラボかき氷', '🍧', 'a collab-cafe shaved ice in a glass bowl with blue and yellow syrup and a little blank flag'),
    'kazaguruma': ('nyan_badge', 'ぱれにゃん缶バッジ', '🐱', 'a round tin can badge printed with PARENYAN, the round white cat mascot, rainbow rim'),
    'uchiwa': ('oshi_uchiwa', '推しうちわ', '🪭', 'a handmade idol support fan (uchiwa) decorated with glitter hearts, stars and ribbons, no letters'),
    'kitsune': ('hinata_mirror', 'ひなたのまねっこアクスタ', '🪞', 'an acrylic stand of HINATA holding a heart-shaped hand mirror and copying a pose, on a clear base'),
    'ringoame': ('koharu_acsta', 'こはるのアクスタ', '🍰', 'an acrylic stand of KOHARU holding a strawberry parfait, on a clear base'),
    'shateki': ('flea', 'フリマ出品', '📦', 'a cardboard shipping box with a heart price tag and a smartphone beside it showing a shopping app with blank cards'),
    'garagara': ('gacha_charm', 'ガチャ運のお守り', '🧧', 'a pastel pink omamori charm bag embroidered with a capsule-toy ball, with a tassel'),
    'taiko': ('yoru_penlight', 'よるのペンライト', '🔦', 'a glowing purple idol penlight with a tiny bat charm hanging from it'),
    'kuji': ('blind_bag', 'ランダム缶バッジ', '🎁', 'a shiny sealed foil blind-bag pouch with a sparkle pattern, slightly puffy'),
    'omikuji': ('hinata_photo', 'ひなたのブロマイド', '📸', 'a glossy photo card (bromide) of HINATA posing with a wink, white border'),
    'hanabi': ('yoru_tape', 'ライブの銀テープ', '🎊', 'a burst of shiny silver and purple concert confetti streamer tapes with a chibi YORU printed on one tape'),
    'saisen': ('hinata_altar', 'ひなたの祭壇', '⛩️', 'a small home altar display shelf full of HINATA goods (badges, acrylic stands), red LED candles and ribbons'),
    'kannushi': ('kosan', '古参オタク', '😎', 'a chibi veteran male idol fan with a headband and a happi coat, a glowing penlight in each hand, confident grin, cute and comedic'),
    'kincap': ('kincap', '金のカプセル', '🌟', 'a shining golden capsule-toy ball with sparkles'),
    'yakisoba': ('koharu_cookie', 'こはるのクッキー缶', '🍪', 'a round cookie tin with chibi KOHARU printed on the lid, cookies around it'),
    'kamifusen': ('nyan_balloon', 'ぱれにゃん風船', '🎈', 'a round white balloon shaped like PARENYAN the cat mascot, with a ribbon string'),
    'yataioji': ('cafe_master', 'コラボカフェの店長', '🧑‍🍳', 'a chibi friendly cafe manager man with an apron and a mustache, holding a tray with a collab drink'),
    'senkou': ('yoru_candle', 'よるのキャンドル', '🕯️', 'a purple LED candle with a small bat ornament and a soft glow'),
    'yakitori': ('koharu_card', 'こはるのトレカ', '🃏', 'a holographic trading card of KOHARU with a rainbow shine'),
    'kame': ('shizumomo_acsta', 'しずもものペアアクスタ', '🤝', 'an acrylic stand of SHIZUKU and MOMO holding hands, on a clear base'),
    'kinchaku': ('oshi_bank', '推し貯金箱', '🐷', 'a piggy bank shaped like PARENYAN the cat mascot with gold coins around it'),
    'yukata': ('yoru_tan', 'よる担のオタク', '💜', 'a chibi excited male fan in a purple t-shirt waving a purple penlight, cute and comedic'),
    'mikoshi': ('hinata_akushu', 'ひなたの握手会', '🤝', 'a chibi HINATA shaking hands with a delighted chibi male fan across a small table'),
    'maneki': ('hinamomo_maneki', '招き猫ポーズのひなもも', '🐱', 'an acrylic stand of HINATA and MOMO doing a cute beckoning-cat (maneki-neko) pose together'),
    'chocoban': ('koharu_nui', 'こはるのおやつぬい', '🧸', 'a small plush doll (nui) of KOHARU holding a chocolate banana'),
    'suzu': ('hinata_bell', 'ひなたの鈴キーホルダー', '🔔', 'a keychain with a gold bell, a red ribbon and a small star charm'),
    'wanage': ('nyan_tower', 'ぱれにゃんタワー', '🗼', 'a tall stack of PARENYAN cat-mascot plushies piled on top of each other'),
    'kingyobachi': ('shizuku_acsta', 'しずくのアクスタ', '💧', 'an acrylic stand of SHIZUKU surrounded by water bubbles, on a clear base'),
    'shishimai': ('hinata_letter', 'ひなたの直筆メッセージ', '💌', 'a cute envelope with a red heart seal and a star sticker, a letter peeking out (no readable text)'),
    'hyottoko': ('hinayoru_board', 'ひなよるのファンサボード', '🪧', 'a decorated fan-service request board with hearts and stars and chibi HINATA and YORU stickers (no letters)'),
    'superball': ('nyan_squeeze', 'ぱれにゃんスクイーズ', '🍡', 'a squishy PARENYAN cat-mascot squeeze toy, round and soft'),
    'kumade': ('hinata_gold', 'ひなたのゴールド缶バッジ', '🥇', 'a shiny GOLD can badge printed with HINATA, sparkling'),
    'ebisu': ('hinata_live', 'ひなたのソロライブ', '🎤', 'a miniature concert stage diorama with HINATA singing under spotlights and a crowd of red penlights'),
    'yagura': ('yoru_shelf', 'よるのゴシック祭壇棚', '🗄️', 'a tall gothic purple display shelf with lace, candles and YORU goods'),
    'benzaiten': ('hinakoha_stream', 'ひなこはのお料理配信', '🍳', 'HINATA and KOHARU cooking pancakes together in a livestream kitchen set with a small camera'),
    'ikayaki': ('koharu_snack', 'こはるのおやつ瓶', '🍬', 'a glass candy jar full of colorful sweets with a yellow lid and a flower'),
    'jagabata': ('koharu_cushion', 'こはるのクッション', '🛋️', 'a round fluffy yellow cushion with chibi KOHARU’s sleepy face'),
    'menko': ('nyan_card', 'ぱれにゃんトレカ', '🎴', 'a holographic trading card of PARENYAN the cat mascot'),
    'demekin': ('shizumomo_hoodie', 'しずもものおそろいパーカー', '🧥', 'two matching hoodies, one sky blue and one pink, with cat ears on the hoods, folded side by side'),
    'katanuki': ('lottery', 'ライブの抽選券', '🎫', 'a shiny concert lottery ticket with stars and a tear-off stub (no readable text)'),
    'tengu': ('hinayoru_costume', 'ひなよるのユニット衣装', '👗', 'a mannequin wearing a split red-and-purple idol stage costume with frills'),
    'karaage': ('koharu_tote', 'こはるのランチトート', '👜', 'a yellow tote bag printed with chibi KOHARU, a bento box peeking out'),
    'kendama': ('nyan_music', 'ぱれにゃんオルゴール', '🎶', 'a pastel music box with a tiny PARENYAN cat mascot on top'),
    'hiyoko': ('momo_mini', 'もものミニぬい', '🧸', 'a tiny plush doll of MOMO with cat ears'),
    'wagasa': ('yoru_parasol', 'よるの日傘', '☂️', 'an open black and purple lace parasol'),
    'dango': ('koharu_sweets', 'こはるのおやつアクスタ', '🍡', 'an acrylic stand of KOHARU eating three-colored dango, on a clear base'),
    'tanabata': ('hinayoru_tapestry', 'ひなよるの星空タペストリー', '🌌', 'a hanging fabric tapestry of a starry night sky with HINATA and YORU'),
    'mizuame': ('koharu_honey', 'こはるのはちみつキャンドル', '🍯', 'a candle shaped like a honey jar with a little bee'),
    'fue': ('penlight', 'ペンライト', '🔦', 'a white idol penlight glowing softly'),
    'usagi': ('hinayoru_ears', 'ひなよるのうさ耳カチューシャ', '🐰', 'a bunny-ear headband, one ear red and one ear purple'),
    'sukuiya': ('momo_tan', 'もも担のオタク', '💗', 'a chibi male fan in a pink t-shirt with heart-shaped glasses, holding a pink penlight, cute and comedic'),
    'hanabishi': ('light_staff', '照明スタッフ', '💡', 'a chibi stage lighting technician with a headset, holding a small spotlight'),
    'hotei': ('hinata_tour', 'ひなたの全国ツアー', '🚌', 'a cute tour bus wrapped with a big picture of HINATA and stars'),
    'tomorokoshi': ('koharu_popcorn', 'こはるのポップコーン', '🍿', 'a popcorn bucket printed with chibi KOHARU, overflowing with popcorn'),
    'shabondama': ('shizuku_bubble', 'しずく色のシャボン玉', '🫧', 'a bubble wand blowing light-blue soap bubbles, with a tiny PARENYAN mascot on the handle'),
    'hotaru': ('momo_ears', 'もものネコ耳カチューシャ', '🐾', 'a pink cat-ear headband with a little bell'),
    'okame': ('hinayoru_cheki', 'ひなよるのペアチェキ', '📷', 'an instant photo (cheki) of HINATA and YORU making a heart together, with doodles around'),
    'taikoboy': ('yoru_cameko', 'よる推しのカメコ', '📹', 'a chibi male fan photographer with a big camera and a purple bandana, cute and comedic'),
    'bishamon': ('hinata_fanmeet', 'ひなたのファンミーティング', '🎉', 'HINATA waving on a small cozy stage with balloons and happy fans below'),
    'daikoku': ('unit_panel', 'ぷりパレ全員の等身大パネル', '🌈', 'a life-size cardboard standee of all five idols (HINATA, SHIZUKU, KOHARU, YORU, MOMO) posing together'),
    'ichigoame': ('koharu_milk', 'こはるのいちごミルク', '🍓', 'a strawberry milk carton printed with chibi KOHARU'),
    'mizudeppo': ('nyan_bottle', 'ぱれにゃんボトル', '🍼', 'a light-blue water bottle printed with PARENYAN the cat mascot'),
    'kabuto': ('momo_capsule', 'もものカプセルトイ', '🥚', 'an open capsule-toy ball with a tiny MOMO figure popping out'),
    'ranchu': ('shizumomo_badge', 'しずもものペア缶バッジ', '💞', 'two overlapping can badges, one of SHIZUKU (blue rim) and one of MOMO (pink rim)'),
    'omamori': ('hinata_charm', 'ひなたの手作りお守り', '🍀', 'a handmade felt charm with a gold star and a red ribbon'),
    'fujin': ('hinata_mic', 'ひなたのセンターマイク', '🎙️', 'a sparkling red and gold idol stage microphone with ribbons'),
    'crepe': ('koharu_crepe', 'コラボクレープ', '🥞', 'a strawberry crepe with whipped cream and a tiny blank yellow flag'),
    'otedama': ('nyan_mini', 'ぱれにゃんのミニぬい', '🐾', 'three tiny PARENYAN cat-mascot plushies sitting together'),
    'suzumushi': ('momo_ribbon', 'もものリボン', '🎀', 'a big pink ribbon hair accessory with a heart charm'),
    'toro': ('shizuyoru_candle', 'しずよるの夜景キャンドル', '🏮', 'a glass lantern glowing blue and purple like a night city'),
    'miko': ('hinata_tan', 'ひなた担のオタク', '❤️', 'a chibi male fan in a red happi coat holding a heart uchiwa fan, cute and comedic'),
    'raijin': ('hinata_secret', 'ひなたのシークレット缶バッジ', '🌈', 'a rare rainbow holographic can badge of HINATA with sparkles'),
    'kushikatsu': ('koharu_gift', 'こはるの差し入れクッキー', '🎁', 'a clear cookie gift bag tied with a yellow ribbon'),
    'darumaotoshi': ('nyan_blocks', 'ぱれにゃん積み木', '🧱', 'stacked wooden toy blocks with PARENYAN cat faces'),
    'inari': ('hinamomo_ribbon', 'ひなもものおそろいリボン', '🎀', 'two matching hair ribbons, one red and one pink, tied together'),
    'ninja': ('merch_staff', '物販スタッフ', '🧢', 'a chibi energetic merch booth staff member with a cap, carrying a box of goods'),
    'hozuki': ('yoru_lantern', 'よるのランタン', '🏮', 'a purple gothic lantern with a little bat on top, glowing'),
    'kirin': ('hinamomo_figure', 'ひなももの限定フィギュア', '🏆', 'a premium scale figure of HINATA and MOMO posing on a round base inside a clear display case'),
    'ougonkingyo': ('shizumomo_sign', 'しずももの金サイン色紙', '✍️', 'a gold autograph board (shikishi) with two playful scribble signatures, hearts and stars (no readable letters)'),
    'takarabune': ('hinata_dress', 'ひなたの黄金ステージ衣装', '👑', 'a gold and red idol stage dress on a mannequin, sparkling with gems'),
    'ryu': ('hinamomo_dome', 'ひなもものドームライブ', '🏟️', 'a miniature dome stadium glowing with red and pink penlight lights'),
    'kinmaneki': ('gold_maneki', '金の招き猫ポーズアクスタ', '🐈', 'a golden acrylic stand of HINATA and MOMO doing a beckoning-cat pose, shining'),
    'hannya': ('yoru_solo', 'よるのソロ衣装', '🦇', 'a black and purple gothic idol dress with bat wings on a mannequin'),
    'kintaro': ('momo_gachikoi', 'もものガチ恋オタク', '😍', 'a chibi male fan with heart eyes hugging a MOMO plush tightly, cute and comedic'),
}
# Who appears on the capsule and speaks: the idols in the tags unless set here.
MEMBERS = ['ひなた', 'しずく', 'こはる', 'よる', 'もも']
CAST = {
    'hinakoha_stream': ['ひなた', 'こはる'],
    'unit_panel': MEMBERS,
    'yoru_tan': ['よる'], 'yoru_cameko': ['よる'], 'momo_tan': ['もも'], 'momo_gachikoi': ['もも'],
}
# 推し活レベル: the 縁日 levels squeezed so about half the goods drop from the very start
# (a wide pool from the first live makes the gacha luckier, spec: random ~10% / good play 35-50%)
LEVEL = {2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 3, 9: 5, 10: 7, 11: 9, 12: 11, 13: 12, 14: 14, 15: 15}
# effects changed from the 縁日 original: (from, to). There is no 注意書き here, so the letter that
# peeled them off pays for a ひなた altar instead.
EFFECTS = {'hinata_letter': ("OnPlacedEatAdjacentTag('のろい', 42)", "AddIfShelfTag('ひなた', 3, 12)")}
# From the very first live every member has at least one goods of each rarity: these drop from Lv1,
# and こはる (who had no ★3 at all) gets her trading card as one, as strong as ひなたのゴールド缶バッジ.
START = {'shizumomo_sign', 'unit_panel'}
RARITY = {'koharu_card': ('Rarity.normal', 'Rarity.epic')}
SET_EFFECTS = {'koharu_card': "[MultAdjacentTag('こはる', 3)]"}
IDS = {'kannushi': ('kosan', '古参オタク'), 'hyottoko': ('hinayoru_board', 'ひなよるのファンサボード')}

# 「お金」 is gone (it read like the hearts): the tag is dropped and its two effects aim elsewhere
RETARGET = {
    'hinata_dress': ("MultShelfTag('', 4)", "MultShelfTag('ひなた', 3)"),
    'gold_maneki': ("MultAdjacentTag('', 3)", "MultAdjacentTag('もも', 3)"),
    'hinamomo_maneki': ("MultAdjacentTag('', 2)", "MultAdjacentTag('ひなた', 2)"),
    # the PARENYAN piggy bank becomes a ぱれにゃん goods that likes the other ぱれにゃん
    'oshi_bank': [("tags: []", "tags: ['ぱれにゃん']"), ("AddPerShelfTag('', 2)", "AddPerShelfTag('ぱれにゃん', 2)")],
}

# Goods made here (no 縁日 original): many work on the diagonals.
# (id, name, emoji, look for the image prompt, the Dart definition)
NEW = [
    ('hinata_xpose', 'ひなたのクロスポーズアクスタ', '❌', 'an acrylic stand of chibi HINATA crossing both arms in a big X pose, red sparkles, on a clear base',
     "FigureDef(id: 'hinata_xpose', name: 'ひなたのクロスポーズアクスタ', emoji: '❌', rarity: Rarity.rare, tags: ['ひなた'], cast: ['ひなた'], effects: [AddPerDiagonalTag('ひなた', 3)])"),
    ('shizuku_snow', 'しずくの雪結晶チャーム', '❄️', 'a light-blue eight-pointed snowflake crystal charm with chibi SHIZUKU in the middle, glittering',
     "FigureDef(id: 'shizuku_snow', name: 'しずくの雪結晶チャーム', emoji: '❄️', rarity: Rarity.rare, tags: ['しずく'], cast: ['しずく'], effects: [AddPerDiagonalFigures(2)])"),
    ('koharu_checker', 'こはるのチェッククッキー', '🍪', 'a square checkerboard cookie (yellow and brown squares) with chibi KOHARU face icing in the middle',
     "FigureDef(id: 'koharu_checker', name: 'こはるのチェッククッキー', emoji: '🍪', rarity: Rarity.normal, tags: ['こはる'], cast: ['こはる'], effects: [Add(1), AddPerDiagonalTag('こはる', 2)])"),
    ('yoru_star', 'よるの四芒星ブローチ', '✴️', 'a purple four-pointed star brooch with long diagonal rays and a tiny black bat, shiny gold rim',
     "FigureDef(id: 'yoru_star', name: 'よるの四芒星ブローチ', emoji: '✴️', rarity: Rarity.epic, tags: ['よる'], cast: ['よる'], level: 3, effects: [MultDiagonal(2)])"),
    ('momo_ribbon_x', 'もものクロスリボン', '🎀', 'a big pink ribbon tied in an X cross shape with a heart charm and a tiny MOMO cat-ear tag',
     "FigureDef(id: 'momo_ribbon_x', name: 'もものクロスリボン', emoji: '🎀', rarity: Rarity.rare, tags: ['もも'], cast: ['もも'], level: 5, effects: [BuffDiagonal(2)])"),
    ('unit_sash', 'ぷりパレのたすき', '🎗️', 'a rainbow diagonal shoulder sash (tasuki) with hearts and stars, folded neatly',
     "FigureDef(id: 'unit_sash', name: 'ぷりパレのたすき', emoji: '🎗️', rarity: Rarity.normal, tags: ['ファン'], effects: [Add(1), AddPerDiagonalFigures(1)])"),
    ('nyan_hop', 'ぱれにゃんのななめジャンプ', '🐱', 'a small plush of PARENYAN (round white cat mascot) jumping diagonally with motion lines and a star trail',
     "FigureDef(id: 'nyan_hop', name: 'ぱれにゃんのななめジャンプ', emoji: '🐱', rarity: Rarity.normal, tags: ['ぱれにゃん'], effects: [AddPerDiagonalTag('ぱれにゃん', 3)])"),
    ('shizuyoru_map', 'しずよるの星座マップ', '🌌', 'a night-sky constellation map in blue and purple with diagonal star lines, tiny chibi SHIZUKU and YORU in the corners',
     "FigureDef(id: 'shizuyoru_map', name: 'しずよるの星座マップ', emoji: '🌌', rarity: Rarity.epic, tags: ['しずく', 'よる'], cast: ['しずく', 'よる'], level: 7, effects: [AddPerDiagonalFigures(4)])"),
    ('ouen_flag', 'ななめ応援フラッグ', '🚩', 'a pink cheering pennant flag on a stick, tilted diagonally, with stars and hearts',
     "FigureDef(id: 'ouen_flag', name: 'ななめ応援フラッグ', emoji: '🚩', rarity: Rarity.rare, tags: ['応援'], level: 9, effects: [BuffDiagonal(3)])"),
    ('hinakoha_bingo', 'ひなこはのビンゴカード', '🎯', 'a bingo card with a diagonal line of stamped hearts, tiny chibi HINATA and KOHARU in the corner',
     "FigureDef(id: 'hinakoha_bingo', name: 'ひなこはのビンゴカード', emoji: '🎯', rarity: Rarity.rare, tags: ['ひなた', 'こはる'], cast: ['ひなた', 'こはる'], level: 7, effects: [Add(1), AddIfDiagonalFull(16)])"),
    ('cross_penlight', 'クロスペンライト', '🔦', 'two glowing penlights crossed in an X, one pink and one cyan, light glow around them',
     "FigureDef(id: 'cross_penlight', name: 'クロスペンライト', emoji: '🔦', rarity: Rarity.epic, tags: ['応援'], level: 12, effects: [MultDiagonal(3)])"),
    ('unit_diamond', 'ぷりパレのダイヤ型ステージ模型', '💎', 'a miniature diamond-shaped stage model with five tiny idol figures (HINATA, SHIZUKU, KOHARU, YORU, MOMO) on it, sparkling lights',
     "FigureDef(id: 'unit_diamond', name: 'ぷりパレのダイヤ型ステージ模型', emoji: '💎', rarity: Rarity.legend, tags: ['ファン'], cast: ['ひなた', 'しずく', 'こはる', 'よる', 'もも'], level: 14, effects: [Add(4), MultDiagonal(4)])"),
]


def figures():
    src = SRC.read_text()
    body = src[src.index('const figures'):]
    out = []
    for old, (new, name, emoji, _) in G.items():
        pat = re.compile(r"FigureDef\(\s*id:\s*'" + old + r"'.*?\]\s*,?\s*(?:level:\s*\d+\s*,?\s*)?\)", re.S)
        m = pat.search(body)
        assert m, old
        d = m.group(0)
        d = re.sub(r"id: '[^']+'", f"id: '{new}'", d)
        if new in EFFECTS:
            d = d.replace(*EFFECTS[new])
        d = re.sub(r"name: '[^']+'", f"name: '{name}'", d)
        d = re.sub(r"emoji: '[^']+'", f"emoji: '{emoji}'", d)
        for a, b in TAGS.items():
            d = d.replace(f"'{a}'", f"'{b}'")
        d = re.sub(r"tags: \[([^\]]*)\]", lambda mm: 'tags: [' + ', '.join(t for t in (x.strip() for x in mm.group(1).split(',')) if t and t != "''") + ']', d)
        if new in RETARGET:
            for x, y in RETARGET[new] if isinstance(RETARGET[new], list) else [RETARGET[new]]:
                d = d.replace(x, y)
        for a, (b, n) in IDS.items():
            d = re.sub(r"AddIfAdjacentId\('" + a + r"', '[^']+'", f"AddIfAdjacentId('{b}', '{n}'", d)
        d = re.sub(r"\s*level: (\d+),", lambda mm: '' if LEVEL[int(mm.group(1))] == 1 else mm.group(0).replace(mm.group(1), str(LEVEL[int(mm.group(1))])), d)
        if new in START:
            d = re.sub(r"\s*level: \d+,", '', d)
        if new in RARITY:
            d = d.replace(*RARITY[new])
        if new in SET_EFFECTS:
            d = re.sub(r"effects: \[[^\]]*\]", lambda _: 'effects: ' + SET_EFFECTS[new], d)
        tags = re.search(r"tags: \[([^\]]*)\]", d).group(1)
        cast = CAST.get(new) or [m for m in MEMBERS if f"'{m}'" in tags]
        if cast:
            lst = ', '.join(f"'{m}'" for m in cast)
            d = re.sub(r"tags: \[([^\]]*)\]", lambda mm: f"tags: [{mm.group(1)}], cast: [{lst}]", d, count=1)
        out.append(d)
    head = """// 推し祭壇ガチャの駒（グッズ）。効果の数字は 縁日版（../gacha_rogue）の対応する駒と同じ。
// 生成元：art/goods.py（名前・タグ・絵の説明はそちらで直して `python3 art/goods.py figures`）。
// 画像は assets/figures/<id>.webp（art/slice.py）。無いときは emoji で代用する。
// タグ：ひなた・しずく・こはる・よる・もも（推し）／ファン・ぱれにゃん・応援

import 'defs.dart';

const figures = <FigureDef>[
"""
    out += [n[4] for n in NEW]
    text = head + ''.join('  ' + d.strip() + ',\n' for d in out) + '];\n\nfinal figureById = {for (final f in figures) f.id: f};\n'
    text = text.replace(',,', ',')
    (ROOT / 'lib' / 'logic' / 'figures.dart').write_text(text)
    print('wrote', len(out), 'figures')


STYLE = ("Style: kawaii flat 2D sticker illustrations of anime idol merchandise (goods), chunky rounded shapes, chibi characters with big sparkling anime eyes, "
         "soft pastel colors with each idol's theme color as accent, clean dark-brown outlines, each object has a thick white die-cut sticker border. "
         "Every object is centered in its own cell, same scale, fully inside the cell with generous margin, no overlap between cells. "
         "The whole background is ONE flat solid pure magenta color (#FF00FF) everywhere, no gradients, no shadows on the background, no grid lines, "
         "no text, no letters, no numbers, no watermark.")
CAST_TEXT = ("The characters are from the attached reference sheet — draw them with exactly these designs (hair, colors, accessories): "
        "HINATA (red-orange theme, orange-brown high side ponytail with a big red ribbon and a gold star clip), "
        "SHIZUKU (sky-blue theme, long straight navy hair with hime cut, water-drop earrings), "
        "KOHARU (yellow theme, wavy honey-blonde bob with a white flower clip, sleepy eyes), "
        "YORU (purple theme, black twin tails with purple tips, bat-wing hair clip, small fang), "
        "MOMO (pink theme, fluffy pastel-pink hair with a pink cat-ear headband), "
        "TSUMUGI (green theme, short chestnut bob with a green hairpin, deadpan half-lidded eyes). "
        "PARENYAN is the idol unit's mascot: a round chubby white cat with a tiny rainbow star on its forehead.")


def prompts():
    gen = ROOT / 'art' / 'gen'
    items = list(G.values())
    sheets = {}
    for k in range(0, len(items), 12):
        part = items[k:k + 12]
        name = f'goods{k // 12 + 1}'
        lines = '\n'.join(f'{i + 1} {look}' for i, (_, _, _, look) in enumerate(part))
        (gen / f'{name}.txt').write_text(
            f"Create one image 1536x1024: a sprite sheet laid out as an exact grid of 4 columns x 3 rows (12 cells of equal size). "
            f"Collectible goods of an original anime idol unit, one per cell, in this order left-to-right, top-to-bottom:\n{lines}\n{CAST_TEXT}\n{STYLE}\n")
        (gen / f'{name}.refs').write_text(str(gen / 'chars_ref.png') + '\n')
        sheets[name] = [n for n, _, _, _ in part]
    # the goods made here get sheets of their own after the 縁日 ones (so those keep their cells)
    for k in range(0, len(NEW), 12):
        part = NEW[k:k + 12]
        name = f'goods_new{k // 12 + 1}'
        lines = '\n'.join(f'{i + 1} {look}' for i, (_, _, _, look, _) in enumerate(part))
        (gen / f'{name}.txt').write_text(
            f"Create one image 1536x1024: a sprite sheet laid out as an exact grid of 4 columns x 3 rows (12 cells of equal size). "
            f"Collectible goods of an original anime idol unit, one per cell, in this order left-to-right, top-to-bottom:\n{lines}\n{CAST_TEXT}\n{STYLE}\n")
        (gen / f'{name}.refs').write_text(str(gen / 'chars_ref.png') + '\n')
        sheets[name] = [n for n, _, _, _, _ in part]
    (gen / 'sheets.json').write_text(json.dumps(sheets, indent=1))
    print('wrote', list(sheets))


if __name__ == '__main__':
    {'figures': figures, 'prompts': prompts}[sys.argv[1]]()
