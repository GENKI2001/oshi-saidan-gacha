// The 妨害: the scalper カイシメ barges in before the hearts are counted.
// Siren and a hazard-striped cut-in; what to do, one line at a time; a fierce
// chibi shoving match between him and the idol with the most goods on the
// altar (まもれ！ mashed in the middle moves the meter and the odds); then the
// outcome, spelled out.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/run.dart';
import 'controller.dart';
import 'idol_widgets.dart';
import 'lines.dart';
import 'widgets.dart';

class JamOverlay extends StatefulWidget {
  final GameController g;
  const JamOverlay(this.g, {super.key});
  @override
  State<JamOverlay> createState() => _JamOverlayState();
}

class _JamOverlayState extends State<JamOverlay> with TickerProviderStateMixin {
  // drives the shaking, the siren light and the stage-in animations
  late final _tick = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  late final _stageIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  int _stage = -1;
  DateTime _stageAt = DateTime.now();
  bool? _saved;
  DateTime _savedAt = DateTime.now();
  int _tapToken = 0;
  int _count = 3;
  DateTime _goAt = DateTime.now();
  DateTime? _tapAt;

  @override
  void dispose() {
    _tick.dispose();
    _stageIn.dispose();
    super.dispose();
  }

  GameController get g => widget.g;

  @override
  Widget build(BuildContext context) {
    if (g.jamStage != _stage) {
      _stage = g.jamStage;
      _stageAt = DateTime.now();
      _stageIn.forward(from: 0);
    }
    if (g.jamSaved != _saved) {
      _saved = g.jamSaved;
      _savedAt = DateTime.now();
    }
    if (g.jamCount != _count) {
      _count = g.jamCount;
      if (_count == 0) _goAt = DateTime.now();
    }
    if (g.jamTapToken != _tapToken) {
      _tapToken = g.jamTapToken;
      _tapAt = DateTime.now();
    }
    final j = g.jam;
    if (j == null) return const SizedBox();
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (_, bc) => AnimatedBuilder(
          animation: Listenable.merge([_tick, _stageIn]),
          builder: (_, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              // the siren light sweeping the hall
              if (g.jamStage < 3) Positioned(left: -600, right: -600, top: -200, bottom: -200, child: IgnorePointer(child: _sirenLight())),
              if (g.jamStage == 0) ..._intro(bc, j),
              if (g.jamStage == 1) ..._rules(bc, j),
              if (g.jamStage == 2) ..._battle(bc, j),
              if (g.jamStage == 3 && g.jamSaved != null) ..._outcome(bc, j),
            ],
          ),
        ),
      ),
    );
  }

  double get _t => _tick.value;
  double get _in => _stageIn.value;

  /// Milliseconds since this stage began / since the outcome was decided.
  double get _ms => DateTime.now().difference(_stageAt).inMilliseconds.toDouble();
  double get _msOut => DateTime.now().difference(_savedAt).inMilliseconds.toDouble();

  /// 0 → 1 between [from] and [to] ms, eased.
  double _seg(double ms, double from, double to, [Curve c = Curves.easeOutCubic]) => c.transform(((ms - from) / (to - from)).clamp(0.0, 1.0));

  Widget _sirenLight() {
    final a = 0.5 + 0.5 * math.sin(_t * 2 * math.pi * 2.2);
    return ColoredBox(color: const Color(0xFFFF1E3C).withValues(alpha: 0.10 + 0.16 * a));
  }

  /// A hazard-striped band with 妨害発生！ and カイシメ storming in.
  List<Widget> _intro(BoxConstraints bc, Jam j) {
    final w = bc.maxWidth, h = bc.maxHeight;
    final ms = _ms;
    final band = _seg(ms, 0, 450);
    final slide = _seg(ms, 250, 1000, Curves.easeOutBack);
    final text = _seg(ms, 600, 1500, Curves.elasticOut);
    return [
      Positioned(
        left: -80,
        right: -80,
        top: h * 0.22,
        height: h * 0.5,
        child: Transform.rotate(
          angle: -0.1,
          child: Transform(
            alignment: Alignment.centerRight,
            transform: Matrix4.diagonal3Values(band, 1, 1),
            child: CustomPaint(painter: _HazardPainter(_t)),
          ),
        ),
      ),
      Positioned(
        left: -w * 0.9 * (1 - slide) - w * 0.08,
        top: h * 0.26,
        height: h * 0.5,
        child: Image.asset('assets/ui/jama_a.webp', fit: BoxFit.contain),
      ),
      Positioned(
        right: 12,
        top: h * 0.2,
        child: Transform.scale(
          scale: text,
          alignment: Alignment.centerRight,
          child: Transform.rotate(
            angle: -0.1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('妨害発生！', style: outlined(48, const Color(0xFFFFE14D), stroke: const Color(0xFF2A0F1F), width: 8)),
                Text('転売ヤー $kJammer', style: outlined(22, Colors.white, stroke: const Color(0xFF2A0F1F), width: 5)),
                const SizedBox(height: 6),
                _PowerStars(j.power),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// The idol says what is at stake (lose / win) in one bubble; まもる！ starts the countdown.
  /// Everything sits together in the middle of the screen.
  List<Widget> _rules(BoxConstraints bc, Jam j) {
    final w = bc.maxWidth, h = bc.maxHeight;
    final ms = _ms;
    final col = idolColor[g.jamIdol]!;
    final idolKey = speakerId[g.jamIdol];
    final bob = math.sin(_t * 2 * math.pi * 2) * 4;
    final slide = _seg(ms, 0, 500, Curves.easeOutBack);
    final chibiH = math.min(h * 0.24, w * 0.5);
    return [
      Positioned.fill(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // the two sides face off
                SizedBox(
                  width: double.infinity,
                  height: chibiH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: w * 0.02 - w * 0.5 * (1 - slide),
                        top: bob,
                        height: chibiH,
                        child: Image.asset('assets/ui/chibi_$idolKey.webp', fit: BoxFit.contain),
                      ),
                      Positioned(
                        right: w * 0.02 - w * 0.5 * (1 - slide),
                        top: -bob,
                        height: chibiH,
                        child: Image.asset('assets/ui/chibi_jama.webp', fit: BoxFit.contain),
                      ),
                      Transform.scale(
                        scale: _seg(ms, 200, 700, Curves.elasticOut),
                        child: Text('VS', style: outlined(56, const Color(0xFFFFE14D), stroke: const Color(0xFF2A0F1F), width: 8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // she tells you what is at stake
                Opacity(
                  opacity: _seg(ms, 400, 750),
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - _seg(ms, 400, 750))),
                    child: _faceLine(
                      IdolFace(g.jamIdol, size: 60),
                      g.jamIdol,
                      'まもれないと… ${j.text}\nまもれたら… ${j.rewardText}！',
                      col,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // まもる！ starts the countdown
                Opacity(
                  opacity: _seg(ms, 900, 1200),
                  child: Transform.scale(
                    scale: _seg(ms, 900, 1400, Curves.elasticOut) * (1 + 0.05 * math.sin(_t * 2 * math.pi * 2)),
                    child: SizedBox(
                      width: 240,
                      child: PopButton('まもる！', fontSize: 34, color: col, onTap: ms > 900 ? g.jamReady : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// What カイシメ says as he makes off with it (his own words, not the player's).
  String _gloat(Jam j) => switch (j.kind) {
    JamKind.steal || JamKind.stealTwo => '${g.jamTaken.map((f) => f.name).join('と')}、もらっていくぜ！',
    JamKind.hearts => 'ハート ${j.pct}%、いただきだぜ！',
    JamKind.noRepull => '「もう一回ひく」は 使わせないぜ！',
    JamKind.half => 'この曲のハートは 半分だぜ！ ヒヒッ',
  };

  /// The shoving match: two chibi, palm to palm, crackling where they meet.
  /// The clash point moves with the odds; every まもれ！ is a lunge and a spark.
  List<Widget> _battle(BoxConstraints bc, Jam j) {
    final w = bc.maxWidth, h = bc.maxHeight;
    final p = g.jamP;
    final col = idolColor[g.jamIdol]!;
    final enter = Curves.easeOutBack.transform(_in.clamp(0, 1));
    final arenaY = h * 0.17, chibiH = math.min(h * 0.32, w * 0.62);
    final idolW = chibiH * 386 / 468, jamW = chibiH * 406 / 473;
    // the clash point: to the right when the idol is winning, to the left when he is (both stay on screen)
    final clash = (w * (0.5 + (p - 0.45) * 0.5)).clamp(idolW * 0.92 + 4, w - jamW * 0.94 - 4).toDouble();
    final cy = arenaY + chibiH * 0.45; // palm height
    // a shove that never stops: both rock back and forth together, plus a jitter
    // how hard he is pushing right now (0 = easing off, 1 = his overpowering mode): the shake and his lean grow with it
    final surge = (g.jamForce / 18).clamp(0.0, 1.0);
    final rock = math.sin(_t * 2 * math.pi * (4.5 + surge * 4)) * (4 + surge * 9);
    double jit(double seed, double amp) => math.sin(_t * 2 * math.pi * 17 + seed) * amp + math.sin(_t * 2 * math.pi * 29 + seed * 2.3) * amp * 0.6;
    // a fresh まもれ！: the idol lunges and the hall flashes
    final lunge = _tapKick * 18;
    final idolKey = speakerId[g.jamIdol];
    return [
      // what is at stake and the time left
      Positioned(
        left: 14,
        right: 14,
        top: 8,
        child: Column(
          children: [
            _bubble('まけると… ${j.text}', C.red),
            const SizedBox(height: 6),
            _timer(g.jamLeft),
          ],
        ),
      ),
      // the two sides' auras meeting at the clash, speed lines, lightning
      Positioned(
        left: -40,
        right: -40,
        top: arenaY - 20,
        height: chibiH + 40,
        child: IgnorePointer(
          child: CustomPaint(painter: _ClashPainter(t: _t, clashX: clash + 40, cy: cy - arenaY + 20, idol: col, kick: _tapKick, front: false)),
        ),
      ),
      // the idol, facing right
      Positioned(
        left: clash - idolW * 0.92 - w * (1 - enter) + rock + lunge + jit(0, 2.5),
        top: arenaY + jit(1.3, 2),
        height: chibiH,
        child: Transform.rotate(angle: 0.05 + _tapKick * 0.08 + jit(2.1, 0.015), child: Image.asset('assets/ui/chibi_$idolKey.webp', fit: BoxFit.contain)),
      ),
      // カイシメ, facing left
      Positioned(
        left: clash - jamW * 0.06 + w * (1 - enter) + rock + lunge * 0.6 + jit(4, 1.5 + surge * 5),
        top: arenaY + jit(5.2, 1.5 + surge * 4),
        height: chibiH,
        child: Transform.rotate(angle: -0.05 - surge * 0.14 + _tapKick * 0.06 + jit(6.3, 0.01 + surge * 0.03), child: Image.asset('assets/ui/chibi_jama.webp', fit: BoxFit.contain)),
      ),
      // the impact star and the lightning go in front of their palms
      Positioned(
        left: -40,
        right: -40,
        top: arenaY - 20,
        height: chibiH + 40,
        child: IgnorePointer(
          child: CustomPaint(painter: _ClashPainter(t: _t, clashX: clash + 40 + rock + lunge * 0.8, cy: cy - arenaY + 20, idol: col, kick: _tapKick, front: true)),
        ),
      ),
      // sparks on every tap, and a word for the shove
      Positioned(
        left: clash - 100,
        top: cy - 100,
        child: IgnorePointer(child: Sparkles(token: g.jamTapToken, size: 200, colors: [col, Colors.white, const Color(0xFFFFE14D)], count: 12)),
      ),
      // he is going all out: a red word over him
      if (g.jamCount == 0 && g.jamMode >= 3)
        Positioned(
          left: clash + jamW * 0.25 + jit(8, 3),
          top: arenaY - 26 + jit(9, 3),
          child: IgnorePointer(
            child: Transform.scale(
              scale: 1 + math.sin(_t * 2 * math.pi * 6).abs() * 0.15 + (g.jamMode >= 4 ? 0.25 + (g.jamMode - 4) * 0.2 : 0),
              child: Transform.rotate(
                angle: 0.18,
                child: Text(
                  switch (g.jamMode) {
                    3 => 'グググッ！',
                    4 => 'ゴゴゴゴ…！',
                    5 => 'ズゴゴゴゴ…！！',
                    _ => '本気だぜ…！！！',
                  },
                  style: outlined(24 + (g.jamMode - 3) * 5.0, g.jamMode >= 5 ? const Color(0xFFB000FF) : const Color(0xFFFF4D6D), stroke: Colors.white, width: 6),
                ),
              ),
            ),
          ),
        ),
      if (g.jamTapToken > 0)
        Positioned(
          left: clash - 80 + ((g.jamTapToken * 37) % 60 - 30),
          top: arenaY - 6 + ((g.jamTapToken * 53) % 30),
          child: IgnorePointer(child: _Onomatopoeia(_words[g.jamTapToken % _words.length], token: g.jamTapToken, color: col)),
        ),
      // the odds and the tug-of-war meter
      Positioned(
        left: 14,
        right: 14,
        top: arenaY + chibiH + 8,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('まもれる確率 ', style: outlined(16, Colors.white, width: 3)),
                Text('${(p * 100).round()}', style: outlined(44, Color.lerp(C.red, C.mint, p)!, stroke: Colors.white, width: 5)),
                Text('%', style: outlined(22, Colors.white, width: 3)),
              ],
            ),
            const SizedBox(height: 8),
            _Meter(p: p, color: col, who: g.jamIdol),
          ],
        ),
      ),
      // まもれ！
      Positioned(
        left: 0,
        right: 0,
        bottom: h * 0.03,
        child: Center(child: _MashButton(onTap: g.jamPush, token: g.jamTapToken, color: col, who: g.jamIdol, t: _t, ready: g.jamCount == 0)),
      ),
      // 3, 2, 1, スタート！
      if (g.jamCount > 0)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('count${g.jamCount}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                builder: (_, k, c) => Opacity(
                  opacity: k < 0.75 ? 1 : (1 - k) * 4,
                  child: Transform.scale(scale: 2.2 - 1.2 * Curves.easeOutBack.transform(math.min(1, k * 1.6)), child: c),
                ),
                child: Text('${g.jamCount}', style: outlined(170, Colors.white, stroke: col, width: 12)),
              ),
            ),
          ),
        )
      else if (DateTime.now().difference(_goAt).inMilliseconds < 800)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: -0.08,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform((DateTime.now().difference(_goAt).inMilliseconds / 600).clamp(0.0, 1.0)),
                  child: Text('スタート！', style: outlined(62, const Color(0xFFFFE14D), stroke: col, width: 9)),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  static const _words = ['バチッ！', 'ドンッ！', 'グイッ！', 'ぐぐっ！', 'バチバチ！', 'ドドン！'];

  /// 1 right after a まもれ！, fading over ~150 ms.
  double get _tapKick {
    final at = _tapAt;
    if (at == null) return 0;
    final ms = DateTime.now().difference(at).inMilliseconds;
    return math.exp(-ms / 150);
  }

  List<Widget> _outcome(BoxConstraints bc, Jam j) {
    final w = bc.maxWidth, h = bc.maxHeight;
    final saved = g.jamSaved == true;
    final ms = _msOut;
    final pop = _seg(ms, 0, 900, Curves.elasticOut);
    final arenaY = h * 0.13, chibiH = math.min(h * 0.28, w * 0.55);
    final idolKey = speakerId[g.jamIdol];
    if (saved) {
      final fly = _seg(ms, 0, 1100, Curves.easeIn);
      final hop = -(math.sin(_t * 2 * math.pi * 2.5).abs() * 26);
      return [
        Positioned(left: w * 0.1, top: arenaY + hop, height: chibiH, child: Image.asset('assets/ui/chibi_$idolKey.webp', fit: BoxFit.contain)),
        Positioned(
          left: w * 0.5 + w * 0.9 * fly,
          top: arenaY - h * 0.28 * math.sin(fly * math.pi * 0.9),
          height: chibiH,
          child: Transform.rotate(angle: fly * 7, child: Image.asset('assets/ui/chibi_jama_out.webp', fit: BoxFit.contain)),
        ),
        Positioned(left: w * 0.55 - 70, top: arenaY + chibiH * 0.2, child: IgnorePointer(child: _Onomatopoeia('ドカーン！', token: g.jamToken, color: C.gold, size: 40))),
        Positioned.fill(child: IgnorePointer(child: Sparkles(token: g.jamToken, size: w * 1.2, colors: [C.gold, Colors.white, idolColor[g.jamIdol]!, C.pink], count: 40))),
        Positioned(
          left: 16,
          right: 16,
          top: arenaY + chibiH + 20,
          child: Transform.scale(
            scale: pop,
            child: Column(
              children: [
                Transform.rotate(angle: -0.08, child: Text('まもった！', style: outlined(54, C.gold, stroke: const Color(0xFFB4501A), width: 7))),
                const SizedBox(height: 8),
                Opacity(opacity: _seg(ms, 700, 1100), child: _faceLine(IdolFace(g.jamIdol, size: 56), g.jamIdol, '追いかえした！ ${j.rewardText}！', idolColor[g.jamIdol]!)),
              ],
            ),
          ),
        ),
      ];
    }
    // he got through: the goods fly into his bags, he gloats, then runs off with them
    final run = _seg(ms, 2200, 3300, Curves.easeIn);
    final jamX = w * 0.52 + w * 0.8 * run;
    return [
      Positioned(left: -600, right: -600, top: -200, bottom: -200, child: IgnorePointer(child: ColoredBox(color: const Color(0xFF3A0010).withValues(alpha: 0.3)))),
      Positioned(
        left: w * 0.06,
        top: arenaY + chibiH * 0.06 * _seg(ms, 0, 600),
        height: chibiH,
        child: Transform.rotate(angle: -0.12, child: Image.asset('assets/ui/chibi_$idolKey.webp', fit: BoxFit.contain)),
      ),
      Positioned(
        left: jamX,
        top: arenaY - (math.sin(_t * 2 * math.pi * 3).abs() * (run > 0 ? 14 : 4)),
        height: chibiH,
        child: Image.asset('assets/ui/chibi_jama.webp', fit: BoxFit.contain),
      ),
      // what he took, flying up from the altar into his bags
      for (var k = 0; k < g.jamTaken.length; k++)
        Builder(builder: (_) {
          final f = _seg(ms, 150 + k * 250, 1050 + k * 250, Curves.easeInOutCubic);
          final x = w * (0.3 + 0.1 * k) + (jamX + chibiH * 0.45 - w * (0.3 + 0.1 * k)) * f;
          final y = h * 0.78 + (arenaY + chibiH * 0.55 - h * 0.78) * f - math.sin(f * math.pi) * h * 0.15;
          return Positioned(
            left: x - 32,
            top: y - 32,
            child: Opacity(opacity: f < 0.95 ? 1 : (1 - f) * 20, child: Transform.rotate(angle: f * 6, child: FigureArt(g.jamTaken[k], size: 64))),
          );
        }),
      if (ms > 900 && ms < 2400) Positioned(left: w * 0.5, top: arenaY - 10, child: IgnorePointer(child: _Onomatopoeia('いただきぃ！', token: g.jamToken + 1, color: const Color(0xFF2A0F1F), size: 32))),
      Positioned(
        left: 16,
        right: 16,
        top: arenaY + chibiH + 20,
        child: Transform.scale(
          scale: pop,
          child: Column(
            children: [
              Transform.rotate(angle: -0.08, child: Text('やられた…', style: outlined(54, const Color(0xFF9AA3B5), stroke: C.ink, width: 7))),
              const SizedBox(height: 8),
              // the scalper's own icon, with what it cost
              Opacity(
                opacity: _seg(ms, 600, 1000),
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - _seg(ms, 600, 1000))),
                  child: _faceLine(const _JammerFace(size: 64), kJammer, _gloat(j), const Color(0xFF2A0F1F)),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// An icon with a name and a line beside it.
  Widget _faceLine(Widget face, String who, String text, Color color) => Row(
    children: [
      face,
      const SizedBox(width: 6),
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(who, style: outlined(13, color, stroke: Colors.white, width: 2.5)),
              Text(text, style: const TextStyle(fontSize: 15, height: 1.3, color: C.ink, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _bubble(String text, Color border) => Container(
    padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, height: 1.3, color: C.ink, fontWeight: FontWeight.w900),
    ),
  );

  Widget _timer(double left) => Container(
    height: 12,
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: left.clamp(0, 1),
          heightFactor: 1,
          child: ColoredBox(color: left < 0.3 ? C.red : const Color(0xFFFFE14D)),
        ),
      ),
    ),
  );
}

/// How hard he pushes, as up to three fists.
class _PowerStars extends StatelessWidget {
  final double power;
  const _PowerStars(this.power);
  @override
  Widget build(BuildContext context) {
    final n = power < 1.0 ? 1 : (power < 1.3 ? 2 : 3);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
      decoration: BoxDecoration(color: const Color(0xCC2A0F1F), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('押しの強さ ', style: outlined(14, Colors.white, width: 2)),
          for (var i = 0; i < 3; i++) Icon(Icons.sports_mma_rounded, size: 20, color: i < n ? const Color(0xFFFF5A5A) : Colors.white24),
        ],
      ),
    );
  }
}

/// The tug-of-war: the idol's color from the left, his black from the right.
class _Meter extends StatelessWidget {
  final double p;
  final Color color;
  final String who;
  const _Meter({required this.p, required this.color, required this.who});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: LayoutBuilder(
      builder: (_, bc) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A0F1F),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 90),
                  widthFactor: p.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.35)!, color]))),
                ),
              ),
            ),
          ),
          Positioned(left: -6, top: -6, child: IdolFace(who, size: 46)),
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A4A5A),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: ClipOval(
                child: OverflowBox(
                  maxWidth: 110,
                  maxHeight: 110,
                  alignment: const Alignment(0, -0.55),
                  child: Image.asset('assets/ui/jama_a.webp', width: 110, height: 110, fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// まもれ！: a big glossy heart in the idol's color, a ring of sparkles turning
/// round it, her face as a sticker, and hearts popping out on every tap.
class _MashButton extends StatelessWidget {
  final VoidCallback onTap;
  final int token;
  final Color color;
  final String who;
  final double t; // 0..1, looping
  final bool ready; // false during the countdown
  const _MashButton({required this.onTap, required this.token, required this.color, required this.who, required this.t, required this.ready});

  static const size = 170.0;

  @override
  Widget build(BuildContext context) {
    final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2);
    final idle = ready ? 1 + 0.04 * math.sin(t * 2 * math.pi * 3) : 0.92;
    final body = TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (_, sq, c) => Transform.scale(scaleX: 2 - sq, scaleY: sq, child: c),
      child: CustomPaint(
        size: const Size(size, size * 0.92),
        painter: _HeartButtonPainter(ready ? color : const Color(0xFFB9B0C0), glow),
        child: SizedBox(
          width: size,
          height: size * 0.92,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('まもれ！', style: outlined(34, Colors.white, stroke: Color.lerp(color, C.ink, 0.55)!, width: 6)),
                Text(ready ? '♥ 連打！ ♥' : 'まってね…', style: outlined(15, const Color(0xFFFFF2A8), stroke: Color.lerp(color, C.ink, 0.55)!, width: 4)),
              ],
            ),
          ),
        ),
      ),
    );
    return Listener(
      // on pointer down, not on tap-up, so fast mashing never drops a tap
      onPointerDown: (_) => onTap(),
      child: SizedBox(
        width: size + 70,
        height: size + 40,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // a soft glow and a ring of sparkles going round
            IgnorePointer(child: CustomPaint(size: const Size(size + 70, size + 40), painter: _SparkleRingPainter(t, color, ready))),
            Transform.scale(scale: idle, child: body),
            // her face as a sticker on the corner
            Positioned(
              right: 14,
              top: 0,
              child: Transform.rotate(angle: 0.18 + 0.06 * math.sin(t * 2 * math.pi * 2), child: IdolFace(who, size: 50)),
            ),
            // hearts pop out of it on every tap
            IgnorePointer(child: _HeartBurst(token: token, color: color)),
          ],
        ),
      ),
    );
  }
}

/// A plump heart with a glossy top, a white rim and a dark outline.
class _HeartButtonPainter extends CustomPainter {
  final Color color;
  final double glow;
  _HeartButtonPainter(this.color, this.glow);

  Path _heart(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w / 2, h * 0.98)
      ..cubicTo(w * 0.12, h * 0.70, -w * 0.02, h * 0.38, w * 0.12, h * 0.17)
      ..cubicTo(w * 0.24, -h * 0.02, w * 0.45, h * 0.02, w / 2, h * 0.2)
      ..cubicTo(w * 0.55, h * 0.02, w * 0.76, -h * 0.02, w * 0.88, h * 0.17)
      ..cubicTo(w * 1.02, h * 0.38, w * 0.88, h * 0.70, w / 2, h * 0.98)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final heart = _heart(size);
    canvas.drawShadow(heart, Colors.black, 6, false);
    canvas.drawPath(heart.shift(const Offset(0, 6)), Paint()..color = Color.lerp(color, Colors.black, 0.35)!);
    canvas.drawPath(
      heart,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 0.95,
          colors: [Color.lerp(color, Colors.white, 0.55)!, color, Color.lerp(color, Colors.black, 0.18)!],
          stops: const [0, 0.6, 1],
        ).createShader(Offset.zero & size),
    );
    // the gloss on top
    canvas.save();
    canvas.clipPath(heart);
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.08, size.width * 0.42, size.height * 0.26),
      Paint()..color = Colors.white.withValues(alpha: 0.45 + 0.15 * glow),
    );
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.24), size.width * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.7));
    canvas.restore();
    canvas.drawPath(
      heart,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawPath(
      heart,
      Paint()
        ..color = C.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_HeartButtonPainter o) => o.color != color || o.glow != glow;
}

/// A glow behind the button and little stars and hearts orbiting it.
class _SparkleRingPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool ready;
  _SparkleRingPainter(this.t, this.color, this.ready);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.height * 0.5, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: ready ? 0.55 : 0.2), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: size.height * 0.5)));
    if (!ready) return;
    for (var k = 0; k < 10; k++) {
      final a = t * 2 * math.pi + k * 2 * math.pi / 10;
      final p = c + Offset(math.cos(a) * size.width * 0.46, math.sin(a) * size.height * 0.46);
      final r = 5.0 + 2 * math.sin(t * 2 * math.pi * 4 + k);
      final paint = Paint()..color = (k.isEven ? Colors.white : const Color(0xFFFFE14D)).withValues(alpha: 0.9);
      if (k % 3 == 0) {
        // a tiny heart
        final hp = Path()
          ..moveTo(p.dx, p.dy + r)
          ..cubicTo(p.dx - r * 1.6, p.dy - r * 0.2, p.dx - r * 0.6, p.dy - r * 1.4, p.dx, p.dy - r * 0.4)
          ..cubicTo(p.dx + r * 0.6, p.dy - r * 1.4, p.dx + r * 1.6, p.dy - r * 0.2, p.dx, p.dy + r)
          ..close();
        canvas.drawPath(hp, Paint()..color = Color.lerp(color, Colors.white, 0.4)!);
      } else {
        // a four-point star
        final sp = Path();
        for (var i = 0; i < 8; i++) {
          final rr = i.isEven ? r : r * 0.35;
          final q = p + Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4)) * rr;
          i == 0 ? sp.moveTo(q.dx, q.dy) : sp.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(sp..close(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkleRingPainter o) => true;
}

/// A handful of hearts flying out from the button, fresh on every tap.
class _HeartBurst extends StatelessWidget {
  final int token;
  final Color color;
  const _HeartBurst({required this.token, required this.color});
  @override
  Widget build(BuildContext context) {
    if (token == 0) return const SizedBox();
    return TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (_, k, _) {
        final rnd = math.Random(token);
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < 5; i++)
                Builder(builder: (_) {
                  final a = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 2.4;
                  final d = 70 + rnd.nextDouble() * 60;
                  return Positioned(
                    left: 120 + math.cos(a) * d * k - 11,
                    top: 120 + math.sin(a) * d * k - 11,
                    child: Opacity(
                      opacity: (1 - k).clamp(0, 1),
                      child: Icon(Icons.favorite_rounded, size: 18 + 10 * rnd.nextDouble(), color: i.isEven ? Colors.white : Color.lerp(color, Colors.white, 0.3)),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

/// Black-and-yellow hazard stripes streaming by, with a red edge.
class _HazardPainter extends CustomPainter {
  final double t;
  _HazardPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = const Color(0xFF2A0F1F));
    final stripe = Paint()..color = const Color(0xFFFFD21E);
    const sw = 46.0;
    final shift = (t * sw * 4) % (sw * 2);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, 22));
    for (var x = -size.height - sw * 2 + shift; x < size.width + sw; x += sw * 2) {
      canvas.drawPath(Path()..addPolygon([Offset(x, 22), Offset(x + sw, 22), Offset(x + sw + 22, 0), Offset(x + 22, 0)], true), stripe);
    }
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, size.height - 22, size.width, 22));
    for (var x = -sw * 2 - shift; x < size.width + sw; x += sw * 2) {
      canvas.drawPath(Path()..addPolygon([Offset(x, size.height), Offset(x + sw, size.height), Offset(x + sw + 22, size.height - 22), Offset(x + 22, size.height - 22)], true), stripe);
    }
    canvas.restore();
    // streaks of red light across the band
    final streak = Paint()..color = const Color(0xFFFF3B5C).withValues(alpha: 0.35);
    final rnd = math.Random(3);
    for (var k = 0; k < 10; k++) {
      final y = 30 + rnd.nextDouble() * (size.height - 60);
      final len = 80 + rnd.nextDouble() * 200;
      final x = ((t * (900 + rnd.nextDouble() * 700) + rnd.nextDouble() * size.width) % (size.width + len)) - len;
      canvas.drawRRect(RRect.fromRectXY(Rect.fromLTWH(x, y, len, 4 + rnd.nextDouble() * 4), 3, 3), streak);
    }
  }

  @override
  bool shouldRepaint(_HazardPainter o) => o.t != t;
}

/// A comic sound word that pops in big and fades.
class _Onomatopoeia extends StatelessWidget {
  final String text;
  final int token;
  final Color color;
  final double size;
  const _Onomatopoeia(this.text, {required this.token, required this.color, this.size = 30});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(token),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 520),
    builder: (_, t, c) => Opacity(
      opacity: t < 0.6 ? 1 : (1 - t) / 0.4,
      child: Transform.rotate(angle: -0.2 + (token % 3) * 0.15, child: Transform.scale(scale: 0.4 + 0.9 * Curves.easeOutBack.transform(math.min(1, t * 2.5)), child: c)),
    ),
    child: Text(text, style: outlined(size, const Color(0xFFFFE14D), stroke: Color.lerp(color, C.ink, 0.5)!, width: 6)),
  );
}

/// Where the two meet: their auras pushing against each other, speed lines
/// pointing in, an impact star and lightning crackling between the palms.
class _ClashPainter extends CustomPainter {
  final double t, clashX, cy, kick;
  final Color idol;
  final bool front; // false: auras and speed lines (behind them); true: impact star and lightning
  _ClashPainter({required this.t, required this.clashX, required this.cy, required this.idol, required this.kick, required this.front});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(clashX, cy);
    final rnd = math.Random((t * 24).floor() + (front ? 7 : 0));
    if (front) {
      _impact(canvas, c, rnd);
      return;
    }
    // the auras: the idol's color from the left, his dark violet from the right, with a wavy front
    final wave = Path()..moveTo(0, 0);
    for (var y = 0.0; y <= size.height; y += 8) {
      wave.lineTo(clashX + math.sin(y / 18 + t * 2 * math.pi * 3) * 10, y);
    }
    wave
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = LinearGradient(colors: [idol.withValues(alpha: 0), idol.withValues(alpha: 0.45)]).createShader(Rect.fromLTWH(0, 0, clashX, size.height)),
    );
    final right = Path()..moveTo(size.width, 0);
    for (var y = 0.0; y <= size.height; y += 8) {
      right.lineTo(clashX + math.sin(y / 18 + t * 2 * math.pi * 3) * 10, y);
    }
    right
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      right,
      Paint()
        ..shader = LinearGradient(colors: [const Color(0x996A2BB0), const Color(0x002A0F1F)]).createShader(Rect.fromLTWH(clashX, 0, size.width - clashX, size.height)),
    );
    // speed lines pointing at the clash
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (var k = 0; k < 22; k++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final r0 = 70 + rnd.nextDouble() * 40, r1 = r0 + 60 + rnd.nextDouble() * 120;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r0, c + Offset(math.cos(a), math.sin(a)) * r1, line);
    }
  }

  void _impact(Canvas canvas, Offset c, math.Random rnd) {
    // the impact star, throbbing (bigger right after a tap)
    final pulse = 0.7 + 0.1 * math.sin(t * 2 * math.pi * 8) + kick * 0.45;
    final star = Path();
    for (var k = 0; k < 24; k++) {
      final r = (k.isEven ? 62.0 : 30.0) * pulse * (0.85 + 0.3 * ((k * 7919) % 5) / 5);
      final a = k * math.pi / 12 + t * 2;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      k == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFE14D).withValues(alpha: 0.85));
    canvas.drawPath(
      star,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(c, 20 * pulse, Paint()..color = Colors.white);
    // lightning: a few zigzag bolts out of the clash, new every frame
    for (var b = 0; b < 4 + (kick * 4).round(); b++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final len = 50 + rnd.nextDouble() * 90 + kick * 60;
      final bolt = Path()..moveTo(c.dx, c.dy);
      var p = c;
      for (var s = 1; s <= 6; s++) {
        final along = c + Offset(math.cos(a), math.sin(a)) * (len * s / 6);
        final n = Offset(-math.sin(a), math.cos(a)) * (rnd.nextDouble() - 0.5) * 26;
        p = along + n;
        bolt.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        bolt,
        Paint()
          ..color = (b.isEven ? idol : const Color(0xFFB98BFF)).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        bolt,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ClashPainter o) => true;
}

/// カイシメ's face in a circle (cropped from his cut-in art), for when he gets away with it.
class _JammerFace extends StatelessWidget {
  final double size;
  const _JammerFace({this.size = 46});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF4A4A5A),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 8)],
    ),
    child: ClipOval(
      child: OverflowBox(
        maxWidth: size * 2.4,
        maxHeight: size * 2.4,
        alignment: const Alignment(0.05, -0.62),
        child: Image.asset('assets/ui/jama_a.webp', width: size * 2.4, height: size * 2.4, fit: BoxFit.cover, alignment: Alignment.topCenter),
      ),
    ),
  );
}
