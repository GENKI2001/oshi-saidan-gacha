// The big moments, made bigger: beams between goods, the quota gauge filling up and paying out,
// the stall's 「レア入荷！」 and the NEW! sticker.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'controller.dart';
import 'widgets.dart';

const _rainbow = [Color(0xFFFF6FA8), Color(0xFFFFB347), Color(0xFFFFE066), Color(0xFF7FE0C0), Color(0xFF8FB8FF), Color(0xFFC79BFF), Color(0xFFFF6FA8)];

/// Beams of light between goods: mint for a buff, pink-gold for a multiplier. Each one shoots
/// from its goods to the targets, then fades.
class BeamLayer extends StatefulWidget {
  final List<Beam> beams;
  final Offset Function(int cell) center;
  const BeamLayer({super.key, required this.beams, required this.center});
  @override
  State<BeamLayer> createState() => _BeamLayerState();
}

class _BeamLayerState extends State<BeamLayer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(painter: _BeamPainter(List.of(widget.beams), widget.center, DateTime.now().millisecondsSinceEpoch)),
  );
}

class _BeamPainter extends CustomPainter {
  final List<Beam> beams;
  final Offset Function(int) center;
  final int now;
  _BeamPainter(this.beams, this.center, this.now);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in beams) {
      final age = ((now - b.born) / 700).clamp(0.0, 1.0);
      final reach = Curves.easeOut.transform((age / 0.4).clamp(0.0, 1.0));
      final fade = age < 0.5 ? 1.0 : (1 - age) / 0.5;
      final from = center(b.from);
      final col = b.mult ? const Color(0xFFFF8FC0) : const Color(0xFF7FE0C0);
      for (final t in b.to) {
        final to = from + (center(t) - from) * reach;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = col.withValues(alpha: 0.75 * fade)
            ..strokeWidth = b.mult ? 9 : 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9 * fade)
            ..strokeWidth = b.mult ? 3 : 2
            ..strokeCap = StrokeCap.round,
        );
        // the hit
        if (reach >= 1) {
          final r = 10 + 22 * ((age - 0.4) / 0.6).clamp(0.0, 1.0);
          canvas.drawCircle(
            to,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = (b.mult ? const Color(0xFFFFE066) : col).withValues(alpha: fade),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BeamPainter o) => true;
}

/// The end of a song: the hearts pour into the gauge, drawn to scale (the marker is the quota,
/// the bar is what you have).
class QuotaFill extends StatefulWidget {
  final int hearts, quota;
  const QuotaFill({super.key, required this.hearts, required this.quota});
  @override
  State<QuotaFill> createState() => _QuotaFillState();
}

class _QuotaFillState extends State<QuotaFill> with TickerProviderStateMixin {
  late final _fill = AnimationController(vsync: this, duration: Duration(milliseconds: 700 + (math.min(widget.hearts / math.max(1, widget.quota), 3) * 350).round()))..forward();
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _fill.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_fill, _loop]),
    builder: (_, _) {
      final h = widget.hearts, q = widget.quota;
      final filled = h * Curves.easeOutCubic.transform(_fill.value);
      final shown = filled;
      final scale = math.max(1, math.max(h, q)).toDouble(); // the bar's full width
      final made = filled >= q;
      final glow = 0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi);
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const HeartIcon(size: 26),
              Text(' ${shown.round()}', style: outlined(30, made ? C.pink : C.ink, stroke: Colors.white, width: 5)),
              Text(' / $q', style: outlined(18, C.ink, stroke: Colors.white, width: 4)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: LayoutBuilder(
              builder: (_, bc) {
                final w = bc.maxWidth;
                final line = (w * q / scale).clamp(8.0, w);
                final right = (w * filled / scale).clamp(0.0, w);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      top: 2,
                      bottom: 2,
                      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: C.ink, width: 2.5))),
                    ),
                    if (right > 6)
                      Positioned(
                        left: 3,
                        top: 5,
                        bottom: 5,
                        width: right - 6,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(colors: made ? _rainbow : const [Color(0xFFFF8FC0), Color(0xFFFF5FA2)]),
                            boxShadow: made ? [BoxShadow(color: const Color(0xFFFFE066).withValues(alpha: 0.5 + 0.3 * glow), blurRadius: 8 + 6 * glow)] : null,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              height: 5,
                              margin: const EdgeInsets.fromLTRB(6, 3, 6, 0),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    // hearts flying in while it fills
                    if (_fill.value < 1)
                      for (var k = 0; k < 3; k++)
                        Positioned(
                          left: right - 14 - k * 16 * (1 - ((_fill.value * 7 + k * 0.3) % 1)),
                          top: -10 + 8 * math.sin((_fill.value * 7 + k) * math.pi),
                          child: Opacity(opacity: 0.85, child: HeartIcon(size: 16 - k * 3.0)),
                        ),
                    // the quota marker: a gold post centred on the bar, sticking out the same above and below
                    Positioned(
                      left: line - 3.5,
                      top: -2,
                      bottom: -2,
                      width: 7,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0A8), Color(0xFFFFC21E), Color(0xFFE6A700)]),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.5 + 0.4 * glow), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      );
    },
  );
}

/// A レア商品 on the stall's shelf: its card bursts with sparkles when it comes in, then keeps
/// shining — a band of light sweeping across it, a gold glow pulsing and stars twinkling at its corners.
class RareShine extends StatefulWidget {
  final int token;
  final Widget child;
  const RareShine({super.key, required this.token, required this.child});
  @override
  State<RareShine> createState() => _RareShineState();
}

class _RareShineState extends State<RareShine> with TickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void didUpdateWidget(RareShine old) {
    super.didUpdateWidget(old);
    if (widget.token != old.token) _in.forward(from: 0);
  }

  @override
  void dispose() {
    _in.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_in, _loop]),
    child: widget.child,
    builder: (_, child) {
      final t = _loop.value;
      final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      final pop = Curves.elasticOut.transform(_in.value);
      return Transform.scale(
        scale: 0.92 + 0.08 * pop,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // the pulsing gold glow behind the card
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.45 + 0.4 * glow), blurRadius: 10 + 12 * glow, spreadRadius: 1 + 3 * glow)],
                ),
              ),
            ),
            child!,
            // a band of light sweeping across
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1, -0.4),
                        end: const Alignment(1, 0.4),
                        colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
                        stops: [(t * 1.6 - 0.45).clamp(0.0, 1.0), (t * 1.6 - 0.3).clamp(0.0, 1.0), (t * 1.6 - 0.15).clamp(0.0, 1.0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // stars twinkling at the corners
            for (final (al, ph, sz) in const [(Alignment(-1.02, -1.25), 0.0, 18.0), (Alignment(1.0, -1.2), 0.35, 14.0), (Alignment(-0.98, 1.2), 0.6, 13.0), (Alignment(1.03, 1.22), 0.8, 17.0), (Alignment(0.1, -1.3), 0.2, 11.0)])
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: al,
                    child: Transform.scale(
                      scale: 0.3 + 0.9 * math.max(0, math.sin((t + ph) * 2 * math.pi)),
                      child: Icon(Icons.auto_awesome, size: sz, color: Colors.white, shadows: const [Shadow(color: Color(0xFFFFC21E), blurRadius: 8)]),
                    ),
                  ),
                ),
              ),
            // the burst as it comes in
            Positioned.fill(
              child: IgnorePointer(
                child: OverflowBox(
                  maxWidth: 360,
                  maxHeight: 220,
                  child: Sparkles(token: widget.token, size: 300, colors: const [Color(0xFFFFE14D), Colors.white, Color(0xFFFFC21E), Color(0xFFFF8FC0)], count: 30),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A goods seen for the first time: a pink star-shaped sticker slaps on with a shine.
class NewSticker extends StatelessWidget {
  final double size;
  const NewSticker({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 700),
    curve: Curves.elasticOut,
    builder: (_, t, c) => Transform.rotate(angle: 0.3 - 0.1 * t, child: Transform.scale(scale: t.clamp(0.0, 2.0), child: c)),
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarBurstPainter(),
        child: Center(child: Text('NEW!', style: outlined(size * 0.3, Colors.white, stroke: const Color(0xFFC2306E), width: 4))),
      ),
    ),
  );
}

class _StarBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final p = Path();
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12;
      final rr = k.isEven ? r : r * 0.8;
      final o = c + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    p.close();
    canvas.drawPath(p.shift(const Offset(0, 3)), Paint()..color = const Color(0x55C2306E));
    canvas.drawPath(p, Paint()..shader = const RadialGradient(colors: [Color(0xFFFF9CCB), Color(0xFFFF3F8E)]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(p, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_StarBurstPainter o) => false;
}

/// Little hearts (and a few stars) bursting out of a point and tumbling away: a few on every beat
/// of the count, a fountain of them on a round number or the final sum. Plays once per [token].
class HeartBurst extends StatefulWidget {
  final int token, count;
  final double size;
  const HeartBurst({super.key, required this.token, this.count = 6, this.size = 200});
  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void didUpdateWidget(HeartBurst old) {
    super.didUpdateWidget(old);
    if (widget.token != old.token) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => _c.value >= 1 ? SizedBox.square(dimension: widget.size) : CustomPaint(size: Size.square(widget.size), painter: _HeartBurstPainter(_c.value, widget.token, widget.count)),
    ),
  );
}

class _HeartBurstPainter extends CustomPainter {
  final double t;
  final int seed, count;
  _HeartBurstPainter(this.t, this.seed, this.count);

  static const _cols = [Color(0xFFFF4F96), Color(0xFFFF8FC0), Color(0xFFFFFFFF), Color(0xFFFFD54F), Color(0xFFFF6FA8)];

  static Path heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.9)
    ..cubicTo(c.dx - s * 1.3, c.dy, c.dx - s * 0.9, c.dy - s * 1.1, c.dx, c.dy - s * 0.35)
    ..cubicTo(c.dx + s * 0.9, c.dy - s * 1.1, c.dx + s * 1.3, c.dy, c.dx, c.dy + s * 0.9)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rnd = math.Random(seed * 7919 + 13);
    final r = size.shortestSide / 2;
    final e = Curves.easeOutCubic.transform(t);
    final fade = t < 0.55 ? 1.0 : (1 - t) / 0.45;
    for (var k = 0; k < count; k++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final dist = r * (0.35 + rnd.nextDouble() * 0.6) * e;
      final o = c + Offset(math.cos(a) * dist, math.sin(a) * dist + 26 * t * t); // a little gravity
      final s = (5 + rnd.nextDouble() * 6) * (1 - 0.3 * t);
      final col = _cols[k % _cols.length];
      if (k % 4 == 3) {
        // a twinkle star
        final st = Path();
        for (var j = 0; j < 8; j++) {
          final aa = j * math.pi / 4 + t * 3;
          final rr = j.isEven ? s * 1.4 : s * 0.45;
          final p = o + Offset(math.cos(aa), math.sin(aa)) * rr;
          j == 0 ? st.moveTo(p.dx, p.dy) : st.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(st..close(), Paint()..color = const Color(0xFFFFE14D).withValues(alpha: fade));
        continue;
      }
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate((rnd.nextDouble() - 0.5) * 1.2 * t);
      canvas.translate(-o.dx, -o.dy);
      canvas.drawPath(heart(o, s), Paint()..color = col.withValues(alpha: fade));
      canvas.drawPath(
        heart(o, s),
        Paint()
          ..color = (col == Colors.white ? const Color(0xFFFF8FC0) : Colors.white).withValues(alpha: 0.9 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeartBurstPainter o) => o.t != t;
}

/// A soft band of light gliding over a badge, again and again.
class Shine extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;
  const Shine({super.key, required this.child, this.radius = const BorderRadius.all(Radius.circular(22))});
  @override
  State<Shine> createState() => _ShineState();
}

class _ShineState extends State<Shine> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: widget.radius,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                final t = _c.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1, -0.6),
                      end: const Alignment(1, 0.6),
                      colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0)],
                      stops: [(t * 1.6 - 0.5).clamp(0.0, 1.0), (t * 1.6 - 0.35).clamp(0.0, 1.0), (t * 1.6 - 0.2).clamp(0.0, 1.0)],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

/// The hearts reached this song's quota mid-song: a pink ribbon (a gold one under it) sweeps across
/// the screen with 「♪ N曲目 ノルマ達成！」 and confetti, then sweeps on out. Both run well past the
/// screen's edges, so no end ever shows.
class QuotaCutIn extends StatelessWidget {
  final int token, song;
  const QuotaCutIn({super.key, required this.token, required this.song});
  @override
  Widget build(BuildContext context) {
    if (token == 0) return const SizedBox();
    final w = MediaQuery.sizeOf(context).width;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(token),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1900),
        builder: (_, t, _) {
          if (t >= 1) return const SizedBox();
          // in fast, hold, out fast (the gold one a beat behind)
          double slide(double lag) {
            final u = (t - lag).clamp(0.0, 1.0);
            return u < 0.18 ? -w * 1.6 * (1 - Curves.easeOutCubic.transform(u / 0.18)) : (u > 0.8 ? w * 1.6 * Curves.easeInCubic.transform(((u - 0.8) / 0.2).clamp(0.0, 1.0)) : 0.0);
          }
          final band = w * 3; // far wider than the screen
          return Center(
            child: OverflowBox(
              maxWidth: band,
              maxHeight: 420,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (t > 0.12) Sparkles(token: token, size: 380, colors: const [Color(0xFFFFE14D), Color(0xFFFF6FA8), Colors.white, Color(0xFF7FE0C0)], count: 44),
                  // the gold ribbon underneath, tilted the other way a little more
                  Transform.translate(
                    offset: Offset(-slide(0.03), 0),
                    child: Transform.rotate(
                      angle: -0.11,
                      child: Container(
                        width: band,
                        height: 178,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0A8), Color(0xFFFFC21E), Color(0xFFE6A700)]),
                          border: Border.symmetric(horizontal: BorderSide(color: Colors.white, width: 3)),
                        ),
                      ),
                    ),
                  ),
                  // the pink ribbon
                  Transform.translate(
                    offset: Offset(slide(0), 0),
                    child: Transform.rotate(
                      angle: -0.07,
                      child: Container(
                        width: band,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF9CCB), Color(0xFFFF4F96), Color(0xFFE53B84)]),
                          boxShadow: [BoxShadow(color: Color(0x66C2306E), blurRadius: 16, offset: Offset(0, 6))],
                        ),
                        child: Stack(
                          children: [
                            // a light sweeping along it
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
                                    stops: [(t * 1.5 - 0.2).clamp(0.0, 1.0), (t * 1.5 - 0.1).clamp(0.0, 1.0), t * 1.5 > 1 ? 1.0 : (t * 1.5).clamp(0.0, 1.0)],
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _edge(),
                                const SizedBox(height: 4),
                                Text(en ? '♪ Song $song' : '♪ $song曲目', style: outlined(20, Colors.white, stroke: const Color(0xFFC2306E), width: 5)),
                                Text(tr('ノルマ達成！'), style: outlined(46, Colors.white, stroke: const Color(0xFFC2306E), width: 7)),
                                const SizedBox(height: 4),
                                _edge(),
                              ],
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
        },
      ),
    );
  }

  /// A double white line with a row of little hearts between them.
  Widget _edge() => Column(
    children: [
      Container(height: 3, color: Colors.white),
      SizedBox(
        height: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < 40; k++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.favorite_rounded, size: 10, color: Colors.white.withValues(alpha: k.isEven ? 0.9 : 0.55)),
              ),
          ],
        ),
      ),
      Container(height: 1.5, color: Colors.white.withValues(alpha: 0.8)),
    ],
  );
}

/// A hanko stamp slammed on the result card: 「成功」 in pink-red or 「失敗」 in grey-blue, tilted, with
/// a double ring, a little smudge and a puff as it lands.
class ResultStamp extends StatelessWidget {
  final bool success;
  final double size;
  const ResultStamp({super.key, required this.success, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final col = success ? const Color(0xFFE5304F) : const Color(0xFF5E6E8A);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        builder: (_, t, _) {
          // waits a beat, then comes down hard
          final d = ((t - 0.35) / 0.25).clamp(0.0, 1.0);
          if (d == 0) return SizedBox.square(dimension: size);
          final land = Curves.easeIn.transform(d);
          final puff = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
          return SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (puff > 0 && puff < 1)
                  Container(
                    width: size * (1 + 0.6 * puff),
                    height: size * (1 + 0.6 * puff),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col.withValues(alpha: 0.5 * (1 - puff)), width: 4)),
                  ),
                Opacity(
                  opacity: (0.3 + 0.7 * land).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 2.4 - 1.4 * land,
                    child: Transform.rotate(
                      angle: -0.28,
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: _StampPainter(col),
                        child: SizedBox.square(
                          dimension: size,
                          child: Center(
                            child: _fitEn(
                              size,
                              Text(
                                tr(success ? '成功' : '失敗'),
                                style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w900, color: col, height: 1, letterSpacing: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final Color col;
  _StampPainter(this.col);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.96, Paint()..color = Colors.white.withValues(alpha: 0.55));
    final ink = Paint()
      ..color = col
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r * 0.94, ink..strokeWidth = r * 0.09);
    canvas.drawCircle(c, r * 0.78, ink..strokeWidth = r * 0.035);
    // little gaps in the ink, like a real stamp
    final rnd = math.Random(7);
    for (var k = 0; k < 9; k++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * (0.86 + rnd.nextDouble() * 0.1), r * 0.035, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(_StampPainter o) => o.col != col;
}

/// A cleared gacha's card: its own CLEAR stamp on the corner (the same pink stamp for every gacha,
/// with that gacha's idol popping out of the top — art/gen/stamp_*.txt), tilted a little, a soft shine
/// passing over it now and then.
class ClearStamp extends StatefulWidget {
  final String machine;
  final double size;
  const ClearStamp({super.key, required this.machine, this.size = 96});
  @override
  State<ClearStamp> createState() => _ClearStampState();
}

class _ClearStampState extends State<ClearStamp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset('assets/ui/stamp_${widget.machine}.png', width: widget.size, height: widget.size);
    return IgnorePointer(
      child: Transform.rotate(
        angle: 0.16,
        child: AnimatedBuilder(
          animation: _c,
          child: img,
          builder: (_, child) {
            final u = _c.value * 1.8 - 0.4;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (r) => LinearGradient(
                begin: const Alignment(-1, -0.6),
                end: const Alignment(1, 0.6),
                colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0)],
                stops: [(u - 0.15).clamp(0.0, 1.0), u.clamp(0.0, 1.0), (u + 0.15).clamp(0.0, 1.0)],
              ).createShader(r),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// English words are wider than the two kanji on the stamp: they shrink to fit inside it.
Widget _fitEn(double size, Widget text) => en ? Padding(padding: EdgeInsets.all(size * 0.16), child: FittedBox(fit: BoxFit.scaleDown, child: text)) : text;
