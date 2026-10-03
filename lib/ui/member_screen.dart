// メンバー紹介: the five idols of ぷりずむ☆パレット and つむぎ. Tap a card to hear her.

import 'package:flutter/material.dart';

import 'idol_widgets.dart';
import 'lines.dart';
import 'sfx.dart';
import 'voice.dart';
import 'widgets.dart';

class _Profile {
  final String who, full, role, text;
  const _Profile(this.who, this.full, this.role, this.text);
}

const _profiles = [
  _Profile('ひなた', '天音 ひなた', 'センター・担当カラー 赤', 'いつでも全力、笑顔がとりえの20歳。ステージに立つと だれより輝く。好きな食べ物は からあげ。'),
  _Profile('しずく', '水瀬 しずく', '歌姫・担当カラー 青', 'クールで ていねいな20歳。透きとおる歌声が自慢。実は ぬいぐるみ集めが趣味。'),
  _Profile('こはる', '春野 こはる', 'ふわふわ担当・担当カラー 黄', 'おっとり マイペースな20歳。お菓子作りが得意で、楽屋では だいたい寝ている。'),
  _Profile('よる', '夜宮 よる', '小悪魔担当・担当カラー 紫', 'からかうのが大好きな20歳。ゴシックな衣装がトレードマーク。じつは さみしがり。'),
  _Profile('もも', '桃瀬 もも', 'あまえんぼ担当・担当カラー ピンク', 'あざとさ全開の20歳。ネコ耳カチューシャは ファンからの贈り物。'),
  _Profile(kTsumugi, '若葉 つむぎ', 'マネージャー・ノルマ担当', 'ぷりパレを支える20歳の新人マネージャー。しっかり者で ハートのノルマにはきびしい。じつは ぷりパレの大ファン…なのは ひみつ。'),
];

class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key});
  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  String? _who;
  String _line = '';
  int _token = 0;

  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  void _talk(String who) {
    Sfx.play('tap');
    final l = idolLines[who];
    final line = l == null ? pick([...lineTap, ...lineTitle]) : pick([...l.talk, ...l.pull, ...l.sr]);
    Voice.say(who, line, delayMs: 80);
    setState(() {
      _who = who;
      _line = line;
      _token++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.night,
    appBar: AppBar(
      backgroundColor: C.night,
      foregroundColor: Colors.white,
      title: Text('メンバー', style: outlined(22, Colors.white, width: 2)),
    ),
    body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                children: [
                  Center(child: Text('ぷりずむ☆パレット', style: outlined(24, Colors.white, stroke: C.pink, width: 4))),
                  const SizedBox(height: 6),
                  for (final p in _profiles) _card(p),
                ],
              ),
              if (_who != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: IgnorePointer(child: IdolToast(who: _who!, line: _line, token: _token)),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _card(_Profile p) {
    final col = idolColor[p.who]!;
    final img = p.who == kTsumugi ? 'assets/ui/boss_1.png' : portrait(p.who);
    return GestureDetector(
      key: ValueKey('member-${p.who}'),
      onTap: () => _talk(p.who),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(col, Colors.white, 0.75)!, Colors.white]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: OverflowBox(
                maxHeight: 260,
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Bounce(token: _who == p.who ? _token : 0, amount: 0.06, child: Image.asset(img, height: 260, fit: BoxFit.fitHeight, alignment: Alignment.topCenter)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.full, style: outlined(22, col, stroke: Colors.white, width: 4)),
                    Text(p.role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: C.ink)),
                    const SizedBox(height: 4),
                    Text(p.text, style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w700, color: C.ink)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.volume_up_rounded, size: 16, color: col),
                        Text(' タップで ボイス', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: col)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
