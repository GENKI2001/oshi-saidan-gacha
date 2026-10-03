// Character voices (フルボイス): every line in lines.dart has a take in
// assets/voice (made by voice/*.py). One line at a time: a new line cuts off
// the last one, and the music ducks while someone is talking.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'crowd.dart';
import 'sfx.dart';
import 'voice_ids.dart';

class Voice {
  static bool enabled = true;
  static const volume = 1.0;
  static AudioPlayer? _player;
  static int _token = 0;
  static bool _paused = false;

  /// Who is talking right now (null when quiet) — the screen can bounce them.
  static String? speaking;

  static AudioPlayer get _p => _player ??= AudioPlayer()
    ..positionUpdater = null // no per-frame position polling (nothing reads it)
    ..setReleaseMode(ReleaseMode.stop)
    ..onPlayerComplete.listen((_) => _done());

  static bool has(String who, String text) => voiceIds.containsKey('$who|$text');

  /// Speaks [text] as [who], after a short beat so it lands just after the line appears.
  static void say(String who, String text, {int delayMs = 220}) {
    final id = voiceIds['$who|$text'];
    final t = ++_token;
    if (id == null || !enabled || _paused) {
      unawaited(_stop());
      return;
    }
    unawaited(() async {
      try {
        await _p.stop();
        await Future.delayed(Duration(milliseconds: delayMs));
        if (t != _token) return;
        speaking = who;
        Bgm.duck(true);
        Crowd.duck(true);
        await _p.setVolume(volume);
        await _p.play(AssetSource('voice/$id.m4a'));
      } catch (_) {
        _done(); // a missing or blocked voice must never break the game
      }
    }());
  }

  static void _done() {
    speaking = null;
    Bgm.duck(false);
    Crowd.duck(false);
  }

  static Future<void> _stop() async {
    _done();
    try {
      await _player?.stop();
    } catch (_) {}
  }

  /// Quiet now (ads, leaving a screen, sound turned off).
  static void stop() {
    _token++;
    unawaited(_stop());
  }

  static void setEnabled(bool on) {
    enabled = on;
    if (!on) stop();
  }

  static void pause(bool paused) {
    _paused = paused;
    if (paused) stop();
  }
}
