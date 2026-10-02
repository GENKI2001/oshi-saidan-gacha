// Runs on the iOS simulator / a device:
//   flutter test integration_test -d <simulator id> --dart-define=RANK_DEMO=true
// Plays a whole run through the real app (title → machine select → game),
// checks the best turn reaches the leaderboard and the player's row shows on
// the ranking screen, and that tapping a shelf figure opens its details.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/main.dart';
import 'package:gacha_rogue/ui/controller.dart';
import 'package:gacha_rogue/ui/game_screen.dart';
import 'package:gacha_rogue/ui/meta.dart';
import 'package:gacha_rogue/ui/rank.dart';
import 'package:gacha_rogue/ui/sfx.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 300]) => t.pump(Duration(milliseconds: ms));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('run → best turn sent → shown on the ranking', (t) async {
    SharedPreferences.setMockInitialValues({});
    Sfx.enabled = true; // exercise the real audio plugin too
    final meta = Meta();
    await meta.load();
    meta.tutorialDone = true; // this test plays a normal run (the tutorial has its own test)
    await Rank.instance.start();
    expect(Rank.instance.ready, isTrue, reason: 'run with --dart-define=RANK_DEMO=true');

    await t.pumpWidget(GachaApp(meta: meta));
    await settle(t, 800);
    expect(find.text('ランキング'), findsOneWidget);

    await t.tap(find.text('あそぶ'));
    await settle(t, 800);
    await t.tap(find.text('はじめる！'));
    await settle(t, 800);
    final g = (t.state(find.byType(GameScreen)) as dynamic).g as GameController;
    var infoChecked = false;

    var guard = 0;
    while (g.phase != Phase.over) {
      expect(++guard, lessThan(4000), reason: 'stuck in ${g.phase}');
      switch (g.phase) {
        case Phase.ready:
          // once, tap a figure on the shelf: its details must open
          final placed = g.run.cells.indexWhere((c) => c != null);
          if (!infoChecked && placed >= 0) {
            infoChecked = true;
            await t.tap(find.byKey(ValueKey('cell-$placed')));
            await settle(t, 600);
            expect(find.textContaining(g.run.cells[placed]!.def.description.split('\n').first), findsWidgets);
            Navigator.of(t.element(find.byType(GameScreen))).pop(); // close the sheet
            await settle(t, 600);
            expect(g.phase, Phase.ready);
          }
          g.turnHandle();
        case Phase.capsule:
          g.openCapsule();
        case Phase.reveal:
          g.choose(g.options.last);
        case Phase.place:
          if (g.pending.isEmpty) break;
          final empty = g.run.emptyCells;
          empty.isEmpty ? g.discardPending() : g.tapCell(empty.first);
        case Phase.payday:
          if (g.payday == null) g.pay();
        case Phase.failed:
          g.giveUp();
        case Phase.shop:
          // buy the first affordable thing (prices rise with each purchase), then move on
          final o = g.run.shop.where((o) => g.run.coins >= g.run.priceOf(o)).firstOrNull;
          if (o != null) g.buy(o);
          g.leaveShop();
        case Phase.cleared:
          g.giveUp();
        default:
          break;
      }
      await settle(t, 250);
    }
    await settle(t, 1500);

    expect(infoChecked, isTrue);
    // a first run always sets a best turn: sent and ranked
    expect(g.turnRecord, isTrue);
    expect(g.turnRank, isNotNull);
    expect(find.textContaining('最高かせぎ 全国'), findsOneWidget);
    // ignore: avoid_print
    print('best turn ${g.run.bestTurn}, rank ${g.turnRank}');

    // open the ranking from the result screen and find our row
    await t.tap(find.text('ランキング').last);
    await settle(t, 1000);
    expect(find.textContaining('（あなた）'), findsOneWidget);
    expect(find.text('${g.run.bestTurn}'), findsWidgets);

    // the other boards and the friends tab render too
    for (final b in boards.values) {
      await t.tap(find.text(b.title));
      await settle(t, 500);
    }
    await t.tap(find.text('フレンド'));
    await settle(t, 500);
    expect(t.takeException(), isNull);
  });
}
