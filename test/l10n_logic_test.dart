// In English, nothing from lib/logic shows Japanese: goods, effects, gachas, achievements, the stall and the 妨害.
import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_saidan/l10n/l10n.dart';
import 'package:oshi_saidan/logic/achievements.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';

final _ja = RegExp(r'[ぁ-んァ-ヶ一-龥「」、。！？]');

void main() {
  setUp(() => en = true);
  tearDown(() => en = false);

  void english(String what, String text) => expect(_ja.hasMatch(text), isFalse, reason: '$what: "$text"');

  test('goods: names, tags and effects', () {
    for (final f in figures) {
      english(f.id, f.name);
      english('${f.id} effects', f.description);
      for (final t in f.tags) {
        english('${f.id} tag', tr(t));
      }
    }
  });

  test('gachas', () {
    for (final m in machines) {
      english(m.id, m.name);
      english('${m.id} blurb', m.blurb);
      english('${m.id} difficulty', m.difficultyText);
      english('${m.id} unlock', m.unlockText);
      for (final p in m.perks) {
        english('${m.id} perk', p);
      }
    }
  });

  test('achievements', () {
    for (final a in achievements) {
      english(a.id, a.title);
      english('${a.id} text', a.text);
    }
  });

  test('the stall and the scalper', () {
    for (final k in OfferKind.values) {
      final o = Offer(k, 1, k == OfferKind.figure ? figures.first : null, 'ひなた');
      english('$k', o.title);
      english('$k text', o.text);
    }
    for (final k in JamKind.values) {
      for (final r in JamReward.values) {
        final j = Jam(k, 1, pct: 30, reward: r, gift: figures.first);
        english('$k', j.text);
        english('$r', j.rewardText);
      }
    }
  });

  test('Japanese is unchanged when en is off', () {
    en = false;
    expect(figureById['coin']!.name, 'ハートのメダル');
    expect(machines.first.name, 'ぷりパレガチャ');
    expect(achievements.first.title, 'はじめてのライブ');
  });
}
