// The "juice" animations: bounce, shake, floating numbers, sunburst, sparkles, smoke, and the
// glow of a stacked goods.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

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

/// Gently breathes in and out, forever (a button waiting to be pressed, the goods in hand).
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
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

/// Rocks side to side, hard then softly, over and over (a capsule waiting to be opened).
class Wobble extends StatefulWidget {
  final Widget child;
  final double strength;
  const Wobble({super.key, required this.child, required this.strength});
  @override
  State<Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<Wobble> with SingleTickerProviderStateMixin {
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
