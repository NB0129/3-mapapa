# 修正指示書
## 対象ファイル: SanmaAnalyzer.gd / SimulatorScreen.gd / GameLogViewerScreen.gd

---

## 修正の概要

1. `chip_value`（手牌内チップの固定表示）を廃止
2. `expected_chip_value`（チップ込み期待値）を追加
3. テンパイ・1シャンテンで期待値を計算、2シャンテン以上は `—`
4. 期待値計算に「見えている牌（捨て牌・副露）」を考慮する `dead_tiles` を導入
5. SimulatorScreen に残り山枚数入力欄と dead_tiles 入力UIを追加
6. GameLogViewerScreen で dead_tiles を自動収集してシミュレーターに渡す

---

## 1. SanmaAnalyzer.gd の修正

### 1-1. 定数追加

```gdscript
# デッキ内の赤・金の総枚数
const TILE_RED_TOTAL: Dictionary  = {25: 2, 35: 2, 44: 1}  # 5p赤×2, 5s赤×2, 北赤×1
const TILE_GOLD_TOTAL: Dictionary = {28: 1, 38: 1}          # 8p金×1, 8s金×1
```

### 1-2. dead_tiles の構造（全ファイル共通）

```gdscript
# dead_tiles: Dictionary
# {
#   "counts": {game_id: 合計切れ枚数},   # 全牌対象
#   "red":    {game_id: 赤の切れ枚数},   # 5p/5s/北のみ
#   "gold":   {game_id: 金の切れ枚数},   # 8p/8sのみ
# }
# ※ 省略時は全て空辞書とみなす
```

### 1-3. evaluate_discards のシグネチャ変更

```gdscript
# 変更前
func evaluate_discards(hand: Array) -> Array

# 変更後
func evaluate_discards(hand: Array, total_wall: int = 61, dead_tiles: Dictionary = {}) -> Array
```

返り値の各辞書から `chip_value` を削除し、代わりに以下を追加：
```gdscript
"expected_chip_value": int,   # チップ込み期待値（点棒換算）。計算不能時は -1
```

### 1-4. _calc_effective_tiles の修正

wall_count を dead_tiles.counts を考慮して計算する：

```gdscript
func _calc_effective_tiles(counts: Array, shanten: int, dead_tiles: Dictionary = {}) -> Dictionary:
    var dead_counts: Dictionary = dead_tiles.get("counts", {})
    var effective: Dictionary = {}
    for idx in range(NUM_TYPES):
        var game_id := _IDX_TO_GAME_ID[idx]
        var dead := int(dead_counts.get(game_id, 0))
        var wall_count := DECK_SIZE - counts[idx] - dead
        if wall_count <= 0:
            continue
        counts[idx] += 1
        if calc_shanten(counts) < shanten:
            effective[game_id] = wall_count
        counts[idx] -= 1
    return effective
```

### 1-5. 期待チップ価値の計算（新規関数）

```gdscript
# ある有効牌を1枚引いた時の「その牌がチップ牌である確率×チップ価値」
func _chip_per_draw(game_id: int, counts_idx: int, dead_tiles: Dictionary) -> float:
    var dead_counts: Dictionary = dead_tiles.get("counts", {})
    var dead_red: Dictionary    = dead_tiles.get("red", {})
    var dead_gold: Dictionary   = dead_tiles.get("gold", {})
    var total_remaining := DECK_SIZE - counts_idx - int(dead_counts.get(game_id, 0))
    if total_remaining <= 0:
        return 0.0
    var value := 0.0
    if TILE_RED_TOTAL.has(game_id):
        var red_remaining := TILE_RED_TOTAL[game_id] - int(dead_red.get(game_id, 0))
        value += (float(maxi(0, red_remaining)) / total_remaining) * CHIP_RED
    if TILE_GOLD_TOTAL.has(game_id):
        var gold_remaining := TILE_GOLD_TOTAL[game_id] - int(dead_gold.get(game_id, 0))
        value += (float(maxi(0, gold_remaining)) / total_remaining) * CHIP_GOLD
    return value


# 期待チップ価値のメイン計算
func _calc_expected_chip(
    counts    : Array,
    shanten   : int,
    effective : Dictionary,  # {game_id: wall_count}
    total_wall: int,
    dead_tiles: Dictionary
) -> int:
    if total_wall <= 0:
        return -1

    # テンパイ時
    if shanten == 0:
        # 有効牌を引いた時のチップ期待値を枚数加重平均で計算
        var chip_sum := 0.0
        var eff_total := 0
        for cnt in effective.values():
            eff_total += int(cnt)
        if eff_total == 0:
            return 0
        for game_id: int in effective:
            var w := int(effective[game_id])
            var idx := _GAME_ID_TO_IDX.get(game_id, -1)
            if idx < 0:
                continue
            chip_sum += float(w) * _chip_per_draw(game_id, counts[idx], dead_tiles)
        var avg_chip := chip_sum / eff_total
        # 手牌内の既存チップ牌の価値（テンパイなので和了時に確実に得る）
        var hand_chip := 0.0
        for i in range(NUM_TYPES):
            if counts[i] <= 0:
                continue
            var gid := _IDX_TO_GAME_ID[i]
            if TILE_RED_TOTAL.has(gid) or TILE_GOLD_TOTAL.has(gid):
                hand_chip += _chip_per_draw(gid, counts[i], dead_tiles) * counts[i]
        # 和了確率
        var turns := ceili(float(total_wall) / 3.0)
        var p_win := 1.0 - pow(float(total_wall - eff_total) / float(total_wall), turns)
        return int((hand_chip + avg_chip) * p_win)

    # 1シャンテン時
    if shanten == 1:
        var p_chip_total := 0.0
        for game_id: int in effective:
            var w_t := int(effective[game_id])
            if w_t <= 0 or total_wall <= 0:
                continue
            var p_draw := float(w_t) / float(total_wall)
            var idx := _GAME_ID_TO_IDX.get(game_id, -1)
            if idx < 0:
                continue
            counts[idx] += 1
            var new_shanten := calc_shanten(counts)
            var remaining_wall := total_wall - 1
            if new_shanten == 0 and remaining_wall > 0:
                var new_eff := _calc_effective_tiles(counts, 0, dead_tiles)
                var e2 := 0
                for cnt in new_eff.values():
                    e2 += int(cnt)
                e2 = mini(e2, remaining_wall)
                var turns2 := ceili(float(remaining_wall) / 3.0)
                var p_tsumo := 1.0 - pow(float(remaining_wall - e2) / float(remaining_wall), turns2)
                # 引いた牌のチップ価値 + 手牌内チップ価値
                var chip_val := _chip_per_draw(game_id, counts[idx] - 1, dead_tiles)
                p_chip_total += p_draw * p_tsumo * chip_val
            counts[idx] -= 1
        return int(p_chip_total)

    # 2シャンテン以上は計算不能
    return -1
```

### 1-6. evaluate_discards 内の呼び出し修正

```gdscript
var effective  := _calc_effective_tiles(counts, shanten, dead_tiles)
# ... eff_count の集計は同じ ...
var expected_chip := _calc_expected_chip(counts, shanten, effective, total_wall, dead_tiles)

results.append({
    "tile_id"             : tile_id,
    "tile_name"           : MahjongLogic.get_tile_name(tile),
    "shanten"             : shanten,
    "shanten_text"        : _shanten_to_text(shanten),
    "effective_tiles"     : effective,
    "effective_count"     : eff_count,
    "expected_chip_value" : expected_chip,  # -1 = 計算不能
})
```

---

## 2. SimulatorScreen.gd の修正

### 2-1. static変数追加

```gdscript
static var initial_dead_tiles: Dictionary = {}   # 牌譜から渡される場合
static var initial_total_wall: int = 61          # 牌譜から渡される場合
```

### 2-2. 内部変数追加

```gdscript
var _dead_tiles: Dictionary = {}   # {counts:{}, red:{}, gold:{}}
var _total_wall: int = 61
var _wall_spinbox: SpinBox
```

### 2-3. 手牌入力エリアへのUI追加

`_build_input_area()` 内、解析ボタンの上に以下を追加：

**残り山枚数入力：**
```
残り山: [SpinBox 1〜61 デフォルト61]
```

**捨て牌・枚数設定（折りたたみ可能パネル）：**
```
[ ▶ 見えている牌 ]  ← ボタンで展開/折りたたみ

展開時:
  特殊牌（赤・金を個別入力）
  ┌─────────────────────────────────────────┐
  │ 5筒   [通常] [-] 0 [+]  [赤] [-] 0 [+] │
  │ 8筒   [通常] [-] 0 [+]  [金] [-] 0 [+] │
  │ 5索   [通常] [-] 0 [+]  [赤] [-] 0 [+] │
  │ 8索   [通常] [-] 0 [+]  [金] [-] 0 [+] │
  │ 北    [通常] [-] 0 [+]  [赤] [-] 0 [+] │
  └─────────────────────────────────────────┘
  その他の牌
  ┌─────────────────────────────────────────┐
  │ 1萬[-]0[+] 9萬[-]0[+] 1筒[-]0[+] ... │
  └─────────────────────────────────────────┘
  [リセット]
```

**入力制約：**
- 通常+赤（または通常+金）の合計が DECK_SIZE を超えないようにボタンを無効化
- 自分の手牌に入っている枚数分も引いた上限（手牌更新時にspinboxの上限も更新する）
- 1以上の値が入っている牌は数字を赤字表示

**dead_tiles 辞書の構築：**
```gdscript
func _build_dead_tiles() -> Dictionary:
    # UIの入力値から dead_tiles を構築して返す
    # counts / red / gold の各辞書を組み立てる
```

### 2-4. _run_analysis() の修正

```gdscript
func _run_analysis() -> void:
    var analyzer := SanmaAnalyzer.new()
    _dead_tiles = _build_dead_tiles()
    _total_wall = int(_wall_spinbox.value)
    _results = analyzer.evaluate_discards(_hand, _total_wall, _dead_tiles)
    _rebuild_result_list()
```

### 2-5. 結果行の表示変更

`chip_value` の表示を削除し、代わりに：
```gdscript
var exp_chip: int = r.get("expected_chip_value", -1)
if exp_chip > 0:
    var chip_lbl := _make_label("期待値 +%d pt" % exp_chip, Vector2(690, 24), 22)
    chip_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
    row_panel.add_child(chip_lbl)
elif exp_chip == 0:
    pass  # 表示なし
elif exp_chip == -1:
    var chip_lbl := _make_label("—", Vector2(690, 24), 20)
    chip_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    row_panel.add_child(chip_lbl)
```

### 2-6. 牌譜からの起動時の初期化

```gdscript
# _ready() の initial_hand 処理ブロック内に追加
if not initial_dead_tiles.is_empty():
    _dead_tiles = initial_dead_tiles
    initial_dead_tiles = {}
    # UIにも反映（各SpinBoxに値をセット）
    _apply_dead_tiles_to_ui(_dead_tiles)
if initial_total_wall > 0:
    _total_wall = initial_total_wall
    _wall_spinbox.value = initial_total_wall
    initial_total_wall = 61
```

---

## 3. GameLogViewerScreen.gd の修正

### 3-1. dead_tiles 収集関数の追加

```gdscript
func _build_dead_tiles_from_log(turns: Array, up_to_turn_idx: int) -> Dictionary:
    var counts := {}
    var red    := {}
    var gold   := {}
    var max_t := mini(up_to_turn_idx + 1, turns.size())
    for i in range(max_t):
        var t: Dictionary = turns[i]
        # 捨て牌
        var did: int = int(t.get("discard", -1))
        if did >= 0:
            counts[did] = counts.get(did, 0) + 1
            if bool(t.get("discard_is_red", false)):
                red[did] = red.get(did, 0) + 1
            if bool(t.get("discard_is_gold", false)):
                gold[did] = gold.get(did, 0) + 1
        # 副露牌（赤・金フラグは副露時の記録に含まれていないため counts のみ）
        var meld = t.get("meld", null)
        if meld != null and meld is Dictionary:
            var mid: int = int(meld.get("tile_id", -1))
            if mid >= 0:
                counts[mid] = counts.get(mid, 0) + 1
    return {"counts": counts, "red": red, "gold": gold}
```

### 3-2. 残り山枚数の計算

```gdscript
func _calc_remaining_wall(turns: Array, up_to_turn_idx: int) -> int:
    # 初期山 = 61枚
    # ツモ1回につき -1、カン補充は無視（簡易計算）
    var draws := 0
    var max_t := mini(up_to_turn_idx + 1, turns.size())
    for i in range(max_t):
        var t: Dictionary = turns[i]
        if int(t.get("draw", -1)) >= 0:
            draws += 1
    return maxi(1, 61 - draws)
```

### 3-3. シミュレーターパネル表示時に dead_tiles を渡す

現在の `_toggle_sim_panel()` または検討ボタン押下時の処理内で、
`SanmaAnalyzer.evaluate_discards()` を呼び出している箇所を以下に修正：

```gdscript
# 現在の局・ターンから dead_tiles と残り山を計算
var rounds: Array = _log.get("rounds", [])
var current_round: Dictionary = rounds[_round_idx]
var turns: Array = current_round.get("turns", [])
var dead_tiles := _build_dead_tiles_from_log(turns, _turn_idx)
var remaining_wall := _calc_remaining_wall(turns, _turn_idx)

# シミュレーター呼び出し
var analyzer := SanmaAnalyzer.new()
_sim_results = analyzer.evaluate_discards(hand_after_draw, remaining_wall, dead_tiles)
```

---

## 受け渡し手順

1. `SanmaAnalyzer.gd`、`SimulatorScreen.gd`、`GameLogViewerScreen.gd` の3ファイルをClaude Codeに渡す
2. この指示書（`CLAUDE_CODE_DIFF.md`）を渡す
3. 以下を伝える：

> この指示書に従って3ファイルを修正して。
> 既存コードのスタイル（_make_label / _make_button 等のヘルパー関数）はそのまま踏襲すること。
> GameLogViewerScreen.gd は途中が切れているが、シミュレーター呼び出し箇所（_toggle_sim_panelまたはSanmaAnalyzer.evaluate_discards を呼んでいる場所）を探して修正すること。

