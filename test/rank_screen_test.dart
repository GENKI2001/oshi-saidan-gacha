import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/ui/rank.dart';
import 'package:gacha_rogue/ui/rank_screen.dart';

void main() {
  testWidgets('ranking screen opens and switches boards without errors', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const MaterialApp(home: RankScreen()));
    await t.pump(const Duration(milliseconds: 300));
    // not signed in (tests have no Game Center): the sign-in panel shows
    expect(find.text('ログインする'), findsOneWidget);
    for (final b in boards.values) {
      await t.tap(find.text(b.title));
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.tap(find.text('フレンド'));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
  });
}
