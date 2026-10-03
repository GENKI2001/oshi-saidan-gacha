import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/achievements.dart';
import 'package:oshi_saidan/ui/meta.dart';

void main() {
  test('every whisper track is opened by exactly one achievement', () {
    for (final t in asmrTracks) {
      expect(achievements.where((a) => a.asmr == t.id).length, 1, reason: t.id);
    }
    expect(asmrTracks.length, 18);
  });

  test('achievements unlock once, from the records', () {
    final m = Meta();
    expect(m.checkAchievements(), isEmpty);
    m.runs = 1;
    expect(m.checkAchievements().map((a) => a.id), ['first_live']);
    expect(m.asmrOpen('tsumugi_1'), isTrue);
    expect(m.checkAchievements(), isEmpty, reason: 'not twice');
    for (var k = 0; k < 30; k++) {
      m.addPlaced('しずく');
    }
    m.noteAltar({'しずく': 6});
    final got = m.checkAchievements().map((a) => a.id).toSet();
    expect(got, {'shizuku_altar', 'shizuku_place'});
    m.clearedMachine('shizumomo');
    expect(m.checkAchievements().map((a) => a.id).toSet(), {'shizuku_clear', 'momo_clear'});
    expect(m.asmrOpen('momo_3'), isTrue);
    expect(m.asmrOpen('momo_1'), isFalse);
  });
}
