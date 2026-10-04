import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/achievements.dart';
import 'package:oshi_saidan/ui/meta.dart';

void main() {
  test('every シチュエーションボイス is opened by exactly one achievement (none for つむぎ)', () {
    for (final t in asmrTracks) {
      expect(achievements.where((a) => a.asmr == t.id).length, 1, reason: t.id);
    }
    expect(asmrTracks.length, 15);
    expect(asmrTracks.where((t) => t.who == 'つむぎ'), isEmpty);
  });

  test('achievements unlock once, from the records', () {
    final m = Meta();
    expect(m.checkAchievements(), isEmpty);
    m.runs = 1;
    expect(m.checkAchievements().map((a) => a.id), ['first_live']);
    expect(m.checkAchievements(), isEmpty, reason: 'not twice');
    for (var k = 0; k < 30; k++) {
      m.addPlaced('しずく');
    }
    m.noteAltar({'しずく': 6});
    final got = m.checkAchievements().map((a) => a.id).toSet();
    expect(got, {'shizuku_altar', 'shizuku_place'});
    m.clearedMachine('momo');
    expect(m.checkAchievements().map((a) => a.id).toSet(), {'momo_clear'});
    expect(m.asmrOpen('momo_3'), isTrue);
    m.clearedMachine('tenbai'); // げきむず
    expect(m.checkAchievements().map((a) => a.id).toSet(), {'hard_clear', 'tenbai'});
    expect(m.asmrOpen('momo_1'), isFalse);
  });
}
