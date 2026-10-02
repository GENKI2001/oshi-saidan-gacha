import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/defs.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/levels.dart';
import 'package:gacha_rogue/logic/modes.dart';
import 'package:gacha_rogue/logic/run.dart';
import 'package:gacha_rogue/ui/meta.dart';

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

  test('level 1 has normal, rare and epic figures; legends come later', () {
    for (final rar in [Rarity.normal, Rarity.rare, Rarity.epic]) {
      expect(figures.any((f) => f.rarity == rar && f.level == 1), isTrue, reason: rar.name);
    }
    expect(figures.any((f) => f.rarity == Rarity.legend && f.level == 1), isFalse);
    expect(figureById['daikoku']!.level, greaterThan(1), reason: '大黒さま is too strong for a first festival');
  });

  test('a legend pull before any legend is unlocked gives an epic', () {
    final r = Run(seed: 5, rules: Rules(level: 1));
    for (var k = 0; k < 200; k++) {
      expect(r.pullOne(minRarity: Rarity.legend).rarity, Rarity.epic);
    }
    for (var k = 0; k < 50; k++) {
      r.rollShop();
    }
  });
}
