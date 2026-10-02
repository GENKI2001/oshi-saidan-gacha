// The festival level (縁日レベル): grows with every coin the player has ever
// earned, across all runs, and unlocks more figures in the gacha.
import 'dart:math' as math;

import 'defs.dart';
import 'figures.dart';

/// Coins needed to go from [level] to the next one. The gauge fills during a
/// run and the level goes up when the run ends, at most one level per run, so
/// the first few plays each give a level and later ones need a good run.
int levelNeed(int level) => (150 * math.pow(1.35, level - 1)).round();

/// Figures that start dropping at exactly [level].
List<FigureDef> unlockedAt(int level) => [
  for (final f in figures)
    if (f.level == level && f.rarity != Rarity.curse) f,
];

/// The next level that unlocks something, or null when everything is out.
int? nextUnlockLevel(int level) {
  final later = [
    for (final f in figures)
      if (f.level > level) f.level,
  ];
  return later.isEmpty ? null : later.reduce(math.min);
}
