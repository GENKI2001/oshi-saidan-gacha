// The capsule dropping, wobbling and opening on what came out.

part of '../game_screen.dart';

extension on _GameScreenState {
  Widget _capsules() {
    final opts = g.options;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: g.phase == Phase.capsule ? g.openCapsule : null,
        // a tall goods (a long effect, the idol's bubble, two buttons) shrinks to fit rather than overflow
        child: LayoutBuilder(
          builder: (_, bc) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: bc.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (g.phase == Phase.capsule) Text(g.omen ? 'な、なんか光ってる…！' : 'タップしてあける！', style: outlined(24, Colors.white)),
                    if (g.phase == Phase.reveal && g.idol != null && g.idolOnPull)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: IdolToast(who: g.idol!, line: g.idolLine, token: g.idolToken, fade: false),
                      ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final o in opts) _capsuleSlot(o, opts.length)]),
                    if (g.phase == Phase.reveal) ...[
                      const SizedBox(height: 14),
                      _revealButton(
                        PopButton(
                          key: _kRepull,
                          _uses('もう一回ひく', g.run.repulls, g.run.repullMax),
                          color: const Color(0xFF8E7CC3),
                          sound: null,
                          onTap: g.run.repulls > 0 ? g.repull : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _capsuleSlot(FigureDef o, int n) {
    final size = n == 1 ? 130.0 : 96.0;
    if (g.phase == Phase.dropping) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.bounceOut,
        builder: (_, t, c) => Transform.translate(offset: Offset(0, -320 * (1 - t)), child: c),
        child: Capsule(rarity: o.rarity, size: size),
      );
    }
    if (g.phase == Phase.capsule) {
      return Wobble(
        strength: 0.05 + o.rarity.index * 0.04,
        child: Capsule(rarity: o.rarity, size: size),
      );
    }
    // reveal
    final col = C.rarity(o.rarity);
    final art = n == 1 ? 200.0 : 140.0;
    return GestureDetector(
      onTap: () => g.choose(o),
      child: SizedBox(
        width: n == 1 ? 340 : 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              key: _kItem,
              alignment: Alignment.center,
              children: [
                Sunburst(color: col, size: art * 1.7),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  builder: (_, t, _) => Capsule(rarity: o.rarity, size: size, split: t),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: o.rarity.index >= Rarity.epic.index ? 900 : 600),
                  curve: Curves.elasticOut,
                  builder: (_, t, c) => Transform.scale(scale: t, child: c),
                  child: FigureArt(o, size: art),
                ),
                Sparkles(token: g.flashToken * 31 + o.hashCode, size: art * 1.8, colors: [col, Colors.white, C.gold, C.pink]),
                if (g.fresh.contains(o.id))
                  Positioned(
                    top: art * 0.05,
                    right: n == 1 ? 40 : 0,
                    child: NewSticker(size: n == 1 ? 76 : 58),
                  ),
              ],
            ),
            Text(o.name, style: outlined(n == 1 ? 30 : 22, Colors.white)),
            // rarity and types side by side
            Padding(
              key: _kTags,
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [RarityStars(o.rarity, size: 22), for (final t in o.tags) TagChip(t)],
              ),
            ),
            const SizedBox(height: 8),
            Panel(
              key: _kEffect,
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(
                    o.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.4, color: C.ink, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _revealButton(PopButton(key: _kPlace, n == 1 ? '祭壇に置く' : 'これにする', onTap: () => g.choose(o))),
          ],
        ),
      ),
    );
  }

  /// The two buttons under a revealed capsule share one width.
  Widget _revealButton(Widget b) => SizedBox(width: 260, child: b);
}
