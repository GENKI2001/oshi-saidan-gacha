import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/modes.dart';
import 'package:gacha_rogue/logic/run.dart';
import 'package:gacha_rogue/ui/meta.dart';

void main() {
  test('machines change the shelf, start and odds', () {
    final r = Run(seed: 9, rules: rulesFor(machineById['mizu']!, 0));
    expect([r.cols, r.rows], [5, 3]);
    expect(r.figs.single.def.id, 'kingyo');
    var water = 0;
    for (var i = 0; i < 400; i++) {
      if (r.pullOne().tags.contains('水')) water++;
    }
    var plain = 0;
    final p = Run(seed: 9);
    for (var i = 0; i < 400; i++) {
      if (p.pullOne().tags.contains('水')) plain++;
    }
    expect(water, greaterThan(plain * 1.2)); // softened when many water figures were added
  });

  test('ascension stacks its rules', () {
    final r = rulesFor(machines.first, 10);
    expect(r.dueMult, closeTo(1.45, 1e-9));
    expect([r.cardEveryPayday, r.removeTickets, r.canExpand, r.noContinue], [true, 0, false, true]);
    expect(Run(rules: r).canPostpone, isFalse);
    final card = Run(rules: r)..coins = 0;
    card.place(figureById[kCardId]!, 0);
    expect(card.endTurn().total, -4);
  });

  test('machines unlock with the festival level', () {
    final m = Meta();
    expect(m.unlocked(machineById['mizu']!), isFalse);
    m.level = 3;
    expect(m.unlocked(machineById['mizu']!), isTrue);
    expect(m.unlocked(machineById['kuishinbo']!), isFalse);
    expect(m.takeNewMachines().map((x) => x.id), ['mizu']);
    expect(m.takeNewMachines(), isEmpty);
    expect(m.recordClear(0), 1);
    expect(m.recordClear(0), isNull);
  });
}
