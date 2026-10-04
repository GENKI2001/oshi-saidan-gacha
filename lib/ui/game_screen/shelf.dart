// The altar: its cells, the numbers floating over them, countdowns.

part of '../game_screen.dart';

extension on _GameScreenState {
  // ── shelf ──
  Widget _shelf() {
    final r = g.run;
    final cols = r.cols, rows = g.shown.length ~/ cols;
    const c0 = defaultSide, r0 = defaultSide;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE1EF), Color(0xFFF0E2FF)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xFFC77BAA), offset: Offset(0, 6)),
              BoxShadow(color: Color(0x66FF6FA3), blurRadius: 22),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          ),
          // the frame's inside keeps the starting shape; the cells shrink to fit as the altar grows
          child: LayoutBuilder(
            builder: (_, bc) {
              final w = bc.maxWidth, h = w * r0 / c0;
              final cell = math.min(w / cols, h / rows);
              return SizedBox(
                width: w,
                height: h,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var y = 0; y < rows; y++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var x = 0; x < cols; x++)
                              SizedBox(
                                width: cell,
                                height: cell,
                                // numbers in the corner scale with the cell (shelves grow up to 5x5)
                                child: KeyedSubtree(
                                  key: _cellKey(y * cols + x),
                                  child: RepaintBoundary(child: _cell(y * cols + x, cell)),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // the altar's name tab
        Positioned(
          top: -13,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 1, 12, 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF8FBF), Color(0xFFC99BFF)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.ink, width: 2),
                ),
                child: Text('♡ 推し祭壇 ♡', style: outlined(12, Colors.white, stroke: C.ink, width: 2.5)),
              ),
            ),
          ),
        ),
        // the floating +N go on top of everything on the altar, the name tab included
        Positioned.fill(child: IgnorePointer(child: _floatLayer(cols, rows, c0, r0))),
      ],
    );
  }

  /// The floating +N / ×2 of every cell, laid over the whole altar (so the name tab can't cover them).
  /// Mirrors the grid's layout: 3 border + 8 padding, the cells centred in the fixed frame.
  Widget _floatLayer(int cols, int rows, int c0, int r0) => LayoutBuilder(
    builder: (_, bc) {
      const inset = 11.0;
      final w = bc.maxWidth - inset * 2, h = w * r0 / c0;
      final cell = math.min(w / cols, h / rows);
      final ox = inset + (w - cell * cols) / 2, oy = inset + (h - cell * rows) / 2;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // every child here is keyed: beams come and go and finished numbers drop out, and an
          // unkeyed list would hand each number its neighbour's place and replay its animation
          // light from a goods to the ones it buffs / multiplies
          if (g.beams.isNotEmpty)
            Positioned.fill(
              key: const ValueKey('beams'),
              child: BeamLayer(beams: g.beams, center: (i) => Offset(ox + (i % cols + 0.5) * cell, oy + (i ~/ cols + 0.5) * cell)),
            ),
          // a stacked goods' burst, over the neighbouring cells
          for (final e in g.powerUp.entries)
            Positioned(
              key: ValueKey('burst-${e.key}'),
              left: ox + (e.key % cols) * cell - cell * 0.6,
              top: oy + (e.key ~/ cols) * cell - cell * 0.6,
              child: PowerUpBurst(token: e.value, size: cell * 2.2, level: g.shown[e.key]?.stack ?? 2),
            ),
          // little hearts popping out of a goods as it earns
          for (final e in g.heartPop.entries)
            Positioned(
              key: ValueKey('hearts-${e.key}'),
              left: ox + (e.key % cols + 0.5) * cell - cell * 0.8,
              top: oy + (e.key ~/ cols + 0.5) * cell - cell * 0.8,
              child: HeartBurst(token: e.value, count: 6, size: cell * 1.6),
            ),
          for (final e in g.floats.entries)
            for (final fl in e.value)
              Positioned(
                key: ValueKey('float-${fl.id}'),
                left: ox + (e.key % cols) * cell,
                top: oy + (e.key ~/ cols) * cell - 10,
                width: cell,
                child: Center(child: FloatText(fl.text, fl.kind, key: ValueKey(fl.id), onDone: () => g.floats[e.key]?.remove(fl))),
              ),
        ],
      );
    },
  );

  Widget _cell(int i, double cell) {
    final f = g.shown[i];
    final placing = g.phase == Phase.place && g.pending.isNotEmpty && (f == null || g.run.canOverwrite(i));
    // the goods in hand is already here: this cell sparkles (put it on top to power it up)
    final same = placing && f != null && g.pending.first.id == f.def.id;
    final stack = f?.stack ?? 1;
    final badge = g.badge[i];
    final rar = f?.def.rarity;
    return GestureDetector(
      key: ValueKey('cell-$i'),
      // a figure on the shelf opens its details; empty cells take the figure in hand
      onTap: () {
        if (placing && f != null) {
          _confirmOverwrite(i);
        } else if (f != null && !placing) {
          Sfx.play('tap');
          // the idol on it says hello, and the details open
          g.tapFigure(f.def);
          _info(f.def, f);
        } else {
          g.tapCell(i);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          // empty cells glow; figures that can be written over only get the pink border
          color: placing && f == null ? const Color(0xFFFFF0B3) : (f == null ? const Color(0xFFFFF5FA) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          boxShadow: f == null ? null : const [BoxShadow(color: Color(0x33D9539A), blurRadius: 4, offset: Offset(0, 2))],
          border: Border.all(
            color: same ? const Color(0xFFFFC21E) : (placing ? C.pink : (rar != null && rar.index >= Rarity.rare.index ? C.rarity(rar) : C.pinkLine)),
            width: placing || (rar != null && rar.index >= Rarity.rare.index) ? 3 : 1.5,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (f == null) Icon(Icons.favorite_rounded, size: cell * 0.3, color: const Color(0xFFFFDDEB)),
            // a stacked goods wears an aura that grows with each stack
            // (keyed, so one appearing never restarts the goods' bounce next to it)
            if (f != null && stack > 1) Positioned.fill(key: const ValueKey('aura'), child: IgnorePointer(child: StackAura(level: stack))),
            // behind the goods and every number on the cell (the ×N tag sits on top of it)
            if (same) Positioned.fill(key: const ValueKey('same'), child: IgnorePointer(child: SameGlow(size: cell))),
            if (f != null)
              Shake(
                key: const ValueKey('goods'),
                token: g.hit[i],
                px: 5,
                child: Bounce(
                  token: g.pulse[i],
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FigureArt(f.def, size: 200),
                  ),
                ),
              ),
            if (f != null) _timer(f),
            if (f != null && stack > 1)
              Positioned(
                left: -4,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFE066), Color(0xFFFF8FC0)]),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('×$stack', style: outlined((cell * 0.17).clamp(10, 15), Colors.white, stroke: const Color(0xFFC2306E), width: 2.5)),
                ),
              ),
            if ((badge != null && badge != 0) || g.gave[i] != null)
              Positioned(
                // scaled with the cell so bigger shelves keep the numbers in the corner
                right: cell * 0.02,
                bottom: cell * 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // what it did to others (×2 gold, +2 mint), then what it earned (pink)
                    if (g.gave[i] != null)
                      Text(
                        g.gave[i]!,
                        style: glowNumber((cell * 0.17).clamp(10, 15), g.gave[i]!.startsWith('×') ? const Color(0xFFFFB300) : C.mint, width: 2.5),
                      ),
                    if (badge != null && badge != 0)
                      Text('$badge', style: badge > 0 ? heartNumber((cell * 0.2).clamp(11, 18), width: (cell * 0.035).clamp(2, 3)) : glowNumber((cell * 0.2).clamp(11, 18), C.red, width: (cell * 0.035).clamp(2, 3))),
                  ],
                ),
              ),
            if (g.smoking(i))
              Positioned.fill(
                key: const ValueKey('smoke'),
                child: OverflowBox(
                  maxWidth: cell * 1.5,
                  maxHeight: cell * 1.5,
                  child: Smoke(token: g.smoke[i], size: cell * 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Countdowns for things that go off (fireworks, balloons, lottery bags).
  Widget _timer(Fig f) {
    int? left;
    final fuse = f.def.effect<Fuse>();
    final life = f.def.effect<Lifetime>();
    final every = f.def.effect<EveryN>() ?? f.def.effect<SpawnEveryN>();
    if (fuse != null) left = fuse.n - f.age;
    if (life != null) left = life.n - f.age;
    if (every != null) {
      final n = every is EveryN ? every.n : (every as SpawnEveryN).n;
      left = n - f.age % n;
    }
    if (left == null || left <= 0) return const SizedBox();
    return Positioned(
      left: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(8)),
        child: Text(
          '$left',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
