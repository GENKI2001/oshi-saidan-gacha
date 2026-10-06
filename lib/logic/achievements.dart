// 実績 and the シチュエーションボイス they unlock. Pure Dart: the checks read a
// small snapshot of the player's records (Stats), so tests and tools can use them.

import '../l10n/l10n.dart';
import 'figures.dart';
import 'modes.dart';

/// The records achievements are judged on (kept in Meta).
class Stats {
  final int runs, clears, bestPaydays, bestTurn, seen;
  final int jamWins, maxStack, totalEarned, open; // 妨害 fended off, highest stack, every heart ever, goods in the gacha
  final Map<String, int> placed; // goods of each idol ever put on the altar
  final Map<String, int> altarPeak; // most goods of each idol on the altar at once
  final Set<String> clearedOn; // machines a live was cleared on
  final bool pulledStar4;
  const Stats({
    this.runs = 0,
    this.clears = 0,
    this.bestPaydays = 0,
    this.bestTurn = 0,
    this.seen = 0,
    this.placed = const {},
    this.altarPeak = const {},
    this.clearedOn = const {},
    this.pulledStar4 = false,
    this.jamWins = 0,
    this.maxStack = 1,
    this.totalEarned = 0,
    this.open = 0,
  });
}

class Achievement {
  final String id;

  /// The Japanese title and text; [titleEn] / [textEn] for ones built with a name in them
  /// (the rest find their English through [tr]).
  final String titleJa, textJa;
  final String? titleEn, textEn;
  String get title => en ? (titleEn ?? tr(titleJa)) : titleJa;
  String get text => en ? (textEn ?? tr(textJa)) : textJa;

  /// How far along: (now, goal).
  final (int, int) Function(Stats s) progress;

  /// The シチュエーションボイス it unlocks (an id in [asmrTracks]), if any.
  final String? asmr;
  const Achievement(this.id, this.titleJa, this.textJa, this.progress, {this.asmr, this.titleEn, this.textEn});

  bool done(Stats s) {
    final (now, goal) = progress(s);
    return now >= goal;
  }
}

/// Each idol's own gacha.
const idolMachine = {'ひなた': 'hinata', 'しずく': 'shizuku', 'こはる': 'koharu', 'よる': 'yoru', 'もも': 'momo'};
const _idolId = {'ひなた': 'hinata', 'しずく': 'shizuku', 'こはる': 'koharu', 'よる': 'yoru', 'もも': 'momo'};
const _machineName = {'hinata': 'ひなた推しガチャ', 'shizuku': 'しずく推しガチャ', 'koharu': 'こはる推しガチャ', 'yoru': 'よる推しガチャ', 'momo': 'もも推しガチャ'};
const _nameEn = {'ひなた': 'Hinata', 'しずく': 'Shizuku', 'こはる': 'Koharu', 'よる': 'Yoru', 'もも': 'Momo'};

final achievements = <Achievement>[
  Achievement('first_live', 'はじめてのライブ', 'ライブを1回終える', (s) => (s.runs, 1)),
  Achievement('first_clear', 'ライブ大成功', '4曲成功して ライブを成功させる', (s) => (s.clears, 1)),
  Achievement('encore', 'アンコール！', '1回のライブで 6曲成功する', (s) => (s.bestPaydays, 6)),
  for (final m in ['ひなた', 'しずく', 'こはる', 'よる', 'もも']) ...[
    Achievement(
      '${_idolId[m]}_altar',
      '$mの祭壇',
      '祭壇に「$m」のグッズを 同時に6個 並べる',
      (s) => (s.altarPeak[m] ?? 0, 6),
      asmr: '${_idolId[m]}_1',
      titleEn: "${_nameEn[m]}'s Altar",
      textEn: 'Have 6 ${_nameEn[m]} goods on the altar at once',
    ),
    Achievement(
      '${_idolId[m]}_place',
      '$m推し',
      '「$m」のグッズを 合計30個 祭壇に置く',
      (s) => (s.placed[m] ?? 0, 30),
      asmr: '${_idolId[m]}_2',
      titleEn: '${_nameEn[m]} Is My Oshi',
      textEn: 'Place 30 ${_nameEn[m]} goods on the altar in all',
    ),
    Achievement(
      '${_idolId[m]}_clear',
      '$mのライブ',
      '${_machineName[idolMachine[m]]}で ライブを成功させる',
      (s) => (s.clearedOn.contains(idolMachine[m]) ? 1 : 0, 1),
      asmr: '${_idolId[m]}_3',
      titleEn: "${_nameEn[m]}'s Live",
      textEn: 'Clear a live on ${_nameEn[m]} Oshi Gacha',
    ),
  ],
  Achievement('heart100', 'ハートの嵐', '1回転で ハートを100 集める', (s) => (s.bestTurn, 100)),
  Achievement('heart500', '会場がゆれた', '1回転で ハートを500 集める', (s) => (s.bestTurn, 500)),
  Achievement('star4', 'キセキの星4', '★4のグッズを引く', (s) => (s.pulledStar4 ? 1 : 0, 1)),
  Achievement('book30', 'コレクター', 'グッズを 30種 あつめる', (s) => (s.seen, 30)),
  Achievement('book60', '推し活のプロ', 'グッズを 60種 あつめる', (s) => (s.seen, 60)),
  Achievement('book96', 'グッズコンプリート', 'グッズを 全部 あつめる', (s) => (s.seen, figures.length)),
  Achievement('hard_clear', 'きびしいライブ', '難易度「げきむず」以上のガチャで ライブを成功させる', (s) => (s.clearedOn.any((id) => (machineById[id]?.difficulty ?? 0) >= 4) ? 1 : 0, 1)),
  Achievement('runs10', '常連さん', 'ライブを 10回 する', (s) => (s.runs, 10)),
  // ── the hard ones ──
  Achievement('heart1000', '伝説の1回転', '1回転で ハートを1000 集める', (s) => (s.bestTurn, 1000)),
  Achievement('heart3000', '会場が割れた', '1回転で ハートを3000 集める', (s) => (s.bestTurn, 3000)),
  Achievement('heart10000', 'ハートの銀河', '1回転で ハートを10000 集める', (s) => (s.bestTurn, 10000)),
  Achievement('encore8', 'アンコールの嵐', '1回のライブで 8曲成功する', (s) => (s.bestPaydays, 8)),
  Achievement('encore10', '終わらないライブ', '1回のライブで 10曲成功する', (s) => (s.bestPaydays, 10)),
  Achievement('clears10', 'ライブの達人', 'ライブを 10回 成功させる', (s) => (s.clears, 10)),
  Achievement('clears30', '伝説のプロデューサー', 'ライブを 30回 成功させる', (s) => (s.clears, 30)),
  Achievement('runs50', '皆勤賞', 'ライブを 50回 する', (s) => (s.runs, 50)),
  Achievement('runs100', '推し活の鬼', 'ライブを 100回 する', (s) => (s.runs, 100)),
  Achievement('dome', 'ドーム制覇', 'ドームツアーガチャで ライブを成功させる', (s) => (s.clearedOn.contains('dome') ? 1 : 0, 1)),
  Achievement('tenbai', '転売ヤーなんかに負けない', '転売ヤー警戒ガチャで ライブを成功させる', (s) => (s.clearedOn.contains('tenbai') ? 1 : 0, 1)),
  Achievement('premium', 'プレミアムな夜', 'プレミアムガチャで ライブを成功させる', (s) => (s.clearedOn.contains('premium') ? 1 : 0, 1)),
  Achievement('allclear', '全ガチャ制覇', 'すべてのガチャで ライブを成功させる', (s) => (machines.where((m) => s.clearedOn.contains(m.id)).length, machines.length)),
  Achievement('jam10', '鉄壁の祭壇', '転売ヤーから 10回 祭壇をまもる', (s) => (s.jamWins, 10)),
  Achievement('jam50', 'カイシメの天敵', '転売ヤーから 50回 祭壇をまもる', (s) => (s.jamWins, 50)),
  Achievement('stack3', '重ね推し', '同じグッズを重ねて ×3 まで強化する', (s) => (s.maxStack, 3)),
  Achievement('stack5', '限界突破', '同じグッズを重ねて ×5 まで強化する', (s) => (s.maxStack, 5)),
  Achievement('earned10k', '推し活貯金', 'ハートを 合計10000 集める', (s) => (s.totalEarned, 10000)),
  Achievement('earned100k', '推しに捧げた10万', 'ハートを 合計100000 集める', (s) => (s.totalEarned, 100000)),
  Achievement('open_all', '推し活マスター', 'すべてのグッズを ガチャに出るようにする', (s) => (s.open, figures.length)),
  for (final m in ['ひなた', 'しずく', 'こはる', 'よる', 'もも']) ...[
    Achievement(
      '${_idolId[m]}_place100',
      '$mにガチ恋',
      '「$m」のグッズを 合計100個 祭壇に置く',
      (s) => (s.placed[m] ?? 0, 100),
      titleEn: 'Head Over Heels for ${_nameEn[m]}',
      textEn: 'Place 100 ${_nameEn[m]} goods on the altar in all',
    ),
    Achievement(
      '${_idolId[m]}_altar10',
      '$m一色',
      '祭壇に「$m」のグッズを 同時に10個 並べる',
      (s) => (s.altarPeak[m] ?? 0, 10),
      titleEn: 'All ${_nameEn[m]}',
      textEn: 'Have 10 ${_nameEn[m]} goods on the altar at once',
    ),
  ],
];

final achievementById = {for (final a in achievements) a.id: a};

/// One シチュエーションボイス: who, the scene's name, and her lines in order.
class AsmrTrack {
  final String id, who, title;
  final List<String> lines;
  const AsmrTrack(this.id, this.who, this.title, this.lines);
}

const asmrTracks = <AsmrTrack>[
  AsmrTrack('hinata_1', 'ひなた', 'おはよう モーニングコール', [
    'おっはよー！ ひなただよ！ 起きてる？',
    'ふふっ、まだ眠そうな声してる',
    '今日はね、いちばんにあなたの声が聞きたくて、電話しちゃった',
    'ひなたの祭壇、あんなにきれいに飾ってくれて、ほんとにうれしかったんだ',
    'だから今日は、ひなたがあなたを元気にする番！',
    'せーの、がんばれ、がんばれ、あなた！',
    'えへへ、元気出た？ いってらっしゃい！',
  ]),
  AsmrTrack('hinata_2', 'ひなた', 'はじめての デート', [
    'ごめーん、待った？ 走ってきちゃった！',
    '今日は、ひなたとあなたの、ふたりだけのお出かけだね',
    'いつも応援してくれるお礼に、今日はひなたが案内するよ',
    'あっ、見て見て、クレープ屋さん！ はんぶんこしよ！',
    'ん〜、おいしい！ あなたと食べると、もっとおいしい',
    'ねえ、手、つないでもいい？ はぐれたら、こまるもん',
    'えへへ、今日のこと、ずっとおぼえてるね',
  ]),
  AsmrTrack('hinata_3', 'ひなた', 'センターの 本音', [
    'ライブ、大成功！ ねえ、見ててくれた？',
    '楽屋まで来てくれるなんて、びっくりしちゃった',
    'ひなたね、センターに立つとき、いつもあなたを探してるんだ',
    '今日もちゃんと見つけたよ。いちばん大きな声だったもん',
    'あなたがいるから、ひなたはセンターで笑っていられるの',
    'これからも、ひなたのとなりで、いっしょに走ってくれる？',
    'やったー！ 約束だよ！ だーいすき！',
  ]),
  AsmrTrack('shizuku_1', 'しずく', '図書館で ばったり', [
    'あ…こんにちは。こんなところで会うなんて',
    'わたし、お休みの日は、よくここで本を読んでいるんです',
    'あなたも、本が好きなんですか？ ふふ、うれしいです',
    'そういえば、わたしの祭壇、とてもきれいでした',
    'ひとつひとつ丁寧に並べてくれたこと、ちゃんと伝わっています',
    'あの…よかったら、わたしのおすすめの本、教えてもいいですか？',
    'となりの席、どうぞ。今日は、ふたりで静かに過ごしましょう',
  ]),
  AsmrTrack('shizuku_2', 'しずく', '雨の日の 相合傘', [
    'あ、雨…。傘、忘れてしまったんですか？',
    'よかったら、入ってください。少しせまいですけど',
    'もう少し、こちらに寄ってもいいですよ。肩、ぬれてしまいます',
    '…なんだか、どきどきしますね',
    'いつも、わたしを応援してくれて、ありがとうございます',
    'こうして、あなたのとなりを歩けるなんて、夢みたいです',
    '駅まで、ゆっくり歩きましょうか',
  ]),
  AsmrTrack('shizuku_3', 'しずく', '青い光の 約束', [
    'ライブ、来てくださって、ありがとうございました',
    'ステージから見た客席の青い光、海みたいで、とてもきれいでした',
    'その中に、あなたの光も、ちゃんと見えていましたよ',
    'わたし、歌うのがこわかったころがあったんです',
    'でも、あなたが応援してくれるから、今は歌うのが幸せです',
    'これからも、わたしの歌を、いちばん近くで聴いてくれますか？',
    '…はい。約束ですよ',
  ]),
  AsmrTrack('koharu_1', 'こはる', '手作り お弁当', [
    'じゃーん！ こはる特製、手作りお弁当だよ！',
    'あなたのために、朝はやく起きて作ったんだ〜',
    'たまご焼きはね、あまーい味にしてみたの',
    'はい、あーん！ …どう？ おいしい？',
    'やったぁ！ こはる、うれしくて踊っちゃいそう！',
    'こはるのグッズ、いっぱい飾ってくれたお礼だよ',
    'また作ってくるね！ 次は何がいい？',
  ]),
  AsmrTrack('koharu_2', 'こはる', 'あなたが 主役の日', [
    'せーの、おめでとー！ ぱちぱちぱち！',
    'えへへ、今日はあなたが主役の日だよ',
    'いつもこはるを応援してくれて、ありがとう！',
    'だからね、ケーキ焼いてきたの！ いちごいっぱい！',
    'ろうそく、ふーってして？ わぁ、すごーい！',
    'あなたの毎日が、ずーっと、にこにこでありますように',
    'こはるも、ずっととなりで、お祝いさせてね！',
  ]),
  AsmrTrack('koharu_3', 'こはる', '楽屋で ごほうび', [
    'あっ、来てくれたんだ！ ライブ、どうだった？',
    'こはる、最後まで元気いっぱい歌えたよ！',
    'あなたの声、ちゃんと聞こえてたんだから',
    'ねえねえ、がんばったこはるに、ごほうびちょうだい？',
    'じゃあ…頭、なでなでして？',
    'えへへ…しあわせ〜',
    'これからも、こはるのこと、いっぱい甘やかしてね！',
  ]),
  AsmrTrack('yoru_1', 'よる', '真夜中の 電話', [
    'もしもし。ふふ、こんな時間に、わたしの声が聞きたくなった？',
    'うそうそ。かけたのは、わたしの方',
    'ねえ、わたしの祭壇、あんなに作っちゃって。重いファンだね',
    '…なんて。ほんとは、すっごくうれしかった',
    'ほかの子には、ないしょだよ',
    'あなたの声を聞いてたら、なんだか落ち着いた',
    'じゃあね。夢の中で、また会おっか',
  ]),
  AsmrTrack('yoru_2', 'よる', '夜の 観覧車', [
    'ほら、早く早く。閉園まで、あと少しだよ',
    '観覧車、乗ろ。てっぺんから見る夜景、きれいなんだって',
    '…わぁ。ほんとにきれい',
    'ねえ、こっち見て。夜景じゃなくて、わたしを',
    'ふふっ、顔、赤くなってる。かわいい',
    'あなたといると、からかうの、やめられないんだよね',
    'てっぺん、着いちゃった。…このまま、止まればいいのに',
  ]),
  AsmrTrack('yoru_3', 'よる', '今夜は 特別', [
    'ライブ成功。やるじゃん、わたしたち',
    '最後の曲、わたしのことだけ見てたでしょ。知ってるよ',
    'ほんとはね、ステージが終わると、ちょっとさみしくなるの',
    'だから、こうして会いに来てくれて、うれしい',
    '今夜は特別。からかわないで、ちゃんと言うね',
    'ありがとう。あなたが、わたしのいちばんのファンだよ',
    '…はい、おしまい。今の、もう一回は言わないからね',
  ]),
  AsmrTrack('momo_1', 'もも', 'ももの おねだり', [
    'ねえねえ、ちょっとだけ、ももの話、聞いて？',
    'ももの祭壇、あんなにかわいくしてくれて、ありがと！',
    'それでね、今日はひとつ、おねだりがあるの',
    'もものこと、名前で呼んでほしいな',
    '…きゃー！ 呼ばれちゃった！ もう一回！',
    'えへへ、あなたに呼ばれると、とくべつな名前になるね',
    'これからも、いっぱい呼んでね？',
  ]),
  AsmrTrack('momo_2', 'もも', '手作り チョコ', [
    'あのね、これ…ももの手作りチョコ！',
    'ほかの人には、あげてないよ。あなただけ、とくべつ',
    'ハートの形にするの、すっごく大変だったんだから',
    '食べて食べて！ …どう？ あまい？',
    'よかったぁ！ もも、ほっとしちゃった',
    'これはね、ももの気持ち、ぜんぶ入りなの',
    'お返し、楽しみにしてるね？ なーんて！',
  ]),
  AsmrTrack('momo_3', 'もも', 'ピンクの ペンライト', [
    'ライブ大成功！ ねえ、もも、かわいかった？',
    'ステージの上から、ピンクのペンライト、数えてたんだよ',
    'あなたのが、いちばんキラキラしてた',
    'ももね、あざといって言われるけど、これはほんとの気持ち',
    'ここまで連れてきてくれて、ありがとう',
    'これからも、ももの、いちばんでいてね',
    'だーいすき！',
  ]),
];

final asmrById = {for (final t in asmrTracks) t.id: t};
