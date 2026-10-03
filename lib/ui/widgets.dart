// Small reusable pieces: colors, figure art, capsule, and the "juice"
// animations (bounce, hit, floating numbers, sunburst, sparkles, shake).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/defs.dart';
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
    Rarity.curse => const Color(0xFF7A6A6A),
  };
}

TextStyle outlined(double size, Color fill, {Color stroke = C.ink, double width = 4}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: fill, shadows: _ring(stroke, width));

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
class Shake extends StatelessWidget {
  final int token;
  final double px;
  final Widget child;
  const Shake({super.key, required this.token, required this.child, this.px = 8});

  @override
  Widget build(BuildContext context) {
    if (token == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, t, c) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 7) * px * (1 - t), math.cos(t * math.pi * 5) * px * 0.4 * (1 - t)),
        child: c,
      ),
      child: child,
    );
  }
}

/// A number that pops up and drifts away.
class FloatText extends StatelessWidget {
  final String text;
  final int kind;
  final VoidCallback? onDone;
  const FloatText(this.text, this.kind, {super.key, this.onDone});

  @override
  Widget build(BuildContext context) {
    final color = const [C.gold, C.mint, C.pink, C.red][kind];
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
                child: Text(text, style: outlined(size, color)),
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

/// Rarity as 1-4 stars (★4 in rainbow gold); つむぎの注意書き shows a 注意 chip instead.
class RarityStars extends StatelessWidget {
  final Rarity rarity;
  final double size;
  const RarityStars(this.rarity, {super.key, this.size = 20});

  static const _fill = [Color(0xFF9FD8FF), Color(0xFFFF8FC0), Color(0xFFC79BFF), Color(0xFFFFD34D)];

  @override
  Widget build(BuildContext context) {
    if (rarity == Rarity.curse) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: 1),
        decoration: BoxDecoration(
          color: C.rarity(rarity),
          borderRadius: BorderRadius.circular(size * 0.4),
          border: Border.all(color: C.ink, width: 1.5),
        ),
        child: Text(rarity.label, style: TextStyle(fontSize: size * 0.6, fontWeight: FontWeight.w900, color: Colors.white)),
      );
    }
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
    final k = rarity == Rarity.curse ? 4 : rarity.index;
    final glow = rarity != Rarity.curse && rarity.index >= Rarity.rare.index;
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        for (final (l, r) in const [(10.0, null), (null, 10.0)])
          Positioned(left: l, right: r, top: 9, child: const IgnorePointer(child: Icon(Icons.favorite_rounded, size: 13, color: C.pinkLine))),
        if (ribbon != null)
          Positioned(
            top: -48,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: Ribbon(ribbon!, width: 220))),
          ),
      ],
    );
  }
}

/// The pink ribbon banner (assets/ui/ui_ribbon.png) with a title on it.
class Ribbon extends StatelessWidget {
  final String text;
  final double width;
  const Ribbon(this.text, {super.key, this.width = 250});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 0.45,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Image.asset('assets/ui/ui_ribbon.png', width: width, fit: BoxFit.contain),
        Padding(
          padding: EdgeInsets.only(bottom: width * 0.06),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.2),
              child: Text(text, style: outlined(width * 0.085, Colors.white, stroke: const Color(0xFFD94E8A), width: 3.5)),
            ),
          ),
        ),
      ],
    ),
  );
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
