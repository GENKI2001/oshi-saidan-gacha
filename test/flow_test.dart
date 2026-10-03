// Plays whole runs through GameController (the same calls the buttons make)
// and checks the phase machine never gets stuck.
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/ui/controller.dart';
import 'package:oshi_saidan/ui/meta.dart';
import 'package:oshi_saidan/ui/sfx.dart';

void main() {
  testWidgets('runs reach the end screen without getting stuck', (t) async {
    Sfx.enabled = false;
    final setups = <GameController Function()>[
      () => GameController(Meta()),
      () => GameController(Meta(), machine: machineById['yoru'], ascension: 10),
      () => GameController(Meta(), machine: machineById['shizumomo'], ascension: 3),
      () => GameController(Meta(), machine: machineById['premium'], ascension: 5),
      () => GameController(Meta(), machine: machineById['koharu']),
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
            g.payday == null ? g.pay() : g.toShop();
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
          case Phase.cutin:
            g.skipCutin();
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

  testWidgets('あきらめる from the menu goes straight to the result, also mid-capsule', (t) async {
    Sfx.enabled = false;
    final meta = Meta();
    final g = GameController(meta);
    g.turnHandle();
    expect(g.canGiveUp, isFalse, reason: 'not while the capsule drops');
    for (var k = 0; k < 20 && g.phase != Phase.capsule; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(g.canGiveUp, isTrue);
    g.giveUp();
    expect(g.phase, Phase.over);
    expect(meta.runs, 1);
    await t.pump(const Duration(seconds: 2));
    expect(g.phase, Phase.over, reason: 'nothing pending brings the run back');
    g.dispose();
  });
}
