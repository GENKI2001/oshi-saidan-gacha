// 実績 and the ささやきボイス (ASMR) they unlock. Pure Dart: the checks read a
// small snapshot of the player's records (Stats), so tests and tools can use them.

/// The records achievements are judged on (kept in Meta).
class Stats {
  final int runs, clears, bestPaydays, bestTurn, seen, maxAsc;
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
    this.maxAsc = 0,
    this.placed = const {},
    this.altarPeak = const {},
    this.clearedOn = const {},
    this.pulledStar4 = false,
  });
}

class Achievement {
  final String id, title, text;

  /// How far along: (now, goal).
  final (int, int) Function(Stats s) progress;

  /// The whisper track it unlocks (an id in [asmrTracks]), if any.
  final String? asmr;
  const Achievement(this.id, this.title, this.text, this.progress, {this.asmr});

  bool done(Stats s) {
    final (now, goal) = progress(s);
    return now >= goal;
  }
}

/// Each idol's own gacha (しずく and もも share theirs).
const idolMachine = {'ひなた': 'hinata', 'しずく': 'shizumomo', 'こはる': 'koharu', 'よる': 'yoru', 'もも': 'shizumomo'};
const _idolId = {'ひなた': 'hinata', 'しずく': 'shizuku', 'こはる': 'koharu', 'よる': 'yoru', 'もも': 'momo'};
const _machineName = {'hinata': 'ひなた推しガチャ', 'shizumomo': 'しずももガチャ', 'koharu': 'こはる推しガチャ', 'yoru': 'よるの真夜中ガチャ'};

final achievements = <Achievement>[
  Achievement('first_live', 'はじめてのライブ', 'ライブを1回終える', (s) => (s.runs, 1), asmr: 'tsumugi_1'),
  Achievement('first_clear', 'ライブ大成功', '4曲成功して ライブを成功させる', (s) => (s.clears, 1), asmr: 'tsumugi_2'),
  Achievement('encore', 'アンコール！', '1回のライブで 6曲成功する', (s) => (s.bestPaydays, 6), asmr: 'tsumugi_3'),
  for (final m in ['ひなた', 'しずく', 'こはる', 'よる', 'もも']) ...[
    Achievement('${_idolId[m]}_altar', '$mの祭壇', '祭壇に「$m」のグッズを 同時に6個 並べる', (s) => (s.altarPeak[m] ?? 0, 6), asmr: '${_idolId[m]}_1'),
    Achievement('${_idolId[m]}_place', '$m推し', '「$m」のグッズを 合計30個 祭壇に置く', (s) => (s.placed[m] ?? 0, 30), asmr: '${_idolId[m]}_2'),
    Achievement(
      '${_idolId[m]}_clear',
      '$mのライブ',
      '${_machineName[idolMachine[m]]}で ライブを成功させる',
      (s) => (s.clearedOn.contains(idolMachine[m]) ? 1 : 0, 1),
      asmr: '${_idolId[m]}_3',
    ),
  ],
  Achievement('heart100', 'ハートの嵐', '1回転で ハートを100 集める', (s) => (s.bestTurn, 100)),
  Achievement('heart500', '会場がゆれた', '1回転で ハートを500 集める', (s) => (s.bestTurn, 500)),
  Achievement('star4', 'キセキの星4', '★4のグッズを引く', (s) => (s.pulledStar4 ? 1 : 0, 1)),
  Achievement('book30', 'コレクター', '図鑑を 30種 うめる', (s) => (s.seen, 30)),
  Achievement('book60', '推し活のプロ', '図鑑を 60種 うめる', (s) => (s.seen, 60)),
  Achievement('book96', '図鑑コンプリート', '図鑑を 全部 うめる', (s) => (s.seen, 96)),
  Achievement('asc3', 'きびしいノルマ', '段位3で ライブを成功させる', (s) => (s.maxAsc >= 4 ? 1 : 0, 1)),
  Achievement('runs10', '常連さん', 'ライブを 10回 する', (s) => (s.runs, 10)),
];

final achievementById = {for (final a in achievements) a.id: a};

/// One whispered track: who, its name, and its lines in order.
class AsmrTrack {
  final String id, who, title;
  final List<String> lines;
  const AsmrTrack(this.id, this.who, this.title, this.lines);
}

const asmrTracks = <AsmrTrack>[
  AsmrTrack('hinata_1', 'ひなた', 'ふたりだけの ないしょ話', [
    'ねえ、こっち向いて。えへへ、ちょっとだけ、ないしょ話',
    '今日もひなたの祭壇、作ってくれて、ありがとう',
    'あなたが応援してくれるから、ひなた、がんばれるんだよ',
    'ほんとはね、ステージの前は、ちょっとこわいの',
    'でも、あなたの顔を思い出すと、だいじょうぶになるんだ',
    'ふふ、これは、ふたりだけの秘密ね',
  ]),
  AsmrTrack('hinata_2', 'ひなた', 'おやすみ前の お話', [
    'もう、こんな時間。眠くなってきた？',
    'じゃあ、ひなたが、子守唄のかわりに、お話ししてあげる',
    '今日のライブ、すっごく楽しかったね',
    'あなたのペンライト、ちゃんと見えてたよ',
    'ゆっくり休んで、また明日、元気に会おうね',
    'おやすみ。だいすきだよ',
  ]),
  AsmrTrack('hinata_3', 'ひなた', 'センターからの 耳打ち', [
    'ライブ、大成功だったね。おめでとう',
    'あのね、最後の曲の前、あなたのこと、探してたんだ',
    '見つけたとき、うれしくて、泣きそうになっちゃった',
    'ひなたの、いちばんのファンは、あなただよ',
    'これからも、となりで走ってくれる？',
    'えへへ。約束、だよ',
  ]),
  AsmrTrack('shizuku_1', 'しずく', '照れ屋の ささやき', [
    'ささやき声で、ごめんなさい。少し、照れくさくて',
    'わたしの祭壇、こんなに飾ってくれたんですね',
    'ひとつひとつ、大切にしてくれているの、わかります',
    '歌っているとき、ときどき、あなたのことを考えます',
    '今の、聞かなかったことにしてください',
    'ふふ。ありがとう',
  ]),
  AsmrTrack('shizuku_2', 'しずく', '雨の日の 深呼吸', [
    '雨の音、好きですか？',
    'わたしは、雨の日に、窓のそばで本を読むのが好きです',
    '今日は、あなたに、静かな時間をあげたくて',
    '目を閉じて。深呼吸、しましょう',
    '吸って。はいて',
    'はい、よくできました。おやすみなさい',
  ]),
  AsmrTrack('shizuku_3', 'しずく', '青い光の海で', [
    'ライブ、成功しましたね',
    'ステージの上から、客席の青い光が、海みたいに見えました',
    'その中に、あなたもいたんですよね',
    'わたし、あなたのために歌えて、幸せです',
    'これからも、わたしの歌を、いちばん近くで聴いてください',
    '約束ですよ',
  ]),
  AsmrTrack('koharu_1', 'こはる', 'ないしょの クッキー', [
    'えへへ、こっそり来ちゃった',
    'こはるのグッズ、いっぱい並べてくれて、ありがとう',
    'ごほうびに、ないしょのクッキー、あげるね',
    'はい、あーん。おいしい？',
    'こはるね、あなたが笑ってると、うれしいの',
    'ずっと、いっしょにいてね',
  ]),
  AsmrTrack('koharu_2', 'こはる', 'いっしょに お昼寝', [
    'ふわぁ、こはる、ちょっと眠くなってきちゃった',
    'あなたも、いっしょにお昼寝しよ？',
    'ほら、ブランケット、はんぶんこ',
    'あったかいね。ぽかぽかするね',
    '起きたら、ホットケーキ、焼いてあげる',
    'おやすみ。むにゃ',
  ]),
  AsmrTrack('koharu_3', 'こはる', 'ちいさな声で ありがとう', [
    'ライブ、大成功だね！ しーっ、小さい声でね',
    'こはる、最後まで、元気いっぱい歌えたよ',
    'それはね、あなたの声が、聞こえてたからなの',
    'ほんとだよ。こはる、耳がいいんだから',
    'これからも、こはるのこと、甘やかしてね',
    'えへへ、だいすき',
  ]),
  AsmrTrack('yoru_1', 'よる', '耳、弱いの？', [
    'ふふっ、耳、弱いの？',
    'わたしの祭壇、こんなに作っちゃって。重いファンだね',
    'うそ。うれしいよ',
    'ほかの子の前では、絶対言わないけど',
    'あなたは、わたしの特別',
    'ほら、顔、赤くなってる。ふふ',
  ]),
  AsmrTrack('yoru_2', 'よる', '眠れない夜に', [
    '夜って、静かでいいよね',
    'ねえ、まだ起きてる？ わたしも、眠れないの',
    'ちょっとだけ、お話しよ',
    '今日、星がきれいだったよ。あなたにも、見せたかった',
    'でも、ここにいるから、いいや',
    'おやすみ。いい夢、見てね',
  ]),
  AsmrTrack('yoru_3', 'よる', '今夜は 特別', [
    'ライブ成功。やるじゃん',
    '最後、わたしだけを見てたでしょ？ 知ってるよ',
    'ほんとはね、ステージの後は、ちょっとさみしくなるの',
    'だから、こうして、そばにいてくれて、うれしい',
    '今夜は、からかわないであげる',
    'ありがとう。だいすきだよ',
  ]),
  AsmrTrack('momo_1', 'もも', 'ほんとの気持ち', [
    'ねえねえ、もものこと、好き？ 耳元で、言ってほしいな',
    'ももの祭壇、いっぱい作ってくれて、ありがとう',
    'ももね、あざといって言われるけど',
    'あなたにだけは、ほんとの気持ち、言うね',
    'あなたのこと、ほんとに、だいすき',
    'えへへ、言っちゃった',
  ]),
  AsmrTrack('momo_2', 'もも', 'さみしがりの夜', [
    'もも、ちょっとだけ、さみしかったの',
    'だから、こうして、となりにいてもいい？',
    'ぎゅー。あったかい',
    'あなたといると、安心するんだ',
    '今日は、このまま、いっしょに休もうね',
    'おやすみ。夢の中でも、会いに行くね',
  ]),
  AsmrTrack('momo_3', 'もも', 'ピンクのペンライト', [
    'ライブ、大成功！ しーっ、ないしょ話ね',
    'ステージの上から、ピンクのペンライト、数えてたの',
    'あなたのが、いちばんキラキラしてたよ',
    'ももを、ここまで連れてきてくれて、ありがとう',
    'これからも、ももの、いちばんでいてね',
    'だーいすき',
  ]),
  AsmrTrack('tsumugi_1', 'つむぎ', 'マネージャーの ねぎらい', [
    'おつかれさまです。マネージャーの、つむぎです',
    '今日は、ないしょで、少しだけ、ねぎらいに来ました',
    'はじめてのライブ、どうでしたか？',
    'わたしは、すごく、どきどきしました',
    '次も、いっしょに、がんばりましょうね',
    'おつかれさまでした',
  ]),
  AsmrTrack('tsumugi_2', 'つむぎ', '記録に残さない話', [
    'ライブ、大成功です。小声で、失礼します',
    'みんなの前では、マネージャーらしくしてますけど',
    '本当は、客席で、いっしょに泣きそうでした',
    'あなたが、ぷりパレを支えてくれたから',
    'ありがとうございます。心から',
    'これは、記録には、残しませんからね',
  ]),
  AsmrTrack('tsumugi_3', 'つむぎ', 'いちばん古いファン', [
    'アンコールまで、本当に、お疲れさまでした',
    'あの、ひとつ、ないしょの話をしてもいいですか',
    'わたし、ぷりパレの、いちばん古いファンなんです',
    'マネージャーになったのも、近くで応援したかったから',
    'だから、あなたと出会えて、うれしいです',
    'これからも、よろしくお願いしますね',
  ]),
];

final asmrById = {for (final t in asmrTracks) t.id: t};
