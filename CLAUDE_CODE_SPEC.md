# 三麻シミュレーター＆牌譜機能 実装仕様書
## Claude Code向け引き継ぎドキュメント
## 最終更新: 2026-05-28
## 実装状況: **全タスク完了**（2026-05-28）

---

## 0. 前提・プロジェクト概要

- **エンジン**: Godot 4.6 / GDScript
- **画面**: 1920×1080 横画面固定
- **プロジェクト名**: 3-mapapa
- **オフライン動作**: すべての機能はオフライン完結
- **UIは全てGDスクリプトでコード生成**（.tscnにノードなし。既存シーンの流儀に合わせること）

### AutoLoad（既存・変更禁止）
1. AudioManager
2. MahjongLogic
3. GameState
4. SaveData

### 既存シーン構成
```
Main.tscn / main.gd
Title.tscn / title.gd
Menu.tscn / menu.gd
Game.tscn / game.gd
Result.tscn / result.gd
```

---

## 1. 牌の定義（既存コード MahjongLogic.gd に完全準拠）

### 牌ID
```
MAN_1=11, MAN_9=19
PIN_1=21, PIN_2=22, ..., PIN_9=29
SOU_1=31, SOU_2=32, ..., SOU_9=39
EAST=41, SOUTH=42, WEST=43, NORTH=44, HAKU=45, HATSU=46, CHUN=47
```

### 牌データ形式（Dictionary）
```gdscript
# MahjongLogic.make_tile() が返す形式
{
    "id": int,             # 上記牌ID
    "is_red": bool,        # 赤ドラ（5p×2, 5s×2, 北×1）
    "is_gold": bool,       # 金ドラ（8p×1, 8s×1）
    "is_haku_pochi": bool  # 白ポッチ（白×1）
}
```

### プレイヤーデータ形式（GameState.players[i]）
```gdscript
{
    "name": String,
    "is_npc": bool,
    "hand": Array,       # Dictionary配列（手牌）
    "discards": Array,   # Dictionary配列（捨て牌）
    "naki": Array,       # 副露情報
    "nukita": Array,     # 北抜き済み牌
    "is_riichi": bool,
    "score": int,
    ...
}
```

### チップ価値（点棒換算、ツモ両者払い）
| 条件 | チップ枚数 | 点棒換算 |
|------|-----------|---------|
| is_red = true（赤ドラ・赤北） | 1枚 | 10,000点 |
| is_gold = true（金ドラ） | 1枚 | 20,000点 |

---

## 2. 実装済みファイル：SanmaAnalyzer.gd

打牌効率分析ロジックは実装済み。以下のパスに配置すること。

```
res://scripts/analyzer/SanmaAnalyzer.gd
```

### 主要API

```gdscript
var analyzer := SanmaAnalyzer.new()

# 14枚手牌（Dictionary配列）から打牌評価
var results: Array = analyzer.evaluate_discards(GameState.players[0].hand)

# 返り値の各要素（Dictionary）：
# {
#   "tile_id"        : int,        # 打牌する牌のゲームID（例: 25 = 5p）
#   "tile_name"      : String,     # MahjongLogic.get_tile_name()と同じ（例: "5筒(赤)"）
#   "shanten"        : int,        # 打牌後向聴数（0=テンパイ）
#   "shanten_text"   : String,     # 例: "テンパイ" / "イーシャンテン"
#   "effective_tiles": Dictionary, # {牌ゲームID: 残り枚数上限}
#   "effective_count": int,        # 有効牌総枚数
#   "chip_value"     : int,        # 残手牌のチップ価値（点棒換算）
# }

# 有効牌の表示名リスト取得（UI表示用）
var names: Array[String] = analyzer.get_effective_tile_names(results[0].effective_tiles)
# → ["1筒×4", "4筒×4", "8筒(金)×3", ...]
```

### 重要な注意点
- 入力は `MahjongLogic.make_tile()` 形式の Dictionary 配列（14枚）
- 北（NORTH=44）が手牌に含まれる場合でも動作する（北は孤立牌として扱われる）
- 有効牌の残り枚数は `4 - 手牌内枚数` の簡易計算（他家手牌・河は考慮しない）
- 七対子は4枚七対子対応（同牌4枚=対子2つ分）
- 国士無双は対象外

---

## 3. シミュレーター専用画面

### 3-1. 新規ファイル

```
res://scenes/simulator/SimulatorScreen.tscn
res://scripts/simulator/SimulatorScreen.gd
```

### 3-2. 画面構成

```
SimulatorScreen（CanvasLayer または FullRect）
├── Header
│   ├── Label "打牌シミュレーター"
│   └── BackButton（メニューへ戻る）
├── HandInputArea（手牌入力エリア）
│   ├── HandDisplay（入力済み手牌・14枚まで）
│   │   └── TileButton×n（タップで入力取り消し）
│   ├── TilePalette（牌選択パレット）
│   │   ├── TabBar（萬子 / 筒子 / 索子 / 字牌）
│   │   └── TileButtonGrid（選択可能な牌ボタン一覧）
│   └── ClearButton（手牌リセット）
├── AnalyzeButton（「解析する」ボタン・14枚揃ったら有効化）
└── ResultArea（解析結果エリア、初期非表示）
    ├── ResultList（打牌候補リスト・スクロール可能）
    │   └── ResultRow × n
    └── EffectiveTileDetail（選択行の有効牌詳細・初期非表示）
```

### 3-3. ResultRow の表示内容

各行に以下を横並びで表示：

```
[★] [5筒(赤)]  テンパイ    有効牌 32枚    +10,000pt
    [7筒    ]  テンパイ    有効牌 28枚    +0pt
    [3筒    ]  イーシャンテン  有効牌 24枚  +0pt
```

- 最良打牌（results[0]）には ★ マーク＋背景ハイライト
- chip_value > 0 の行には点棒換算値を表示

### 3-4. 牌パレット仕様

| タブ | 表示する牌 |
|------|-----------|
| 萬子 | 1m, 9m のみ |
| 筒子 | 1p〜9p（5pは「5p通常」と「5p赤」の2ボタン、8pは「8p通常」と「8p金」の2ボタン） |
| 索子 | 1s〜9s（5sは「5s通常」と「5s赤」の2ボタン、8sは「8s通常」と「8s金」の2ボタン） |
| 字牌 | 東・南・西・北・白・発・中 |

牌の作成は `MahjongLogic.make_tile(id, is_red, is_gold)` を使う。

### 3-5. 操作フロー

1. パレットから牌をタップ → HandDisplay に追加（最大14枚）
2. 同じIDの牌は手牌内の現在枚数に応じてボタンを無効化（4枚上限）
3. 14枚揃ったら AnalyzeButton が有効化（14枚未満では無効）
4. 解析ボタン押下で `analyzer.evaluate_discards(hand)` 実行
5. ResultList に結果表示（最良順）
6. ResultRow タップで EffectiveTileDetail を展開

---

## 4. 牌譜機能

### 4-1. 新規ファイル

```
res://scripts/gamelog/GameLogRecorder.gd   # 記録クラス
res://scripts/gamelog/GameLogStorage.gd    # 保存・読み込みクラス
res://scenes/gamelog/GameLogListScreen.tscn
res://scripts/gamelog/GameLogListScreen.gd
res://scenes/gamelog/GameLogViewerScreen.tscn
res://scripts/gamelog/GameLogViewerScreen.gd
```

### 4-2. 牌譜データ構造（JSON保存）

```json
{
  "version": 1,
  "game_id": "20260527_193000",
  "date": "2026-05-27T19:30:00",
  "players": [
    { "name": "プレイヤー名", "is_npc": false, "npc_id": "" },
    { "name": "くまぱぱ",   "is_npc": true,  "npc_id": "kuma_def" },
    { "name": "眼鏡くま",   "is_npc": true,  "npc_id": "kuma_megane" }
  ],
  "final_scores": [42000, 28000, 30000],
  "final_chips": [3, -1, -2],
  "rounds": [ ...RoundLog... ]
}
```

```json
// RoundLog
{
  "wind": 41,       // 場風の牌ID（EAST=41, SOUTH=42）
  "kyoku": 1,       // 局番
  "honba": 0,
  "dealer": 0,      // 親プレイヤーのインデックス（players配列の番号）
  "initial_scores": [35000, 35000, 35000],
  "turns": [ ...TurnLog... ],
  "result": { ...RoundResult... }
}
```

```json
// TurnLog
{
  "player": 0,          // プレイヤーインデックス
  "draw": 25,           // ツモ牌のゲームID（-1=なし、北抜き補充後なども記録）
  "draw_is_red": false, // ツモ牌の赤フラグ
  "draw_is_gold": false,// ツモ牌の金フラグ
  "hand_after_draw": [  // ツモ後14枚（プレイヤー=人間のみ記録、NPCは[]）
    { "id": 25, "is_red": false, "is_gold": false, "is_haku_pochi": false },
    ...
  ],
  "discard": 22,        // 打牌のゲームID
  "discard_is_red": false,
  "discard_is_gold": false,
  "is_riichi": false,
  "is_kita": false,     // 北抜きターンの場合true（drawが-1のことも）
  "meld": null          // ポン/カン等があった場合 MeldLog
}
```

```json
// MeldLog
{
  "type": "pon",          // "pon" | "ankan" | "minkan" | "kakan"
  "tile_id": 41,          // 鳴いた牌のID
  "from_player": 1        // 鳴き元プレイヤーインデックス（暗槓は-1）
}
```

```json
// RoundResult
{
  "type": "tsumo",        // "tsumo" | "ron" | "draw" | "chombo"
  "winner": 0,            // -1=流局
  "loser": -1,            // ツモ・流局は-1
  "winning_hand": [       // 和了手牌（牌IDリスト、和了牌含む）
    { "id": 25, "is_red": true, ... }, ...
  ],
  "winning_tile_id": 25,
  "yaku": ["門前清自摸和", "リーチ"],
  "han": 3,
  "score_changes": [4000, -1000, -3000]
}
```

### 4-3. GameLogRecorder クラス

```gdscript
# res://scripts/gamelog/GameLogRecorder.gd
class_name GameLogRecorder
extends RefCounted

func start_game(players_data: Array) -> void
# players_data: GameState.players 配列をそのまま渡す

func start_round(wind: int, kyoku: int, honba: int, dealer: int, scores: Array) -> void

func record_draw(player: int, tile: Dictionary, hand_after_draw: Array) -> void
# hand_after_draw: プレイヤー（is_npc=false）のみ14枚を渡す。NPCは[]でよい

func record_kita(player: int, kita_tile: Dictionary, hand_after_draw: Array) -> void
# 北抜き記録（draw=-1のTurnLogとして記録）

func record_discard(player: int, tile: Dictionary, is_riichi: bool) -> void

func record_meld(player: int, meld_type: String, tile_id: int, from_player: int) -> void

func end_round(result: Dictionary) -> void
# result: GameState の局終了時に構築する辞書

func end_game(final_scores: Array, final_chips: Array) -> String
# 保存してファイルパスを返す
```

### 4-4. GameLogStorage クラス

```gdscript
# res://scripts/gamelog/GameLogStorage.gd
class_name GameLogStorage
extends RefCounted

const SAVE_DIR := "user://gamelogs/"

func save(log_data: Dictionary) -> String        # → ファイルパス
func list_logs() -> Array[Dictionary]            # 新しい順。各要素は概要情報のみ
func load_log(path: String) -> Dictionary        # フル読み込み
func delete_log(path: String) -> void
```

保存ファイル名: `user://gamelogs/YYYYMMDD_HHMMSS.json`

### 4-5. 既存コードへの組み込みポイント（GameState.gd）

以下のタイミングで `_recorder` を呼び出す。`_recorder` は GameState の変数として持つ。

```gdscript
# GameState.gd に追記する変数
var _recorder: GameLogRecorder = null

# start_match() の末尾に追加
func start_match() -> void:
    ...既存処理...
    _recorder = GameLogRecorder.new()
    _recorder.start_game(players)

# _start_kyoku() の末尾に追加
func _start_kyoku() -> void:
    ...既存処理...
    _recorder.start_round(round_wind, kyoku, honba, dealer,
        players.map(func(p): return p.score))

# _do_draw() 内のツモ処理後に追加
# ※ プレイヤーのツモ後14枚を hand_after_draw として渡す
_recorder.record_draw(player_idx, drawn_tile,
    players[player_idx].hand if not players[player_idx].is_npc else [])

# _do_kita() 内の北抜き後に追加
_recorder.record_kita(player_idx, kita_tile,
    players[player_idx].hand if not players[player_idx].is_npc else [])

# _do_discard() 内の打牌処理後に追加
_recorder.record_discard(player_idx, discarded_tile, is_riichi)

# _do_pon() / _do_ankan() / _do_minkan() / _do_kakan() 後に追加
_recorder.record_meld(player_idx, meld_type, tile_id, from_player)

# _end_kyoku() の局結果確定後に追加
_recorder.end_round(result_dict)

# _end_match() の精算確定後に追加
var path = _recorder.end_game(
    players.map(func(p): return p.score),
    player_chips
)
```

---

## 5. 牌譜閲覧画面

### 5-1. 一覧画面（GameLogListScreen）

```
GameLogListScreen
├── Header（"牌譜" ラベル・閉じるボタン）
└── ScrollContainer
    └── VBoxContainer
        └── LogEntryPanel × n（各牌譜行）
            ├── Label: 日時（例: "2026/05/27 19:30"）
            ├── Label: プレイヤー vs NPC1 vs NPC2
            ├── Label: 最終スコア / チップ収支
            └── Button "詳細" → GameLogViewerScreen へ遷移（パスを渡す）
```

### 5-2. 閲覧画面（GameLogViewerScreen）

```
GameLogViewerScreen
├── Header（日時 / 閉じるボタン）
├── RoundTab（局選択タブ: "東1局" "東2局" ...）
├── ReplayArea
│   ├── InfoBar（"東1局 3巡目　右家ツモ: 5筒" など）
│   ├── PlayerHandView（プレイヤーの現在手牌・タップでシミュレーター起動）
│   │   └── TileButton × 手牌枚数
│   ├── DiscardPileView（3者の捨て牌）
│   └── MeldView（副露・北抜き表示）
├── NavigationBar
│   ├── Button "◀" （1手戻る）
│   ├── Button "▶" （1手進む）
│   ├── Slider（局内ターン位置）
│   └── Button "🔍 検討" → SimulatorPanel 表示
└── SimulatorPanel（初期非表示・下部オーバーレイ）
```

### 5-3. シミュレーター連携の動作

**発動条件**: 現在のリプレイ位置が「プレイヤーのツモ後（hand_after_draw が14枚）」の場合のみ有効

**動作手順**:
1. ユーザーが「🔍 検討」ボタンまたはプレイヤー手牌の牌をタップ
2. `SimulatorPanel` が表示される
3. `TurnLog.hand_after_draw`（14枚）を `SanmaAnalyzer.evaluate_discards()` に渡す
4. 結果を SimulatorPanel に表示
5. **実際に切った牌**（`TurnLog.discard`）を結果リスト内でハイライト表示
6. 最善打牌と実際の打牌が違う場合は差分情報を表示
   - 例: "実際: 3筒（有効牌24枚）　最善: 7筒（有効牌32枚）　差 -8枚"

### 5-4. SimulatorPanel 表示レイアウト（牌譜閲覧内埋め込み版）

```
┌──────────────────────────────────────────┐
│ 東1局 3巡目  ツモ: 5筒(赤)               │
│ ────────────────────────────────────── │
│  打牌         向聴      有効牌  チップ価値 │
│ ★ 7筒      テンパイ    32枚   +0        │
│   5筒(赤)  テンパイ    28枚   +10,000   │
│ → 3筒      イーシャン  24枚   +0  ←実際 │  ← 実際の打牌をハイライト
│ ────────────────────────────────────── │
│ 7筒 を切った場合の有効牌:                 │
│   1筒×4  4筒×4  7筒×3  8筒(金)×3 ...  │
└──────────────────────────────────────────┘
```

---

## 6. 推奨ファイル構成

```
res://
├── scripts/
│   ├── analyzer/
│   │   └── SanmaAnalyzer.gd        ★実装済み
│   ├── simulator/
│   │   └── SimulatorScreen.gd      ← 新規
│   └── gamelog/
│       ├── GameLogRecorder.gd      ← 新規
│       ├── GameLogStorage.gd       ← 新規
│       ├── GameLogListScreen.gd    ← 新規
│       └── GameLogViewerScreen.gd  ← 新規
├── scenes/
│   ├── simulator/
│   │   └── SimulatorScreen.tscn    ← 新規
│   └── gamelog/
│       ├── GameLogListScreen.tscn  ← 新規
│       └── GameLogViewerScreen.tscn ← 新規
└── autoload/
    ├── MahjongLogic.gd             ★既存・変更禁止
    ├── GameState.gd                ★既存・_recorderの追加のみ
    ├── GameState_gd.uid            ★既存・変更禁止
    └── SaveData.gd                 ★既存・変更禁止
```

---

## 7. 実装優先順位

| 順番 | タスク | 備考 |
|------|--------|------|
| 1 | SanmaAnalyzer.gd を配置して動作確認 | ✅ 完了（既存） |
| 2 | SimulatorScreen 実装 | ✅ 完了 |
| 3 | GameLogRecorder 実装 | ✅ 完了 |
| 4 | GameLogStorage 実装 | ✅ 完了 |
| 5 | GameState.gd に _recorder を組み込み | ✅ 完了 |
| 6 | GameLogListScreen 実装 | ✅ 完了 |
| 7 | GameLogViewerScreen 実装 | ✅ 完了（SimulatorPanel 込み） |
| 8 | menu.gd にシミュレーター・牌譜ボタン追加 | ✅ 完了 |

---

## 8. 留意事項

- `tscn` ファイルはノードなし。UIは全て `_ready()` 内でコード生成すること（既存シーンと同じ流儀）
- `MahjongLogic` / `GameState` / `SaveData` は AutoLoad のため `$` なしで直接参照可能
- 北（NORTH=44）は手牌に存在し得るが、シミュレーターでは孤立牌として扱う（既存の `_can_start_sequence` と同じ扱い）
- NPCの `hand_after_draw` は `[]`（空配列）で記録する。牌譜閲覧のシミュレーター機能はプレイヤーターンのみ
- 牌譜ファイルは `user://` 以下に保存（`DirAccess.make_dir_recursive_absolute()` でディレクトリ作成）
