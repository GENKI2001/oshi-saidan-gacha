// Title, machine select and the book.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/figures.dart';
import '../logic/modes.dart';
import '../logic/run.dart';
import 'achievement_screen.dart';
import 'game_screen.dart';
import 'howto_screen.dart';
import 'idol_widgets.dart';
import 'level_card.dart';
import 'lines.dart';
import 'meta.dart';
import 'rank.dart';
import 'rank_screen.dart';
import 'member_screen.dart';
import 'sfx.dart';
import 'voice.dart';
import 'widgets.dart';

const _bg = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A3F8E), Color(0xFF9A5C9E), Color(0xFFE79A8E)],
  ),
);

/// The live hall, warming up, with drifting lights behind [child].
Widget _festival(Widget child) => Container(
  decoration: _bg,
  child: Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/ui/venue_1.jpg', fit: BoxFit.cover),
      const _Twinkles(),
      child,
    ],
  ),
);

const _cardFraction = 0.78;

Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
);

class TitleScreen extends StatefulWidget {
  final Meta meta;
  const TitleScreen({super.key, required this.meta});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin, RouteAware {
  // a tap on one of the five in the key visual: she says something, and hearts pop where you tapped
  static const _kvOrder = ['こはる', 'しずく', 'ひなた', 'よる', 'もも']; // left to right in the picture
  Offset? _tapAt;
  int _tapToken = 0;

  void _tapIdol(TapUpDetails d, Size box) {
    final fx = d.localPosition.dx / box.width, fy = d.localPosition.dy / box.height;
    if (fy < 0.36 || fy > 0.97) return; // the logo and the sky are nobody
    final who = _kvOrder[(fx * _kvOrder.length).floor().clamp(0, _kvOrder.length - 1)];
    final l = idolLines[who]!;
    Voice.say(who, pick([...l.talk, ...l.pull, ...l.sr]), delayMs: 0);
    HapticFeedback.selectionClick();
    setState(() {
      _tapAt = d.localPosition;
      _tapToken++;
    });
  }

  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  // the title's tune comes back whenever the title is on top again, however the screens above
  // were left (a replaced route ends the push's future early, so awaiting it was not enough)
  @override
  void didPopNext() {
    Bgm.play('bgm_title');
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Bgm.play('bgm_title');
    // the title call, once the screen is up
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _who == null) _talk();
    });
  }

  bool _warmed = false;

  /// Loads the pictures the first pulls need while the title is up (on the web they come over the network).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context) case final PageRoute r) routes.subscribe(this, r);
    if (_warmed) return;
    _warmed = true;
    final paths = [
      for (var k = 0; k < 5; k++) ...['assets/ui/capsule_${k}_top.png', 'assets/ui/capsule_${k}_bot.png'],
      for (final m in members) ...[portrait(m), portrait(m, happy: true)],
      for (final f in figures) 'assets/figures/${f.id}.webp',
      for (var k = 0; k < 4; k++) 'assets/ui/venue_$k.jpg',
    ];
    for (final p in paths) {
      precacheImage(AssetImage(p), context).ignore();
    }
  }

  @override
  void dispose() {
    routes.unsubscribe(this);
    _c.dispose();
    super.dispose();
  }

  Widget _toggle(IconData icon, VoidCallback f) => GestureDetector(
    onTap: () {
      f();
      Sfx.play('toggle');
      setState(() {});
    },
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: C.cream,
        shape: BoxShape.circle,
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Icon(icon, color: C.ink, size: 24),
    ),
  );

  /// Until the tutorial is done, playing means the guided first game.
  Future<void> _play() async {
    final m = widget.meta;
    if (!m.tutorialDone) {
      await _go(GameScreen(meta: m, machine: machines.first, tutorial: true));
      return;
    }
    await _go(SelectScreen(meta: m));
  }

  Future<void> _go(Widget page) async {
    Voice.stop();
    await Navigator.of(context).push(_fade(page));
  }

  /// Someone on the key visual says something (the first time: the title call).
  String? _who;
  String _line = '';
  int _token = 0;
  int _taps = 0;

  void _talk() {
    final who = members[math.Random().nextInt(members.length)];
    final l = idolLines[who]!;
    final line = _taps++ == 0 ? pick(l.title) : pick([...l.title, ...l.talk, ...l.pull]);
    Voice.say(who, line, delayMs: 120);
    setState(() {
      _who = who;
      _line = line;
      _token++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return Scaffold(
      body: Container(
        decoration: _bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // all five on the key visual stay in view: the picture is shown whole (fitted, never cropped)
            // over a blurred, zoomed copy of itself that fills the rest of the screen
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.asset('assets/ui/title_bg.jpg', fit: BoxFit.cover),
            ),
            const ColoredBox(color: Color(0x33FFFFFF)),
            Align(
              alignment: const Alignment(0, -0.2),
              child: AspectRatio(
                aspectRatio: 1024 / 1536,
                child: ShaderMask(
                  // the sharp picture melts into the blur at its top and bottom edges
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.08, 0.9, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: LayoutBuilder(
                    builder: (_, bc) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tapIdol(d, bc.biggest),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: Image.asset('assets/ui/title_bg.jpg', fit: BoxFit.fill)),
                          if (_tapAt case final at?)
                            Positioned(
                              left: at.dx - 70,
                              top: at.dy - 70,
                              child: Sparkles(token: _tapToken, size: 140, colors: const [Color(0xFFFF6FA8), Colors.white, Color(0xFFFFE14D)], count: 14),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const _Twinkles(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 58),
                          AnimatedBuilder(
                            animation: _c,
                            builder: (_, c) => Transform.translate(offset: Offset(0, -5 * Curves.easeInOut.transform(_c.value)), child: c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: Image.asset('assets/ui/title.png', semanticLabel: '推し祭壇ガチャ'),
                            ),
                          ),
                          // the idols on the key visual: tap them and someone talks
                          Expanded(
                            child: GestureDetector(
                              key: const ValueKey('idols'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _talk,
                              child: Stack(
                                children: [
                                  if (_who != null)
                                    Positioned(
                                      left: 14,
                                      right: 14,
                                      bottom: 10,
                                      child: IgnorePointer(child: IdolToast(who: _who!, line: _line, token: _token)),
                                    ),
                                  if (_who == null)
                                    Positioned(
                                      right: 18,
                                      bottom: 12,
                                      child: AnimatedBuilder(
                                        animation: _c,
                                        builder: (_, c) => Opacity(opacity: 0.55 + 0.45 * _c.value, child: c),
                                        child: Text('タップすると しゃべるよ', style: outlined(13, Colors.white, stroke: C.pink, width: 3)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // the very first time it is the tutorial; afterwards it just plays
                          // coloured after the members on the key visual above them: ひなた in the middle …
                          PopButton(m.tutorialDone ? 'あそぶ' : 'チュートリアル', fontSize: m.tutorialDone ? 32 : 26, color: idolColor['ひなた']!, onTap: _play),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                // … and left to right こはる, しずく, よる, もも, as they stand
                                for (final (label, color, page) in [
                                  ('図鑑', idolColor['こはる']!, BookScreen(meta: m) as Widget),
                                  ('メンバー', idolColor['しずく']!, const MemberScreen()),
                                  ('実績', idolColor['よる']!, AchievementScreen(meta: m) as Widget),
                                  ('ランキング', idolColor['もも']!, RankScreen(meta: m)),
                                ])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: PopButton(
                                        label,
                                        color: color,
                                        fontSize: 13,
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                                        onTap: () => _go(page),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // the buttons sit well above the bottom edge, over the idols' skirts, not their feet
                          SizedBox(height: math.max(40, MediaQuery.sizeOf(context).height * 0.09)),
                        ],
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: GestureDetector(
                          onTap: () {
                            Sfx.play('toggle');
                            _go(HowToScreen(meta: m));
                          },
                          // same height as the round sound toggles on the right (8 + 24 + 8 + borders)
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                            decoration: BoxDecoration(
                              color: C.cream,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: C.ink, width: 3),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.help_rounded, color: C.ink, size: 22),
                                SizedBox(width: 4),
                                Text(
                                  'あそびかた',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Row(
                          children: [
                            _toggle(m.music ? Icons.music_note_rounded : Icons.music_off_rounded, () {
                              m.toggleMusic();
                              Bgm.setEnabled(m.music);
                            }),
                            const SizedBox(width: 6),
                            _toggle(m.voice ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded, () {
                              m.toggleVoice();
                              Voice.setEnabled(m.voice);
                            }),
                            const SizedBox(width: 6),
                            _toggle(m.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, () {
                              m.toggleSound();
                              Sfx.enabled = m.sound;
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screens that put their own tune back when they are on top again.
final routes = RouteObserver<PageRoute<dynamic>>();

/// Pick a machine (swipe); each card shows how hard it is.
class SelectScreen extends StatefulWidget {
  final Meta meta;
  const SelectScreen({super.key, required this.meta});
  @override
  State<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context) case final PageRoute r) routes.subscribe(this, r);
  }

  @override
  void didPopNext() => Bgm.play('bgm_select');

  late int _i = math.max(0, machines.indexWhere((m) => m.id == widget.meta.lastMachine));
  late final _pc = PageController(initialPage: _i, viewportFraction: _cardFraction);

  @override
  void initState() {
    super.initState();
    Bgm.play('bgm_select');
    // each machine's best spin goes to its own board (only what isn't there yet), then the ranks come back
    () async {
      for (final e in widget.meta.machineTurn.entries) {
        await Rank.instance.submitMachine(e.key, e.value);
      }
      await Rank.instance.refreshMachineRanks();
    }();
  }

  @override
  void dispose() {
    routes.unsubscribe(this);
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final m = machines[_i];
    final open = meta.unlocked(m);
    return Scaffold(
      body: _festival(
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  ScreenHeader('ガチャをえらぶ', trailing: _menuButton()),
                  FractionallySizedBox(
                    widthFactor: _cardFraction,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: LevelCard(meta)),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: Rank.instance,
                      builder: (_, _) => PageView.builder(
                      controller: _pc,
                      itemCount: machines.length,
                      onPageChanged: (i) {
                        Sfx.play('rattle');
                        setState(() => _i = i);
                      },
                      itemBuilder: (_, i) => _card(machines[i], meta.unlocked(machines[i]), i == _i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PopButton(
                    open ? 'はじめる！' : 'まだ遊べない',
                    fontSize: 28,
                    sound: 'handle',
                    onTap: open
                        ? () {
                            meta.remember(m.id);
                            Navigator.of(context).pushReplacement(_fade(GameScreen(meta: meta, machine: m)));
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton() => GestureDetector(
    onTap: _menu,
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: C.cream,
        shape: BoxShape.circle,
        border: Border.all(color: C.ink, width: 3),
      ),
      child: const Icon(Icons.menu_rounded, color: C.ink, size: 24),
    ),
  );

  /// What one might want before picking a machine, without going back to the title:
  /// sound, the book, the members, achievements, ranking and how to play.
  void _menu() {
    Sfx.play('tap');
    final m = widget.meta;
    void open(BuildContext ctx, Widget page) {
      Navigator.of(ctx).pop();
      Navigator.of(context).push(_fade(page));
    }

    Widget sound(IconData icon, VoidCallback toggle, StateSetter set) => GestureDetector(
      onTap: () {
        toggle();
        Sfx.play('toggle');
        set(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: C.cream, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 3)),
        child: Icon(icon, color: C.ink, size: 26),
      ),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Dialog(
          backgroundColor: Colors.transparent,
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // titled like the other screens (あそびかた etc.): on the ribbon
                const Ribbon('メニュー', width: 200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    sound(m.music ? Icons.music_note_rounded : Icons.music_off_rounded, () {
                      m.toggleMusic();
                      Bgm.setEnabled(m.music);
                    }, set),
                    const SizedBox(width: 12),
                    sound(m.voice ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded, () {
                      m.toggleVoice();
                      Voice.setEnabled(m.voice);
                    }, set),
                    const SizedBox(width: 12),
                    sound(m.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, () {
                      m.toggleSound();
                      Sfx.enabled = m.sound;
                    }, set),
                  ],
                ),
                const SizedBox(height: 14),
                // one column, the colours running warm to cool down the list (no two alike)
                for (final (label, color, onTap) in <(String, Color, VoidCallback)>[
                  ('図鑑', idolColor['こはる']!, () => open(ctx, BookScreen(meta: m))),
                  ('ランキング', idolColor['もも']!, () => open(ctx, RankScreen(meta: m))),
                  ('実績', idolColor['よる']!, () => open(ctx, AchievementScreen(meta: m))),
                  ('メンバー', idolColor['しずく']!, () => open(ctx, const MemberScreen())),
                  ('あそびかた', const Color(0xFF3FC2A8), () => open(ctx, HowToScreen(meta: m))),
                  ('とじる', const Color(0xFF8A93A8), () => Navigator.of(ctx).pop()),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: SizedBox(width: 240, child: PopButton(label, fontSize: 18, color: color, onTap: onTap)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(MachineDef m, bool open, bool current) => AnimatedScale(
    scale: current ? 1 : 0.88,
    duration: const Duration(milliseconds: 200),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Panel(
        // the art takes a fixed share so every card's text starts at the same height
        child: Column(
          children: [
            // how far this machine has been played: cleared or not, best songs, best spin
            if (open) _records(m),
            Expanded(
              flex: 5,
              child: MachineArt(hue: m.hue, locked: !open),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 3,
              // a machine with many perks shrinks its text rather than overflow
              child: LayoutBuilder(
                builder: (_, bc) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: bc.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  FittedBox(fit: BoxFit.scaleDown, child: StickerText(m.name, size: 24)), // the name shows even while locked: something to aim for
                  const SizedBox(height: 8),
                  DifficultyBadge(m.difficulty),
                  const SizedBox(height: 2),
                  Text(
                    open ? m.blurb : '解放条件：${m.unlockText}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: C.ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (open)
                    for (final p in m.perks)
                      Text(
                        '・$p',
                        style: const TextStyle(color: C.ink, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      )),
          // "このガチャで全国○位": a medal of its own on the corner (it compares with everyone, unlike the records)
          if (open && Rank.instance.machineRank[m.id] != null)
            Positioned(right: -8, top: 92, child: _RankMedal(Rank.instance.machineRank[m.id]!)), // beside the machine art
        ],
      ),
    ),
  );

  /// A little strip on top of a card: a medal once cleared, the most songs met and the best spin.
  Widget _records(MachineDef m) {
    final meta = widget.meta;
    final cleared = meta.clearedOn.contains(m.id);
    final songs = meta.machineSongs[m.id] ?? 0;
    final turn = meta.machineTurn[m.id] ?? 0;
    Widget pill(Widget icon, String text, Color color) => Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 3), Text(text, style: outlined(13, color, stroke: Colors.white, width: 2.5))],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      // クリア on its own row, the two bests side by side under it
      child: Column(
        children: [
          cleared
              ? pill(Image.asset('assets/ui/ui_medal.png', width: 20, height: 20), 'クリア！', const Color(0xFFE6A700))
              : pill(const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFFB9A8C8)), 'まだクリアしてない', const Color(0xFFB9A8C8)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pill(Image.asset('assets/ui/ui_note.png', width: 18, height: 18), '最高 $songs/${Run.clearPaydays}曲', C.lilac),
                const SizedBox(width: 6),
                pill(const HeartIcon(size: 18), '最高 $turn', C.pink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookScreen extends StatelessWidget {
  final Meta meta;
  const BookScreen({super.key, required this.meta});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.night,
    body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
      child: SafeArea(bottom: false, child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CustomScrollView(
          slivers: [
            // the header scrolls away with the goods
            SliverToBoxAdapter(child: ScreenHeader('図鑑', note: '${meta.seen.length} / ${figures.length}')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverGrid.count(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final f in figures)
              GestureDetector(
                onTap: meta.seen.contains(f.id)
                    ? () {
                        Sfx.play('tap');
                        showFigureInfo(context, f);
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: C.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: meta.seen.contains(f.id) ? C.rarity(f.rarity) : C.woodDark, width: 3),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: meta.seen.contains(f.id)
                      ? FigureArt(f, size: 100)
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                f.level > meta.level ? const Color(0xFF3A2D52) : const Color(0xFF5A4A6A),
                                BlendMode.srcIn,
                              ),
                              child: FigureArt(f, size: 100),
                            ),
                            // not in the gacha yet: show the level that unlocks it
                            if (f.level > meta.level) Text('Lv${f.level}', style: outlined(18, Colors.white, width: 3)),
                          ],
                        ),
                ),
              ),
          ],
              ),
            ),
          ],
        ),
      ),
    ))),
  );
}

/// Soft lights that drift up and twinkle behind the title.
class _Twinkles extends StatefulWidget {
  const _Twinkles();
  @override
  State<_Twinkles> createState() => _TwinklesState();
}

class _TwinklesState extends State<_Twinkles> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _TwinklePainter(_c.value)),
    ),
  );
}

class _TwinklePainter extends CustomPainter {
  final double t;
  _TwinklePainter(this.t);
  static const _colors = [Color(0xFFFFE08A), Color(0xFFFFB3D1), Color(0xFFB8F1FF), Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < 16; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.4 + rnd.nextDouble() * 0.6;
      final y = (rnd.nextDouble() - t * speed) % 1.0 * size.height;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 6 + phase);
      final r = 2.0 + rnd.nextDouble() * 4;
      final color = _colors[i % _colors.length];
      final pos = Offset(x + 6 * math.sin(t * 2 * math.pi * 3 + phase), y);
      canvas.drawCircle(
        pos,
        r * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.15 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      if (i % 3 == 0) {
        // A four-point star glint.
        final s = r * (1.2 + glow);
        final path = Path();
        for (var k = 0; k < 8; k++) {
          final rr = k.isEven ? s : s * 0.3;
          final p = pos + Offset(math.cos(k * math.pi / 4), math.sin(k * math.pi / 4)) * rr;
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), Paint()..color = color.withValues(alpha: 0.35 + 0.35 * glow));
      } else {
        canvas.drawCircle(pos, r * 0.6, Paint()..color = color.withValues(alpha: 0.2 + 0.35 * glow));
      }
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter o) => o.t != t;
}

/// The player's national rank on one machine, as a tilted medal: gold / silver / bronze for the top three.
class _RankMedal extends StatefulWidget {
  final int rank;
  const _RankMedal(this.rank);
  @override
  State<_RankMedal> createState() => _RankMedalState();
}

class _RankMedalState extends State<_RankMedal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _tiers = [
    [Color(0xFFFFF3B0), Color(0xFFFFC21E), Color(0xFFB8860B)], // 1st: gold
    [Color(0xFFFFFFFF), Color(0xFFC9D3DD), Color(0xFF7D8A99)], // 2nd: silver
    [Color(0xFFFFE0C2), Color(0xFFE09A5B), Color(0xFF9A5A2A)], // 3rd: bronze
  ];
  static const _rest = [Color(0xFFFFE6F1), Color(0xFFFF8FC0), Color(0xFFE6A700)]; // pink gold

  @override
  Widget build(BuildContext context) {
    final r = widget.rank;
    final cols = r <= 3 ? _tiers[r - 1] : _rest;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, c) => Transform.rotate(angle: 0.18 + 0.03 * math.sin(_c.value * 2 * math.pi), child: c),
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // the medal
              Positioned(
                top: 14,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: cols),
                    border: Border.all(color: C.ink, width: 3),
                    boxShadow: [BoxShadow(color: cols[1].withValues(alpha: 0.8), blurRadius: 14, spreadRadius: 1)],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('全国', style: outlined(12, Colors.white, stroke: C.ink, width: 2.5).copyWith(height: 1)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '$r', style: outlined(r < 100 ? 28 : 22, Colors.white, stroke: C.ink, width: 4)),
                                TextSpan(text: '位', style: outlined(13, Colors.white, stroke: C.ink, width: 3)),
                              ],
                            ),
                            textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // the crown on top
              const Positioned(
                top: -2,
                child: Icon(Icons.workspace_premium_rounded, size: 30, color: Color(0xFFFFD34D), shadows: [Shadow(color: C.ink, offset: Offset(0, 1.5))]),
              ),
              // a glint travelling round the rim
              Positioned(
                top: 14,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => CustomPaint(size: const Size(78, 78), painter: _Glint(_c.value)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small four-point sparkle travelling round the medal's rim.
class _Glint extends CustomPainter {
  final double t;
  _Glint(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final a = t * 2 * math.pi - math.pi / 2;
    final p = c + Offset(math.cos(a), math.sin(a)) * (size.width / 2 - 4);
    final r = 6 + 2 * math.sin(t * 2 * math.pi * 3);
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final rr = k.isEven ? r : r * 0.3;
      final q = p + Offset(math.cos(k * math.pi / 4), math.sin(k * math.pi / 4)) * rr;
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_Glint o) => o.t != t;
}
