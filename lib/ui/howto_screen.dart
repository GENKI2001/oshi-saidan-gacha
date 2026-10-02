// あそびかた: the rules on a few illustrated pages.
import 'package:flutter/material.dart';

import 'meta.dart';
import 'sfx.dart';
import 'widgets.dart';

class HowToScreen extends StatefulWidget {
  final Meta meta;

  final int initialPage;
  const HowToScreen({super.key, required this.meta, this.initialPage = 0});
  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

typedef _Page = ({String title, Widget art, List<String> lines});

class _HowToScreenState extends State<HowToScreen> {
  late final _pc = PageController(initialPage: widget.initialPage);
  late int _i = widget.initialPage;

  /// A real screenshot of the game (made by art/howto.py), framed.
  static Widget _shot(String name) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: C.ink, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.asset('assets/howto/$name.jpg', fit: BoxFit.contain),
    ),
  );

  final List<_Page> _pages = [
    (title: 'ガチャを回す', art: _shot('spin'), lines: ['「回す！」をタップすると カプセルが出てくる', 'カプセルをタップして開けよう。光っていたら レアの予感！']),
    (title: '棚に置く・もう一回ひく', art: _shot('reveal'), lines: ['「棚に置く」で 好きなマスに置く', '気に入らなければ「もう一回ひく」']),
    (
      title: '稼ぎと 組み合わせ',
      art: _shot('shelf'),
      lines: ['駒は毎回 小判を稼ぐ。マスの右下が その駒の稼ぎ、左上の「+N」が今回の合計', '「×2」「+2」は ほかの駒を強くした印', 'となりや種類を うまく組み合わせて 小判をがっぽり稼ごう！'],
    ),
    (title: '親分の取り立て', art: _shot('payday'), lines: ['5回まわすごとに ショバ代の取り立て。足りないと おしまい', '4回払えば完済！ そのあとは延長戦で どこまで行けるか ランキングで勝負']),
    (
      title: '親分の夜店',
      art: _shot('shop'),
      lines: ['払ったあとは夜店。駒・運アップ・棚を広げる（最大6×6）・どける/いれかえ/もう一回ひくの回数アップ', '最初の1品は タダ！ 何個でも買えるけど 2品目からは 買うたびに値上がり'],
    ),
    (title: '縁日レベル', art: _shot('result'), lines: ['稼いだ小判で ゲージがたまる。いっぱいになったら プレイ終了時に 縁日レベルが1上がる', 'レベルが上がると 新しい駒や ガチャが出るように。負けても稼ぎは次につながる']),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_i < _pages.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.night,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  ),
                  Text('あそびかた', style: outlined(24, Colors.white, width: 3)),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    Sfx.play('toggle');
                    setState(() => _i = i);
                  },
                  itemBuilder: (_, i) => _page(_pages[i], i),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k < _pages.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: k == _i ? 22 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: k == _i ? C.gold : Colors.white30,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: C.ink, width: 1.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(width: 260, child: PopButton(_i < _pages.length - 1 ? 'つぎへ' : 'とじる', fontSize: 22, onTap: _next)),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _page(_Page p, int i) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Panel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${i + 1}. ${p.title}', style: outlined(26, C.pink, stroke: C.ink, width: 3)),
          const SizedBox(height: 12),
          // the picture takes only the room it needs, so the text sits right under it
          Flexible(child: p.art),
          const SizedBox(height: 12),
          for (final l in p.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.star_rounded, size: 18, color: C.gold),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l,
                      style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w800, color: C.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
