// Walks the guided first game through every step, the way the highlighted
// controls would be tapped, and checks each one leads to the next.
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/ui/controller.dart';
import 'package:oshi_saidan/ui/meta.dart';
import 'package:oshi_saidan/ui/sfx.dart';

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
    expect(g.options.single.id, 'koharu_keyholder');
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
    expect(g.options.single.id, 'momo_badge');
    g.repull();
    await settle(Coach.item);
    expect(g.options.single.id, 'koharu_acsta');
    g.coachNext();
    g.coachNext();
    g.coachNext();
    expect(g.coach, Coach.place2);
    g.choose(g.options.single);
    g.tapCell(GameController.tutorialCell2);
    await settle(Coach.doubled);
    // the アクスタ doubled the アクキー next to it
    expect(g.run.cells[GameController.tutorialCell1]!.lastGain, 4);
    g.coachNext();
    expect(g.coach, Coach.go);
    // 回す！ on that last step: the tutorial is over, the game carries on
    g.turnHandle();
    expect(g.coach, Coach.none);
    expect(meta.tutorialDone, isTrue);
    await t.pump(const Duration(seconds: 5));
    g.dispose();
  });
}
