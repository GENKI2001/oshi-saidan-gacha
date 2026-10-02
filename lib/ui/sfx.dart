// Sound effects (assets/sfx, made by art/sfx.py). Each sound gets a small
// pool so rapid beats (scoring ticks, clicks) can overlap.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class Sfx {
  static bool enabled = true;
  static final Map<String, Future<AudioPool>> _pools = {};

  static const _names = [
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
    'boss_0',
    'boss_1',
    'boss_2',
    'boss_3',
    'shop',
    'buy',
    'reroll',
    'new',
    'unlock',
    'clear',
    'over',
    'jingle',
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

  static void play(String name, {double volume = 1}) {
    Bgm.kick();
    if (!enabled) return;
    unawaited(() async {
      try {
        await (await _pool(name)).start(volume: volume);
      } catch (_) {
        // a missing or blocked sound must never break the game
      }
    }());
  }

  /// Coin blip that climbs the scale with each scoring beat.
  static void tick(int step) => play(_tick(step), volume: 0.8);
}

/// Background music: one looping track at a time (assets/bgm, made by art/bgm.py).
class Bgm {
  static bool enabled = true;
  static const volume = 0.32;
  static AudioPlayer? _player;
  static String? _want; // track that should be playing
  static String? _playing;
  static bool _paused = false;

  static AudioPlayer get _p => _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  /// Switches to [track] (`bgm_title`, `bgm_select`, or `bgm_` + a machine id); no-op if already on it.
  static void play(String track) {
    _want = track;
    _sync();
  }

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
        if (target == _playing) return;
        if (target == null) {
          await _p.pause();
          _playing = null;
          return;
        }
        await _p.stop();
        await _p.setVolume(volume);
        await _p.play(AssetSource('bgm/$target.wav'));
        _playing = target;
      } catch (_) {
        _playing = null; // blocked (web autoplay) or missing plugin: try again later
      }
    }());
  }
}
