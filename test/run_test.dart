import 'dart:math' as math;

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

  test('payday takes coins, fails when short, and the ad gives 5 more spins in the same song, once', () {
    final r = Run(seed: 3)..coins = 100;
    r.songTurn = 5;
    expect(r.paydayNow, isTrue);
    final p = r.payday();
    expect(p.paid, isTrue);
    expect(r.coins, 100 - r.baseDue(0));
    r
      ..songTurn = 5
      ..coins = 7;
    final dueBefore = r.due;
    expect(r.payday().paid, isFalse);
    expect(r.canPostpone, isTrue);
    r.postpone();
    // the same song against the same quota, the hearts kept, 5 spins to go
    expect(r.paydaysPaid, 1);
    expect(r.due, dueBefore);
    expect(r.coins, 7);
    expect(r.turnsToPayday, Run.extraSpins);
    expect(r.paydayNow, isFalse);
    // and never again this live
    expect(r.canPostpone, isFalse);
  });

  test('the extension takes back what the 「曲の終わりに」 goods paid in, since they pay again', () {
    final r = Run(seed: 3);
    r.place(figureById.values.firstWhere((d) => d.has<OnPaydayGain>()), 0);
    final bonus = r.paydayBonus;
    expect(bonus, greaterThan(0));
    r
      ..paydaysPaid = 2 // a quota well above what the goods pay in
      ..songTurn = 5
      ..coins = 3;
    expect(r.payday().paid, isFalse);
    expect(r.coins, 3 + bonus);
    r.postpone();
    expect(r.coins, 3);
  });

  test('stacking makes quota cutters, luck and spawners stronger; only two cutters count', () {
    final cut = figureById.values.firstWhere((d) => d.has<PaydayDiscount>());
    final pct = cut.effect<PaydayDiscount>()!.pct;
    final r = Run(seed: 3);
    final base = r.due;
    r.place(cut, 0);
    expect(r.due, (base * (1 - pct / 100)).round());
    r.overwrite(cut, 0); // stacked: ×2
    expect(r.due, (base * math.max(0.4, 1 - math.min(90, pct * 2) / 100)).round());

    final lucky = figureById['gacha_charm']!;
    final l = Run(seed: 3);
    l.place(lucky, 0);
    final one = l.luck;
    l.overwrite(lucky, 0);
    expect(l.luck, one * 2);

    final spawner = figureById['blind_bag']!;
    final n = spawner.effect<SpawnEveryN>()!.n;
    final s1 = Run(seed: 3)..place(spawner, 0);
    final s2 = Run(seed: 3)
      ..place(spawner, 0)
      ..overwrite(spawner, 0);
    for (var k = 0; k < n; k++) {
      s1.endTurn();
      s2.endTurn();
    }
    expect(s1.figs.length, 2);
    expect(s2.figs.length, 3);
  });

  test('three quota cutters on the altar: only the two strongest count', () {
    final cuts = figureById.values.where((d) => d.has<PaydayDiscount>()).toList();
    final r = Run(seed: 3);
    final base = r.due;
    for (var i = 0; i < 3; i++) {
      r.place(cuts[i % cuts.length], i);
    }
    final pcts = [for (var i = 0; i < 3; i++) cuts[i % cuts.length].effect<PaydayDiscount>()!.pct]..sort((a, b) => b.compareTo(a));
    final f = pcts.take(2).fold(1.0, (a, p) => a * (1 - p / 100));
    expect(r.due, (base * math.max(0.4, f)).round());
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

  test('the bingo card counts its own up-right diagonal, on any width', () {
    for (final grow in [false, true]) {
      final r = Run(seed: 3)..coins = 999;
      if (grow) {
        r.shop = [Offer(OfferKind.expand, 1)];
        r.buy(r.shop.first); // 5 wide
      }
      final c = r.cols;
      final at = 3 * c; // bottom-left corner of a 4-row altar
      r.place(figureById['hinakoha_bingo']!, at);
      expect(r.endTurn().gains[at], 1, reason: 'line not filled yet');
      for (var k = 1; k < 4; k++) {
        r.place(figureById['coin']!, (3 - k) * c + k);
      }
      expect(r.endTurn().gains[at], 17, reason: 'cols $c');
    }
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
