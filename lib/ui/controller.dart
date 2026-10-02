// Drives one run on screen: phases, timed playback of scoring steps, and the
// small bits of display state (pulses, floating numbers, boss mood) widgets
// animate from. Game rules live in logic/run.dart only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../logic/defs.dart';
import '../logic/figures.dart';
import '../logic/modes.dart';
import '../logic/run.dart';
import 'lines.dart';
import 'meta.dart';
import 'ads/ads.dart';
import 'rank.dart';
import 'sfx.dart';

enum Phase { ready, dropping, capsule, reveal, place, scoring, payday, failed, cleared, shop, over }

class Float {
  static int _ids = 0;
  final int id = ++_ids;
  final String text;
  final int kind; // 0 add, 1 buff, 2 mult, 3 minus
  Float(this.text, this.kind);
}

enum AdReward { remove, coins, luck }

/// Rewarded ads (the 広告で報酬 button and the payday 延長): iOS for now.
bool get kAdsEnabled => Ads.instance.enabled;

/// Steps of the guided first game. Action steps wait for the highlighted
/// control; info steps advance with a tap. [wait] blocks input during animations.
enum Coach {
  none,
  wait,
  spin1,
  place1,
  cell1,
  coins,
  goal,
  spin2,
  repull,
  item,
  tags,
  effect,
  place2,
  cell2,
  doubled,
  spin3,
  place3,
  cell3,
  spin4,
  place4,
  cell4,
  swap1,
  swap2,
  swap3,
  swapped,
  go,
  free,
  pay,
  expand,
  reroll,
  multi,
  leave,
  card,
  remove1,
  remove2,
  tools,
}

class GameController extends ChangeNotifier {
  final Meta meta;
  late Run run;
  Phase phase = Phase.ready;

  // shelf as shown (lags behind run.cells while steps play)
  List<Fig?> shown = [];
  final Map<int, int> badge = {};
  final Map<int, String> gave = {}; // what a cell did to others this turn (×2, +2), kept until the next spin
  List<int> pulse = [];
  List<int> hit = [];
  List<int> smoke = []; // a puff of smoke (the gold capsule opening, figures popping out)
  final Map<int, DateTime> _smokeAt = {};

  /// Whether cell [i]'s puff is still billowing (so a rebuilt cell never replays an old one).
  bool smoking(int i) {
    final t = _smokeAt[i];
    return t != null && DateTime.now().difference(t).inMilliseconds < 1000;
  }

  void _puff(int i) {
    smoke[i]++;
    _smokeAt[i] = DateTime.now();
    notifyListeners();
  }

  final Map<int, List<Float>> floats = {};

  List<FigureDef> options = [];
  Set<String> fresh = {};
  bool opened = false;
  final List<FigureDef> pending = [];
  bool removing = false;
  bool swapping = false; // いれかえ: pick two cells
  int? swapFirst;

  int coinsShown = 0;
  String? banner;
  int bannerToken = 0;
  int shakeToken = 0;
  int flashToken = 0;
  int lastTotal = 0;
  int totalToken = 0;

  int bossMood = 0;
  String bossLine = '';
  int bossToken = 0;

  PaydayResult? payday;
  bool _alive = true;
  bool newRecord = false;

  // how this run was set up, and what it unlocked
  final MachineDef machine;
  final int ascension;
  int? ascOpened;
  List<MachineDef> newMachines = [];
  bool turnRecord = false; // beat the best single turn this run

  // ── tutorial ──
  final bool tutorial;
  Coach coach = Coach.none;
  int _pulls = 0;
  static const tutorialCell1 = 6, tutorialCell2 = 7; // たこ焼き, then りんご飴 to its right
  // わたあめ far from the りんご飴, 狸の置物 right under it; then the two swap places
  static const tutorialCell3 = 12, tutorialCell4 = 11;
  static const _tutorialPulls = ['takoyaki', 'tanuki', 'ringoame', 'wataame', 'tanuki'];

  /// The info steps move on with a tap anywhere.
  void coachNext() {
    coach = switch (coach) {
      Coach.coins => Coach.goal,
      Coach.goal => Coach.spin2,
      Coach.item => Coach.tags,
      Coach.tags => Coach.effect,
      Coach.effect => Coach.place2,
      Coach.doubled => Coach.spin3,
      Coach.swapped => Coach.go,
      Coach.multi => Coach.leave,
      Coach.tools => Coach.none,
      final c => c,
    };
    if (coach == Coach.none) meta.finishTutorial();
    notifyListeners();
  }

  // ── festival level ──
  int _counted = 0; // run.earned already added to the lifetime total
  List<int> levelUps = []; // levels reached during this run

  /// Moves this run's new earnings into the lifetime total and the level gauge.
  void _countEarned() {
    meta.addEarned(run.earned - _counted);
    _counted = run.earned;
  }

  int? turnRank; // 全国順位 on that board, once known
  int _step = 0;

  GameController(this.meta, {MachineDef? machine, this.ascension = 0, this.tutorial = false}) : machine = machine ?? machines.first {
    newRun();
  }

  void newRun() {
    // the pool is fixed for the run: figures unlocked mid-run drop from the next one
    run = Run(seed: DateTime.now().microsecondsSinceEpoch, rules: rulesFor(machine, ascension)..level = meta.level);
    _counted = 0;
    levelUps = [];
    for (final f in run.figs) {
      meta.see(f.def.id);
    }
    ascOpened = null;
    newMachines = [];
    turnRecord = false;
    turnRank = null;
    phase = Phase.ready;
    pending.clear();
    badge.clear();
    floats.clear();
    removing = false;
    swapping = false;
    swapFirst = null;
    gave.clear();
    payday = null;
    newRecord = false;
    _adAt = -1;
    _syncShelf();
    coinsShown = run.coins;
    lastTotal = 0;
    say(0, pick(lineStart), voice: false);
    if (tutorial) {
      coach = Coach.spin1;
      _pulls = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    timeDilation = 1;
    super.dispose();
  }

  void _syncShelf() {
    shown = List.of(run.cells);
    if (pulse.length != shown.length) {
      pulse = List.filled(shown.length, 0);
      hit = List.filled(shown.length, 0);
      smoke = List.filled(shown.length, 0);
    }
  }

  // ── fast-forward: a finger held down while the coins are counted ──
  static const fastSpeed = 3;
  bool _held = false;
  bool get fast => _held && phase == Phase.scoring;
  set holding(bool v) {
    if (_held == v) return;
    _held = v;
    _syncSpeed();
  }

  /// Animations speed up with the beats (timeDilation below 1 runs them faster).
  void _syncSpeed() {
    final d = fast ? 1 / fastSpeed : 1.0;
    if (timeDilation != d) {
      timeDilation = d;
      notifyListeners();
    }
  }

  /// While scoring, waits in small slices so a hold takes effect mid-wait.
  Future<void> _wait(int ms) async {
    if (phase != Phase.scoring) return Future.delayed(Duration(milliseconds: ms));
    const slice = 16;
    var left = ms.toDouble();
    while (left > 0 && _alive) {
      await Future.delayed(const Duration(milliseconds: slice));
      left -= slice * (fast ? fastSpeed : 1);
    }
  }

  void say(int mood, String line, {bool voice = true}) {
    bossMood = mood;
    bossLine = line;
    bossToken++;
    if (voice) Sfx.play('boss_$mood', volume: 0.7);
  }

  // ── gacha ──
  Future<void> turnHandle() async {
    if (phase != Phase.ready) return;
    phase = Phase.dropping;
    lastTotal = 0; // the last turn's gain stays up until the next spin
    badge.clear();
    gave.clear();
    removing = false;
    swapping = false;
    swapFirst = null;
    if (const [Coach.spin1, Coach.spin2, Coach.spin3, Coach.spin4].contains(coach)) coach = Coach.wait;
    if (coach == Coach.go) coach = Coach.free;
    await _drop();
  }

  /// Puts the capsule back and pulls again (free; limited uses per payday).
  Future<void> repull() async {
    if (phase != Phase.reveal || run.repulls <= 0) return;
    run.repulls--;
    if (coach == Coach.repull) coach = Coach.wait;
    Sfx.play('reroll');
    // never worse than what was just in hand
    final floor = bestOption == Rarity.curse ? Rarity.normal : bestOption;
    phase = Phase.dropping;
    await _drop(run.pullAtLeast(floor));
  }

  Future<void> _drop([List<FigureDef>? pulled]) async {
    options = pulled ?? run.pull();
    // the tutorial's draws are fixed so every step can be shown
    if (tutorial && _pulls < _tutorialPulls.length) {
      options = [figureById[_tutorialPulls[_pulls]]!];
      _pulls++;
    }
    opened = false;
    HapticFeedback.mediumImpact();
    notifyListeners();
    await _wait(300);
    // the capsule sounds fancier the rarer the best thing inside is
    final best = bestOption;
    Sfx.play('drop_${best == Rarity.curse ? 0 : math.min(best.index, 3)}');
    await _wait(450);
    if (!_alive || phase == Phase.over) return;
    phase = Phase.capsule;
    if (coach == Coach.wait) Future.delayed(const Duration(milliseconds: 600), openCapsule);
    Sfx.play(omen ? 'omen' : 'rattle');
    notifyListeners();
  }

  /// The rarest drop (the boss's card ranks lowest).
  Rarity get bestOption =>
      options.map((o) => o.rarity).reduce((a, b) => (a == Rarity.curse ? -1 : a.index) >= (b == Rarity.curse ? -1 : b.index) ? a : b);

  bool get omen => bestOption != Rarity.curse && bestOption.index >= Rarity.epic.index;

  Future<void> openCapsule() async {
    if (phase != Phase.capsule) return;
    opened = true;
    phase = Phase.reveal;
    if (coach == Coach.wait) {
      coach = switch (options.first.id) {
        'takoyaki' => Coach.place1,
        'tanuki' => _pulls == 2 ? Coach.repull : Coach.place4,
        'ringoame' => Coach.item,
        'wataame' => Coach.place3,
        _ => Coach.wait,
      };
    }
    final best = bestOption;
    if (omen) {
      flashToken++;
      shakeToken++;
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    if (best == Rarity.legend) say(2, pick(lineLegend));
    if (best == Rarity.curse) say(1, 'ワシの名刺や！ ハズレちゃうで、記念品や');
    fresh = {
      for (final o in options)
        if (!meta.seen.contains(o.id)) o.id,
    };
    Sfx.play('open');
    Future.delayed(const Duration(milliseconds: 90), () {
      Sfx.play(best == Rarity.curse ? 'minus' : 'reveal_${math.min(best.index, 3)}');
      if (fresh.isNotEmpty) Future.delayed(const Duration(milliseconds: 350), () => Sfx.play('new', volume: 0.7));
    });
    for (final o in options) {
      meta.see(o.id);
    }
    notifyListeners();
  }

  void choose(FigureDef d) {
    if (phase != Phase.reveal) return;
    Sfx.play('tap');
    pending.add(d);
    phase = Phase.place;
    if (coach == Coach.place1) coach = Coach.cell1;
    if (coach == Coach.place2) coach = Coach.cell2;
    if (coach == Coach.place3) coach = Coach.cell3;
    if (coach == Coach.place4) coach = Coach.cell4;
    notifyListeners();
  }

  /// The boss's card must go on the shelf unless there is no room.
  bool get canDiscard => pending.isNotEmpty && (pending.first.id != kCardId || run.emptyCells.isEmpty);

  void discardPending() {
    if (!canDiscard) return;
    Sfx.play('pop');
    pending.removeAt(0);
    _afterPlace();
  }

  Future<void> tapCell(int i) async {
    if (swapping) {
      // the tutorial swaps the わたあめ with the 狸の置物
      if (coach == Coach.swap2 && i != tutorialCell3) return;
      if (coach == Coach.swap3 && i != tutorialCell4) return;
      if (swapFirst == null) {
        if (shown[i] == null) return;
        swapFirst = i;
        if (coach == Coach.swap2) coach = Coach.swap3;
        Sfx.play('tap');
        pulse[i]++;
        notifyListeners();
        return;
      }
      final a = swapFirst!;
      swapFirst = null;
      swapping = false;
      if (a != i && run.swap(a, i)) {
        if (coach == Coach.swap3) coach = Coach.swapped;
        final ba = badge.remove(a), bi = badge.remove(i);
        if (ba != null) badge[i] = ba;
        if (bi != null) badge[a] = bi;
        final ga = gave.remove(a), gi = gave.remove(i);
        if (ga != null) gave[i] = ga;
        if (gi != null) gave[a] = gi;
        _syncShelf();
        pulse[a]++;
        pulse[i]++;
        Sfx.play('place');
        HapticFeedback.selectionClick();
      }
      notifyListeners();
      return;
    }
    if (removing) {
      if (shown[i] == null) return;
      // the tutorial wants the boss's card gone
      if (coach == Coach.remove2 && shown[i]!.def.id != kCardId) return;
      if (coach == Coach.remove2) coach = Coach.tools;
      final g = run.remove(i);
      badge.remove(i);
      gave.remove(i);
      removing = false;
      _float(i, g > 0 ? '+$g' : 'ポイ', 0);
      Sfx.play('pop');
      if (g > 0) Sfx.play('buy');
      hit[i]++;
      HapticFeedback.mediumImpact();
      _syncShelf();
      coinsShown = run.coins;
      notifyListeners();
      return;
    }
    if (phase != Phase.place || pending.isEmpty) return;
    // the tutorial wants a particular cell
    if (coach == Coach.cell1 && i != tutorialCell1) return;
    if (coach == Coach.cell2 && i != tutorialCell2) return;
    if (coach == Coach.cell3 && i != tutorialCell3) return;
    if (coach == Coach.cell4 && i != tutorialCell4) return;
    if (const [Coach.cell1, Coach.cell2, Coach.cell3, Coach.cell4].contains(coach)) coach = Coach.wait;
    // the new figure can go over an old one
    if (run.cells[i] != null && !run.canOverwrite(i)) return;
    final over = run.cells[i] != null;
    final d = pending.removeAt(0);
    final steps = over ? run.overwrite(d, i) : run.place(d, i);
    badge.remove(i);
    gave.remove(i);
    if (over) hit[i]++;
    meta.see(d.id);
    final capsule = d.effect<OnPlacedSpawnRare>() != null;
    // the gold capsule itself goes on the shelf first (run.cells already holds what pops out)
    shown[i] = capsule ? Fig(d, -1) : (run.cells[i] ?? Fig(d, -1));
    pulse[i]++;
    _step = 0;
    Sfx.play('place');
    HapticFeedback.selectionClick();
    notifyListeners();
    if (capsule) {
      // it sits a moment, wobbles twice, then bursts into smoke and the figures pop out
      await _wait(700);
      for (final ms in const [450, 350]) {
        hit[i]++;
        Sfx.play('rattle');
        HapticFeedback.lightImpact();
        notifyListeners();
        await _wait(ms);
      }
    }
    for (final s in steps) {
      if (!capsule) await _wait(260);
      if (capsule && (s.kind == StepKind.remove || (s.kind == StepKind.spawn && s.idx != i))) {
        // one puff where the capsule was (the first figure appears inside it), one for each other figure
        _puff(s.idx);
        await _wait(s.kind == StepKind.remove ? 120 : 250);
      }
      _apply(s);
      if (capsule) await _wait(s.kind == StepKind.remove ? 380 : 450);
    }
    if (capsule) await _wait(300);
    for (final f in run.figs) {
      meta.see(f.def.id);
    }
    _syncShelf();
    coinsShown = run.coins;
    notifyListeners();
    await _wait(steps.isEmpty ? 120 : 300);
    _afterPlace();
  }

  // ── ad reward: one extra remove ticket per payday period ──
  int _adAt = -1; // paydaysPaid when the ad was last watched
  bool get canWatchAd => kAdsEnabled && _adAt != run.paydaysPaid && phase == Phase.ready;

  /// Coins the "coins" ad reward gives: a quarter of the next payday.
  int get adCoins => math.max(3, run.due ~/ 4);

  /// Plays a rewarded ad; the reward comes once it has been watched.
  Future<void> watchAd(AdReward reward) async {
    if (!canWatchAd) return;
    if (!await Ads.instance.show(() => _grant(reward))) _adNotReady();
  }

  void _adNotReady() {
    say(0, '広告の準備中や。ちょっと待ってから もう一回押してな', voice: false);
    notifyListeners();
  }

  void _grant(AdReward reward) {
    if (!canWatchAd) return;
    _adAt = run.paydaysPaid;
    switch (reward) {
      case AdReward.remove:
        run.removeTickets = run.removeMax;
        run.swapTickets = run.swapMax;
        run.repulls = run.repullMax;
        say(1, 'しゃあない、どける・いれかえ 使えるようにしたる', voice: false);
      case AdReward.coins:
        run.coins += adCoins;
        coinsShown = run.coins;
        say(2, '小判 $adCoins 枚、もってき！', voice: false);
      case AdReward.luck:
        run.luckBonus += 5;
        say(1, '運を 5% 上げといたで', voice: false);
    }
    Sfx.play('buy');
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void toggleSwap() {
    if (run.swapTickets <= 0 || phase == Phase.scoring) return;
    // the tutorial's swap has to happen once it has been pointed at
    if (coach == Coach.swap2 || coach == Coach.swap3) return;
    swapping = !swapping;
    swapFirst = null;
    removing = false;
    if (coach == Coach.swap1 && swapping) coach = Coach.swap2;
    Sfx.play('toggle');
    notifyListeners();
  }

  /// Used-up どける / いれかえ: the boss points at his stall.
  void ticketUsed() {
    say(0, 'もう使うたやろ。次の取り立てが済んだら また使えるで', voice: false);
    notifyListeners();
  }

  /// The tutorial showed what the boss's card does; now it can be removed.
  void cardSeen() {
    if (coach != Coach.card) return;
    coach = Coach.remove1;
    notifyListeners();
  }

  void toggleRemove() {
    if (run.removeTickets <= 0 || phase == Phase.scoring) return;
    swapping = false;
    swapFirst = null;
    removing = !removing;
    if (coach == Coach.remove1 && removing) coach = Coach.remove2;
    Sfx.play('toggle');
    notifyListeners();
  }

  void _afterPlace() {
    if (phase == Phase.over) return; // gave up from the menu mid-animation
    if (pending.isNotEmpty) {
      notifyListeners();
      return;
    }
    if (_fromShop) {
      _fromShop = false;
      phase = Phase.ready;
      say(0, pick(lineIdle));
      notifyListeners();
      return;
    }
    _score();
  }

  bool _fromShop = false;

  // ── scoring ──
  void _float(int i, String t, int kind) {
    (floats[i] ??= []).add(Float(t, kind));
    if (floats[i]!.length > 4) floats[i]!.removeAt(0);
  }

  void _apply(Step s) {
    switch (s.kind) {
      case StepKind.add:
        badge[s.idx] = (badge[s.idx] ?? 0) + s.amount;
        pulse[s.idx]++;
        _float(s.idx, s.amount > 0 ? '+${s.amount}' : '${s.amount}', s.amount > 0 ? 0 : 3);
        s.amount > 0 ? Sfx.tick(_step++) : Sfx.play('minus');
        HapticFeedback.selectionClick();
      case StepKind.instant:
        pulse[s.idx]++;
        _float(s.idx, '+${s.amount}', 0);
        Sfx.tick(_step++);
        coinsShown += s.amount;
      case StepKind.buff:
        Sfx.play('buff');
        pulse[s.idx]++;
        gave[s.idx] = '+${s.amount}';
        for (final t in s.targets) {
          badge[t] = (badge[t] ?? 0) + s.amount;
          hit[t]++;
          _float(t, '+${s.amount}', 1);
        }
        HapticFeedback.selectionClick();
      case StepKind.mult:
        pulse[s.idx]++;
        gave[s.idx] = '×${s.amount}';
        for (final t in s.targets) {
          badge[t] = (badge[t] ?? 0) * s.amount;
          hit[t]++;
          _float(t, '×${s.amount}', 2);
        }
        if (s.targets.length >= 4) {
          banner = '×${s.amount}!!';
          bannerToken++;
          shakeToken++;
          Sfx.play('mult_big');
        } else {
          Sfx.play('mult');
        }
        HapticFeedback.mediumImpact();
      case StepKind.shoot:
        pulse[s.idx]++;
        for (final t in s.targets) {
          hit[t]++;
          shown[t] = null;
          badge.remove(t);
        }
        badge[s.idx] = s.amount;
        _float(s.idx, '+${s.amount}', 0);
        shakeToken++;
        Sfx.play('shoot');
        HapticFeedback.heavyImpact();
      case StepKind.remove:
        Sfx.play('pop');
        hit[s.idx]++;
        shown[s.idx] = null;
        badge.remove(s.idx);
        gave.remove(s.idx);
      case StepKind.spawn:
        Sfx.play('spawn');
        shown[s.idx] = s.fig;
        pulse[s.idx]++;
        if (s.fig != null) meta.see(s.fig!.def.id);
    }
    notifyListeners();
  }

  Future<void> _score() async {
    phase = Phase.scoring;
    _syncSpeed(); // a finger may already be down
    badge.clear();
    _step = 0;
    final res = run.endTurn();
    notifyListeners();
    await _wait(200);
    // beats speed up as they pile on, like a slot paying out
    var ms = 300;
    for (final s in res.steps) {
      if (!_alive) return;
      if (s.kind == StepKind.remove && shown[s.idx] == null) continue;
      _apply(s);
      await _wait(s.kind == StepKind.mult ? ms + 180 : ms);
      ms = math.max(110, (ms * 0.9).round());
    }
    lastTotal = res.total;
    totalToken++;
    final big = res.total >= 40 && res.total >= run.due ~/ 3;
    if (res.total > 0) Sfx.play(big ? 'total_big' : 'total_small');
    if (big) {
      shakeToken++;
      HapticFeedback.heavyImpact();
      say(2, pick(lineBigTurn));
    } else if (res.total < 3 && run.turn > 3) {
      say(0, pick(lineSmallTurn));
    } else if (math.Random().nextDouble() < 0.25) {
      say(0, pick(lineIdle), voice: false);
    }
    coinsShown = run.coins; // the per-cell numbers stay up until the next spin
    notifyListeners();
    await _wait(700);
    _syncShelf();
    _countEarned();
    if (meta.recordTurn(res.total)) {
      turnRecord = true;
      Rank.instance.submit(Board.bestTurn, res.total);
    }
    if (run.paydayNow) {
      phase = Phase.payday;
      payday = null;
      Sfx.play('payday');
      say(0, '取り立てや！ ${run.due}コイン、きっちりもらうで', voice: false);
      if (coach == Coach.free) coach = Coach.pay;
    } else {
      phase = Phase.ready;
      if (coach == Coach.wait) {
        coach = switch (run.turn) {
          1 => Coach.coins,
          2 => Coach.doubled,
          3 => Coach.spin4,
          _ => Coach.swap1,
        };
      }
    }
    _syncSpeed(); // back to normal speed once the counting is over
    notifyListeners();
  }

  // ── payday ──
  Future<void> pay() async {
    if (phase != Phase.payday || payday != null) return;
    final p = run.payday();
    payday = p;
    if (!p.paid) {
      Sfx.play('pay_fail');
      say(3, pick(lineFail));
      shakeToken++;
      HapticFeedback.heavyImpact();
      coinsShown = run.coins;
      // straight to the 足りない card (no second pop-up in between)
      phase = Phase.failed;
      notifyListeners();
      return;
    }
    coinsShown = run.coins;
    Sfx.play('pay_ok');
    say(1, pick(p.cardCells.isNotEmpty ? lineCard : linePaid));
    HapticFeedback.mediumImpact();
    _syncShelf();
    for (final c in p.cardCells) {
      pulse[c]++;
    }
    meta.recordPaydays(run.paydaysPaid);
    if (run.cleared && run.paydaysPaid == Run.clearPaydays) {
      phase = Phase.cleared;
      Sfx.play('clear');
      say(2, pick(lineClear), voice: false);
      ascOpened = meta.recordClear(ascension);
      Rank.instance.submit(Board.ascension, ascension);
    } else {
      _openShop();
    }
    notifyListeners();
  }

  /// Rewarded-ad rescue from a payday that came up short.
  Future<void> watchAdToPostpone() async {
    if (!run.canPostpone) return;
    if (!await Ads.instance.show(postpone)) _adNotReady();
  }

  void postpone() {
    if (!run.canPostpone) return;
    run.postpone();
    say(0, pick(linePostpone));
    _openShop();
    notifyListeners();
  }

  /// The menu's あきらめる: not while a spin or the coin count is playing out.
  bool get canGiveUp => phase != Phase.dropping && phase != Phase.scoring && phase != Phase.over;

  void giveUp() {
    if (phase == Phase.over) return;
    if (tutorial) meta.finishTutorial();
    _countEarned();
    // the level goes up (by one at most) when the run is over; celebrated on the result screen
    if (meta.finishRun() case final up?) levelUps.add(up);
    phase = Phase.over;
    // how far the run got, extensions included
    if (run.paydaysPaid > 0) Rank.instance.submit(Board.paydays, run.paydaysPaid);
    newRecord = meta.recordPaydays(run.paydaysPaid);
    meta.recordRun();
    if (turnRecord) _fetchTurnRank();
    newMachines = meta.takeNewMachines();
    Sfx.play(run.cleared ? 'jingle' : 'over');
    if (newMachines.isNotEmpty || ascOpened != null) {
      Future.delayed(const Duration(milliseconds: 900), () => Sfx.play('unlock'));
    }
    notifyListeners();
  }

  Future<void> _fetchTurnRank() async {
    final r = await Rank.instance.myRank(Board.bestTurn);
    if (!_alive || r == null) return;
    turnRank = r;
    notifyListeners();
  }

  void keepGoing() {
    _openShop();
    notifyListeners();
  }

  // ── shop ──
  void _openShop() {
    if (coach == Coach.pay) {
      coach = Coach.expand;
      // the boss's card turns up early in the tutorial, so どける can be shown on it
      run.leaveCard();
      _syncShelf();
      // the tutorial shows off the shelf upgrade: make sure it is there and affordable
      Future.microtask(() {
        // still three items: the upgrade replaces one of them
        run.shop.removeWhere((o) => o.kind == OfferKind.expand);
        if (run.shop.length >= 3) run.shop.removeLast();
        run.shop.insert(0, Offer(OfferKind.expand, math.min(run.expandPrice, run.coins ~/ 2)));
        notifyListeners();
      });
    }
    run.rollShop();
    phase = Phase.shop;
    Sfx.play('shop');
  }

  Future<void> buy(Offer o) async {
    final oldCols = run.cols;
    final d = run.buy(o);
    if (!o.sold) return;
    // a wider shelf renumbers the cells: move the per-cell numbers with their figures
    if (run.cols != oldCols) {
      int moved(int i) => (i ~/ oldCols) * run.cols + i % oldCols;
      final b = {for (final e in badge.entries) moved(e.key): e.value};
      final gv = {for (final e in gave.entries) moved(e.key): e.value};
      badge
        ..clear()
        ..addAll(b);
      gave
        ..clear()
        ..addAll(gv);
      floats.clear();
    }
    Sfx.play('buy');
    HapticFeedback.mediumImpact();
    if (d != null) pending.add(d);
    if (o.kind == OfferKind.expand) _syncShelf();
    coinsShown = run.coins;
    notifyListeners();
    if (coach == Coach.expand && o.kind == OfferKind.expand) {
      // next: 品がえ
      coach = Coach.reroll;
      notifyListeners();
    }
  }

  void reroll() {
    if (run.reroll()) {
      Sfx.play('reroll');
      coinsShown = run.coins;
      HapticFeedback.selectionClick();
      if (coach == Coach.reroll) coach = Coach.multi;
    }
    notifyListeners();
  }

  void leaveShop() {
    if (phase != Phase.shop) return;
    if (coach == Coach.leave) coach = Coach.card;
    _syncShelf();
    if (pending.isNotEmpty) {
      _fromShop = true;
      phase = Phase.place;
    } else {
      phase = Phase.ready;
      say(0, pick(lineIdle));
    }
    notifyListeners();
  }
}
