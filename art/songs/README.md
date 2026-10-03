# 歌入り BGM（assets/bgm/*.m4a）

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
| bgm_pripare | 11 | 0.69 |
| bgm_hinata | 11 | 0.68 |
| bgm_koharu | 12 | 0.63（s13 は無音 6.8 秒があり不採用） |
| bgm_shizumomo | 13 | 0.61 |
| bgm_yoru | 12 | 0.60 |
| bgm_premium | 11 | 0.50（文字起こし冒頭の「作詞・作曲…」は Whisper の幻聴でイントロに歌はない） |
