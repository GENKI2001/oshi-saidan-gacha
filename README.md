# ぽんぽこガチャ縁日（ガチャ収集ローグ・型02の最初の版）

仕様：`../../specs/02_ガチャ収集ローグ.md`

## 動かす
```
flutter run                 # iOS シミュレーター／実機
flutter run -d chrome       # ブラウザ
flutter test                # ルールのテスト＋最後まで自動で遊ぶテスト
dart run tool/sim.dart 2000 # バランス調整（ボット3種のクリア率・駒ごとの貢献）
```

## シミュレーターで確認
```
open -a Simulator
flutter run -d <シミュレーターID> --dart-define=RANK_DEMO=true     # デモのランキングで画面確認
flutter test integration_test -d <シミュレーターID> --dart-define=RANK_DEMO=true  # 自動で通し確認
```
`RANK_DEMO=true` を外すと本物の Game Center につなぐ（下の設定が必要）。

## ランキング（サーバーなし）の設定
ID は `lib/ui/rank.dart` の `boards` に書く。

**iOS（Game Center）**
1. Apple Developer で Bundle ID（`com.sonson.ponpoko`）を登録し、Game Center を有効にする
2. App Store Connect でアプリを作成 →「Game Center」→ リーダーボードを3つ作る
   - `gacha.best_turn`：クラシック、大きい方が上
   - `gacha.ascension`：クラシック、大きい方が上
   - `gacha.paydays`：クラシック、大きい方が上（延長戦も含めて払えた取り立ての回数）
3. シミュレーター／実機の「設定」→「Game Center」で Apple ID（サンドボックスでも可）にログイン
4. `RANK_DEMO` なしで起動すると、ログインのシートが出てスコアが送られる

**Android（Google Play ゲーム サービス）**
1. Play Console → Play ゲーム サービス → 設定で、ゲームを作成してアプリとリンク
2. リーダーボードを3つ作り、出てきた ID（`CgkI…`）を `rank.dart` の android 側に書く
3. プロジェクト ID を `android/app/src/main/res/values/games-ids.xml` に書く

送れなかったスコアは端末に残り、次にログインした時に送られる。

## 構成
| 場所 | 中身 |
|---|---|
| `lib/logic/defs.dart` | 効果の文法（DSL）。説明文は効果から自動生成 |
| `lib/logic/figures.dart` | テーマ「縁日」の駒 96 種（データだけ） |
| `lib/logic/levels.dart` | 縁日レベル（累計の稼ぎ → レベル → 解禁される駒） |
| `lib/logic/run.dart` | 1ランのルール（ガチャ・棚・集計・取り立て・店）。Flutter 非依存 |
| `lib/ui/controller.dart` | 画面の進行と演出のタイミング |
| `lib/ui/game_screen.dart` | ゲーム画面・各オーバーレイ |
| `lib/logic/modes.dart` | マシン6種・段位0〜10（どちらも `Rules` の差分） |
| `lib/ui/lines.dart` | ぽん親分の台詞 |
| `lib/ui/rank.dart` / `rank_screen.dart` | ランキング（Game Center / Play ゲーム）。サーバー不要 |
| `integration_test/app_test.dart` | シミュレーター上で1ラン最後まで遊び、駒の詳細表示とランキング表示まで確認 |
| `lib/ui/sfx.dart` | 効果音の再生（音ごとに小さなプールで重ね鳴らし） |
| `art/bgm.py` | BGM 2曲（祭り囃子・琴）を合成して `assets/bgm/` に書き出す（継ぎ目なしループ） |
| `art/sfx.py` | 効果音54種を合成して `assets/sfx/` に書き出す（素材なし・ライセンスフリー）。`candidates` を付けるとガチャ音の候補と試聴ページを `art/sfx_candidates/` に出す。使う候補は先頭の `HANDLE` / `DROP` |
| `tool/sim.dart` | ヘッドレスのシミュレーター |
| `art/gen/` | Codex の画像プロンプトと生成元 |
| `art/slice.py` | マゼンタ背景のシートを透過 PNG に切り出す |
| `art/howto.py` | `art/howto/` のゲーム画面スクショを切り抜き、印を付けて あそびかた の絵（`assets/howto/`）にする |

## 縁日レベル
- これまで稼いだ小判の合計（端末に保存）でレベルが上がる。必要枚数は `lib/logic/levels.dart` の `levelNeed`
- 駒の `level` がそのレベルになるとガチャに出る（ランの途中で上がっても、出るのは次のランから）

## 駒を足す
1. `figures.dart` に `FigureDef` を足す（効果は `defs.dart` の部品だけで書く。`level:` で解禁レベル）
2. `dart run tool/sim.dart` で強すぎ・弱すぎを確認（lift が +15 を超えたら強すぎ）
3. 画像は `art/gen/*.txt` と同じ書式でシートを生成 → `art/slice.py` に ID を足して切り出し

## マシン・段位を足す
- マシン：`modes.dart` の `machines` に1つ足す（出やすいタグ・棚の形・初期駒・取り立て倍率・解放条件）
- 足したら `dart run tool/sim.dart` でクリア率を確認（店も使うボットで 20〜55% が目安）

## まだ入っていないもの
- 広告（「広告を見て待ってもらう」は今は無料でコンティニュー）
- ストア側のランキング登録（上の手順。登録するまでは `RANK_DEMO=true` で画面確認）

## リリースビルド
```
flutter build ipa --release          # iOS（App Store Connect へアップロード）
flutter build appbundle --release    # Android（Google Play へアップロードする .aab）
```
- アプリID：`com.sonson.ponpoko`（iOS・Android 共通。リリース後は変更不可）
- Android の署名：`android/key.properties`（git 管理外）が `~/.android-keys/ponpoko-upload.jks` を指す。
  鍵とパスワード（`~/.android-keys/ponpoko-key.properties`）は必ずバックアップすること。
  `key.properties` がないとデバッグ鍵で署名される。
- 広告：iOS だけ AdMob のリワード広告（今は Google のテスト用ID）。本番前に `lib/ui/ads/ads_mobile.dart` の広告ユニットIDと
  `ios/Runner/Info.plist` の `GADApplicationIdentifier` を自分のものに差し替える。Android は広告なし（`--dart-define=ADS=true` で表示して確認できる）。
- iPhone 専用（iPad 対応なし）。

## ストア用の素材
- 掲載文・キーワード：`docs/store_listing.md`／プライバシーポリシー：`docs/privacy_policy.md`
- スクリーンショット：`tool/screenshots.sh <シミュレーターID> store/ios_6.9`（iPhone 17 Pro Max で撮ると 6.9インチ用の 1320×2868）
- `store/android_phone/`（縦横比 2:1 以内にした版）、`store/android/feature_graphic_1024x500.png`、`store/android/icon_512.png`
