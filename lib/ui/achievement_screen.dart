// 実績: the list, the "unlocked!" toast, and the ささやきボイス player that
// achievements open.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../logic/achievements.dart';
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
                    _withIcon(Icons.headphones_rounded, '${track.who}のささやきボイスが 聞けるように！', C.ink)
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
      appBar: AppBar(
        backgroundColor: C.night,
        foregroundColor: Colors.white,
        title: Text('実績 $done / ${achievements.length}', style: outlined(22, Colors.white, width: 2)),
      ),
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.ink, width: 2)),
                  child: Row(
                    children: [
                      const Icon(Icons.headphones_rounded, color: C.pink, size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '実績を達成すると、メンバーの「ささやきボイス」が聞けるようになるよ。ヘッドホン推奨！',
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
        ),
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
                    got ? Icons.headphones_rounded : Icons.lock_rounded,
                    got ? '${track.who}「${track.title}」' : '${track.who}のささやきボイス',
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

/// Plays one ささやきボイス track with its lines as subtitles.
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

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final col = idolColor[t.who]!;
    final cur = _line;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1230),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(t.title, style: outlined(20, Colors.white, stroke: col, width: 3))),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: 0.35, child: Image.asset('assets/ui/venue_0.jpg', fit: BoxFit.cover)),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, const Color(0xFF1A1230).withValues(alpha: 0.9)]))),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headphones_rounded, color: Colors.white, size: 18, shadows: [Shadow(color: col, blurRadius: 4)]),
                    const SizedBox(width: 4),
                    Text('ヘッドホン推奨', style: outlined(14, Colors.white, stroke: col, width: 3)),
                  ],
                ),
                Expanded(
                  child: t.who == kTsumugi
                      ? Image.asset('assets/ui/boss_1.png', fit: BoxFit.contain)
                      : Image.asset(portrait(t.who), fit: BoxFit.contain, alignment: Alignment.topCenter),
                ),
                // the line she is whispering now, the others faint
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      cur < 0 ? '……' : t.lines[cur],
                      key: ValueKey(cur),
                      textAlign: TextAlign.center,
                      style: outlined(18, Colors.white, stroke: Color.lerp(col, C.ink, 0.4)!, width: 4).copyWith(height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PopButton(_playing ? 'もう一度はじめから' : '▶ 聞く', color: col, fontSize: 18, onTap: _play),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
