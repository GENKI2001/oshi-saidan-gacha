import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/l10n.dart';
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
  // English unless the device is in Japanese (or the player picked one on the title);
  // --dart-define=LANG=en|ja forces one (store screenshots)
  const forced = String.fromEnvironment('LANG');
  en = (forced.isNotEmpty ? forced : meta.lang ?? PlatformDispatcher.instance.locale.languageCode) != 'ja';
  Sfx.enabled = meta.sound;
  Bgm.enabled = meta.music;
  Voice.enabled = meta.voice;
  Sfx.preload();
  runApp(GachaApp(meta: meta));
  // Game Center / Play Games sign-in (shows the system sheet when needed)
  Rank.instance.start();
  // ad consent (only where the law needs it) and the iOS tracking prompt, then the first rewarded ad loads
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
    title: en ? 'Oshi Altar Gacha' : '推し祭壇ガチャ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, fontFamily: 'Rounded', colorSchemeSeed: const Color(0xFFFF6FA3)),
    navigatorObservers: [routes],
    home: TitleScreen(meta: meta),
  );
}
