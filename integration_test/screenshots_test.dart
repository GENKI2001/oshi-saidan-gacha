// Store screenshots. Drives the real app into a few good-looking moments and
// prints "SHOT <name>" while each one stays still for a few seconds, so a shell
// loop can grab the simulator screen:
//   tool/screenshots.sh <simulator id> <out dir>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/main.dart';
import 'package:oshi_saidan/ui/controller.dart';
import 'package:oshi_saidan/ui/game_screen.dart';
import 'package:oshi_saidan/ui/lines.dart';
import 'package:oshi_saidan/ui/meta.dart';
import 'package:oshi_saidan/ui/rank.dart';
import 'package:oshi_saidan/ui/sfx.dart';
import 'package:oshi_saidan/ui/voice.dart';
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
    await settle(t, 1500);
    await shot(t, 'h_start'); // the hall before any hearts

    // a shelf that is already doing well
    final r = g.run;
    const layout = {
      0: 'shizumomo_strap', 1: 'shizuku_acsta', 2: 'shizumomo_strap', 3: 'coin',
      4: 'koharu_keyholder', 5: 'koharu_acsta', 6: 'koharu_badge', 7: 'hinamomo_maneki',
      8: 'koharu_cookie', 9: 'yoru_tape', 10: 'oshi_bank', 12: 'momo_badge', 13: 'hinata_photo', 15: 'yoru_badge',
    };
    for (final e in layout.entries) {
      if (r.cells[e.key] == null) r.place(figureById[e.value]!, e.key);
    }
    r.coins = 86;
    r.turn = 3;
    g.shown = List.of(r.cells);
    g.coinsShown = r.coins;

    // a ★4 capsule waiting to be opened
    g.options = [figureById['hinamomo_dome']!];
    g.phase = Phase.capsule;
    g.notifyListeners();
    await settle(t, 800);
    await shot(t, 'h_capsule');
    // opened: the idol cuts in first
    g.openCapsule();
    await settle(t, 900);
    await shot(t, '2_cutin');
    g.skipCutin();
    await settle(t, 1600);
    await shot(t, '3_reveal');

    // place it and catch the coins mid-count
    g.choose(g.options.single);
    await settle(t, 300);
    g.tapCell(11);
    await settle(t, 2600);
    await shot(t, '4_scoring');
    for (var k = 0; k < 80 && g.phase == Phase.scoring; k++) {
      await settle(t, 200);
    }
    await settle(t, 600);
    await shot(t, 'h_spin');

    // a normal pull: she says hello in a bubble
    g.options = [figureById['yoru_penlight']!];
    g.phase = Phase.capsule;
    g.openCapsule();
    await settle(t, 1400);
    await shot(t, '5_pull');
    g.choose(g.options.single);
    await settle(t, 300);
    g.tapCell(14);
    for (var k = 0; k < 80 && g.phase != Phase.ready; k++) {
      await settle(t, 200);
    }

    // the end of a song: つむぎ checks the quota
    r.turn = 5;
    r.coins = 160;
    g.coinsShown = 160;
    g.phase = Phase.payday;
    g.payday = null;
    g.say(0, linePayday.first);
    await settle(t, 1200);
    await shot(t, '6_payday');

    // quota met: the curtain call, then the merch booth
    g.pay();
    await settle(t, 1600);
    await shot(t, '7_songclear');
    g.toShop();
    await settle(t, 1400);
    await shot(t, '8_shop');

    // a 妨害: the idol tells what is at stake (for あそびかた)
    g.leaveShop();
    await settle(t, 600);
    g.run.rules.jamRate = 1;
    g.options = [figureById['koharu_badge']!];
    g.phase = Phase.capsule;
    g.openCapsule();
    await settle(t, 1200);
    g.choose(g.options.single);
    await settle(t, 300);
    g.tapCell(g.run.emptyCells.isEmpty ? 0 : g.run.emptyCells.first); // (written over when the altar is full)
    for (var k = 0; k < 120 && g.jamStage != 1; k++) {
      await settle(t, 100);
    }
    // its lines fade in on the real clock: let them, then draw that frame
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1800)));
    await t.pump(const Duration(milliseconds: 1));
    await shot(t, 'h_jam');

    // back out to the members and the goods book
    g.giveUp();
    await settle(t, 2500);
    await shot(t, 'h_result');
    Navigator.of(t.element(find.byType(GameScreen))).pop();
    await settle(t, 1200);
    await t.tap(find.text('メンバー'));
    await settle(t, 1200);
    await t.tap(find.byKey(const ValueKey('member-よる')));
    await settle(t, 1200);
    await shot(t, '9_members');
    await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await settle(t, 1000);
    await t.tap(find.textContaining('図鑑'));
    await settle(t, 1200);
    await shot(t, '10_book');
    await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await settle(t, 1000);
    await t.tap(find.text('実績'));
    await settle(t, 1200);
    await shot(t, '11_achievements');
    await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await settle(t, 1000);
    await t.tap(find.text('あそぶ'));
    await settle(t, 1500);
    await shot(t, 'h_select');
    // let the last voice line go quiet before the tree is torn down
    Voice.stop();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump();
  });
}
