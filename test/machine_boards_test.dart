import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/ui/rank.dart';

void main() {
  test('every machine has its own leaderboard, with unique IDs on both stores', () {
    expect(machineBoards.keys.toSet(), machines.map((m) => m.id).toSet());
    final ios = machineBoards.values.map((b) => b.ios).toSet();
    final android = machineBoards.values.map((b) => b.android).toSet();
    expect(ios.length, machines.length);
    expect(android.length, machines.length);
    expect(ios.intersection(boards.values.map((b) => b.ios).toSet()), isEmpty, reason: 'not clashing with the shared boards');
  });
}
