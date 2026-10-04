import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/defs.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';

void main() {
  test('any figure can be overwritten on a full altar', () {
    final r = Run(seed: 2);
    for (var i = 0; i < r.size; i++) {
      if (r.cells[i] == null) r.place(figureById['coin']!, i);
    }
    expect(r.emptyCells, isEmpty);
    expect(r.canOverwrite(3), isTrue);
    r.overwrite(figureById['koharu_keyholder']!, 3);
    expect(r.cells[3]!.def.id, 'koharu_keyholder');
  });

  test('a figure can be overwritten while the shelf still has room', () {
    final r = Run(seed: 2);
    r.place(figureById['coin']!, 0);
    expect(r.emptyCells, isNotEmpty);
    expect(r.canOverwrite(0), isTrue);
    expect(r.canOverwrite(1), isFalse);
    r.overwrite(figureById['koharu_keyholder']!, 0);
    expect(r.cells[0]!.def.id, 'koharu_keyholder');
  });

  test('the shelf grows to 5x5 and no further, each step dearer', () {
    final r = Run(seed: 4)..coins = 1 << 30;
    var last = 0;
    while (r.canGrow) {
      expect(r.expandPrice, greaterThan(last));
      last = r.expandPrice;
      r.buy(Offer(OfferKind.expand, r.expandPrice));
      r.shopBuys = 0;
    }
    expect([r.cols, r.rows], [5, 5]);
  });

  test('もう一回ひく is free: one use per payday, up to 3 with upgrades', () {
    final r = Run(seed: 7)..coins = 9999;
    expect([r.repulls, r.repullMax], [1, 1]);
    r.repulls = 0;
    r.buy(_find(r, OfferKind.repullTicket));
    expect([r.repulls, r.repullMax], [1, 2]);
    r.turn = Run.turnsPerPayday;
    r.repulls = 0;
    r.payday();
    expect(r.repulls, 2, reason: 'refilled for free at the payday');
  });

  test('the stall always shows three things', () {
    final r = Run(seed: 8);
    for (var k = 0; k < 200; k++) {
      r.rollShop();
      expect(r.shop.length, 3);
    }
  });

  test('妨害: about 5% of turns, and each outcome does what it says', () {
    final r = Run(seed: 11);
    var n = 0;
    for (var k = 0; k < 4000; k++) {
      if (r.rollJam() != null) n++;
    }
    expect(n / 4000, closeTo(0.05, 0.015));

    final s = Run(seed: 12);
    for (var i = 0; i < 4; i++) {
      s.place(figureById['coin']!, i);
    }
    final taken = s.applyJam(const Jam(JamKind.stealTwo, 1));
    expect(taken.length, 2);
    expect(s.figs.length, 2);

    s.applyJam(const Jam(JamKind.noRepull, 1));
    expect(s.repulls, 0);
    s.applyJam(const Jam(JamKind.half, 1));
    s.place(figureById['koharu_keyholder']!, 5); // +2 every turn
    final full = s.clone()..halfThisSong = false;
    expect(s.endTurn().total, (full.endTurn().total / 2).ceil());
    s.coins = 100;
    s.applyJam(const Jam(JamKind.hearts, 1, pct: 30));
    expect(s.coins, 70);
    // a new song lifts the spell
    s.coins = 9999;
    s.turn = Run.turnsPerPayday;
    s.payday();
    expect([s.halfThisSong, s.repulls], [false, s.repullMax]);
  });

  test('fending a 妨害 off for hearts doubles them until the song ends', () {
    final r = Run(seed: 14);
    r.place(figureById['koharu_keyholder']!, 0); // +2 every turn
    final plain = r.clone().endTurn().total;
    r.rewardJam(const Jam(JamKind.steal, 1, reward: JamReward.hearts));
    expect(r.endTurn().total, plain * 2);
    expect(r.endTurn().total, plain * 2, reason: 'still this song');
    r.coins = 9999;
    r.turn = Run.turnsPerPayday;
    r.payday();
    expect(r.doubleThisSong, isFalse, reason: 'a new song');
  });

  test('出現率UP doubles an idol\'s goods for the rest of the live, and stacks', () {
    int count(Run r) {
      var n = 0;
      for (var k = 0; k < 3000; k++) {
        if (r.pullOne().tags.contains('こはる')) n++;
      }
      return n;
    }
    final plain = count(Run(seed: 21));
    final r = Run(seed: 21)..coins = 9999;
    r.buy(Offer(OfferKind.boost, 0, null, 'こはる'));
    r.buy(Offer(OfferKind.boost, 0, null, 'こはる'));
    expect(r.boost['こはる'], 4);
    expect(count(r), greaterThan(plain * 1.8));
  });

  test('at most two quota cutters on the altar: then they stop dropping and leave the stall', () {
    final r = Run(seed: 22);
    r.place(figureById['kosan']!, 0);
    r.place(figureById['hinata_live']!, 1);
    for (var k = 0; k < 3000; k++) {
      expect(r.pullOne().has<PaydayDiscount>(), isFalse);
    }
    for (var k = 0; k < 300; k++) {
      r.rollShop();
      expect(r.shop.any((o) => o.fig?.has<PaydayDiscount>() ?? false), isFalse);
    }
    r.cells[1] = null; // one leaves: they can come again
    expect(Iterable.generate(3000, (_) => r.pullOne()).any((f) => f.has<PaydayDiscount>()), isTrue);
  });

  test('a 妨害 has a hidden cap of 65-95% and a reward that suits the gacha', () {
    final r = Run(seed: 31, rules: rulesFor(machineById['koharu']!));
    final rewards = <JamReward>{};
    for (var k = 0; k < 400; k++) {
      final j = r.rollJam(force: true)!;
      rewards.add(j.reward);
      if (j.reward == JamReward.goods) expect(j.gift!.tags, contains('こはる'), reason: 'こはる推しガチャ gives こはる goods');
    }
    expect(rewards, JamReward.values.toSet());
    final luck = r.luckBonus;
    r.rewardJam(const Jam(JamKind.steal, 1, reward: JamReward.luck));
    expect(r.luckBonus, luck + 10);
  });

  test('no 妨害 on a machine that turns them off', () {
    final r = Run(seed: 13, rules: Rules(jamRate: 0));
    for (var k = 0; k < 500; k++) {
      expect(r.rollJam(), isNull);
    }
  });
}

/// Re-rolls the stall until [k] is on sale (only some upgrades show each visit).
Offer _find(Run r, OfferKind k) {
  for (var i = 0; i < 200; i++) {
    r.rollShop();
    final o = r.shop.where((o) => o.kind == k);
    if (o.isNotEmpty) return o.first;
  }
  throw StateError('$k never came up');
}
