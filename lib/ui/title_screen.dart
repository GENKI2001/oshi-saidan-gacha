// Title, machine/ascension select and the book.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/figures.dart';
import '../logic/modes.dart';
import 'game_screen.dart';
import 'howto_screen.dart';
import 'level_card.dart';
import 'meta.dart';
import 'rank_screen.dart';
import 'sfx.dart';
import 'widgets.dart';

const _bg = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A3F8E), Color(0xFF9A5C9E), Color(0xFFE79A8E)],
  ),
);

/// The festival evening picture with drifting lights, behind [child].
Widget _festival(Widget child) => Container(
  decoration: _bg,
  child: Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/ui/title_bg.jpg', fit: BoxFit.cover),
      const _Twinkles(),
      child,
    ],
  ),
);

const _cardFraction = 0.78;

Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
);

class TitleScreen extends StatefulWidget {
  final Meta meta;
  const TitleScreen({super.key, required this.meta});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Bgm.play('bgm_title');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _toggle(IconData icon, VoidCallback f) => GestureDetector(
    onTap: () {
      f();
      Sfx.play('toggle');
      setState(() {});
    },
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: C.cream,
        shape: BoxShape.circle,
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Icon(icon, color: C.ink, size: 24),
    ),
  );

  /// Until the tutorial is done, playing means the guided first game.
  Future<void> _play() async {
    final m = widget.meta;
    if (!m.tutorialDone) {
      await _go(GameScreen(meta: m, machine: machines.first, tutorial: true));
      return;
    }
    await _go(SelectScreen(meta: m));
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(_fade(page));
    Bgm.play('bgm_title');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return Scaffold(
      body: Container(
        decoration: _bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/ui/title_bg.jpg', fit: BoxFit.cover),
            const _Twinkles(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 60),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Image.asset('assets/ui/title.png', semanticLabel: 'ぽんぽこガチャ縁日'),
                          ),
                          // the machine and the buttons sit a bit above the bottom edge, not on it
                          Expanded(
                            flex: 6,
                            child: AnimatedBuilder(
                              animation: _c,
                              builder: (_, _) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  const IgnorePointer(
                                    child: Opacity(opacity: 0.35, child: Sunburst(color: Color(0xFFFFE08A), size: 380)),
                                  ),
                                  Transform.translate(
                                    offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)),
                                    child: MachineArt(hue: machineById[m.lastMachine]?.hue ?? 0, height: 260),
                                  ),
                                  Positioned(
                                    right: 24,
                                    bottom: 4,
                                    child: Transform.rotate(
                                      angle: 0.08 * math.sin(_c.value * math.pi),
                                      child: Image.asset('assets/ui/boss_0.png', height: 110),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // the very first time it is the tutorial; afterwards it just plays
                          PopButton(m.tutorialDone ? 'あそぶ' : 'チュートリアル', fontSize: m.tutorialDone ? 32 : 26, onTap: _play),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PopButton(
                                '図鑑  ${m.seen.length} / ${figures.length}',
                                color: const Color(0xFF8E7CC3),
                                fontSize: 18,
                                onTap: () => _go(BookScreen(meta: m)),
                              ),
                              const SizedBox(width: 10),
                              PopButton(
                                'ランキング',
                                color: C.gold,
                                fontSize: 18,
                                onTap: () => _go(RankScreen(meta: m)),
                              ),
                            ],
                          ),
                          const Spacer(),
                        ],
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: GestureDetector(
                          onTap: () {
                            Sfx.play('toggle');
                            _go(HowToScreen(meta: m));
                          },
                          // same height as the round sound toggles on the right (8 + 24 + 8 + borders)
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                            decoration: BoxDecoration(
                              color: C.cream,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: C.ink, width: 3),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.help_rounded, color: C.ink, size: 22),
                                SizedBox(width: 4),
                                Text(
                                  'あそびかた',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Row(
                          children: [
                            _toggle(m.music ? Icons.music_note_rounded : Icons.music_off_rounded, () {
                              m.toggleMusic();
                              Bgm.setEnabled(m.music);
                            }),
                            const SizedBox(width: 8),
                            _toggle(m.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, () {
                              m.toggleSound();
                              Sfx.enabled = m.sound;
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick a machine (swipe) and an ascension level.
class SelectScreen extends StatefulWidget {
  final Meta meta;
  const SelectScreen({super.key, required this.meta});
  @override
  State<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> {
  late int _i = math.max(0, machines.indexWhere((m) => m.id == widget.meta.lastMachine));
  late int _asc = math.min(widget.meta.lastAsc, widget.meta.maxAsc);
  late final _pc = PageController(initialPage: _i, viewportFraction: _cardFraction);

  @override
  void initState() {
    super.initState();
    Bgm.play('bgm_select');
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final m = machines[_i];
    final open = meta.unlocked(m);
    return Scaffold(
      body: _festival(
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 30),
                      ),
                      Text('ガチャをえらぶ', style: outlined(24, Colors.white, width: 3)),
                    ],
                  ),
                  FractionallySizedBox(
                    widthFactor: _cardFraction,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: LevelCard(meta)),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: machines.length,
                      onPageChanged: (i) {
                        Sfx.play('rattle');
                        setState(() => _i = i);
                      },
                      itemBuilder: (_, i) => _card(machines[i], meta.unlocked(machines[i]), i == _i),
                    ),
                  ),
                  // Same width as a machine card (page fraction minus its side padding).
                  FractionallySizedBox(
                    widthFactor: _cardFraction,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _ascension()),
                  ),
                  const SizedBox(height: 12),
                  PopButton(
                    open ? 'はじめる！' : 'まだ遊べない',
                    fontSize: 28,
                    sound: 'handle',
                    onTap: open
                        ? () {
                            meta.remember(m.id, _asc);
                            Navigator.of(context).pushReplacement(_fade(GameScreen(meta: meta, machine: m, ascension: _asc)));
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(MachineDef m, bool open, bool current) => AnimatedScale(
    scale: current ? 1 : 0.88,
    duration: const Duration(milliseconds: 200),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Panel(
        // the art takes a fixed share so every card's text starts at the same height
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: MachineArt(hue: m.hue, locked: !open),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Text(open ? m.name : '？？？', style: outlined(24, C.pink, stroke: C.ink, width: 3)),
                  Text(
                    open ? m.blurb : '解放条件：${m.unlockText}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: C.ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (open)
                    for (final p in m.perks)
                      Text(
                        '・$p',
                        style: const TextStyle(color: C.ink, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _ascension() {
    final max = widget.meta.maxAsc;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _arrow('−', _asc > 0 ? () => setState(() => _asc--) : null),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '段位 $_asc', style: outlined(20, C.gold, width: 3)),
                        if (max < maxAscension) TextSpan(text: ' （$max まで解放）', style: outlined(13, C.gold, width: 2)),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
                Text(
                  _asc == 0 ? 'ふつう' : [for (var k = 1; k <= _asc; k++) ascensionText[k]].join(' / '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.ink, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _arrow('＋', _asc < max ? () => setState(() => _asc++) : null),
        ],
      ),
    );
  }

  Widget _arrow(String t, VoidCallback? f) => PopButton(
    t,
    onTap: f,
    sound: 'toggle',
    fontSize: 20,
    color: const Color(0xFF8E7CC3),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  );
}

class BookScreen extends StatelessWidget {
  final Meta meta;
  const BookScreen({super.key, required this.meta});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.night,
    appBar: AppBar(
      backgroundColor: C.night,
      foregroundColor: Colors.white,
      title: Text('図鑑 ${meta.seen.length} / ${figures.length}', style: outlined(22, Colors.white, width: 2)),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final f in figures)
              GestureDetector(
                onTap: meta.seen.contains(f.id)
                    ? () {
                        Sfx.play('tap');
                        showFigureInfo(context, f);
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: C.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: meta.seen.contains(f.id) ? C.rarity(f.rarity) : C.woodDark, width: 3),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: meta.seen.contains(f.id)
                      ? FigureArt(f, size: 100)
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                f.level > meta.level ? const Color(0xFF3A2D52) : const Color(0xFF5A4A6A),
                                BlendMode.srcIn,
                              ),
                              child: FigureArt(f, size: 100),
                            ),
                            // not in the gacha yet: show the level that unlocks it
                            if (f.level > meta.level) Text('Lv${f.level}', style: outlined(18, Colors.white, width: 3)),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Soft festival lights that drift up and twinkle behind the title.
class _Twinkles extends StatefulWidget {
  const _Twinkles();
  @override
  State<_Twinkles> createState() => _TwinklesState();
}

class _TwinklesState extends State<_Twinkles> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _TwinklePainter(_c.value)),
    ),
  );
}

class _TwinklePainter extends CustomPainter {
  final double t;
  _TwinklePainter(this.t);
  static const _colors = [Color(0xFFFFE08A), Color(0xFFFFB3D1), Color(0xFFB8F1FF), Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < 16; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.4 + rnd.nextDouble() * 0.6;
      final y = (rnd.nextDouble() - t * speed) % 1.0 * size.height;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 6 + phase);
      final r = 2.0 + rnd.nextDouble() * 4;
      final color = _colors[i % _colors.length];
      final pos = Offset(x + 6 * math.sin(t * 2 * math.pi * 3 + phase), y);
      canvas.drawCircle(
        pos,
        r * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.15 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      if (i % 3 == 0) {
        // A four-point star glint.
        final s = r * (1.2 + glow);
        final path = Path();
        for (var k = 0; k < 8; k++) {
          final rr = k.isEven ? s : s * 0.3;
          final p = pos + Offset(math.cos(k * math.pi / 4), math.sin(k * math.pi / 4)) * rr;
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), Paint()..color = color.withValues(alpha: 0.35 + 0.35 * glow));
      } else {
        canvas.drawCircle(pos, r * 0.6, Paint()..color = color.withValues(alpha: 0.2 + 0.35 * glow));
      }
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter o) => o.t != t;
}
