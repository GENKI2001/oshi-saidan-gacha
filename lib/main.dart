import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/ads/ads.dart';
import 'ui/meta.dart';
import 'ui/rank.dart';
import 'ui/sfx.dart';
import 'ui/title_screen.dart';
import 'ui/voice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final meta = Meta();
  await meta.load();
  Sfx.enabled = meta.sound;
  Bgm.enabled = meta.music;
  Voice.enabled = meta.voice;
  Sfx.preload();
  runApp(GachaApp(meta: meta));
  // Game Center / Play Games sign-in (shows the system sheet when needed)
  Rank.instance.start();
  // ad consent and the tracking prompt, then the first rewarded ad loads
  Ads.instance.start();
}

class GachaApp extends StatefulWidget {
  final Meta meta;
  const GachaApp({super.key, required this.meta});
  @override
  State<GachaApp> createState() => _GachaAppState();
}

class _GachaAppState extends State<GachaApp> {
  // stop the music and voices while the app is in the background
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () {
        Bgm.pause(true);
        Voice.pause(true);
      },
      onShow: () {
        Bgm.pause(false);
        Voice.pause(false);
      },
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Meta get meta => widget.meta;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '推し祭壇ガチャ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, fontFamily: 'Rounded', colorSchemeSeed: const Color(0xFFFF6FA3)),
    home: TitleScreen(meta: meta),
  );
}
