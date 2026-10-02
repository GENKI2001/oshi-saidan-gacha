// ignore_for_file: avoid_print
// How fast 縁日レベル grows over a player's runs.
//   dart run tool/level_sim.dart [players]
// Each simulated player plays runs back to back on 縁日ガチャ; a run is played at
// the current level, the coins fill the gauge, and a full gauge gives one level.
import 'package:gacha_rogue/logic/levels.dart';
import 'package:gacha_rogue/logic/modes.dart';

import 'sim.dart';

void main(List<String> args) {
  final players = args.isEmpty ? 100 : int.parse(args.first);
  const bots = <Bot>[(name: 'random', smart: false, shop: false), (name: 'greedy+shop', smart: true, shop: true)];
  const marks = [2, 3, 4, 5, 6, 8, 10, 12, 15];
  for (final bot in bots) {
    final reach = {for (final l in marks) l: <int>[]};
    final earnedAt = <int, List<int>>{};
    for (var p = 0; p < players; p++) {
      var level = 1, into = 0;
      for (var run = 1; run <= 120 && level < 15; run++) {
        final res = play(p * 104729 + run * 7919, bot, () => rulesFor(machines.first, 0)..level = level);
        (earnedAt[level] ??= []).add(res.earned);
        into = (into + res.earned).clamp(0, levelNeed(level));
        if (into >= levelNeed(level)) {
          level++;
          into = 0;
          reach[level]?.add(run);
        }
      }
    }
    int med(List<int> xs) => xs.isEmpty ? -1 : (xs..sort())[xs.length ~/ 2];
    print('── ${bot.name}: runs to reach (median)');
    print('   ${marks.map((l) => 'Lv$l:${med(reach[l]!)}').join('  ')}');
    print('   earned per run at level (median): ${[1, 3, 5, 8, 10, 12, 14].map((l) => 'Lv$l ${med(earnedAt[l] ?? [])}').join('  ')}');
  }
}
