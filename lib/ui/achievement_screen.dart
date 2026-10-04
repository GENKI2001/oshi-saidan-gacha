// 実績: the list, the "unlocked!" toast, and the シチュエーションボイス player that
// achievements open.

import 'dart:math' as math;
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../logic/achievements.dart';
import '../logic/defs.dart';
import '../logic/modes.dart';
import 'asmr_timing.dart';
import 'idol_widgets.dart';
import 'lines.dart';
import 'meta.dart';
import 'sfx.dart';
import 'voice.dart';
import 'widgets.dart';

/// The face for a whisper track's speaker (つむぎ uses her happy bust).
Widget _face(String who, double size) => who == kTsumugi
    ? Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFDDF5E4),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: ClipOval(
          child: OverflowBox(
            maxHeight: size * 2.4,
            alignment: Alignment.topCenter,
            child: Padding(padding: EdgeInsets.only(top: size * 0.08), child: Image.asset('assets/ui/boss_1.png', height: size * 2.4)),
          ),
        ),
      )
    : IdolFace(who, size: size);

Widget _withIcon(IconData icon, String text, Color col) => Row(
  children: [
    Icon(icon, size: 14, color: col),
    const SizedBox(width: 3),
    Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: col))),
  ],
);

/// Slides in at the top of the game when achievements are unlocked.
class AchievementToast extends StatelessWidget {
  final List<Achievement> got;
  final int token;
  const AchievementToast(this.got, {super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final a = got.first;
    final track = a.asmr == null ? null : asmrById[a.asmr];
    return TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 4200),
      builder: (_, t, c) {
        final ms = t * 4200;
        final inT = Curves.easeOutBack.transform((ms / 400).clamp(0, 1));
        final out = ((ms - 3700) / 500).clamp(0.0, 1.0);
        return Opacity(opacity: 1 - out, child: Transform.translate(offset: Offset(0, -60 * (1 - inT)), child: c));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF4C2), Color(0xFFFFE0F0)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.ink, width: 3),
          boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.7), blurRadius: 14)],
        ),
        child: Row(
          children: [
            Image.asset('assets/ui/ui_medal.png', width: 44, height: 44),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('実績解除！ ${a.title}${got.length > 1 ? ' ほか${got.length - 1}件' : ''}', style: outlined(15, C.pink, stroke: Colors.white, width: 3)),
                  if (track != null)
                    _withIcon(Icons.record_voice_over_rounded, '${track.who}のシチュエーションボイスが 聞けるように！', C.ink)
                  else
                    Text(a.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.ink)),
                ],
              ),
            ),
            if (track != null) _face(track.who, 40),
          ],
        ),
      ),
    );
  }
}

/// A first clear: the same toast as a 実績, with the goods it brought into the gacha.
class NewGoodsToast extends StatelessWidget {
  final MachineDef machine;
  final List<FigureDef> news;
  final int token;
  const NewGoodsToast(this.machine, this.news, {super.key, required this.token});

  @override
  Widget build(BuildContext context) => _ToastFrame(
    token: token,
    icon: Image.asset('assets/ui/ui_medal.png', width: 44, height: 44),
    title: '${machine.name} 初クリア！',
    body: Row(
      children: [
        Text('新しく ${news.length} 種がガチャに ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.ink)),
        for (final f in news.take(5)) FigureArt(f, size: 22),
      ],
    ),
  );
}

/// The frame the top-of-screen toasts share: slides down, stays, fades.
class _ToastFrame extends StatelessWidget {
  final int token;
  final Widget icon, body;
  final String title;
  const _ToastFrame({required this.token, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(token),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 4200),
    builder: (_, t, c) {
      final ms = t * 4200;
      final inT = Curves.easeOutBack.transform((ms / 400).clamp(0, 1));
      final out = ((ms - 3700) / 500).clamp(0.0, 1.0);
      return Opacity(opacity: 1 - out, child: Transform.translate(offset: Offset(0, -60 * (1 - inT)), child: c));
    },
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF4C2), Color(0xFFFFE0F0)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.ink, width: 3),
        boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.7), blurRadius: 14)],
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, style: outlined(15, C.pink, stroke: Colors.white, width: 3))),
                body,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A gacha just unlocked: the same toast as a 実績, with the machine on it.
class UnlockToast extends StatelessWidget {
  final List<MachineDef> got;
  final int token;
  const UnlockToast(this.got, {super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final m = got.first;
    return _ToastFrame(
      token: token,
      icon: MachineArt(hue: m.hue, height: 44),
      title: 'ガチャ解放！ ${m.name}${got.length > 1 ? ' ほか${got.length - 1}台' : ''}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.blurb, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.ink)),
          DifficultyBadge(m.difficulty, size: 11),
        ],
      ),
    );
  }
}

class AchievementScreen extends StatefulWidget {
  final Meta meta;
  const AchievementScreen({super.key, required this.meta});
  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  @override
  void initState() {
    super.initState();
    widget.meta.checkAchievements(); // records made before 実績 existed count too
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    final st = m.stats;
    final done = achievements.where((a) => m.achieved.contains(a.id)).length;
    return Scaffold(
      backgroundColor: C.night,
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
        child: SafeArea(bottom: false, child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                // the header scrolls away with the list
                ScreenHeader('実績', note: '$done / ${achievements.length}'),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.ink, width: 2)),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, color: C.pink, size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '実績を達成すると、メンバーの「シチュエーションボイス」が聞けるようになるよ。あなただけの特別なひとときを！',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.ink, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final a in achievements) _row(a, st, m.achieved.contains(a.id)),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _row(Achievement a, Stats st, bool got) {
    final (now, goal) = a.progress(st);
    final track = a.asmr == null ? null : asmrById[a.asmr];
    final col = track == null ? C.gold : idolColor[track.who]!;
    return Container(
      key: ValueKey('ach-${a.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: got ? [Colors.white, Color.lerp(col, Colors.white, 0.8)!] : const [Color(0xFFF2EEF4), Color(0xFFE8E2EC)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: got ? col : const Color(0xFFB9AEC0), width: 3),
      ),
      child: Row(
        children: [
          Opacity(opacity: got ? 1 : 0.35, child: Image.asset('assets/ui/ui_medal.png', width: 44, height: 44)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: outlined(16, got ? C.pink : const Color(0xFF9A8FA2), stroke: Colors.white, width: 3)),
                Text(a.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.ink)),
                if (!got && goal > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: (now / goal).clamp(0.0, 1.0), minHeight: 8, color: col, backgroundColor: Colors.white),
                    ),
                  ),
                if (!got && goal > 1) Text('${now.clamp(0, goal)} / $goal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.ink)),
                if (track != null)
                  _withIcon(
                    got ? Icons.record_voice_over_rounded : Icons.lock_rounded,
                    got ? '${track.who}「${track.title}」' : '${track.who}のシチュエーションボイス',
                    got ? col : const Color(0xFF9A8FA2),
                  ),
              ],
            ),
          ),
          if (track != null)
            got
                ? PopButton(
                    '聞く',
                    key: ValueKey('listen-${track.id}'),
                    color: col,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AsmrScreen(track: track))),
                  )
                : Opacity(opacity: 0.5, child: _face(track.who, 42)),
        ],
      ),
    );
  }
}

/// Plays one シチュエーションボイス with its lines as subtitles.
class AsmrScreen extends StatefulWidget {
  final AsmrTrack track;
  const AsmrScreen({super.key, required this.track});
  @override
  State<AsmrScreen> createState() => _AsmrScreenState();
}

class _AsmrScreenState extends State<AsmrScreen> {
  final _p = AudioPlayer()..positionUpdater = null;
  Timer? _pos;
  StreamSubscription<void>? _done;
  int _ms = 0;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    Voice.stop();
    Bgm.pause(true); // just her voice
    // poll the position for the subtitles (works the same on every platform)
    _pos = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      final d = await _p.getCurrentPosition();
      if (mounted && d != null && d.inMilliseconds != _ms) setState(() => _ms = d.inMilliseconds);
    });
    _done = _p.onPlayerComplete.listen((_) => setState(() => _playing = false));
    _play();
  }

  Future<void> _play() async {
    try {
      await _p.stop();
      await _p.play(AssetSource('asmr/${widget.track.id}.m4a'));
      setState(() {
        _playing = true;
        _ms = 0;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _pos?.cancel();
    _done?.cancel();
    _p.dispose();
    Bgm.pause(false);
    super.dispose();
  }

  int get _line {
    final starts = asmrStarts[widget.track.id] ?? const [];
    var k = -1;
    for (var i = 0; i < starts.length; i++) {
      if (_ms >= starts[i]) k = i;
    }
    return k;
  }

  /// Her face for a line: shy and touched on the tender ones, beaming on the excited ones.
  String _expression(String line) {
    if (RegExp(r'…|ありがと|秘密|ないしょ|照れ|ドキドキ|どきどき|ほんと|気持ち|約束|特別|夢').hasMatch(line)) return 'c';
    if (RegExp(r'！|やった|だいすき|だーいすき|おめでと|すごい|わぁ|きゃー').hasMatch(line)) return 'b';
    return 'a';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final col = idolColor[t.who]!;
    final cur = _line;
    final line = cur < 0 ? null : t.lines[cur];
    final face = line == null ? 'a' : _expression(line);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1230),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(t.title, style: outlined(20, Colors.white, stroke: col, width: 3))),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: 0.45, child: Image.asset('assets/ui/venue_0.jpg', fit: BoxFit.cover)),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col.withValues(alpha: 0.18), const Color(0xFF1A1230).withValues(alpha: 0.85)]))),
          SafeArea(
            child: Column(
              children: [
                // she stands in a fixed box: the length of the line never moves her
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: 8,
                        child: _Breathing(
                          // a little hop as each line starts
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(cur),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 520),
                            builder: (_, v, c) => Transform.translate(
                              offset: Offset(0, -math.sin(v * math.pi) * (face == 'b' ? 18 : 8)),
                              child: Transform.rotate(angle: math.sin(v * math.pi) * (face == 'b' ? 0.025 : (face == 'c' ? -0.015 : 0)), child: c),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              child: Image.asset(
                                portrait(t.who, face: face),
                                key: ValueKey(face),
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // shy lines get a few floating hearts
                      if (face == 'c')
                        Positioned(
                          right: 40,
                          top: 60,
                          child: IgnorePointer(child: Sparkles(token: cur + 1, size: 120, colors: [col, Colors.white, const Color(0xFFFF8FC0)], count: 10)),
                        ),
                    ],
                  ),
                ),
                // what she is saying, in a speech bubble of fixed height
                SizedBox(
                  height: 150,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: FadeTransition(opacity: a, child: c)),
                      child: _bubble(t.who, line ?? '……', col, key: ValueKey(cur)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PopButton(_playing ? 'もう一度はじめから' : '▶ 聞く', color: col, fontSize: 18, onTap: _play),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String who, String text, Color col, {Key? key}) => Stack(
    key: key,
    clipBehavior: Clip.none,
    children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: col, width: 3),
          boxShadow: [BoxShadow(color: col.withValues(alpha: 0.45), blurRadius: 14)],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w900, color: C.ink)),
            ),
          ),
        ),
      ),
      // the tail points up at her
      Positioned(
        top: 2,
        left: 0,
        right: 0,
        child: Center(child: CustomPaint(size: const Size(28, 16), painter: _TailPainter(col))),
      ),
      // her name on a tag
      Positioned(
        left: 14,
        top: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
          child: Text(who, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ),
    ],
  );
}

/// A slow, gentle breathing sway, so she never stands frozen.
class _Breathing extends StatefulWidget {
  final Widget child;
  const _Breathing({required this.child});
  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, c) {
      final v = math.sin(_c.value * 2 * math.pi);
      return Transform.translate(
        offset: Offset(0, v * 3),
        child: Transform.scale(scale: 1 + v * 0.008, alignment: Alignment.bottomCenter, child: c),
      );
    },
    child: widget.child,
  );
}

/// The little triangle on top of the speech bubble.
class _TailPainter extends CustomPainter {
  final Color col;
  _TailPainter(this.col);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height),
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_TailPainter o) => o.col != col;
}
