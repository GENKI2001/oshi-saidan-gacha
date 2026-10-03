// The audience (art/crowd.py). No background loop: the hall answers the
// hearts — short cheers while a turn's hearts are counted, growing with each
// beat and with the hype; a swell on a big turn, a roar at the end of a song,
// and fans calling an idol's name when her goods go on the altar.
import 'dart:math' as math;

import 'sfx.dart';

class Crowd {
  static double _hype = 0;
  static bool _ducked = false;
  static int _lastBeat = -1000;
  static final _r = math.Random();

  /// 0 (quiet hall) .. 1 (the hall is going wild).
  static void setHype(double h) => _hype = h.clamp(0.0, 1.0);

  /// Softer while someone on screen is talking.
  static void duck(bool on) => _ducked = on;

  static double get _vol => _ducked ? 0.5 : 1.0;

  /// A beat of the heart count: [step] counts up within the turn, [gain] is
  /// what this beat added. Not every beat cheers — the crowd rides along.
  static void beat(int step, int gain) {
    if (gain <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // at most one cheer every ~0.35 s, so they overlap into a swell instead of a rattle
    if (now - _lastBeat < 350) return;
    _lastBeat = now;
    final heat = (_hype * 0.7 + math.min(step, 12) / 12 * 0.3).clamp(0.0, 1.0);
    final size = heat < 0.35 ? 0 : (heat < 0.7 ? 1 : 2);
    Sfx.play('cheer_s${size}_${_r.nextInt(3)}', volume: (0.25 + 0.55 * heat) * _vol);
  }

  /// A swell of cheers (a big turn, a ★3/★4).
  static void cheer() => Sfx.play('cheer_big', volume: (0.55 + 0.45 * _hype) * _vol);

  /// The roar at the end of a song.
  static void songEnd() => Sfx.play('cheer_song', volume: _vol);

  /// A fan calls [id]'s name (hinata, shizuku, …).
  static void call(String id) => Sfx.play('call_${id}_${_r.nextInt(4)}', volume: (0.45 + 0.4 * _hype) * _vol);

  // the screen still tells us when a live is on (kept for symmetry; nothing loops now)
  static void start() {}
  static void stop() {}
}
