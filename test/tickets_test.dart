import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/run.dart';

void main() {
  test('いれかえ: free, refills every payday, the stall raises it up to 3', () {
    final r = Run(seed: 1);
    r.place(figureById['koban']!, 0);
    expect(r.swap(0, 5), isTrue);
    expect(r.cells[0], isNull);
    expect(r.cells[5]!.def.id, 'koban');
    expect(r.swap(5, 0), isFalse, reason: 'only one use per payday');
    r.coins = 9999;
    for (var k = 0; k < 60; k++) {
      r.rollShop();
      final more = r.shop.where((o) => o.kind == OfferKind.swapTicket);
      if (more.isNotEmpty) r.buy(more.first);
    }
    expect(r.swapMax, Run.maxUses, reason: 'capped at 3');
    // paying a payday refills every use for free
    r.swapTickets = 0;
    r.coins = 9999;
    r.turn = Run.turnsPerPayday;
    r.payday();
    expect(r.swapTickets, Run.maxUses);
  });

  test('a figure can be overwritten, but not the boss card', () {
    final r = Run(seed: 2);
    for (var i = 0; i < r.size; i++) {
      if (r.cells[i] == null) r.place(figureById[i == 3 ? kCardId : 'koban']!, i);
    }
    expect(r.emptyCells, isEmpty);
    expect(r.canOverwrite(3), isFalse);
    expect(r.canOverwrite(0), isTrue);
    r.overwrite(figureById['takoyaki']!, 0);
    expect(r.cells[0]!.def.id, 'takoyaki');
  });

  test('a figure can be overwritten while the shelf still has room', () {
    final r = Run(seed: 2);
    r.place(figureById['koban']!, 0);
    expect(r.emptyCells, isNotEmpty);
    expect(r.canOverwrite(0), isTrue);
    expect(r.canOverwrite(1), isFalse);
    r.overwrite(figureById['takoyaki']!, 0);
    expect(r.cells[0]!.def.id, 'takoyaki');
  });

  test('どける starts at one use per payday; an upgrade adds one', () {
    final r = Run(seed: 3)..coins = 999;
    r.place(figureById['koban']!, 0);
    r.remove(0);
    expect(r.removeTickets, 0);
    r.buy(_find(r, OfferKind.removeTickets));
    expect([r.removeTickets, r.removeMax], [1, 2]);
  });

  test('the shelf grows to 6x6 and no further, each step dearer', () {
    final r = Run(seed: 4)..coins = 1 << 30;
    var last = 0;
    while (r.canGrow) {
      expect(r.expandPrice, greaterThan(last));
      last = r.expandPrice;
      r.buy(Offer(OfferKind.expand, r.expandPrice));
      r.shopBuys = 0;
    }
    expect([r.cols, r.rows], [6, 6]);
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

  test('the stall shows three things, one a どける / いれかえ upgrade while they can grow', () {
    final r = Run(seed: 8);
    for (var k = 0; k < 200; k++) {
      r.rollShop();
      expect(r.shop.length, 3);
      expect(r.shop.any((o) => o.kind == OfferKind.removeTickets || o.kind == OfferKind.swapTicket), isTrue);
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
