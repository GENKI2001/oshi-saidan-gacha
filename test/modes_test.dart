import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';
import 'package:oshi_saidan/ui/meta.dart';

void main() {
  test('machines change the shelf, start and odds', () {
    final r = Run(seed: 9, rules: rulesFor(machineById['shizumomo']!));
    expect([r.cols, r.rows], [defaultSide, defaultSide]);
    expect(r.figs.single.def.id, 'shizumomo_strap');
    var water = 0;
    for (var i = 0; i < 400; i++) {
      if (r.pullOne().tags.contains('しずく')) water++;
    }
    var plain = 0;
    final p = Run(seed: 9);
    for (var i = 0; i < 400; i++) {
      if (p.pullOne().tags.contains('しずく')) plain++;
    }
    expect(water, greaterThan(plain * 1.2)); // softened when many water figures were added
  });

  test('ドームツアー stacks the hard rules', () {
    final r = rulesFor(machineById['dome']!);
    expect(r.dueMult, closeTo(1.75, 1e-9));
    expect([r.canExpand, r.noContinue], [false, true]);
    expect(Run(rules: r).canPostpone, isFalse);
  });

  test('every machine has a difficulty, and they cover easy to hard', () {
    for (final m in machines) {
      expect(m.difficulty, inInclusiveRange(1, 5), reason: m.id);
    }
    expect(machines.map((m) => m.difficulty).toSet(), {1, 2, 3, 4, 5});
  });

  test('machines open by clearing another one (no level)', () {
    final m = Meta();
    expect(m.unlocked(machineById['shizumomo']!), isFalse);
    expect(m.clearedMachine('pripare'), isTrue);
    expect(m.clearedMachine('pripare'), isFalse); // only the first clear is news
    expect(m.unlocked(machineById['shizumomo']!), isTrue);
    expect(m.unlocked(machineById['koharu']!), isTrue);
    expect(m.unlocked(machineById['hinata']!), isFalse);
    expect(m.takeNewMachines().map((x) => x.id), ['shizumomo', 'koharu']);
    expect(m.takeNewMachines(), isEmpty);
    m.recordClear();
    expect(m.clears, 1);
  });

  test("a first clear brings that machine's goods into the gacha", () {
    final m = Meta();
    final goods = m.broughtBy('koharu');
    expect(goods, isNotEmpty);
    expect(goods.any(m.figureOpen), isFalse);
    expect(rulesFor(machineById['koharu']!)..open = m.openFigures, isNotNull);
    m.clearedMachine('koharu');
    expect(goods.every(m.figureOpen), isTrue);
  });

  test('no dead end: from a new save every machine and every goods can be reached', () {
    final m = Meta();
    for (var changed = true; changed;) {
      changed = false;
      for (final mc in machines) {
        if (!m.unlocked(mc) || m.clearedOn.contains(mc.id)) continue;
        // play it until it is cleared, meeting everything that can drop
        m.clearedMachine(mc.id);
        m.recordClear();
        m.seen.addAll(m.openFigures);
        changed = true;
      }
    }
    expect([for (final mc in machines) if (!m.unlocked(mc)) mc.id], isEmpty);
    expect([for (final f in figures) if (!m.figureOpen(f)) f.id], isEmpty);
    for (final f in figures) {
      if (f.from != null) expect(machineById[f.from], isNotNull, reason: f.id);
    }
  });

  test('every machine brings some goods into the gacha with its first clear', () {
    final m = Meta();
    for (final mc in machines) {
      expect(m.broughtBy(mc.id), isNotEmpty, reason: mc.id);
    }
  });

  test("the 中身 sheet's odds add up and match what really drops", () {
    final r = Run(seed: 11, rules: rulesFor(machineById['koharu']!)..open = Meta().openFigures);
    final list = r.lineup();
    expect(list.fold(0.0, (a, e) => a + e.p), closeTo(1, 1e-9));
    final seen = <String, int>{};
    const n = 40000;
    for (var k = 0; k < n; k++) {
      final f = r.pullOne();
      seen[f.id] = (seen[f.id] ?? 0) + 1;
    }
    for (final e in list) {
      expect((seen[e.def.id] ?? 0) / n, closeTo(e.p, 0.012), reason: e.def.id);
    }
    expect(seen.keys.toSet(), list.map((e) => e.def.id).toSet());
  });
}
