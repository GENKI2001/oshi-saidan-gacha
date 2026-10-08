// One roguelite run: gacha → shelf → scoring → payday → shop (spec 02 §3).
// Pure Dart with no Flutter imports, so tool/sim.dart can play thousands of
// runs headlessly to balance figures and dues (spec 02 §9).

import 'dart:math' as math;

import '../l10n/l10n.dart';
import 'defs.dart';
import 'figures.dart';
import 'modes.dart';

/// Small seeded RNG whose state can be copied (for bot look-ahead).
class Rng {
  int _s;
  Rng(int seed) : _s = (seed & 0x7fffffff) == 0 ? 0x2545F491 : seed & 0x7fffffff;
  Rng._copy(this._s);
  Rng copy() => Rng._copy(_s);

  int _next() {
    // Park–Miller; stays inside 2^31 so it behaves the same on VM and web.
    _s = (_s * 48271) % 0x7fffffff;
    return _s;
  }

  int nextInt(int n) => _next() % n;
  double nextDouble() => _next() / 0x7fffffff;
  T pick<T>(List<T> xs) => xs[nextInt(xs.length)];
}

class Fig {
  final FigureDef def;
  final int uid;
  int age = 0;
  int lastGain = 0;
  int stack = 1; // the same goods put on top of it: its numbers are ×stack (×2, ×3, …)
  Fig(this.def, this.uid);
  Fig copy() => Fig(def, uid)
    ..age = age
    ..lastGain = lastGain
    ..stack = stack;

  /// A multiplier [f] of a stacked goods grows with the stack: ×3 stacked twice is ×6, ×2 three times ×6.
  int factor(int f) => f * stack;
}

enum StepKind { add, buff, mult, shoot, remove, spawn, instant, copy }

/// One beat of the scoring animation. [idx] is the acting cell.
class Step {
  final StepKind kind;
  final int idx;
  final int amount; // coins (add/buff/shoot/instant) or factor (mult)
  final List<int> targets;
  final Fig? fig; // spawned figure
  const Step(this.kind, this.idx, {this.amount = 0, this.targets = const [], this.fig});
}

/// What a 妨害 does if he gets through.
enum JamKind {
  steal, // takes one of the goods off the altar
  stealTwo, // takes two
  noRepull, // no もう一回ひく until the song ends
  half, // hearts are halved until the song ends
  hearts, // knocks [Jam.pct]% of the hearts away
}

/// What fending him off brings.
enum JamReward {
  hearts, // hearts ×2 until the song ends
  goods, // a goods that suits this gacha ([Jam.gift])
  luck, // 運 +10% for the rest of the live
  repull, // もう一回ひく +1 (this song)
}

class Jam {
  final JamKind kind;

  /// How hard he pushes (1 = normal): the player has to mash harder.
  final double power;
  final int pct;
  final JamReward reward;
  final FigureDef? gift;
  const Jam(this.kind, this.power, {this.pct = 0, this.reward = JamReward.hearts, this.gift});

  String get rewardText => en
      ? switch (reward) {
          JamReward.hearts => 'Hearts ×2 for this song',
          JamReward.goods => 'You get ★${gift!.rarity.index + 1} "${gift!.name}"',
          JamReward.luck => 'Luck +10%',
          JamReward.repull => 'Re-pull +1',
        }
      : switch (reward) {
          JamReward.hearts => 'この曲のハートが ×2',
          JamReward.goods => '★${gift!.rarity.index + 1}「${gift!.name}」がもらえる',
          JamReward.luck => '運が +10%',
          JamReward.repull => '「もう一回ひく」が +1',
        };

  String get text => en
      ? switch (kind) {
          JamKind.steal => 'He steals one of your goods',
          JamKind.stealTwo => 'He steals two of your goods',
          JamKind.noRepull => 'No Re-pull for this song',
          JamKind.half => 'Hearts halved for this song',
          JamKind.hearts => 'He takes $pct% of your Hearts',
        }
      : switch (kind) {
          JamKind.steal => 'グッズを1つ 持っていかれる',
          JamKind.stealTwo => 'グッズを2つ 持っていかれる',
          JamKind.noRepull => 'この曲は「もう一回ひく」が使えない',
          JamKind.half => 'この曲のハートが 半分になる',
          JamKind.hearts => 'ハートを $pct% 持っていかれる',
        };
}

class TurnResult {
  final List<Step> steps;
  final int total;
  final Map<int, int> gains; // final coins per cell
  TurnResult(this.steps, this.total, this.gains);
}

class PaydayResult {
  final int due, bonus, coinsBefore;
  final bool paid;
  PaydayResult(this.due, this.bonus, this.coinsBefore, this.paid);
}

enum OfferKind {
  figure,
  luck,
  boost,
  repullTicket,
  rerollTicket,
  expand,
  // レア商品: only now and then at the stall, and never the free first pick
  extraSpin, // one more spin every song, for the rest of the live
  rareSong, // the next song only drops R and up
  idolSong, // the next song only drops [Offer.idol]'s goods
}

class Offer {
  final OfferKind kind;
  final int price;
  final FigureDef? fig;
  final String? idol; // boost: whose goods come out more
  bool sold = false;
  Offer(this.kind, this.price, [this.fig, this.idol]);

  String get title => en
      ? switch (kind) {
          OfferKind.figure => fig!.name,
          OfferKind.luck => "Tsumugi's Good-Luck Charm",
          OfferKind.boost => '${tr(idol!)} Rate-Up',
          OfferKind.repullTicket => 'Re-pull +1',
          OfferKind.rerollTicket => 'Restock +1',
          OfferKind.expand => 'Bigger Altar',
          OfferKind.extraSpin => 'Encore Magic',
          OfferKind.rareSong => 'Sparkle Ticket',
          OfferKind.idolSong => '${tr(idol!)} Ticket',
        }
      : switch (kind) {
          OfferKind.figure => fig!.name,
          OfferKind.luck => 'つむぎのおまじない',
          OfferKind.boost => '$idolの出現率UP',
          OfferKind.repullTicket => 'もう一回ひく +1',
          OfferKind.rerollTicket => '品がえ +1',
          OfferKind.expand => '祭壇を広げる',
          OfferKind.extraSpin => 'アンコールの魔法',
          OfferKind.rareSong => 'キラキラ確定チケット',
          OfferKind.idolSong => '$idol確定チケット',
        };

  /// A レア商品 (shown with its own badge).
  bool get rare => kind == OfferKind.extraSpin || kind == OfferKind.rareSong || kind == OfferKind.idolSong;

  String get text => en
      ? switch (kind) {
          OfferKind.figure => fig!.description,
          OfferKind.luck => '★2+ comes more often (+8%)',
          OfferKind.boost => '${tr(idol!)} goods come more often (×${Run.boostStep.round()})',
          OfferKind.repullTicket => 'One more Re-pull per song (up to 5)',
          OfferKind.rerollTicket => 'One more Restock per visit (up to 3)',
          OfferKind.expand => 'Adds cells to the altar',
          OfferKind.extraSpin => '+1 spin every song, for the rest of the live',
          OfferKind.rareSong => 'Next song: only ★2+ comes out',
          OfferKind.idolSong => 'Next song: only ${tr(idol!)} goods come out',
        }
      : switch (kind) {
          OfferKind.figure => fig!.description,
          OfferKind.luck => 'R以上が出やすくなる（+8%）',
          OfferKind.boost => '「$idol」のグッズが よく出る（×${Run.boostStep.round()}）',
          OfferKind.repullTicket => '「もう一回ひく」が1回ふえる（最大5回）',
          OfferKind.rerollTicket => '「品がえ」が1回ふえる（最大3回）',
          OfferKind.expand => '祭壇のマスが増える',
          OfferKind.extraSpin => '1曲で回せる回数が ずっと +1',
          OfferKind.rareSong => '次の曲のあいだ R以上しか出ない',
          OfferKind.idolSong => '次の曲のあいだ「$idol」のグッズしか出ない',
        };
}

const _idols = ['ひなた', 'しずく', 'こはる', 'よる', 'もも'];

class Run {
  static const turnsPerPayday = 5;
  // 取り立て grows by the same factor every time
  static const firstDue = 17; // raised from 14 with the diagonal goods, stacking and the レア商品 (random ~10%, good play ~40%)
  /// Every quota ×0.7: the whole game made easier (2026-10: ×0.9, ×0.8, then ×0.7).
  static const ease = 0.7;
  static const dueGrowth = 3.95;
  static const clearPaydays = 4;

  final Rng rng;
  final Rules rules;
  int cols, rows;
  late List<Fig?> cells;
  int coins = 5;
  int earned = 0; // all coins made this run
  int turn = 0; // completed turns
  int paydaysPaid = 0;
  int carriedDebt = 0;
  int luckBonus = 0;
  int choose = 1;
  // 品がえ starts at 1 use per visit and the stall can raise it to [maxUses].
  static const maxUses = 3;
  static const maxRepulls = 5; // もう一回ひく can grow further
  bool continueUsed = false;
  int bestTurn = 0;
  int turnsPerSong = turnsPerPayday; // spins in a song (アンコールの魔法 adds one)
  int songTurn = 0; // spins done in this song
  static const maxTurnsPerSong = turnsPerPayday + 1; // the extra spin can be bought once
  bool rareSong = false; // キラキラ確定チケット: this song drops R and up only
  String? idolSong; // ○○確定チケット: this song drops only her goods
  int _uid = 0;
  final Set<String> seen = {};
  List<Offer> shop = [];
  // 品がえ at the stall: free, [rerollMax] times per visit (1, up to [maxUses] with upgrades)
  int rerollMax = 1, rerolls = 1;

  Run({int seed = 1, Rules? rules})
    : rules = rules ?? Rules(),
      rng = Rng(seed),
      cols = (rules ?? Rules()).cols,
      rows = (rules ?? Rules()).rows {
    cells = List.filled(cols * rows, null);
    coins = this.rules.coins;
    luckBonus = this.rules.luck;
    choose = this.rules.choose;
    // starting figures go near the middle
    final order = [for (var i = 0; i < size; i++) i]..sort((a, b) => _centerDist(a).compareTo(_centerDist(b)));
    for (var k = 0; k < this.rules.start.length && k < size; k++) {
      cells[order[k]] = _newFig(figureById[this.rules.start[k]]!);
    }
  }

  double _centerDist(int i) {
    final dy = rowOf(i) - (rows - 1) / 2, dx = colOf(i) - (cols - 1) / 2;
    return dx * dx + dy * dy + i * 1e-3;
  }

  Run._raw(this.rng, this.rules, this.cols, this.rows);

  Run clone() {
    final r = Run._raw(rng.copy(), rules, cols, rows)
      ..cells = [for (final c in cells) c?.copy()]
      ..coins = coins
      ..earned = earned
      ..turn = turn
      ..paydaysPaid = paydaysPaid
      ..carriedDebt = carriedDebt
      ..luckBonus = luckBonus
      ..choose = choose
      ..expansions = expansions
      ..repulls = repulls
      ..repullMax = repullMax
      ..rerollMax = rerollMax
      ..rerolls = rerolls
      ..continueUsed = continueUsed
      ..halfThisSong = halfThisSong
      ..doubleThisSong = doubleThisSong
      ..boost.addAll(boost)
      ..bestTurn = bestTurn
      ..turnsPerSong = turnsPerSong
      ..songTurn = songTurn
      ..shelfMultsUsed = shelfMultsUsed
      ..took.addAll(took)
      ..rareSong = rareSong
      ..idolSong = idolSong
      .._uid = _uid;
    return r;
  }

  // ── board helpers ──
  int get size => cols * rows;
  int rowOf(int i) => i ~/ cols;
  int colOf(int i) => i % cols;
  bool isCorner(int i) => (rowOf(i) == 0 || rowOf(i) == rows - 1) && (colOf(i) == 0 || colOf(i) == cols - 1);

  List<int> neighbors(int i) {
    final r = rowOf(i), c = colOf(i), out = <int>[];
    // up, down, left, right (no diagonals)
    for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) out.add(nr * cols + nc);
    }
    return out;
  }

  /// The (up to) four cells touching [i] corner to corner.
  List<int> diagonals(int i) {
    final r = rowOf(i), c = colOf(i), out = <int>[];
    for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
      final nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) out.add(nr * cols + nc);
    }
    return out;
  }

  /// The ビンゴ line of [AddIfDiagonalFull]: [i] and the cells up and to the right of it, four in all
  /// (shorter when it runs off the altar). Works on any width: it steps one row up, one column right.
  List<int> bingoLine(int i) {
    final out = <int>[];
    for (var k = 0; k < 4; k++) {
      final r = rowOf(i) - k, c = colOf(i) + k;
      if (r < 0 || c >= cols) break;
      out.add(r * cols + c);
    }
    return out;
  }

  List<int> get emptyCells => [
    for (var i = 0; i < size; i++)
      if (cells[i] == null) i,
  ];
  Iterable<Fig> get figs => cells.whereType<Fig>();
  int shelfTag(String tag) => figs.where((f) => f.def.tags.contains(tag)).length;

  /// How many goods on the altar each member is on.
  Map<String, int> castCounts() {
    final count = <String, int>{};
    for (final f in figs) {
      for (final m in f.def.cast) {
        count[m] = (count[m] ?? 0) + 1;
      }
    }
    return count;
  }

  /// The member with the most goods on the altar (null while none is on it).
  String? get topCast {
    final count = castCounts();
    return count.isEmpty ? null : (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  int get luck => luckBonus + figs.fold(0, (s, f) => s + (f.def.effect<Luck>()?.v ?? 0));

  // ── payday ──
  int get turnsToPayday => turnsPerSong - songTurn;
  bool get paydayNow => songTurn >= turnsPerSong;
  bool get cleared => paydaysPaid >= clearPaydays;

  /// The quota of song i+1: ×[dueGrowth] a song up to the 4th, then from the アンコール the growth
  /// itself goes up ×[encoreGrowth] a song (×5.9, ×8.9, ×13.3, …), so a strong altar (about ×6 a
  /// song) keeps up for an encore or so and then can't.
  int baseDue(int i) {
    var due = firstDue * ease * math.pow(dueGrowth, math.min(i, clearPaydays - 1));
    for (var k = 1; k <= i - (clearPaydays - 1); k++) {
      due *= dueGrowth * math.pow(encoreGrowth, k);
    }
    return due.round();
  }

  static const encoreGrowth = 1.5;

  int get due {
    var f = 1.0;
    for (final x in figs) {
      final d = x.def.effect<PaydayDiscount>();
      if (d != null) f *= 1 - d.pct / 100;
    }
    final wall = paydaysPaid == 2 ? rules.thirdDueMult : 1.0;
    return (baseDue(paydaysPaid) * rules.dueMult * wall * math.max(f, 0.4)).round() + carriedDebt;
  }

  // ── gacha ──
  /// Hidden luck that grows with every payday paid (not shown as 運 +N%).
  static const paydayLuck = 5;

  List<double> get rarityWeights {
    final l = (luck + paydaysPaid * paydayLuck).toDouble();
    return [math.max(20, 62 - l), 27 + l * 0.6, 9 + l * 0.3, 2 + l * 0.1];
  }

  /// What can drop now. Goods that cut the quota stop dropping (and leave the stall) once
  /// [maxDiscounts] of them are on the altar; goods that multiply the whole altar once
  /// [maxShelfMults] of them are.
  List<FigureDef> _unlocked(Rarity r) {
    final capped = figs.where((f) => f.def.has<PaydayDiscount>()).length >= maxDiscounts;
    final multsFull = shelfMultsFull;
    return figures
        .where((f) => f.rarity == r && (rules.open?.contains(f.id) ?? true) && !(capped && f.has<PaydayDiscount>()) && !(multsFull && isShelfMult(f)) && !_tookOnly(f))
        .toList();
  }

  static const maxDiscounts = 2;

  /// Goods that multiply across the whole altar (the deck payoffs: 箱推し, 単推し, a tag once there are
  /// enough of it, the one-shot [Fuse]). A live uses at most [maxShelfMults] of them in all, stacking
  /// included and taking one off giving nothing back, so they can't snowball.
  static bool isShelfMult(FigureDef f) =>
      f.effects.any((e) => e is MultIfAllMembers || e is MultIfOnly || e is MultShelfTagIfCount || e is Fuse);
  static const maxShelfMults = 4;
  int shelfMultsUsed = 0; // placed or stacked this live
  bool get shelfMultsFull => shelfMultsUsed >= maxShelfMults;

  void _usedShelfMult(FigureDef d) {
    if (onePerLive.contains(d.id) && took.add(d.id)) _dropShelfMultOffers();
    if (!isShelfMult(d)) return;
    shelfMultsUsed++;
    if (shelfMultsFull) _dropShelfMultOffers();
  }

  /// Goods a live can have only one of (ぷりパレ全員の等身大パネル): once taken, they drop no more.
  static const onePerLive = {'unit_panel'};
  final Set<String> took = {};
  bool _tookOnly(FigureDef f) => onePerLive.contains(f.id) && took.contains(f.id);

  /// Goods that can't come any more this live: a ×-all goods once [maxShelfMults] are used, a one-per-live one once taken.
  bool _blocked(FigureDef f) => (isShelfMult(f) && shelfMultsFull) || _tookOnly(f);

  /// A stall offer that can't be bought right now: a shelf-wide × goods once [maxShelfMults] have been used.
  /// (They are taken off the stall as the altar fills, so this is only a safety net.)
  bool canBuy(Offer o) => !(o.kind == OfferKind.figure && _blocked(o.fig!));

  /// The altar has just filled up with ×-all goods: those still on the stall make way for other goods.
  void _dropShelfMultOffers() {
    for (var i = 0; i < shop.length; i++) {
      final o = shop[i];
      if (o.kind == OfferKind.figure && !o.sold && _blocked(o.fig!)) shop[i] = _figureOffer();
    }
  }

  // ── 出現率UP (bought at the stall): each one doubles an idol's goods, for the rest of the live ──
  static const boostStep = 2.0;
  final Map<String, double> boost = {};

  double _weight(FigureDef f) {
    var b = 1.0;
    for (final t in f.tags) {
      b = math.max(b, boost[t] ?? 1);
    }
    return rules.weightOf(f.id) * b * (isMultiplier(f) ? multWeight : 1);
  }

  /// Goods that multiply (×) come out less often than the rest: a few of them snowball a run.
  static double multWeight = 0.5;
  static bool isMultiplier(FigureDef f) => f.effects.any((e) => e is MultAdjacentTag || e is MultDiagonal) || isShelfMult(f);

  FigureDef pullOne({Rarity maxRarity = Rarity.legend, Rarity minRarity = Rarity.normal}) {
    final w = rarityWeights;
    var lo = minRarity.index, hi = maxRarity.index;
    if (rareSong) lo = math.min(hi, math.max(lo, Rarity.rare.index));
    var sum = 0.0;
    for (var k = lo; k <= hi; k++) {
      sum += w[k];
    }
    var x = rng.nextDouble() * sum;
    var rar = Rarity.values[hi];
    for (var k = lo; k <= hi; k++) {
      x -= w[k];
      if (x <= 0) {
        rar = Rarity.values[k];
        break;
      }
    }
    // a rarity with nothing unlocked yet (no レジェンド before 縁日 Lv6) gives the next one down
    // ○○確定チケット: only her goods (any rarity she has, when this one has none)
    List<FigureDef> avail(Rarity r) => [for (final f in _unlocked(r)) if (idolSong == null || f.cast.contains(idolSong)) f];
    var pool = avail(rar);
    while (pool.isEmpty && rar.index > 0) {
      rar = Rarity.values[rar.index - 1];
      pool = avail(rar);
    }
    for (var k = rar.index + 1; pool.isEmpty && k < Rarity.values.length; k++) {
      pool = avail(Rarity.values[k]);
    }
    if (pool.isEmpty) pool = _unlocked(Rarity.normal);
    final ws = [for (final f in pool) _weight(f)];
    var y = rng.nextDouble() * ws.fold(0.0, (a, b) => a + b);
    for (var k = 0; k < pool.length; k++) {
      y -= ws[k];
      if (y <= 0) return pool[k];
    }
    return pool.last;
  }

  /// What a normal spin can drop right now and how likely each one is (for the machine's 中身 sheet).
  /// The same odds as [pullOne]: luck, R-only songs, member-only songs, boosts and the × goods' lower weight.
  List<({FigureDef def, double p})> lineup() {
    final w = rarityWeights;
    final lo = rareSong ? Rarity.rare.index : 0;
    List<FigureDef> avail(int k) => [for (final f in _unlocked(Rarity.values[k])) if (idolSong == null || f.cast.contains(idolSong)) f];
    final share = List<double>.generate(4, (k) => k < lo ? 0 : w[k]);
    final sum = share.fold(0.0, (a, b) => a + b);
    for (var k = 0; k < 4; k++) {
      share[k] /= sum;
    }
    // a rarity with nothing in it passes its share down (or up, at the bottom), like pullOne
    for (var k = 3; k > 0; k--) {
      if (avail(k).isEmpty) {
        share[k - 1] += share[k];
        share[k] = 0;
      }
    }
    for (var k = 0; k < 3 && avail(k).isEmpty; k++) {
      share[k + 1] += share[k];
      share[k] = 0;
    }
    final out = <({FigureDef def, double p})>[];
    for (var k = 3; k >= 0; k--) {
      final pool = avail(k);
      if (pool.isEmpty || share[k] == 0) continue;
      final tw = pool.fold(0.0, (a, f) => a + _weight(f));
      for (final f in pool) {
        out.add((def: f, p: share[k] * _weight(f) / tw));
      }
    }
    return out;
  }

  /// Pulling again after seeing what came out is free:
  /// 1 use per payday to start, raised at the stall up to [maxRepulls].
  int repullMax = 1;
  int repulls = 1; // uses left until the next payday

  /// What the machine drops this turn. [atLeast] keeps a re-pull from coming
  /// out worse than what was already in hand.
  List<FigureDef> pullAtLeast(Rarity atLeast) => [pullOne(minRarity: atLeast)];

  /// What the machine drops this turn (1, or 2 to choose from).
  List<FigureDef> pull() {
    final out = <FigureDef>[pullOne()];
    while (out.length < choose) {
      final f = pullOne();
      if (!out.contains(f) || figures.length < 3) out.add(f);
    }
    return out;
  }

  // ── placing / removing ──
  Fig _newFig(FigureDef d) {
    seen.add(d.id);
    return Fig(d, ++_uid);
  }

  /// Puts [d] at [idx]; returns the instant beats (scooping, spawning).
  List<Step> place(FigureDef d, int idx) {
    assert(cells[idx] == null);
    final steps = <Step>[];
    cells[idx] = _newFig(d);
    _usedShelfMult(d);
    final bonus = d.effect<GainOnPlaced>();
    if (bonus != null) {
      coins += bonus.v;
      earned += bonus.v;
      steps.add(Step(StepKind.instant, idx, amount: bonus.v));
    }
    final eat = d.effect<OnPlacedEatAdjacentTag>();
    if (eat != null) {
      for (final n in neighbors(idx)) {
        final f = cells[n];
        if (f != null && f.def.tags.contains(eat.tag)) {
          cells[n] = null;
          coins += eat.v;
          earned += eat.v;
          steps
            ..add(Step(StepKind.remove, n))
            ..add(Step(StepKind.instant, idx, amount: eat.v));
        }
      }
    }
    final spawn = d.effect<OnPlacedSpawnRare>();
    if (spawn != null) {
      cells[idx] = null;
      steps.add(Step(StepKind.remove, idx));
      for (var k = 0; k < spawn.n; k++) {
        final empty = emptyCells;
        if (empty.isEmpty) {
          coins += 10;
          earned += 10;
          steps.add(Step(StepKind.instant, idx, amount: 10));
          continue;
        }
        final at = k == 0 ? idx : rng.pick(empty);
        final f = _newFig(pullOne(minRarity: Rarity.rare));
        cells[at] = f;
        steps.add(Step(StepKind.spawn, at, fig: f));
      }
    }
    return steps;
  }

  /// A new figure can go over any old one.
  bool canOverwrite(int idx) => cells[idx] != null;

  /// The same goods on top of itself stacks it instead (its numbers go ×2, ×3, …).
  bool stacksOn(FigureDef d, int idx) => cells[idx]?.def.id == d.id;

  List<Step> overwrite(FigureDef d, int idx) {
    assert(canOverwrite(idx));
    if (stacksOn(d, idx)) {
      seen.add(d.id);
      cells[idx]!.stack++;
      _usedShelfMult(d);
      return const [];
    }
    cells[idx] = null;
    return place(d, idx);
  }

  // ── scoring ──
  int _base(int i) {
    final f = cells[i]!;
    var v = 0;
    for (final e in f.def.effects) {
      v += switch (e) {
        Add() => e.v,
        AddIfCorner() => isCorner(i) ? e.v : 0,
        AddPerEmptyAdjacent() => neighbors(i).where((n) => cells[n] == null).length * e.v,
        AddPerShelfTag() => shelfTag(e.tag) * e.v,
        AddIfShelfTag() => shelfTag(e.tag) >= e.n ? e.v : 0,
        AddIfAdjacentId() => neighbors(i).any((n) => cells[n]?.def.id == e.id) ? e.v : 0,
        Grow() => (f.age - 1) * e.v,
        EveryN() => f.age % e.n == 0 ? e.v : 0,
        AddPerAdjacentTag() => neighbors(i).where((n) => cells[n]?.def.tags.contains(e.tag) ?? false).length * e.v,
        AddIfAlone() => neighbors(i).every((n) => cells[n] == null) ? e.v : 0,
        AddPerShelfFigures() => figs.length ~/ e.n * e.v,
        Cooling() => math.max(0, e.v - (f.age - 1)),
        RandomAdd() => e.lo + rng.nextInt(e.hi - e.lo + 1),
        AddPerDiagonalTag() => diagonals(i).where((n) => cells[n]?.def.tags.contains(e.tag) ?? false).length * e.v,
        AddPerDiagonalFigures() => diagonals(i).where((n) => cells[n] != null).length * e.v,
        AddIfDiagonalFull() => bingoLine(i).length == 4 && bingoLine(i).every((n) => cells[n] != null) ? e.v : 0,
        _ => 0,
      };
    }
    return v * f.stack;
  }

  TurnResult endTurn() {
    turn++;
    songTurn++;
    for (final f in figs) {
      f.age++;
    }
    final steps = <Step>[];
    final gain = <int, int>{}; // cell → hearts this turn
    _shoot(gain, steps);
    _baseIncome(gain, steps);
    _buffs(gain, steps);
    final fused = _multipliers(gain, steps);
    _copycats(gain, steps);
    final total = _bank(gain);
    _afterScoring(fused, steps);
    return TurnResult(steps, total, gain);
  }

  /// 1. shooters fire first; victims leave before anyone else scores
  void _shoot(Map<int, int> gain, List<Step> steps) {
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      final sh = f?.def.effect<ShootAdjacent>();
      if (sh == null) continue;
      // only the cell to its right
      if (colOf(i) == cols - 1 || cells[i + 1] == null) continue;
      final v = i + 1;
      final g = math.max(_base(v), 1) * sh.m;
      cells[v] = null;
      gain[i] = g;
      steps.add(Step(StepKind.shoot, i, amount: g, targets: [v]));
    }
  }

  /// 2. base income in reading order
  void _baseIncome(Map<int, int> gain, List<Step> steps) {
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      if (f == null || gain.containsKey(i) || f.def.has<CopyBestAdjacent>()) continue;
      final b = _base(i);
      gain[i] = b;
      if (b != 0) steps.add(Step(StepKind.add, i, amount: b));
    }
  }

  /// 3. buffs: every row buff, then every column buff, then every diagonal one
  void _buffs(Map<int, int> gain, List<Step> steps) {
    void buff(int i, int v, List<int> ts) {
      for (final t in ts) {
        gain[t] = (gain[t] ?? 0) + v;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.buff, i, amount: v, targets: ts));
    }

    for (var i = 0; i < size; i++) {
      final b = cells[i]?.def.effect<BuffRow>();
      if (b == null) continue;
      final ts = [
        for (var c = 0; c < cols; c++)
          if (rowOf(i) * cols + c != i && cells[rowOf(i) * cols + c] != null) rowOf(i) * cols + c,
      ];
      buff(i, b.v * cells[i]!.stack, ts);
    }
    for (var i = 0; i < size; i++) {
      final b = cells[i]?.def.effect<BuffColumn>();
      if (b == null) continue;
      final ts = [
        for (var r = 0; r < rows; r++)
          if (r * cols + colOf(i) != i && cells[r * cols + colOf(i)] != null) r * cols + colOf(i),
      ];
      buff(i, b.v * cells[i]!.stack, ts);
    }
    for (var i = 0; i < size; i++) {
      final b = cells[i]?.def.effect<BuffDiagonal>();
      if (b == null) continue;
      buff(i, b.v * cells[i]!.stack, diagonals(i).where((n) => cells[n] != null).toList());
    }
  }

  /// 4. multipliers on what has earned so far: local ones (neighbours, diagonals), then a tag across
  /// the altar, then the deck payoffs on the whole altar. Returns the fuses that went off.
  List<int> _multipliers(Map<int, int> gain, List<Step> steps) {
    void mult(int i, int f, List<int> ts) {
      for (final t in ts) {
        gain[t] = gain[t]! * f;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.mult, i, amount: f, targets: ts));
    }

    for (var i = 0; i < size; i++) {
      final m = cells[i]?.def.effect<MultAdjacentTag>();
      if (m == null) continue;
      final ts = neighbors(i).where((n) => cells[n] != null && cells[n]!.def.tags.contains(m.tag) && (gain[n] ?? 0) > 0).toList();
      mult(i, cells[i]!.factor(m.f), ts);
    }
    for (var i = 0; i < size; i++) {
      final m = cells[i]?.def.effect<MultDiagonal>();
      if (m == null) continue;
      final ts = diagonals(i).where((n) => cells[n] != null && (gain[n] ?? 0) > 0).toList();
      mult(i, cells[i]!.factor(m.f), ts);
    }
    List<int> tagged(List<String> tags) => [
      for (final e in gain.entries)
        if (e.value > 0 && (cells[e.key]?.def.tags.any(tags.contains) ?? false)) e.key,
    ];
    for (var i = 0; i < size; i++) {
      final m = cells[i]?.def.effect<MultShelfTagIfCount>();
      if (m == null || shelfTag(m.tag) < m.n) continue;
      mult(i, cells[i]!.factor(m.f), tagged([m.tag]));
    }
    final fused = <int>[];
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      final fuse = f?.def.effect<Fuse>();
      if (fuse == null || f!.age < fuse.n) continue;
      fused.add(i);
      mult(i, f.factor(fuse.f), tagged(fuse.tags));
    }
    // the deck payoffs last, on the whole altar: 箱推し (all five there) or 単推し (nothing else there)
    final everyone = [
      for (final e in gain.entries)
        if (e.value > 0) e.key,
    ];
    final members = {for (final f in figs) ...f.def.tags.where(_idols.contains)};
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      if (f == null) continue;
      final all = f.def.effect<MultIfAllMembers>();
      if (all != null && members.length == _idols.length) mult(i, f.factor(all.f), everyone);
      final only = f.def.effect<MultIfOnly>();
      if (only != null && figs.every((g) => g.def.tags.any(only.tags.contains))) mult(i, f.factor(only.f), everyone);
    }
    return fused;
  }

  /// 5. copycats (fox masks) go last, on the final values, and chain: a row of
  ///    masks keeps passing the best number along until they all agree
  void _copycats(Map<int, int> gain, List<Step> steps) {
    final copycats = [
      for (var i = 0; i < size; i++)
        if (cells[i]?.def.has<CopyBestAdjacent>() == true) i,
    ];
    for (final i in copycats) {
      gain[i] = 0;
    }
    for (var changed = true, guard = 0; changed && guard < size; guard++) {
      changed = false;
      for (final i in copycats) {
        final best = neighbors(i).map((n) => gain[n] ?? 0).fold(0, math.max);
        if (best > gain[i]!) {
          gain[i] = best;
          changed = true;
        }
      }
    }
    // each one shows where its number came from: the neighbour it copied ([Step.targets])
    for (final i in copycats) {
      if (gain[i]! == 0) continue;
      final from = neighbors(i).where((n) => (gain[n] ?? 0) == gain[i]).firstOrNull;
      steps.add(Step(StepKind.copy, i, amount: gain[i]!, targets: [?from]));
    }
  }

  /// 6. the turn's hearts go into the purse; returns how many
  int _bank(Map<int, int> gain) {
    var total = gain.values.fold(0, (a, b) => a + b);
    // 妨害: this song's hearts come in at half (getting through) or double (fended off)
    if (halfThisSong && total > 0) total = (total / 2).ceil();
    if (doubleThisSong && total > 0) total *= 2;
    coins = math.max(0, coins + total);
    earned += math.max(0, total);
    bestTurn = math.max(bestTurn, total);
    for (final e in gain.entries) {
      cells[e.key]?.lastGain = e.value;
    }
    return total;
  }

  /// 7. after scoring: fireworks leave, balloons pop, lottery bags spawn
  void _afterScoring(List<int> fused, List<Step> steps) {
    for (final i in fused) {
      cells[i] = null;
      steps.add(Step(StepKind.remove, i));
    }
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      final life = f?.def.effect<Lifetime>();
      if (life != null && f!.age >= life.n) {
        cells[i] = null;
        steps.add(Step(StepKind.remove, i));
      }
    }
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      final sp = f?.def.effect<SpawnEveryN>();
      if (sp == null || f!.age % sp.n != 0) continue;
      final empty = emptyCells;
      if (empty.isEmpty) continue;
      final at = rng.pick(empty);
      final nf = _newFig(pullOne(maxRarity: Rarity.rare));
      cells[at] = nf;
      steps.add(Step(StepKind.spawn, at, fig: nf));
    }
  }

  // ── payday ──
  /// What the 「曲の終わりに +N」 goods add when the song ends.
  int get paydayBonus => figs.fold(0, (a, f) => a + (f.def.effect<OnPaydayGain>()?.v ?? 0));

  PaydayResult payday() {
    final before = coins;
    final bonus = paydayBonus;
    coins += bonus;
    final d = due;
    if (coins < d) return PaydayResult(d, bonus, before, false);
    coins -= d;
    carriedDebt = 0;
    paydaysPaid++;
    // a fresh song: もう一回ひく fills back up, and a 妨害's spell and the 確定チケット wear off
    songTurn = 0;
    repulls = repullMax;
    halfThisSong = false;
    doubleThisSong = false;
    rareSong = false;
    idolSong = null;
    return PaydayResult(d, bonus, before, true);
  }

  /// The once-per-run rescue (rewarded ad): this payday's bill moves to the next one.
  bool get canPostpone => !continueUsed && !rules.noContinue;

  void postpone() {
    continueUsed = true;
    carriedDebt = due;
    paydaysPaid++;
    songTurn = 0;
    repulls = repullMax;
    halfThisSong = false;
    doubleThisSong = false;
    rareSong = false;
    idolSong = null;
  }

  // ── 妨害 (a scalper barges in before the hearts are counted) ──
  bool halfThisSong = false; // 妨害: hearts are halved until the song ends
  bool doubleThisSong = false; // a 妨害 was fended off: hearts ×2 until the song ends

  /// Whether a 妨害 happens this turn (rolled after placing, before scoring). [force]: it does.
  Jam? rollJam({bool force = false}) {
    if (!force && (rules.jamRate <= 0 || rng.nextDouble() >= rules.jamRate)) return null;
    // how hard he pushes, and how bad it is if he gets through
    final power = 0.75 + rng.nextDouble() * 0.6 * rules.jamPower;
    final x = rng.nextDouble();
    final kind = x < 0.45
        ? JamKind.steal
        : x < 0.6
        ? JamKind.stealTwo
        : x < 0.75
        ? JamKind.noRepull
        : x < 0.88
        ? JamKind.half
        : JamKind.hearts;
    final goods = [for (var i = 0; i < size; i++) if (cells[i] != null) i];
    final kindOk = switch (kind) {
      JamKind.steal || JamKind.stealTwo => goods.isNotEmpty,
      JamKind.noRepull => repulls > 0,
      JamKind.half => !halfThisSong,
      JamKind.hearts => coins > 0,
    };
    final k = kindOk ? kind : (goods.isNotEmpty ? JamKind.steal : JamKind.hearts);
    // what fending him off brings
    final y = rng.nextDouble();
    final gift = _jamGift();
    final reward = y < 0.4
        ? JamReward.hearts
        : y < 0.75 && gift != null
        ? JamReward.goods
        : y < 0.88
        ? JamReward.luck
        : JamReward.repull;
    return Jam(k, power, pct: k == JamKind.hearts ? 20 + rng.nextInt(21) : 0, reward: reward, gift: reward == JamReward.goods ? gift : null);
  }

  /// A goods this gacha is glad of: of the idol it favours, else the one most on the altar; ★3 if there is one.
  FigureDef? _jamGift() {
    String? who;
    var best = 1.0;
    for (final e in rules.tagWeight.entries) {
      if (_idols.contains(e.key) && e.value > best) {
        best = e.value;
        who = e.key;
      }
    }
    who ??= topCast ?? rng.pick(_idols);
    for (final r in [Rarity.epic, Rarity.rare]) {
      final pool = [for (final f in _unlocked(r)) if (f.tags.contains(who)) f];
      if (pool.isNotEmpty) return rng.pick(pool);
    }
    return null;
  }

  /// He was fended off: the reward (a goods comes back for the caller to place).
  FigureDef? rewardJam(Jam j) {
    switch (j.reward) {
      case JamReward.hearts:
        doubleThisSong = true;
      case JamReward.goods:
        // chosen when he came; if the live has used up its ×-all goods since, another goods
        // (or the hearts when there is none)
        if (_blocked(j.gift!)) {
          final other = _jamGift();
          if (other == null) doubleThisSong = true;
          return other;
        }
        return j.gift;
      case JamReward.luck:
        luckBonus += 10;
      case JamReward.repull:
        repulls++;
    }
    return null;
  }

  /// The 妨害 got through. Returns the cells it emptied.
  List<int> applyJam(Jam j) {
    final out = <int>[];
    switch (j.kind) {
      case JamKind.steal || JamKind.stealTwo:
        for (var k = 0; k < (j.kind == JamKind.stealTwo ? 2 : 1); k++) {
          final goods = [for (var i = 0; i < size; i++) if (cells[i] != null) i];
          if (goods.isEmpty) break;
          final at = rng.pick(goods);
          cells[at] = null;
          out.add(at);
        }
      case JamKind.noRepull:
        repulls = 0;
      case JamKind.half:
        halfThisSong = true;
      case JamKind.hearts:
        coins -= (coins * j.pct / 100).round();
    }
    return out;
  }

  // ── shop ──
  double get _priceScale => (1 + paydaysPaid * 0.3) * rules.priceMult;

  Offer _figureOffer() {
    final x = rng.nextDouble();
    var rar = x < 0.55 ? Rarity.rare : (x < 0.9 ? Rarity.epic : Rarity.legend);
    if (_unlocked(rar).isEmpty) rar = Rarity.epic;
    final base = const {Rarity.rare: 14, Rarity.epic: 30, Rarity.legend: 60}[rar]!;
    return Offer(
      OfferKind.figure,
      (base * _priceScale).round(),
      rng.pick(_unlocked(rar)),
    );
  }

  void rollShop({bool resetReroll = true}) {
    if (resetReroll) {
      rerolls = rerollMax;
      shopBuys = 0;
    }
    Offer use(OfferKind k, int now) => Offer(k, (12 * (now + 1) * _priceScale).round());
    // three items, completely random
    shop = [];
    final pool = <Offer>[
      _figureOffer(),
      _figureOffer(),
      _figureOffer(),
      Offer(OfferKind.luck, (10 * _priceScale).round()),
      Offer(OfferKind.boost, (12 * _priceScale).round(), null, rng.pick(_idols)),
      if (rules.canExpand && canGrow) Offer(OfferKind.expand, expandPrice),
      if (repullMax < maxRepulls) use(OfferKind.repullTicket, repullMax),
      if (rerollMax < maxUses) use(OfferKind.rerollTicket, rerollMax),
    ];
    while (shop.length < 3 && pool.isNotEmpty) {
      shop.add(pool.removeAt(rng.nextInt(pool.length)));
    }
    // now and then a レア商品 takes one of the places
    if (shop.isNotEmpty && rng.nextDouble() < rareChance) {
      final x = rng.nextDouble();
      final o = x < 0.3 && turnsPerSong < maxTurnsPerSong
          ? Offer(OfferKind.extraSpin, (45 * _priceScale).round())
          : x < 0.6
          ? Offer(OfferKind.rareSong, (30 * _priceScale).round())
          : Offer(OfferKind.idolSong, (25 * _priceScale).round(), null, rng.pick(_idols));
      shop[rng.nextInt(shop.length)] = o;
    }
    shop.shuffle(math.Random(rng.nextInt(1 << 30)));
  }

  /// Buy as much as you like at the boss's stall: the first thing each visit is
  /// free, then each purchase marks the rest up: by [shopMarkup] of the list
  /// price, and at least a growing share of the coins still in the purse
  /// (40%, 60%, 80%, then all of it).
  static const shopMarkup = 0.5;
  double rareChance = 0.08; // a レア商品 at about one stall visit in twelve
  int shopBuys = 0;
  int priceOf(Offer o) {
    if (shopBuys == 0) return o.rare ? o.price : 0;
    final marked = (o.price * (1 + shopMarkup * shopBuys)).round();
    final share = (coins * (0.2 + 0.2 * shopBuys)).ceil();
    return math.max(marked, share);
  }

  bool reroll() {
    if (rerolls <= 0) return false;
    rerolls--;
    rollShop(resetReroll: false);
    return true;
  }

  /// Buys an offer. A bought figure is returned so the caller can place it.
  FigureDef? buy(Offer o) {
    final price = priceOf(o);
    if (o.sold || coins < price || !canBuy(o)) return null;
    coins -= price;
    o.sold = true;
    shopBuys++;
    switch (o.kind) {
      case OfferKind.figure:
        return o.fig;
      case OfferKind.luck:
        luckBonus += 8;
      case OfferKind.boost:
        boost[o.idol!] = (boost[o.idol!] ?? 1) * boostStep;
      case OfferKind.repullTicket:
        repullMax = math.min(maxRepulls, repullMax + 1);
        repulls++;
      case OfferKind.rerollTicket:
        rerollMax = math.min(maxUses, rerollMax + 1);
        rerolls++;
      case OfferKind.expand:
        _expand();
      case OfferKind.extraSpin:
        turnsPerSong = math.min(maxTurnsPerSong, turnsPerSong + 1);
      case OfferKind.rareSong:
        rareSong = true;
      case OfferKind.idolSong:
        idolSong = o.idol;
    }
    return null;
  }

  /// Shelf upgrades grow it one column or row at a time, up to 5x5 (6x6 made play heavy).
  static const maxSide = 5;
  int expansions = 0;
  bool get canGrow => cols < maxSide || rows < maxSide;

  /// Each upgrade costs 1.7x the last.
  int get expandPrice => (20 * math.pow(1.7, expansions) * rules.priceMult).round();

  void _expand() {
    expansions++;
    final wide = cols < maxSide && (cols <= rows || rows >= maxSide);
    final nc = wide ? cols + 1 : cols;
    final nr = wide ? rows : rows + 1;
    final next = List<Fig?>.filled(nc * nr, null);
    for (var i = 0; i < size; i++) {
      next[rowOf(i) * nc + colOf(i)] = cells[i];
    }
    cols = nc;
    rows = nr;
    cells = next;
  }
}
