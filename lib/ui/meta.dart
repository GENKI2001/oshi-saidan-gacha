// What survives between runs: the figure book, records, unlocked machines
// and settings (spec 02 §5).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/achievements.dart';
import '../logic/defs.dart';
import '../logic/figures.dart';
import '../logic/modes.dart';

class Meta extends ChangeNotifier {
  SharedPreferences? _p;
  Set<String> seen = {};
  int bestPaydays = 0, bestTurn = 0, runs = 0, clears = 0;
  Set<String> machinesShown = _openFromStart(); // unlocks already announced (the ones open from the start need none)
  bool sound = true;
  bool music = true;
  bool voice = true; // character voices
  String lastMachine = 'pripare';
  int totalEarned = 0; // every coin ever earned (a record)
  // There is no level: goods come into the gacha with the first clear of a machine ([FigureDef.from]),
  // and machines open by clearing another one or by a record ([MachineDef.unlock]).
  bool figureOpen(FigureDef f) => f.from == null || clearedOn.contains(f.from);
  Set<String> get openFigures => {for (final f in figures) if (figureOpen(f)) f.id};
  /// The goods a first clear of [machine] brings into the gacha.
  List<FigureDef> broughtBy(String machine) => [for (final f in figures) if (f.from == machine) f];
  bool tutorialDone = false; // the guided first game was finished
  double? mashRate; // how fast this player mashes まもれ！ (taps a second, a running average; null = not seen yet)

  // ── 実績 ──
  Set<String> achieved = {};
  Map<String, int> placed = {}; // each idol's goods ever put on the altar
  Map<String, int> altarPeak = {}; // most of an idol's goods on the altar at once
  Set<String> clearedOn = {}; // machines a live was cleared on
  Map<String, int> machineSongs = {}; // most songs met in one live, per machine
  Map<String, int> machineTurn = {}; // most hearts in one spin, per machine
  bool pulledStar4 = false;

  Stats get stats => Stats(
    runs: runs,
    clears: clears,
    bestPaydays: bestPaydays,
    bestTurn: bestTurn,
    seen: seen.length,
    placed: placed,
    altarPeak: altarPeak,
    clearedOn: clearedOn,
    pulledStar4: pulledStar4,
    jamWins: jamWins,
    maxStack: maxStack,
    totalEarned: totalEarned,
    open: openFigures.length,
  );

  int jamWins = 0; // 妨害 fended off, ever
  int maxStack = 1; // the most a goods was ever stacked (×n)

  void recordJamWin() {
    jamWins++;
    _save();
  }

  void noteStack(int n) {
    if (n <= maxStack) return;
    maxStack = n;
    _save();
  }

  void addPlaced(String idol) {
    placed[idol] = (placed[idol] ?? 0) + 1;
    _save();
  }

  void noteAltar(Map<String, int> counts) {
    var changed = false;
    for (final e in counts.entries) {
      if (e.value > (altarPeak[e.key] ?? 0)) {
        altarPeak[e.key] = e.value;
        changed = true;
      }
    }
    if (changed) _save();
  }

  /// This machine's own records (shown on its card in the gacha select).
  /// Returns true when [turn] is a new best on it (worth sending to its leaderboard).
  bool recordMachine(String id, {int songs = 0, int turn = 0}) {
    var changed = false, newTurn = false;
    if (songs > (machineSongs[id] ?? 0)) {
      machineSongs[id] = songs;
      changed = true;
    }
    if (turn > (machineTurn[id] ?? 0)) {
      machineTurn[id] = turn;
      changed = newTurn = true;
    }
    if (changed) _save();
    return newTurn;
  }

  /// Records a clear on [id]; true the first time (its goods come into the gacha, see [broughtBy]).
  bool clearedMachine(String id) {
    if (!clearedOn.add(id)) return false;
    _save();
    notifyListeners();
    return true;
  }

  void star4() {
    if (pulledStar4) return;
    pulledStar4 = true;
    _save();
  }

  /// Achievements met since the last check (and now marked achieved).
  List<Achievement> checkAchievements() {
    final st = stats;
    final out = [
      for (final a in achievements)
        if (!achieved.contains(a.id) && a.done(st)) a,
    ];
    if (out.isNotEmpty) {
      achieved.addAll(out.map((a) => a.id));
      _save();
      notifyListeners();
    }
    return out;
  }

  /// Whisper tracks the player can listen to.
  bool asmrOpen(String track) => achievements.any((a) => a.asmr == track && achieved.contains(a.id));

  static Map<String, int> _map(List<String>? xs) => {
    for (final x in xs ?? const <String>[])
      if (x.contains(':')) x.split(':').first: int.tryParse(x.split(':').last) ?? 0,
  };
  static List<String> _list(Map<String, int> m) => [for (final e in m.entries) '${e.key}:${e.value}'];

  /// After a 妨害: folds this shove's taps a second into [mashRate], so the next scalper fits the player.
  void recordMash(double tps) {
    final r = mashRate;
    mashRate = r == null ? tps : r + (tps - r) * 0.4;
    _save();
  }

  void finishTutorial() {
    tutorialDone = true;
    _save();
  }

  /// Adds coins to the lifetime total (a record).
  void addEarned(int n) {
    if (n <= 0) return;
    totalEarned += n;
    _save();
    notifyListeners();
  }


  Future<void> load() async {
    try {
      final p = _p = await SharedPreferences.getInstance();
      // goods that were taken out of the game (つむぎの注意書き) drop out of the book
      seen = (p.getStringList('seen') ?? []).where(figureById.containsKey).toSet();
      bestPaydays = p.getInt('bestPaydays') ?? 0;
      bestTurn = p.getInt('bestTurn') ?? 0;
      runs = p.getInt('runs') ?? 0;
      clears = p.getInt('clears') ?? 0;
      machinesShown = {..._openFromStart(), ...?p.getStringList('machinesShown')};
      sound = p.getBool('sound') ?? true;
      music = p.getBool('music') ?? true;
      voice = p.getBool('voice') ?? true;
      lastMachine = p.getString('lastMachine') ?? 'pripare';
      totalEarned = p.getInt('totalEarned') ?? 0;
      tutorialDone = p.getBool('tutorialDone') ?? false;
      mashRate = p.getDouble('mashRate');
      achieved = (p.getStringList('achieved') ?? []).toSet();
      placed = _map(p.getStringList('placed'));
      altarPeak = _map(p.getStringList('altarPeak'));
      clearedOn = (p.getStringList('clearedOn') ?? []).toSet();
      machineSongs = _map(p.getStringList('machineSongs'));
      machineTurn = _map(p.getStringList('machineTurn'));
      pulledStar4 = p.getBool('pulledStar4') ?? false;
      jamWins = p.getInt('jamWins') ?? 0;
      maxStack = p.getInt('maxStack') ?? 1;
    } catch (_) {
      // storage can be unavailable (private browsing); play on without it
    }
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setStringList('seen', seen.toList());
    p.setInt('bestPaydays', bestPaydays);
    p.setInt('bestTurn', bestTurn);
    p.setInt('runs', runs);
    p.setInt('clears', clears);
    p.setStringList('machinesShown', machinesShown.toList());
    p.setBool('sound', sound);
    p.setBool('music', music);
    p.setBool('voice', voice);
    p.setString('lastMachine', lastMachine);
    p.setInt('totalEarned', totalEarned);
    p.setBool('tutorialDone', tutorialDone);
    if (mashRate case final r?) p.setDouble('mashRate', r);
    p.setStringList('achieved', achieved.toList());
    p.setStringList('placed', _list(placed));
    p.setStringList('altarPeak', _list(altarPeak));
    p.setStringList('clearedOn', clearedOn.toList());
    p.setStringList('machineSongs', _list(machineSongs));
    p.setStringList('machineTurn', _list(machineTurn));
    p.setBool('pulledStar4', pulledStar4);
    p.setInt('jamWins', jamWins);
    p.setInt('maxStack', maxStack);
  }

  void toggleMusic() {
    music = !music;
    _save();
    notifyListeners();
  }

  void toggleVoice() {
    voice = !voice;
    _save();
    notifyListeners();
  }

  void toggleSound() {
    sound = !sound;
    _save();
    notifyListeners();
  }

  void remember(String machine) {
    lastMachine = machine;
    _save();
  }

  /// Returns true when [id] is new to the book.
  bool see(String id) {
    if (!seen.add(id)) return false;
    _save();
    notifyListeners();
    return true;
  }

  bool recordTurn(int total) {
    if (total <= bestTurn) return false;
    bestTurn = total;
    _save();
    return true;
  }

  bool recordPaydays(int n) {
    if (n <= bestPaydays) return false;
    bestPaydays = n;
    _save();
    return true;
  }

  void recordRun() {
    runs++;
    _save();
  }

  void recordClear() {
    clears++;
    _save();
  }

  // ── machines ──
  static Set<String> _openFromStart() => {
    for (final m in machines)
      if (m.unlock == UnlockKind.none) m.id,
  };

  // a machine once opened stays open (saves from the 推し活レベル days keep theirs)
  bool unlocked(MachineDef m) => machinesShown.contains(m.id) || switch (m.unlock) {
    UnlockKind.none => true,
    UnlockKind.machine => clearedOn.contains(m.unlockId),
    UnlockKind.seen => seen.length >= m.unlockN,
    UnlockKind.bestTurn => bestTurn >= m.unlockN,
    UnlockKind.paydays => bestPaydays >= m.unlockN,
    UnlockKind.clears => clears >= m.unlockN,
  };

  /// Machines unlocked since we last announced; marks them announced.
  List<MachineDef> takeNewMachines() {
    final out = [
      for (final m in machines)
        if (unlocked(m) && !machinesShown.contains(m.id)) m,
    ];
    if (out.isNotEmpty) {
      machinesShown.addAll(out.map((m) => m.id));
      _save();
    }
    return out;
  }
}
