// Sheets and dialogs: a goods' details, writing over / stacking, the ad rewards, the menu.

part of '../game_screen.dart';

extension on _GameScreenState {
  /// The machine's 中身: what can drop now and how likely each one is, each ★ in its own colour.
  void _lineup() {
    Sfx.play('tap');
    final r = g.run;
    final list = r.lineup();
    String pct(double p) => p >= 0.1 ? '${(p * 100).toStringAsFixed(0)}%' : (p >= 0.01 ? '${(p * 100).toStringAsFixed(1)}%' : '${(p * 100).toStringAsFixed(2)}%');
    final later = figures.where((f) => !(r.rules.open?.contains(f.id) ?? true)).length;
    const rarities = [Rarity.legend, Rarity.epic, Rarity.rare, Rarity.normal];
    Color tint(Rarity x) => RarityStars.colors[x.index];
    final luck = r.luck + r.paydaysPaid * Run.paydayLuck;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: StickerText(en ? "What's in ${g.machine.name}" : '${g.machine.name}の中身', size: 22)),
                const SizedBox(height: 6),
                // each rarity's share in all
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final rar in rarities)
                      if (list.any((e) => e.def.rarity == rar))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RarityStars(rar, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              pct(list.where((e) => e.def.rarity == rar).fold(0.0, (a, e) => a + e.p)),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.ink),
                            ),
                          ],
                        ),
                  ],
                ),
                if (luck > 0 || r.rareSong || r.idolSong != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (luck > 0) en ? 'incl. luck +$luck%' : '運 +$luck% こみ',
                        if (r.rareSong) tr('この曲は ★2以上だけ'),
                        if (r.idolSong != null) en ? 'This song: only ${tr(r.idolSong!)} goods' : 'この曲は「${r.idolSong}」のグッズだけ',
                      ].join('　'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.woodDark),
                    ),
                  ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final rar in rarities)
                        for (final e in list.where((e) => e.def.rarity == rar).toList()..sort((a, b) => b.p.compareTo(a.p)))
                          // each rarity in its star's colour, so the rare ones stand out
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color.lerp(tint(rar), Colors.white, 0.72),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tint(rar), width: 2),
                            ),
                            child: Row(
                              children: [
                                FigureArt(e.def, size: 34),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(e.def.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.ink)),
                                ),
                                RarityStars(rar, size: 12),
                                SizedBox(
                                  width: 58,
                                  child: Text(
                                    pct(e.p),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color.lerp(tint(rar), C.ink, 0.45)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                if (later > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      en ? 'Clear other gachas to add $later more' : 'ほかのガチャを クリアすると あと $later 種 入るよ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.woodDark),
                    ),
                  ),
                const SizedBox(height: 8),
                PopButton('とじる', fontSize: 16, color: Colors.blueGrey, filled: false, onTap: () => Navigator.of(ctx).pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            d?.name ?? tr('空きマス'),
            textAlign: TextAlign.center,
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
              tr(note),
              textAlign: TextAlign.center,
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
              FittedBox(fit: BoxFit.scaleDown, child: Text(tr(title), style: outlined(20, color, stroke: C.ink, width: 3))),
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
                  PopButton('やめる', fontSize: 16, color: Colors.blueGrey, filled: false, onTap: () => Navigator.of(ctx).pop()),
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
                    tr(title),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.ink),
                  ),
                  Text(
                    tr(sub),
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
              FittedBox(fit: BoxFit.scaleDown, child: Text(tr('広告を見て どれかひとつ'), style: outlined(22, C.mint, stroke: C.ink, width: 3))),
              Text(
                tr('1曲ごとに1回まで'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.ink),
              ),
              const SizedBox(height: 10),
              option(AdReward.coins, const HeartIcon(size: 52), en ? 'Hearts +${g.adCoins}' : 'ハート +${g.adCoins}', 'すぐにもらえる'),
              option(AdReward.repull, const Icon(Icons.replay_rounded, size: 44, color: C.pink), 'もう一回ひく 復活', '曲の終わりを待たずに 満タンにもどる'),
              option(AdReward.luck, FigureArt(figureById['gacha_charm']!, size: 52), en ? 'Luck +5%' : '運 +5%', 'Rが出やすくなる'),
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
              Text(tr('メニュー'), style: outlined(26, C.pink, stroke: Colors.white, width: 3)),
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
                  'おわる',
                  fontSize: 18,
                  color: Colors.blueGrey,
                  filled: false,
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
