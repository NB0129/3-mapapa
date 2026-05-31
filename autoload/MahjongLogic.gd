extends Node

# ============================================================
# 牌 ID 定数
# ============================================================
const MAN_1 = 11
const MAN_9 = 19
const PIN_1 = 21; const PIN_2 = 22; const PIN_3 = 23; const PIN_4 = 24
const PIN_5 = 25; const PIN_6 = 26; const PIN_7 = 27; const PIN_8 = 28; const PIN_9 = 29
const SOU_1 = 31; const SOU_2 = 32; const SOU_3 = 33; const SOU_4 = 34
const SOU_5 = 35; const SOU_6 = 36; const SOU_7 = 37; const SOU_8 = 38; const SOU_9 = 39
const EAST  = 41
const SOUTH = 42
const WEST  = 43
const NORTH = 44
const HAKU  = 45
const HATSU = 46
const CHUN  = 47

const ALL_TILE_IDS := [
	11, 19,
	21, 22, 23, 24, 25, 26, 27, 28, 29,
	31, 32, 33, 34, 35, 36, 37, 38, 39,
	41, 42, 43, 44, 45, 46, 47,
]

# ============================================================
# 牌の生成ヘルパー
# ============================================================

func make_tile(id: int, is_red: bool = false, is_gold: bool = false, is_haku_pochi: bool = false) -> Dictionary:
	return {"id": id, "is_red": is_red, "is_gold": is_gold, "is_haku_pochi": is_haku_pochi}

func get_tile_name(tile: Dictionary) -> String:
	var suffix := ""
	if tile.get("is_red", false):
		suffix = "赤"
	elif tile.get("is_gold", false):
		suffix = "金"
	var id: int = tile.id
	if id == MAN_1: return "1萬" + suffix
	if id == MAN_9: return "9萬" + suffix
	if id >= 21 and id <= 29: return str(id - 20) + "筒" + suffix
	if id >= 31 and id <= 39: return str(id - 30) + "索" + suffix
	match id:
		41: return "東"
		42: return "南"
		43: return "西"
		44: return "北" + suffix
		45: return "白ポッチ" if tile.get("is_haku_pochi", false) else "白"
		46: return "發"
		47: return "中"
	return "?" + str(id)

func get_wind_name(wind_id: int) -> String:
	match wind_id:
		EAST:  return "東"
		SOUTH: return "南"
		WEST:  return "西"
		NORTH: return "北"
	return "?"

# ============================================================
# デッキ生成（三麻 108枚）
# ============================================================

func create_deck() -> Array:
	var deck: Array = []
	# 萬子：1萬・9萬 各4枚
	for _i in range(4): deck.append(make_tile(MAN_1))
	for _i in range(4): deck.append(make_tile(MAN_9))
	# 筒子 1〜9 各4枚
	for n in range(1, 10):
		var id := 20 + n
		for i in range(4):
			if id == PIN_5:
				deck.append(make_tile(id, i < 2, false))       # 赤×2
			elif id == PIN_8:
				deck.append(make_tile(id, false, i < 1))       # 金×1
			else:
				deck.append(make_tile(id))
	# 索子 1〜9 各4枚
	for n in range(1, 10):
		var id := 30 + n
		for i in range(4):
			if id == SOU_5:
				deck.append(make_tile(id, i < 2, false))
			elif id == SOU_8:
				deck.append(make_tile(id, false, i < 1))
			else:
				deck.append(make_tile(id))
	# 東・南・西 各4枚
	for id in [EAST, SOUTH, WEST]:
		for _i in range(4): deck.append(make_tile(id))
	# 北 4枚（うち1枚赤）
	for i in range(4): deck.append(make_tile(NORTH, i < 1, false))
	# 白 4枚（うち1枚は白ポッチ）
	deck.append(make_tile(HAKU, false, false, true))  # 白ポッチ×1
	for _i in range(3): deck.append(make_tile(HAKU))  # 通常白×3
	# 發・中 各4枚
	for id in [HATSU, CHUN]:
		for _i in range(4): deck.append(make_tile(id))
	return deck  # 合計108枚

# ============================================================
# ドラ（表示牌の次の牌がドラ）
# ============================================================

func get_dora_from_indicator(indicator_id: int) -> int:
	if indicator_id >= PIN_1 and indicator_id < PIN_9: return indicator_id + 1
	if indicator_id == PIN_9: return PIN_1
	if indicator_id >= SOU_1 and indicator_id < SOU_9: return indicator_id + 1
	if indicator_id == SOU_9: return SOU_1
	if indicator_id == MAN_1: return MAN_9
	if indicator_id == MAN_9: return MAN_1
	if indicator_id == EAST:  return SOUTH
	if indicator_id == SOUTH: return WEST
	if indicator_id == WEST:  return NORTH
	if indicator_id == NORTH: return EAST
	if indicator_id == HAKU:  return HATSU
	if indicator_id == HATSU: return CHUN
	if indicator_id == CHUN:  return HAKU
	return indicator_id

# ============================================================
# 和了判定
# ============================================================

# 手牌 Dictionary 配列から ID だけ取り出す
func get_ids(hand: Array) -> Array:
	return hand.map(func(t): return t.id)

# IDリスト(14枚)が和了形かどうか
func is_complete_hand(hand_ids: Array) -> bool:
	var size := hand_ids.size()
	if size < 5 or (size - 2) % 3 != 0:
		return false
	# 北が手牌にある場合、役満形（国士・字一色・大四喜・小四喜）のみ和了可
	if NORTH in hand_ids:
		return _is_valid_north_hand(hand_ids)
	if size == 14 and _is_seven_pairs(hand_ids):
		return true
	if size == 14 and _check_kokushi(hand_ids):
		return true
	return _is_normal_hand(hand_ids)

# 北入り手で和了可能な形かチェック（国士・字一色・大四喜・小四喜のみ許可）
func _is_valid_north_hand(hand_ids: Array) -> bool:
	var size := hand_ids.size()
	# 国士無双
	if size == 14 and _check_kokushi(hand_ids):
		return true
	# 全牌が字牌（字一色候補）
	var all_honor := true
	for id: int in hand_ids:
		if not is_honor(id):
			all_honor = false
			break
	if all_honor:
		if size == 14 and _is_seven_pairs(hand_ids): return true
		return _is_normal_hand(hand_ids)
	# 大四喜・小四喜: 四風が全て刻子 or 三風刻子+一風対子 の形
	if _is_north_in_siisou(hand_ids):
		return _is_normal_hand(hand_ids)
	return false

# 北が四喜系（大四喜・小四喜）の風牌として使われているかチェック
func _is_north_in_siisou(hand_ids: Array) -> bool:
	var cnt := count_tiles(hand_ids)
	var wind_trips := 0
	var wind_pair := false
	for w: int in [EAST, SOUTH, WEST, NORTH]:
		var c: int = cnt.get(w, 0)
		if c >= 3:
			wind_trips += 1
		elif c == 2:
			wind_pair = true
	# 大四喜: 4風全て刻子以上
	if wind_trips == 4: return true
	# 小四喜: 3風が刻子以上 + 1風が対子（北が刻子または対子）
	if wind_trips == 3 and wind_pair: return true
	return false

# 七対子（2枚対子×7、4枚対子含む）
func _is_seven_pairs(hand_ids: Array) -> bool:
	if hand_ids.size() != 14:
		return false
	var counts := count_tiles(hand_ids)
	var pairs := 0
	for t in counts:
		var c: int = counts[t]
		if c == 2 or c == 4:
			pairs += c / 2 as int
		else:
			return false
	return pairs == 7

# 通常手（雀頭＋メンツN個）
func _is_normal_hand(hand_ids: Array) -> bool:
	var counts := count_tiles(hand_ids)
	var tiles := counts.keys()
	tiles.sort()
	for t in tiles:
		if counts[t] >= 2:
			counts[t] -= 2
			if can_form_melds(counts):
				counts[t] += 2
				return true
			counts[t] += 2
	return false

# メンツ構成（三麻対応：字牌・萬子の順子なし）
func can_form_melds(counts: Dictionary) -> bool:
	var min_tile := -1
	for t in counts:
		if counts[t] > 0 and (min_tile == -1 or t < min_tile):
			min_tile = t
	if min_tile == -1:
		return true  # 全て使い切った

	# 刻子
	if counts[min_tile] >= 3:
		counts[min_tile] -= 3
		if can_form_melds(counts):
			counts[min_tile] += 3
			return true
		counts[min_tile] += 3

	# 順子（筒子 PIN_1〜PIN_7 または 索子 SOU_1〜SOU_7 のみ可）
	if _can_start_sequence(min_tile):
		var n1: int = counts.get(min_tile + 1, 0)
		var n2: int = counts.get(min_tile + 2, 0)
		if n1 > 0 and n2 > 0:
			counts[min_tile]     -= 1
			counts[min_tile + 1] -= 1
			counts[min_tile + 2] -= 1
			if can_form_melds(counts):
				counts[min_tile]     += 1
				counts[min_tile + 1] += 1
				counts[min_tile + 2] += 1
				return true
			counts[min_tile]     += 1
			counts[min_tile + 1] += 1
			counts[min_tile + 2] += 1

	return false

func _can_start_sequence(id: int) -> bool:
	# 筒子 21〜27、索子 31〜37 のみ順子の起点になれる
	return (id >= PIN_1 and id <= PIN_1 + 6) or (id >= SOU_1 and id <= SOU_1 + 6)

# 両面待ち判定：和了牌が属する順子でペンチャン・カンチャンでないか確認
func _is_ryanmen_in_decomp(decomp: Dictionary, winning_id: int) -> bool:
	for meld: Array in decomp.melds:
		if winning_id not in meld: continue
		if not is_meld_sequence(meld): return false  # 刻子は不可
		var lo: int = meld[0]
		var hi: int = meld[2]
		if winning_id == meld[1]: return false  # カンチャン（中張牌）
		if winning_id == lo:
			# [lo+1, lo+2] から lo を和了 → lo-1 or lo+3 待ち。lo+3 が存在するか確認
			return _is_sequential_tile(hi + 1)
		else:  # winning_id == hi
			# [lo, lo+1] から hi を和了 → lo-1 or hi+1 待ち。lo-1 が存在するか確認
			return _is_sequential_tile(lo - 1)
	return false

# 筒子・索子の有効な牌 ID かどうか
func _is_sequential_tile(id: int) -> bool:
	return (id >= PIN_1 and id <= PIN_9) or (id >= SOU_1 and id <= SOU_9)

# テンパイ判定：13枚の手牌から有効牌リストを返す
func find_waiting_tiles(hand_ids: Array) -> Array:
	var waiting: Array = []
	var seen := {}
	for tid in ALL_TILE_IDS:
		if tid in seen:
			continue
		seen[tid] = true
		var test := hand_ids.duplicate()
		test.append(tid)
		test.sort()
		if is_complete_hand(test):
			waiting.append(tid)
	return waiting

# 牌枚数カウント（IDリスト → {id: count}）
func count_tiles(hand_ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for id in hand_ids:
		counts[id] = counts.get(id, 0) + 1
	return counts

# ============================================================
# 点数計算（30符固定テーブル）
# ============================================================
# 戻り値:
#   total    : 和了者が受け取る合計点数（積み棒除く）
#   each     : ツモオール時の各自払い（子/親が同額の場合）
#   ko_pay   : ツモ時の子払い（3ハン等で異なる場合）
#   oya_pay  : ツモ時の親払い（3ハン等で異なる場合）

func calc_score(han: int, is_parent: bool, is_tsumo: bool) -> Dictionary:
	var r := {"total": 0, "each": 0, "ko_pay": 0, "oya_pay": 0}
	# 点数テーブル: [子ロン, 子ツモオール, 子ツモ子払, 子ツモ親払, 親ロン, 親ツモオール]
	var row := _score_row(han)
	if is_parent:
		if is_tsumo:
			r.each  = row[5]
			r.total = row[5] * 2
		else:
			r.total = row[4]
	else:
		if is_tsumo:
			if row[2] > 0:  # 子払/親払が異なるケース（3ハンなど）
				r.ko_pay  = row[2]
				r.oya_pay = row[3]
				r.total   = row[2] + row[3]
			else:            # オール
				r.each  = row[1]
				r.total = row[1] * 2
		else:
			r.total = row[0]
	return r

# [子ロン, 子ツモオール, 子ツモ子払, 子ツモ親払, 親ロン, 親ツモオール]
func _score_row(han: int) -> Array:
	if   han <= 1: return [1000,  1000, 0,      0,      2000,  1000 ]
	elif han == 2: return [2000,  1000, 0,      0,      3000,  2000 ]
	elif han == 3: return [4000,  0,    1000,   3000,   6000,  3000 ]
	elif han <= 5: return [8000,  0,    3000,   5000,   12000, 6000 ]  # 満貫
	elif han <= 7: return [12000, 0,    4000,   8000,   18000, 9000 ]  # 跳満
	elif han <= 10:return [16000, 0,    6000,   10000,  24000, 12000]  # 倍満
	elif han <= 12:return [24000, 0,    8000,   16000,  36000, 18000]  # 三倍満
	else:          return [32000, 0,    12000,  20000,  48000, 24000]  # 役満

# ============================================================
# 牌種ヘルパー
# ============================================================

func is_terminal(id: int) -> bool:
	return id in [MAN_1, MAN_9, PIN_1, PIN_9, SOU_1, SOU_9]

func is_honor(id: int) -> bool:
	return id >= EAST and id <= CHUN

func is_yaochuupai(id: int) -> bool:
	return is_terminal(id) or is_honor(id)

func get_suit(id: int) -> int:
	if id == MAN_1 or id == MAN_9:    return 1
	if id >= PIN_1 and id <= PIN_9:   return 2
	if id >= SOU_1 and id <= SOU_9:   return 3
	if id >= EAST  and id <= CHUN:    return 4
	return -1

func is_meld_sequence(meld: Array) -> bool:
	if meld.size() < 3: return false
	var s: int = get_suit(meld[0])
	if s < 2 or s > 3: return false
	return meld[1] == meld[0] + 1 and meld[2] == meld[0] + 2

func is_meld_triplet(meld: Array) -> bool:
	if meld.size() < 3: return false
	return meld[0] == meld[1] and meld[1] == meld[2]

# ============================================================
# 手牌分解（通常手の全パターンを列挙）
# ============================================================

func decompose_hand(hand_ids: Array) -> Array:
	var results: Array = []
	var counts: Dictionary = count_tiles(hand_ids)
	var tiles: Array = counts.keys()
	tiles.sort()
	for jantai in tiles:
		if counts[jantai] >= 2:
			counts[jantai] -= 2
			_collect_melds(counts, [], results, jantai)
			counts[jantai] += 2
	return results

func _collect_melds(counts: Dictionary, current: Array, results: Array, jantai: int) -> void:
	var min_tile: int = -1
	for t in counts:
		if counts[t] > 0 and (min_tile == -1 or t < min_tile):
			min_tile = t
	if min_tile == -1:
		results.append({"jantai": jantai, "melds": current.duplicate(true)})
		return
	if counts[min_tile] >= 3:
		counts[min_tile] -= 3
		current.append([min_tile, min_tile, min_tile])
		_collect_melds(counts, current, results, jantai)
		current.pop_back()
		counts[min_tile] += 3
	if _can_start_sequence(min_tile):
		if counts.get(min_tile + 1, 0) > 0 and counts.get(min_tile + 2, 0) > 0:
			counts[min_tile]     -= 1
			counts[min_tile + 1] -= 1
			counts[min_tile + 2] -= 1
			current.append([min_tile, min_tile + 1, min_tile + 2])
			_collect_melds(counts, current, results, jantai)
			current.pop_back()
			counts[min_tile]     += 1
			counts[min_tile + 1] += 1
			counts[min_tile + 2] += 1

# ============================================================
# フリテン・リーチ補助
# ============================================================

func is_furiten(hand_ids: Array, discard_ids: Array) -> bool:
	var waiting: Array = find_waiting_tiles(hand_ids)
	for tid in waiting:
		if tid in discard_ids:
			return true
	return false

# 13枚手牌でリーチ可能な捨て牌インデックス一覧（捨ててテンパイになる牌）
func get_riichi_discards(hand: Array) -> Array:
	var hand_ids: Array = get_ids(hand)
	var result: Array = []
	var cache: Dictionary = {}  # tid -> bool
	for i in range(hand_ids.size()):
		var tid: int = hand_ids[i]
		if tid in cache:
			if cache[tid]:
				result.append(i)
			continue
		var test: Array = hand_ids.duplicate()
		test.remove_at(i)
		var tenpai: bool = not find_waiting_tiles(test).is_empty()
		cache[tid] = tenpai
		if tenpai:
			result.append(i)
	return result

func calculate_shanten(hand_ids: Array) -> int:
	var normal: int = _normal_shanten(hand_ids)
	var chiitoi: int = _chiitoi_shanten(hand_ids)
	var kokushi: int = _kokushi_shanten(hand_ids)
	return min(normal, min(chiitoi, kokushi))

func count_ukeire_after_discard(hand_ids_13: Array) -> int:
	var current: int = calculate_shanten(hand_ids_13)
	var counts: Dictionary = count_tiles(hand_ids_13)
	var total := 0
	for tid: int in ALL_TILE_IDS:
		var left: int = 4 - counts.get(tid, 0)
		if left <= 0:
			continue
		var test: Array = hand_ids_13.duplicate()
		test.append(tid)
		if calculate_shanten(test) < current:
			total += left
	return total

func _normal_shanten(hand_ids: Array) -> int:
	var counts: Dictionary = count_tiles(hand_ids)
	var best := [8]
	var cache := {}
	_normal_shanten_dfs(counts, 0, 0, 0, best, cache)
	return best[0]

func _normal_shanten_dfs(counts: Dictionary, melds: int, pairs: int, taatsu: int, best: Array, cache: Dictionary) -> void:
	var cache_key := _shanten_cache_key(counts, melds, pairs, taatsu)
	if cache.has(cache_key):
		return
	cache[cache_key] = true

	var first: int = -1
	for tid: int in ALL_TILE_IDS:
		if counts.get(tid, 0) > 0:
			first = tid
			break
	if first == -1:
		var effective_taatsu: int = min(taatsu, 4 - melds)
		var shanten: int = 8 - melds * 2 - effective_taatsu - pairs
		best[0] = min(best[0], shanten)
		return

	counts[first] -= 1
	_normal_shanten_dfs(counts, melds, pairs, taatsu, best, cache)
	counts[first] += 1

	if counts.get(first, 0) >= 3:
		counts[first] -= 3
		_normal_shanten_dfs(counts, melds + 1, pairs, taatsu, best, cache)
		counts[first] += 3

	if _can_start_sequence(first) and counts.get(first + 1, 0) > 0 and counts.get(first + 2, 0) > 0:
		counts[first] -= 1
		counts[first + 1] -= 1
		counts[first + 2] -= 1
		_normal_shanten_dfs(counts, melds + 1, pairs, taatsu, best, cache)
		counts[first] += 1
		counts[first + 1] += 1
		counts[first + 2] += 1

	if pairs == 0 and counts.get(first, 0) >= 2:
		counts[first] -= 2
		_normal_shanten_dfs(counts, melds, 1, taatsu, best, cache)
		counts[first] += 2

	if counts.get(first, 0) >= 2:
		counts[first] -= 2
		_normal_shanten_dfs(counts, melds, pairs, taatsu + 1, best, cache)
		counts[first] += 2

	if _can_start_sequence(first) and counts.get(first + 1, 0) > 0:
		counts[first] -= 1
		counts[first + 1] -= 1
		_normal_shanten_dfs(counts, melds, pairs, taatsu + 1, best, cache)
		counts[first] += 1
		counts[first + 1] += 1

	if _can_start_sequence(first) and counts.get(first + 2, 0) > 0:
		counts[first] -= 1
		counts[first + 2] -= 1
		_normal_shanten_dfs(counts, melds, pairs, taatsu + 1, best, cache)
		counts[first] += 1
		counts[first + 2] += 1

func _shanten_cache_key(counts: Dictionary, melds: int, pairs: int, taatsu: int) -> String:
	var parts := [str(melds), str(pairs), str(taatsu)]
	for tid: int in ALL_TILE_IDS:
		parts.append(str(counts.get(tid, 0)))
	return ",".join(parts)

func _chiitoi_shanten(hand_ids: Array) -> int:
	var counts: Dictionary = count_tiles(hand_ids)
	var pairs := 0
	var unique := 0
	for tid in counts:
		unique += 1
		pairs += min(int(counts[tid] / 2), 2)
	return 6 - pairs + max(0, 7 - unique)

func _kokushi_shanten(hand_ids: Array) -> int:
	var yaochu_ids := [MAN_1, MAN_9, PIN_1, PIN_9, SOU_1, SOU_9, EAST, SOUTH, WEST, NORTH, HAKU, HATSU, CHUN]
	var counts: Dictionary = count_tiles(hand_ids)
	var unique := 0
	var has_pair := false
	for tid: int in yaochu_ids:
		var c: int = counts.get(tid, 0)
		if c > 0:
			unique += 1
		if c >= 2:
			has_pair = true
	return 13 - unique - (1 if has_pair else 0)

# ============================================================
# 役判定メイン
# ============================================================
# context キー:
#   round_wind, player_wind, is_tsumo, is_riichi, is_daburi, is_ippatsu,
#   is_rinshan, is_chankan, is_haitei, is_houtei,
#   is_tenhou, is_chiihou, is_renhou, is_nagashi,
#   open_melds: [{type, tile_ids, from_player}]

func check_yaku(hand_ids: Array, context: Dictionary) -> Array:
	var open_melds: Array = context.get("open_melds", [])
	var is_open: bool = false
	for m: Dictionary in open_melds:
		if m.get("type", "") in ["pon", "minkan", "kakan"]:
			is_open = true
			break

	# 役満チェック（先）
	var yakuman: Array = _check_yakuman_all(hand_ids, context, is_open, open_melds)
	if not yakuman.is_empty():
		return yakuman

	# 北が手牌にある場合、役満形のみ和了可（役満チェックを通過した＝役満なし → 和了不可）
	if NORTH in hand_ids:
		return []

	var yaku: Array = []

	# 状況役
	if context.get("is_riichi", false):
		if context.get("is_daburi", false):
			yaku.append({"name": "ダブルリーチ", "han": 2})
		else:
			yaku.append({"name": "リーチ", "han": 1})
		if context.get("is_open_riichi", false):
			yaku.append({"name": "オープン立直", "han": 1})
		if context.get("is_ippatsu", false):
			yaku.append({"name": "一発", "han": 1})
	if context.get("is_tsumo", false) and not is_open:
		yaku.append({"name": "門前ツモ", "han": 1})
	if context.get("is_rinshan", false):
		yaku.append({"name": "嶺上開花", "han": 1})
	if context.get("is_chankan", false):
		yaku.append({"name": "槍槓", "han": 1})
	if context.get("is_haitei", false) and context.get("is_tsumo", false):
		yaku.append({"name": "海底摸月", "han": 1})
	if context.get("is_houtei", false) and not context.get("is_tsumo", false):
		yaku.append({"name": "河底撈魚", "han": 1})

	# タンヤオ
	if _all_simples(hand_ids, open_melds):
		yaku.append({"name": "タンヤオ", "han": 1})

	# 役牌
	yaku.append_array(_get_yakuhai(hand_ids, open_melds,
		context.get("round_wind", EAST), context.get("player_wind", EAST)))

	# 七対子系
	if _is_seven_pairs(hand_ids):
		yaku.append({"name": _get_chiitoi_name(hand_ids), "han": _get_chiitoi_han(hand_ids)})
		if _check_honitsu(hand_ids, []):
			yaku.append({"name": "混一色", "han": 3})
		return yaku

	# 通常手分解が必要な役
	var decomps: Array = decompose_hand(hand_ids)
	if not decomps.is_empty():
		yaku.append_array(_best_decomp_yaku(decomps, open_melds, context, is_open))

	# 複合役
	if _check_chinitsu(hand_ids, open_melds):
		yaku.append({"name": "清一色", "han": (6 if not is_open else 5)})
	elif _check_honitsu(hand_ids, open_melds):
		yaku.append({"name": "混一色", "han": (3 if not is_open else 2)})

	if _check_honroutou(hand_ids, open_melds):
		yaku.append({"name": "ホンロウトウ", "han": 4})

	return yaku

func count_han(yaku_list: Array) -> int:
	var total: int = 0
	for y: Dictionary in yaku_list:
		total += int(y.get("han", 0))
	return total

# ============================================================
# 役満判定
# ============================================================

func _check_yakuman(hand_ids: Array, context: Dictionary, is_open: bool, open_melds: Array) -> Array:
	if context.get("is_tenhou", false): return [{"name": "天和",   "han": 13}]
	if context.get("is_chiihou", false): return [{"name": "地和",  "han": 13}]
	if context.get("is_renhou", false):  return [{"name": "人和",  "han": 13}]
	if context.get("is_nagashi", false): return [{"name": "流し満貫", "han": 13}]

	# 大車輪（清一色七対子）
	if _is_seven_pairs(hand_ids) and _check_chinitsu(hand_ids, []):
		return [{"name": "大車輪", "han": 13}]

	# 12枚七対子（4枚対子×3）
	if _is_seven_pairs(hand_ids):
		var cnt: Dictionary = count_tiles(hand_ids)
		var q: int = 0
		for t in cnt:
			if cnt[t] == 4: q += 1
		if q == 3: return [{"name": "12枚七対子", "han": 13}]

	# 国士無双
	if _check_kokushi(hand_ids): return [{"name": "国士無双", "han": 13}]

	# 清老頭
	if _check_chinroutou(hand_ids, open_melds): return [{"name": "清老頭", "han": 13}]

	# 字一色
	if _check_tsuiso(hand_ids, open_melds): return [{"name": "字一色", "han": 13}]

	# 緑一色
	if _check_ryuuiisou(hand_ids, open_melds): return [{"name": "緑一色", "han": 13}]

	# 萬子混一色
	if _check_manzu_honitsu(hand_ids, open_melds): return [{"name": "萬子混一色", "han": 13}]

	# 大三元
	if _check_daisangen(hand_ids, open_melds): return [{"name": "大三元", "han": 13}]

	# 大四喜
	if _check_daisuushii(hand_ids, open_melds): return [{"name": "大四喜", "han": 13}]

	# 小四喜
	if _check_shousuushii(hand_ids, open_melds): return [{"name": "小四喜", "han": 13}]

	# 九蓮宝燈（門前のみ）
	if not is_open and _check_chuuren_poutou(hand_ids):
		return [{"name": "九蓮宝燈", "han": 13}]

	# 四暗刻（門前のみ）
	if not is_open and _check_suuankou(hand_ids, context):
		return [{"name": "四暗刻", "han": 13}]

	# 四槓子
	if _count_kantsu(open_melds) >= 4: return [{"name": "四槓子", "han": 13}]

	return []

# ============================================================
# 役判定ヘルパー
# ============================================================

func _check_yakuman_all(hand_ids: Array, context: Dictionary, is_open: bool, open_melds: Array) -> Array:
	var yaku: Array = []
	if context.get("is_tenhou", false): yaku.append({"name": "天和", "han": 13})
	if context.get("is_chiihou", false): yaku.append({"name": "地和", "han": 13})
	if context.get("is_renhou", false): yaku.append({"name": "人和", "han": 13})
	if context.get("is_nagashi", false): yaku.append({"name": "流し満貫", "han": 13})
	if _is_seven_pairs(hand_ids) and _check_chinitsu(hand_ids, []):
		yaku.append({"name": "大車輪", "han": 13})
	if _is_seven_pairs(hand_ids):
		var cnt: Dictionary = count_tiles(hand_ids)
		var q: int = 0
		for t in cnt:
			if cnt[t] == 4: q += 1
		if q == 3:
			yaku.append({"name": "12枚七対子", "han": 13})
	if _check_kokushi(hand_ids): yaku.append({"name": "国士無双", "han": 13})
	if _check_chinroutou(hand_ids, open_melds): yaku.append({"name": "清老頭", "han": 13})
	if _check_tsuiso(hand_ids, open_melds): yaku.append({"name": "字一色", "han": 13})
	if _check_ryuuiisou(hand_ids, open_melds): yaku.append({"name": "緑一色", "han": 13})
	if _check_manzu_honitsu(hand_ids, open_melds): yaku.append({"name": "萬子混一色", "han": 13})
	if _check_daisangen(hand_ids, open_melds): yaku.append({"name": "大三元", "han": 13})
	if _check_daisuushii(hand_ids, open_melds): yaku.append({"name": "大四喜", "han": 13})
	if _check_shousuushii(hand_ids, open_melds): yaku.append({"name": "小四喜", "han": 13})
	if not is_open and _check_chuuren_poutou(hand_ids):
		yaku.append({"name": "九蓮宝燈", "han": 13})
	if not is_open and _check_suuankou(hand_ids, context):
		yaku.append({"name": "四暗刻", "han": 13})
	if _count_kantsu(open_melds) >= 4:
		yaku.append({"name": "四槓子", "han": 13})
	return yaku

func _all_simples(hand_ids: Array, open_melds: Array) -> bool:
	for id: int in hand_ids:
		if is_yaochuupai(id): return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if is_yaochuupai(id): return false
	return true

func _get_yakuhai(hand_ids: Array, open_melds: Array, round_wind: int, player_wind: int) -> Array:
	var yaku: Array = []
	var honor_trip: Dictionary = {}
	var cnt: Dictionary = count_tiles(hand_ids)
	for id: int in [EAST, SOUTH, WEST, NORTH, HAKU, HATSU, CHUN]:
		if cnt.get(id, 0) >= 3: honor_trip[id] = true
	for m: Dictionary in open_melds:
		var ids: Array = m.get("tile_ids", [])
		if ids.size() >= 3 and is_honor(ids[0]) and ids[0] == ids[1] and ids[1] == ids[2]:
			honor_trip[ids[0]] = true
	for id: int in honor_trip:
		if id == round_wind:  yaku.append({"name": "場風（" + get_wind_name(id) + "）", "han": 1})
		if id == player_wind: yaku.append({"name": "自風（" + get_wind_name(id) + "）", "han": 1})
		if id == HAKU:  yaku.append({"name": "白", "han": 1})
		if id == HATSU: yaku.append({"name": "發", "han": 1})
		if id == CHUN:  yaku.append({"name": "中", "han": 1})
	return yaku

func _get_chiitoi_han(hand_ids: Array) -> int:
	var cnt: Dictionary = count_tiles(hand_ids)
	var q: int = 0
	for t in cnt:
		if cnt[t] == 4: q += 1
	if q >= 2: return 8
	if q >= 1: return 4
	return 2

func _get_chiitoi_name(hand_ids: Array) -> String:
	match _get_chiitoi_han(hand_ids):
		8: return "8枚七対子"
		4: return "4枚七対子"
	return "七対子"

func _check_honitsu(hand_ids: Array, open_melds: Array) -> bool:
	var suits: Dictionary = {}
	for id: int in hand_ids:
		if not is_honor(id): suits[get_suit(id)] = true
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if not is_honor(id): suits[get_suit(id)] = true
	return suits.size() == 1

func _check_chinitsu(hand_ids: Array, open_melds: Array) -> bool:
	for id: int in hand_ids:
		if is_honor(id): return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if is_honor(id): return false
	return _check_honitsu(hand_ids, open_melds)

func _check_honroutou(hand_ids: Array, open_melds: Array) -> bool:
	for id: int in hand_ids:
		if not is_yaochuupai(id): return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if not is_yaochuupai(id): return false
	return true

func _check_kokushi(hand_ids: Array) -> bool:
	if hand_ids.size() != 14: return false
	var needed: Array = [MAN_1, MAN_9, PIN_1, PIN_9, SOU_1, SOU_9,
						 EAST, SOUTH, WEST, NORTH, HAKU, HATSU, CHUN]
	var cnt: Dictionary = count_tiles(hand_ids)
	var has_pair: bool = false
	for id: int in needed:
		if cnt.get(id, 0) == 0: return false
		if cnt.get(id, 0) >= 2: has_pair = true
	return has_pair

func _check_chinroutou(hand_ids: Array, open_melds: Array) -> bool:
	var t: Array = [MAN_1, MAN_9, PIN_1, PIN_9, SOU_1, SOU_9]
	for id: int in hand_ids:
		if id not in t: return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if id not in t: return false
	return true

func _check_tsuiso(hand_ids: Array, open_melds: Array) -> bool:
	for id: int in hand_ids:
		if not is_honor(id): return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if not is_honor(id): return false
	return true

func _check_ryuuiisou(hand_ids: Array, open_melds: Array) -> bool:
	var green: Array = [SOU_2, SOU_3, SOU_4, SOU_6, SOU_8, HATSU]
	for id: int in hand_ids:
		if id not in green: return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if id not in green: return false
	return true

func _check_chuuren_poutou(hand_ids: Array) -> bool:
	if hand_ids.size() != 14:
		return false
	var suit: int = -1
	for id: int in hand_ids:
		if is_honor(id):
			return false
		var s: int = get_suit(id)
		if s != 2 and s != 3:
			return false
		if suit < 0:
			suit = s
		elif s != suit:
			return false

	var base: int = PIN_1 if suit == 2 else SOU_1
	var cnt: Dictionary = count_tiles(hand_ids)
	for n in range(1, 10):
		var id: int = base + n - 1
		var required: int = 3 if n == 1 or n == 9 else 1
		if cnt.get(id, 0) < required:
			return false
	return true

func _check_manzu_honitsu(hand_ids: Array, open_melds: Array) -> bool:
	var has_man: bool = false
	for id: int in hand_ids:
		if id == MAN_1 or id == MAN_9: has_man = true
		elif not is_honor(id): return false
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			if id == MAN_1 or id == MAN_9: has_man = true
			elif not is_honor(id): return false
	return has_man

func _check_daisangen(hand_ids: Array, open_melds: Array) -> bool:
	var cnt: Dictionary = count_tiles(hand_ids)
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			cnt[id] = cnt.get(id, 0) + 1
	for id: int in [HAKU, HATSU, CHUN]:
		if cnt.get(id, 0) < 3: return false
	return true

func _check_shousuushii(hand_ids: Array, open_melds: Array) -> bool:
	var cnt: Dictionary = count_tiles(hand_ids)
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			cnt[id] = cnt.get(id, 0) + 1
	var trips: int = 0; var pair_found: bool = false
	for id: int in [EAST, SOUTH, WEST, NORTH]:
		var c: int = cnt.get(id, 0)
		if c >= 3: trips += 1
		elif c >= 2: pair_found = true
	return trips == 3 and pair_found

func _check_daisuushii(hand_ids: Array, open_melds: Array) -> bool:
	var cnt: Dictionary = count_tiles(hand_ids)
	for m: Dictionary in open_melds:
		for id: int in m.get("tile_ids", []):
			cnt[id] = cnt.get(id, 0) + 1
	for id: int in [EAST, SOUTH, WEST, NORTH]:
		if cnt.get(id, 0) < 3: return false
	return true

func _check_suuankou(hand_ids: Array, context: Dictionary) -> bool:
	var decomps: Array = decompose_hand(hand_ids)
	for decomp: Dictionary in decomps:
		var all_trip: bool = true
		for meld: Array in decomp.melds:
			if not is_meld_triplet(meld): all_trip = false; break
		if all_trip: return true
	return false

func _count_kantsu(open_melds: Array) -> int:
	var n: int = 0
	for m: Dictionary in open_melds:
		if m.get("type", "") in ["minkan", "ankan", "kakan"]: n += 1
	return n

# ============================================================
# 分解ベース役（最大ハン分解を返す）
# ============================================================

func _best_decomp_yaku(decomps: Array, open_melds: Array, context: Dictionary, is_open: bool) -> Array:
	var best: Array = []; var best_han: int = 0
	for decomp: Dictionary in decomps:
		var extra: Array = []; var extra_han: int = 0
		var melds: Array = decomp.melds

		# 平和
		if not is_open and _check_pinfu(decomp, context):
			extra.append({"name": "平和", "han": 1}); extra_han += 1

		# 一盃口/二盃口
		if not is_open:
			var ipe: int = _iipeiko_count(melds)
			if ipe >= 2:   extra.append({"name": "二盃口", "han": 3}); extra_han += 3
			elif ipe == 1: extra.append({"name": "一盃口", "han": 1}); extra_han += 1

		# 対々和
		if _check_toitoi(melds, open_melds):
			extra.append({"name": "対々和", "han": 2}); extra_han += 2

		# 三暗刻
		if _check_sanankou(melds, open_melds, context):
			extra.append({"name": "三暗刻", "han": 2}); extra_han += 2

		# 三槓子
		if _count_kantsu(open_melds) >= 3:
			extra.append({"name": "三槓子", "han": 2}); extra_han += 2

		# 一気通貫
		var ittsu_h: int = _check_ittsu(melds, open_melds, is_open)
		if ittsu_h > 0: extra.append({"name": "一気通貫", "han": ittsu_h}); extra_han += ittsu_h

		# 三色同刻
		if _check_sanshokudoukou(melds, open_melds):
			extra.append({"name": "三色同刻", "han": 2}); extra_han += 2

		# 小三元
		if _check_shousangen(decomp, open_melds):
			extra.append({"name": "小三元", "han": 2}); extra_han += 2

		# チャンタ/純チャン（ホンロウトウと排他だが上位で処理）
		var ch_h: int = _check_chanta_or_junchan(melds, open_melds, is_open, decomp.jantai)
		if ch_h > 0:
			var ch_name: String = "純チャン" if ch_h >= 5 else "チャンタ"
			extra.append({"name": ch_name, "han": ch_h}); extra_han += ch_h

		if extra_han > best_han: best_han = extra_han; best = extra
	return best

func _check_pinfu(decomp: Dictionary, context: Dictionary) -> bool:
	# 全メンツが順子
	for meld: Array in decomp.melds:
		if not is_meld_sequence(meld): return false
	# 雀頭が役牌でない
	var j: int = decomp.jantai
	if j == HAKU or j == HATSU or j == CHUN: return false
	if j == context.get("round_wind", EAST) or j == context.get("player_wind", EAST): return false
	# 和了牌が両面待ちか確認（タンキ・カンチャン・ペンチャンは不可）
	var winning_id: int = context.get("winning_tile_id", -1)
	if winning_id < 0: return false
	return _is_ryanmen_in_decomp(decomp, winning_id)

func _iipeiko_count(melds: Array) -> int:
	var seq_cnt: Dictionary = {}
	for meld: Array in melds:
		if is_meld_sequence(meld):
			var k: String = str(meld[0]) + "_" + str(meld[1]) + "_" + str(meld[2])
			seq_cnt[k] = seq_cnt.get(k, 0) + 1
	var pairs: int = 0
	for k: String in seq_cnt: pairs += seq_cnt[k] / 2
	return pairs

func _check_toitoi(melds: Array, open_melds: Array) -> bool:
	for meld: Array in melds:
		if not is_meld_triplet(meld): return false
	for m: Dictionary in open_melds:
		if m.get("type", "") not in ["pon", "minkan", "kakan", "ankan"]: return false
	return true

func _check_sanankou(melds: Array, open_melds: Array, context: Dictionary) -> bool:
	var n: int = 0
	for meld: Array in melds:
		if is_meld_triplet(meld): n += 1
	for m: Dictionary in open_melds:
		if m.get("type", "") == "ankan": n += 1
	if not context.get("is_tsumo", false): n = max(0, n - 1)
	return n >= 3

func _check_ittsu(melds: Array, open_melds: Array, is_open: bool) -> int:
	var all_m: Array = melds.duplicate()
	for m: Dictionary in open_melds:
		var ids: Array = m.get("tile_ids", [])
		if ids.size() >= 3: all_m.append(ids.slice(0, 3))
	for base: int in [PIN_1, SOU_1]:
		var h123: bool = false; var h456: bool = false; var h789: bool = false
		for meld: Array in all_m:
			if is_meld_sequence(meld):
				if   meld[0] == base:     h123 = true
				elif meld[0] == base + 3: h456 = true
				elif meld[0] == base + 6: h789 = true
		if h123 and h456 and h789: return 1 if is_open else 2
	return 0

func _check_sanshokudoukou(melds: Array, open_melds: Array) -> bool:
	var all_m: Array = melds.duplicate()
	for m: Dictionary in open_melds:
		var ids: Array = m.get("tile_ids", [])
		if ids.size() >= 3: all_m.append(ids.slice(0, 3))
	var trip_set: Dictionary = {}
	for meld: Array in all_m:
		if is_meld_triplet(meld): trip_set[meld[0]] = true
	# 三麻では1萬(11)・1筒(21)・1索(31) または 9萬(19)・9筒(29)・9索(39)
	if trip_set.get(MAN_1,false) and trip_set.get(PIN_1,false) and trip_set.get(SOU_1,false): return true
	if trip_set.get(MAN_9,false) and trip_set.get(PIN_9,false) and trip_set.get(SOU_9,false): return true
	# 2〜8の同色なし（萬子に2〜8がないため）
	return false

func _check_shousangen(decomp: Dictionary, open_melds: Array) -> bool:
	var trips: Dictionary = {}
	for meld: Array in decomp.melds:
		if is_meld_triplet(meld) and meld[0] in [HAKU, HATSU, CHUN]: trips[meld[0]] = true
	for m: Dictionary in open_melds:
		var ids: Array = m.get("tile_ids", [])
		if ids.size() >= 3 and ids[0] == ids[1] and ids[0] in [HAKU, HATSU, CHUN]: trips[ids[0]] = true
	return trips.size() == 2 and (decomp.jantai in [HAKU, HATSU, CHUN])

func _check_chanta_or_junchan(melds: Array, open_melds: Array, is_open: bool, jantai: int) -> int:
	if not is_yaochuupai(jantai): return 0
	var all_m: Array = melds.duplicate()
	for m: Dictionary in open_melds:
		var ids: Array = m.get("tile_ids", [])
		if ids.size() >= 3: all_m.append(ids.slice(0, 3))
	var has_honor: bool = is_honor(jantai)
	for meld: Array in all_m:
		var has_yao: bool = false
		for id: int in meld:
			if is_yaochuupai(id):
				has_yao = true
				if is_honor(id): has_honor = true
		if not has_yao: return 0
	if not has_honor: return 5 if is_open else 6  # 純チャン
	return 3 if is_open else 4  # チャンタ
