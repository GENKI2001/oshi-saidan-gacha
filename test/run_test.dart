import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/defs.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/run.dart';

FigureDef _plain(String tag) => FigureDef(id: 'test_$tag', name: tag, emoji: '', rarity: Rarity.normal, tags: [tag], effects: const [Add(2)]);

void main() {
  test('lucky cat doubles the ひなた goods next to it', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['hinata_badge']!, 0);
    r.place(figureById['hinamomo_maneki']!, 1);
    expect(r.endTurn().total, 1 * 2 + 1);
  });

  test('cotton candy grows each turn', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['koharu_badge']!, 5);
    expect([r.endTurn().total, r.endTurn().total, r.endTurn().total], [0, 1, 2]);
  });

  test('the silver tape goes off on turn 3: only よる goods ×4, then it leaves', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['koharu_keyholder']!, 0); // こはる +2: untouched
    r.place(_plain('よる'), 2); // よる +2: ×4 on turn 3
    r.place(figureById['yoru_tape']!, 10);
    expect([r.endTurn().total, r.endTurn().total, r.endTurn().total], [4, 4, 2 + 8]);
    expect(r.cells[10], isNull);
  });

  test('payday takes coins, fails when short, and can be postponed once', () {
    final r = Run(seed: 3)..coins = 100;
    r.songTurn = 5;
    expect(r.paydayNow, isTrue);
    final p = r.payday();
    expect(p.paid, isTrue);
    expect(r.coins, 100 - Run.firstDue);
    r
      ..songTurn = 5
      ..coins = 0;
    expect(r.payday().paid, isFalse);
    r.postpone();
    expect(r.paydaysPaid, 2);
    expect(r.due, r.baseDue(2) + r.baseDue(1));
  });

  test('expanding the shelf keeps figures in their row and column', () {
    final r = Run(seed: 3)..coins = 999;
    r.place(figureById['coin']!, 5); // row 1, col 1
    r.shop = [Offer(OfferKind.expand, 1)];
    r.buy(r.shop.first);
    expect(r.cols, 5);
    expect(r.cells[1 * 5 + 1]?.def.id, 'coin');
  });

  test('the same goods on itself stacks: ×2, then ×3', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['coin']!, 0);
    expect(r.endTurn().total, 1);
    expect(r.stacksOn(figureById['coin']!, 0), isTrue);
    r.overwrite(figureById['coin']!, 0);
    expect(r.cells[0]!.stack, 2);
    expect(r.endTurn().total, 2);
    r.overwrite(figureById['coin']!, 0);
    expect(r.endTurn().total, 3);
    // a different goods still replaces it
    r.overwrite(figureById['hinata_badge']!, 0);
    expect(r.cells[0]!.stack, 1);
  });

  test('a stacked multiplier grows with the stack: ×2 twice is ×4, three times ×6', () {
    final r = Run(seed: 3)..coins = 0;
    r.place(figureById['yoru_star']!, 5); // ×2 on its diagonals
    r.overwrite(figureById['yoru_star']!, 5);
    r.place(figureById['coin']!, 0);
    expect(r.endTurn().gains[0], 4);
    r.overwrite(figureById['yoru_star']!, 5);
    expect(r.endTurn().gains[0], 6);
  });

  test('diagonal goods see only the corner-to-corner cells', () {
    final r = Run(seed: 3)..coins = 0;
    // 4x4: cell 5 has diagonals 0, 2, 8, 10 and neighbours 1, 4, 6, 9
    r.place(figureById['shizuku_snow']!, 5); // +2 per diagonal goods
    r.place(figureById['coin']!, 0);
    r.place(figureById['coin']!, 10);
    r.place(figureById['coin']!, 1); // a neighbour: does not count
    final g = r.endTurn().gains;
    expect(g[5], 4);
  });

  test('アンコールの魔法 adds a spin to every song', () {
    final r = Run(seed: 3)..coins = 999;
    final o = Offer(OfferKind.extraSpin, 1);
    r.shop = [o];
    r.shopBuys = 0;
    expect(r.priceOf(o), 1, reason: 'a レア商品 is never the free pick');
    r.buy(o);
    expect(r.turnsPerSong, Run.turnsPerPayday + 1);
    for (var k = 0; k < Run.turnsPerPayday; k++) {
      r.endTurn();
    }
    expect(r.paydayNow, isFalse);
    r.endTurn();
    expect(r.paydayNow, isTrue);
  });

  test('確定チケット: the next song drops only what it says', () {
    final r = Run(seed: 9)..coins = 999;
    r.buy(Offer(OfferKind.idolSong, 0, null, 'こはる'));
    for (var k = 0; k < 200; k++) {
      expect(r.pullOne().cast, contains('こはる'));
    }
    r.idolSong = null;
    r.buy(Offer(OfferKind.rareSong, 0));
    for (var k = 0; k < 200; k++) {
      expect(r.pullOne().rarity.index, greaterThanOrEqualTo(Rarity.rare.index));
    }
    r.songTurn = Run.turnsPerPayday;
    r.payday();
    expect([r.rareSong, r.idolSong], [false, null], reason: 'only for one song');
  });
}
