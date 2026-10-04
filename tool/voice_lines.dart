// Lists every spoken line for the voice batch:
//   dart run tool/voice_lines.dart > voice/lines.json
import 'dart:convert';

import 'package:oshi_saidan/logic/achievements.dart';
import 'package:oshi_saidan/ui/lines.dart';

// ignore_for_file: avoid_print
void main() {
  final out = [
    for (final (who, text, mood) in allVoiced()) {'who': who, 'text': text, 'mood': mood},
    // シチュエーションボイス: mixed into one track each by art/asmr.py
    for (final t in asmrTracks)
      for (final l in t.lines) {'who': t.who, 'text': l, 'mood': 'scene', 'track': t.id},
  ];
  print(const JsonEncoder.withIndent(' ').convert(out));
}
