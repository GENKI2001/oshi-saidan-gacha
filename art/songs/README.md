# 歌入り BGM（assets/bgm/*.m4a）

> **歌詞は全部ひらがなで ACE-Step に渡す。** 漢字だと読み間違える（タイトルの「赤 青 黄色 紫」が「あか おう そいろ さき」、「虹色」が「にじろ」になった）。歌詞を考えたら、カタカナ語も含めて全部ひらがなにして `songs.py` の `lyrics_kana` に書き、`gen_songs.py --lyrics lyrics_kana` で作る。区切りの空白はフレーズの切れ目だけに入れる。☆ などの記号や、ユニット名「ぷりずむぱれっと」のような造語も入れない（崩れて、ほかの所まで狂う。タイトルのサビは「ひかりをかさねて」「てのひらいっぱい」に変えた）。漢字の歌詞は `docs/lyrics.md` に残してよい。ローマ字は不要。repaint（`repaint.py`）で一部だけ言い直すとメロディーが崩れるので、使わずに曲ごと作り直す。

## メンバー本人の声で歌い直す（今の assets/bgm）
ACE-Step の歌声は AI っぽさが残るので、採用テイクのボーカルを抜き出して、ゲームのボイスと同じ5人の声で歌い直し、伴奏に戻している（`sing.py`）。
- ボーカル分離：demucs `htdemucs_ft`（`--two-stems=vocals`）
- 歌声変換：Seed-VC（https://github.com/Plachtaa/seed-vc 、commit 51383ef、f0 条件つきの歌声モデル `seed-uvit-whisper-base`）。セットアップ先は `~/tools/svc/seed-vc`（venv は python3.10。`inference.py` は MPS 用に F0 を float32 にし、保存を soundfile に変えている）
- 声のお手本：各メンバーのボイス（`voice/render`、元気な台詞から）を約20秒つないだもの（`~/tools/svc/work/refs/<id>.wav`）
- 割り振り（`sing.py` の `CAST`）：ひなた・こはる・よるの曲はソロ、ユニット曲（選択・ぷりパレ・プレミアム）は5人。タイトルとしずももは元の歌のまま（そのほうが良かったので。かわりに下のハモりを足している）。サビ（Whisper の聞き取りを歌詞と照らして判定）は全員の合唱（左右に散らし数msずらす）、それ以外は1行ずつ交代。元の歌がない所は消し（変換が伴奏を声にしてしまうため）、軽いホールの残響をかける

### タイトルとしずももは「元の歌＋メンバーのハモり」（`harmony.py`）
元の ACE-Step の歌は差し替えずに残し、要所にだけメンバーの声のハモりを足している。Seed-VC の音程シフトを置き換え、1フレームごとに曲の調の音階で n 個となりの音へ動かすので（+2＝3度上、-2＝3度下、-5＝6度下、0＝主旋律を重ねる）、長短が調に合う。どこで誰が何度でハモるかは `TRACKS` に書いてある。左右に振って残響をかける。
- しずもも（A major）：ももが3度上・しずくが3度下。サビ、Pre-Chorus「並べば ちょうどいい」、Aメロの1行ずつ、Outro「ふたりで ひとつの メロディー」。元の歌声より 7dB 小さく
- タイトル（E major、5人）：声の高さ（話し声の中央値 ひなた B4・もも A4・こはる E4・しずく D#4・よる B3）で割り振り、合唱は もも3度上／ひなた・こはるが主旋律を左右で重ねる／しずく3度下／よる6度下。1番の2行目と Pre-Chorus 前半は もも＋しずくの2人、「ステージへ ジャンプ」からサビ、「ひとりじゃ出せない」、2番 Pre-Chorus〜サビ〜Outro は5人。主旋律を重ねる声は `sing.py` 用の全体変換（`work/conv`）があればそれを使う

- 歌詞の言い直し（`repaint.py`）：タイトルの「赤 青 黄色 紫 ピンク」を ACE-Step の repaint で、その区間だけひらがなの歌詞で作り直してみた。発音は良くなったがメロディーが崩れたので、使わなかった。「虹色」も、短い区間・行全体・XL モデルのどれで試しても元より悪くなった。結局、全部ひらがなの歌詞で曲ごと作り直す方がよかった（上の注意書き）

```
~/tools/svc/seed-vc/.venv/bin/python art/songs/harmony.py convert bgm_title
~/tools/svc/seed-vc/.venv/bin/python art/songs/harmony.py mix bgm_title
python3 art/songs/finalize.py bgm_title=$HOME/tools/svc/work/harmony/bgm_title/mix.wav
```

```
W=~/tools/svc/work
~/tools/svc/seed-vc/.venv/bin/python -m demucs --two-stems=vocals -n htdemucs_ft -d mps -o $W/sep <take.wav>
~/tools/svc/seed-vc/.venv/bin/python art/songs/convert_batch.py            # 全員ぶんの変換（モデルは1回だけ読む。1曲1人 約5〜8分）
~/Desktop/escape-games/tadaima-hiyori/tools/Irodori-TTS/.venv/bin/python art/songs/sing.py align   # 歌詞の行の位置
~/tools/svc/seed-vc/.venv/bin/python art/songs/sing.py mix                  # → $W/mixed/<track>.wav
python3 art/songs/finalize.py bgm_title=$W/mixed/bgm_title.wav ...
```

## ACE-Step におまかせで作る（`inspire.py`）
短い注文文（`QUERY`）から ACE-Step 1.5 の言語モデルが説明・歌詞（ローマ字）・テンポ・キーを書き、そのまま曲にする（Simple Mode の `create_sample`）。ぷりパレ・ドーム・転売ヤー警戒の曲はこれ（出力は `~/tools/songgen/out_inspire/`、書いた歌詞は同名の .json）。

## ACE-Step におまかせで作る（`inspire.py`）
短い注文文（`QUERY`）から ACE-Step 1.5 の言語モデルが説明・歌詞（ローマ字）・テンポ・キーを書き、そのまま曲にする（Simple Mode の `create_sample`）。ぷりパレ・ドーム・転売ヤー警戒の曲はこれ（出力は `~/tools/songgen/out_inspire/`、書いた歌詞は同名の .json）。

## もとの歌入りテイクを作る（ACE-Step）

- モデル：ACE-Step 1.5（https://github.com/ace-step/ACE-Step-1.5 、MIT License、commit ca1e85f）
  - DiT `acestep-v15-turbo`（8 steps, guidance 1.0, shift 3.0）＋ LM `acestep-5Hz-lm-1.7B`（mlx）
  - セットアップ先：`~/tools/songgen/ACE-Step-1.5`（専用の venv）。生成物は `~/tools/songgen/out_turbo/`
- 歌詞：`docs/lyrics.md`（オリジナル）。曲ごとの設定（テンポ・キー・スタイル・歌詞）は `songs.py`

## 作り直す
```
cd ~/tools/songgen/ACE-Step-1.5
.venv/bin/python <project>/art/songs/gen_songs.py --tracks bgm_title --seeds 11 12 13 --out ~/tools/songgen/out_turbo
~/tools/songgen/qc/bin/python <project>/art/songs/qc.py ~/tools/songgen/out_turbo/bgm_title*.wav   # 歌詞の聞き取り率・音量・無音
python3 <project>/art/songs/finalize.py bgm_title=~/tools/songgen/out_turbo/bgm_title__acestep-v15-turbo__s11.wav
```
`finalize.py`：頭とお尻の無音カット、終わり 1.5 秒フェード、-16 LUFS、AAC 128kbps ステレオ。

## 採用したテイク（Whisper の歌詞カバー率で選んだ。耳での確認はまだ）
| 曲 | seed | 歌詞カバー率 |
|---|---|---|
| bgm_title | 11 | 0.64 |
| bgm_select | 11 | 0.68 |
| bgm_hinata | 11 | 0.68 |
| bgm_koharu | 12 | 0.63（s13 は無音 6.8 秒があり不採用） |
| bgm_shizumomo | 13 | 0.61 |
| bgm_yoru | 12 | 0.60 |
| bgm_clear（ノルマ達成・物販、歌なし） | 31 | — |
| bgm_result（リザルト、歌なし） | 32 | — |
| bgm_pripare | `inspire.py` i4（ACE-Step のおまかせ：歌詞も曲も ACE-Step） | — |
| bgm_dome（ドームツアー） | `inspire.py` i3 | — |
| bgm_tenbai（転売ヤー警戒） | `inspire.py` i5 | — |
| bgm_premium | 11 | 0.50（文字起こし冒頭の「作詞・作曲…」は Whisper の幻聴でイントロに歌はない） |
| bgm_lobby（ぷりパレガチャ「きらきら はっぴー」） | `out_lobby` の kana s74（耳で選んだ） | —（`harmony.py` の `bgm_lobby` で5人のハモり・ビブラート・しゃくり・息・冒頭のひなたのセリフを足した） |
