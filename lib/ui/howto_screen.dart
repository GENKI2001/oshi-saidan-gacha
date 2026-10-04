// あそびかた: the rules on a few illustrated pages. Each page has a real
// screenshot in a polaroid frame and a member (or つむぎ) explaining it in bubbles.
import 'package:flutter/material.dart';

import 'idol_widgets.dart';
import 'lines.dart';
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

/// [shot]: `assets/howto/<shot>.jpg` (made by art/howto.py); [who]: who explains it.
typedef _Page = ({String title, String shot, String who, List<String> lines});

class _HowToScreenState extends State<HowToScreen> {
  late final _pc = PageController(initialPage: widget.initialPage);
  late int _i = widget.initialPage;

  static const List<_Page> _pages = [
    (
      title: 'ガチャを回す',
      shot: 'spin',
      who: 'ひなた',
      lines: ['「回す！」をタップすると カプセルが出てくるよ！', 'カプセルをタップして開けてね。光っていたら ★3や★4の予感！'],
    ),
    (
      title: '祭壇に置く',
      shot: 'reveal',
      who: 'こはる',
      lines: ['「祭壇に置く」で 好きなマスに置こ〜。同じグッズの上に重ねると ×2、×3…と強化されて、ピカピカ光るマスが目印だよ', '気に入らなかったら「もう一回ひく」。1曲ごとに 回数がもどるよ'],
    ),
    (
      title: 'ハートを集める',
      shot: 'shelf',
      who: 'しずく',
      lines: ['グッズは 回すたびにハートを集めます。マスの右下が そのグッズの分です', '「×2」「+2」は ほかのグッズを強くした印。同じ推しを となりに並べると、ぐんと増えます'],
    ),
    (
      title: '1曲ごとのノルマ',
      shot: 'payday',
      who: kTsumugi,
      lines: ['5回まわすと 1曲おわり。ノルマのハートが足りないと、ライブはそこでおしまいです', 'ノルマを達成しながら 4曲こなしたら ライブ大成功！ そのあとは アンコールです'],
    ),
    (
      title: 'つむぎの物販ブース',
      shot: 'shop',
      who: kTsumugi,
      lines: ['ノルマを達成したら 物販ブースです。最初の1品は タダ！', 'グッズ・運アップ・推しの出現率UP・祭壇を広げる などが並びます。ときどき金色の「レア商品」も。2品目からは 値上がりしますよ'],
    ),
    (
      title: '転売ヤーの妨害',
      shot: 'jam',
      who: 'よる',
      lines: ['ときどき 転売ヤーのカイシメが 祭壇をねらってくるよ', '「まもる！」でカウントダウン、そのあと「まもれ！」を連打して。まもれたら ハート2倍やグッズのごほうび、負けたら グッズやハートを持っていかれちゃう'],
    ),
    (
      title: '推し活レベルとガチャ',
      shot: 'select',
      who: 'もも',
      lines: ['ハートを集めて 推し活レベルが上がると、新しいグッズや 推しのガチャが出るよ', 'ガチャには 難易度（かんたん〜おに）があるの。ガチャごとに クリアと最高記録も 残るんだよ！'],
    ),
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
    body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
      child: Container(
        color: const Color(0x99241A4A),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                        ),
                        const Expanded(child: Center(child: Ribbon('あそびかた', width: 210))),
                        const SizedBox(width: 48),
                      ],
                    ),
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
                  // which page: a row of hearts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var k = 0; k < _pages.length; k++)
                        AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: k == _i ? 1.3 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Icon(Icons.favorite_rounded, size: 16, color: k == _i ? C.pink : Colors.white38),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(width: 260, child: PopButton(_i < _pages.length - 1 ? 'つぎへ' : 'とじる', fontSize: 22, onTap: _next)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _page(_Page p, int i) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // the step number in a badge, and the title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StickerBadge(i + 1),
              const SizedBox(width: 10),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: StickerText(p.title, size: 24))),
            ],
          ),
          const SizedBox(height: 12),
          // the screenshot in a slightly tilted polaroid
          Flexible(
            child: Transform.rotate(
              angle: i.isEven ? -0.025 : 0.025,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset('assets/howto/${p.shot}.jpg', fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final l in p.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuideFace(p.who),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: idolColor[p.who]!, width: 2.5),
                      ),
                      child: Text(l, style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w800, color: C.ink)),
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

/// Who explains a page: an idol's face, or つむぎ's.
class _GuideFace extends StatelessWidget {
  final String who;
  const _GuideFace(this.who);

  @override
  Widget build(BuildContext context) {
    if (who != kTsumugi) return IdolFace(who, size: 38);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(idolColor[kTsumugi], Colors.white, 0.6),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: idolColor[kTsumugi]!.withValues(alpha: 0.6), blurRadius: 8)],
      ),
      child: ClipOval(
        child: OverflowBox(
          maxWidth: 70,
          maxHeight: 70,
          alignment: const Alignment(0, -0.6),
          child: Image.asset('assets/ui/boss_1.png', width: 70, height: 70, fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
      ),
    );
  }
}
