// Machines (推し別のガチャ) and ascension (段位) (spec 02 §5).
// Both only change the numbers in [Rules]; run.dart reads Rules and
// never knows which mode produced them, so tool/sim.dart can balance any mix.

import 'figures.dart';

/// Everything a run needs to know about how it is set up.
class Rules {
  Map<String, double> tagWeight;
  Map<String, double> idWeight;
  int cols, rows;
  List<String> start;
  int luck;
  double dueMult;
  double curseRate; // chance a pull is つむぎの注意書き instead
  int choose;
  int coins;
  int removeTickets;
  bool cardEveryPayday;
  double priceMult;
  bool canExpand;
  int curseExtra; // extra minus on つむぎの注意書き
  bool noContinue;
  int level; // the player's 推し活 level: only figures unlocked by it drop

  Rules({
    Map<String, double>? tagWeight,
    Map<String, double>? idWeight,
    this.cols = 4,
    this.rows = 4,
    List<String>? start,
    this.luck = 0,
    this.dueMult = 1,
    this.curseRate = 0,
    this.choose = 1,
    this.coins = 5,
    this.removeTickets = 1,
    this.cardEveryPayday = false,
    this.priceMult = 1,
    this.canExpand = true,
    this.curseExtra = 0,
    this.noContinue = false,
    this.level = 999,
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

class MachineDef {
  final String id, name, blurb;
  final double hue; // tint of the machine art, degrees
  final UnlockKind unlock;
  final int unlockN;
  final void Function(Rules r) apply;
  final List<String> perks; // shown on the select screen
  const MachineDef({
    required this.id,
    required this.name,
    required this.blurb,
    required this.hue,
    required this.apply,
    required this.perks,
    this.unlock = UnlockKind.none,
    this.unlockN = 0,
  });

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
  MachineDef(id: 'pripare', name: 'ぷりパレガチャ', blurb: '会場のロビーにある いつものガチャ', hue: 0, perks: const ['5人のグッズが 同じくらい出る'], apply: (r) {}),
  MachineDef(
    id: 'shizumomo',
    name: 'しずももガチャ',
    blurb: 'しずくとももの コンビ推し向け',
    hue: 200,
    unlock: UnlockKind.level,
    unlockN: 3,
    perks: const ['「しずく」「もも」がすごく出る', '祭壇が横長（5×3）', 'ラバストからスタート', 'ノルマ +50%'],
    apply: (r) {
      r.tagWeight = {'しずく': 10, 'もも': 6}; // about 2 in 3 pulls (ぷりパレガチャ: 1 in 5)
      r.dueMult = 1.5; // the pair combos pay well, so the rent goes up
      r.cols = 5;
      r.rows = 3;
      r.start = ['shizumomo_strap'];
    },
  ),
  MachineDef(
    id: 'koharu',
    name: 'こはる推しガチャ',
    blurb: 'ほんのり あまいにおいがする',
    hue: 40,
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
    unlock: UnlockKind.level,
    unlockN: 7,
    perks: const ['「ひなた」がよく出る', '運 +10%', 'ノルマ +30%'],
    apply: (r) {
      r.tagWeight = {'ひなた': 3};
      r.luck += 10;
      r.dueMult *= 1.3;
    },
  ),
  MachineDef(
    id: 'yoru',
    name: 'よるの真夜中ガチャ',
    blurb: 'ライブ後の真夜中だけ動く',
    hue: 270,
    unlock: UnlockKind.level,
    unlockN: 10,
    perks: const ['ガチャから注意書きが出る（7%）', '「よる」がよく出る', 'ハート25でスタート', 'ノルマ +10%'],
    apply: (r) {
      r.curseRate = 0.07;
      r.tagWeight = {'よる': 2.5}; // よる's goods combo better than the 縁日 tools did, so the rent goes up
      r.coins = 25;
      r.dueMult *= 1.1;
    },
  ),
  MachineDef(
    id: 'premium',
    name: 'プレミアムガチャ',
    blurb: '全部キラキラ。目がチカチカする',
    hue: 50,
    unlock: UnlockKind.level,
    unlockN: 13,
    perks: const ['運 +25%', 'ノルマ +35%'],
    apply: (r) {
      r.luck += 25;
      r.dueMult *= 1.35;
    },
  ),
];

final machineById = {for (final m in machines) m.id: m};

// ── ascension ──

const maxAscension = 10;

const ascensionText = [
  'ふつう',
  'ノルマ +10%',
  'つむぎが 1曲ごとに注意書きを置いていく',
  'どける なしでスタート',
  '物販の値段 +25%',
  'ノルマ +25%（合計）',
  'Rが出にくい（運 -6%）',
  '祭壇を広げられない',
  '注意書きが もっと痛い（毎回 -4）',
  'ノルマ +45%（合計）',
  '待ってもらえない（コンティニューなし）',
];

void applyAscension(Rules r, int n) {
  if (n >= 1) r.dueMult *= n >= 9 ? 1.45 : (n >= 5 ? 1.25 : 1.10);
  if (n >= 2) r.cardEveryPayday = true;
  if (n >= 3) r.removeTickets = 0;
  if (n >= 4) r.priceMult *= 1.25;
  if (n >= 6) r.luck -= 6;
  if (n >= 7) r.canExpand = false;
  if (n >= 8) r.curseExtra = 2;
  if (n >= 10) r.noContinue = true;
}

Rules rulesFor(MachineDef m, int ascension) {
  final r = Rules();
  m.apply(r);
  applyAscension(r, ascension);
  return r;
}
