// Machines (推し別のガチャ) (spec 02 §5). A machine only changes the numbers
// in [Rules]; run.dart reads Rules and never knows which machine produced
// them, so tool/sim.dart can balance any of them.

import 'figures.dart';

/// The altar every live starts with (and the size of its frame on screen).
const defaultSide = 4;

/// Everything a run needs to know about how it is set up.
class Rules {
  Map<String, double> tagWeight;
  Map<String, double> idWeight;
  int cols, rows;
  List<String> start;
  int luck;
  double dueMult;
  double thirdDueMult; // the third song's quota is multiplied again (a wall there; song 4 grows from the usual curve)
  int choose;
  int coins;
  double priceMult;
  bool canExpand;
  bool noContinue;
  int level; // the player's 推し活 level: only figures unlocked by it drop
  double jamRate; // chance of a 妨害 each turn
  double jamPower; // how much harder than usual the 妨害 pushes

  Rules({
    Map<String, double>? tagWeight,
    Map<String, double>? idWeight,
    this.cols = defaultSide,
    this.rows = defaultSide,
    List<String>? start,
    this.luck = 0,
    this.dueMult = 1,
    this.thirdDueMult = 1,
    this.choose = 1,
    this.coins = 5,
    this.priceMult = 1,
    this.canExpand = true,
    this.noContinue = false,
    this.level = 999,
    this.jamRate = 0.05,
    this.jamPower = 1,
  }) : tagWeight = tagWeight ?? {},
       idWeight = idWeight ?? {},
       start = start ?? [];

  double weightOf(String id) {
    final f = figureById[id]!;
    var w = idWeight[id] ?? 1;
    var tw = 1.0;
    for (final t in f.tags) {
      final x = tagWeight[t];
      if (x != null && x > tw) tw = x;
    }
    return w * tw;
  }
}

// ── machines ──

enum UnlockKind { none, seen, bestTurn, paydays, clears, level }

/// How hard a machine is, 1..5 (from tool/sim.dart's clear rates).
const difficultyLabel = ['', 'かんたん', 'ふつう', 'むずかしい', 'げきむず', 'おに'];

class MachineDef {
  final String id, name, blurb;
  final double hue; // tint of the machine art, degrees
  final int difficulty; // 1..5
  final String bgm; // assets/bgm/bgm_<bgm>.m4a
  final UnlockKind unlock;
  final int unlockN;
  final void Function(Rules r) apply;
  final List<String> perks; // shown on the select screen
  const MachineDef({
    required this.id,
    required this.name,
    required this.blurb,
    required this.hue,
    required this.difficulty,
    required this.apply,
    required this.perks,
    String? bgm,
    this.unlock = UnlockKind.none,
    this.unlockN = 0,
  }) : bgm = bgm ?? id;

  String get difficultyText => difficultyLabel[difficulty];

  String get unlockText => switch (unlock) {
    UnlockKind.none => '',
    UnlockKind.seen => '図鑑を$unlockN種あつめる',
    UnlockKind.bestTurn => '1回転でハートを$unlockN以上集める',
    UnlockKind.paydays => '1回のライブで$unlockN曲成功する',
    UnlockKind.clears => '$unlockN回 完済する',
    UnlockKind.level => '推し活レベル $unlockN で解放',
  };
}

final machines = <MachineDef>[
  MachineDef(
    id: 'pripare',
    name: 'ぷりパレガチャ',
    blurb: '会場のロビーにある いつものガチャ',
    hue: 0,
    difficulty: 2,
    bgm: 'title', // the title screen's song, also the lobby gacha's
    perks: const ['5人のグッズが 同じくらい出る'],
    apply: (r) {},
  ),
  MachineDef(
    id: 'otameshi',
    name: 'おためしガチャ',
    blurb: 'はじめての人に やさしい練習用',
    hue: 140,
    difficulty: 1,
    bgm: 'lobby', // the five-voice lobby song (art/songs/harmony.py bgm_lobby), moved here from ぷりパレ
    perks: const ['ノルマ -30%', '妨害が来ない'],
    apply: (r) {
      r.dueMult = 0.7;
      r.jamRate = 0;
    },
  ),
  MachineDef(
    id: 'shizumomo',
    name: 'しずももガチャ',
    blurb: 'しずくとももの コンビ推し向け',
    hue: 200,
    difficulty: 2,
    unlock: UnlockKind.level,
    unlockN: 3,
    perks: const ['「しずく」「もも」がすごく出る', 'ラバストからスタート', 'ノルマ +50%'],
    apply: (r) {
      r.tagWeight = {'しずく': 10, 'もも': 6}; // about 2 in 3 pulls (ぷりパレガチャ: 1 in 5)
      r.dueMult = 1.5; // the pair combos pay well, so the quota goes up
      r.start = ['shizumomo_strap'];
    },
  ),
  MachineDef(
    id: 'koharu',
    name: 'こはる推しガチャ',
    blurb: 'ほんのり あまいにおいがする',
    hue: 40,
    difficulty: 2,
    unlock: UnlockKind.level,
    unlockN: 5,
    perks: const ['「こはる」がよく出る', 'アクキーからスタート', 'ノルマ +30%'],
    apply: (r) {
      r.tagWeight = {'こはる': 3};
      r.start = ['koharu_keyholder'];
      r.dueMult *= 1.3;
    },
  ),
  MachineDef(
    id: 'hinata',
    name: 'ひなた推しガチャ',
    blurb: 'センターの笑顔で 運が上がる',
    hue: 330,
    difficulty: 3,
    unlock: UnlockKind.level,
    unlockN: 6,
    perks: const ['「ひなた」がよく出る', '運 +10%', 'ノルマ +30%'],
    apply: (r) {
      r.tagWeight = {'ひなた': 3};
      r.luck += 10;
      r.dueMult *= 1.3;
    },
  ),
  MachineDef(
    id: 'shizuku',
    name: 'しずく推しガチャ',
    blurb: '水色のカプセルが しずかに光る',
    hue: 185,
    difficulty: 2,
    bgm: 'shizumomo',
    unlock: UnlockKind.level,
    unlockN: 7,
    perks: const ['「しずく」がよく出る', 'ノルマ +10%'],
    apply: (r) {
      r.tagWeight = {'しずく': 3};
      r.dueMult *= 1.1;
    },
  ),
  MachineDef(
    id: 'momo',
    name: 'もも推しガチャ',
    blurb: 'ハートのシールで デコられている',
    hue: 310,
    difficulty: 2,
    bgm: 'shizumomo',
    unlock: UnlockKind.level,
    unlockN: 8,
    perks: const ['「もも」がよく出る', 'ノルマ +5%'],
    apply: (r) {
      r.tagWeight = {'もも': 3};
      r.dueMult *= 1.05;
    },
  ),
  MachineDef(
    id: 'nyan',
    name: 'ぱれにゃんガチャ',
    blurb: 'マスコットのぱれにゃんが いっぱい',
    hue: 95,
    difficulty: 3,
    bgm: 'pripare',
    unlock: UnlockKind.level,
    unlockN: 9,
    perks: const ['「ぱれにゃん」がよく出る', 'ノルマ +20%'],
    apply: (r) {
      r.tagWeight = {'ぱれにゃん': 3};
      r.dueMult *= 1.2;
    },
  ),
  MachineDef(
    id: 'yoru',
    name: 'よる推しガチャ',
    blurb: 'ライブ後の真夜中だけ動く',
    hue: 270,
    difficulty: 3,
    unlock: UnlockKind.level,
    unlockN: 10,
    perks: const ['「よる」がよく出る', 'ハート25でスタート', 'ノルマ +25%'],
    apply: (r) {
      r.tagWeight = {'よる': 2.5};
      r.coins = 25;
      r.dueMult *= 1.25;
    },
  ),
  MachineDef(
    id: 'fan',
    name: 'ファンミーティングガチャ',
    blurb: 'オタクたちの熱気で ムンムンしている',
    hue: 20,
    difficulty: 4,
    bgm: 'hinata',
    unlock: UnlockKind.level,
    unlockN: 11,
    perks: const ['「ファン」がよく出る', '妨害が多い（10%）', 'ノルマ +45%'],
    apply: (r) {
      r.tagWeight = {'ファン': 3};
      r.jamRate = 0.10;
      r.dueMult *= 1.45;
    },
  ),
  MachineDef(
    id: 'premium',
    name: 'プレミアムガチャ',
    blurb: '全部キラキラ。目がチカチカする',
    hue: 50,
    difficulty: 3,
    unlock: UnlockKind.level,
    unlockN: 12,
    perks: const ['運 +25%', 'ノルマ +60%'],
    apply: (r) {
      r.luck += 25;
      r.dueMult *= 1.6;
    },
  ),
  MachineDef(
    id: 'tenbai',
    name: '転売ヤー警戒ガチャ',
    blurb: 'カイシメが 何度も乗りこんでくる',
    hue: 240,
    difficulty: 4,
    unlock: UnlockKind.level,
    unlockN: 13,
    perks: const ['妨害がとても多い（25%）', '妨害の押しが強い', 'ノルマ +30%'],
    apply: (r) {
      r.jamRate = 0.25;
      r.jamPower = 1.6;
      r.dueMult *= 1.3;
    },
  ),
  MachineDef(
    id: 'dome',
    name: 'ドームツアーガチャ',
    blurb: '最高の舞台。最高にきびしい',
    hue: 290,
    difficulty: 5,
    unlock: UnlockKind.level,
    unlockN: 15,
    perks: const ['ノルマ +50%', '3曲目のノルマが 超きびしい', '祭壇を広げられない', '妨害が多い（10%）', '延長できない'],
    apply: (r) {
      r.dueMult *= 1.5;
      r.thirdDueMult = 3.5; // about 9 in 10 good players fall at song 3
      r.canExpand = false;
      r.jamRate = 0.10;
      r.noContinue = true;
    },
  ),
];

final machineById = {for (final m in machines) m.id: m};

Rules rulesFor(MachineDef m) {
  final r = Rules();
  m.apply(r);
  return r;
}
