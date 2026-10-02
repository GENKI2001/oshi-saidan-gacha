// Store screenshots. Drives the real app into a few good-looking moments and
// prints "SHOT <name>" while each one stays still for a few seconds, so a shell
// loop can grab the simulator screen:
//   tool/screenshots.sh <simulator id> <out dir>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/logic/figures.dart';
import 'package:gacha_rogue/main.dart';
import 'package:gacha_rogue/ui/controller.dart';
import 'package:gacha_rogue/ui/game_screen.dart';
import 'package:gacha_rogue/ui/meta.dart';
import 'package:gacha_rogue/ui/rank.dart';
import 'package:gacha_rogue/ui/sfx.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 300]) async {
  for (var k = 0; k < ms ~/ 50; k++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Holds the current frame on screen while the shell takes the picture.
Future<void> shot(WidgetTester t, String name) async {
  // ignore: avoid_print
  print('SHOT $name');
  await t.runAsync(() => Future.delayed(const Duration(seconds: 4)));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (t) async {
    SharedPreferences.setMockInitialValues({});
    Sfx.enabled = false;
    final meta = Meta();
    await meta.load();
    meta
      ..tutorialDone = true
      ..level = 8
      ..levelInto = 600;
    for (final f in figures.take(58)) {
      meta.see(f.id);
    }
    await Rank.instance.start();

    await t.pumpWidget(GachaApp(meta: meta));
    await settle(t, 1500);
    await shot(t, '1_title');

    await t.tap(find.text('あそぶ'));
    await settle(t, 800);
    await t.tap(find.text('はじめる！'));
    await settle(t, 1200);
    final g = (t.state(find.byType(GameScreen)) as dynamic).g as GameController;

    // a shelf that is already doing well
    final r = g.run;
    const layout = {
      0: 'kingyo', 1: 'kingyobachi', 2: 'kingyo', 3: 'koban',
      4: 'takoyaki', 5: 'ringoame', 6: 'wataame', 7: 'maneki',
      8: 'yakisoba', 9: 'hanabi', 10: 'kinchaku', 12: 'tanuki', 13: 'omikuji', 15: 'chochin',
    };
    for (final e in layout.entries) {
      if (r.cells[e.key] == null) r.place(figureById[e.value]!, e.key);
    }
    r.coins = 86;
    r.turn = 3;
    g.shown = List.of(r.cells);
    g.coinsShown = r.coins;

    // a legend out of the capsule
    g.options = [figureById['ryu']!];
    g.phase = Phase.capsule;
    g.openCapsule();
    await settle(t, 1600);
    await shot(t, '2_reveal');

    // place it and catch the coins mid-count
    g.choose(g.options.single);
    await settle(t, 300);
    g.tapCell(11);
    await settle(t, 2600);
    await shot(t, '3_scoring');
    for (var k = 0; k < 80 && g.phase == Phase.scoring; k++) {
      await settle(t, 200);
    }
    await settle(t, 600);
    await shot(t, '4_shelf');

    // the boss's stall
    r.paydaysPaid = 1;
    r.coins = 140;
    g.keepGoing();
    await settle(t, 1200);
    await shot(t, '5_shop');

    // back out to the figure book
    g.leaveShop();
    await settle(t, 600);
    Navigator.of(t.element(find.byType(GameScreen))).pop();
    await settle(t, 1200);
    await t.tap(find.textContaining('図鑑'));
    await settle(t, 1200);
    await shot(t, '6_book');
  });
}
