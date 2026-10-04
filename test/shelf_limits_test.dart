// The altar holds at most 4 goods that multiply all of it (or all of one member),
// the extra spin can be bought once, and the stall's レア商品 come up less often.
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';

void main() {
  test('once 4 ×-all goods are on the altar, no more drop or can be bought', () {
    final r = Run(seed: 5, rules: Rules()..level = 99);
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    final panel = figureById['unit_panel']!;
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

  test('the 4th ×-all goods on the altar takes the others off the stall', () {
    final r = Run(seed: 5, rules: Rules()..level = 99);
    for (var i = 0; i < r.size; i++) {
      r.cells[i] = null;
    }
    final panel = figureById['unit_panel']!;
    for (var i = 0; i < 3; i++) {
      r.place(panel, i);
    }
    r.shop = [Offer(OfferKind.figure, 10, panel), Offer(OfferKind.figure, 10, figureById['hinamomo_dome']!), Offer(OfferKind.luck, 10)];
    r.place(panel, 3);
    expect(r.shop.where((o) => o.kind == OfferKind.figure && Run.isShelfMult(o.fig!)), isEmpty);
    expect(r.shop.length, 3);
    expect(r.shop[2].kind, OfferKind.luck);
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
