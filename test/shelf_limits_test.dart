// The altar holds at most 4 goods that multiply all of it (or all of one member),
// the extra spin can be bought once, and the stall's レア商品 come up less often.
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';

void main() {
  test('once 4 ×-all goods are on the altar, no more drop or can be bought', () {
    final r = Run(seed: 5, rules: Rules());
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    final panel = figureById['hinata_dress']!; // a ×-all goods (the life-size panel is one per live)
    for (var i = 0; i < 3; i++) {
      r.place(panel, i);
    }
    expect(r.shelfMultsFull, isFalse);
    expect(r.canBuy(Offer(OfferKind.figure, 10, panel)), isTrue);
    r.place(panel, 3);
    expect(r.shelfMultsFull, isTrue);
    expect(r.canBuy(Offer(OfferKind.figure, 10, panel)), isFalse);
    expect(r.canBuy(Offer(OfferKind.figure, 10, figureById['hinata_badge']!)), isTrue);
    for (var k = 0; k < 2000; k++) {
      expect(Run.isShelfMult(r.pullOne()), isFalse);
    }
    r.coins = 999;
    expect(r.buy(Offer(OfferKind.figure, 10, panel)), isNull);
    expect(r.coins, 999);
  });

  test('the 4 count every one used in the live: stacking counts, taking one off gives nothing back', () {
    final r = Run(seed: 5, rules: Rules());
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    final panel = figureById['unit_panel']!;
    r.place(panel, 0);
    r.overwrite(panel, 0); // stacked on itself: 2 used
    expect(r.shelfMultsUsed, 2);
    r.cells[0] = null; // gone (stolen, sold, …)
    r.place(panel, 1);
    expect(r.shelfMultsFull, isFalse);
    r.overwrite(panel, 1);
    expect(r.shelfMultsUsed, 4);
    expect(r.shelfMultsFull, isTrue);
    expect(r.figs.where((f) => Run.isShelfMult(f.def)).length, 1);
  });

  test('the 4th ×-all goods on the altar takes the others off the stall', () {
    final r = Run(seed: 5, rules: Rules());
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    final panel = figureById['hinata_dress']!;
    for (var i = 0; i < 3; i++) {
      r.place(panel, i);
    }
    r.shop = [Offer(OfferKind.figure, 10, panel), Offer(OfferKind.figure, 10, figureById['hinamomo_dome']!), Offer(OfferKind.luck, 10)];
    r.place(panel, 3);
    expect(r.shop.where((o) => o.kind == OfferKind.figure && Run.isShelfMult(o.fig!)), isEmpty);
    expect(r.shop.length, 3);
    expect(r.shop[2].kind, OfferKind.luck);
  });

  test('only one life-size panel a live: once taken it drops no more and leaves the stall', () {
    final r = Run(seed: 5, rules: Rules());
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    final panel = figureById['unit_panel']!;
    r.shop = [Offer(OfferKind.figure, 10, panel), Offer(OfferKind.luck, 10)];
    r.place(panel, 0);
    expect(r.shop.any((o) => o.kind == OfferKind.figure && o.fig!.id == 'unit_panel'), isFalse);
    expect(r.canBuy(Offer(OfferKind.figure, 10, panel)), isFalse);
    for (var k = 0; k < 3000; k++) {
      expect(r.pullOne().id, isNot('unit_panel'));
    }
  });

  test('the quota grows ×3.95 a song up to the 4th, then the growth itself ×1.5 each アンコール', () {
    final r = Run(seed: 1);
    final d = [for (var k = 0; k < 7; k++) r.baseDue(k)];
    expect(d.take(4), [17, 67, 265, 1048]);
    expect(d[4] / d[3], closeTo(3.95 * 1.5, 0.01));
    expect(d[5] / d[4], closeTo(3.95 * 1.5 * 1.5, 0.01));
    expect(d[6] / d[5], closeTo(3.95 * 1.5 * 1.5 * 1.5, 0.01));
  });

  test('the extra spin can be bought only once', () {
    final r = Run(seed: 1)..coins = 999;
    final before = r.turnsPerSong;
    r.buy(Offer(OfferKind.extraSpin, 0));
    r.buy(Offer(OfferKind.extraSpin, 0));
    expect(r.turnsPerSong, before + 1);
    for (var k = 0; k < 300; k++) {
      r.rollShop();
      expect(r.shop.where((o) => o.kind == OfferKind.extraSpin), isEmpty);
    }
  });

  test('a レア商品 shows up at about one stall visit in twelve', () {
    final r = Run(seed: 9);
    var rare = 0;
    for (var k = 0; k < 4000; k++) {
      r.rollShop();
      if (r.shop.any((o) => o.rare)) rare++;
    }
    expect(rare / 4000, closeTo(0.08, 0.02));
  });
}
