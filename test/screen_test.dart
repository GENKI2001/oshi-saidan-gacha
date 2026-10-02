import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gacha_rogue/ui/game_screen.dart';
import 'package:gacha_rogue/ui/meta.dart';

void main() {
  testWidgets('game screen lays out on a phone', (t) async {
    t.view.physicalSize = const Size(1465, 812);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(MaterialApp(home: GameScreen(meta: Meta())));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('回す！'), findsOneWidget);
    expect(t.getSize(find.text('回す！')).width, greaterThan(20));
  });
}
