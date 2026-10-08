// Buttons, panels and headers every screen shares.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'sfx.dart';
import 'theme.dart';

/// The tag every button is built on: a card with a white edge, dashed stitching just inside it and a
/// soft drop. Without [fill] it is the near-white card (put coloured text on it); with [fill] it is that
/// colour, lighter at the top (put white text on it). [circle] makes it round (the icon buttons).
class TagSurface extends StatelessWidget {
  final Widget child;
  final Color? fill;
  final Color stitch;
  final double radius;
  final bool circle, pressed;
  final EdgeInsets padding;
  const TagSurface({
    super.key,
    required this.child,
    this.fill,
    this.stitch = C.tagStitch,
    this.radius = 16,
    this.circle = false,
    this.pressed = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final f = fill;
    final drop = f == null ? C.tagShadow : f.withValues(alpha: 0.4);
    return CustomPaint(
      foregroundPainter: _Stitch(stitch, circle ? null : radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: f == null ? C.tag : null,
          gradient: f == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(f, Colors.white, 0.32)!, Color.lerp(f, C.ink, 0.04)!],
                ),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          border: Border.all(color: Colors.white, width: 2),
          // pressed, it sits down on the page and its drop shrinks
          boxShadow: [
            pressed
                ? BoxShadow(color: drop.withValues(alpha: drop.a * 0.6), blurRadius: 5, offset: const Offset(0, 2))
                : BoxShadow(color: drop, blurRadius: f == null ? 14 : 18, offset: Offset(0, f == null ? 5 : 7)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// The dashed line 5px in from a [TagSurface]'s edge ([radius] null: a circle).
class _Stitch extends CustomPainter {
  final Color color;
  final double? radius;
  const _Stitch(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(5);
    if (r.isEmpty) return;
    final r0 = radius;
    final path = r0 == null ? (Path()..addOval(r)) : (Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(math.max(2, r0 - 5)))));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4.5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Stitch old) => old.color != color || old.radius != radius;
}

/// The game's button: a [TagSurface]. [filled] (the default) is the coloured tag with white lettering,
/// for the thing to do next; otherwise it is the white tag with the colour in its lettering and
/// stitching, for everything beside it (the menu row, とじる, おわる). Its label is shown through [tr]
/// (a fixed Japanese label turns English by itself), and in English it shrinks to fit rather than
/// wrapping or overflowing.
class PopButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;
  final String? sound;
  final bool filled;

  /// Looks disabled but still takes taps (e.g. to point the player elsewhere).
  final bool dimmed;

  /// Drawn after the label (e.g. a coin icon and a price).
  final Widget? trailing;
  const PopButton(
    this.label, {
    super.key,
    this.onTap,
    this.dimmed = false,
    this.filled = true,
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
    final filled = widget.filled;
    // white lettering keeps a thin ring of its own colour, deepened, so it reads on gold and mint too
    final style = filled
        ? outlined(widget.fontSize, Colors.white, stroke: Color.lerp(col, C.ink, 0.45)!, width: 1.6).copyWith(fontWeight: FontWeight.w900)
        : TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900, color: Color.lerp(col, const Color(0xFF3A1F3A), 0.35));
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
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        child: TagSurface(
          fill: filled ? col : null,
          stitch: filled ? Colors.white.withValues(alpha: 0.75) : Color.lerp(col, Colors.white, 0.3)!,
          radius: widget.fontSize >= 20 ? 18 : 14,
          pressed: _down,
          // the old candy button had a 5px rim; the tag has 2, so the label keeps its room
          padding: widget.padding + const EdgeInsets.all(3),
          child: _fit(
            widget.trailing == null
                ? Text(tr(widget.label), textAlign: TextAlign.center, style: style)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text(tr(widget.label), style: style), widget.trailing!],
                  ),
          ),
        ),
      ),
    );
  }

  /// English runs longer: one line, scaled down to the room there is (Japanese lays out as before).
  Widget _fit(Widget w) => en ? FittedBox(fit: BoxFit.scaleDown, child: w) : w;
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
    // passthrough: given a fixed size (a page, a Positioned.fill) the card fills it instead of
    // shrinking to its contents
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        card,
        for (final (l, r) in const [(10.0, null), (null, 10.0)])
          Positioned(left: l, right: r, top: 9, child: const IgnorePointer(child: Icon(Icons.favorite_rounded, size: 13, color: C.pinkLine))),
        if (ribbon != null)
          Positioned(
            top: -48,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: Ribbon(ribbon!, width: 240))),
          ),
      ],
    );
  }
}

/// The pink ribbon banner (assets/ui/ui_ribbon.png) with a title on it.
/// The band arches up in the middle, so the title is laid along its centre line.
class Ribbon extends StatelessWidget {
  final String text;
  final double width;
  const Ribbon(this.text, {super.key, this.width = 250});

  /// The art is 512x232.
  static const aspect = 232 / 512;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(outlined(width * 0.085, Colors.white, stroke: const Color(0xFFD94E8A), width: 3.5));
    return SizedBox(
      width: width,
      height: width * aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/ui/ui_ribbon.png', fit: BoxFit.fill),
          CustomPaint(painter: _ArcTextPainter(tr(text), style)),
        ],
      ),
    );
  }
}

/// Draws [text] one glyph at a time along the ribbon band's centre line.
class _ArcTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  _ArcTextPainter(this.text, this.style);

  // the band's centre line, measured from the stitches in ui_ribbon.png:
  // y/h = a·(x/w − ½)² + b·(x/w − ½) + c
  static const _a = 1.395, _b = -0.0166, _c = 0.314;
  // the flat front of the band (the folds at both ends stay clear)
  static const _span = 0.52;

  double _y(double u) => _a * (u - 0.5) * (u - 0.5) + _b * (u - 0.5) + _c;
  double _slope(double u) => 2 * _a * (u - 0.5) + _b;

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.characters.toList();
    TextPainter glyph(String ch, double scale) => TextPainter(
      text: TextSpan(text: ch, style: style.copyWith(fontSize: style.fontSize! * scale, shadows: [for (final s in style.shadows ?? const <Shadow>[]) Shadow(color: s.color, offset: s.offset * scale)])),
      textDirection: TextDirection.ltr,
    )..layout();
    var scale = 1.0;
    var gs = [for (final ch in chars) glyph(ch, scale)];
    var total = gs.fold(0.0, (a, g) => a + g.width);
    if (total > size.width * _span) {
      scale = size.width * _span / total;
      gs = [for (final ch in chars) glyph(ch, scale)];
      total = gs.fold(0.0, (a, g) => a + g.width);
    }
    var x = (size.width - total) / 2;
    for (final g in gs) {
      final cx = x + g.width / 2, u = cx / size.width;
      canvas.save();
      canvas.translate(cx, _y(u) * size.height);
      canvas.rotate(math.atan(_slope(u) * size.height / size.width));
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      x += g.width;
    }
  }

  @override
  bool shouldRepaint(_ArcTextPainter o) => o.text != text || o.style != style;
}

/// The header every sub-screen shares: a back arrow, the title on a ribbon in the middle,
/// and an optional count on a little pill under it.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? note;
  final IconData icon;
  final Widget? trailing; // e.g. a menu button on the right, at most 48 wide
  const ScreenHeader(this.title, {super.key, this.note, this.icon = Icons.arrow_back_rounded, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(icon, color: Colors.white, size: 30, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)]),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ribbon(title, width: 210),
              if (note != null)
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                    decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.ink, width: 2)),
                    child: Text(note!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.ink)),
                  ),
                ),
            ],
          ),
        ),
        // as wide as the arrow, so the ribbon sits in the middle
        SizedBox(width: 48, child: trailing == null ? null : Padding(padding: const EdgeInsets.only(top: 4), child: trailing)),
      ],
    ),
  );
}

/// [ScreenHeader] as an app bar over the screen's own background.
PreferredSizeWidget ribbonBar(String title, {String? note}) => PreferredSize(
  preferredSize: Size.fromHeight(note == null ? 104 : 132),
  child: SafeArea(bottom: false, child: ScreenHeader(title, note: note)),
);

/// A round white tag with an icon (the menu buttons, the sound switches).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size, padding;
  const RoundIconButton(this.icon, {super.key, this.onTap, this.size = 24, this.padding = 7});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    // the tag's edge is 1px thinner than the old ring, so the padding takes it and the size stays
    child: TagSurface(circle: true, padding: EdgeInsets.all(padding + 1), child: Icon(icon, color: C.tagText, size: size)),
  );
}
