// Sheets and dialogs: a goods' details, writing over / stacking, the ad rewards, the menu.

part of '../game_screen.dart';

extension on _GameScreenState {
  Future<void> _info(FigureDef d, [Fig? f]) => showFigureInfo(context, d, f, g.run);

  /// Shows what would be lost before writing over it.
  void _confirmOverwrite(int i) {
    // the same goods: it is stacked and powers up instead of being replaced
    if (g.run.stacksOn(g.pending.first, i)) {
      // now (as it is on the altar) → after one more stack, the numbers that grow in colour
      final now = g.shown[i]?.stack ?? 1;
      _confirmPair(
        '重ねて 強化しますか？',
        g.shown[i]?.def,
        g.shown[i]?.def,
        Icons.arrow_forward_rounded,
        '強化する',
        C.gold,
        () => g.tapCell(i),
        leftDesc: _stackedDesc(g.pending.first, now, hot: false),
        rightDesc: _stackedDesc(g.pending.first, now + 1),
      );
      return;
    }
    _confirmPair(
      'これに 上書きしますか？',
      g.pending.first,
      g.shown[i]?.def,
      Icons.arrow_forward_rounded,
      '上書きする',
      C.pink,
      () => g.tapCell(i),
      rightNote: 'このグッズは なくなります',
    );
  }

  /// [d]'s effects once stacked ×[stack], the numbers that change in colour.
  /// Only what stacking really multiplies changes (hearts, buffs, multipliers; not luck or one-off gains).
  Widget _stackedDesc(FigureDef d, int stack, {bool hot = true}) {
    final spans = <TextSpan>[];
    const plain = TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w700, color: C.ink);
    for (final (k, e) in d.effects.indexed) {
      if (k > 0) spans.add(const TextSpan(text: '\n'));
      final text = e.describe();
      final stacks = switch (e) {
        Luck() || GainOnPlaced() || OnPaydayGain() || PaydayDiscount() || OnPlacedEatAdjacentTag() || OnPlacedSpawnRare() || SpawnEveryN() || ShootAdjacent() || CopyBestAdjacent() || Lifetime() => false,
        _ => true,
      };
      if (!stacks) {
        spans.add(TextSpan(text: text));
        continue;
      }
      var at = 0;
      for (final m in RegExp(r'([+×-])(\d+)').allMatches(text)) {
        spans.add(TextSpan(text: text.substring(at, m.start)));
        final v = int.parse(m.group(2)!);
        final now = v * stack;
        spans.add(TextSpan(text: '${m.group(1)}$now', style: _hotStyle(hot)));
        at = m.end;
      }
      spans.add(TextSpan(text: text.substring(at)));
    }
    return Text.rich(TextSpan(style: plain, children: spans), textAlign: TextAlign.center);
  }

  TextStyle? _hotStyle(bool on) => on ? const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w900, color: Color(0xFFE5408A)) : null;

  /// Two figures side by side with their effects, and a yes / no.
  void _confirmPair(String title, FigureDef? left, FigureDef? right, IconData arrow, String yes, Color color, VoidCallback onYes, {String? rightNote, Widget? leftDesc, Widget? rightDesc}) {
    Sfx.play('tap');
    Widget side(FigureDef? d, [String? note, Widget? desc]) => Expanded(
      child: Column(
        children: [
          d == null ? const SizedBox(width: 64, height: 64, child: Icon(Icons.crop_square_rounded, size: 48, color: C.woodDark)) : FigureArt(d, size: 64),
          Text(
            d?.name ?? '空きマス',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.ink),
          ),
          // rarity and types, so you can see what the other figures will make of it
          if (d != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [RarityStars(d.rarity, size: 15), for (final t in d.tags) TagChip(t, size: 11)],
              ),
            ),
          if (desc != null)
            desc
          else if (d != null)
            Text(
              d.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w700, color: C.ink),
            ),
          if (note != null)
            Text(
              note,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.red),
            ),
        ],
      ),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(14),
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: outlined(20, color, stroke: C.ink, width: 3)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  side(left, null, leftDesc),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Icon(arrow, size: 36, color: color),
                  ),
                  side(right, rightNote, rightDesc),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PopButton('やめる', fontSize: 16, color: Colors.blueGrey, onTap: () => Navigator.of(ctx).pop()),
                  const SizedBox(width: 12),
                  PopButton(
                    yes,
                    fontSize: 18,
                    color: color,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onYes();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick what to get for watching an ad.
  void _adSheet() {
    Sfx.play('tap');
    Widget option(AdReward r, Widget icon, String title, String sub) => GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        g.watchAd(r);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.woodDark, width: 2.5),
        ),
        child: Row(
          children: [
            SizedBox(width: 52, height: 52, child: icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.ink),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.woodDark),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: C.mint, size: 34),
          ],
        ),
      ),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(14),
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('広告を見て どれかひとつ', style: outlined(22, C.mint, stroke: C.ink, width: 3)),
              const Text(
                '1曲ごとに1回まで',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.ink),
              ),
              const SizedBox(height: 10),
              option(AdReward.coins, const HeartIcon(size: 52), 'ハート +${g.adCoins}', 'すぐにもらえる'),
              option(AdReward.repull, const Icon(Icons.replay_rounded, size: 44, color: C.pink), 'もう一回ひく 復活', '曲の終わりを待たずに 満タンにもどる'),
              option(AdReward.luck, FigureArt(figureById['gacha_charm']!, size: 52), '運 +5%', 'Rが出やすくなる'),
            ],
          ),
        ),
      ),
    );
  }

  /// In-run menu: resume, sound, or quit to the title.
  void _menu() {
    Sfx.play('tap');
    final m = widget.meta;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('メニュー', style: outlined(26, C.pink, stroke: C.ink, width: 3)),
              const SizedBox(height: 8),
              // sound settings as icons, like on the title
              SoundToggles(m),
              const SizedBox(height: 14),
              for (final b in [
                PopButton('つづける', fontSize: 22, onTap: () => Navigator.of(ctx).pop()),
                PopButton(
                  'あそびかた',
                  fontSize: 18,
                  color: C.gold,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HowToScreen(meta: m)));
                  },
                ),
                // ends the run right away and shows the result
                PopButton(
                  'あきらめる',
                  fontSize: 18,
                  color: C.red,
                  onTap: g.canGiveUp
                      ? () {
                          Navigator.of(ctx).pop();
                          g.giveUp();
                        }
                      : null,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(width: 240, child: b),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
