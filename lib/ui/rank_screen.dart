// In-game leaderboard screen (data from Game Center / Play Games via rank.dart).
import 'package:flutter/material.dart';

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.night, C.night2, Color(0xFF8A4A5E)]),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 30),
                    ),
                    Text('ランキング', style: outlined(26, C.gold, width: 3)),
                    const Spacer(),
                    if (Rank.demo) Text('デモ表示  ', style: outlined(14, C.red, stroke: Colors.white, width: 2)),
                  ],
                ),
                if (widget.meta case final m?) ...[_records(m), const SizedBox(height: 10)],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [for (final b in Board.values) Expanded(child: _tab(boards[b]!.title, _board == b, () => _pick(b)))],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chip('全国', !_friends, () => _scope(false)),
                    const SizedBox(width: 8),
                    _chip('フレンド', _friends, () => _scope(true)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _body()),
                ),
                if (r.ready && !Rank.demo)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: PopButton(_storeName(context), fontSize: 15, color: const Color(0xFF4FA3D9), onTap: () => r.showNative(_board)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String _storeName(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS ? 'Game Center で見る' : 'Play ゲームで見る';

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

  /// This device's own records, shown above the online boards.
  Widget _records(Meta m) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        children: [
          const Text(
            'じぶんの記録',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.ink),
          ),
          const SizedBox(height: 4),
          Row(children: [_stat('最高 払った回数', '${m.bestPaydays}'), _stat('一回の最高', '${m.bestTurn}'), _stat('完済', '${m.clears}')]),
        ],
      ),
    ),
  );

  Widget _stat(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: C.wood,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.woodDark, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: C.ink, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          Text(value, style: outlined(22, C.gold, width: 3)),
        ],
      ),
    ),
  );

  Widget _tab(String t, bool on, VoidCallback f) => GestureDetector(
    onTap: f,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: on ? C.pink : C.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: on ? outlined(14, Colors.white, width: 2) : const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.ink),
      ),
    ),
  );

  Widget _chip(String t, bool on, VoidCallback f) => GestureDetector(
    onTap: f,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: on ? C.gold : Colors.white24,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.ink, width: 2),
      ),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.w900, color: on ? C.ink : Colors.white),
      ),
    ),
  );

  Widget _body() {
    if (r.state == RankState.signingIn) return _msg('ログイン中…', null);
    if (!r.ready) {
      return _msg(r.error ?? 'ランキングを見るにはログインしてね', PopButton('ログインする', onTap: r.signIn));
    }
    return FutureBuilder<List<RankEntry>>(
      future: _rows,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _msg('よみこみ中…', null);
        if (snap.hasError) return _msg('ランキングを読めませんでした', PopButton('もう一回', onTap: _reload));
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return _msg(_friends ? 'フレンドのスコアはまだないよ' : 'まだ誰もいない。一番乗りのチャンス！', null);
        final info = boards[_board]!;
        return ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => _row(rows[i], info));
      },
    );
  }

  Widget _row(RankEntry e, BoardInfo info) {
    final medal = switch (e.rank) {
      1 => const Color(0xFFFFC93C),
      2 => const Color(0xFFC9D3DD),
      3 => const Color(0xFFE09A5B),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: e.me ? const Color(0xFFFFF0B3) : C.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: e.me ? C.pink : C.ink, width: e.me ? 3.5 : 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: medal != null
                ? Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medal,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.ink, width: 2.5),
                    ),
                    child: Text('${e.rank}', style: outlined(18, Colors.white, width: 3)),
                  )
                : Text('${e.rank}', style: outlined(20, Colors.white, width: 3)),
          ),
          ClipOval(
            child: e.icon != null
                ? Image.memory(e.icon!, width: 34, height: 34, fit: BoxFit.cover)
                : Image.asset('assets/ui/boss_${e.rank % 4}.png', width: 34, height: 34),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.me ? '${e.name}（あなた）' : e.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.ink),
            ),
          ),
          Text(_board == Board.ascension ? '段位 ${e.score}' : '${e.score}', style: outlined(20, C.gold, width: 3)),
          if (_board != Board.ascension)
            Text(
              ' ${info.unit}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.ink),
            ),
        ],
      ),
    );
  }

  Widget _msg(String t, Widget? action) => Center(
    child: Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/boss_0.png', height: 90),
          Text(
            t,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.ink),
          ),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    ),
  );
}
