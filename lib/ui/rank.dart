// Leaderboards without our own server: Game Center (iOS) and Google Play
// Games (Android) through games_services. Scores that fail to send are kept
// and sent after the next sign-in.
//
// Leaderboard IDs must match App Store Connect / Play Console (see README).
// `--dart-define=RANK_DEMO=true` fills the boards with clearly labelled demo
// players so the screen can be checked on a simulator before the stores are
// set up.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/modes.dart';

enum Board { bestTurn, paydays }

class BoardInfo {
  final String title, unit, ios, android;
  final TimeScope time;
  const BoardInfo(this.title, this.unit, this.ios, this.android, this.time);
}

/// Edit these to the IDs you create in the stores.
const boards = {
  Board.bestTurn: BoardInfo('1回の最高ハート', 'ハート', 'oshi.best_turn', 'CgkI_REPLACE_best_turn', TimeScope.allTime),
  Board.paydays: BoardInfo('成功した曲の数', '曲', 'oshi.paydays', 'CgkI_REPLACE_paydays', TimeScope.allTime),
};

/// One board per machine: the best single spin on that machine ("このガチャで全国○位").
/// Create these in App Store Connect / Play Console with the same IDs (see README),
/// then replace the Android placeholders with the IDs Play gives.
final machineBoards = {
  for (final m in machines) m.id: BoardInfo('${m.name}の最高ハート', 'ハート', 'oshi.turn.${m.id}', 'CgkI_REPLACE_turn_${m.id}', TimeScope.allTime),
};

class RankEntry {
  final int rank, score;
  final String name;
  final bool me;
  final Uint8List? icon;
  const RankEntry(this.rank, this.name, this.score, {this.me = false, this.icon});
}

enum RankState { off, signingIn, ready, unavailable }

class Rank extends ChangeNotifier {
  static const demo = bool.fromEnvironment('RANK_DEMO');
  static final instance = Rank._();
  Rank._();

  RankState state = RankState.off;
  String? playerName;
  String? error;
  final Map<Board, int> _pending = {};
  final Map<String, int> _pendingMachine = {}; // machine id → best spin not sent yet
  final Map<String, int> machineRank = {}; // machine id → the player's rank there, once known
  final Map<String, int> _sentMachine = {}; // machine id → the best already on its board
  SharedPreferences? _p;

  bool get ready => state == RankState.ready;

  Future<void> start() async {
    try {
      _p = await SharedPreferences.getInstance();
      for (final b in Board.values) {
        final v = _p!.getInt('pending_${b.name}');
        if (v != null) _pending[b] = v;
      }
      for (final id in machineBoards.keys) {
        final v = _p!.getInt('pending_m_$id');
        if (v != null) _pendingMachine[id] = v;
        final s = _p!.getInt('sent_m_$id');
        if (s != null) _sentMachine[id] = s;
      }
    } catch (_) {}
    await signIn();
  }

  Future<void> signIn() async {
    if (demo) {
      state = RankState.ready;
      playerName = 'あなた';
      notifyListeners();
      return;
    }
    if (kIsWeb) {
      state = RankState.unavailable;
      error = 'ブラウザ版ではランキングは使えません';
      notifyListeners();
      return;
    }
    state = RankState.signingIn;
    notifyListeners();
    try {
      await GameAuth.signIn();
      if (await GameAuth.isSignedIn) {
        state = RankState.ready;
        playerName = await Player.getPlayerName();
        error = null;
        unawaited(_flush());
      } else {
        state = RankState.unavailable;
        error = 'ログインできませんでした';
      }
    } catch (e) {
      state = RankState.unavailable;
      error = _explain(e);
    }
    notifyListeners();
  }

  String _explain(Object e) {
    final s = e.toString();
    debugPrint('[Rank] $s');
    if (s.contains('not recognized') || s.contains('GKErrorDomain error 15')) {
      return 'このアプリはまだ Game Center に登録されていません';
    }
    if (s.contains('not been authenticated') || s.contains('cancel')) {
      return 'Game Center にログインしていません\n設定アプリ →「Game Center」でログインしてね';
    }
    if (s.contains('MissingPlugin')) return 'この環境ではランキングを使えません';
    return 'ランキングに接続できませんでした';
  }

  // ── sending ──

  /// Sends a score; it is kept and retried later if it cannot be sent now.
  Future<void> submit(Board b, int value) async {
    final best = _pending[b];
    if (best == null || value > best) _pending[b] = value;
    _savePending();
    if (ready) await _flush();
  }

  /// The best spin on one machine; kept and retried like [submit].
  Future<void> submitMachine(String id, int value) async {
    if (value <= (_sentMachine[id] ?? 0)) return; // already there
    final best = _pendingMachine[id];
    if (best == null || value > best) _pendingMachine[id] = value;
    _savePending();
    if (ready) await _flush();
  }

  Future<void> _flush() async {
    if (demo) {
      _demoMine.addAll(_pending);
      _demoMachine.addAll(_pendingMachine);
      _pending.clear();
      _pendingMachine.clear();
      _savePending();
      return;
    }
    for (final id in [..._pendingMachine.keys]) {
      final info = machineBoards[id];
      if (info == null) continue;
      try {
        await Leaderboards.submitScore(
          score: Score(iOSLeaderboardID: info.ios, androidLeaderboardID: info.android, value: _pendingMachine[id]!),
        );
        _sentMachine[id] = _pendingMachine.remove(id)!;
        _p?.setInt('sent_m_$id', _sentMachine[id]!);
      } catch (_) {
        // not set up in the stores yet, or offline: keep it for the next try
      }
    }
    for (final b in [..._pending.keys]) {
      final info = boards[b]!;
      try {
        await Leaderboards.submitScore(
          score: Score(iOSLeaderboardID: info.ios, androidLeaderboardID: info.android, value: _pending[b]!),
        );
        _pending.remove(b);
      } catch (_) {
        // keep it for the next try
      }
    }
    _savePending();
  }

  void _savePending() {
    final p = _p;
    if (p == null) return;
    for (final b in Board.values) {
      final v = _pending[b];
      v == null ? p.remove('pending_${b.name}') : p.setInt('pending_${b.name}', v);
    }
    for (final id in machineBoards.keys) {
      final v = _pendingMachine[id];
      v == null ? p.remove('pending_m_$id') : p.setInt('pending_m_$id', v);
    }
  }

  /// Fetches the player's rank on every machine board (for the gacha select's cards).
  /// Boards that don't exist yet or have no score just stay unknown.
  Future<void> refreshMachineRanks() async {
    if (!ready) return;
    for (final e in machineBoards.entries) {
      int? r;
      if (demo) {
        final mine = _demoMachine[e.key];
        r = mine == null ? null : (5000 ~/ (mine + 10)).clamp(1, 999) + 1;
      } else {
        try {
          final s = await Leaderboards.getPlayerScoreObject(
            iOSLeaderboardID: e.value.ios,
            androidLeaderboardID: e.value.android,
            scope: PlayerScope.global,
            timeScope: e.value.time,
          );
          r = s?.rank;
        } catch (_) {}
      }
      if (r != null && r > 0) machineRank[e.key] = r;
    }
    notifyListeners();
  }

  // ── reading ──

  Future<List<RankEntry>> load(Board b, {bool friends = false, int max = 25}) async {
    if (demo) return _demoBoard(b, friends);
    if (!ready) return const [];
    final info = boards[b]!;
    final scope = friends ? PlayerScope.friendsOnly : PlayerScope.global;
    final list = await Leaderboards.loadLeaderboardScores(
      iOSLeaderboardID: info.ios,
      androidLeaderboardID: info.android,
      scope: scope,
      timeScope: info.time,
      maxResults: max,
      forceRefresh: true,
    );
    final myId = await Player.getPlayerID();
    return [
      for (final s in list ?? const <LeaderboardScoreData>[])
        RankEntry(
          s.rank,
          s.scoreHolder.displayName,
          s.rawScore,
          me: s.scoreHolder.playerID != null && s.scoreHolder.playerID == myId,
          icon: _icon(s.scoreHolder.iconImage),
        ),
    ];
  }

  /// The player's own rank on a board, or null.
  Future<int?> myRank(Board b) async {
    if (demo) {
      final l = _demoBoard(b, false);
      for (final e in l) {
        if (e.me) return e.rank;
      }
      return null;
    }
    if (!ready) return null;
    final info = boards[b]!;
    try {
      final s = await Leaderboards.getPlayerScoreObject(
        iOSLeaderboardID: info.ios,
        androidLeaderboardID: info.android,
        scope: PlayerScope.global,
        timeScope: info.time,
      );
      return s?.rank;
    } catch (_) {
      return null;
    }
  }

  /// Opens the store's own leaderboard screen.
  Future<void> showNative(Board b) async {
    if (demo || !ready) return;
    final info = boards[b]!;
    try {
      await Leaderboards.showLeaderboards(iOSLeaderboardID: info.ios, androidLeaderboardID: info.android, timeScope: info.time);
    } catch (_) {}
  }

  Uint8List? _icon(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  // ── demo data (RANK_DEMO only; every name says it is a demo) ──
  final Map<Board, int> _demoMine = {};
  final Map<String, int> _demoMachine = {};

  List<RankEntry> _demoBoard(Board b, bool friends) {
    const names = ['デモ たぬ吉', 'デモ こばん', 'デモ きつね', 'デモ わたあめ', 'デモ ラムネ', 'デモ 太鼓', 'デモ 金魚', 'デモ だるま'];
    final base = switch (b) {
      Board.bestTurn => 900,
      Board.paydays => 14,
    };
    final others = [
      for (var i = 0; i < (friends ? 3 : names.length); i++)
        (names[i], (base * (1 - i * 0.11)).round()),
    ];
    final mine = _demoMine[b] ?? _pending[b];
    final all = [...others.map((o) => (o.$1, o.$2, false)), if (mine != null) ('あなた', mine, true)]..sort((x, y) => y.$2.compareTo(x.$2));
    return [for (var i = 0; i < all.length; i++) RankEntry(i + 1, all[i].$1, all[i].$2, me: all[i].$3)];
  }
}
