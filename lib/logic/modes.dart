// Machines and ascension (段位) (spec 02 §5).
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
  double curseRate; // chance a pull is the boss's card instead
  int choose;
  int coins;
  int removeTickets;
  bool cardEveryPayday;
  double priceMult;
  bool canExpand;
  int curseExtra; // extra minus on the boss's card
  bool noContinue;
  int level; // the player's festival level: only figures unlocked by it drop

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
    UnlockKind.bestTurn => '1回転で$unlockNコイン以上かせぐ',
    UnlockKind.paydays => '1回のプレイで取り立てを$unlockN回払う',
    UnlockKind.clears => '$unlockN回 完済する',
    UnlockKind.level => '縁日レベル $unlockN で解放',
  };
}

final machines = <MachineDef>[
  MachineDef(id: 'ennichi', name: '縁日ガチャ', blurb: 'いつものガチャ。なんでも出る', hue: 0, perks: const ['ぜんぶの駒が同じくらい出る'], apply: (r) {}),
  MachineDef(
    id: 'mizu',
    name: '水まつりガチャ',
    blurb: '金魚すくいの屋台の横にあるやつ',
    hue: 180,
    unlock: UnlockKind.level,
    unlockN: 3,
    perks: const ['「水」「動物」がすごく出る', '棚が横長（5×3）', '金魚からスタート', '取り立て +50%'],
    apply: (r) {
      r.tagWeight = {'水': 10, '動物': 6}; // about 2 in 3 pulls (縁日ガチャ: 1 in 5)
      r.dueMult = 1.5; // the water combos pay well, so the boss asks for more
      r.cols = 5;
      r.rows = 3;
      r.start = ['kingyo'];
    },
  ),
  MachineDef(
    id: 'kuishinbo',
    name: '食いしん坊ガチャ',
    blurb: 'ソースのにおいがする',
    hue: 35,
    unlock: UnlockKind.level,
    unlockN: 5,
    perks: const ['「食べ物」がよく出る', 'たこ焼きからスタート', '取り立て +30%'],
    apply: (r) {
      r.tagWeight = {'食べ物': 3};
      r.start = ['takoyaki'];
      r.dueMult *= 1.3;
    },
  ),
  MachineDef(
    id: 'engi',
    name: '縁起ガチャ',
    blurb: '神社の境内に置いてある',
    hue: 320,
    unlock: UnlockKind.level,
    unlockN: 7,
    perks: const ['「縁起」がよく出る', '運 +10%', '取り立て +30%'],
    apply: (r) {
      r.tagWeight = {'縁起': 3};
      r.luck += 10;
      r.dueMult *= 1.3;
    },
  ),
  MachineDef(
    id: 'ayashii',
    name: '妖しいガチャ',
    blurb: '夜にだけ出る。親分も近寄らない',
    hue: 260,
    unlock: UnlockKind.level,
    unlockN: 10,
    perks: const ['ガチャから名刺が出る（7%）', '「道具」がよく出る', 'コイン25でスタート'],
    apply: (r) {
      r.curseRate = 0.07;
      r.tagWeight = {'道具': 2.5};
      r.coins = 25;
    },
  ),
  MachineDef(
    id: 'kinpika',
    name: '金ぴかガチャ',
    blurb: '全部金色。目がチカチカする',
    hue: 50,
    unlock: UnlockKind.level,
    unlockN: 13,
    perks: const ['運 +25%', '取り立て +35%'],
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
  '取り立て +10%',
  '親分が取り立てのたびに名刺を置いていく',
  'どける券なしでスタート',
  '夜店の値段 +25%',
  '取り立て +25%（合計）',
  'レアが出にくい（運 -6%）',
  '棚を広げられない',
  '名刺が もっと痛い（毎回 -4）',
  '取り立て +45%（合計）',
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
