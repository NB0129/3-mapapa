# SanmaAnalyzer.gd
# ==================================================
# 三麻（三人打ち麻雀）打牌効率分析クラス
#
# 【既存プロジェクトの牌ID体系に準拠】
#   MAN_1=11, MAN_9=19
#   PIN_1〜PIN_9 = 21〜29
#   SOU_1〜SOU_9 = 31〜39
#   EAST=41, SOUTH=42, WEST=43, NORTH=44, HAKU=45, HATSU=46, CHUN=47
#
# 【入力形式】
#   MahjongLogic.make_tile() が返す Dictionary の配列（14枚）
#   例: [{id:25, is_red:true, is_gold:false, ...}, ...]
#
# 【使用例】
#   var analyzer = SanmaAnalyzer.new()
#   var results = analyzer.evaluate_discards(GameState.players[0].hand)
#   for r in results:
#       print(r.tile_name, ": ", r.shanten_text, " 有効牌 ", r.effective_count, "枚")
# ==================================================

class_name SanmaAnalyzer
extends RefCounted

# --------------------------------------------------
# ゲームIDから内部インデックスへの変換テーブル
# （バックトラッキング用に連続した配列を使うため）
# --------------------------------------------------
const _GAME_ID_TO_IDX: Dictionary = {
	11: 0,                                           # 1m
	19: 1,                                           # 9m
	21: 2,  22: 3,  23: 4,  24: 5,  25: 6,          # 1p〜5p
	26: 7,  27: 8,  28: 9,  29: 10,                 # 6p〜9p
	31: 11, 32: 12, 33: 13, 34: 14, 35: 15,         # 1s〜5s
	36: 16, 37: 17, 38: 18, 39: 19,                 # 6s〜9s
	41: 20, 42: 21, 43: 22, 44: 23,                 # 東南西北
	45: 24, 46: 25, 47: 26                           # 白発中
}

const _IDX_TO_GAME_ID: Array[int] = [
	11, 19,
	21, 22, 23, 24, 25, 26, 27, 28, 29,
	31, 32, 33, 34, 35, 36, 37, 38, 39,
	41, 42, 43, 44, 45, 46, 47
]

const NUM_TYPES := 27
const DECK_SIZE := 4

# チップ価値（点棒換算・ツモ両者払い）
# is_red=true なら +10000、is_gold=true なら +20000
const CHIP_RED  := 10000
const CHIP_GOLD := 20000

# デッキ内の赤・金の総枚数
const TILE_RED_TOTAL: Dictionary  = {25: 2, 35: 2, 44: 1}  # 5p赤×2, 5s赤×2, 北赤×1
const TILE_GOLD_TOTAL: Dictionary = {28: 1, 38: 1}          # 8p金×1, 8s金×1

# --------------------------------------------------
# 内部変数
# --------------------------------------------------
var _best: int


# ==================================================
# パブリックAPI
# ==================================================

## 14枚手牌（Dictionary配列）を受け取り、各打牌の評価結果を返す。
## 返り値はソート済み（向聴数 → 有効牌枚数 → 期待チップ価値の優先順）。
##
## [return] 辞書の配列。各辞書のキー：
##   tile_id              : 打牌する牌のゲームID（例: 25 = 5p）
##   tile_name            : 表示名（例: "5筒(赤)"）
##   shanten              : 打牌後の向聴数（0=テンパイ）
##   shanten_text         : 向聴数テキスト（例: "テンパイ"）
##   effective_tiles      : 有効牌 { ゲームID: 残り枚数上限 }
##   effective_count      : 有効牌の総枚数
##   expected_chip_value  : チップ込み期待値（点棒換算）。計算不能時は -1
func evaluate_discards(hand: Array, total_wall: int = 61, dead_tiles: Dictionary = {}) -> Array:
	assert(hand.size() == 14, "手牌は14枚である必要があります")

	var results: Array = []
	var evaluated: Dictionary = {}  # 同じIDの重複打牌を省略

	for i in range(14):
		var tile: Dictionary = hand[i]
		var tile_id: int = tile.id

		# 同じIDの牌は代表1枚だけ評価
		if evaluated.has(tile_id):
			continue
		evaluated[tile_id] = true

		# i枚目を除いた13枚を解析
		var remaining := hand.duplicate()
		remaining.remove_at(i)

		var counts        := _to_counts(remaining)
		var shanten       := calc_shanten(counts)
		var effective     := _calc_effective_tiles(counts, shanten, dead_tiles)
		var eff_count     := 0
		for cnt: int in effective.values():
			eff_count += cnt
		var expected_chip := _calc_expected_chip(counts, shanten, effective, total_wall, dead_tiles)

		results.append({
			"tile_id"            : tile_id,
			"tile_name"          : MahjongLogic.get_tile_name(tile),
			"shanten"            : shanten,
			"shanten_text"       : _shanten_to_text(shanten),
			"effective_tiles"    : effective,
			"effective_count"    : eff_count,
			"expected_chip_value": expected_chip,
		})

	# ソート：向聴数（昇順）→ 有効牌枚数（降順）→ 期待チップ価値（降順）
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.shanten != b.shanten:
			return a.shanten < b.shanten
		if a.effective_count != b.effective_count:
			return a.effective_count > b.effective_count
		return a.expected_chip_value > b.expected_chip_value
	)
	return results


## 向聴数のみ計算する（一般手と七対子の最小値）
## counts: _to_counts() が返す内部インデックス配列
func calc_shanten(counts: Array) -> int:
	return mini(_shanten_regular(counts), _shanten_chiitoi(counts))


## 有効牌の表示名リストを返す（UI表示用）
## 例: ["1筒×4", "4筒×4", "8筒(金)×3"]
func get_effective_tile_names(effective: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for game_id: int in effective:
		var dummy_tile := {"id": game_id, "is_red": false, "is_gold": false, "is_haku_pochi": false}
		names.append(MahjongLogic.get_tile_name(dummy_tile) + "×" + str(effective[game_id]))
	return names


# ==================================================
# 向聴数計算（一般手）
# ==================================================

func _shanten_regular(counts: Array) -> int:
	_best = 8
	_search(counts, 0, 0, 0, false)
	return _best


## バックトラッキングで最適な面子・搭子・雀頭の組み合わせを探索する。
## 公式: 向聴数 = 8 - 2×面子数 - min(搭子数, 4-面子数) - 雀頭有無(0or1)
func _search(
		counts    : Array,
		tile      : int,
		mentsu    : int,
		taatsu    : int,
		has_jantai: bool
) -> void:
	# 現在の構成で向聴数を評価・更新
	var j     := 1 if has_jantai else 0
	var eff_t := mini(taatsu, 4 - mentsu)
	var s     := 8 - 2 * mentsu - eff_t - j
	if s < _best:
		_best = s
	if s == -1:
		return  # 和了形確定

	# 次の非ゼロ牌を探す
	var t := tile
	while t < NUM_TYPES and counts[t] == 0:
		t += 1
	if t >= NUM_TYPES:
		return

	# ── 面子 ──────────────────────────────────────

	# 刻子 (aaa)
	if counts[t] >= 3:
		counts[t] -= 3
		_search(counts, t, mentsu + 1, taatsu, has_jantai)
		counts[t] += 3

	# 順子 (a, a+1, a+2) ─ 筒子・索子のみ
	if _can_seq(t) and counts[t + 1] >= 1 and counts[t + 2] >= 1:
		counts[t] -= 1; counts[t + 1] -= 1; counts[t + 2] -= 1
		_search(counts, t, mentsu + 1, taatsu, has_jantai)
		counts[t] += 1; counts[t + 1] += 1; counts[t + 2] += 1

	# ── 搭子 ──────────────────────────────────────

	# 雀頭候補 (aa)
	if not has_jantai and counts[t] >= 2:
		counts[t] -= 2
		_search(counts, t, mentsu, taatsu, true)
		counts[t] += 2

	# 対子搭子 (aa)
	if counts[t] >= 2:
		counts[t] -= 2
		_search(counts, t, mentsu, taatsu + 1, has_jantai)
		counts[t] += 2

	# 連続搭子 (a, a+1)
	if _can_adj(t) and counts[t + 1] >= 1:
		counts[t] -= 1; counts[t + 1] -= 1
		_search(counts, t, mentsu, taatsu + 1, has_jantai)
		counts[t] += 1; counts[t + 1] += 1

	# 嵌張搭子 (a, a+2)
	if _can_seq(t) and counts[t + 2] >= 1:
		counts[t] -= 1; counts[t + 2] -= 1
		_search(counts, t, mentsu, taatsu + 1, has_jantai)
		counts[t] += 1; counts[t + 2] += 1

	# 孤立：1枚スキップして同位置で再探索
	counts[t] -= 1
	_search(counts, t, mentsu, taatsu, has_jantai)
	counts[t] += 1


# ==================================================
# 向聴数計算（七対子）
# ==================================================

## 4枚七対子対応：同牌4枚 = 対子2つ分
## 向聴数 = 6 - 対子数（最大7）
func _shanten_chiitoi(counts: Array) -> int:
	var pairs := 0
	for i in range(NUM_TYPES):
		pairs += counts[i] / 2  # 整数除算: 4枚→2, 2枚→1
	pairs = mini(pairs, 7)
	return 6 - pairs


# ==================================================
# 有効牌計算
# ==================================================

## 現在の向聴数を下げる牌と残り枚数（dead_tiles考慮）を返す。
func _calc_effective_tiles(counts: Array, shanten: int, dead_tiles: Dictionary = {}) -> Dictionary:
	var dead_counts: Dictionary = dead_tiles.get("counts", {})
	var effective: Dictionary = {}
	for idx in range(NUM_TYPES):
		var game_id: int = _IDX_TO_GAME_ID[idx]
		var dead: int = int(dead_counts.get(game_id, 0))
		var wall_count: int = DECK_SIZE - int(counts[idx]) - dead
		if wall_count <= 0:
			continue
		counts[idx] += 1
		if calc_shanten(counts) < shanten:
			effective[game_id] = wall_count
		counts[idx] -= 1
	return effective


# ==================================================
# チップ期待値計算
# ==================================================

## ある有効牌を1枚引いたときの「チップ牌である確率×チップ価値」の期待値
func _chip_per_draw(game_id: int, counts_idx: int, dead_tiles: Dictionary) -> float:
	var dead_counts: Dictionary = dead_tiles.get("counts", {})
	var dead_red: Dictionary    = dead_tiles.get("red", {})
	var dead_gold: Dictionary   = dead_tiles.get("gold", {})
	var total_remaining: int = DECK_SIZE - counts_idx - int(dead_counts.get(game_id, 0))
	if total_remaining <= 0:
		return 0.0
	var value := 0.0
	if TILE_RED_TOTAL.has(game_id):
		var red_remaining: int = int(TILE_RED_TOTAL[game_id]) - int(dead_red.get(game_id, 0))
		value += (float(maxi(0, red_remaining)) / total_remaining) * CHIP_RED
	if TILE_GOLD_TOTAL.has(game_id):
		var gold_remaining: int = int(TILE_GOLD_TOTAL[game_id]) - int(dead_gold.get(game_id, 0))
		value += (float(maxi(0, gold_remaining)) / total_remaining) * CHIP_GOLD
	return value


## 打牌後の手牌に対するチップ込み期待値を計算する。
## テンパイ・1シャンテンのみ計算、2シャンテン以上は -1 を返す。
func _calc_expected_chip(
		counts    : Array,
		shanten   : int,
		effective : Dictionary,
		total_wall: int,
		dead_tiles: Dictionary
) -> int:
	if total_wall <= 0:
		return -1

	# テンパイ時
	if shanten == 0:
		var chip_sum := 0.0
		var eff_total := 0
		for cnt in effective.values():
			eff_total += int(cnt)
		if eff_total == 0:
			return 0
		for game_id: int in effective:
			var w: int = int(effective[game_id])
			var idx: int = _GAME_ID_TO_IDX.get(game_id, -1)
			if idx < 0:
				continue
			chip_sum += float(w) * _chip_per_draw(game_id, int(counts[idx]), dead_tiles)
		var avg_chip := chip_sum / eff_total
		var hand_chip := 0.0
		for i in range(NUM_TYPES):
			if int(counts[i]) <= 0:
				continue
			var gid: int = _IDX_TO_GAME_ID[i]
			if TILE_RED_TOTAL.has(gid) or TILE_GOLD_TOTAL.has(gid):
				hand_chip += _chip_per_draw(gid, int(counts[i]), dead_tiles) * int(counts[i])
		var turns: int = ceili(float(total_wall) / 3.0)
		var p_win := 1.0 - pow(float(total_wall - eff_total) / float(total_wall), turns)
		return int((hand_chip + avg_chip) * p_win)

	# 1シャンテン時
	if shanten == 1:
		var p_chip_total := 0.0
		for game_id: int in effective:
			var w_t: int = int(effective[game_id])
			if w_t <= 0 or total_wall <= 0:
				continue
			var p_draw := float(w_t) / float(total_wall)
			var idx: int = _GAME_ID_TO_IDX.get(game_id, -1)
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
				var turns2: int = ceili(float(remaining_wall) / 3.0)
				var p_tsumo := 1.0 - pow(float(remaining_wall - e2) / float(remaining_wall), turns2)
				var chip_val := _chip_per_draw(game_id, int(counts[idx]) - 1, dead_tiles)
				p_chip_total += p_draw * p_tsumo * chip_val
			counts[idx] -= 1
		return int(p_chip_total)

	# 2シャンテン以上は計算不能
	return -1


# ==================================================
# ユーティリティ
# ==================================================

## Dictionary配列 → 内部インデックス用カウント配列
func _to_counts(hand: Array) -> Array:
	var counts: Array = []
	counts.resize(NUM_TYPES)
	counts.fill(0)
	for tile: Dictionary in hand:
		var idx: int = _GAME_ID_TO_IDX.get(tile.id, -1)
		if idx >= 0:
			counts[idx] += 1
	return counts


## 内部インデックスtが順子・嵌張搭子の開始点として有効か
## （t, t+1, t+2 が同スートに存在する）
## 筒子 idx 2〜8（1p〜7p）、索子 idx 11〜17（1s〜7s）
func _can_seq(t: int) -> bool:
	return (t >= 2 and t <= 8) or (t >= 11 and t <= 17)


## 内部インデックスtが連続搭子の開始点として有効か
## （t, t+1 が同スートに存在する）
## 筒子 idx 2〜9（1p〜8p）、索子 idx 11〜18（1s〜8s）
func _can_adj(t: int) -> bool:
	return (t >= 2 and t <= 9) or (t >= 11 and t <= 18)


func _shanten_to_text(s: int) -> String:
	match s:
		0: return "テンパイ"
		1: return "イーシャンテン"
		2: return "リャンシャンテン"
		3: return "サンシャンテン"
		_: return str(s) + "向聴"
