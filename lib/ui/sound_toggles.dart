// Music, voices and sound effects on / off: the three round icons on the title and in the menus.

import 'package:flutter/material.dart';

import 'meta.dart';
import 'sfx.dart';
import 'voice.dart';
import 'widgets.dart';

class SoundToggles extends StatefulWidget {
  final Meta meta;
  final double size, padding, gap;
  const SoundToggles(this.meta, {super.key, this.size = 26, this.padding = 9, this.gap = 12});
  @override
  State<SoundToggles> createState() => _SoundTogglesState();
}

class _SoundTogglesState extends State<SoundToggles> {
  Widget _toggle(IconData icon, VoidCallback toggle) => RoundIconButton(
    icon,
    size: widget.size,
    padding: widget.padding,
    onTap: () {
      toggle();
      Sfx.play('toggle');
      setState(() {});
    },
  );

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _toggle(m.music ? Icons.music_note_rounded : Icons.music_off_rounded, () {
          m.toggleMusic();
          Bgm.setEnabled(m.music);
        }),
        SizedBox(width: widget.gap),
        _toggle(m.voice ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded, () {
          m.toggleVoice();
          Voice.setEnabled(m.voice);
        }),
        SizedBox(width: widget.gap),
        _toggle(m.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, () {
          m.toggleSound();
          Sfx.enabled = m.sound;
        }),
      ],
    );
  }
}
