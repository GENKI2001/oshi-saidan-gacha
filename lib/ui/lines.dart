// ぽん親分（取り立て役）の台詞。mood: 0=ふつう 1=ご機嫌 2=びっくり 3=おこ
import 'dart:math' as math;

final _r = math.Random();
String pick(List<String> xs) => xs[_r.nextInt(xs.length)];

const lineStart = ['よう来たな。ガチャ代はタダや。そのかわり5回ごとにショバ代もらうで', 'ここの棚はあんたのもんや。並べ方しだいで化けるで'];
const lineIdle = ['回さんと始まらんで', 'ハンドル、遠慮せんと回し', '今日はええの入っとるで。知らんけど', 'ワシの顔見とらんで、ガチャ見ぃ'];
const lineBigTurn = ['なんやその稼ぎ…ワシより持っとるやん', 'ちょ、ちょっと待ちぃ。計算合っとる？', 'そろばんが追いつかへん'];
const lineSmallTurn = ['しょっぱいなぁ', 'それで足りるんか？', 'ワシは知らんで〜'];
const linePaid = ['まいど！', 'ええ心がけや', 'ほな、また5回後にな'];
const lineCard = ['ワシの名刺置いとくわ。大事にしてや', '名刺や。捨てたら泣くで'];
const lineFail = ['足りひんやないか！', '出直してき！', 'ツケは効かんで！'];
const linePostpone = ['…しゃあない、今回だけやで。次まとめてもらうからな'];
const lineClear = ['……参った。あんたがこの縁日の主や'];
const lineLegend = ['うそやろ…レジェンドやんけ', 'それ、ワシも見たことないやつや'];
