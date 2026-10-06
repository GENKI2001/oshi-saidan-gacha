// English. The game is written (and voiced) in Japanese; on a device set to any other language
// the text shows in English, while the voices and songs stay Japanese (the lines on screen are
// their subtitles). Pure Dart, so lib/logic can use it too.
//
// How text is translated:
// - A fixed Japanese string: `tr('ガチャ選択へ')`, with its English in one of the maps below.
//   The Japanese stays the key everywhere it is a key (voice lookup, tags, ids).
// - A string with numbers or names in it: `en ? 'Song $n' : '$n曲目'` right where it is built.
// - Text must follow [en] when it is read, not when it is first built (the language can be
//   switched while the app runs), so translate in getters / build methods, never into a
//   top-level `final` that is computed once.
//
// Glossary (use these words everywhere):
//   ハート Hearts · 祭壇 altar · グッズ goods · ガチャ gacha · 回す！ Spin! · カプセル capsule
//   もう一回ひく Re-pull · 品がえ Restock · ノルマ quota · 曲 song · ○曲目 Song ○ · ライブ live / the show
//   ライブ大成功 Live success! · アンコール encore · 盛り上がり hype · 運 luck · 出現率UP rate-up
//   レア商品 rare item · つむぎの物販ブース Tsumugi's merch booth · タダ FREE · 祭壇に置く Place on altar
//   重ねる stack · 転売ヤー scalper · カイシメ Kaishime · まもる！ Guard! · まもれ！ Push back!
//   実績 Achievements · シチュエーションボイス Situation Voice · コレクション / 図鑑 Collection
//   メンバー Members · ランキング Ranking · あそびかた How to play · メニュー Menu · とじる Close
//   推し oshi (your favourite; keep the word, idol fans know it) · ○○推しガチャ ○○ Oshi Gacha
//   ★1〜★4 stay as stars; R以上 ★2+ · 期間限定 limited-time · 全国○位 #○ worldwide
//   難易度: かんたん Easy · ふつう Normal · むずかしい Hard · げきむず Very Hard · おに Brutal
// Names: ひなた Hinata · しずく Shizuku · こはる Koharu · よる Yoru · もも Momo · つむぎ Tsumugi
//   (full: 天音 ひなた Hinata Amane · 水瀬 しずく Shizuku Minase · 春野 こはる Koharu Haruno ·
//   夜宮 よる Yoru Yomiya · 桃瀬 もも Momo Momose) · ぷりずむ☆パレット Prism☆Palette · ぷりパレ PriPale
//   ぱれにゃん Palenyan · しずもも ShizuMomo · ひなもも HinaMomo · カイシメ Kaishime
//   ファン(tag) Fans · 応援(tag) Cheer · のろい(tag) Curse
// Tone: the idols are bubbly, cute and casual; つむぎ is a polite, slightly deadpan manager.
// Keep English short: it runs longer than Japanese and most of it sits in small boxes.

import 'en_asmr.dart';
import 'en_idols.dart';
import 'en_lines.dart';
import 'en_logic.dart';
import 'en_ui_game.dart';
import 'en_ui_menus.dart';

/// Show the text in English (set from the device language at start, switchable in the menu).
bool en = false;

/// [ja] in the current language: itself in Japanese, its English otherwise (Japanese if none yet).
String tr(String ja) => en ? (enText[ja] ?? ja) : ja;

/// Every fixed string's English, keyed by the Japanese.
final Map<String, String> enText = {...enLines, ...enIdols, ...enAsmr, ...enLogic, ...enUiGame, ...enUiMenus};
