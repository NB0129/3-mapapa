# iOS実機テスト準備メモ

このメモは、Apple Developer Programへ加入する前にできる準備と、加入後または無料Apple IDでXcode実機実行へ進む時の手順をまとめる。

## 現在の方針

- ゲーム本体の基準解像度は `1920x1080` のまま維持する。
- iPhone縦画面では、GodotのStretch設定で16:9ゲーム画面全体を縦長画面内へ収める。
- 画面上部のノッチ / Dynamic Islandとは距離ができるため、現状のUIは直接被りにくい。
- 縦画面いっぱいを使う専用UIは、将来の別作業として扱う。

## Project Settings

`project.godot` の主なiOS向け準備:

- `display/window/size/viewport_width=1920`
- `display/window/size/viewport_height=1080`
- `display/window/stretch/mode="canvas_items"`
- `display/window/stretch/aspect="keep"`
- `display/window/handheld/orientation=1`

`aspect="keep"` にしているため、縦長iPhoneではゲーム画面が丸ごと縮小表示される。画面外にはみ出しにくく、ノッチやDynamic Islandにも被りにくいが、縦画面専用レイアウトより表示は小さくなる。

## タッチ入力

- 通常の `Button.pressed` はGodotのControl入力に任せる。
- 手牌、メンツ選択、デバッグパネルなど、自前で `gui_input` を見ている箇所は `InputEventMouseButton` と `InputEventScreenTouch` の両方を受ける。
- `input_devices/pointing/emulate_mouse_from_touch=false` として、タッチと擬似マウスの二重発火を避ける。

## 牌のタップ判定

プレイヤー手牌は仮想解像度上で `128x176`。iPhone縦画面で16:9全体を収めた場合でも、おおむね横幅70px前後のタップ領域になる想定。

今後実機で見るポイント:

- 手牌の1枚選択が誤タップしないか。
- リーチ宣言牌の2回タップ操作が小さすぎないか。
- アクションボタンが指で押しやすいか。
- デバッグパネルは開発用なので、必要ならiPad/横画面前提にする。

## リーチカットイン

カットインも `1920x1080` 基準で作っている。Stretchの `keep` により、iPhone縦画面では演出全体が縮小表示されるため、画面外にはみ出しにくい。

実機確認ポイント:

- キャラ画像が帯の中で見切れすぎていないか。
- リーチ棒の着地点が卓上リーチ棒置き場に見えるか。
- 3秒演出がスマホ画面で長すぎないか。

## iOS Export Preset

`export_presets.cfg` にはiOS presetを用意済み。

- Platform: iOS
- Export Project Only: 有効
- Export Path: `../iOSBuild/mapapa.ipa`
- Bundle Identifier: `com.nb0129.mapapa3`
- Target Device Family: iPhone & iPad（iPhone実機確認用にiPhoneを含める）
- Team ID: `J9PMYUQB9V`
- Code Sign Identity / Provisioning Profile: 未設定

Provisioning Profileは未設定のため、Xcode側で無料Apple IDまたは加入後のTeamを選ぶ。

`Export Project` で書き出す場合、`export_path` のファイル名部分はXcodeプロジェクト名のベースとして使われる。`.xcodeproj` を含めると、Godotがアプリ本体フォルダを `mapapa.xcodeproj`、実際のXcodeプロジェクトを `mapapa.xcodeproj.xcodeproj` として生成してしまい、間違って前者を開くと `project.pbxproj` が無い壊れたプロジェクトに見える。

正常な書き出し結果:

- `../iOSBuild/mapapa/` ... アプリ本体用ファイル
- `../iOSBuild/mapapa.xcodeproj/project.pbxproj` ... Xcodeで開くプロジェクト
- `../iOSBuild/mapapa.pck`
- `../iOSBuild/mapapa.xcframework`

Xcode側の `TARGETED_DEVICE_FAMILY` は `1,2` になり、iPhone実機とiPadの両方を対象にする。

現在の確認結果:

- Godot 4.6.3 stableから `iOS` presetは認識される。
- このMacには `~/Library/Application Support/Godot/export_templates/4.6.3.stable/ios.zip` が導入済み。
- `ios.zip` 内に `godot_apple_embedded.xcodeproj/project.pbxproj` が含まれていることを確認済み。

## 無料Apple IDで実機実行する流れ

1. macOSにGodot 4.6系とXcodeを入れる。
2. GodotのiOS export templateをインストールする。
3. Godotで `Project > Export` を開き、iOS presetを選ぶ。
4. `Export Project` でXcodeプロジェクトを書き出す。
5. Xcodeで書き出した `.xcodeproj` を開く。
6. `Signing & Capabilities` で自分のApple IDのPersonal Teamを選ぶ。
7. Bundle Identifierが重複する場合は、末尾に自分用の文字列を足す。
8. iPhoneをUSB接続し、XcodeからRunする。
9. iPhone側で開発元を信頼する必要がある場合は、iOS設定から信頼する。

無料Apple IDでは、実機インストールの有効期限や利用できる機能に制限がある。App Store配布やTestFlightはApple Developer Program加入後に行う。

## 加入後に確認すること

- 正式な Team ID を `export_presets.cfg` またはGodot Export画面で設定する。
- App ID / Bundle ID をApple Developerサイトで登録する。
- 自動署名を使う場合はXcode側で `Automatically manage signing` を有効にする。
- App Store用アイコン、表示名、バージョン番号、プライバシー項目を埋める。
- 実機でSafe Area、音量、タップ判定、負荷、発熱を確認する。
