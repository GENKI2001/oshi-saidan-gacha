// Pictures: goods, capsules, rarity stars, the gacha machine, the heart, the difficulty badge.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/defs.dart';
import '../logic/modes.dart';
import 'theme.dart';

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

/// Rarity as 1-4 stars (★4 in rainbow gold).
class RarityStars extends StatelessWidget {
  final Rarity rarity;
  final double size;
  const RarityStars(this.rarity, {super.key, this.size = 20});

  /// Each rarity's star colour (★ light blue, ★★ pink, ★★★ purple, ★★★★ gold), also used to colour-code lists.
  static const colors = [Color(0xFF9FD8FF), Color(0xFFFF8FC0), Color(0xFFC79BFF), Color(0xFFFFD34D)];

  @override
  Widget build(BuildContext context) {
    final n = rarity.index + 1;
    final col = colors[rarity.index];
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
      label: en ? '$n stars' : '星$n',
      child: Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < 4; k++) star(k < n)]),
    );
  }
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
      Text(tr('難易度 '), style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w900, color: C.ink)),
      for (var i = 1; i <= 5; i++)
        Icon(i <= level ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: size, color: i <= level ? colors[level] : const Color(0xFFD9C3D8)),
      const SizedBox(width: 4),
      Text(tr(difficultyLabel[level]), style: outlined(size, colors[level], stroke: Colors.white, width: 3)),
    ],
  );
}
