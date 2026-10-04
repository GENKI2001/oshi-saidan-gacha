import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/defs.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/levels.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';
import 'package:oshi_saidan/ui/meta.dart';

void main() {
  test('the level goes up by one at most, when a run ends', () {
    final m = Meta();
    m.addEarned(levelNeed(1) - 1);
    expect(m.finishRun(), isNull);
    expect(m.level, 1);
    m.addEarned(levelNeed(1) * 10); // a huge run still fills just one gauge
    expect(m.level, 1, reason: 'not mid-run');
    expect(m.finishRun(), 2);
    expect(m.levelInto, 0);
    expect(m.finishRun(), isNull);
    m.addEarned(levelNeed(2));
    expect(m.finishRun(), 3);
    expect(levelNeed(5), greaterThan(levelNeed(1)));
  });

  test('the gacha only drops figures the level has unlocked', () {
    final r = Run(seed: 3, rules: Rules(level: 1));
    for (var k = 0; k < 2000; k++) {
      final f = r.pullOne();
      expect(f.level, 1, reason: f.id);
    }
  });

  test('level 1 already has every rarity for every member (a wide, lucky pool)', () {
    for (final rar in [Rarity.normal, Rarity.rare, Rarity.epic, Rarity.legend]) {
      for (final m in ['ひなた', 'しずく', 'こはる', 'よる', 'もも']) {
        expect(figures.any((f) => f.rarity == rar && f.level == 1 && f.cast.contains(m)), isTrue, reason: '$m ${rar.name}');
      }
    }
    expect(figures.where((f) => f.level == 1).length, greaterThanOrEqualTo(40));
  });
}
