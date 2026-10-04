# 推し祭壇ガチャ（ガチャ収集ローグ・型02の派生／男性向け・フルボイス）

『ぽんぽこガチャ縁日』（`../gacha_rogue`）と同じエンジンで、テーマを「アイドルの推し活」にした派生版。
ルール（`lib/logic/run.dart`）は同じで、駒（グッズ）・マシン・絵・声・BGM を差し替えている。
仕様：`../../specs/02_ガチャ収集ローグ.md`

- コンセプトは「推しのライブを成功させる」。通貨はハート。5回まわすごとに1曲で、曲ごとのハートのノルマを4曲ぶん届ければライブ大成功、そのあとはアンコール（ロジック上は縁日版の取り立て・完済・延長戦と同じ）
- 会場はハートが集まるほど盛り上がる：背景の会場が4段階（`assets/ui/venue_0..3.jpg`、同じ構図の編集）でクロスフェードし、ペンライト・ハート・光線・紙吹雪が増える（`lib/ui/venue.dart`）。盛り上がり度は `GameController.hype`
- 歓声：ループはなし。ハートを数えている間に短い歓声が重なって大きくなり（盛り上がり度で大きさが変わる）、大きく稼ぐと歓声、曲の成功で大歓声、推しのグッズを置くと客席から名前コール（`lib/ui/crowd.dart`、音は `art/crowd.py` が TTS のファンの叫び声とノイズから合成）
- アイドルユニット「ぷりずむ☆パレット」5人（ひなた・しずく・こはる・よる・もも）＋マネージャーのつむぎ（ノルマ係）。全員20歳の架空の人物
- グッズのタグ＝推しの名前。同じ推しを並べる・推し同士のコンビで稼ぐ
- **ボイス**：メンバー5人のガチャ時の台詞・応援・タイトルコール・妨害の台詞を音声で再生。祭壇のグッズをタップするとそのメンバーがしゃべる。つむぎは文字だけ（声はささやきボイスのみ）
- **妨害イベント**：駒を置いたあと・点数計算の前に、転売ヤーのカイシメが乗りこんでくる（ふつう5%、ガチャ台で変わる）。サイレンとカットインのあと、祭壇にいちばん多いメンバーと押し合い。「まもれ！」の連打でまもれる確率が上がる（10回/秒の連打で約80%）。押しの強さと、負けたときの効果（グッズを1〜2個持っていかれる／この曲はもう一回ひくなし／この曲のハート半分／ハートを20〜40%失う）はランダム（`Run.rollJam`、画面は `lib/ui/jam_widgets.dart`、音は `art/sfx_jam.py`）
- 祭壇のグッズは上から置きかえられる（注意書きの上に置くと +20）。どける・いれかえ・段位はなし
- レア度は星1〜4。★3 / ★4 を引くと推しのカットイン（`lib/ui/idol_widgets.dart`）。カプセルはレア度ごとの絵（`assets/ui/capsule_<n>_top/bot.png`、`art/slice.py` が継ぎ目で上下に切る）
- 実績（`lib/logic/achievements.dart`）：達成すると ささやきボイス（ASMR、18本）が聞ける。`art/asmr.py` が台詞を本物のささやき声に変換して左右の耳に振り分けた1本の音声にする（`assets/asmr/`、字幕のタイミングは `lib/ui/asmr_timing.dart`）
- タイトルのメンバーをタップ／メンバー紹介でボイスが聞ける

## Web 版（GitHub Pages）
https://genki2001.github.io/oshi-saidan-gacha/ — main に push すると `.github/workflows/pages.yml` が Web 版をビルドして公開する（広告・ランキングは Web では無効）

## 動かす
```
flutter run                 # iOS シミュレーター／実機
flutter test                # ルールのテスト＋最後まで自動で遊ぶテスト
dart run tool/sim.dart 2000 # バランス調整（ボット3種のクリア率・グッズごとの貢献）
flutter test integration_test/app_test.dart -d <シミュレーターID> --dart-define=RANK_DEMO=true  # 実機相当で通し確認
```

## 構成（縁日版との差分）
| 場所 | 中身 |
|---|---|
| `art/goods.py` | グッズ96種の表（縁日版の駒 → 新ID・名前・絵文字・タグ・絵の説明）。`figures` で `lib/logic/figures.dart` を、`prompts` で画像プロンプトを生成。効果の数字は縁日版と同じ |
| `lib/logic/modes.dart` | ガチャ台13種と難易度（かんたん〜おに、`tool/sim.dart` のクリア率から決めた） |
| `lib/ui/jam_widgets.dart` | 妨害イベントの画面（カイシメの絵は `art/gen/jama.txt` → `assets/ui/jama_a/b.webp`） |
| `lib/ui/lines.dart` | 声の出る台詞すべて（つむぎ／5人／チュートリアル）。数字の変わる文は入れない（声は文ごとに1回録るため） |
| `lib/ui/voice.dart` | ボイス再生。1度に1人、話している間は BGM を下げる。設定で ON/OFF |
| `lib/ui/voice_ids.dart` | 「話者\|台詞」→ `assets/voice/<id>.m4a`（生成物） |
| `lib/ui/idol_widgets.dart` | カットイン・吹き出し・顔アイコン・メンバーの色 |
| `lib/ui/member_screen.dart` | メンバー紹介 |
| `art/songs/` | 歌入り BGM 8曲（ACE-Step 1.5 で作り、歌はメンバー本人の声で歌い直し＝`sing.py`。歌詞は `docs/lyrics.md`）。手順と採用テイクは `art/songs/README.md`。`art/bgm.py` は以前の歌なし版（今は未使用） |
| `art/slice.py` | Codex の生成画像（マゼンタ／グリーン背景）を透過 PNG に。背景は端から続く部分だけ抜くので紫・ピンクの絵が欠けない |
| `art/launch.py` | 起動画面（iOS はキービジュアル全面、Android はロゴ） |
| `art/crowd.py` | 歓声・コール（`voice/crowd/` の叫び声 → `assets/sfx/crowd_*.wav` など） |
| `lib/ui/venue.dart` / `lib/ui/crowd.dart` | 盛り上がる会場の背景／客席の音 |

## ボイスを作り直す
台詞を変えたら（Irodori-TTS：`~/Desktop/escape-games/tadaima-hiyori/tools/Irodori-TTS` を使用）
```
dart run tool/voice_lines.dart > voice/lines.json
python3 voice/make_voice_jobs.py          # voice/jobs.json と lib/ui/voice_ids.dart（変わった台詞だけ新しいID）
cd ~/Desktop/escape-games/tadaima-hiyori/tools/Irodori-TTS && PYTHONPATH=. .venv/bin/python <このフォルダ>/voice/voice_batch.py <このフォルダ>/voice/jobs.json
python3 voice/convert_voice.py            # assets/voice/*.m4a（使われなくなったものは消す）
```
- 歓声の元の叫び声：`voice/crowd_jobs.json`（`check: false` で ASR チェックなし）→ `python3 art/crowd.py`
- 声の元：`voice/candidates/<話者>_<A-C>.wav` から1つを参照音声にしている（`make_voice_jobs.py` の `VOICES`）。つむぎは A だと声が高くなりすぎたので B
- 読みの直し：`READINGS`（×2→2倍、SSR→エスエスアール、推し祭壇→おしさいだん…）。言い間違いの撮り直しは `SEED` に台詞と別のシードを書く
- 自動チェック：頭の30msが無音か、Whisper の聞き取りが台本と近いか（`voice_batch.py`）。**最後は耳で確認すること**

## 絵を作り直す
`art/gen/*.txt` がプロンプト、`*.refs` が参照画像（`chars_ref.png` = キャラ設定画）。
```
cd art/gen && ./codex_image.sh goods3      # out_goods3.png（5〜10分）
python3 art/slice.py && python3 art/icon.py && python3 art/launch.py
```

## 解放（レベルはない。縁日版と同じしくみ）
- グッズ：それぞれ「どのガチャを初めてクリアするとガチャに入るか」（`FigureDef.from`）。最初から入っているのは52種。どのガチャも 初クリアで何かしら入る。
  メンバーのグッズはその推しガチャ、ファンはファンミ、ぱれにゃんはぱれにゃん、応援はぷりパレとおためし、しずももはしずもも、豪華なものはプレミアム、スタッフは転売ヤー警戒、ドーム・ツアー・ソロ衣装はドームのクリアで入る。
  初クリアの時に「新しく N 種がガチャに」の通知。選択画面のガチャには、クリアで入るグッズを（クリア前はシルエットで）出し、図鑑のまだのグッズには「○○でクリア」を出す
- ガチャ：ぷりパレ →しずもも・こはる推し、こはる推し→ひなた推し、しずもも→しずく推し・もも推し、しずく推し→よる推し、ひなた推し→ファンミ、
  よる推し→転売ヤー警戒、プレミアム→ドーム。ぱれにゃんは図鑑40種、プレミアムはどれかで5回クリア。一度解放されたガチャはずっと解放のまま
- 詰み防止：`test/modes_test.dart` が、新しいセーブから全部のガチャと全部のグッズにたどり着けることを確かめる
- 難易度の目安（上級者ボット、`dart run tool/sim.dart 2000 machines`）：★2 約30%、推しガチャ 約20%、★3 約15%、★4 約10%、★5 約5%

## ランキング（サーバーなし）の設定
ID は `lib/ui/rank.dart` の `boards`（`oshi.best_turn` / `oshi.paydays`）。手順は縁日版の README と同じ。
Android は Play Console で作った ID を `rank.dart` と `android/app/src/main/res/values/games-ids.xml` に書く。

### ガチャごとのランキング（「このガチャで全国○位」）
ガチャ選択のカードに、そのガチャでの「1回の最高ハート」の全国順位を出す。ボードは `lib/ui/rank.dart` の `machineBoards`（ガチャの一覧から自動で作る）。
- App Store Connect：Game Center → リーダーボード（クラシック）を下の iOS ID で作る。スコアは整数・大きいほど上・期間なし。作ったら審査に出すバージョンの Game Center 欄に追加する
- Play Console：Play ゲームサービス → リーダーボードを同じ名前で作り、振られた ID を `rank.dart` の Android 側（今は `CgkI_REPLACE_turn_…`）と `android/app/src/main/res/values/games-ids.xml` に書く
- 登録前・未ログインのときは送れなかったスコアを取っておき（ガチャごとに送った最高値も覚えている）、登録後に送る。順位はわかった台だけ表示する

| iOS ID | 表示名 | Android（仮） |
|---|---|---|
| `oshi.turn.pripare` | ぷりパレガチャの最高ハート | `CgkI_REPLACE_turn_pripare` |
| `oshi.turn.otameshi` | おためしガチャの最高ハート | `CgkI_REPLACE_turn_otameshi` |
| `oshi.turn.shizumomo` | しずももガチャの最高ハート | `CgkI_REPLACE_turn_shizumomo` |
| `oshi.turn.koharu` | こはる推しガチャの最高ハート | `CgkI_REPLACE_turn_koharu` |
| `oshi.turn.hinata` | ひなた推しガチャの最高ハート | `CgkI_REPLACE_turn_hinata` |
| `oshi.turn.shizuku` | しずく推しガチャの最高ハート | `CgkI_REPLACE_turn_shizuku` |
| `oshi.turn.momo` | もも推しガチャの最高ハート | `CgkI_REPLACE_turn_momo` |
| `oshi.turn.nyan` | ぱれにゃんガチャの最高ハート | `CgkI_REPLACE_turn_nyan` |
| `oshi.turn.yoru` | よる推しガチャの最高ハート | `CgkI_REPLACE_turn_yoru` |
| `oshi.turn.fan` | ファンミーティングガチャの最高ハート | `CgkI_REPLACE_turn_fan` |
| `oshi.turn.premium` | プレミアムガチャの最高ハート | `CgkI_REPLACE_turn_premium` |
| `oshi.turn.tenbai` | 転売ヤー警戒ガチャの最高ハート | `CgkI_REPLACE_turn_tenbai` |
| `oshi.turn.dome` | ドームツアーガチャの最高ハート | `CgkI_REPLACE_turn_dome` |

## リリースビルド
```
flutter build ipa --release          # iOS
flutter build appbundle --release    # Android
```
- アプリID：`com.sonson.oshisaidan`（iOS・Android 共通。リリース後は変更不可）
- Android の署名：`android/key.properties`（git 管理外）を作って新しいアップロード鍵を指す（縁日版の鍵は使い回さない）。ないとデバッグ鍵で署名される
- 広告：縁日版と同じく Google のテスト用ID。本番前に `lib/ui/ads/ads_mobile.dart` の広告ユニットIDと `ios/Runner/Info.plist` の `GADApplicationIdentifier` を差し替える
- iPhone 専用（iPad 対応なし）

## ストア用の素材
- 掲載文・キーワード：`docs/store_listing.md`／プライバシーポリシー：`docs/privacy_policy.md`
- スクリーンショット：`tool/screenshots.sh <iPhone 17 Pro Max のID> store/ios_6.9`（1320×2868）→ `python3 art/store.py`（Android 用の比率・フィーチャーグラフィック・512アイコン）
- あそびかたの絵：`tool/screenshots.sh <iPhone 17 Pro のID> art/howto/shots` → `python3 art/howto.py`
