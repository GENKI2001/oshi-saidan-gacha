// Picking a gacha: a swipeable card per machine with its records and national rank, and the menu.

part of '../title_screen.dart';

const _cardFraction = 0.78;

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

  Widget _menuButton() => RoundIconButton(Icons.menu_rounded, onTap: _menu);

  /// What one might want before picking a machine, without going back to the title:
  /// sound, the book, the members, achievements, ranking and how to play.
  void _menu() {
    Sfx.play('tap');
    final m = widget.meta;
    void open(BuildContext ctx, Widget page) {
      Navigator.of(ctx).pop();
      Navigator.of(context).push(_fade(page));
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // titled like the other screens (あそびかた etc.): on the ribbon
              const Ribbon('メニュー', width: 200),
              SoundToggles(m),
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
