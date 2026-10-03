// Sound effects (assets/sfx, made by art/sfx.py). Each sound gets a small
// pool so rapid beats (scoring ticks, clicks) can overlap.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

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

/// Background music: one looping idol song at a time (assets/bgm, made by art/songs).
class Bgm {

  static bool enabled = true;
  static const volume = 0.32;
  static AudioPlayer? _player;
  static String? _want; // track that should be playing
  static String? _playing;
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
        await _p.setVolume(on ? volume * 0.45 : volume);
      } catch (_) {}
    }());
  }

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
        await _p.setVolume(_ducked ? volume * 0.45 : volume);
        // sung idol songs (art/songs, ACE-Step 1.5)
        await _p.play(AssetSource('bgm/$target.m4a'));
        _playing = target;
      } catch (_) {
        _playing = null; // blocked (web autoplay) or missing plugin: try again later
      }
    }());
  }
}
