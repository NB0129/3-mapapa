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


# --------------------------------------------------
# 内部変数
# --------------------------------------------------
var _best: int
var _shanten_cache: Dictionary = {}


# ==================================================
# パブリックAPI
# ==================================================

## 14枚手牌（Dictionary配列）を受け取り、各打牌の評価結果を返す。
## 返り値はソート済み（向聴数 → 有効牌枚数 → 和了率の優先順）。
##
## [return] 辞書の配列。各辞書のキー：
##   tile_id                 : 打牌する牌のゲームID（例: 25 = 5p）
##   tile_name               : 表示名（例: "5筒(赤)"）
##   shanten                 : 打牌後の向聴数（0=テンパイ）
##   shanten_text            : 向聴数テキスト（例: "テンパイ"）
##   effective_tiles         : 有効牌 { ゲームID: 残り枚数上限 }
##   effective_count         : 有効牌の総枚数（生の枚数）
##   effective_count_expected: 有効牌の期待値枚数（山確率補正後、float）
##   next_tenpai_rate        : 次の1巡でテンパイ/繰り上げする確率（= expected / total_wall、float）
##   tile_breakdown          : 有効牌ごとの内訳（上位3候補のみ計算、それ以外は {}）
func evaluate_discards(hand: Array, total_wall: int = 61, dead_tiles: Dictionary = {}, meld_count: int = 0) -> Array:
	assert(hand.size() >= 2 and hand.size() % 3 == 2, "手牌は14枚・11枚・8枚・5枚・2枚のいずれかである必要があります")

	_shanten_cache.clear()
	var results: Array = []
	var evaluated: Dictionary = {}

	# --- 1パス目: 全候補の向聴数・有効牌・基本値を計算 ---
	for i in range(hand.size()):
		var tile: Dictionary = hand[i]
		var tile_id: int = tile.id

		if evaluated.has(tile_id):
			continue
		evaluated[tile_id] = true

		var remaining := hand.duplicate()
		remaining.remove_at(i)

		var counts    := _to_counts(remaining)
		var shanten   := calc_shanten(counts, meld_count)
		var effective := _calc_effective_tiles(counts, shanten, dead_tiles, meld_count)
		var eff_count_raw := 0
		for cnt: int in effective.values():
			eff_count_raw += cnt
		var in_wall_prob_val := float(total_wall) / float(total_wall + 34.0)
		var eff_count_expected: float = float(eff_count_raw) * in_wall_prob_val
		var next_tenpai_rate: float = minf(eff_count_expected / float(total_wall), 1.0) if total_wall > 0 else 0.0

		results.append({
			"tile_id"                 : tile_id,
			"tile_name"               : MahjongLogic.get_tile_name(tile),
			"shanten"                 : shanten,
			"shanten_text"            : _shanten_to_text(shanten),
			"effective_tiles"         : effective,
			"effective_count"         : eff_count_raw,
			"effective_count_expected": eff_count_expected,
			"next_tenpai_rate"        : next_tenpai_rate,
			"tile_breakdown"          : {},
			"_counts"                 : counts,
		})

	# --- ソート: 向聴数（昇順）→ 有効牌枚数（降順）→ next_tenpai_rate（降順）---
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.shanten != b.shanten:
			return a.shanten < b.shanten
		if a.effective_count != b.effective_count:
			return a.effective_count > b.effective_count
		return float(a.next_tenpai_rate) > float(b.next_tenpai_rate)
	)

	# --- 2パス目: 一時的に無効化（処理時間計測用）---
	#for i in range(mini(3, results.size())):
	#	var r: Dictionary = results[i]
	#	if r.shanten >= 1:
	#		var rates := _calc_rates(r["_counts"], r.shanten, r["effective_tiles"], total_wall, dead_tiles)
	#		r["tile_breakdown"] = rates.tile_breakdown

	# --- 一時キーを削除 ---
	for r: Dictionary in results:
		r.erase("_counts")

	return results


## 向聴数のみ計算する（一般手と七対子の最小値）
## counts: _to_counts() が返す内部インデックス配列
## meld_count: 副露済み面子数（>0 のとき七対子を除外）
func calc_shanten(counts: Array, meld_count: int = 0) -> int:
	var key := str(counts)
	if _shanten_cache.has(key):
		return _shanten_cache[key]
	var s_regular := _shanten_regular(counts, meld_count)
	var result: int
	if meld_count > 0:
		result = s_regular
	else:
		result = mini(s_regular, _shanten_chiitoi(counts))
	_shanten_cache[key] = result
	return result


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

func _shanten_regular(counts: Array, meld_count: int = 0) -> int:
	_best = 8 - meld_count * 2
	_search(counts, 0, meld_count, 0, false)
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

## 現在の向聴数を下げる牌と山の生の枚数（補正なし）を返す。
## wall_count = DECK_SIZE - 手牌 - 死牌
func _calc_effective_tiles(counts: Array, shanten: int, dead_tiles: Dictionary = {}, meld_count: int = 0) -> Dictionary:
	var dead_counts: Dictionary = dead_tiles.get("counts", {})
	var effective: Dictionary = {}
	for idx in range(NUM_TYPES):
		var game_id: int = _IDX_TO_GAME_ID[idx]
		var dead: int = int(dead_counts.get(game_id, 0))
		var wall_count: int = DECK_SIZE - counts[idx] - dead
		if wall_count <= 0:
			continue
		counts[idx] += 1
		if calc_shanten(counts, meld_count) < shanten:
			effective[game_id] = wall_count
		counts[idx] -= 1
	return effective


# ==================================================
# テンパイ率・和了率計算
# ==================================================

## テンパイ率・和了率・有効牌内訳を返す。
## shanten==0: tenpai_rate=1.0, agari_rate=ツモ和了確率
## shanten==1: tenpai_rate=テンパイ到達確率, agari_rate=和了期待値, tile_breakdown=各有効牌内訳
## shanten==2: tenpai_rate=1シャンテン到達率, agari_rate=テンパイ到達率, tile_breakdown=各有効牌内訳
## shanten>=3: tenpai_rate=1シャンテン到達率, agari_rate=-1.0
func _calc_rates(
		counts    : Array,
		shanten   : int,
		effective : Dictionary,
		total_wall: int,
		dead_tiles: Dictionary
) -> Dictionary:
	if total_wall <= 0:
		return {"tenpai_rate": -1.0, "agari_rate": -1.0, "tile_breakdown": {}}

	var eff_total := 0
	for cnt in effective.values():
		eff_total += int(cnt)

	var in_wall_prob := float(total_wall) / float(total_wall + 34.0)

	if shanten == 0:
		if eff_total == 0:
			return {"tenpai_rate": 1.0, "agari_rate": 0.0, "tile_breakdown": {}}
		var eff_capped := mini(eff_total, total_wall)
		var agari := _calc_agari_rate(float(eff_capped) * in_wall_prob, float(total_wall))
		return {"tenpai_rate": 1.0, "agari_rate": agari, "tile_breakdown": {}}

	if shanten == 1:
		if eff_total == 0:
			return {"tenpai_rate": 0.0, "agari_rate": 0.0, "tile_breakdown": {}}
		var eff_capped := mini(eff_total, total_wall)
		var tenpai := _calc_agari_rate(float(eff_capped) * in_wall_prob, float(total_wall))
		var agari := 0.0
		var tile_breakdown := {}
		var num_tile_types := float(effective.size())
		var per_tile_expected: float = (float(eff_total) * in_wall_prob) / num_tile_types if num_tile_types > 0 else 0.0
		for game_id: int in effective:
			var w_tile: int = int(effective[game_id])
			if w_tile <= 0:
				continue
			var w_tile_expected := float(w_tile) * in_wall_prob
			var p_draw := w_tile_expected / float(total_wall)
			var idx: int = _GAME_ID_TO_IDX.get(game_id, -1)
			if idx < 0:
				continue
			counts[idx] += 1
			var new_shanten := calc_shanten(counts)
			var remaining := total_wall - 1
			var tile_agari := 0.0
			if new_shanten == 0 and remaining > 0:
				var new_eff := _calc_effective_tiles(counts, 0, dead_tiles)
				var e2 := 0.0
				for cnt in new_eff.values():
					e2 += float(cnt)
				var remaining_in_wall_prob := float(remaining) / float(remaining + 34.0)
				tile_agari = _calc_agari_rate(e2 * remaining_in_wall_prob, float(remaining))
			agari += p_draw * tile_agari
			tile_breakdown[game_id] = {
				"wall_count" : w_tile,
				"expected"   : per_tile_expected,
				"tenpai_rate": p_draw,
				"agari_rate" : tile_agari,
			}
			counts[idx] -= 1
		tenpai = minf(tenpai, 1.0)
		agari  = minf(agari, 1.0)
		return {"tenpai_rate": tenpai, "agari_rate": agari, "tile_breakdown": tile_breakdown}

	if shanten == 2:
		if eff_total == 0:
			return {"tenpai_rate": -1.0, "agari_rate": -1.0, "tile_breakdown": {}}
		var eff_capped := mini(eff_total, total_wall)
		var reach_1shan := minf(_calc_agari_rate(float(eff_capped) * in_wall_prob, float(total_wall)), 1.0)
		var tenpai := 0.0
		var tile_breakdown := {}
		var num_tile_types := float(effective.size())
		var per_tile_expected: float = (float(eff_total) * in_wall_prob) / num_tile_types if num_tile_types > 0 else 0.0
		for game_id: int in effective:
			var w_tile: int = int(effective[game_id])
			if w_tile <= 0:
				continue
			var w_tile_expected := float(w_tile) * in_wall_prob
			var p_draw := w_tile_expected / float(total_wall)
			var idx: int = _GAME_ID_TO_IDX.get(game_id, -1)
			if idx < 0:
				continue
			counts[idx] += 1
			var new_shanten := calc_shanten(counts)
			var remaining := total_wall - 1
			if new_shanten == 1 and remaining > 0:
				var new_eff := _calc_effective_tiles(counts, 1, dead_tiles)
				var e2 := 0.0
				for cnt in new_eff.values():
					e2 += float(cnt)
				var remaining_in_wall_prob := float(remaining) / float(remaining + 34.0)
				var tile_tenpai := _calc_agari_rate(e2 * remaining_in_wall_prob, float(remaining))
				tenpai += p_draw * tile_tenpai
				tile_breakdown[game_id] = {
					"wall_count" : w_tile,
					"expected"   : per_tile_expected,
					"tenpai_rate": p_draw,
					"agari_rate" : -1.0,
				}
			counts[idx] -= 1
		tenpai = minf(tenpai, 1.0)
		return {"tenpai_rate": reach_1shan, "agari_rate": tenpai, "tile_breakdown": tile_breakdown}

	# shanten >= 3
	if eff_total == 0:
		return {"tenpai_rate": -1.0, "agari_rate": -1.0, "tile_breakdown": {}}
	var eff_capped := mini(eff_total, total_wall)
	var reach_1shan := _calc_agari_rate(float(eff_capped) * in_wall_prob, float(total_wall))
	return {"tenpai_rate": reach_1shan, "agari_rate": -1.0, "tile_breakdown": {}}


## 逐次計算で和了率（または到達率）を返す。
## e: 初期有効牌期待枚数（補正済み）  w: 残り山枚数
func _calc_agari_rate(e: float, w: float) -> float:
	if w <= 0.0 or e <= 0.0:
		return 0.0
	var turns: int = ceili(w / 3.0)
	var p_not := 1.0
	var ev := e
	var wv := w
	for k in range(turns):
		if wv <= 0.0:
			break
		ev -= ev * (2.0 / (wv + 34.0))
		ev = maxf(0.0, ev)
		p_not *= 1.0 - ev / wv
		wv -= 3.0
	return minf(1.0 - p_not, 1.0)


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
