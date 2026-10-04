import 'package:flutter_test/flutter_test.dart';
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
    expect(r.dueMult, closeTo(1.5, 1e-9));
    expect([r.canExpand, r.noContinue], [false, true]);
    expect(Run(rules: r).canPostpone, isFalse);
  });

  test('every machine has a difficulty, and they cover easy to hard', () {
    for (final m in machines) {
      expect(m.difficulty, inInclusiveRange(1, 5), reason: m.id);
    }
    expect(machines.map((m) => m.difficulty).toSet(), {1, 2, 3, 4, 5});
  });

  test('machines unlock with the festival level', () {
    final m = Meta();
    expect(m.unlocked(machineById['shizumomo']!), isFalse);
    m.level = 3;
    expect(m.unlocked(machineById['shizumomo']!), isTrue);
    expect(m.unlocked(machineById['koharu']!), isFalse);
    expect(m.takeNewMachines().map((x) => x.id), ['shizumomo']);
    expect(m.takeNewMachines(), isEmpty);
    m.recordClear();
    expect(m.clears, 1);
  });
}
