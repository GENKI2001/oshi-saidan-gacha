// The 推し活 level and how far it is to the next unlock: a rosette badge, a
// glossy heart gauge and a pastel card, all drawn in code so the number sits
// dead centre and every outline matches.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/levels.dart';
import 'meta.dart';
import 'widgets.dart';

class LevelCard extends StatelessWidget {
  final Meta meta;
  const LevelCard(this.meta, {super.key});

  @override
  Widget build(BuildContext context) {
    final level = meta.level, need = meta.levelNeedNow;
    final left = need - meta.levelInto;
    // what the next level brings, if anything
    final count = unlockedAt(level + 1).length;
    final allOut = nextUnlockLevel(level) == null;
    final f = (meta.levelInto / need).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.ink,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x55220A2A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF4FA), Color(0xFFFFE3F1), Color(0xFFEFE4FF)]),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Dots()))),
            Row(
              children: [
                _Badge(level, size: 54),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('推し活レベル', style: outlined(15, C.pink, stroke: Colors.white, width: 3)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                allOut
                                    ? '全部のグッズが出るよ！'
                                    : left <= 0
                                    ? '次のプレイ終了で Lv${level + 1}！'
                                    : 'あと ♥$left で Lv${level + 1}${count > 0 ? '（新グッズ $count 種）' : ''}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFB0679A)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _Gauge(f),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A plump glossy heart with a little gold crown, "Lv" and the number in its middle.
class _Badge extends StatelessWidget {
  final int level;
  final double size;
  const _Badge(this.level, {required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _HeartBadgePainter(),
      child: Padding(
        // the heart's visual middle sits a little above the box's
        padding: EdgeInsets.only(top: size * 0.14, bottom: size * 0.16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lv', style: outlined(size * 0.16, Colors.white, stroke: const Color(0xFFC2306E), width: 2).copyWith(height: 1)),
            Text(
              '$level',
              textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
              style: outlined(size * (level >= 10 ? 0.32 : 0.38), Colors.white, stroke: const Color(0xFFC2306E), width: 4).copyWith(height: 1),
            ),
          ],
          ),
        ),
      ),
    ),
  );
}

class _HeartBadgePainter extends CustomPainter {
  Path _heart(Rect r) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    return Path()
      ..moveTo(x + w / 2, y + h * 0.98)
      ..cubicTo(x + w * 0.1, y + h * 0.7, x - w * 0.04, y + h * 0.36, x + w * 0.12, y + h * 0.17)
      ..cubicTo(x + w * 0.25, y + h * 0.0, x + w * 0.45, y + h * 0.04, x + w / 2, y + h * 0.22)
      ..cubicTo(x + w * 0.55, y + h * 0.04, x + w * 0.75, y + h * 0.0, x + w * 0.88, y + h * 0.17)
      ..cubicTo(x + w * 1.04, y + h * 0.36, x + w * 0.9, y + h * 0.7, x + w / 2, y + h * 0.98)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(size.width * 0.04, size.height * 0.1, size.width * 0.92, size.height * 0.86);
    final heart = _heart(r);
    // a soft drop shadow and the outline
    canvas.drawPath(heart.shift(const Offset(0, 3)), Paint()..color = const Color(0x55C2306E));
    canvas.drawPath(heart, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), radius: 1, colors: [Color(0xFFFFC2DD), Color(0xFFFF6FA8), Color(0xFFE5408A)], stops: [0, 0.55, 1]).createShader(r));
    canvas.save();
    canvas.clipPath(heart);
    // gloss on the upper left lobe, a sparkle on the right
    canvas.drawOval(Rect.fromLTWH(r.left + r.width * 0.14, r.top + r.height * 0.1, r.width * 0.34, r.height * 0.2), Paint()..color = Colors.white.withValues(alpha: 0.6));
    canvas.drawCircle(Offset(r.left + r.width * 0.76, r.top + r.height * 0.22), r.width * 0.045, Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.restore();
    canvas.drawPath(heart, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = size.width * 0.07);
    canvas.drawPath(heart, Paint()..color = C.ink..style = PaintingStyle.stroke..strokeWidth = 2.2);
    // the crown, tilted on the left lobe
    canvas.save();
    canvas.translate(r.left + r.width * 0.2, r.top + r.height * 0.02);
    canvas.rotate(-0.35);
    final cw = size.width * 0.34, ch = size.width * 0.22;
    final crown = Path()
      ..moveTo(-cw / 2, ch * 0.5)
      ..lineTo(-cw / 2, -ch * 0.25)
      ..lineTo(-cw / 4, ch * 0.1)
      ..lineTo(0, -ch * 0.5)
      ..lineTo(cw / 4, ch * 0.1)
      ..lineTo(cw / 2, -ch * 0.25)
      ..lineTo(cw / 2, ch * 0.5)
      ..close();
    canvas.drawPath(crown, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0A8), Color(0xFFFFC21E)]).createShader(Rect.fromCenter(center: Offset.zero, width: cw, height: ch)));
    canvas.drawPath(crown, Paint()..color = C.ink..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeJoin = StrokeJoin.round);
    for (final x in [-cw / 2, 0.0, cw / 2]) {
      canvas.drawCircle(Offset(x, x == 0 ? -ch * 0.5 : -ch * 0.25), ch * 0.12, Paint()..color = const Color(0xFFFF6FA8));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartBadgePainter o) => false;
}

/// A white groove filling pink-to-gold with a gloss on top and a heart riding the tip.
class _Gauge extends StatelessWidget {
  final double f;
  const _Gauge(this.f);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: LayoutBuilder(
      builder: (_, bc) {
        final w = bc.maxWidth;
        final fill = f <= 0 ? 0.0 : (w * f).clamp(18.0, w);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: C.ink, width: 2.5),
                boxShadow: const [BoxShadow(color: Color(0x33D9539A), blurRadius: 0, offset: Offset(0, 3))],
              ),
            ),
            if (fill > 0)
              Positioned(
                left: 3,
                top: 3,
                bottom: 3,
                width: math.max(0, fill - 6),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8FC0), Color(0xFFFF5FA2), Color(0xFFFFC93C)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.fromLTRB(5, 2, 5, 0),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
            Positioned(left: (fill - 14).clamp(-4.0, w - 22), top: -4, child: const HeartIcon(size: 28)),
          ],
        );
      },
    ),
  );
}

/// Faint sparkles scattered over the card.
class _Dots extends CustomPainter {
  const _Dots();
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(5);
    final p = Paint()..color = Colors.white.withValues(alpha: 0.8);
    for (var k = 0; k < 14; k++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(o, 1 + rnd.nextDouble() * 1.6, p);
    }
  }

  @override
  bool shouldRepaint(_Dots o) => false;
}
