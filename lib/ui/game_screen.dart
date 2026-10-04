// The run screen: HUD, gacha stage with the boss, the shelf, and overlays
// for capsules, payday, shop and the end of a run.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/defs.dart';
import '../logic/figures.dart';
import '../logic/modes.dart';
import '../logic/run.dart';
import 'controller.dart';
import 'crowd.dart';
import 'howto_screen.dart';
import 'achievement_screen.dart';
import 'idol_widgets.dart';
import 'jam_widgets.dart';
import 'juice.dart';
import 'coach.dart';
import 'lines.dart';
import 'voice.dart';
import 'meta.dart';
import 'rank_screen.dart';
import 'sfx.dart';
import 'title_screen.dart';
import 'venue.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final Meta meta;
  final MachineDef? machine;

  /// The guided first game: fixed draws and step-by-step highlights.
  final bool tutorial;
  const GameScreen({super.key, required this.meta, this.machine, this.tutorial = false});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final g = GameController(widget.meta, machine: widget.machine, tutorial: widget.tutorial);

  @override
  void initState() {
    super.initState();
    Bgm.play('bgm_${g.machine.bgm}', fromStart: true); // each machine has its own tune, from the top
    Crowd.start(); // the hall
  }

  @override
  void dispose() {
    Crowd.stop();
    g.dispose();
    super.dispose();
  }

  // what the tutorial points at
  final _kSpin = GlobalKey(), _kPlace = GlobalKey(), _kRepull = GlobalKey(), _kItem = GlobalKey();
  final _kTags = GlobalKey(), _kEffect = GlobalKey(), _kCoin = GlobalKey(), _kTotal = GlobalKey();
  final _kBubble = GlobalKey();
  final _kCells = <int, GlobalKey>{};
  GlobalKey _cellKey(int i) => _kCells.putIfAbsent(i, GlobalKey.new);

  /// The tutorial overlay for the current step (null when there is nothing to show).
  Widget? _coach() {
    final (keys, text, circle, info) = switch (g.coach) {
      Coach.spin1 => ([_kSpin], coachLines[Coach.spin1.name]!, true, false),
      Coach.place1 => ([_kPlace], coachLines[Coach.place1.name]!, false, false),
      Coach.cell1 => ([_cellKey(GameController.tutorialCell1)], coachLines[Coach.cell1.name]!, false, false),
      Coach.coins => ([_kCoin, _kTotal], coachLines[Coach.coins.name]!, false, true),
      Coach.goal => ([_kBubble], coachLines[Coach.goal.name]!, false, true),
      Coach.spin2 => ([_kSpin], coachLines[Coach.spin2.name]!, true, false),
      Coach.repull => ([_kRepull], coachLines[Coach.repull.name]!, false, false),
      Coach.item => ([_kItem], coachLines[Coach.item.name]!, false, true),
      Coach.tags => ([_kTags], coachLines[Coach.tags.name]!, false, true),
      Coach.effect => ([_kEffect], coachLines[Coach.effect.name]!, false, true),
      Coach.place2 => ([_kPlace], coachLines[Coach.place2.name]!, false, false),
      Coach.cell2 => ([_cellKey(GameController.tutorialCell2)], coachLines[Coach.cell2.name]!, false, false),
      Coach.doubled => ([_cellKey(GameController.tutorialCell1), _cellKey(GameController.tutorialCell2)], coachLines[Coach.doubled.name]!, false, true),
      Coach.go => ([_kSpin], coachLines[Coach.go.name]!, true, false),
      _ => (const <GlobalKey>[], '', false, false),
    };
    if (keys.isEmpty) {
      // between steps (animations): hold input; free play: nothing
      return g.coach == Coach.wait ? const AbsorbPointer(child: SizedBox.expand()) : null;
    }
    return CoachLayer(key: ValueKey(g.coach), targets: keys, text: text, circle: circle, onTap: info ? g.coachNext : null);
  }

  @override
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: g,
      // holding a finger down anywhere while the coins are counted speeds it up
      builder: (context, _) => Listener(
        onPointerDown: (_) => g.holding = true,
        onPointerUp: (_) => g.holding = false,
        onPointerCancel: (_) => g.holding = false,
        child: Stack(
          children: [
            Positioned.fill(child: _screen(context)),
            // the flash covers the whole screen, past the safe area and the width cap
            Positioned.fill(key: const ValueKey('flash'), child: _flash()),
            if (g.fast) Positioned(top: MediaQuery.paddingOf(context).top + 8, right: 12, child: _fastBadge()),
            if (_coach() case final c?) Positioned.fill(child: c),
          ],
        ),
      ),
    ),
  );

  Widget _screen(BuildContext context) {
    Crowd.setHype(g.hype);
    return Stack(
      fit: StackFit.expand,
      children: [
        // the hall heats up with the hearts
        Positioned.fill(
          child: VenueBackground(hype: g.hype, burst: g.burstToken),
        ),
        _play(context),
      ],
    );
  }

  Widget _play(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Shake(
          token: g.shakeToken,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none, // the dim reaches past the safe area
            children: [
              Positioned.fill(child: _main()),
              ..._overlays(),
              // keyed so they keep their state when the overlays above change in number
              // (otherwise a finished banner would replay on the next spin)
              KeyedSubtree(key: const ValueKey('banner'), child: _banner()),
              if (g.toast case final t?)
                Positioned(
                  key: const ValueKey('toast'),
                  top: 54,
                  left: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: switch (t) {
                      TopToast(achievements: final a?) => AchievementToast(a, token: g.toastToken),
                      TopToast(level: (final from, final to)?) => LevelUpToast(from, to, token: g.toastToken),
                      TopToast(machines: final m?) => UnlockToast(m, token: g.toastToken),
                      _ => const SizedBox(),
                    },
                  ),
                ),
              // the hearts of this spin stay on top, even over a toast
              KeyedSubtree(key: const ValueKey('total'), child: _total()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _main() => LayoutBuilder(
    builder: (context, bc) {
      // keep at least ~230px for the machine and the boss; the shelf takes the rest.
      // Its frame is always the default 4×4 size: a bigger altar packs smaller
      // cells into the same frame, so the gacha and 回す never move.
      const c0 = defaultSide, r0 = defaultSide;
      final maxShelfH = bc.maxHeight - 64 - (kAdsEnabled ? 56 : 10) - 230;
      final shelfW = math.max(220.0, math.min(bc.maxWidth - 24, maxShelfH * c0 / r0));
      _shelfW = shelfW; // the result card matches it
      return Column(
        children: [
          _hud(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _stage()),
                // an idol cheering a big turn, over the machine (clear of つむぎ and 回す, above the 運 chip)
                if (g.idol != null && !g.idolOnPull && (g.phase == Phase.scoring || g.phase == Phase.ready || g.phase == Phase.place))
                  Positioned(
                    key: const ValueKey('idol'),
                    left: 4,
                    right: 176,
                    bottom: _chipsBottom + 4 + _chips.length * 27.0, // above the stacked chips
                    child: IgnorePointer(
                      child: IdolToast(who: g.idol!, line: g.idolLine, token: g.idolToken),
                    ),
                  ),
                // what this gacha has been tuned with (and a 妨害's spell), lined up with the shelf's left edge
                if (_chips.isNotEmpty)
                  Positioned(
                    left: (bc.maxWidth - shelfW) / 2,
                    bottom: _chipsBottom,
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in _chips) Padding(padding: const EdgeInsets.only(top: 3), child: c),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(width: shelfW, child: _shelf()),
          ),
          if (kAdsEnabled) _bottomBar() else const SizedBox(height: 10),
        ],
      );
    },
  );

  /// What this live has been tuned with (and a 妨害's spell), stacked up the left side above the altar.
  List<Widget> get _chips => [
    if (g.run.luck > 0) _chip('運 +${g.run.luck}%', const Color(0xFF1E9E7E)),
    // 出現率UP bought at the stall
    for (final e in g.run.boost.entries) _chip('${e.key} 出現率×${e.value.round()}', idolColor[e.key]!),
    if (g.run.doubleThisSong) _chip('この曲 ハート×2', const Color(0xFFE6A700)),
    if (g.run.halfThisSong) _chip('この曲 ハート半分', C.red),
  ];

  /// Clear of the altar's name tab.
  static const _chipsBottom = 16.0;

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: C.cream,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: C.ink, width: 2),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
    ),
  );

  // ── HUD ──
  Widget _hud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Container(
            key: _kCoin,
            padding: const EdgeInsets.fromLTRB(4, 2, 14, 2),
            decoration: BoxDecoration(
              color: C.cream,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: C.ink, width: 3),
            ),
            child: Row(
              children: [
                const HeartIcon(size: 34),
                const SizedBox(width: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: g.coinsShown.toDouble()),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text('${v.round()}', style: outlined(26, C.pink, stroke: Colors.white, width: 4)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // shrinks when the coin count gets long
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Text(_chipText, style: outlined(13, Colors.white, width: 2)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _menu,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: C.cream,
                shape: BoxShape.circle,
                border: Border.all(color: C.ink, width: 3),
              ),
              child: const Icon(Icons.menu_rounded, color: C.ink, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ── machine + boss ──
  Widget _stage() {
    final ready = g.phase == Phase.ready;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: g.turnHandle,
                    child: Shake(
                      token: g.phase == Phase.dropping ? 1 : 0,
                      px: 5,
                      child: MachineArt(hue: g.machine.hue, alignment: Alignment.bottomCenter),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 168,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      // the bubble reaches left past this column, up to the gacha-name chip's left edge
                      // bubble + boss sit together right above 回す; they shrink a little only if space runs out
                      child: OverflowBox(
                        alignment: Alignment.bottomRight,
                        minWidth: _bubbleWidth(context),
                        maxWidth: _bubbleWidth(context),
                        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: _boss(_bubbleWidth(context))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // the 回す button's slot also shows what's in hand while placing
                    Stack(
                      children: [
                        Visibility(
                          visible: ready,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: KeyedSubtree(
                            key: _kSpin,
                            child: _Pulse(child: PopButton('回す！', onTap: ready ? g.turnHandle : null, fontSize: 26)),
                          ),
                        ),
                        if (!ready) Positioned.fill(child: _hand()),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The boss's speech bubble: the next payday on top (what he's here to
  /// collect), his line below, and a tail pointing down at him.
  String get _chipText => '${g.machine.name}・難易度 ${g.machine.difficultyText}';

  /// From the right edge to the left edge of the gacha-name chip in the top bar:
  /// menu button (46) + gap (8) + chip (text + 24 padding + 3 border).
  double _bubbleWidth(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: _chipText, style: DefaultTextStyle.of(context).style.merge(outlined(13, Colors.white, width: 2))),
      textDirection: TextDirection.ltr,
    )..layout();
    return 46 + 8 + tp.width + 27;
  }

  Widget _boss(double width) {
    final r = g.run;
    final left = r.turnsToPayday;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Bounce(
            token: g.bossToken,
            amount: 0.08,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: Color(0x55220A2A), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  // the outline goes on top: drawn underneath, the meter's gradient covered its rounded corners
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.ink, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyedSubtree(
                        key: _kBubble,
                        child: SongMeter(
                          song: r.paydaysPaid + 1,
                          songs: Run.clearPaydays,
                          spinsLeft: left,
                          spins: r.turnsPerSong,
                          hearts: g.coinsShown,
                          quota: r.due,
                        ),
                      ),
                      Container(height: 2, color: const Color(0x33F59AC3)),
                      Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 7), child: _TwoLines(g.bossLine)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 46),
                  child: CustomPaint(size: const Size(18, 12), painter: _TailPainter()),
                ),
              ],
            ),
          ),
          // the boss, right under the tail, at the right end above 回す
          GestureDetector(
            key: const ValueKey('tsumugi'),
            onTap: g.tapTsumugi,
            child: Bounce(token: g.bossToken, amount: 0.12, child: Image.asset('assets/ui/boss_${g.bossMood}.png', height: 104)),
          ),
        ],
      ),
    );
  }

  // ── what's in hand ──
  Widget _hand() {
    if (g.phase == Phase.place && g.pending.isNotEmpty) {
      final d = g.pending.first;
      final full = g.run.emptyCells.isEmpty;
      return Row(
        children: [
          GestureDetector(
            onTap: () {
              Sfx.play('tap');
              _info(d);
            },
            child: _Pulse(child: FigureArt(d, size: 50)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(full ? '上書きするグッズをタップ' : '置く場所をタップ（上書きもOK）', style: outlined(14, Colors.white, width: 2)),
                ),
                const SizedBox(height: 4),
                PopButton(
                  'すてる',
                  onTap: g.canDiscard ? g.discardPending : null,
                  color: Colors.blueGrey,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return const SizedBox();
  }

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

  /// "品がえ" for a single use, "品がえ 2/3" once the stall has added more.
  String _uses(String name, int left, int max) => max <= 1 ? name : '$name $left/$max';

  /// The rewarded ad (only where ads run).
  Widget _bottomBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Align(
      alignment: Alignment.centerRight,
      child: PopButton(
        '▶ 広告で報酬',
        onTap: g.canWatchAd ? _adSheet : null,
        color: C.mint,
        fontSize: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
  );

  // ── overlays ──
  List<Widget> _overlays() => switch (g.phase) {
    Phase.dropping || Phase.capsule || Phase.reveal => [_dim(onTap: g.phase == Phase.capsule ? g.openCapsule : null), _capsules()],
    Phase.cutin => [
      _dim(onTap: g.skipCutin),
      CutIn(who: g.idol!, line: g.idolLine, ssr: g.bestOption == Rarity.legend, token: g.idolToken, onTap: g.skipCutin),
    ],
    Phase.jam => [_dim(), _jam()],
    Phase.payday => [_dim(), _payday()],
    Phase.failed => [_dim(), _failed()],
    Phase.cleared => [_clearBg(), _cleared()],
    Phase.shop => [_dim(), _shop()],
    // a cleared live ends over the celebration picture, a lost one over the dim
    Phase.over => [g.run.cleared ? _clearBg() : _dim(), _over()],
    _ => const [],
  };

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

  /// The 妨害 (siren, shoving match, outcome); a fresh one each time.
  Widget _jam() => JamOverlay(g, key: ValueKey(g.jamToken));

  /// Darkens the whole screen (well past the safe area and the 480px column).
  Widget _dim({VoidCallback? onTap}) => Positioned(
    left: -600,
    right: -600,
    top: -200,
    bottom: -200,
    child: GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 0.6),
        duration: const Duration(milliseconds: 250),
        builder: (_, a, _) => ColoredBox(color: Colors.black.withValues(alpha: a)),
      ),
    ),
  );

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
      return _Wobble(
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
          _wide(PopButton('あきらめる', onTap: g.giveUp, color: Colors.blueGrey, fontSize: 16)),
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

  /// The altar's width, kept from the last layout (the result card is as wide).
  double _shelfW = 360;

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
                    Image.asset('assets/ui/boss_${r.cleared || g.levelUps.isNotEmpty ? 1 : 0}.png', height: 76),
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

  Widget _fastBadge() => IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
      child: Text('▶▶ ${g.speed}倍速', style: outlined(15, C.gold, width: 2)),
    ),
  );

  Widget _flash() => IgnorePointer(
    child: g.flashToken == 0
        ? const SizedBox()
        : TweenAnimationBuilder<double>(
            key: ValueKey(g.flashToken),
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 500),
            builder: (_, a, _) => ColoredBox(
              color: Colors.white.withValues(alpha: a * 0.85),
              child: const SizedBox.expand(),
            ),
          ),
  );

  Widget _banner() => IgnorePointer(
    child: g.bannerToken == 0
        ? const SizedBox()
        : Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(g.bannerToken),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (_, t, _) => Opacity(
                opacity: t < 0.75 ? 1 : (1 - t) * 4,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Transform.scale(
                    scale: t < 0.25 ? Curves.easeOutBack.transform(t * 4) * 1.4 : 1.4,
                    child: Text(g.banner ?? '', style: outlined(64, C.pink, stroke: Colors.white, width: 6)),
                  ),
                ),
              ),
            ),
          ),
  );

  /// The last turn's gain, popped under the coin counter (top-left) and kept
  /// there until the next spin. Bigger gains get a bigger badge and more sparkle.
  /// The spin's total the player tapped away (it pops off and stays gone until the next one).
  int _dismissed = 0;
  bool _popping = false;

  Widget _total() {
    // while the hearts come in it shows the running count and swells with it; then the final sum pops
    final live = g.phase == Phase.scoring && g.liveTotal != 0;
    final v = live ? g.liveTotal : g.lastTotal;
    // only while playing: not over the payday, stall or result cards
    final playing = g.phase == Phase.ready || g.phase == Phase.place || g.phase == Phase.scoring;
    if (!playing || v == 0 || (!live && g.totalToken == 0)) return const SizedBox();
    final gone = !live && _dismissed == g.totalToken;
    if (gone && !_popping) return const SizedBox();
    final plus = v > 0;
    final big = v >= 40;
    final size = (26 + math.log(v.abs() + 1) * 6.5).clamp(26, 70).toDouble();
    return Positioned(
      left: 10,
      top: 60,
      // a tap pops it away (it can sit in the way)
      child: GestureDetector(
        key: _kTotal,
        onTap: live || gone
            ? null
            : () {
                Sfx.play('pop');
                setState(() {
                  _dismissed = g.totalToken;
                  _popping = true;
                });
              },
        child: gone
            ? TweenAnimationBuilder<double>(
                key: ValueKey('poof${g.totalToken}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                onEnd: () => setState(() => _popping = false),
                builder: (_, t, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.scale(scale: 1 + 0.5 * Curves.easeOut.transform(t), alignment: Alignment.centerLeft, child: _totalLook(v, size, plus, 1)),
                    ),
                    Positioned(left: size * 0.45 - 110, top: size * 0.55 - 110, child: HeartBurst(token: -100000 - g.totalToken, count: 18, size: 220)),
                  ],
                ),
              )
            : TweenAnimationBuilder<double>(
          // each beat bumps it (and a round number passed bumps it harder); the end pops once more
          key: ValueKey(live ? 'live$v-${g.milestoneToken}' : 'end${g.totalToken}'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: live ? 320 : 900),
          builder: (_, t, _) {
            final pop = Curves.elasticOut.transform(t);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (plus && (!live || g.milestoneToken > 0))
                  Positioned(
                    left: 60 - (big ? 130 : 85),
                    top: 26 - (big ? 130 : 85),
                    child: Sparkles(token: live ? g.milestoneToken : g.totalToken, size: big ? 260 : 170, colors: const [C.gold, Colors.white, C.pink], count: big ? 34 : 16),
                  ),
                // cute hearts popping out of the badge: a few on every beat, a fountain at the end
                if (plus)
                  Positioned(
                    left: size * 0.45 - 110,
                    top: size * 0.55 - 110,
                    child: HeartBurst(token: live ? v : -g.totalToken, count: live ? 7 : (big ? 26 : 16), size: 220),
                  ),
                Transform.scale(
                  scale: live ? 1 + 0.16 * (1 - pop) : 1 + 0.3 * (1 - pop),
                  alignment: Alignment.centerLeft,
                  child: _totalLook(v, size, plus, t, pop),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The total badge itself: the heart (beating with [pop]), the number, the gloss and the glow.
  Widget _totalLook(int v, double size, bool plus, double t, [double pop = 1]) {
    final shown = v;
    return Transform.rotate(
                    angle: -0.06,
                    child: _Pulse(
                      child: Shine(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 2, 14, 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: plus ? const [Color(0xFFFFB3D6), Color(0xFFFF4F98)] : const [Color(0xFFB0B8C8), Color(0xFF6A7488)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: C.ink, width: 3),
                          boxShadow: [
                            if (plus)
                              BoxShadow(
                                color: Color.lerp(C.gold, const Color(0xFFFF6FA8), (math.log(v + 1) / math.log(2000)).clamp(0.0, 1.0))!.withValues(alpha: 0.8 * (1 - t * 0.5)),
                                blurRadius: 18 + 10 * (1 - t) + (math.log(v + 1) * 2),
                                spreadRadius: 2 + math.log(v + 1) * 0.6,
                              ),
                            const BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (plus)
                              Padding(
                                padding: const EdgeInsets.only(right: 2),
                                // the heart beats with every heart that comes in
                                child: Transform.scale(scale: 1 + 0.35 * (1 - pop), child: HeartIcon(size: size * 0.9)),
                              ),
                            Text(plus ? '+$shown' : '$shown', style: outlined(size, Colors.white, stroke: plus ? const Color(0xFFB0306E) : C.ink, width: 5)),
                          ],
                        ),
                      ),
                      ),
                    ),
                  );
  }

  Future<void> _info(FigureDef d, [Fig? f]) => showFigureInfo(context, d, f, g.run);

  /// The two buttons under a revealed capsule share one width.
  Widget _revealButton(Widget b) => SizedBox(width: 260, child: b);

  /// Stacked buttons on the result cards all share one width.
  Widget _wide(Widget b) => SizedBox(width: 250, child: b);

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

  /// Leaves the live for the gacha select screen (its back arrow leads on to the title).
  void _toSelect() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SelectScreen(meta: widget.meta)));

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

  Widget _soundIcon(IconData icon, VoidCallback toggle, StateSetter set) => GestureDetector(
    onTap: () {
      toggle();
      Sfx.play('toggle');
      set(() {});
    },
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: C.cream,
        shape: BoxShape.circle,
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Icon(icon, color: C.ink, size: 26),
    ),
  );

  /// In-run menu: resume, sound, or quit to the title.
  void _menu() {
    Sfx.play('tap');
    final m = widget.meta;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Dialog(
          backgroundColor: Colors.transparent,
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('メニュー', style: outlined(26, C.pink, stroke: C.ink, width: 3)),
                const SizedBox(height: 8),
                // sound settings as icons, like on the title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _soundIcon(m.music ? Icons.music_note_rounded : Icons.music_off_rounded, () {
                      m.toggleMusic();
                      Bgm.setEnabled(m.music);
                    }, set),
                    const SizedBox(width: 12),
                    _soundIcon(m.voice ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded, () {
                      m.toggleVoice();
                      Voice.setEnabled(m.voice);
                    }, set),
                    const SizedBox(width: 12),
                    _soundIcon(m.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, () {
                      m.toggleSound();
                      Sfx.enabled = m.sound;
                    }, set),
                  ],
                ),
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
      ),
    );
  }
}

Future<void> showFigureInfo(BuildContext context, FigureDef d, [Fig? f, Run? run]) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(14),
      child: Panel(
        child: Row(
          children: [
            FigureArt(d, size: 110),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.ink),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RarityStars(d.rarity, size: 18),
                        Text(
                          d.tags.map((t) => '「$t」').join(),
                          style: const TextStyle(color: C.ink, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.description,
                    style: const TextStyle(fontSize: 15, height: 1.4, color: C.ink, fontWeight: FontWeight.w600),
                  ),
                  if (f != null && f.stack > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('重ねて強化中：効果が ×${f.stack}', style: outlined(15, const Color(0xFFE6A700), stroke: Colors.white, width: 3)),
                    ),
                  if (f != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '置いてから ${f.age} 回転${f.lastGain != 0 ? '・さっきのハート ${f.lastGain}' : ''}',
                      style: const TextStyle(color: C.woodDark, fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The little downward tail under the boss's speech bubble.
/// The boss's line in at most two lines: the font shrinks until it fits.
class _TwoLines extends StatelessWidget {
  final String text;
  const _TwoLines(this.text);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, bc) {
      final base = DefaultTextStyle.of(context).style;
      var size = 15.0;
      TextStyle style() => base.merge(TextStyle(fontSize: size, height: 1.3, color: C.ink, fontWeight: FontWeight.w800));
      while (size > 10) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: style()),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: bc.maxWidth);
        if (!tp.didExceedMaxLines) break;
        size -= 0.5;
      }
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style());
    },
  );
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -3)
      ..lineTo(size.width * 0.35, size.height)
      ..lineTo(size.width, -3)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(0, -1)
        ..lineTo(size.width * 0.35, size.height)
        ..lineTo(size.width, -1),
      Paint()
        ..color = C.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TailPainter o) => false;
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  // its own layer: a forever-pulsing button must not repaint the whole screen each frame
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, c) => Transform.scale(scale: 1 + 0.06 * Curves.easeInOut.transform(_c.value), child: c),
      child: widget.child,
    ),
  );
}

class _Wobble extends StatefulWidget {
  final Widget child;
  final double strength;
  const _Wobble({required this.child, required this.strength});
  @override
  State<_Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<_Wobble> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, c) => Transform.rotate(angle: math.sin(_c.value * 2 * math.pi * 2) * widget.strength * (_c.value < 0.5 ? 1 : 0.3), child: c),
      child: widget.child,
    ),
  );
}
