// Small reusable pieces: colors, figure art, capsule, and the "juice"
// animations (bounce, hit, floating numbers, sunburst, sparkles, shake).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/defs.dart';
import '../logic/modes.dart';
import 'sfx.dart';

class C {
  static const night = Color(0xFF241A4A);
  static const night2 = Color(0xFF4A2E66);
  static const cream = Color(0xFFFFF7FB);
  // the altar (祭壇): pastel pink with a deeper rose edge
  static const wood = Color(0xFFF9D7EA);
  static const woodDark = Color(0xFFD993BC);
  static const ink = Color(0xFF4A2A48);
  static const pink = Color(0xFFFF6FA3);
  static const pinkSoft = Color(0xFFFFD6E8);
  static const pinkLine = Color(0xFFF59AC3);
  static const lilac = Color(0xFFB98BEA);
  static const gold = Color(0xFFFFC93C);
  static const mint = Color(0xFF52D6B4);
  static const red = Color(0xFFFF5A5A);

  static Color rarity(Rarity r) => switch (r) {
    Rarity.normal => const Color(0xFF9FB4C8),
    Rarity.rare => const Color(0xFF4F9CFF),
    Rarity.epic => const Color(0xFFC25CFF),
    Rarity.legend => gold,
  };
}

TextStyle outlined(double size, Color fill, {Color stroke = C.ink, double width = 4}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: fill, shadows: _ring(stroke, width));

/// The numbers on the altar: [color] in a white rim (no dark outline, no blur).
TextStyle glowNumber(double size, Color color, {double width = 3}) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w900,
  color: color,
  shadows: _ring(Colors.white, width),
);

/// The hearts' own number style: hot pink.
TextStyle heartNumber(double size, {double width = 3}) => glowNumber(size, const Color(0xFFFF4F96), width: width);

/// A heading like a sticker: rose pink round the outside, white inside it, the
/// letters in a pink gradient, a soft rose drop below. Strokes trace the glyphs;
/// the little ring of copies under each stroke fills the tiny counters (壇, 置)
/// it would leave open. Three text layouts, so for headings, not per-frame text.
class StickerText extends StatelessWidget {
  final String text;
  final double size;
  const StickerText(this.text, {super.key, required this.size});

  static const rose = Color(0xFFF0639E);
  static const _fill = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF9CCB), Color(0xFFFF4F96)]);

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1.2);
    Text ring(Color c, double w, {Shadow? drop}) => Text(text, style: base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round
        ..color = c,
      shadows: [for (var k = 0; k < 12; k++) Shadow(offset: Offset.fromDirection(k * math.pi / 6, w / 4), color: c), ?drop],
    ));
    return Stack(
      children: [
        ring(rose, size * 0.42, drop: Shadow(offset: Offset(0, size * 0.12), color: const Color(0x8CE2457F))),
        ring(Colors.white, size * 0.23),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: _fill.createShader,
          child: Text(text, style: base.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

/// The round number badge that goes with [StickerText]: pink, a white rim, rose round it.
class StickerBadge extends StatelessWidget {
  final int n;
  const StickerBadge(this.n, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFA9CF), StickerText.rose]),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [
        const BoxShadow(color: StickerText.rose, spreadRadius: 2.5),
        BoxShadow(color: StickerText.rose.withValues(alpha: 0.5), offset: const Offset(0, 3), spreadRadius: 2.5),
      ],
    ),
    child: Text('$n', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
  );
}

/// A ring of copies around the glyphs makes a round outline. Unblurred on
/// purpose: blurred shadows cost a blur pass per copy and made play sluggish.
/// Thicker outlines get more copies so their curve stays smooth.
final _rings = <(Color, double), List<Shadow>>{};
List<Shadow> _ring(Color c, double w) => _rings[(c, w)] ??= () {
  final n = (w * 2.5).round().clamp(8, 16);
  return [
    for (var k = 0; k < n; k++) Shadow(offset: Offset(math.cos(k * 2 * math.pi / n), math.sin(k * 2 * math.pi / n)) * w / 2, color: c),
    Shadow(offset: Offset(0, w * 0.75), color: c),
  ];
}();

class FigureArt extends StatelessWidget {
  final FigureDef def;
  final double size;
  const FigureArt(this.def, {super.key, required this.size});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/figures/${def.id}.webp',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(def.emoji, style: TextStyle(fontSize: size * 0.6)),
      ),
    ),
  );
}

/// Restarts a little scale "boing" every time [token] changes.
class Bounce extends StatelessWidget {
  final int token;
  final double amount;
  final Widget child;
  const Bounce({super.key, required this.token, required this.child, this.amount = 0.28});

  @override
  Widget build(BuildContext context) {
    if (token == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      builder: (_, t, c) {
        final s = 1 + amount * math.sin(math.pi * t) * (1 - t * 0.4);
        final squash = 1 - 0.12 * math.sin(math.pi * t);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(s, s * squash + (1 - squash) * 0.3, 1),
          child: c,
        );
      },
      child: child,
    );
  }
}

/// Shakes sideways when [token] changes.
class Shake extends StatefulWidget {
  final int token;
  final double px;
  final Widget child;
  const Shake({super.key, required this.token, required this.child, this.px = 8});
  @override
  State<Shake> createState() => _ShakeState();
}

// The child stays the same element across shakes (a keyed rebuild used to restart every
// animation inside it, so an old 「×2!!」 banner played again when カイシメ shook the screen).
class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 1);

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.token != old.token && widget.token != 0) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, c) {
      final t = _c.value;
      return Transform.translate(
        offset: Offset(math.sin(t * math.pi * 7) * widget.px * (1 - t), math.cos(t * math.pi * 5) * widget.px * 0.4 * (1 - t)),
        child: c,
      );
    },
    child: widget.child,
  );
}

/// A number that pops up and drifts away.
class FloatText extends StatelessWidget {
  final String text;
  final int kind;
  final VoidCallback? onDone;
  const FloatText(this.text, this.kind, {super.key, this.onDone});

  @override
  Widget build(BuildContext context) {
    // hearts earned in pink, + buffs mint, × multipliers gold, losses red
    final color = const [Color(0xFFFF4F96), C.mint, Color(0xFFFFB300), C.red][kind];
    final size = kind == 2 ? 30.0 : 22.0;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        onEnd: onDone,
        builder: (_, t, _) {
          final pop = t < 0.18 ? Curves.easeOutBack.transform(t / 0.18) * 1.25 : 1.25 - (t - 0.18) * 0.3;
          return Opacity(
            opacity: (1 - math.pow(t, 3)).clamp(0, 1).toDouble(),
            child: Transform.translate(
              offset: Offset(0, -46 * Curves.easeOut.transform(t)),
              child: Transform.scale(
                scale: pop,
                child: Text(text, style: glowNumber(size, color, width: 3.5)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rotating rays behind a reveal.
class Sunburst extends StatefulWidget {
  final Color color;
  final double size;
  const Sunburst({super.key, required this.color, required this.size});
  @override
  State<Sunburst> createState() => _SunburstState();
}

class _SunburstState extends State<Sunburst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(size: Size.square(widget.size), painter: _RaysPainter(widget.color, _c.value * 2 * math.pi)),
  );
}

class _RaysPainter extends CustomPainter {
  final Color color;
  final double angle;
  _RaysPainter(this.color, this.angle);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final p = Paint()..color = Colors.white.withValues(alpha: 0.35);
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = angle + i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.09), c.dy + r * math.sin(a - 0.09))
        ..lineTo(c.dx + r * math.cos(a + 0.09), c.dy + r * math.sin(a + 0.09))
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter o) => o.angle != angle || o.color != color;
}

/// One burst of confetti-like sparkles, replayed when [token] changes.
class Sparkles extends StatelessWidget {
  final int token;
  final double size;
  final List<Color> colors;
  final int count;
  const Sparkles({super.key, required this.token, required this.size, required this.colors, this.count = 26});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(token),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        builder: (_, t, _) => CustomPaint(size: Size.square(size), painter: _SparklePainter(t, token, colors, count)),
      ),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  final double t;
  final int seed, count;
  final List<Color> colors;
  _SparklePainter(this.t, this.seed, this.colors, this.count);
  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final rnd = math.Random(seed);
    final c = size.center(Offset.zero);
    for (var i = 0; i < count; i++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final sp = 0.35 + rnd.nextDouble() * 0.65;
      final d = size.width / 2 * sp * Curves.easeOutCubic.transform(t);
      final pos = c + Offset(math.cos(a), math.sin(a)) * d + Offset(0, 60 * t * t);
      final s = (5 + rnd.nextDouble() * 7) * (1 - t);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: 1 - t);
      if (i.isEven) {
        canvas.drawCircle(pos, s * 0.6, paint);
      } else {
        final path = Path();
        for (var k = 0; k < 8; k++) {
          final rr = k.isEven ? s : s * 0.35;
          final aa = k * math.pi / 4 + t * 4;
          final p = pos + Offset(math.cos(aa), math.sin(aa)) * rr;
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SparklePainter o) => o.t != t;
}

/// Rarity as 1-4 stars (★4 in rainbow gold).
class RarityStars extends StatelessWidget {
  final Rarity rarity;
  final double size;
  const RarityStars(this.rarity, {super.key, this.size = 20});

  static const _fill = [Color(0xFF9FD8FF), Color(0xFFFF8FC0), Color(0xFFC79BFF), Color(0xFFFFD34D)];

  @override
  Widget build(BuildContext context) {
    final n = rarity.index + 1;
    final col = _fill[rarity.index];
    Widget star(bool on) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.star_rounded, size: size * 1.22, color: on ? C.ink : const Color(0x664A2A48)),
          on && n == 4
              ? ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFF8FC0), Color(0xFFFFD34D), Color(0xFF8FF0C8), Color(0xFF9FC8FF)]).createShader(r),
                  child: Icon(Icons.star_rounded, size: size * 0.9, color: Colors.white),
                )
              : Icon(Icons.star_rounded, size: size * 0.9, color: on ? col : const Color(0xFFEDE3F0)),
          if (on) Positioned(left: size * 0.33, top: size * 0.27, child: Container(width: size * 0.13, height: size * 0.13, decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle))),
        ],
      ),
    );
    return Semantics(
      label: '星$n',
      child: Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < 4; k++) star(k < n)]),
    );
  }
}

/// A cartoon puff of smoke that billows out and fades when [token] changes.
class Smoke extends StatelessWidget {
  final int token;
  final double size;
  const Smoke({super.key, required this.token, required this.size});

  @override
  Widget build(BuildContext context) {
    if (token == 0) return const SizedBox();
    return IgnorePointer(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(token),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          builder: (_, t, _) => CustomPaint(size: Size.square(size), painter: _SmokePainter(t, token)),
        ),
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  final double t;
  final int seed;
  _SmokePainter(this.t, this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final rnd = math.Random(seed * 7919);
    final c = size.center(Offset.zero);
    final r0 = size.width / 2;
    final grow = Curves.easeOutCubic.transform(t);
    // fully thick for the first third, then thins out
    final fade = t < 0.35 ? 1.0 : 1 - Curves.easeIn.transform((t - 0.35) / 0.65);
    const n = 11;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < n; i++) {
        final a = i / n * 2 * math.pi + rnd.nextDouble() * 0.5;
        final d = r0 * (0.15 + 0.4 * grow) * (0.7 + rnd.nextDouble() * 0.5);
        final pos = c + Offset(math.cos(a) * d, math.sin(a) * d * 0.8 - r0 * 0.25 * t);
        final rr = r0 * (0.18 + 0.22 * grow) * (0.8 + rnd.nextDouble() * 0.4);
        if (pass == 0) {
          // soft grey outline under the white puffs
          canvas.drawCircle(pos, rr + 2.5, Paint()..color = const Color(0xFFB8B0C8).withValues(alpha: 0.9 * fade));
        } else {
          canvas.drawCircle(pos, rr, Paint()..color = Colors.white.withValues(alpha: 0.95 * fade));
          canvas.drawCircle(
            pos - Offset(rr * 0.3, rr * 0.3),
            rr * 0.35,
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6 * fade),
          );
        }
      }
    }
    // the core covers the middle while the figure swaps in
    canvas.drawCircle(c, r0 * (0.3 + 0.15 * grow), Paint()..color = Colors.white.withValues(alpha: 0.95 * fade));
  }

  @override
  bool shouldRepaint(_SmokePainter o) => o.t != t;
}

/// A capsule; its top color hints the rarity inside (the "omen").
class Capsule extends StatelessWidget {
  final Rarity rarity;
  final double size;
  final double split; // 0 closed → 1 halves flown away
  const Capsule({super.key, required this.rarity, required this.size, this.split = 0});

  @override
  Widget build(BuildContext context) {
    final col = C.rarity(rarity);
    final k = rarity.index;
    final glow = rarity.index >= Rarity.rare.index;
    final w = size * 1.12;
    return SizedBox(
      width: size * 1.6,
      height: size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow && split == 0)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: col.withValues(alpha: 0.8), blurRadius: size * (rarity.index * 0.18), spreadRadius: size * 0.05 * rarity.index)],
              ),
            ),
          // the two halves of the capsule art (art/slice.py cuts them at the seam)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(-size * 0.5 * split, -size * 0.7 * split),
                child: Transform.rotate(
                  angle: -1.2 * split,
                  child: Opacity(opacity: (1 - split).clamp(0, 1), child: Image.asset('assets/ui/capsule_${k}_top.png', width: w, fit: BoxFit.fitWidth)),
                ),
              ),
              Transform.translate(
                offset: Offset(size * 0.4 * split, size * 0.6 * split),
                child: Transform.rotate(
                  angle: 0.9 * split,
                  child: Opacity(opacity: (1 - split).clamp(0, 1), child: Image.asset('assets/ui/capsule_${k}_bot.png', width: w, fit: BoxFit.fitWidth)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chunky candy button.
class PopButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;
  final String? sound;

  /// Looks disabled but still takes taps (e.g. to point the player elsewhere).
  final bool dimmed;

  /// Drawn after the label (e.g. a coin icon and a price).
  final Widget? trailing;
  const PopButton(
    this.label, {
    super.key,
    this.onTap,
    this.dimmed = false,
    this.trailing,
    this.sound = 'tap',
    this.color = C.pink,
    this.fontSize = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
  });
  @override
  State<PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<PopButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final col = enabled && !widget.dimmed ? widget.color : Colors.grey.shade400;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              if (widget.sound != null) Sfx.play(widget.sound!);
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: C.ink, width: 3),
          boxShadow: [if (!_down) BoxShadow(color: Color.lerp(col, C.ink, 0.55)!, offset: const Offset(0, 4))],
        ),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(37),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
            // candy gloss: light on top, the color in the middle, a little deeper at the bottom
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(col, Colors.white, 0.45)!, col, Color.lerp(col, C.ink, 0.12)!],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: widget.trailing == null
              ? Text(widget.label, textAlign: TextAlign.center, style: outlined(widget.fontSize, Colors.white, stroke: Color.lerp(col, C.ink, 0.6)!, width: 3))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.label, style: outlined(widget.fontSize, Colors.white, stroke: Color.lerp(col, C.ink, 0.6)!, width: 3)),
                    widget.trailing!,
                  ],
                ),
        ),
      ),
    );
  }
}

/// A soft pink card: plum outline, a pink lace rim inside, tiny hearts in the
/// corners, and an optional ribbon with a title on top.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final String? ribbon;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = C.cream, this.ribbon});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: color,
        gradient: color == C.cream ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFFFF0F7)]) : null,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: C.ink, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x66220A2A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: padding + EdgeInsets.only(top: ribbon != null ? 34 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: C.pinkLine.withValues(alpha: 0.7), width: 2),
        ),
        child: child,
      ),
    );
    // passthrough: given a fixed size (a page, a Positioned.fill) the card fills it instead of
    // shrinking to its contents
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        card,
        for (final (l, r) in const [(10.0, null), (null, 10.0)])
          Positioned(left: l, right: r, top: 9, child: const IgnorePointer(child: Icon(Icons.favorite_rounded, size: 13, color: C.pinkLine))),
        if (ribbon != null)
          Positioned(
            top: -48,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: Ribbon(ribbon!, width: 240))),
          ),
      ],
    );
  }
}

/// The pink ribbon banner (assets/ui/ui_ribbon.png) with a title on it.
/// The band arches up in the middle, so the title is laid along its centre line.
class Ribbon extends StatelessWidget {
  final String text;
  final double width;
  const Ribbon(this.text, {super.key, this.width = 250});

  /// The art is 512x232.
  static const aspect = 232 / 512;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(outlined(width * 0.085, Colors.white, stroke: const Color(0xFFD94E8A), width: 3.5));
    return SizedBox(
      width: width,
      height: width * aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/ui/ui_ribbon.png', fit: BoxFit.fill),
          CustomPaint(painter: _ArcTextPainter(text, style)),
        ],
      ),
    );
  }
}

/// Draws [text] one glyph at a time along the ribbon band's centre line.
class _ArcTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  _ArcTextPainter(this.text, this.style);

  // the band's centre line, measured from the stitches in ui_ribbon.png:
  // y/h = a·(x/w − ½)² + b·(x/w − ½) + c
  static const _a = 1.395, _b = -0.0166, _c = 0.314;
  // the flat front of the band (the folds at both ends stay clear)
  static const _span = 0.52;

  double _y(double u) => _a * (u - 0.5) * (u - 0.5) + _b * (u - 0.5) + _c;
  double _slope(double u) => 2 * _a * (u - 0.5) + _b;

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.characters.toList();
    TextPainter glyph(String ch, double scale) => TextPainter(
      text: TextSpan(text: ch, style: style.copyWith(fontSize: style.fontSize! * scale, shadows: [for (final s in style.shadows ?? const <Shadow>[]) Shadow(color: s.color, offset: s.offset * scale)])),
      textDirection: TextDirection.ltr,
    )..layout();
    var scale = 1.0;
    var gs = [for (final ch in chars) glyph(ch, scale)];
    var total = gs.fold(0.0, (a, g) => a + g.width);
    if (total > size.width * _span) {
      scale = size.width * _span / total;
      gs = [for (final ch in chars) glyph(ch, scale)];
      total = gs.fold(0.0, (a, g) => a + g.width);
    }
    var x = (size.width - total) / 2;
    for (final g in gs) {
      final cx = x + g.width / 2, u = cx / size.width;
      canvas.save();
      canvas.translate(cx, _y(u) * size.height);
      canvas.rotate(math.atan(_slope(u) * size.height / size.width));
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      x += g.width;
    }
  }

  @override
  bool shouldRepaint(_ArcTextPainter o) => o.text != text || o.style != style;
}

/// The glossy pink heart (the currency).
class HeartIcon extends StatelessWidget {
  final double size;
  const HeartIcon({super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => Image.asset('assets/ui/ui_heart.png', width: size, height: size);
}

/// The machine art, recolored for each machine kind.
class MachineArt extends StatelessWidget {
  final double hue;
  final double? height;
  final bool locked;
  final Alignment alignment;
  const MachineArt({super.key, required this.hue, this.height, this.locked = false, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset('assets/ui/machine.png', height: height, fit: BoxFit.contain, alignment: alignment);
    if (hue != 0) img = ColorFiltered(colorFilter: ColorFilter.matrix(hueMatrix(hue)), child: img);
    if (locked) {
      img = ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFF3A2D52), BlendMode.srcIn), child: img);
    }
    return img;
  }
}

List<double> hueMatrix(double degrees) {
  final a = degrees * math.pi / 180, c = math.cos(a), s = math.sin(a);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return [
    lr + c * (1 - lr) + s * -lr,
    lg + c * -lg + s * -lg,
    lb + c * -lb + s * (1 - lb),
    0,
    0,
    lr + c * -lr + s * 0.143,
    lg + c * (1 - lg) + s * 0.140,
    lb + c * -lb + s * -0.283,
    0,
    0,
    lr + c * -lr + s * -(1 - lr),
    lg + c * -lg + s * lg,
    lb + c * (1 - lb) + s * lb,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// 難易度: five hearts filled up to [level] (1..5) and its name.
class DifficultyBadge extends StatelessWidget {
  final int level;
  final double size;
  const DifficultyBadge(this.level, {super.key, this.size = 16});

  static const colors = [C.mint, C.mint, Color(0xFFFFB238), Color(0xFFFF7A3D), C.red, Color(0xFF9B2BD9)];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('難易度 ', style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w900, color: C.ink)),
      for (var i = 1; i <= 5; i++)
        Icon(i <= level ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: size, color: i <= level ? colors[level] : const Color(0xFFD9C3D8)),
      const SizedBox(width: 4),
      Text(difficultyLabel[level], style: outlined(size, colors[level], stroke: Colors.white, width: 3)),
    ],
  );
}

/// The header every sub-screen shares: a back arrow, the title on a ribbon in the middle,
/// and an optional count on a little pill under it.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? note;
  final IconData icon;
  final Widget? trailing; // e.g. a menu button on the right, at most 48 wide
  const ScreenHeader(this.title, {super.key, this.note, this.icon = Icons.arrow_back_rounded, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(icon, color: Colors.white, size: 30, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)]),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ribbon(title, width: 210),
              if (note != null)
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                    decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.ink, width: 2)),
                    child: Text(note!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.ink)),
                  ),
                ),
            ],
          ),
        ),
        // as wide as the arrow, so the ribbon sits in the middle
        SizedBox(width: 48, child: trailing == null ? null : Padding(padding: const EdgeInsets.only(top: 4), child: trailing)),
      ],
    ),
  );
}

/// [ScreenHeader] as an app bar over the screen's own background.
PreferredSizeWidget ribbonBar(String title, {String? note}) => PreferredSize(
  preferredSize: Size.fromHeight(note == null ? 104 : 132),
  child: SafeArea(bottom: false, child: ScreenHeader(title, note: note)),
);

/// A round cream button with an icon (the menu buttons, the sound switches).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size, padding;
  const RoundIconButton(this.icon, {super.key, this.onTap, this.size = 24, this.padding = 7});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: C.cream,
        shape: BoxShape.circle,
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Icon(icon, color: C.ink, size: size),
    ),
  );
}

/// A goods stacked on itself: a soft rotating halo of light behind it, brighter and more
/// colourful with each stack (×2 gold, ×3 pink-gold, ×4 and up rainbow).
class StackAura extends StatefulWidget {
  final int level;
  const StackAura({super.key, required this.level});
  @override
  State<StackAura> createState() => _StackAuraState();
}

class _StackAuraState extends State<StackAura> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(painter: _AuraPainter(_c.value, widget.level)),
  );
}

class _AuraPainter extends CustomPainter {
  final double t;
  final int level;
  _AuraPainter(this.t, this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.5;
    final colors = level >= 4
        ? const [Color(0xFFFF6FA8), Color(0xFFFFE066), Color(0xFF7FE0C0), Color(0xFF8FB8FF), Color(0xFFC79BFF), Color(0xFFFF6FA8)]
        : level == 3
        ? const [Color(0xFFFFE066), Color(0xFFFF8FC0), Color(0xFFFFE066), Color(0xFFFF8FC0), Color(0xFFFFE066)]
        : const [Color(0xFFFFE9A0), Color(0xFFFFC21E), Color(0xFFFFE9A0), Color(0xFFFFC21E), Color(0xFFFFE9A0)];
    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2);
    // the glow
    canvas.drawCircle(
      c,
      r * 1.15 * pulse,
      Paint()
        ..shader = RadialGradient(colors: [colors[1].withValues(alpha: 0.8), colors[1].withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r * 1.15))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // a turning ring of light
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * math.pi);
    canvas.drawCircle(
      Offset.zero,
      r * 0.98,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + level * 0.6
        ..shader = SweepGradient(colors: colors).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // little sparkles riding the ring (one more per stack)
    final p = Paint()..color = Colors.white;
    for (var k = 0; k < level + 1; k++) {
      final a = k * 2 * math.pi / (level + 1);
      final o = Offset(math.cos(a), math.sin(a)) * r * 0.98;
      final s = r * 0.07 * (0.7 + 0.3 * math.sin(t * 2 * math.pi * 3 + k));
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - s * 2)
          ..lineTo(o.dx + s * 0.5, o.dy - s * 0.5)
          ..lineTo(o.dx + s * 2, o.dy)
          ..lineTo(o.dx + s * 0.5, o.dy + s * 0.5)
          ..lineTo(o.dx, o.dy + s * 2)
          ..lineTo(o.dx - s * 0.5, o.dy + s * 0.5)
          ..lineTo(o.dx - s * 2, o.dy)
          ..lineTo(o.dx - s * 0.5, o.dy - s * 0.5)
          ..close(),
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter o) => o.t != t || o.level != level;
}

/// The goods in hand is already on this cell: a blinking gold frame with twinkles, so you can
/// see at a glance where it would stack.
class SameGlow extends StatefulWidget {
  final double size;
  const SameGlow({super.key, required this.size});
  @override
  State<SameGlow> createState() => _SameGlowState();
}

class _SameGlowState extends State<SameGlow> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final v = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                // calmer than it was: a soft gold pulse, not a strobe
                border: Border.all(color: Color.lerp(const Color(0xFFFFD54F), const Color(0xFFFFF3C4), v)!.withValues(alpha: 0.75), width: 2),
                boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.12 + 0.15 * v), blurRadius: 3 + 3 * v)],
              ),
            ),
          ),
          for (final (x, y, ph) in const [(0.1, 0.12, 0.0), (0.88, 0.86, 0.5)])
            Positioned(
              left: widget.size * x - 7,
              top: widget.size * y - 7,
              child: Opacity(
                opacity: (0.35 + 0.45 * math.sin((_c.value + ph) * 2 * math.pi)).clamp(0.0, 1.0),
                child: const Icon(Icons.auto_awesome, size: 11, color: Colors.white, shadows: [Shadow(color: Color(0xFFFFC21E), blurRadius: 4)]),
              ),
            ),
        ],
      );
    },
  );
}

/// The moment a goods is stacked: light spirals in and charges it up (ギュイーン), then it
/// bursts in a white flash with a ring and stars flying out (ピカーン). Plays once per [token].
class PowerUpBurst extends StatefulWidget {
  final int token;
  final double size;
  final int level; // the new stack: the burst grows with it
  const PowerUpBurst({super.key, required this.token, required this.size, this.level = 2});
  @override
  State<PowerUpBurst> createState() => _PowerUpBurstState();
}

class _PowerUpBurstState extends State<PowerUpBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    if (widget.token > 0) _c.forward();
  }

  @override
  void didUpdateWidget(PowerUpBurst old) {
    super.didUpdateWidget(old);
    if (widget.token != old.token) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => _c.value == 0 || _c.value == 1 ? const SizedBox() : CustomPaint(size: Size.square(widget.size), painter: _BurstPainter(_c.value, widget.level)),
  );
}

class _BurstPainter extends CustomPainter {
  final double t;
  final int level;
  _BurstPainter(this.t, this.level);

  static const _cols = [Color(0xFFFFE066), Color(0xFFFF8FC0), Color(0xFF8FE8FF), Color(0xFFC79BFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const charge = 0.5; // ギュイーン until here, then ピカーン
    if (t < charge) {
      final u = t / charge;
      // streaks of light spiralling in, faster and tighter as it charges
      for (var k = 0; k < 10; k++) {
        final a = k * math.pi / 5 + u * u * math.pi * 3;
        final d = r * (1 - u) * 0.95 + r * 0.12;
        final p0 = c + Offset(math.cos(a), math.sin(a)) * d;
        final p1 = c + Offset(math.cos(a - 0.5), math.sin(a - 0.5)) * (d + r * 0.22 * (1 - u));
        canvas.drawLine(
          p1,
          p0,
          Paint()
            ..color = _cols[k % _cols.length].withValues(alpha: 0.4 + 0.6 * u)
            ..strokeWidth = 3 + 3 * u
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }
      // the goods glows hotter
      canvas.drawCircle(
        c,
        r * (0.3 + 0.25 * u),
        Paint()
          ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9 * u), const Color(0xFFFFE066).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r * 0.55))
          ..blendMode = BlendMode.plus,
      );
      return;
    }
    final u = (t - charge) / (1 - charge);
    final fade = 1 - u;
    // the flash
    canvas.drawCircle(
      c,
      r * (0.4 + 0.7 * u),
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: fade), const Color(0xFFFFE066).withValues(alpha: 0.6 * fade), Colors.transparent], stops: const [0, 0.45, 1])
            .createShader(Rect.fromCircle(center: c, radius: r * (0.4 + 0.7 * u)))
        ..blendMode = BlendMode.plus,
    );
    // a shock ring
    canvas.drawCircle(
      c,
      r * (0.35 + 0.75 * Curves.easeOut.transform(u)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * fade + 1
        ..color = Color.lerp(const Color(0xFFFFE066), const Color(0xFFFF8FC0), u)!.withValues(alpha: fade),
    );
    // rays
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4 + 0.2;
      final d0 = r * (0.3 + 0.4 * u), d1 = d0 + r * 0.35 * fade;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * d0,
        c + Offset(math.cos(a), math.sin(a)) * d1,
        Paint()
          ..color = Colors.white.withValues(alpha: fade)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    // stars flying out (more for a bigger stack)
    final n = 6 + level * 2;
    for (var k = 0; k < n; k++) {
      final a = k * 2 * math.pi / n + 0.4;
      final d = r * (0.25 + 0.85 * Curves.easeOut.transform(u));
      final o = c + Offset(math.cos(a), math.sin(a)) * d;
      final s = r * 0.075 * fade + 1;
      final star = Path()
        ..moveTo(o.dx, o.dy - s * 2)
        ..lineTo(o.dx + s * 0.5, o.dy - s * 0.5)
        ..lineTo(o.dx + s * 2, o.dy)
        ..lineTo(o.dx + s * 0.5, o.dy + s * 0.5)
        ..lineTo(o.dx, o.dy + s * 2)
        ..lineTo(o.dx - s * 0.5, o.dy + s * 0.5)
        ..lineTo(o.dx - s * 2, o.dy)
        ..lineTo(o.dx - s * 0.5, o.dy - s * 0.5)
        ..close();
      canvas.drawPath(star, Paint()..color = _cols[k % _cols.length].withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}
