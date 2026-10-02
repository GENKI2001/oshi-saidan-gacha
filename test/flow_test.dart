// Plays whole runs through GameController (the same calls the buttons make)
// and checks the phase machine never gets stuck.
import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/logic/modes.dart';
import 'package:gacha_rogue/ui/controller.dart';
import 'package:gacha_rogue/ui/meta.dart';
import 'package:gacha_rogue/ui/sfx.dart';

void main() {
  testWidgets('runs reach the end screen without getting stuck', (t) async {
    Sfx.enabled = false;
    final setups = <GameController Function()>[
      () => GameController(Meta()),
      () => GameController(Meta(), machine: machineById['ayashii'], ascension: 10),
      () => GameController(Meta(), machine: machineById['mizu'], ascension: 3),
      () => GameController(Meta(), machine: machineById['kinpika'], ascension: 5),
      () => GameController(Meta(), machine: machineById['kuishinbo']),
    ];
    for (var game = 0; game < setups.length; game++) {
      final g = setups[game]();
      var guard = 0, postponed = false, shopped = 0;
      while (g.phase != Phase.over) {
        expect(++guard, lessThan(5000), reason: 'stuck in ${g.phase}');
        switch (g.phase) {
          case Phase.ready:
            g.turnHandle();
          case Phase.capsule:
            g.openCapsule();
          case Phase.reveal:
            g.choose(g.options.last);
          case Phase.place:
            // pending is empty while a placement's own beats are still playing
            if (g.pending.isEmpty) break;
            final empty = g.run.emptyCells;
            if (empty.isEmpty) {
              expect(g.canDiscard, isTrue);
              g.discardPending();
            } else {
              g.tapCell(empty.first);
            }
          case Phase.payday:
            if (g.payday == null) g.pay();
          case Phase.failed:
            if (!postponed && g.run.canPostpone) {
              postponed = true;
              g.postpone();
            } else {
              g.giveUp();
            }
          case Phase.shop:
            for (final o in g.run.shop) {
              if (g.run.coins >= g.run.priceOf(o)) g.buy(o);
            }
            shopped++;
            g.leaveShop();
          case Phase.cleared:
            g.keepGoing();
          case Phase.dropping || Phase.scoring || Phase.over:
            break;
        }
        await t.pump(const Duration(milliseconds: 400));
      }
      // ignore: avoid_print
      print('game $game (${g.machine.name}): paydays ${g.run.paydaysPaid}, turns ${g.run.turn}, shops $shopped, best ${g.run.bestTurn}');
      await t.pump(const Duration(seconds: 2)); // let delayed jingles fire
      g.dispose();
    }
  });

  test('the boss card cannot be thrown away while there is room', () {
    Sfx.enabled = false;
    final g = GameController(Meta());
    g.pending.add(figureById[kCardId]!);
    expect(g.canDiscard, isFalse);
  });
}
