// Figure definitions and the effect grammar (spec 02 §4.2).
// Effects are plain data; run.dart interprets them. Descriptions are
// generated from the data so mass-produced figures never drift from text.

import '../l10n/l10n.dart';

enum Rarity { normal, rare, epic, legend }

extension RarityInfo on Rarity {
  String get label => const ['★1', '★2', '★3', '★4'][index];
}

sealed class Effect {
  const Effect();
  String describe();
}

/// 毎回 +v
class Add extends Effect {
  final int v;
  const Add(this.v);
  @override
  String describe() => en ? (v >= 0 ? '+$v every spin' : '$v every spin') : (v >= 0 ? '毎回 +$v' : '毎回 $v');
}

/// 角にいると +v
class AddIfCorner extends Effect {
  final int v;
  const AddIfCorner(this.v);
  @override
  String describe() => en ? '+$v more in a corner' : '角にいると さらに +$v';
}

/// 隣の空きマス1つにつき +v
class AddPerEmptyAdjacent extends Effect {
  final int v;
  const AddPerEmptyAdjacent(this.v);
  @override
  String describe() => en ? '+$v per empty cell next to it' : 'となりの空きマス1つにつき +$v';
}

/// 棚の [tag] 1体につき +v（自分も含む）
class AddPerShelfTag extends Effect {
  final String tag;
  final int v;
  const AddPerShelfTag(this.tag, this.v);
  @override
  String describe() => en ? '+$v per ${tr(tag)} on the altar' : '祭壇の「$tag」1つにつき +$v';
}

/// 棚に [tag] が n体以上なら +v
class AddIfShelfTag extends Effect {
  final String tag;
  final int n, v;
  const AddIfShelfTag(this.tag, this.n, this.v);
  @override
  String describe() => en ? '+$v more with $n+ ${tr(tag)} on the altar' : '祭壇に「$tag」が$n個以上なら さらに +$v';
}

/// 隣に [id] がいれば +v
class AddIfAdjacentId extends Effect {
  final String id, name;
  final int v;
  const AddIfAdjacentId(this.id, this.name, this.v);
  @override
  String describe() => en ? '+$v more next to ${tr(name)}' : 'となりに$nameがいると さらに +$v';
}

/// 置いてからの回転数 × v（育つ）
class Grow extends Effect {
  final int v;
  const Grow(this.v);
  @override
  String describe() => en ? 'Grows +$v every spin (starts at 0)' : '毎回 +$v ずつ育つ（最初は0）';
}

/// n回転ごとに +v
class EveryN extends Effect {
  final int n, v;
  const EveryN(this.n, this.v);
  @override
  String describe() => en ? '+$v every $n spins' : '$n回転ごとに +$v';
}

/// 同じ段の他の駒すべてに +v
class BuffRow extends Effect {
  final int v;
  const BuffRow(this.v);
  @override
  String describe() => en ? 'All other goods in its row +$v' : '同じ段のほかのグッズ すべて +$v';
}

/// 隣でいちばん稼いだ駒と同じだけ稼ぐ
class CopyBestAdjacent extends Effect {
  const CopyBestAdjacent();
  @override
  String describe() => en ? 'Earns as much as the best goods next to it' : 'となりで一番かせいだグッズと同じだけかせぐ';
}

/// 隣の [tag] を ×f
class MultAdjacentTag extends Effect {
  final String tag;
  final int f;
  const MultAdjacentTag(this.tag, this.f);
  @override
  String describe() => en ? '${tr(tag)} next to it ×$f' : 'となりの「$tag」を ×$f';
}

/// 箱推し: 祭壇に5人全員のグッズがあれば、棚の全駒を ×f
class MultIfAllMembers extends Effect {
  final int f;
  const MultIfAllMembers(this.f);
  @override
  String describe() => en ? 'With goods of all 5 members on the altar, the whole altar ×$f' : '祭壇に5人全員のグッズがそろっていれば 祭壇の全部を ×$f';
}

/// 単推し: 棚の駒が全部 [tags] のどれかなら、棚の全駒を ×f
class MultIfOnly extends Effect {
  final List<String> tags;
  final int f;
  const MultIfOnly(this.tags, this.f);
  @override
  String describe() => en ? 'If every goods on the altar is ${tags.map(tr).join(' or ')}, all ×$f' : '祭壇のグッズが全部「${tags.join('」か「')}」なら 全部 ×$f';
}

/// n回転目に棚の [tags] の駒を ×f して消える
class Fuse extends Effect {
  final int n, f;
  final List<String> tags;
  const Fuse(this.n, this.f, this.tags);
  @override
  String describe() => en ? 'Spin $n: MAX hype! All ${tags.map(tr).join(' and ')} on the altar ×$f (then it\'s gone)' : '$n回転目に 盛り上がりMAX！ 祭壇の「${tags.join('」と「')}」を全部 ×$f（消える）';
}

/// n回転で消える
class Lifetime extends Effect {
  final int n;
  const Lifetime(this.n);
  @override
  String describe() => en ? 'Gone after $n spins (limited-time)' : '$n回転で 消える（期間限定）';
}

/// 毎回となりの駒を1体撃ち落とし、その稼ぎの ×m をもらう
class ShootAdjacent extends Effect {
  final int m;
  const ShootAdjacent(this.m);
  @override
  String describe() => en ? 'Each spin, sells the goods to its right for ×$m of its earnings' : '毎回 右どなりのグッズを売って、その稼ぎの×$mをもらう';
}

/// n回転ごとに空きマスへ駒を生む
class SpawnEveryN extends Effect {
  final int n;
  const SpawnEveryN(this.n);
  @override
  String describe() => en ? 'Every $n spins, puts a goods in an empty cell' : '$n回転ごとに 空きマスへグッズをひとつ出す';
}

/// 置いた時、隣の [tag] を全部すくって1体につき +v
class OnPlacedEatAdjacentTag extends Effect {
  final String tag;
  final int v;
  const OnPlacedEatAdjacentTag(this.tag, this.v);
  @override
  String describe() => en ? 'When placed, trades away every ${tr(tag)} next to it: +$v each' : '置いた時、となりの「$tag」を全部 交換に出して 1つにつき +$v';
}

/// 置いた時、レア以上の駒を n体生んで割れる
class OnPlacedSpawnRare extends Effect {
  final int n;
  const OnPlacedSpawnRare(this.n);
  @override
  String describe() => en ? 'When placed, turns into $n goods of ★2+' : '置いた時、R以上のグッズを$n個出して消える';
}

/// 曲の終わり（ノルマの時）に +v
class OnPaydayGain extends Effect {
  final int v;
  const OnPaydayGain(this.v);
  @override
  String describe() => en ? '+$v at the end of each song' : '曲の終わりに +$v';
}

/// ノルマを pct% 減らす
class PaydayDiscount extends Effect {
  final int pct;
  const PaydayDiscount(this.pct);
  @override
  String describe() => en ? 'Quota −$pct%' : 'ノルマを $pct% へらす';
}

/// 棚にいる間、レアの出やすさ +v%
class Luck extends Effect {
  final int v;
  const Luck(this.v);
  @override
  String describe() => en ? 'While on the altar, ★2+ comes more often (+$v%)' : '祭壇にある間 R以上が出やすい（+$v%）';
}

/// となりの [tag] 1体につき +v
class AddPerAdjacentTag extends Effect {
  final String tag;
  final int v;
  const AddPerAdjacentTag(this.tag, this.v);
  @override
  String describe() => en ? '+$v per ${tr(tag)} next to it' : 'となりの「$tag」1つにつき +$v';
}

/// となりに駒がいないと +v
class AddIfAlone extends Effect {
  final int v;
  const AddIfAlone(this.v);
  @override
  String describe() => en ? '+$v more with nothing next to it' : 'となりに何もないと さらに +$v';
}

/// 棚の駒 n体につき +v
class AddPerShelfFigures extends Effect {
  final int n, v;
  const AddPerShelfFigures(this.n, this.v);
  @override
  String describe() => en ? '+$v per $n goods on the altar' : '祭壇のグッズ$n個につき +$v';
}

/// 置いた時 +v（1回だけ）
class GainOnPlaced extends Effect {
  final int v;
  const GainOnPlaced(this.v);
  @override
  String describe() => en ? '+$v when placed' : '置いた時 +$v';
}

/// 最初 +v、毎回 1 ずつ減る（0 で止まる）
class Cooling extends Effect {
  final int v;
  const Cooling(this.v);
  @override
  String describe() => en ? '+$v fresh, cools by 1 every spin' : 'できたては +$v、毎回 1 ずつ冷める';
}

/// 同じ列の他の駒すべてに +v
class BuffColumn extends Effect {
  final int v;
  const BuffColumn(this.v);
  @override
  String describe() => en ? 'All other goods in its column +$v' : '同じ列のほかのグッズ すべて +$v';
}

/// 毎回 lo〜hi のどれか
class RandomAdd extends Effect {
  final int lo, hi;
  const RandomAdd(this.lo, this.hi);
  @override
  String describe() => en ? '+$lo to +$hi every spin' : '毎回 +$lo〜+$hi のどれか';
}

/// 棚に [tag] が n 個以上あれば、棚の [tag] をすべて ×f
class MultShelfTagIfCount extends Effect {
  final String tag;
  final int n, f;
  const MultShelfTagIfCount(this.tag, this.n, this.f);
  @override
  String describe() => en ? 'With $n+ ${tr(tag)} on the altar, all ${tr(tag)} ×$f' : '祭壇に「$tag」が$n個以上あれば「$tag」を全部 ×$f';
}

/// ななめの [tag] 1つにつき +v
class AddPerDiagonalTag extends Effect {
  final String tag;
  final int v;
  const AddPerDiagonalTag(this.tag, this.v);
  @override
  String describe() => en ? '+$v per ${tr(tag)} diagonal to it' : 'ななめの「$tag」1つにつき +$v';
}

/// ななめの駒1つにつき +v
class AddPerDiagonalFigures extends Effect {
  final int v;
  const AddPerDiagonalFigures(this.v);
  @override
  String describe() => en ? '+$v per goods diagonal to it' : 'ななめのグッズ1つにつき +$v';
}

/// 自分から右上へ、ななめ一直線の4マス（自分ふくむ）が全部うまっていると +v（ビンゴ）
class AddIfDiagonalFull extends Effect {
  final int v;
  const AddIfDiagonalFull(this.v);
  @override
  String describe() => en ? '+$v if the 4 cells running up-right from it (itself included) are all filled' : '自分から右上へ ななめ4マス（自分ふくむ）が全部うまっていると +$v';
}

/// ななめの駒すべてに +v
class BuffDiagonal extends Effect {
  final int v;
  const BuffDiagonal(this.v);
  @override
  String describe() => en ? 'All goods diagonal to it +$v' : 'ななめのグッズ すべて +$v';
}

/// ななめの駒を ×f
class MultDiagonal extends Effect {
  final int f;
  const MultDiagonal(this.f);
  @override
  String describe() => en ? 'Goods diagonal to it ×$f' : 'ななめのグッズを ×$f';
}

class FigureDef {
  final String id, emoji;

  /// The Japanese name (the key for its English, and what the voices and tools use).
  final String nameJa;
  String get name => tr(nameJa);
  final Rarity rarity;
  final List<String> tags;
  final List<Effect> effects;

  /// The machine whose first clear (完済) brings this into the gacha; null: in it from the start.
  final String? from;

  /// The idols who appear (and speak) when this comes out of a capsule.
  final List<String> cast;
  const FigureDef({
    required this.id,
    required String name,
    required this.emoji,
    required this.rarity,
    required this.tags,
    required this.effects,
    this.from,
    this.cast = const [],
  }) : nameJa = name;

  T? effect<T extends Effect>() {
    for (final e in effects) {
      if (e is T) return e;
    }
    return null;
  }

  bool has<T extends Effect>() => effect<T>() != null;

  String get description => effects.map((e) => e.describe()).join('\n');
}
