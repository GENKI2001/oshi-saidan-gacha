// The title (the key visual, tap a member to hear her). Gacha select and the book are in title_screen/.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../logic/achievements.dart';
import '../logic/figures.dart';
import '../logic/modes.dart';
import '../logic/run.dart';
import 'achievement_screen.dart';
import 'figure_info.dart';
import 'game_screen.dart';
import 'howto_screen.dart';
import 'idol_widgets.dart';
import 'juice.dart';
import 'lines.dart';
import 'meta.dart';
import 'rank.dart';
import 'rank_screen.dart';
import 'member_screen.dart';
import 'sfx.dart';
import 'sound_toggles.dart';
import 'voice.dart';
import 'widgets.dart';

part 'title_screen/book.dart';
part 'title_screen/select.dart';

const _bg = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A3F8E), Color(0xFF9A5C9E), Color(0xFFE79A8E)],
  ),
);

/// The live hall, warming up, with drifting lights behind [child].
Widget _festival(Widget child) => Container(
  decoration: _bg,
  child: Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/ui/venue_1.jpg', fit: BoxFit.cover),
      const _Twinkles(),
      child,
    ],
  ),
);

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

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin, RouteAware {
  // a tap on one of the five in the key visual: she says something, and hearts pop where you tapped
  static const _kvOrder = ['こはる', 'しずく', 'ひなた', 'よる', 'もも']; // left to right in the picture
  static const _kvSplit = [0.19, 0.37, 0.59, 0.81]; // where one ends and the next begins (fractions of the width)
  final _kvKey = GlobalKey();
  Offset? _tapAt;
  int _tapToken = 0;

  /// A tap anywhere over the key visual (the talk area lies on top of it): the one under the finger talks.
  void _tapIdol(Offset global) {
    final box = _kvKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final at = box.globalToLocal(global);
    final fx = at.dx / box.size.width, fy = at.dy / box.size.height;
    if (fx < 0 || fx > 1 || fy < 0.36 || fy > 0.97) return; // the logo, the sky and the edges are nobody
    final k = _kvSplit.indexWhere((x) => fx < x);
    _talk(who: _kvOrder[k < 0 ? _kvOrder.length - 1 : k]);
    HapticFeedback.selectionClick();
    setState(() {
      _tapAt = at;
      _tapToken++;
    });
  }

  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  // the title's tune comes back whenever the title is on top again, however the screens above
  // were left (a replaced route ends the push's future early, so awaiting it was not enough)
  @override
  void didPopNext() {
    Bgm.play('bgm_title');
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Bgm.play('bgm_title');
    // the title call, once the screen is up
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _who == null) _talk();
    });
  }

  bool _warmed = false;

  /// Loads the pictures the first pulls need while the title is up (on the web they come over the network).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context) case final PageRoute r) routes.subscribe(this, r);
    if (_warmed) return;
    _warmed = true;
    final paths = [
      for (var k = 0; k < 5; k++) ...['assets/ui/capsule_${k}_top.png', 'assets/ui/capsule_${k}_bot.png'],
      for (final m in members) ...[portrait(m), portrait(m, happy: true)],
      for (final f in figures) 'assets/figures/${f.id}.webp',
      for (var k = 0; k < 4; k++) 'assets/ui/venue_$k.jpg',
    ];
    for (final p in paths) {
      precacheImage(AssetImage(p), context).ignore();
    }
  }

  @override
  void dispose() {
    routes.unsubscribe(this);
    _c.dispose();
    super.dispose();
  }

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
    Voice.stop();
    await Navigator.of(context).push(_fade(page));
  }

  /// Someone on the key visual says something (the first time: the title call).
  String? _who;
  String _line = '';
  int _token = 0;
  int _taps = 0;

  void _talk({String? who}) {
    who ??= members[math.Random().nextInt(members.length)];
    final l = idolLines[who]!;
    final line = _taps++ == 0 ? pick(l.title) : pick([...l.title, ...l.talk, ...l.pull]);
    Voice.say(who, line, delayMs: 120);
    setState(() {
      _who = who;
      _line = line;
      _token++;
    });
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
            // all five on the key visual stay in view: the picture is shown whole (fitted, never cropped)
            // over a blurred, zoomed copy of itself that fills the rest of the screen
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.asset('assets/ui/title_bg.jpg', fit: BoxFit.cover),
            ),
            const ColoredBox(color: Color(0x33FFFFFF)),
            Align(
              alignment: const Alignment(0, -0.2),
              child: AspectRatio(
                aspectRatio: 1024 / 1536,
                child: ShaderMask(
                  // the sharp picture melts into the blur at its top and bottom edges
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.08, 0.9, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: GestureDetector(
                    key: _kvKey,
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _tapIdol(d.globalPosition),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: Image.asset('assets/ui/title_bg.jpg', fit: BoxFit.fill)),
                        if (_tapAt case final at?)
                          Positioned(
                            left: at.dx - 70,
                            top: at.dy - 70,
                            child: Sparkles(token: _tapToken, size: 140, colors: const [Color(0xFFFF6FA8), Colors.white, Color(0xFFFFE14D)], count: 14),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const _Twinkles(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 58),
                          AnimatedBuilder(
                            animation: _c,
                            builder: (_, c) => Transform.translate(offset: Offset(0, -5 * Curves.easeInOut.transform(_c.value)), child: c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: Image.asset('assets/ui/title.png', semanticLabel: tr('推し祭壇ガチャ')),
                            ),
                          ),
                          // the idols on the key visual: tap one and she talks
                          Expanded(
                            child: GestureDetector(
                              key: const ValueKey('idols'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) => _tapIdol(d.globalPosition),
                              child: Stack(
                                children: [
                                  if (_who != null)
                                    Positioned(
                                      left: 14,
                                      right: 14,
                                      bottom: 10,
                                      child: IgnorePointer(child: IdolToast(who: _who!, line: tr(_line), token: _token)),
                                    ),
                                  if (_who == null)
                                    Positioned(
                                      right: 18,
                                      bottom: 12,
                                      child: AnimatedBuilder(
                                        animation: _c,
                                        builder: (_, c) => Opacity(opacity: 0.55 + 0.45 * _c.value, child: c),
                                        child: Text(tr('タップすると しゃべるよ'), style: outlined(13, Colors.white, stroke: C.pink, width: 3)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // the very first time it is the tutorial; afterwards it just plays
                          // coloured after the members on the key visual above them: ひなた in the middle …
                          PopButton(tr(m.tutorialDone ? 'あそぶ' : 'チュートリアル'), fontSize: m.tutorialDone ? 32 : 26, color: idolColor['ひなた']!, onTap: _play),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                // … and left to right こはる, しずく, よる, もも, as they stand
                                for (final (ja, color, page) in [
                                  ('コレクション', idolColor['こはる']!, CollectionScreen(meta: m) as Widget),
                                  ('メンバー', idolColor['しずく']!, const MemberScreen()),
                                  ('実績', idolColor['よる']!, AchievementScreen(meta: m) as Widget),
                                  ('ランキング', idolColor['もも']!, RankScreen(meta: m)),
                                ])
                                  // widths follow the labels, so 「コレクション」 stays on one line
                                  if (tr(ja) case final label)
                                  Expanded(
                                    flex: label.length + 3,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: PopButton(
                                        label,
                                        color: color,
                                        fontSize: 13,
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                                        onTap: () => _go(page),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // the buttons sit well above the bottom edge, over the idols' skirts, not their feet
                          SizedBox(height: math.max(40, MediaQuery.sizeOf(context).height * 0.09)),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.help_rounded, color: C.ink, size: 22),
                                const SizedBox(width: 4),
                                Text(
                                  tr('あそびかた'),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.ink),
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
                            // 日本語 ⇄ English (the voices stay Japanese)
                            RoundIconButton(
                              Icons.translate_rounded,
                              key: const ValueKey('lang'),
                              size: 24,
                              padding: 8,
                              onTap: () {
                                Sfx.play('toggle');
                                setState(m.toggleLang);
                              },
                            ),
                            const SizedBox(width: 6),
                            SoundToggles(m, size: 24, padding: 8, gap: 6),
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

/// Screens that put their own tune back when they are on top again.
final routes = RouteObserver<PageRoute<dynamic>>();

/// Soft lights that drift up and twinkle behind the title.
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
