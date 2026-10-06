// In-game leaderboard screen (data from Game Center / Play Games via rank.dart).
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'idol_widgets.dart';
import 'meta.dart';
import 'rank.dart';
import 'sfx.dart';
import 'widgets.dart';

class RankScreen extends StatefulWidget {
  final Board initial;
  final Meta? meta;
  const RankScreen({super.key, this.initial = Board.bestTurn, this.meta});
  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  final r = Rank.instance;
  late Board _board = widget.initial;
  bool _friends = false;
  Future<List<RankEntry>>? _rows;

  @override
  void initState() {
    super.initState();
    r.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    r.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final rows = r.ready ? r.load(_board, friends: _friends) : null;
    setState(() {
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_2.jpg'), fit: BoxFit.cover)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC241A4A), Color(0x99241A4A), Color(0xDD241A4A)]),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // one scroll: the header goes up with the list
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // back, and the title on a ribbon (clear of the arrow)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 30),
                        ),
                        Expanded(child: Center(child: Ribbon(tr('ランキング'), width: 210))),
                        // as wide as the arrow, so the ribbon sits in the middle
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  if (Rank.demo) Text(tr('デモ表示'), style: outlined(12, C.red, stroke: Colors.white, width: 2)),
                  const SizedBox(height: 4),
                  // which board, then 全国 / フレンド
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (final b in Board.values) Expanded(child: _tab(b, _board == b)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _scopeToggle(),
                  const SizedBox(height: 10),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _body()),
                  if (r.ready && !Rank.demo)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                      child: PopButton(_storeName(context), fontSize: 15, color: const Color(0xFF4FA3D9), onTap: () => r.showNative(_board)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  String _storeName(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS ? tr('Game Center で見る') : tr('Play ゲームで見る');

  void _pick(Board b) {
    Sfx.play('toggle');
    _board = b;
    _reload();
  }

  void _scope(bool friends) {
    Sfx.play('toggle');
    _friends = friends;
    _reload();
  }

  static const _boardIcon = {Board.bestTurn: 'assets/ui/ui_heart.png', Board.paydays: 'assets/ui/ui_note.png'};

  /// A big board tab with its icon (pink when picked).
  Widget _tab(Board b, bool on) => GestureDetector(
    onTap: () => _pick(b),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        gradient: on
            ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF9EC9), Color(0xFFFF5FA2)])
            : const LinearGradient(colors: [Colors.white, Color(0xFFFFF0F7)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on ? Colors.white : C.ink, width: 3),
        boxShadow: on ? [BoxShadow(color: C.pink.withValues(alpha: 0.6), blurRadius: 14)] : const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(_boardIcon[b]!, width: 26, height: 26),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tr(boards[b]!.title), style: on ? outlined(15, Colors.white, stroke: C.ink, width: 3) : const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.ink)),
            ),
          ),
        ],
      ),
    ),
  );

  /// 全国 / フレンド as one pill with a sliding knob.
  Widget _scopeToggle() => Container(
    width: 220,
    height: 38,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0x66000000),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white54, width: 2),
    ),
    child: Stack(
      children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          alignment: _friends ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 1,
            child: Container(decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.ink, width: 2))),
          ),
        ),
        Row(
          children: [
            for (final (label, f) in [('全国', false), ('フレンド', true)])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _scope(f),
                  child: Center(
                    child: Text(tr(label), style: _friends == f ? const TextStyle(fontWeight: FontWeight.w900, color: C.ink) : const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _body() {
    if (r.state == RankState.signingIn) return _msg('ログイン中…', null);
    if (!r.ready) {
      return _msg(r.error ?? 'ランキングを見るにはログインしてね', PopButton(tr('ログインする'), onTap: r.signIn));
    }
    return FutureBuilder<List<RankEntry>>(
      future: _rows,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _msg('よみこみ中…', null);
        if (snap.hasError) return _msg('ランキングを読めませんでした', PopButton(tr('もう一回'), onTap: _reload));
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return _msg(_friends ? 'フレンドのスコアはまだないよ' : 'まだ誰もいない。一番乗りのチャンス！', null);
        final info = boards[_board]!;
        final top = rows.take(3).toList();
        return Column(
          children: [
            _podium(top, info),
            const SizedBox(height: 10),
            for (final e in rows.skip(3)) _row(e, info),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  static const _medal = [Color(0xFFFFC93C), Color(0xFFC9D3DD), Color(0xFFE09A5B)];
  static const _faces = ['ひなた', 'しずく', 'こはる', 'よる', 'もも'];

  Widget _avatar(RankEntry e, double size) => e.icon != null
      ? Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          child: ClipOval(child: Image.memory(e.icon!, fit: BoxFit.cover)),
        )
      : IdolFace(_faces[(e.rank - 1) % _faces.length], size: size);

  /// 1st in the middle (tallest), 2nd left, 3rd right, each on a step with a medal.
  Widget _podium(List<RankEntry> top, BoardInfo info) {
    Widget place(RankEntry e, double step) {
      final col = _medal[e.rank - 1];
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (e.rank == 1) const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD34D), size: 36),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: col.withValues(alpha: 0.8), blurRadius: 16, spreadRadius: 2)]),
                  child: _avatar(e, e.rank == 1 ? 68 : 56),
                ),
                if (e.me) Positioned(bottom: -6, child: _meTag()),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr(e.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: outlined(13, Colors.white, width: 3)),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${e.score}', style: outlined(e.rank == 1 ? 24 : 19, C.gold, width: 4)),
                TextSpan(text: ' ${tr(info.unit)}', style: outlined(11, Colors.white, width: 2)),
              ]),
            ),
            const SizedBox(height: 4),
            Container(
              height: step,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(col, Colors.white, 0.4)!, col]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border.all(color: C.ink, width: 3),
              ),
              alignment: Alignment.center,
              child: Text('${e.rank}', style: outlined(30, Colors.white, stroke: C.ink, width: 5)),
            ),
          ],
        ),
      );
    }

    final byRank = {for (final e in top) e.rank: e};
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white38, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (byRank[2] case final e?) place(e, 70) else const Spacer(),
          if (byRank[1] case final e?) place(e, 96) else const Spacer(),
          if (byRank[3] case final e?) place(e, 52) else const Spacer(),
        ],
      ),
    );
  }

  Widget _meTag() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: C.pink, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2)),
    child: Text(tr('あなた'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
  );

  /// 4th and below: a card each, yours glowing pink.
  Widget _row(RankEntry e, BoardInfo info) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: e.me ? const [Color(0xFFFFE0EF), Color(0xFFFFF4C2)] : const [Colors.white, Color(0xFFF6EEFF)]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: e.me ? C.pink : C.ink, width: e.me ? 3.5 : 2.5),
      boxShadow: e.me ? [BoxShadow(color: C.pink.withValues(alpha: 0.7), blurRadius: 14)] : const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3), blurRadius: 4)],
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.lilac, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 2.5)),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text('${e.rank}', style: outlined(17, Colors.white, stroke: C.ink, width: 3))),
        ),
        const SizedBox(width: 8),
        _avatar(e, 40),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(child: Text(tr(e.name), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.ink))),
              if (e.me) ...[const SizedBox(width: 4), _meTag()],
            ],
          ),
        ),
        Text('${e.score}', style: outlined(21, C.gold, width: 3)),
        Text(' ${tr(info.unit)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.ink)),
      ],
    ),
  );

  Widget _msg(String t, Widget? action) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/boss_0.png', height: 90),
          Text(tr(t), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.ink)),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    ),
  );
}
