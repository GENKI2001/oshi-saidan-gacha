// One roguelite run: gacha → shelf → scoring → payday → shop (spec 02 §3).
// Pure Dart with no Flutter imports, so tool/sim.dart can play thousands of
// runs headlessly to balance figures and dues (spec 02 §9).

import 'dart:math' as math;

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
  Fig(this.def, this.uid);
  Fig copy() => Fig(def, uid)
    ..age = age
    ..lastGain = lastGain;
}

enum StepKind { add, buff, mult, shoot, remove, spawn, instant }

/// One beat of the scoring animation. [idx] is the acting cell.
class Step {
  final StepKind kind;
  final int idx;
  final int amount; // coins (add/buff/shoot/instant) or factor (mult)
  final List<int> targets;
  final Fig? fig; // spawned figure
  const Step(this.kind, this.idx, {this.amount = 0, this.targets = const [], this.fig});
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
  final List<int> cardCells;
  PaydayResult(this.due, this.bonus, this.coinsBefore, this.paid, this.cardCells);
}

enum OfferKind { figure, luck, removeTickets, swapTicket, repullTicket, rerollTicket, expand }

class Offer {
  final OfferKind kind;
  final int price;
  final FigureDef? fig;
  bool sold = false;
  Offer(this.kind, this.price, [this.fig]);

  String get title => switch (kind) {
    OfferKind.figure => fig!.name,
    OfferKind.luck => 'つむぎのおまじない',
    OfferKind.removeTickets => 'どける 回数+1',
    OfferKind.swapTicket => 'いれかえ 回数+1',
    OfferKind.repullTicket => 'もう一回ひく 回数+1',
    OfferKind.rerollTicket => '品がえ 回数+1',
    OfferKind.expand => '祭壇を広げる',
  };

  String get text => switch (kind) {
    OfferKind.figure => fig!.description,
    OfferKind.luck => 'R以上が出やすくなる（+8%）',
    OfferKind.removeTickets => '「どける」が1回ふえる（最大3回）',
    OfferKind.swapTicket => '「いれかえ」が1回ふえる（最大3回）',
    OfferKind.repullTicket => '「もう一回ひく」が1回ふえる（最大5回）',
    OfferKind.rerollTicket => '「品がえ」が1回ふえる（最大3回）',
    OfferKind.expand => '祭壇のマスが増える',
  };
}

class Run {
  static const turnsPerPayday = 5;
  // 取り立て grows by the same factor every time
  static const firstDue = 14;
  static const dueGrowth = 3.7;
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
  // どける / いれかえ are free to use; uses left refill at every payday.
  // Each starts at 1 use per payday and the stall can raise it to [maxUses].
  static const maxUses = 3;
  static const maxRepulls = 5; // もう一回ひく can grow further
  int removeMax = 1, swapMax = 1;
  int removeTickets = 1; // どける uses left until the next payday
  int swapTickets = 1; // いれかえ uses left until the next payday
  bool continueUsed = false;
  int bestTurn = 0;
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
    // どける / いれかえ are one use each (0 when an ascension takes them away)
    removeMax = swapMax = math.min(this.rules.removeTickets, 1);
    removeTickets = swapTickets = removeMax;
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
      ..removeTickets = removeTickets
      ..swapTickets = swapTickets
      ..removeMax = removeMax
      ..swapMax = swapMax
      ..expansions = expansions
      ..repulls = repulls
      ..repullMax = repullMax
      ..rerollMax = rerollMax
      ..rerolls = rerolls
      ..continueUsed = continueUsed
      ..bestTurn = bestTurn
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

  List<int> get emptyCells => [
    for (var i = 0; i < size; i++)
      if (cells[i] == null) i,
  ];
  Iterable<Fig> get figs => cells.whereType<Fig>();
  int shelfTag(String tag) => figs.where((f) => f.def.tags.contains(tag)).length;

  int get luck => luckBonus + figs.fold(0, (s, f) => s + (f.def.effect<Luck>()?.v ?? 0));

  // ── payday ──
  int get turnsToPayday => turnsPerPayday - turn % turnsPerPayday;
  bool get paydayNow => turn > 0 && turn % turnsPerPayday == 0 && turn ~/ turnsPerPayday > paydaysPaid;
  bool get cleared => paydaysPaid >= clearPaydays;

  int baseDue(int i) => (firstDue * math.pow(dueGrowth, i)).round();

  int get due {
    var f = 1.0;
    for (final x in figs) {
      final d = x.def.effect<PaydayDiscount>();
      if (d != null) f *= 1 - d.pct / 100;
    }
    return (baseDue(paydaysPaid) * rules.dueMult * math.max(f, 0.4)).round() + carriedDebt;
  }

  // ── gacha ──
  /// Hidden luck that grows with every payday paid (not shown as 運 +N%).
  static const paydayLuck = 5;

  List<double> get rarityWeights {
    final l = (luck + paydaysPaid * paydayLuck).toDouble();
    return [math.max(20, 62 - l), 27 + l * 0.6, 9 + l * 0.3, 2 + l * 0.1];
  }

  List<FigureDef> _unlocked(Rarity r) => figures.where((f) => f.rarity == r && f.level <= rules.level).toList();

  FigureDef pullOne({Rarity maxRarity = Rarity.legend, Rarity minRarity = Rarity.normal, bool allowCurse = false}) {
    if (allowCurse && rules.curseRate > 0 && rng.nextDouble() < rules.curseRate) return figureById[kCardId]!;
    final w = rarityWeights;
    var lo = minRarity.index, hi = maxRarity.index;
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
    var pool = _unlocked(rar);
    while (pool.isEmpty && rar.index > 0) {
      rar = Rarity.values[rar.index - 1];
      pool = _unlocked(rar);
    }
    final ws = [for (final f in pool) rules.weightOf(f.id)];
    var y = rng.nextDouble() * ws.fold(0.0, (a, b) => a + b);
    for (var k = 0; k < pool.length; k++) {
      y -= ws[k];
      if (y <= 0) return pool[k];
    }
    return pool.last;
  }

  /// Pulling again after seeing what came out is free, like どける / いれかえ:
  /// 1 use per payday to start, raised at the stall up to [maxUses].
  int repullMax = 1;
  int repulls = 1; // uses left until the next payday

  /// What the machine drops this turn. [atLeast] keeps a re-pull from coming
  /// out worse than what was already in hand (and rules out the boss's card).
  List<FigureDef> pullAtLeast(Rarity atLeast) => [pullOne(minRarity: atLeast, allowCurse: atLeast == Rarity.normal)];

  /// What the machine drops this turn (1, or 2 to choose from).
  List<FigureDef> pull() {
    final out = <FigureDef>[pullOne(allowCurse: true)];
    while (out.length < choose) {
      final f = pullOne(allowCurse: true);
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

  /// Swaps two cells (either may be empty) with the いれかえ ticket.
  bool swap(int a, int b) {
    if (swapTickets <= 0 || a == b || (cells[a] == null && cells[b] == null)) return false;
    swapTickets--;
    final t = cells[a];
    cells[a] = cells[b];
    cells[b] = t;
    return true;
  }

  /// A new figure can go over an old one (not over the boss's card).
  bool canOverwrite(int idx) => cells[idx] != null && cells[idx]!.def.id != kCardId;

  List<Step> overwrite(FigureDef d, int idx) {
    assert(canOverwrite(idx));
    cells[idx] = null;
    return place(d, idx);
  }

  /// Removes the figure at [idx] with a ticket. Returns coins gained.
  int remove(int idx) {
    final f = cells[idx];
    if (f == null || removeTickets <= 0) return 0;
    removeTickets--;
    cells[idx] = null;
    final g = f.def.effect<OnRemovedGain>()?.v ?? 0;
    coins += g;
    earned += g;
    return g;
  }

  // ── scoring ──
  int _base(int i) {
    final f = cells[i]!;
    var v = 0;
    for (final e in f.def.effects) {
      v += switch (e) {
        Add() => e.v - (f.def.id == kCardId ? rules.curseExtra : 0),
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
        _ => 0,
      };
    }
    return v;
  }

  TurnResult endTurn() {
    turn++;
    for (final f in figs) {
      f.age++;
    }
    final steps = <Step>[];
    final gain = <int, int>{};

    // 1. shooters fire first; victims leave before anyone else scores
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      final sh = f?.def.effect<ShootAdjacent>();
      if (sh == null) continue;
      // only the cell to its right
      if (colOf(i) == cols - 1 || cells[i + 1] == null) continue;
      final v = i + 1;
      final victim = cells[v]!;
      final g = math.max(_base(v), 1) * sh.m + (victim.def.effect<OnRemovedGain>()?.v ?? 0);
      cells[v] = null;
      gain[i] = g;
      steps.add(Step(StepKind.shoot, i, amount: g, targets: [v]));
    }

    // 2. base income in reading order
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      if (f == null || gain.containsKey(i) || f.def.has<CopyBestAdjacent>()) continue;
      final b = _base(i);
      gain[i] = b;
      if (b != 0) steps.add(Step(StepKind.add, i, amount: b));
    }

    // 3. row buffs
    for (var i = 0; i < size; i++) {
      final buff = cells[i]?.def.effect<BuffRow>();
      if (buff == null) continue;
      final ts = [
        for (var c = 0; c < cols; c++)
          if (rowOf(i) * cols + c != i && cells[rowOf(i) * cols + c] != null) rowOf(i) * cols + c,
      ];
      for (final t in ts) {
        gain[t] = (gain[t] ?? 0) + buff.v;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.buff, i, amount: buff.v, targets: ts));
    }

    // 3b. column buffs
    for (var i = 0; i < size; i++) {
      final buff = cells[i]?.def.effect<BuffColumn>();
      if (buff == null) continue;
      final ts = [
        for (var r = 0; r < rows; r++)
          if (r * cols + colOf(i) != i && cells[r * cols + colOf(i)] != null) r * cols + colOf(i),
      ];
      for (final t in ts) {
        gain[t] = (gain[t] ?? 0) + buff.v;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.buff, i, amount: buff.v, targets: ts));
    }

    // 5. local multipliers, then global ones
    for (var i = 0; i < size; i++) {
      final m = cells[i]?.def.effect<MultAdjacentTag>();
      if (m == null) continue;
      final ts = neighbors(i).where((n) => cells[n] != null && cells[n]!.def.tags.contains(m.tag) && (gain[n] ?? 0) > 0).toList();
      for (final t in ts) {
        gain[t] = gain[t]! * m.f;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.mult, i, amount: m.f, targets: ts));
    }
    for (var i = 0; i < size; i++) {
      final m = cells[i]?.def.effect<MultShelfTag>();
      if (m == null) continue;
      final ts = [
        for (final e in gain.entries)
          if (e.value > 0 && (cells[e.key]?.def.tags.contains(m.tag) ?? false)) e.key,
      ];
      for (final t in ts) {
        gain[t] = gain[t]! * m.f;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.mult, i, amount: m.f, targets: ts));
    }
    final fused = <int>[];
    for (var i = 0; i < size; i++) {
      final f = cells[i];
      if (f == null) continue;
      var factor = f.def.effect<MultAll>()?.f;
      final fuse = f.def.effect<Fuse>();
      if (fuse != null && f.age >= fuse.n) {
        factor = fuse.f;
        fused.add(i);
      }
      if (factor == null) continue;
      final ts = [
        for (final e in gain.entries)
          if (e.value > 0) e.key,
      ];
      for (final t in ts) {
        gain[t] = gain[t]! * factor;
      }
      if (ts.isNotEmpty) steps.add(Step(StepKind.mult, i, amount: factor, targets: ts));
    }

    // 6. copycats (fox masks) go last, on the final values, and chain: a row of
    //    masks keeps passing the best number along until they all agree
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
    for (final i in copycats) {
      if (gain[i]! != 0) steps.add(Step(StepKind.add, i, amount: gain[i]!));
    }

    final total = gain.values.fold(0, (a, b) => a + b);
    coins = math.max(0, coins + total);
    earned += math.max(0, total);
    bestTurn = math.max(bestTurn, total);
    for (final e in gain.entries) {
      cells[e.key]?.lastGain = e.value;
    }

    // 7. after scoring: fireworks leave, balloons pop, lottery bags spawn
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
    return TurnResult(steps, total, gain);
  }

  // ── payday ──
  PaydayResult payday() {
    final before = coins;
    var bonus = 0;
    for (final f in figs) {
      bonus += f.def.effect<OnPaydayGain>()?.v ?? 0;
    }
    coins += bonus;
    final d = due;
    if (coins < d) return PaydayResult(d, bonus, before, false, const []);
    coins -= d;
    carriedDebt = 0;
    paydaysPaid++;
    // a fresh period: どける / いれかえ fill back up, free
    removeTickets = removeMax;
    swapTickets = swapMax;
    repulls = repullMax;
    final cards = <int>[];
    // from the 2nd payday on, the boss leaves his card (an obstacle) on the shelf every time
    if (rules.cardEveryPayday || paydaysPaid >= 2) {
      final at = leaveCard();
      if (at != null) cards.add(at);
    }
    return PaydayResult(d, bonus, before, true, cards);
  }

  /// The boss puts his card in an empty cell (an obstacle to どける). Returns where, or null if full.
  int? leaveCard() {
    final empty = emptyCells;
    if (empty.isEmpty) return null;
    final at = rng.pick(empty);
    cells[at] = _newFig(figureById[kCardId]!);
    return at;
  }

  /// The once-per-run rescue (rewarded ad): this payday's bill moves to the next one.
  bool get canPostpone => !continueUsed && !rules.noContinue;

  void postpone() {
    continueUsed = true;
    carriedDebt = due;
    paydaysPaid++;
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
    // three items. One slot goes to a どける or いれかえ upgrade while either can still grow
    final tools = [
      if (removeMax < maxUses) use(OfferKind.removeTickets, removeMax),
      if (swapMax < maxUses) use(OfferKind.swapTicket, swapMax),
    ];
    shop = [if (tools.isNotEmpty) rng.pick(tools)];
    // the rest is completely random
    final pool = <Offer>[
      _figureOffer(),
      _figureOffer(),
      _figureOffer(),
      Offer(OfferKind.luck, (10 * _priceScale).round()),
      if (rules.canExpand && canGrow) Offer(OfferKind.expand, expandPrice),
      if (repullMax < maxRepulls) use(OfferKind.repullTicket, repullMax),
      if (rerollMax < maxUses) use(OfferKind.rerollTicket, rerollMax),
      for (final t in tools)
        if (t.kind != shop.firstOrNull?.kind) t,
    ];
    while (shop.length < 3 && pool.isNotEmpty) {
      shop.add(pool.removeAt(rng.nextInt(pool.length)));
    }
    shop.shuffle(math.Random(rng.nextInt(1 << 30)));
  }

  /// Buy as much as you like at the boss's stall: the first thing each visit is
  /// free, then each purchase marks the rest up: by [shopMarkup] of the list
  /// price, and at least a growing share of the coins still in the purse
  /// (40%, 60%, 80%, then all of it).
  static const shopMarkup = 0.5;
  int shopBuys = 0;
  int priceOf(Offer o) {
    if (shopBuys == 0) return 0;
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
    if (o.sold || coins < price) return null;
    coins -= price;
    o.sold = true;
    shopBuys++;
    switch (o.kind) {
      case OfferKind.figure:
        return o.fig;
      case OfferKind.luck:
        luckBonus += 8;
      case OfferKind.removeTickets:
        removeMax = math.min(maxUses, removeMax + 1);
        removeTickets++;
      case OfferKind.swapTicket:
        swapMax = math.min(maxUses, swapMax + 1);
        swapTickets++;
      case OfferKind.repullTicket:
        repullMax = math.min(maxRepulls, repullMax + 1);
        repulls++;
      case OfferKind.rerollTicket:
        rerollMax = math.min(maxUses, rerollMax + 1);
        rerolls++;
      case OfferKind.expand:
        _expand();
    }
    return null;
  }

  /// Shelf upgrades grow it one column or row at a time, up to 6x6.
  static const maxSide = 6;
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
