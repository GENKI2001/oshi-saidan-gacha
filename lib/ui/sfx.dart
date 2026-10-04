// Sound effects (assets/sfx, made by art/sfx.py). Each sound gets a small
// pool so rapid beats (scoring ticks, clicks) can overlap.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'sfx_levels.dart';

class Sfx {
  static bool enabled = true;
  static final Map<String, Future<AudioPool>> _pools = {};

  static final _names = [
    'tap',
    'toggle',
    'handle',
    'drop_0',
    'drop_1',
    'drop_2',
    'drop_3',
    'rattle',
    'open',
    'omen',
    'reveal_0',
    'reveal_1',
    'reveal_2',
    'reveal_3',
    'place',
    'minus',
    'buff',
    'mult',
    'mult_big',
    'shoot',
    'pop',
    'spawn',
    'total_small',
    'total_big',
    'payday',
    'pay_ok',
    'pay_fail',
    'shop',
    'buy',
    'reroll',
    'new',
    'unlock',
    'clear',
    'over',
    'jingle',
    'siren',
    'push',
    'jam_win',
    'jam_lose',
    'cheer_big',
    'cheer_song',
    for (var n = 0; n < 3; n++)
      for (var v = 0; v < 3; v++) 'cheer_s${n}_$v',
    for (final i in ['hinata', 'shizuku', 'koharu', 'yoru', 'momo'])
      for (var n = 0; n < 4; n++) 'call_${i}_$n',
  ];
  static const ticks = 15;

  static Future<AudioPool> _pool(String name) => _pools[name] ??= AudioPool.create(
    source: AssetSource('sfx/$name.wav'),
    minPlayers: 1,
    maxPlayers: name.startsWith('tick') || name == 'tap' || name == 'pop' ? 4 : 2,
  );

  /// Warms up every pool so the first plays are not late.
  static void preload() {
    for (final n in _names) {
      _pool(n).ignore();
    }
    for (var i = 0; i < ticks; i++) {
      _pool(_tick(i)).ignore();
    }
  }

  static String _tick(int i) => 'tick_${i.clamp(0, ticks - 1).toString().padLeft(2, '0')}';

  static final Map<String, int> _cutAt = {};
  static final Map<String, List<Future<void> Function()>> _live = {};
  static final Map<String, int> _starting = {}; // plays waiting for a free player

  static void play(String name, {double volume = 1}) {
    Bgm.kick();
    if (!enabled) return;
    final asked = DateTime.now().microsecondsSinceEpoch;
    unawaited(() async {
      try {
        final pool = await _pool(name);
        // cut off (see [cut]) while it was still on its way: it never starts
        if ((_cutAt[name] ?? 0) > asked) return;
        // a sound asked for faster than it can start (mashing) is dropped, not queued:
        // a backlog kept thumping on after the mashing was over
        if ((_starting[name] ?? 0) >= 2) return;
        _starting[name] = (_starting[name] ?? 0) + 1;
        final Future<void> Function() stop;
        try {
          // levelled against the music (art/sfx_levels.py); [volume] is on top of that
          stop = await pool.start(volume: volume * (sfxGain[name] ?? 1));
        } finally {
          _starting[name] = (_starting[name] ?? 1) - 1;
        }
        // cut while it was starting: stop it straight away
        if ((_cutAt[name] ?? 0) > asked) {
          unawaited(stop().catchError((_) {}));
          return;
        }
        final live = _live[name] ??= [];
        live.add(stop);
        if (live.length > 8) live.removeAt(0);
      } catch (_) {
        // a missing or blocked sound must never break the game
      }
    }());
  }

  /// Silences [name] now: what is playing stops and what was asked for but has not
  /// started yet is dropped (the まもれ！ taps that pile up when mashing fast).
  static void cut(String name) {
    _cutAt[name] = DateTime.now().microsecondsSinceEpoch;
    for (final stop in _live.remove(name) ?? const <Future<void> Function()>[]) {
      unawaited(stop().catchError((_) {}));
    }
  }

  /// Coin blip that climbs the scale with each scoring beat.
  static void tick(int step) => play(_tick(step));
}

/// Background music: one looping idol song at a time (assets/bgm, made by art/songs).
class Bgm {

  static bool enabled = true;
  static const volume = 0.32;
  static const duckLevel = 0.7; // under a voice line (was 0.45: with the voices turned down, a light dip is enough)
  static AudioPlayer? _player;
  static String? _want; // track that should be playing
  static String? _playing;
  // where each song was left (a song comes back after the stall's tune and carries on);
  // the short tunes for a cleared song and the result always start from the top
  static final Map<String, Duration> _at = {};
  static const _fromTop = {'bgm_clear', 'bgm_result'};
  static bool _paused = false;
  static bool _ducked = false;

  static AudioPlayer get _p => _player ??= AudioPlayer()
    ..positionUpdater = null // nothing reads the position
    ..setReleaseMode(ReleaseMode.loop);

  /// Quieter while a character is talking.
  static void duck(bool on) {
    if (_ducked == on) return;
    _ducked = on;
    if (_playing == null) return;
    unawaited(() async {
      try {
        await _p.setVolume(on ? volume * duckLevel : volume);
      } catch (_) {}
    }());
  }

  /// Switches to [track] (`bgm_title`, `bgm_select`, or `bgm_` + a machine id); no-op if already on it.
  /// [fromStart]: from the top, even if it is already playing or was left halfway (a new live).
  static void play(String track, {bool fromStart = false}) {
    _want = track;
    if (fromStart) {
      _at.remove(track);
      _restart = true;
    }
    _sync();
  }

  static bool _restart = false;

  static void setEnabled(bool on) {
    enabled = on;
    _sync();
  }

  /// App went to the background / came back.
  static void pause(bool paused) {
    _paused = paused;
    _sync();
  }

  /// Browsers only allow audio after a user gesture; retry on taps.
  static void kick() {
    if (_playing == null) _sync();
  }

  static void _sync() {
    unawaited(() async {
      try {
        final target = enabled && !_paused ? _want : null;
        if (target == _playing) {
          // already on it, but asked to start over
          if (_restart && target != null) {
            _restart = false;
            await _p.seek(Duration.zero);
          }
          return;
        }
        _restart = false;
        // remember where the song we leave was, so coming back carries on from there
        if (_playing case final was?) {
          final at = await _p.getCurrentPosition();
          if (at != null && !_fromTop.contains(was)) _at[was] = at;
        }
        if (target == null) {
          await _p.pause();
          _playing = null;
          return;
        }
        await _p.stop();
        await _p.setVolume(_ducked ? volume * duckLevel : volume);
        // sung idol songs (art/songs, ACE-Step 1.5), picked up where they were left
        await _p.play(AssetSource('bgm/$target.m4a'), position: _fromTop.contains(target) ? null : _at[target]);
        _playing = target;
      } catch (_) {
        _playing = null; // blocked (web autoplay) or missing plugin: try again later
      }
    }());
  }
}
