// Colours and text styles: the outlined lettering, the numbers on the altar, sticker headings.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/defs.dart';

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
