// What survives between runs: the figure book, records, unlocked machines,
// ascension and settings (spec 02 §5).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/levels.dart';
import '../logic/modes.dart';

class Meta extends ChangeNotifier {
  SharedPreferences? _p;
  Set<String> seen = {};
  int bestPaydays = 0, bestTurn = 0, runs = 0, clears = 0;
  int maxAsc = 0; // highest ascension the player may pick
  Set<String> machinesShown = {'ennichi'}; // unlocks already announced
  bool sound = true;
  bool music = true;
  String lastMachine = 'ennichi';
  int lastAsc = 0;
  int totalEarned = 0; // every coin ever earned (a record)
  // 縁日レベル: coins fill the gauge (capped when full); a full gauge levels up when a run ends
  int level = 1, levelInto = 0;
  int get levelNeedNow => levelNeed(level);
  bool tutorialDone = false; // the guided first game was finished

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
      machinesShown = (p.getStringList('machinesShown') ?? ['ennichi']).toSet();
      sound = p.getBool('sound') ?? true;
      music = p.getBool('music') ?? true;
      lastMachine = p.getString('lastMachine') ?? 'ennichi';
      lastAsc = p.getInt('lastAsc') ?? 0;
      totalEarned = p.getInt('totalEarned') ?? 0;
      level = p.getInt('level') ?? 1;
      levelInto = p.getInt('levelInto') ?? 0;
      tutorialDone = p.getBool('tutorialDone') ?? false;
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
    p.setString('lastMachine', lastMachine);
    p.setInt('lastAsc', lastAsc);
    p.setInt('totalEarned', totalEarned);
    p.setInt('level', level);
    p.setInt('levelInto', levelInto);
    p.setBool('tutorialDone', tutorialDone);
  }

  void toggleMusic() {
    music = !music;
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
