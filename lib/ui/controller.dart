// Drives one run on screen: phases, timed playback of scoring steps, and the
// small bits of display state (pulses, floating numbers, boss mood) widgets
// animate from. Game rules live in logic/run.dart only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../logic/achievements.dart';
import '../logic/defs.dart';
import '../logic/figures.dart';
import '../logic/modes.dart';
import '../logic/run.dart';
import 'lines.dart';
import 'meta.dart';
import 'ads/ads.dart';
import 'rank.dart';
import 'crowd.dart';
import 'sfx.dart';
import 'voice.dart';

enum Phase { ready, dropping, capsule, cutin, reveal, place, jam, scoring, payday, failed, cleared, shop, over }

/// Light from a goods to the goods it buffs (+) or multiplies (×).
class Beam {
  final int from;
  final List<int> to;
  final bool mult;
  final int amount;
  final int born = DateTime.now().millisecondsSinceEpoch;
  Beam(this.from, this.to, this.mult, this.amount);
}

class Float {
  static int _ids = 0;
  final int id = ++_ids;
  final String text;
  final int kind; // 0 add, 1 buff, 2 mult, 3 minus
  Float(this.text, this.kind);
}

enum AdReward { repull, coins, luck }

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
  go,
}

/// One piece of news for the top of the screen.
class TopToast {
  final List<Achievement>? achievements;
  final (MachineDef, List<FigureDef>)? figures; // a first clear: the goods it brings into the gacha
  final List<MachineDef>? machines;
  const TopToast({this.achievements, this.figures, this.machines});
}

class GameController extends ChangeNotifier {
  final Meta meta;
  late Run run;
  Phase phase = Phase.ready;

  // shelf as shown (lags behind run.cells while steps play)
  List<Fig?> shown = [];
  final Map<int, int> powerUp = {}; // cell → token: a stacked goods' burst
  final Map<int, int> heartPop = {}; // cell → token: little hearts out of a goods that earned

  // ── juice ──
  // the running count while the hearts come in (the top-left badge grows with it)
  int liveTotal = 0, milestoneToken = 0;
  final List<Beam> beams = [];
  int rareToken = 0; // a レア商品 came in at the stall
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

  // an idol popping in to talk (on a pull, or cheering a big turn)
  String? idol;
  String idolLine = '';
  int idolToken = 0;
  bool idolBig = false; // ★3/★4: the full-screen cut-in
  bool idolOnPull = false; // said over this capsule (shown inside the reveal)

  PaydayResult? payday;
  String overLine = '';

  // ── the live ──
  /// How hot the hall is: 0 when a live starts, 1 when it goes wild. Each song
  /// starts a little warmer than the last and heats up as hearts reach its quota.
  double get hype {
    if (run.cleared) return 1;
    final base = run.paydaysPaid / Run.clearPaydays * 0.3;
    // slow at first, so a fresh song starts quiet and the last hearts to the quota feel big
    final f = math.pow((coinsShown / math.max(1, run.due)).clamp(0.0, 1.0), 1.7).toDouble();
    return (base + f * (1 - base)).clamp(0.0, 1.0);
  }

  int burstToken = 0; // confetti

  // ── news at the top of the screen: 実績, new goods in the gacha, a new gacha — one at a time ──
  TopToast? toast;
  int toastToken = 0;
  final List<TopToast> _toasts = [];
  Timer? _toastTimer;
  final List<Achievement> runAchievements = []; // unlocked during this live

  void _pushToast(TopToast t) {
    _toasts.add(t);
    if (toast == null) _nextToast();
  }

  void _nextToast() {
    if (!_alive) return;
    if (_toasts.isEmpty) {
      toast = null;
      notifyListeners();
      return;
    }
    toast = _toasts.removeAt(0);
    toastToken++;
    final token = toastToken;
    Future.delayed(const Duration(milliseconds: 400), () => Sfx.play('unlock'));
    notifyListeners();
    // each stays up as long as its slide-in, read and fade-out take
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 4300), () {
      if (toastToken == token) _nextToast();
    });
  }

  void _checkAchievements() {
    final got = meta.checkAchievements();
    if (got.isEmpty) return;
    runAchievements.addAll(got);
    _pushToast(TopToast(achievements: got));
  }

  /// Counts each idol's goods on the altar now (for the 祭壇 achievements).
  void _noteAltar() => meta.noteAltar(run.castCounts());
  String? songIdol; // who thanks the crowd after a song
  String songLine = '';
  bool _alive = true;
  bool newRecord = false;

  // how this run was set up, and what it unlocked
  final MachineDef machine;
  List<MachineDef> newMachines = [];
  bool turnRecord = false; // beat the best single turn this run

  // ── tutorial ──
  final bool tutorial;
  Coach coach = Coach.none;
  int _pulls = 0;
  static const tutorialCell1 = 6, tutorialCell2 = 7; // こはるのアクキー, then こはるのアクスタ to its right
  static const _tutorialPulls = ['koharu_keyholder', 'momo_badge', 'koharu_acsta'];

  /// The info steps move on with a tap anywhere.
  void coachNext() {
    coach = switch (coach) {
      Coach.coins => Coach.goal,
      Coach.goal => Coach.spin2,
      Coach.item => Coach.tags,
      Coach.tags => Coach.effect,
      Coach.effect => Coach.place2,
      Coach.doubled => Coach.go,
      final c => c,
    };
    if (coach == Coach.none) meta.finishTutorial();
    notifyListeners();
  }

  // ── lifetime hearts (a record) ──
  int _counted = 0; // run.earned already added to the lifetime total

  /// Moves this run's new earnings into the lifetime total.
  void _countEarned() {
    meta.addEarned(run.earned - _counted);
    _counted = run.earned;
  }

  int? turnRank; // 全国順位 on that board, once known
  int _step = 0;

  GameController(this.meta, {MachineDef? machine, this.tutorial = false}) : machine = machine ?? machines.first {
    newRun();
  }

  void newRun() {
    // the pool is fixed for the run: figures unlocked mid-run drop from the next one
    run = Run(seed: DateTime.now().microsecondsSinceEpoch, rules: rulesFor(machine)..open = meta.openFigures);
    // `--dart-define=JAM_DEMO=true`: a 妨害 every turn, to check its screens
    if (const bool.fromEnvironment('JAM_DEMO')) run.rules.jamRate = 1;
    // `--dart-define=STACK_DEMO=true`: a few goods already on the altar and the gacha drops only
    // those, so stacking the same goods (×2, ×3, …) can be tried right away
    // `--dart-define=JUICE_DEMO=true`: the big moments come often, to try them out —
    // ★3/★4 capsules (昇格演出), a レア商品 at every stall, a low best spin (FEVER) and spare hearts
    if (const bool.fromEnvironment('JUICE_DEMO')) {
      run.luckBonus += 60;
      run.rareChance = 1;
      run.coins += 60;
      run.rules.jamRate = 0;
      meta.bestTurn = 10;
    }
    if (const bool.fromEnvironment('STACK_DEMO')) {
      const ids = ['koharu_badge', 'hinata_badge', 'yoru_star', 'shizuku_snow'];
      for (final (k, id) in ids.indexed) {
        final at = const [5, 6, 9, 10][k];
        if (run.cells[at] == null) run.place(figureById[id]!, at);
      }
      run.rules.idWeight.addAll({for (final id in ids) id: 1e6});
      run.rules.jamRate = 0;
    }
    _counted = 0;
    for (final f in run.figs) {
      meta.see(f.def.id);
    }
    newMachines = [];
    toast = null;
    _toasts.clear();
    _toastTimer?.cancel();
    turnRecord = false;
    turnRank = null;
    phase = Phase.ready;
    pending.clear();
    badge.clear();
    floats.clear();
    gave.clear();
    jam = null;
    payday = null;
    newRecord = false;
    runAchievements.clear();
    _adAt = -1;
    _syncShelf();
    coinsShown = run.coins;
    lastTotal = 0;
    say(0, pick(lineStart));
    if (tutorial) {
      coach = Coach.spin1;
      _pulls = 0;
    }
    Bgm.play('bgm_${machine.bgm}', fromStart: true); // a new live: its song from the top
    notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    _toastTimer?.cancel();
    timeDilation = 1;
    Voice.stop();
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

  // ── fast-forward while the coins are counted: ×2 on its own once the altar is crowded,
  //    ×3 while a finger is held down ──
  static const fastSpeed = 3, autoSpeed = 2;
  static const autoFastGoods = 10; // this many goods on the altar and the count runs at ×2
  bool _held = false;
  int get speed => phase != Phase.scoring ? 1 : (_held ? fastSpeed : (run.figs.length >= autoFastGoods ? autoSpeed : 1));
  bool get fast => speed > 1;
  set holding(bool v) {
    if (_held == v) return;
    _held = v;
    _syncSpeed();
  }

  /// Animations speed up with the beats (timeDilation below 1 runs them faster).
  void _syncSpeed() {
    final d = 1 / speed;
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
      left -= slice * speed;
    }
  }

  /// つむぎ says [line] (text only: she has no voice in play).
  void say(int mood, String line) {
    bossMood = mood;
    bossLine = line;
    bossToken++;
  }

  /// A goods with an idol on it was tapped on the altar: she says hello.
  void tapFigure(FigureDef d) {
    if (_coaching || d.cast.isEmpty || phase == Phase.scoring || phase == Phase.jam) return;
    final who = d.cast[math.Random().nextInt(d.cast.length)];
    final lines = idolLines[who]!;
    idolSay(who, pick(math.Random().nextBool() ? lines.pull : lines.talk));
    notifyListeners();
  }

  /// The player pokes つむぎ on the stage: she chats (not mid-count or in the tutorial).
  void tapTsumugi() {
    if (_coaching || phase == Phase.scoring) return;
    say(math.Random().nextInt(3) == 0 ? 1 : 0, pick(lineTap));
    notifyListeners();
  }

  /// One of the idols pops in and says [line].
  void idolSay(String who, String line, {bool big = false}) {
    idol = who;
    idolLine = line;
    idolBig = big;
    idolOnPull = phase == Phase.capsule || phase == Phase.cutin || phase == Phase.reveal;
    idolToken++;
    Voice.say(who, line, delayMs: big ? 350 : 220);
  }

  /// The tutorial's own explanations are spoken; the idols keep quiet then.
  bool get _coaching => tutorial && coach != Coach.none;

  // ── gacha ──
  Future<void> turnHandle() async {
    if (phase != Phase.ready) return;
    phase = Phase.dropping;
    lastTotal = 0; // the last turn's gain stays up until the next spin
    idol = null;
    badge.clear();
    heartPop.clear(); // (a later rebuild must not pop old hearts again)
    gave.clear();
    if (const [Coach.spin1, Coach.spin2].contains(coach)) coach = Coach.wait;
    // the last guided step: spinning on from here is the game itself
    if (coach == Coach.go) {
      coach = Coach.none;
      meta.finishTutorial();
    }
    await _drop();
  }

  /// Puts the capsule back and pulls again (free; limited uses per payday).
  Future<void> repull() async {
    if (phase != Phase.reveal || run.repulls <= 0) return;
    run.repulls--;
    idol = null;
    if (coach == Coach.repull) coach = Coach.wait;
    Sfx.play('reroll');
    // never worse than what was just in hand
    final floor = bestOption;
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
    Sfx.play('drop_${math.min(best.index, 3)}');
    await _wait(450);
    if (!_alive || phase == Phase.over) return;
    phase = Phase.capsule;
    if (coach == Coach.wait) Future.delayed(const Duration(milliseconds: 600), openCapsule);
    Sfx.play(omen ? 'omen' : 'rattle');
    notifyListeners();
  }

  /// The rarest drop.
  Rarity get bestOption => options.map((o) => o.rarity).reduce((a, b) => a.index >= b.index ? a : b);

  bool get omen => bestOption.index >= Rarity.epic.index;

  /// The best option that has an idol on it, and who of them talks.
  (FigureDef, String)? get _speaker {
    final withCast = options.where((o) => o.cast.isNotEmpty).toList()
      ..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
    if (withCast.isEmpty) return null;
    final f = withCast.first;
    return (f, f.cast[math.Random().nextInt(f.cast.length)]);
  }

  Future<void> openCapsule() async {
    if (phase != Phase.capsule) return;
    opened = true;
    final sp = _coaching ? null : _speaker;
    final best = bestOption;
    if (sp != null && best.index >= Rarity.epic.index && sp.$1.rarity == best) {
      // ★3 / ★4 with an idol on it: she cuts in first, then the goods come out
      final lines = idolLines[sp.$2]!;
      phase = Phase.cutin;
      flashToken++;
      burstToken++;
      Crowd.cheer();
      HapticFeedback.heavyImpact();
      Sfx.play('omen');
      idolSay(sp.$2, pick(best == Rarity.legend ? lines.ssr : lines.sr), big: true);
      notifyListeners();
      await _wait(2100);
      if (!_alive || phase != Phase.cutin) return;
      _reveal(null, fromCutin: true);
      return;
    }
    _reveal(sp);
  }

  /// Skips the rest of the cut-in.
  void skipCutin() {
    if (phase == Phase.cutin) _reveal(null, fromCutin: true);
  }

  void _reveal((FigureDef, String)? sp, {bool fromCutin = false}) {
    phase = Phase.reveal;
    if (coach == Coach.wait) {
      coach = switch (options.first.id) {
        'koharu_keyholder' => Coach.place1,
        'momo_badge' => Coach.repull,
        'koharu_acsta' => Coach.item,
        _ => Coach.wait,
      };
    }
    final best = bestOption;
    if (best == Rarity.legend) meta.star4();
    if (omen) {
      flashToken++;
      shakeToken++;
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    if (sp != null) {
      idolSay(sp.$2, pick(idolLines[sp.$2]!.pull));
    } else if (fromCutin) {
      idolOnPull = true; // she stays on as a little bubble over the goods
    } else if (!_coaching) {
      if (best == Rarity.legend && options.every((o) => o.cast.isEmpty)) say(2, pick(lineLegend));
    }
    fresh = {
      for (final o in options)
        if (!meta.seen.contains(o.id)) o.id,
    };
    Sfx.play('open');
    Future.delayed(const Duration(milliseconds: 90), () {
      Sfx.play('reveal_${math.min(best.index, 3)}');
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
    notifyListeners();
  }

  bool get canDiscard => pending.isNotEmpty;

  void discardPending() {
    if (!canDiscard) return;
    Sfx.play('pop');
    pending.removeAt(0);
    _afterPlace();
  }

  Future<void> tapCell(int i) async {
    if (phase != Phase.place || pending.isEmpty) return;
    // the tutorial wants a particular cell
    if (coach == Coach.cell1 && i != tutorialCell1) return;
    if (coach == Coach.cell2 && i != tutorialCell2) return;
    if (const [Coach.cell1, Coach.cell2].contains(coach)) coach = Coach.wait;
    // the new figure can go over an old one
    if (run.cells[i] != null && !run.canOverwrite(i)) return;
    final over = run.cells[i] != null;
    final d = pending.removeAt(0);
    final stacking = over && run.stacksOn(d, i);
    final steps = over ? run.overwrite(d, i) : run.place(d, i);
    // the same goods on itself: it powers up (×2, ×3, …) and puts on an aura
    if (stacking) {
      meta.noteStack(run.cells[i]!.stack);
      powerUp[i] = (powerUp[i] ?? 0) + 1; // ギュイーン… ピカーン (PowerUpBurst)
      Sfx.play('omen');
      HapticFeedback.lightImpact();
      () async {
        await _wait(620);
        Sfx.play('mult_big');
        HapticFeedback.heavyImpact();
        await _wait(900);
        // done: drop it, so a later rebuild of the altar never plays it again
        powerUp.remove(i);
        notifyListeners();
      }();
    }
    badge.remove(i);
    gave.remove(i);
    if (over) hit[i]++;
    meta.see(d.id);
    if (d.cast.isNotEmpty && !_coaching) Crowd.call(speakerId[d.cast[math.Random().nextInt(d.cast.length)]]!);
    for (final m in d.cast) {
      meta.addPlaced(m);
    }
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
    _noteAltar();
    _checkAchievements();
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
    say(0, pick(lineAdWait));
    notifyListeners();
  }

  void _grant(AdReward reward) {
    if (!canWatchAd) return;
    _adAt = run.paydaysPaid;
    switch (reward) {
      case AdReward.repull:
        run.repulls = run.repullMax;
        say(1, pick(lineAdTickets));
      case AdReward.coins:
        run.coins += adCoins;
        coinsShown = run.coins;
        say(1, pick(lineAdCoins));
      case AdReward.luck:
        run.luckBonus += 5;
        say(1, pick(lineAdLuck));
    }
    Sfx.play('buy');
    HapticFeedback.mediumImpact();
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
    _jamThenScore();
  }

  // ── 妨害: the scalper barges in after placing, before the hearts are counted ──
  Jam? jam;
  int jamStage = 0; // 0 siren + cut-in, 1 what to do (one line at a time), 2 the shoving match, 3 the outcome
  int jamCount = 0; // the countdown before the shove: 3, 2, 1, then 0 = go
  double jamP = 0; // chance to fend him off, moved by まもれ！
  double jamLeft = 1; // shoving time left (1 → 0)
  bool? jamSaved;
  String jamIdol = 'ひなた'; // the idol with the most goods on the altar pushes back
  int jamToken = 0, jamTapToken = 0;
  List<FigureDef> jamTaken = []; // what he got away with

  // slow enough to follow: the cut-in, then the rules line by line, the shove, a beat of suspense, the outcome
  static const jamIntroMs = 2400, jamPushMs = 4500, jamOutroMs = 3800;
  Completer<void>? _jamGo;

  /// まもる！ on the explanation: the countdown starts.
  void jamReady() {
    if (phase != Phase.jam || jamStage != 1) return;
    Sfx.play('tap');
    if (_jamGo?.isCompleted == false) _jamGo!.complete();
  }
  // まもれ！ adds [jamTap]; the scalper pulls it back down. How hard he pulls changes all the time:
  // he is in one of seven hidden modes (weak … overpowering), each a pull worth [jamModeRate] taps a
  // second, held for a random while and wobbling ±40% inside it. Mode 4 out-pushes ordinary fast
  // mashing; modes 5 and 6 only come out against players who mash faster still (a phone mashes fast).
  // Held at the top, it is 100%.
  static const jamStart = 0.25, jamTap = 0.045, jamMin = 0.03;
  static const jamModeRate = [2.0, 3.0, 4.5, 7.5, 14.0, 19.0, 25.0];
  int jamMode = 0; // 0 weak … 6 monstrous (hidden)
  double jamForce = 0; // his pull right now, in taps a second (smoothed)

  int _jamTaps = 0; // まもれ！ taps in this shove, to learn how fast the player mashes

  /// The next mode: a stronger scalper ([Jam.power]) leans to the strong ones, and so does a player who
  /// mashes fast ([Meta.mashRate] above 7 a second; a slow one meets the weak ones more); never the same twice.
  int _nextJamMode(double power) {
    final rate = meta.mashRate ?? 7;
    final skill = ((rate - 7) / 4).clamp(-1.0, 1.5);
    // the two monstrous modes open up only for very fast mashers: from 10 and 12 taps a second
    double gate(int m) => m == 5 ? ((rate - 10) / 3).clamp(0.0, 1.0) : (m == 6 ? ((rate - 12) / 3).clamp(0.0, 1.0) : 1.0);
    final w = [
      for (var m = 0; m < jamModeRate.length; m++)
        m == jamMode ? 0.0 : [2.2, 3.0, 3.0, 2.2, 1.4, 1.2, 1.0][m] * math.pow(power, math.min(m, 4) - 1.5) * math.exp(skill * 0.55 * (math.min(m, 4) - 2)) * gate(m),
    ];
    var x = run.rng.nextDouble() * w.fold(0.0, (a, b) => a + b);
    for (var m = 0; m < jamModeRate.length; m++) {
      if ((x -= w[m]) < 0) return m;
    }
    return 2;
  }

  FigureDef? _jamGift;
  bool _giftPlacing = false;

  Future<void> _jamThenScore() async {
    if (_giftPlacing) {
      _giftPlacing = false;
      _score();
      return;
    }
    // never during the tutorial (its first song)
    final j = tutorial && !meta.tutorialDone ? null : run.rollJam();
    if (j != null) await _jam(j);
    if (!_alive || phase == Phase.over) return;
    // fended off for a goods: it goes on the altar first, then the hearts are counted
    if (_jamGift case final gift?) {
      _jamGift = null;
      pending.add(gift);
      _giftPlacing = true;
      phase = Phase.place;
      notifyListeners();
      return;
    }
    _score();
  }

  Future<void> _jam(Jam j) async {
    jam = j;
    jamStage = 0;
    jamCount = 3;
    jamP = jamStart;
    jamLeft = 1;
    jamSaved = null;
    jamTaken = [];
    jamToken++;
    jamIdol = run.topCast ?? members[math.Random().nextInt(members.length)];
    phase = Phase.jam;
    Sfx.play('siren');
    HapticFeedback.heavyImpact();
    shakeToken++;
    flashToken++;
    say(2, pick(lineJam));
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: jamIntroMs));
    if (!_alive || phase != Phase.jam) return;
    // what is at stake, then wait for まもる！
    jamStage = 1;
    _jamGo = Completer<void>();
    notifyListeners();
    await _jamGo!.future;
    if (!_alive || phase != Phase.jam) return;
    // 3, 2, 1 … まもれ！ only works once it says スタート
    jamStage = 2;
    for (jamCount = 3; jamCount > 0; jamCount--) {
      Sfx.play('tap');
      HapticFeedback.selectionClick();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_alive || phase != Phase.jam) return;
    }
    Sfx.play('omen');
    HapticFeedback.heavyImpact();
    Voice.say(jamIdol, pick(idolLines[jamIdol]!.jamHelp), delayMs: 0);
    notifyListeners();
    // real time (a throttled browser tab must not stretch it), or the frames counted
    // when the clock stands still (fake clocks in tests)
    final sw = Stopwatch()..start();
    var ms = 0;
    _jamTaps = 0;
    jamMode = _nextJamMode(j.power);
    jamForce = jamModeRate[jamMode];
    var modeUntil = 300 + run.rng.nextInt(900), target = jamForce;
    while (_alive && phase == Phase.jam && ms < jamPushMs) {
      await Future.delayed(const Duration(milliseconds: 33));
      final now = math.min(jamPushMs, math.max(ms + 33, sw.elapsedMilliseconds));
      if (now >= modeUntil) {
        jamMode = _nextJamMode(j.power);
        modeUntil = now + 350 + run.rng.nextInt(950);
      }
      // a fresh wobble every few frames, eased into so it surges rather than buzzes
      if (run.rng.nextDouble() < 0.25) target = jamModeRate[jamMode] * (0.6 + run.rng.nextDouble() * 0.8);
      jamForce += (target - jamForce) * 0.3;
      jamP = (jamP - jamTap * jamForce * (now - ms) / 1000).clamp(jamMin, 1.0);
      ms = now;
      jamLeft = 1 - ms / jamPushMs;
      notifyListeners();
    }
    if (!_alive || phase != Phase.jam) return;
    jamLeft = 0;
    Sfx.cut('push'); // taps still queued up must not keep thumping over the outcome
    meta.recordMash(_jamTaps * 1000 / jamPushMs);
    // the outcome, right away
    jamStage = 3;
    final saved = jamSaved = run.rng.nextDouble() < jamP;
    if (saved) {
      meta.recordJamWin();
      _checkAchievements();
      _jamGift = run.rewardJam(j); // the reward (a goods is placed before the count)
      Sfx.play('jam_win');
      burstToken++;
      Crowd.cheer();
      HapticFeedback.mediumImpact();
      say(1, pick(lineJamWin));
      Voice.say(jamIdol, pick(idolLines[jamIdol]!.jamWin), delayMs: 300);
      notifyListeners();
    } else {
      Sfx.play('jam_lose');
      shakeToken++;
      HapticFeedback.heavyImpact();
      say(3, pick(lineJamLose));
      Voice.say(jamIdol, pick(idolLines[jamIdol]!.jamLose), delayMs: 300);
      final before = List.of(run.cells);
      final cells = run.applyJam(j);
      jamTaken = [for (final c in cells) before[c]!.def];
      notifyListeners();
      // the goods fly off to him first, then the altar shows the gap
      await Future.delayed(const Duration(milliseconds: 900));
      if (!_alive || phase != Phase.jam) return;
      for (final c in cells) {
        hit[c]++;
        _puff(c);
        badge.remove(c);
        gave.remove(c);
      }
      _syncShelf();
      coinsShown = run.coins;
      notifyListeners();
    }
    await Future.delayed(const Duration(milliseconds: jamOutroMs));
    if (!_alive || phase != Phase.jam) return;
    jam = null;
    notifyListeners();
  }

  /// まもれ！ — each tap shoves the scalper back a little.
  void jamPush() {
    if (phase != Phase.jam || jamStage != 2 || jamCount > 0) return;
    jamP = math.min(1.0, jamP + jamTap);
    _jamTaps++;
    jamTapToken++;
    Sfx.play('push', volume: 0.8);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  bool _fromShop = false;

  // ── scoring ──
  void _float(int i, String t, int kind) {
    (floats[i] ??= []).add(Float(t, kind));
    if (floats[i]!.length > 4) floats[i]!.removeAt(0);
  }

  /// A beam of light from the goods to the ones it powers up (gone after a moment).
  void _beam(Step s, bool mult) {
    final b = Beam(s.idx, s.targets, mult, s.amount);
    beams.add(b);
    Future.delayed(const Duration(milliseconds: 750), () {
      beams.remove(b);
      if (_alive) notifyListeners();
    });
  }

  void _apply(Step s) {
    switch (s.kind) {
      case StepKind.add:
        badge[s.idx] = (badge[s.idx] ?? 0) + s.amount;
        pulse[s.idx]++;
        _float(s.idx, s.amount > 0 ? '+${s.amount}' : '${s.amount}', s.amount > 0 ? 0 : 3);
        if (s.amount > 0) heartPop[s.idx] = (heartPop[s.idx] ?? 0) + 1;
        s.amount > 0 ? Sfx.tick(_step++) : Sfx.play('minus');
        Crowd.setHype(hype);
        Crowd.beat(_step, s.amount);
        HapticFeedback.selectionClick();
      case StepKind.instant:
        pulse[s.idx]++;
        _float(s.idx, '+${s.amount}', 0);
        Sfx.tick(_step++);
        coinsShown += s.amount;
      case StepKind.buff:
        _beam(s, false);
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
        _beam(s, true);
        pulse[s.idx]++;
        gave[s.idx] = '×${s.amount}';
        for (final t in s.targets) {
          badge[t] = (badge[t] ?? 0) * s.amount;
          hit[t]++;
          _float(t, '×${s.amount}', 2);
        }
        Crowd.beat(_step + 6, 99); // a multiplier always gets the hall going
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
    liveTotal = 0;
    final res = run.endTurn();
    notifyListeners();
    await _wait(200);
    // beats speed up as they pile on, like a slot paying out
    var ms = 300;
    for (final s in res.steps) {
      if (!_alive) return;
      if (s.kind == StepKind.remove && shown[s.idx] == null) continue;
      _apply(s);
      // the running count, with a jolt at every round number it passes
      final now = badge.values.fold(0, (a, b) => a + b);
      for (final m in const [100, 500, 1000, 5000, 10000]) {
        if (liveTotal < m && now >= m) {
          milestoneToken++;
          shakeToken++;
          Sfx.play('total_big', volume: 0.6);
          HapticFeedback.heavyImpact();
        }
      }
      liveTotal = now;
      notifyListeners();
      await _wait(s.kind == StepKind.mult ? ms + 180 : ms);
      ms = math.max(110, (ms * 0.9).round());
    }
    lastTotal = res.total;
    totalToken++;
    final big = res.total >= 40 && res.total >= run.due ~/ 3;
    if (res.total > 0) Sfx.play(big ? 'total_big' : 'total_small');
    // the idols on the altar cheer a big turn now and then; つむぎ can't believe it
    final fans = {for (final f in run.figs) ...f.def.cast}.toList();
    if (big) {
      shakeToken++;
      HapticFeedback.heavyImpact();
      Crowd.cheer();
      if (fans.isNotEmpty && !_coaching && math.Random().nextDouble() < 0.6) {
        final who = fans[math.Random().nextInt(fans.length)];
        idolSay(who, pick(idolLines[who]!.cheer));
        bossLine = pick(lineBigTurn);
        bossMood = 2;
        bossToken++;
      } else {
        say(2, pick(lineBigTurn));
      }
    } else if (res.total < 3 && run.turn > 3) {
      say(0, pick(lineSmallTurn));
    } else if (!_coaching && math.Random().nextDouble() < 0.2) {
      say(0, pick(lineIdle));
    }
    coinsShown = run.coins; // the per-cell numbers stay up until the next spin
    notifyListeners();
    await _wait(700);
    if (!_alive) return; // the screen was left mid-count
    _syncShelf();
    _countEarned();
    if (meta.recordMachine(machine.id, turn: res.total)) Rank.instance.submitMachine(machine.id, res.total);
    if (meta.recordTurn(res.total)) {
      turnRecord = true;
      Rank.instance.submit(Board.bestTurn, res.total);
    }
    _checkAchievements();
    if (run.paydayNow) {
      phase = Phase.payday;
      payday = null;
      Sfx.play('payday');
      _curtainCall();
    } else {
      phase = Phase.ready;
      if (coach == Coach.wait) {
        coach = switch (run.turn) {
          1 => Coach.coins,
          _ => Coach.doubled,
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
    bossMood = 1;
    bossToken++;
    HapticFeedback.mediumImpact();
    _syncShelf();
    meta.recordPaydays(run.paydaysPaid);
    meta.recordMachine(machine.id, songs: run.paydaysPaid);
    if (run.cleared && run.paydaysPaid == Run.clearPaydays) {
      // the first clear of this machine brings its goods into the gacha (from the next live)
      if (meta.clearedMachine(machine.id) && meta.broughtBy(machine.id).isNotEmpty) {
        _pushToast(TopToast(figures: (machine, meta.broughtBy(machine.id))));
      }
      phase = Phase.cleared;
      Sfx.play('clear');
      say(1, pick(lineClear));
      meta.recordClear();
      _checkAchievements();
    } else {
      // the curtain call was already on the song's card: straight on to the merch booth
      _openShop();
    }
    notifyListeners();
  }

  /// The end of a song. Quota met: one card for it all — the idol with the most goods on the altar
  /// thanks the crowd (her line, her voice, the curtain-call tune) over the gauge brimming past the
  /// quota. Short of it: つむぎ says so over the gauge.
  void _curtainCall() {
    if (run.coins < run.due) {
      songIdol = null;
      say(0, pick(linePayday));
      return;
    }
    songIdol = run.topCast ?? members[math.Random().nextInt(members.length)];
    songLine = pick(idolLines[songIdol!]!.songEnd);
    Voice.say(songIdol!, songLine, delayMs: 500);
    Bgm.play('bgm_clear'); // the curtain call and the stall get their own tune
    Crowd.songEnd();
    burstToken++;
    HapticFeedback.mediumImpact();
  }

  /// From the song's curtain call to the merch booth.
  void toShop() {
    if (phase != Phase.payday || payday?.paid != true) return;
    _openShop();
    notifyListeners();
  }

  /// Rewarded-ad rescue from a payday that came up short.
  Future<void> watchAdToPostpone() async {
    if (!run.canPostpone) return;
    if (!await Ads.instance.show(postpone)) _adNotReady();
  }

  void postpone() {
    if (!run.canPostpone) return;
    Bgm.play('bgm_clear');
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
    Bgm.play('bgm_result');
    _countEarned();
    phase = Phase.over;
    // how far the run got, extensions included
    if (run.paydaysPaid > 0) Rank.instance.submit(Board.paydays, run.paydaysPaid);
    newRecord = meta.recordPaydays(run.paydaysPaid);
    meta.recordRun();
    _checkAchievements();
    if (turnRecord) _fetchTurnRank();
    newMachines = meta.takeNewMachines();
    if (newMachines.isNotEmpty) _pushToast(TopToast(machines: newMachines));
    // a jingle only for a cleared live; giving up stays quiet (the result BGM is enough)
    if (run.cleared) Sfx.play('jingle');
    // つむぎ sums it up
    overLine = pick(run.cleared ? lineOverWin : lineOverLose);
    notifyListeners();
  }

  Future<void> _fetchTurnRank() async {
    final r = await Rank.instance.myRank(Board.bestTurn);
    if (!_alive || r == null) return;
    turnRank = r;
    notifyListeners();
  }

  /// アンコール: the live goes on past the 4th song.
  void keepGoing() {
    _openShop(encore: true);
    notifyListeners();
  }

  // ── shop ──
  void _openShop({bool encore = false}) {
    heartPop.clear(); // the altar may grow at the stall and renumber its cells
    run.rollShop();
    phase = Phase.shop;
    Sfx.play('shop');
    _rareArrival();
    final hello = pick(encore ? lineEncore : lineShop);
    if (!_coaching) Future.delayed(const Duration(milliseconds: 700), () => _alive && phase == Phase.shop ? say(encore ? 1 : 0, hello) : null);
  }

  /// A レア商品 on the shelf: a gold 「レア入荷！」 and a chime.
  void _rareArrival() {
    if (!run.shop.any((o) => o.rare)) return;
    rareToken++;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (_alive && phase == Phase.shop) {
        Sfx.play('unlock');
        HapticFeedback.mediumImpact();
      }
    });
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
  }

  void reroll() {
    if (run.reroll()) {
      Sfx.play('reroll');
      _rareArrival();
      coinsShown = run.coins;
      HapticFeedback.selectionClick();
    }
    notifyListeners();
  }

  void leaveShop() {
    if (phase != Phase.shop) return;
    Bgm.play('bgm_${machine.bgm}'); // the next song
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
