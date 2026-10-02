// Walks the guided first game through every step, the way the highlighted
// controls would be tapped, and checks each one leads to the next.
import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/run.dart';
import 'package:gacha_rogue/ui/controller.dart';
import 'package:gacha_rogue/ui/meta.dart';
import 'package:gacha_rogue/ui/sfx.dart';

void main() {
  testWidgets('the tutorial goes from the first spin to the end', (t) async {
    Sfx.enabled = false;
    final meta = Meta();
    final g = GameController(meta, tutorial: true);
    Future<void> settle(Coach want) async {
      for (var k = 0; k < 100 && g.coach != want; k++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(g.coach, want);
    }

    expect(g.coach, Coach.spin1);
    g.turnHandle();
    await settle(Coach.place1);
    expect(g.options.single.id, 'takoyaki');
    g.choose(g.options.single);
    expect(g.coach, Coach.cell1);
    await g.tapCell(0); // not the highlighted cell: ignored
    expect(g.run.cells[0], isNull);
    g.tapCell(GameController.tutorialCell1);
    await settle(Coach.coins);
    g.coachNext();
    expect(g.coach, Coach.goal);
    g.coachNext();
    expect(g.coach, Coach.spin2);

    g.turnHandle();
    await settle(Coach.repull);
    expect(g.options.single.id, 'tanuki');
    g.repull();
    await settle(Coach.item);
    expect(g.options.single.id, 'ringoame');
    g.coachNext();
    g.coachNext();
    g.coachNext();
    expect(g.coach, Coach.place2);
    g.choose(g.options.single);
    g.tapCell(GameController.tutorialCell2);
    await settle(Coach.doubled);
    // りんご飴 doubled the たこ焼き next to it
    expect(g.run.cells[GameController.tutorialCell1]!.lastGain, 4);
    g.coachNext();
    expect(g.coach, Coach.spin3);

    // わたあめ goes far from the りんご飴, then 狸の置物 next to it
    g.turnHandle();
    await settle(Coach.place3);
    expect(g.options.single.id, 'wataame');
    g.choose(g.options.single);
    expect(g.coach, Coach.cell3);
    await g.tapCell(0); // not the highlighted cell: ignored
    expect(g.run.cells[0], isNull);
    g.tapCell(GameController.tutorialCell3);
    await settle(Coach.spin4);
    g.turnHandle();
    await settle(Coach.place4);
    expect(g.options.single.id, 'tanuki');
    g.choose(g.options.single);
    g.tapCell(GameController.tutorialCell4);
    await settle(Coach.swap1);

    // いれかえ the two, so the わたあめ sits by the りんご飴
    g.toggleSwap();
    expect(g.coach, Coach.swap2);
    await g.tapCell(GameController.tutorialCell1); // not the わたあめ: ignored
    expect(g.swapFirst, isNull);
    await g.tapCell(GameController.tutorialCell3);
    expect(g.coach, Coach.swap3);
    await g.tapCell(GameController.tutorialCell1); // not the 狸の置物: ignored
    expect(g.coach, Coach.swap3);
    await g.tapCell(GameController.tutorialCell4);
    expect(g.coach, Coach.swapped);
    expect(g.run.cells[GameController.tutorialCell4]!.def.id, 'wataame');
    expect(g.run.cells[GameController.tutorialCell3]!.def.id, 'tanuki');
    g.coachNext();
    expect(g.coach, Coach.go);
    g.turnHandle();
    expect(g.coach, Coach.free);

    // free play up to the first payday
    for (var k = 0; k < 400 && g.coach == Coach.free; k++) {
      switch (g.phase) {
        case Phase.ready:
          g.turnHandle();
        case Phase.capsule:
          g.openCapsule();
        case Phase.reveal:
          g.choose(g.options.single);
        case Phase.place:
          if (g.pending.isNotEmpty) g.tapCell(g.run.emptyCells.first);
        default:
          break;
      }
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(g.coach, Coach.pay);
    g.pay();
    await settle(Coach.expand);
    await t.pump(const Duration(milliseconds: 50));
    final expand = g.run.shop.firstWhere((o) => o.kind == OfferKind.expand);
    expect(g.run.coins, greaterThanOrEqualTo(g.run.priceOf(expand)));
    g.buy(expand);
    await settle(Coach.reroll);
    expect(g.run.rerolls, 1);
    g.reroll();
    expect(g.coach, Coach.multi);
    g.coachNext();
    expect(g.coach, Coach.leave);
    g.leaveShop();
    expect(g.coach, Coach.card);
    final card = g.run.cells.indexWhere((f) => f?.def.id == kCardId);
    expect(card, greaterThanOrEqualTo(0), reason: 'the boss left his card to remove');
    g.cardSeen(); // its effect was shown
    expect(g.coach, Coach.remove1);
    g.toggleRemove();
    expect(g.coach, Coach.remove2);
    await g.tapCell(g.run.cells.indexWhere((f) => f != null && f.def.id != kCardId)); // not the card: ignored
    expect(g.coach, Coach.remove2);
    await g.tapCell(card);
    expect(g.coach, Coach.tools);
    expect(g.run.cells[card], isNull);
    g.coachNext();
    expect(g.coach, Coach.none);
    expect(meta.tutorialDone, isTrue);
    await t.pump(const Duration(seconds: 2));
    g.dispose();
  });
}
