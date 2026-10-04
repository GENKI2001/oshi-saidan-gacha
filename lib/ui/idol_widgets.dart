// The idols on screen: the ★3/★4 cut-in, the little speech bubble when one
// comes out of a capsule or cheers a big turn, and their colors.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/defs.dart';
import 'lines.dart';
import 'widgets.dart';

/// Each idol's theme color (つむぎ is the green one).
const idolColor = {
  'ひなた': Color(0xFFFF6B4A),
  'しずく': Color(0xFF4FA8F0),
  'こはる': Color(0xFFFFC23C),
  'よる': Color(0xFF9B5CE6),
  'もも': Color(0xFFFF7EB8),
  kTsumugi: Color(0xFF6CC27A),
};

/// Waist-up portrait: 'a' smiling, 'b' super happy (hearts).
/// Her waist-up portrait: [face] a smiling, b ultra happy ([happy]), c shy and touched.
String portrait(String who, {bool happy = false, String? face}) => 'assets/ui/cutin_${speakerId[who]}_${face ?? (happy ? 'b' : 'a')}.webp';

/// Where each face sits on her smiling portrait (fractions of width / height).
const _faceAt = {'ひなた': (0.46, 0.2), 'しずく': (0.5, 0.2), 'こはる': (0.5, 0.21), 'よる': (0.5, 0.21), 'もも': (0.5, 0.2)};

/// A round face crop of the portrait.
class IdolFace extends StatelessWidget {
  final String who;
  final double size;
  const IdolFace(this.who, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    // つむぎ has no cut-in portrait: her face comes from her standing picture
    if (who == kTsumugi) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(idolColor[who], Colors.white, 0.6),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: idolColor[who]!.withValues(alpha: 0.6), blurRadius: 8)],
        ),
        child: ClipOval(
          child: OverflowBox(
            maxWidth: size * 1.85,
            maxHeight: size * 1.85,
            alignment: const Alignment(0, -0.6),
            child: Image.asset('assets/ui/boss_1.png', width: size * 1.85, height: size * 1.85, fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
        ),
      );
    }
    final (fx, fy) = _faceAt[who] ?? (0.5, 0.2);
    // the portrait is about 2:3; the whole head fits the circle (chin, ears and bows too)
    final w = size * 1.4, h = w * 1.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(idolColor[who], Colors.white, 0.6),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: idolColor[who]!.withValues(alpha: 0.6), blurRadius: 8)],
      ),
      child: ClipOval(
        child: OverflowBox(
          maxWidth: w,
          maxHeight: h,
          minWidth: w,
          minHeight: h,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(size / 2 - fx * w, size / 2 - fy * h),
            child: Image.asset(portrait(who), width: w, height: h, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}

/// Face + speech bubble. [fade] makes it leave on its own after a few seconds.
class IdolToast extends StatelessWidget {
  final String who, line;
  final int token;
  final bool fade;
  const IdolToast({super.key, required this.who, required this.line, required this.token, this.fade = true});

  @override
  Widget build(BuildContext context) {
    final col = idolColor[who]!;
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IdolFace(who, size: 62),
        const SizedBox(width: 4),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: col, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(who, style: outlined(13, col, stroke: Colors.white, width: 2.5)),
                Text(line, style: const TextStyle(fontSize: 14, height: 1.3, color: C.ink, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ],
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: fade ? 3600 : 500),
      builder: (_, t, c) {
        final ms = t * (fade ? 3600 : 500);
        final inT = Curves.easeOutBack.transform((ms / 350).clamp(0, 1));
        final out = fade ? ((ms - 3150) / 450).clamp(0.0, 1.0) : 0.0;
        return Opacity(
          opacity: (1 - out).clamp(0, 1),
          child: Transform.translate(offset: Offset(-40 * (1 - inT), 0), child: Transform.scale(scale: 0.85 + 0.15 * inT, alignment: Alignment.centerLeft, child: c)),
        );
      },
      child: body,
    );
  }
}

/// ★3 / ★4: the idol bursts in across a band of her color before the goods appear.
class CutIn extends StatelessWidget {
  final String who, line;
  final bool ssr;
  final int token;
  final VoidCallback onTap;
  const CutIn({super.key, required this.who, required this.line, required this.ssr, required this.token, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = idolColor[who]!;
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (_, bc) => TweenAnimationBuilder<double>(
            key: ValueKey(token),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 2100),
            builder: (_, t, _) {
              final ms = t * 2100;
              final band = Curves.easeOutCubic.transform((ms / 260).clamp(0, 1));
              final slide = Curves.easeOutBack.transform(((ms - 120) / 520).clamp(0, 1));
              final text = Curves.elasticOut.transform(((ms - 380) / 700).clamp(0, 1));
              final h = bc.maxHeight;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // the band
                  Positioned(
                    left: -80,
                    right: -80,
                    top: h * 0.2,
                    height: h * 0.58,
                    child: Transform.rotate(
                      angle: -0.12,
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.diagonal3Values(band, 1, 1),
                        child: CustomPaint(painter: _BandPainter(col, ms / 1000, ssr)),
                      ),
                    ),
                  ),
                  if (ssr) Positioned.fill(child: Sparkles(token: token, size: bc.maxWidth * 1.2, colors: [C.gold, Colors.white, col, C.pink], count: 50)),
                  // the idol
                  Positioned(
                    right: -bc.maxWidth * 0.9 * (1 - slide) - 10,
                    top: h * 0.06,
                    height: h * 0.8,
                    child: Image.asset(portrait(who, happy: true), fit: BoxFit.contain, alignment: Alignment.topRight),
                  ),
                  // the stars and the name
                  Positioned(
                    left: 14,
                    top: h * 0.2,
                    child: Transform.scale(
                      scale: text,
                      alignment: Alignment.centerLeft,
                      child: Transform.rotate(
                        angle: -0.12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RarityStars(ssr ? Rarity.legend : Rarity.epic, size: ssr ? 50 : 44),
                            Text(who, style: outlined(34, Colors.white, stroke: col, width: 6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // what she says
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: h * 0.1,
                    child: Opacity(
                      opacity: ((ms - 500) / 250).clamp(0, 1),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: col, width: 4),
                          boxShadow: [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 14)],
                        ),
                        child: Text(
                          line,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, height: 1.35, color: C.ink, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: h * 0.03,
                    child: Opacity(opacity: ((ms - 900) / 300).clamp(0, 0.8), child: Text('タップでスキップ', style: outlined(12, Colors.white, width: 2))),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A band of the idol's color with streaming light stripes.
class _BandPainter extends CustomPainter {
  final Color col;
  final double t;
  final bool ssr;
  _BandPainter(this.col, this.t, this.ssr);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(col, Colors.white, 0.35)!, col, Color.lerp(col, Colors.black, 0.15)!],
        ).createShader(r),
    );
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final rnd = math.Random(7);
    for (var k = 0; k < 18; k++) {
      final y = rnd.nextDouble() * size.height;
      final w = 60 + rnd.nextDouble() * 220;
      final speed = 900 + rnd.nextDouble() * 900;
      final x = size.width - ((t * speed + rnd.nextDouble() * size.width) % (size.width + w));
      canvas.drawRRect(RRect.fromRectXY(Rect.fromLTWH(x, y, w, 3 + rnd.nextDouble() * 5), 4, 4), stripe);
    }
    final edge = Paint()
      ..color = ssr ? C.gold : Colors.white
      ..strokeWidth = 6;
    canvas.drawLine(Offset(0, 3), Offset(size.width, 3), edge);
    canvas.drawLine(Offset(0, size.height - 3), Offset(size.width, size.height - 3), edge);
  }

  @override
  bool shouldRepaint(_BandPainter o) => o.t != t;
}

/// This song's progress: ♪ N曲目, the spins left as notes, and the heart gauge
/// toward its quota (it glows once the quota is met).
class SongMeter extends StatelessWidget {
  final int song, songs, spinsLeft, spins, hearts, quota;
  const SongMeter({super.key, required this.song, required this.songs, required this.spinsLeft, required this.spins, required this.hearts, required this.quota});

  @override
  Widget build(BuildContext context) {
    final done = hearts >= quota;
    final f = (hearts / (quota <= 0 ? 1 : quota)).clamp(0.0, 1.0);
    final encore = song > songs;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 7),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFE3F0), Color(0xFFF1E4FF)])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset('assets/ui/ui_note.png', width: 24, height: 24),
              const SizedBox(width: 3),
              Text(encore ? 'アンコール' : '$song曲目', style: outlined(15, C.pink, stroke: Colors.white, width: 3)),
              if (!encore) Text(' / $songs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.ink)),
              const Spacer(),
              // one note per spin left in this song
              for (var i = 0; i < spins; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 15,
                    color: i < spins - spinsLeft ? const Color(0xFFD9C3D8) : (spinsLeft <= 1 ? C.red : C.lilac),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // the heart gauge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 20,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.ink, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      widthFactor: f,
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: done ? const [Color(0xFFFFB3D9), Color(0xFFFFD86B)] : const [Color(0xFFFF9EC9), Color(0xFFFF5FA2)]),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(height: 5, margin: const EdgeInsets.fromLTRB(6, 3, 6, 0), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(4))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: FittedBox(
                      child: Text(done ? 'ノルマ達成！' : '$hearts / $quota', style: outlined(13, Colors.white, stroke: C.ink, width: 3)),
                    ),
                  ),
                ),
              ),
              Positioned(left: -6, top: -6, child: Image.asset('assets/ui/ui_heart.png', width: 32, height: 32)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tag as a little chip: an idol's tag in her color, the rest in cream.
class TagChip extends StatelessWidget {
  final String tag;
  final double size;
  const TagChip(this.tag, {super.key, this.size = 13});
  @override
  Widget build(BuildContext context) {
    final col = idolColor[tag];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.6, vertical: size * 0.12),
      decoration: BoxDecoration(
        color: col ?? C.cream,
        borderRadius: BorderRadius.circular(size),
        border: Border.all(color: C.ink, width: 2),
      ),
      child: Text(
        tag,
        style: col != null ? outlined(size, Colors.white, stroke: Color.lerp(col, C.ink, 0.55)!, width: 2.5) : TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: C.ink),
      ),
    );
  }
}
