// The 推し活 level and how far it is to the next unlock,
// with the Codex-made badge and gauge (assets/ui/lv_badge.png, lv_gauge.png, lv_fill.png).
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
    return LayoutBuilder(
      builder: (_, bc) {
        final w = bc.maxWidth;
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
          decoration: BoxDecoration(
            color: C.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.ink, width: 2.5),
          ),
          child: Row(
            children: [
              _badge(level, 50),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '推し活レベル',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.ink),
                        ),
                        const SizedBox(width: 8),
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
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.woodDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _gauge(w - 86, (meta.levelInto / need).clamp(0.0, 1.0)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The rosette badge with the level number in its cream circle.
  /// The cream circle sits at (163, 160) in the 328x354 image, 192 px across.
  Widget _badge(int level, double size) {
    final w = size * 328 / 354, d = size * 192 / 354;
    return SizedBox(
      width: w,
      height: size,
      child: Stack(
        children: [
          Image.asset('assets/ui/lv_badge.png', height: size),
          Positioned(
            left: size * 163 / 354 - d / 2,
            top: size * 160 / 354 - d / 2,
            width: d,
            height: d,
            child: Center(
              child: Text(
                '$level',
                // tight line box so the digits sit in the middle of the circle
                textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
                style: outlined(d * (level >= 10 ? 0.5 : 0.6), C.gold, width: 3).copyWith(height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The wooden gauge with the glossy fill clipped to [f].
  Widget _gauge(double w, double f) {
    final h = w * 140 / 1220;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/ui/lv_gauge.png', fit: BoxFit.fill)),
          // the empty inside of the tube
          Positioned(
            left: w * 0.075,
            right: w * 0.075,
            top: h * 0.19,
            bottom: h * 0.19,
            child: LayoutBuilder(
              builder: (_, inner) => Align(
                alignment: Alignment.centerLeft,
                child: f <= 0
                    ? const SizedBox()
                    : Container(
                        width: (inner.maxWidth * f).clamp(inner.maxHeight * 1.6, inner.maxWidth),
                        height: inner.maxHeight,
                        // a firmer outline than the art's own thin one
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(inner.maxHeight),
                          border: Border.all(color: C.ink, width: 2),
                        ),
                        child: Image.asset('assets/ui/lv_fill.png', fit: BoxFit.fill),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
