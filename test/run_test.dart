import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/run.dart';

void main() {
  test('lucky cat doubles the coin next to it', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['koban']!, 0);
    r.place(figureById['maneki']!, 1);
    expect(r.endTurn().total, 1 * 2 + 1);
  });

  test('daikoku doubles everything after additions', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['takoyaki']!, 0);
    r.place(figureById['taiko']!, 1);
    r.place(figureById['daikoku']!, 15);
    // takoyaki 2 + drum buff 2 = 4, ×2
    expect(r.endTurn().total, 8);
  });

  test('cotton candy grows each turn', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['wataame']!, 5);
    expect([r.endTurn().total, r.endTurn().total, r.endTurn().total], [0, 1, 2]);
  });

  test('fireworks go off on turn 3 and leave', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['takoyaki']!, 0);
    r.place(figureById['hanabi']!, 5);
    expect([r.endTurn().total, r.endTurn().total, r.endTurn().total], [2, 2, 6]);
    expect(r.cells[5], isNull);
  });

  test('payday takes coins, fails when short, and can be postponed once', () {
    final r = Run(seed: 3)..coins = 100;
    r.turn = 5;
    expect(r.paydayNow, isTrue);
    final p = r.payday();
    expect(p.paid, isTrue);
    expect(r.coins, 100 - Run.firstDue);
    r
      ..turn = 10
      ..coins = 0;
    expect(r.payday().paid, isFalse);
    r.postpone();
    expect(r.paydaysPaid, 2);
    expect(r.due, r.baseDue(2) + r.baseDue(1));
  });

  test('expanding the shelf keeps figures in their row and column', () {
    final r = Run(seed: 3)..coins = 999;
    r.place(figureById['koban']!, 5); // row 1, col 1
    r.shop = [Offer(OfferKind.expand, 1)];
    r.buy(r.shop.first);
    expect(r.cols, 5);
    expect(r.cells[1 * 5 + 1]?.def.id, 'koban');
  });
}
