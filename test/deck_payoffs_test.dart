// The goods that used to multiply the whole altar now pay off for one kind of altar:
// 箱推し (all five members there), 単推し (nothing else there), enough ファン.
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/logic/defs.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/run.dart';

FigureDef _plain(String tag) => FigureDef(id: 'test_$tag', name: tag, emoji: '', rarity: Rarity.normal, tags: [tag], effects: const [Add(2)]);

Run _altar(List<String> tags, String payoff) {
  final r = Run(seed: 3)..coins = 0;
  for (var i = 0; i < r.size; i++) {
    r.cells[i] = null;
  }
  for (final (k, t) in tags.indexed) {
    r.place(_plain(t), k);
  }
  r.place(figureById[payoff]!, r.size - 1);
  return r;
}

void main() {
  test('箱推し: the life-size panel triples the altar only with all five members on it', () {
    expect(_altar(['ひなた', 'しずく', 'こはる', 'よる', 'もも'], 'unit_panel').endTurn().total, 10 * 3);
    expect(_altar(['ひなた', 'しずく', 'こはる', 'よる'], 'unit_panel').endTurn().total, 8);
  });

  test('単推し: the golden dress ×4 only when every goods is ひなた', () {
    expect(_altar(['ひなた', 'ひなた', 'ひなた'], 'hinata_dress').endTurn().total, 6 * 4);
    expect(_altar(['ひなた', 'ひなた', 'もも'], 'hinata_dress').endTurn().total, 6);
  });

  test('the dome live ×3 when the altar is only ひなた and もも', () {
    expect(_altar(['ひなた', 'もも', 'もも'], 'hinamomo_dome').endTurn().total, 6 * 3);
    expect(_altar(['ひなた', 'もも', 'よる'], 'hinamomo_dome').endTurn().total, 6);
  });

  test('the fan meeting ×3 on the ファン once there are 6 of them', () {
    // the fan meeting goods is a ファン itself: 5 more make 6
    expect(_altar(['ファン', 'ファン', 'ファン', 'ファン', 'ファン'], 'hinata_fanmeet').endTurn().total, 10 * 3);
    expect(_altar(['ファン', 'ファン', 'ファン', 'ファン'], 'hinata_fanmeet').endTurn().total, 8);
  });

  test('the cooking stream earns more for every こはる on the altar', () {
    final few = _altar(['こはる'], 'hinakoha_stream').endTurn().total;
    final many = _altar(['こはる', 'こはる', 'こはる', 'こはる'], 'hinakoha_stream').endTurn().total;
    expect(few, 2 + 3 + 5);
    expect(many, 8 + 3 + 20);
  });

  test('they count toward the 4 on the altar', () {
    for (final id in ['unit_panel', 'hinata_dress', 'hinamomo_dome', 'hinata_fanmeet', 'yoru_tape', 'shizuyoru_candle']) {
      expect(Run.isShelfMult(figureById[id]!), isTrue, reason: id);
    }
    expect(Run.isShelfMult(figureById['hinakoha_stream']!), isFalse);
  });
}
