// The live venue behind the game: four paintings of the same hall (quiet →
// warming up → hot → MAX) crossfaded with the hype, and on top of them
// hearts drifting up from the crowd, swaying penlights, light beams and
// confetti that all grow with it.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'idol_widgets.dart';

class VenueBackground extends StatefulWidget {
  /// 0 (the live just started) .. 1 (the hall is going wild).
  final double hype;

  /// Bumped for a burst of confetti (a song cleared, a ★4).
  final int burst;
  const VenueBackground({super.key, required this.hype, this.burst = 0});

  @override
  State<VenueBackground> createState() => _VenueBackgroundState();
}

class _VenueBackgroundState extends State<VenueBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  int _burst = 0;
  double _burstAt = -10;

  @override
  void didUpdateWidget(VenueBackground old) {
    super.didUpdateWidget(old);
    if (widget.burst != _burst) {
      _burst = widget.burst;
      _burstAt = _time;
    }
  }

  double get _time => (_c.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // the hall warms up (and cools down) smoothly, not in steps
    tween: Tween(end: widget.hype.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 1400),
    curve: Curves.easeInOut,
    builder: (_, h, _) {
      final x = h * 3; // 0..3 across the four paintings
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/ui/venue_0.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter, gaplessPlayback: true),
          for (var k = 1; k <= 3; k++)
            if (x > k - 1)
              Opacity(
                opacity: (x - (k - 1)).clamp(0.0, 1.0),
                child: Image.asset('assets/ui/venue_$k.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter, gaplessPlayback: true),
              ),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(painter: _VenueFx(h, _time, _time - _burstAt)),
            ),
          ),
        ],
      );
    },
  );
}

class _VenueFx extends CustomPainter {
  final double hype, t, sinceBurst;
  _VenueFx(this.hype, this.t, this.sinceBurst);

  static final _colors = [for (final m in ['ひなた', 'しずく', 'こはる', 'よる', 'もも']) idolColor[m]!];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // light beams sweeping from the stage (once it warms up)
    if (hype > 0.3) {
      final a = ((hype - 0.3) / 0.7).clamp(0.0, 1.0);
      for (var k = 0; k < 4; k++) {
        final from = Offset(w * (0.15 + 0.23 * k), h * 0.05);
        final ang = math.pi / 2 + 0.55 * math.sin(t * (0.5 + 0.13 * k) + k * 1.7);
        final to = from + Offset(math.cos(ang), math.sin(ang)) * h * 0.95;
        final perp = Offset(-math.sin(ang), math.cos(ang)) * (w * 0.09);
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx + perp.dx, to.dy + perp.dy)
          ..lineTo(to.dx - perp.dx, to.dy - perp.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_colors[k].withValues(alpha: 0.22 * a), _colors[k].withValues(alpha: 0)],
            ).createShader(Rect.fromPoints(from, to))
            ..blendMode = BlendMode.plus,
        );
      }
    }

    // penlights swaying above the crowd at the bottom: more of them, and faster, as it heats up
    final lights = (6 + hype * 34).round();
    final rnd = math.Random(3);
    for (var i = 0; i < lights; i++) {
      final bx = rnd.nextDouble() * w;
      final by = h * (0.78 + rnd.nextDouble() * 0.2);
      final phase = rnd.nextDouble() * math.pi * 2;
      final col = _colors[i % 5];
      final sway = math.sin(t * (1.6 + hype * 2.2) + phase) * 0.35;
      final len = 18 + rnd.nextDouble() * 10;
      final tip = Offset(bx + math.sin(sway) * len, by - math.cos(sway) * len);
      canvas.drawLine(
        Offset(bx, by),
        tip,
        Paint()
          ..color = col.withValues(alpha: 0.85)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        tip,
        9,
        Paint()
          ..color = col.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // hearts drifting up from the crowd
    final hearts = (4 + hype * 26).round();
    final hr = math.Random(9);
    for (var i = 0; i < hearts; i++) {
      final speed = 0.04 + hr.nextDouble() * 0.05 + hype * 0.04;
      final p = (hr.nextDouble() + t * speed) % 1.0;
      final x = hr.nextDouble() * w + math.sin(t * 1.3 + i) * 14;
      final y = h * (0.95 - p * 0.9);
      final s = 7 + hr.nextDouble() * 9 + hype * 5;
      final fade = math.min(1.0, math.min(p * 5, (1 - p) * 3));
      _heart(canvas, Offset(x, y), s, _colors[(i + 4) % 5].withValues(alpha: 0.55 * fade));
    }

    // confetti: always at MAX, and in a burst after a song or a ★3/★4
    final burst = sinceBurst >= 0 && sinceBurst < 4 ? (1 - sinceBurst / 4) : 0.0;
    final confetti = ((hype > 0.82 ? (hype - 0.82) / 0.18 * 40 : 0) + burst * 70).round();
    final cr = math.Random(17);
    for (var i = 0; i < confetti; i++) {
      final speed = 0.08 + cr.nextDouble() * 0.12;
      final p = (cr.nextDouble() + t * speed) % 1.0;
      final x = cr.nextDouble() * w + math.sin(t * 2 + i) * 20;
      final y = p * h;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (2 + cr.nextDouble() * 4) + i);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -2, 8, 4),
        Paint()..color = [...(_colors), const Color(0xFFFFE27A), Colors.white][i % 7].withValues(alpha: 0.9),
      );
      canvas.restore();
    }
  }

  void _heart(Canvas canvas, Offset c, double s, Color col) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.35)
      ..cubicTo(c.dx - s * 1.1, c.dy - s * 0.3, c.dx - s * 0.45, c.dy - s * 1.0, c.dx, c.dy - s * 0.4)
      ..cubicTo(c.dx + s * 0.45, c.dy - s * 1.0, c.dx + s * 1.1, c.dy - s * 0.3, c.dx, c.dy + s * 0.35)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
  }

  @override
  bool shouldRepaint(_VenueFx o) => o.t != t || o.hype != hype;
}
