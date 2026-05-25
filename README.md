# 3-mapapa

Godot 4.6系で制作中の三人麻雀プロジェクト。

## MacBookで開く手順

1. Gitをインストールする。
2. Godot 4.6.2 stableをインストールする。
3. 任意の作業フォルダでcloneする。

```bash
git clone https://github.com/NB0129/3-mapapa.git
cd 3-mapapa
```

4. Godotを起動し、`project.godot` をインポートして開く。
5. 初回起動時に `.godot/` と各種 `.import` キャッシュがMac側で再生成されるのを待つ。
6. `Main.tscn` または通常起動で動作確認する。

## iPhone実機確認の準備

iOS実機確認の詳細は [README_IOS.md](README_IOS.md) を参照。

現時点ではApple Developer Program加入、証明書作成、Provisioning Profile作成は行わない。
