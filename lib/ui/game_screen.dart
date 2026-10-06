// The run screen: HUD, gacha stage with the boss, the altar and the overlays. The altar, the
// capsule, the cards (song end, stall, result) and the sheets are in game_screen/.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/defs.dart';
import '../logic/figures.dart';
import '../logic/modes.dart';
import '../logic/run.dart';
import 'controller.dart';
import 'crowd.dart';
import 'figure_info.dart';
import 'howto_screen.dart';
import 'achievement_screen.dart';
import 'idol_widgets.dart';
import 'jam_widgets.dart';
import 'juice.dart';
import 'coach.dart';
import 'lines.dart';
import 'meta.dart';
import 'rank_screen.dart';
import 'sfx.dart';
import 'sound_toggles.dart';
import 'title_screen.dart';
import 'venue.dart';
import 'widgets.dart';

part 'game_screen/capsule.dart';
part 'game_screen/cards.dart';
part 'game_screen/sheets.dart';
part 'game_screen/shelf.dart';

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
      Coach.spin3 => ([_kSpin], coachLines[Coach.spin3.name]!, true, false),
      Coach.place3 => ([_kPlace], coachLines[Coach.place3.name]!, false, false),
      Coach.cell3 => ([_cellKey(GameController.tutorialCell2)], coachLines[Coach.cell3.name]!, false, false),
      Coach.stacked => ([_cellKey(GameController.tutorialCell2)], coachLines[Coach.stacked.name]!, false, true),
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
                      TopToast(figures: (final m, final f)?) => NewGoodsToast(m, f, token: g.toastToken),
                      TopToast(machines: final m?) => UnlockToast(m, token: g.toastToken),
                      _ => const SizedBox(),
                    },
                  ),
                ),
              // the hearts of this spin stay on top, even over a toast
              KeyedSubtree(key: const ValueKey('total'), child: _total()),
              KeyedSubtree(key: const ValueKey('quota'), child: QuotaCutIn(token: g.quotaToken, song: g.quotaSong)),
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
    if (g.run.luck > 0) _chip(en ? 'Luck +${g.run.luck}%' : '運 +${g.run.luck}%', const Color(0xFF1E9E7E)),
    // 出現率UP bought at the stall
    for (final e in g.run.boost.entries) _chip(en ? '${tr(e.key)} rate ×${e.value.round()}' : '${e.key} 出現率×${e.value.round()}', idolColor[e.key]!),
    if (g.run.doubleThisSong) _chip(tr('この曲 ハート×2'), const Color(0xFFE6A700)),
    if (g.run.halfThisSong) _chip(tr('この曲 ハート半分'), C.red),
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
          RoundIconButton(Icons.menu_rounded, onTap: _menu),
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
                    // the machine itself shows what is inside it (spinning is the 回す！ button)
                    onTap: _lineup,
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
                            child: Pulse(child: PopButton('回す！', onTap: ready ? g.turnHandle : null, fontSize: 26)),
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
  String get _chipText => en ? '${g.machine.name} · ${tr(g.machine.difficultyText)}' : '${g.machine.name}・難易度 ${g.machine.difficultyText}';

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
                      Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 7), child: _TwoLines(tr(g.bossLine))),
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
            child: Pulse(child: FigureArt(d, size: 50)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(tr(full ? '上書きするグッズをタップ' : '置く場所をタップ（上書きもOK）'), style: outlined(14, Colors.white, width: 2)),
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

  /// "品がえ" for a single use, "品がえ 2/3" once the stall has added more.
  String _uses(String name, int left, int max) => max <= 1 ? tr(name) : '${tr(name)} $left/$max';

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

  /// The altar's width, kept from the last layout (the result card is as wide).
  double _shelfW = 360;

  Widget _fastBadge() => IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
      child: Text(en ? '▶▶ ×${g.speed} speed' : '▶▶ ${g.speed}倍速', style: outlined(15, C.gold, width: 2)),
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
      child: Pulse(
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

  /// Leaves the live for the gacha select screen (its back arrow leads on to the title).
  void _toSelect() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SelectScreen(meta: widget.meta)));

}

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

/// The little downward tail under the boss's speech bubble.
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
