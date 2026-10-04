// The cards over the altar: the end of a song, the quota missed, the live cleared, the
// merch booth and the result.

part of '../game_screen.dart';

extension on _GameScreenState {
  /// The live was a success: the five celebrating on stage fill the screen (fading in, slowly
  /// zooming), so a cleared live looks different at a glance.
  Widget _clearBg() {
    final screen = MediaQuery.sizeOf(context);
    return Positioned(
      left: -600,
      right: -600,
      top: -200,
      bottom: -200,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 4000),
          builder: (_, t, _) => Opacity(
            opacity: (t * 4).clamp(0.0, 1.0),
            child: ColoredBox(
              color: const Color(0xFF2A1238),
              child: Center(
                child: SizedBox(
                  width: screen.width,
                  height: screen.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(scale: 1.08 - 0.08 * Curves.easeOut.transform(t), child: Image.asset('assets/ui/clear_bg.jpg', fit: BoxFit.cover)),
                      // a light veil so the card on top still reads
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x55120820), Color(0x55120820), Color(0x22000000)],
                            stops: [0, 0.35, 0.8, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bossCard({required Widget body, String? ribbon}) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (_, s, c) => Transform.scale(scale: s, child: c),
        child: Panel(
          ribbon: ribbon,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Bounce(token: g.bossToken, amount: 0.1, child: Image.asset('assets/ui/boss_${g.bossMood}.png', height: 170)),
              Text(
                g.bossLine,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: C.ink, fontWeight: FontWeight.w800, height: 1.4),
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    ),
  );

  Widget _payday() {
    final r = g.run;
    final song = r.paydaysPaid + 1;
    final who = g.songIdol;
    // short of the quota: つむぎ's card with the gauge; met: the curtain call (below)
    if (who == null) {
      return _bossCard(
        ribbon: '♪ $song曲目 おわり！',
        body: Column(
          children: [
            SizedBox(width: 260, child: QuotaFill(key: ValueKey('quota-${r.paydaysPaid}'), hearts: r.coins, quota: r.due)),
            const SizedBox(height: 10),
            _wide(PopButton('ハートを届ける！', onTap: g.pay, fontSize: 22)),
          ],
        ),
      );
    }
    // the song was a success: one card — the idol in the middle with her line, the gauge past the quota
    final col = idolColor[who]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, t, c) => Transform.scale(scale: 0.5 + 0.5 * t, child: c),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Sparkles(token: g.burstToken, size: 420, colors: [C.gold, C.pink, col, Colors.white], count: 50),
              Panel(
                ribbon: '♪ $song曲目 大成功！',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(portrait(who, happy: true), height: 210, fit: BoxFit.contain, alignment: Alignment.topCenter),
                    Container(
                      width: 270,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: col, width: 3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(who, style: outlined(14, col, stroke: Colors.white, width: 3)),
                          Text(g.songLine, style: const TextStyle(fontSize: 15, height: 1.35, color: C.ink, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: 260, child: QuotaFill(key: ValueKey('quota-${r.paydaysPaid}'), hearts: r.coins, quota: r.due)),
                    const SizedBox(height: 10),
                    _wide(PopButton('ハートを届ける！', onTap: g.pay, fontSize: 22)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _failed() {
    final p = g.payday!;
    final short = p.due - (p.coinsBefore + p.bonus);
    return _bossCard(
      ribbon: 'ノルマ未達成…',
      body: Column(
        children: [
          Text('ハートが あと $short 足りない…', style: outlined(22, C.red, stroke: Colors.white)),
          const SizedBox(height: 12),
          if (kAdsEnabled && g.run.canPostpone) _wide(PopButton('▶ 広告を見て延長！', onTap: g.watchAdToPostpone, color: C.mint, fontSize: 17)),
          const SizedBox(height: 10),
          _wide(PopButton('おわる', onTap: g.giveUp, color: Colors.blueGrey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _cleared() => Stack(
    alignment: Alignment.center,
    children: [
      Sparkles(token: 777, size: 460, colors: const [C.gold, C.pink, C.mint, Colors.white], count: 60),
      _bossCard(
        ribbon: 'ライブ大成功！',
        body: Column(
          children: [
            Image.asset('assets/ui/ui_medal.png', height: 90),
            const SizedBox(height: 8),
            _wide(PopButton('アンコールへ！', onTap: g.keepGoing)),
            const SizedBox(height: 10),
            _wide(PopButton('おわる', onTap: g.giveUp, color: Colors.blueGrey, fontSize: 16)),
          ],
        ),
      ),
    ],
  );

  Widget _shop() {
    final r = g.run;
    return Center(
      // scrolls when revivals add extra items
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 58, 14, 14),
        child: Panel(
          ribbon: 'つむぎの物販ブース',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r.shopBuys == 0) Text('最初の1品は タダ！', style: outlined(16, C.pink, stroke: Colors.white, width: 3)),
              const SizedBox(height: 10),
              Column(children: [for (final o in r.shop) _offer(o)]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  PopButton(
                    _uses('品がえ', r.rerolls, r.rerollMax),
                    onTap: r.rerolls > 0 ? g.reroll : null,
                    color: const Color(0xFF8E7CC3),
                    fontSize: 16,
                  ),
                  PopButton('つぎの曲へ ♪', onTap: g.leaveShop, color: C.pink, fontSize: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offer(Offer o) {
    final can = !o.sold && g.run.coins >= g.run.priceOf(o) && g.run.canBuy(o);
    final icon = switch (o.kind) {
      OfferKind.figure => FigureArt(o.fig!, size: 60),
      OfferKind.luck => FigureArt(figureById['gacha_charm']!, size: 60),
      OfferKind.boost => SizedBox(width: 60, child: Center(child: IdolFace(o.idol!, size: 52))),
      OfferKind.repullTicket => const SizedBox(width: 60, child: Icon(Icons.replay_rounded, size: 46, color: Color(0xFF8E7CC3))),
      OfferKind.rerollTicket => const SizedBox(width: 60, child: Icon(Icons.shuffle_rounded, size: 44, color: C.woodDark)),
      OfferKind.expand => const SizedBox(width: 60, child: Icon(Icons.grid_view_rounded, size: 44, color: C.woodDark)),
      OfferKind.extraSpin => const SizedBox(width: 60, child: Icon(Icons.more_time_rounded, size: 46, color: Color(0xFFE6A700))),
      OfferKind.rareSong => const SizedBox(width: 60, child: Icon(Icons.auto_awesome_rounded, size: 46, color: Color(0xFFE6A700))),
      OfferKind.idolSong => SizedBox(width: 60, child: Center(child: IdolFace(o.idol!, size: 52))),
    };
    final card = Container(
      padding: const EdgeInsets.all(8),
      // a レア商品 shines gold
      decoration: BoxDecoration(
        color: o.rare ? const Color(0xFFFFF8DC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: o.rare ? const Color(0xFFE6A700) : (o.fig != null ? C.rarity(o.fig!.rarity) : C.woodDark), width: o.rare ? 3.5 : 2.5),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: C.ink),
                ),
                Text(o.text, style: const TextStyle(fontSize: 12, height: 1.3, color: C.ink)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopButton(
            o.sold ? '売切' : (g.run.priceOf(o) == 0 ? 'タダ' : '${g.run.priceOf(o)}'),
            onTap: can ? () => g.buy(o) : null,
            color: C.gold,
            fontSize: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ],
      ),
    );
    // a レア商品 sparkles on the shelf itself
    return Opacity(
      opacity: o.sold ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: o.rare && !o.sold ? RareShine(token: g.rareToken, child: card) : card,
      ),
    );
  }

  Widget _over() {
    final r = g.run;
    // everything on the result card spans the card
    Widget wide(Widget b) => SizedBox(width: double.infinity, child: b);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SizedBox(
          width: _shelfW,
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.cleared ? 'ライブ成功！' : 'ライブ終了', style: outlined(36, C.pink, stroke: Colors.white, width: 5)),
                // つむぎ sums the run up
                wide(
                  Row(
                    children: [
                      Image.asset('assets/ui/boss_${r.cleared ? 1 : 0}.png', height: 76),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: C.ink, width: 2),
                          ),
                          child: Text(
                            g.overLine,
                            style: const TextStyle(fontSize: 13, height: 1.35, color: C.ink, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // the three records side by side, as wide as the buttons
                wide(
                  Row(
                    children: [
                      _stat('成功した曲', '${r.paydaysPaid}/${Run.clearPaydays}'),
                      _stat('一回の最高', '${r.bestTurn}'),
                      _stat('図鑑', '${widget.meta.seen.length}/${figures.length}'),
                    ],
                  ),
                ),
                if (g.newRecord) Text('自己ベスト更新！', style: outlined(20, C.gold)),
                if (g.turnRank != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, t, c) => Transform.scale(scale: t, child: c),
                    child: Text('最高ハート 全国 ${g.turnRank} 位！', style: outlined(24, C.pink, stroke: Colors.white, width: 4)),
                  ),
                const SizedBox(height: 10),
                Text(
                  'このライブで集めたハート ${r.earned}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.ink),
                ),
                const SizedBox(height: 14),
                wide(PopButton('もう一回！', onTap: g.newRun, fontSize: 24)),
                const SizedBox(height: 10),
                wide(
                  PopButton(
                    'ランキング',
                    fontSize: 16,
                    color: C.gold,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RankScreen(meta: widget.meta),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                wide(PopButton('ガチャ選択へ', onTap: _toSelect, color: Colors.blueGrey, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One record: a small caption over the number.
  Widget _stat(String k, String v) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: C.ink, fontWeight: FontWeight.w800),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(v, style: outlined(22, C.gold, width: 3)),
        ),
      ],
    ),
  );

  /// Stacked buttons on the result cards all share one width.
  Widget _wide(Widget b) => SizedBox(width: 250, child: b);
}
