// What survives between runs: the figure book, records, unlocked machines,
// ascension and settings (spec 02 §5).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/achievements.dart';
import '../logic/levels.dart';
import '../logic/modes.dart';

class Meta extends ChangeNotifier {
  SharedPreferences? _p;
  Set<String> seen = {};
  int bestPaydays = 0, bestTurn = 0, runs = 0, clears = 0;
  int maxAsc = 0; // highest ascension the player may pick
  Set<String> machinesShown = {'pripare'}; // unlocks already announced
  bool sound = true;
  bool music = true;
  bool voice = true; // character voices
  String lastMachine = 'pripare';
  int lastAsc = 0;
  int totalEarned = 0; // every coin ever earned (a record)
  // 推し活レベル: coins fill the gauge (capped when full); a full gauge levels up when a run ends
  int level = 1, levelInto = 0;
  int get levelNeedNow => levelNeed(level);
  bool tutorialDone = false; // the guided first game was finished

  // ── 実績 ──
  Set<String> achieved = {};
  Map<String, int> placed = {}; // each idol's goods ever put on the altar
  Map<String, int> altarPeak = {}; // most of an idol's goods on the altar at once
  Set<String> clearedOn = {}; // machines a live was cleared on
  bool pulledStar4 = false;

  Stats get stats => Stats(
    runs: runs,
    clears: clears,
    bestPaydays: bestPaydays,
    bestTurn: bestTurn,
    seen: seen.length,
    maxAsc: maxAsc,
    placed: placed,
    altarPeak: altarPeak,
    clearedOn: clearedOn,
    pulledStar4: pulledStar4,
  );

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

  void clearedMachine(String id) {
    if (clearedOn.add(id)) _save();
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

  void finishTutorial() {
    tutorialDone = true;
    _save();
  }

  /// Adds coins to the lifetime total and the level gauge.
  void addEarned(int n) {
    if (n <= 0) return;
    totalEarned += n;
    levelInto = (levelInto + n).clamp(0, levelNeedNow);
    _save();
    notifyListeners();
  }

  /// At the end of a run: a full gauge gives one level. Returns the new level if it went up.
  int? finishRun() {
    if (levelInto < levelNeedNow) return null;
    level++;
    levelInto = 0;
    _save();
    notifyListeners();
    return level;
  }

  Future<void> load() async {
    try {
      final p = _p = await SharedPreferences.getInstance();
      seen = (p.getStringList('seen') ?? []).toSet();
      bestPaydays = p.getInt('bestPaydays') ?? 0;
      bestTurn = p.getInt('bestTurn') ?? 0;
      runs = p.getInt('runs') ?? 0;
      clears = p.getInt('clears') ?? 0;
      maxAsc = p.getInt('maxAsc') ?? 0;
      machinesShown = (p.getStringList('machinesShown') ?? ['pripare']).toSet();
      sound = p.getBool('sound') ?? true;
      music = p.getBool('music') ?? true;
      voice = p.getBool('voice') ?? true;
      lastMachine = p.getString('lastMachine') ?? 'pripare';
      lastAsc = p.getInt('lastAsc') ?? 0;
      totalEarned = p.getInt('totalEarned') ?? 0;
      level = p.getInt('level') ?? 1;
      levelInto = p.getInt('levelInto') ?? 0;
      tutorialDone = p.getBool('tutorialDone') ?? false;
      achieved = (p.getStringList('achieved') ?? []).toSet();
      placed = _map(p.getStringList('placed'));
      altarPeak = _map(p.getStringList('altarPeak'));
      clearedOn = (p.getStringList('clearedOn') ?? []).toSet();
      pulledStar4 = p.getBool('pulledStar4') ?? false;
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
    p.setInt('maxAsc', maxAsc);
    p.setStringList('machinesShown', machinesShown.toList());
    p.setBool('sound', sound);
    p.setBool('music', music);
    p.setBool('voice', voice);
    p.setString('lastMachine', lastMachine);
    p.setInt('lastAsc', lastAsc);
    p.setInt('totalEarned', totalEarned);
    p.setInt('level', level);
    p.setInt('levelInto', levelInto);
    p.setBool('tutorialDone', tutorialDone);
    p.setStringList('achieved', achieved.toList());
    p.setStringList('placed', _list(placed));
    p.setStringList('altarPeak', _list(altarPeak));
    p.setStringList('clearedOn', clearedOn.toList());
    p.setBool('pulledStar4', pulledStar4);
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

  void remember(String machine, int asc) {
    lastMachine = machine;
    lastAsc = asc;
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

  /// A clear at the top ascension opens the next one. Returns the new level or null.
  int? recordClear(int asc) {
    clears++;
    int? opened;
    if (asc >= maxAsc && maxAsc < maxAscension) {
      maxAsc = asc + 1;
      opened = maxAsc;
    }
    _save();
    return opened;
  }

  // ── machines ──
  bool unlocked(MachineDef m) => switch (m.unlock) {
    UnlockKind.none => true,
    UnlockKind.seen => seen.length >= m.unlockN,
    UnlockKind.bestTurn => bestTurn >= m.unlockN,
    UnlockKind.paydays => bestPaydays >= m.unlockN,
    UnlockKind.clears => clears >= m.unlockN,
    UnlockKind.level => level >= m.unlockN,
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
