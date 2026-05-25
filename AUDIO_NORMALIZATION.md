# 音源正規化ルール

## 2026-05-25 音源形式ルール

- BGM / ボイス / 長めのSEは `.ogg`（Vorbis, `-c:a libvorbis -q:a 5`）を標準にする。
- `.wav` は遅延を避けたいごく短いSEだけに限定する。
- 現行のWAV例外は `se/wav/yakuhyouji.wav` のみ。
- OGGへ変換した元 `.wav` と対応する `.wav.import` は削除する。

新しい音源を追加した時は、実装完了前に既存音源と同じ基準でラウドネス正規化する。

## 対象

- `se/` 以下の効果音・NPCボイス
- `BGM/` 以下のBGM
- `assets/bgm/` 以下のBGM

## 基準

- SE / ボイス: `loudnorm=I=-16:TP=-1.0:LRA=11`
- BGM: `loudnorm=I=-20:TP=-1.5:LRA=11`

SEやボイスは聞き取りやすさを優先して少し大きめ、BGMはゲーム中に邪魔になりすぎないよう少し控えめにする。

## 形式

- `.ogg` は Vorbis で出力する: `-c:a libvorbis -q:a 5`
- `.wav` は Godot が確実に読み込める形式にする: `-ar 44100 -c:a pcm_s16le`
- 拡張子は原則維持する。ユーザーから変換指示がある場合だけ変更する。
- NPCリーチBGMなど、ユーザーが「oggに変換して使う」と指定した `.wav` は `.ogg` に変換し、元 `.wav` と `.wav.import` は削除する。

## 実行例

ffmpeg がない場合は一時ディレクトリへ入れる。

```powershell
npm --prefix $env:TEMP\mapapa-ffmpeg install @ffmpeg-installer/ffmpeg
$ffmpeg = "$env:TEMP\mapapa-ffmpeg\node_modules\@ffmpeg-installer\win32-x64\ffmpeg.exe"
```

SE / ボイスの `.wav` を正規化する例。

```powershell
& $ffmpeg -y -i "input.wav" -af "loudnorm=I=-16:TP=-1.0:LRA=11" -ar 44100 -c:a pcm_s16le "input.normalized.wav"
Move-Item -Force "input.normalized.wav" "input.wav"
```

BGMの `.ogg` を正規化する例。

```powershell
& $ffmpeg -y -i "input.ogg" -af "loudnorm=I=-20:TP=-1.5:LRA=11" -c:a libvorbis -q:a 5 "input.normalized.ogg"
Move-Item -Force "input.normalized.ogg" "input.ogg"
```

一括処理する場合も、正規化用の一時ファイルを残さない。

## 確認

正規化後は Godot の import を更新し、最低限 `Game.tscn` のヘッドレス起動を確認する。

```powershell
& 'C:\Users\hskst\OneDrive\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\hskst\work\3-mapapa' --editor --quit
& 'C:\Users\hskst\OneDrive\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\hskst\work\3-mapapa' --scene res://Game.tscn --quit-after 2
```

終了時に ObjectDB や Resource の警告が出ることはある。終了コードが 0 で、音源 import エラーがなければよい。
