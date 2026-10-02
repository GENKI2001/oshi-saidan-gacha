import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/defs.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/run.dart';

void main() {
  test('fox masks copy the final value and pass it along the chain', () {
    // row 0: [maneki ×2 on koban] [koban] [fox] [fox]
    final r = Run(seed: 5);
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    r.place(figureById['maneki']!, 0);
    r.place(figureById['koban']!, 1);
    r.place(figureById['kitsune']!, 2);
    r.place(figureById['kitsune']!, 3);
    final res = r.endTurn();
    final koban = res.gains[1]!;
    expect(koban, 2, reason: 'koban 1, doubled by the lucky cat');
    expect(res.gains[2], koban, reason: 'copies the doubled value');
    expect(res.gains[3], koban, reason: 'the chained mask agrees');
  });

  test('a re-pull never comes out rarer-down', () {
    final r = Run(seed: 6);
    for (var k = 0; k < 500; k++) {
      final f = r.pullAtLeast(Rarity.epic).single;
      expect(f.rarity.index, greaterThanOrEqualTo(Rarity.epic.index));
      expect(f.rarity, isNot(Rarity.curse));
    }
  });
}
