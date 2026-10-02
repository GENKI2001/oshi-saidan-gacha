// Tutorial coach marks: the screen darkens except a cut-out around one control,
// with a message next to it. Only the cut-out takes taps (action steps), or a tap
// anywhere moves on (info steps).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'widgets.dart';

class CoachLayer extends StatefulWidget {
  /// What to cut out; its box is re-measured every frame (things pulse and slide).
  final List<GlobalKey> targets;
  final String text;
  final bool circle;

  /// Info steps: a tap anywhere calls this. Action steps leave it null and let
  /// taps inside the cut-out reach the control underneath.
  final VoidCallback? onTap;
  const CoachLayer({super.key, required this.targets, required this.text, this.circle = false, this.onTap});

  @override
  State<CoachLayer> createState() => _CoachLayerState();
}

class _CoachLayerState extends State<CoachLayer> with SingleTickerProviderStateMixin {
  late final _tick = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  /// The entrance: a short pause, then the dim fades in as the hole closes in.
  static const _pause = 0.4, _intro = 1.0; // seconds
  final _clock = Stopwatch()..start();
  double get _t => Curves.easeOutCubic.transform(((_clock.elapsedMilliseconds / 1000 - _pause) / (_intro - _pause)).clamp(0.0, 1.0));
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _tick.addListener(_measure);
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _measure() {
    final me = context.findRenderObject() as RenderBox?;
    if (me == null || !me.hasSize) return;
    Rect? r;
    for (final k in widget.targets) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final tl = me.globalToLocal(box.localToGlobal(Offset.zero));
      final rr = tl & box.size;
      r = r == null ? rr : r.expandToInclude(rr);
    }
    // redraw every frame: the entrance and the ring pulse animate even when the target is still
    setState(() => _hole = r);
  }

  @override
  Widget build(BuildContext context) {
    final hole = _hole;
    return LayoutBuilder(
      builder: (_, bc) {
        final size = bc.biggest;
        if (hole == null) {
          // target not on screen yet: just hold input
          return const SizedBox.expand(child: AbsorbPointer());
        }
        final target = widget.circle ? Rect.fromCircle(center: hole.center, radius: hole.longestSide / 2 + 10) : hole.inflate(8);
        final t = _t;
        // the hole starts as the whole screen and closes onto the target
        // the hole keeps its shape while it closes in: scaled about its own centre,
        // from big enough to clear the whole screen down to the target
        final c = target.center;
        final far = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
        final start = widget.circle
            ? far.map((p) => (p - c).distance).reduce(math.max) / (target.width / 2)
            : far.map((p) => math.max((p.dx - c.dx).abs() * 2 / target.width, (p.dy - c.dy).abs() * 2 / target.height)).reduce(math.max) *
                  1.15;
        final k = start + (1 - start) * t;
        final cut = Rect.fromCenter(center: c, width: target.width * k, height: target.height * k);
        final pulse = (0.5 + 0.5 * math.sin(_tick.value * 2 * math.pi)) * t;
        final below = target.center.dy < size.height * 0.55;
        return Stack(
          children: [
            // the dim with the hole
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _HolePainter(cut, widget.circle, pulse, t, k))),
            ),
            // absorb taps everywhere except the hole
            ..._blockers(size, target),
            // nothing gets through until the highlight has settled
            if (t < 1) const Positioned.fill(child: AbsorbPointer()),
            if (widget.onTap != null)
              Positioned.fromRect(
                rect: cut,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap),
              ),
            // the message
            Positioned(
              left: 16,
              right: 16,
              top: below ? math.min(target.bottom + 14, size.height - 170) : null,
              bottom: below ? null : math.min(size.height - target.top + 14, size.height - 170),
              child: IgnorePointer(
                ignoring: widget.onTap == null || t < 1,
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - t)),
                    child: GestureDetector(
                      onTap: widget.onTap,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: C.cream,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: C.ink, width: 3),
                        ),
                        child: Row(
                          children: [
                            Image.asset('assets/ui/boss_1.png', height: 54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.text,
                                    style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w800, color: C.ink),
                                  ),
                                  if (widget.onTap != null)
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'タップでつぎへ ▶',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.woodDark),
                                      ),
                                    ),
                                ],
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
          ],
        );
      },
    );
  }

  /// Four tap-eaters around the hole (taps inside it fall through to the game).
  List<Widget> _blockers(Size s, Rect c) {
    Widget eat(Rect r) => Positioned.fromRect(
      rect: r,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap),
    );
    return [
      eat(Rect.fromLTRB(0, 0, s.width, math.max(0, c.top))),
      eat(Rect.fromLTRB(0, c.bottom, s.width, s.height)),
      eat(Rect.fromLTRB(0, c.top, math.max(0, c.left), c.bottom)),
      eat(Rect.fromLTRB(c.right, c.top, s.width, c.bottom)),
    ];
  }
}

class _HolePainter extends CustomPainter {
  final Rect cut;
  final bool circle;
  final double pulse, t, k; // k: how far the hole is scaled up (1 = settled)
  _HolePainter(this.cut, this.circle, this.pulse, this.t, this.k);

  @override
  void paint(Canvas canvas, Size size) {
    final shape = circle ? (Path()..addOval(cut)) : (Path()..addRRect(RRect.fromRectAndRadius(cut, Radius.circular(18 * k))));
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(shape, Offset.zero);
    canvas.drawPath(dim, Paint()..color = Color.fromRGBO(0, 0, 0, 0.7 * t));
    // a soft pulsing ring so the eye finds the hole
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 2 * pulse
        ..color = Colors.white.withValues(alpha: (0.6 + 0.4 * pulse) * t),
    );
  }

  @override
  bool shouldRepaint(_HolePainter o) => o.cut != cut || o.pulse != pulse || o.circle != circle || o.t != t || o.k != k;
}
