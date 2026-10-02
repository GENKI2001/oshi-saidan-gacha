// Figure definitions and the effect grammar (spec 02 §4.2).
// Effects are plain data; run.dart interprets them. Descriptions are
// generated from the data so mass-produced figures never drift from text.

enum Rarity { normal, rare, epic, legend, curse }

extension RarityInfo on Rarity {
  String get label => const ['ノーマル', 'レア', 'エピック', 'レジェンド', 'のろい'][index];
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
  String describe() => v >= 0 ? '毎回 +$v' : '毎回 $v';
}

/// 角にいると +v
class AddIfCorner extends Effect {
  final int v;
  const AddIfCorner(this.v);
  @override
  String describe() => '角にいると さらに +$v';
}

/// 隣の空きマス1つにつき +v
class AddPerEmptyAdjacent extends Effect {
  final int v;
  const AddPerEmptyAdjacent(this.v);
  @override
  String describe() => 'となりの空きマス1つにつき +$v';
}

/// 棚の [tag] 1体につき +v（自分も含む）
class AddPerShelfTag extends Effect {
  final String tag;
  final int v;
  const AddPerShelfTag(this.tag, this.v);
  @override
  String describe() => '棚の「$tag」1体につき +$v';
}

/// 棚に [tag] が n体以上なら +v
class AddIfShelfTag extends Effect {
  final String tag;
  final int n, v;
  const AddIfShelfTag(this.tag, this.n, this.v);
  @override
  String describe() => '棚に「$tag」が$n体以上なら さらに +$v';
}

/// 隣に [id] がいれば +v
class AddIfAdjacentId extends Effect {
  final String id, name;
  final int v;
  const AddIfAdjacentId(this.id, this.name, this.v);
  @override
  String describe() => 'となりに$nameがいると さらに +$v';
}

/// 置いてからの回転数 × v（育つ）
class Grow extends Effect {
  final int v;
  const Grow(this.v);
  @override
  String describe() => '毎回 +$v ずつ育つ（最初は0）';
}

/// n回転ごとに +v
class EveryN extends Effect {
  final int n, v;
  const EveryN(this.n, this.v);
  @override
  String describe() => '$n回転ごとに +$v';
}

/// 同じ段の他の駒すべてに +v
class BuffRow extends Effect {
  final int v;
  const BuffRow(this.v);
  @override
  String describe() => '同じ段のほかの駒 すべて +$v';
}

/// 隣でいちばん稼いだ駒と同じだけ稼ぐ
class CopyBestAdjacent extends Effect {
  const CopyBestAdjacent();
  @override
  String describe() => 'となりで一番かせいだ駒と同じだけかせぐ';
}

/// 隣の [tag] を ×f
class MultAdjacentTag extends Effect {
  final String tag;
  final int f;
  const MultAdjacentTag(this.tag, this.f);
  @override
  String describe() => 'となりの「$tag」を ×$f';
}

/// 棚の全駒を ×f
class MultAll extends Effect {
  final int f;
  const MultAll(this.f);
  @override
  String describe() => '棚の全部の駒を ×$f';
}

/// n回転目に棚の全駒を ×f して消える
class Fuse extends Effect {
  final int n, f;
  const Fuse(this.n, this.f);
  @override
  String describe() => '$n回転目に打ち上がり、棚の全部を ×$f（消える）';
}

/// n回転で消える
class Lifetime extends Effect {
  final int n;
  const Lifetime(this.n);
  @override
  String describe() => '$n回転で割れて消える';
}

/// 毎回となりの駒を1体撃ち落とし、その稼ぎの ×m をもらう（のろいを優先）
class ShootAdjacent extends Effect {
  final int m;
  const ShootAdjacent(this.m);
  @override
  String describe() => '毎回 右どなりの駒を撃ち落とし、その稼ぎの×$mをもらう';
}

/// n回転ごとに空きマスへ駒を生む
class SpawnEveryN extends Effect {
  final int n;
  const SpawnEveryN(this.n);
  @override
  String describe() => '$n回転ごとに 空きマスへ駒をひとつ生む';
}

/// 置いた時、隣の [tag] を全部すくって1体につき +v
class OnPlacedEatAdjacentTag extends Effect {
  final String tag;
  final int v;
  const OnPlacedEatAdjacentTag(this.tag, this.v);
  @override
  String describe() => '置いた時、となりの「$tag」を全部すくって 1体につき +$v';
}

/// 置いた時、レア以上の駒を n体生んで割れる
class OnPlacedSpawnRare extends Effect {
  final int n;
  const OnPlacedSpawnRare(this.n);
  @override
  String describe() => '置いた時、レア以上の駒を$n体生んで割れる';
}

/// 取り立ての時 +v
class OnPaydayGain extends Effect {
  final int v;
  const OnPaydayGain(this.v);
  @override
  String describe() => '取り立ての時 +$v';
}

/// 取り立て額を pct% 減らす
class PaydayDiscount extends Effect {
  final int pct;
  const PaydayDiscount(this.pct);
  @override
  String describe() => '取り立て額を $pct% へらす';
}

/// 棚にいる間、レアの出やすさ +v%
class Luck extends Effect {
  final int v;
  const Luck(this.v);
  @override
  String describe() => '棚にいる間 レア以上が出やすい（+$v%）';
}

/// どけた時 +v
class OnRemovedGain extends Effect {
  final int v;
  const OnRemovedGain(this.v);
  @override
  String describe() => 'どけると +$v';
}

/// となりの [tag] 1体につき +v
class AddPerAdjacentTag extends Effect {
  final String tag;
  final int v;
  const AddPerAdjacentTag(this.tag, this.v);
  @override
  String describe() => 'となりの「$tag」1体につき +$v';
}

/// となりに駒がいないと +v
class AddIfAlone extends Effect {
  final int v;
  const AddIfAlone(this.v);
  @override
  String describe() => 'となりに誰もいないと さらに +$v';
}

/// 棚の駒 n体につき +v
class AddPerShelfFigures extends Effect {
  final int n, v;
  const AddPerShelfFigures(this.n, this.v);
  @override
  String describe() => '棚の駒$n体につき +$v';
}

/// 置いた時 +v（1回だけ）
class GainOnPlaced extends Effect {
  final int v;
  const GainOnPlaced(this.v);
  @override
  String describe() => '置いた時 +$v';
}

/// 最初 +v、毎回 1 ずつ減る（0 で止まる）
class Cooling extends Effect {
  final int v;
  const Cooling(this.v);
  @override
  String describe() => 'できたては +$v、毎回 1 ずつ冷める';
}

/// 同じ列の他の駒すべてに +v
class BuffColumn extends Effect {
  final int v;
  const BuffColumn(this.v);
  @override
  String describe() => '同じ列のほかの駒 すべて +$v';
}

/// 毎回 lo〜hi のどれか
class RandomAdd extends Effect {
  final int lo, hi;
  const RandomAdd(this.lo, this.hi);
  @override
  String describe() => '毎回 +$lo〜+$hi のどれか';
}

/// 棚の [tag] をすべて ×f
class MultShelfTag extends Effect {
  final String tag;
  final int f;
  const MultShelfTag(this.tag, this.f);
  @override
  String describe() => '棚の「$tag」を全部 ×$f';
}

class FigureDef {
  final String id, name, emoji;
  final Rarity rarity;
  final List<String> tags;
  final List<Effect> effects;

  /// 縁日レベルがこの値になるとガチャから出るようになる
  final int level;
  const FigureDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rarity,
    required this.tags,
    required this.effects,
    this.level = 1,
  });

  T? effect<T extends Effect>() {
    for (final e in effects) {
      if (e is T) return e;
    }
    return null;
  }

  bool has<T extends Effect>() => effect<T>() != null;

  String get description => effects.map((e) => e.describe()).join('\n');
}
