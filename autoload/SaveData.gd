extends Node

const SAVE_PATH := "user://savedata.json"
const DEFAULT_NPC_SEATS := {"bottom": "kuma_def", "right": "kuma_hiyake", "top": ""}
const DEFAULT_NPC_IDS := ["kuma_def", "kuma_hiyake"]

var total_p: int = 0
var dan: int = 1
var dan_plus: int = 0
var dan_points: int = 0
var total_games: int = 0
var rank_count: Array = [0, 0, 0]
var total_agari: int = 0
var total_houjuu: int = 0
var total_kyoku: int = 0
var total_agari_jun: int = 0
var total_agari_han: int = 0
var total_agari_chip: int = 0
var total_score: int = 0
var total_chip: int = 0

# プレイヤー設定
var player_name: String = "あなた"
var selected_player_character: String = "hachimi"
var selected_npc: Array = DEFAULT_NPC_IDS.duplicate()
var selected_empty_seat: String = "top"
var selected_npc_seats: Dictionary = DEFAULT_NPC_SEATS.duplicate()

const NPC_DEFS := {
	"kuma_black":    {"name": "ブラックくま",       "path": "res://chara/kuma_black.webp",    "path_game": "res://chara/kuma_black2a.webp",    "path_menu": "res://chara/kuma_black2b.webp"},
	"kuma_def":      {"name": "くまぱぱ",           "path": "res://chara/kuma_def.webp",      "path_game": "res://chara/kuma_def2a.webp",      "path_menu": "res://chara/kuma_def2b.webp"},
	"kuma_hiyake":   {"name": "日焼けくま",         "path": "res://chara/kuma_hiyake.webp",   "path_game": "res://chara/kuma_hiyake2a.webp",   "path_menu": "res://chara/kuma_hiyake2b.webp"},
	"kuma_hokkyoku": {"name": "北極熊",             "path": "res://chara/kuma_hokkyoku.webp", "path_game": "res://chara/kuma_hokkyoku2a.webp", "path_menu": "res://chara/kuma_hokkyoku2b.webp"},
	"kuma_megane":   {"name": "眼鏡くま",           "path": "res://chara/kuma_megane.webp",   "path_game": "res://chara/kuma_megane2a.webp",   "path_menu": "res://chara/kuma_megane2b.webp"},
	"kuma_saibo":    {"name": "サイボーグくま",     "path": "res://chara/kuma_saibo.webp",    "path_game": "res://chara/kuma_saibo2a.webp",    "path_menu": "res://chara/kuma_saibo2b.webp"},
}

# NPC別対戦回数（NPC01〜06それぞれ）
var npc_games: Dictionary = {
	"kuma_black": 0, "kuma_def": 0, "kuma_hiyake": 0,
	"kuma_hokkyoku": 0, "kuma_megane": 0, "kuma_saibo": 0,
}

var bgm_volume: float = AudioManager.DEFAULT_BGM_VOLUME
var se_volume: float = AudioManager.DEFAULT_SE_VOLUME
var assist_enabled: bool = true
var assist_mode: int = 1 # 0=OFF, 1=star only, 2=star + panel
var reach_cutin_enabled: bool = true

func _ready() -> void:
	load_data()
	AudioManager.set_volumes(bgm_volume, se_volume)

func save_data() -> void:
	var data := {
		"total_p": total_p, "dan": dan, "dan_plus": dan_plus, "dan_points": dan_points,
		"total_games": total_games, "rank_count": rank_count,
		"total_agari": total_agari, "total_houjuu": total_houjuu, "total_kyoku": total_kyoku,
		"total_agari_jun": total_agari_jun, "total_agari_han": total_agari_han,
		"total_agari_chip": total_agari_chip, "total_score": total_score, "total_chip": total_chip,
		"player_name": player_name, "selected_player_character": selected_player_character,
		"selected_npc": selected_npc, "selected_empty_seat": selected_empty_seat,
		"selected_npc_seats": selected_npc_seats, "npc_games": npc_games,
		"bgm_volume": bgm_volume, "se_volume": se_volume,
		"assist_enabled": assist_enabled, "assist_mode": assist_mode,
		"reach_cutin_enabled": reach_cutin_enabled,
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var result: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(result) != TYPE_DICTIONARY:
		return
	var d: Dictionary = result
	total_p        = d.get("total_p", 0)
	dan            = d.get("dan", 1)
	dan_plus       = d.get("dan_plus", 0)
	dan_points     = d.get("dan_points", 0)
	total_games    = d.get("total_games", 0)
	rank_count     = d.get("rank_count", [0, 0, 0])
	total_agari    = d.get("total_agari", 0)
	total_houjuu   = d.get("total_houjuu", 0)
	total_kyoku    = d.get("total_kyoku", 0)
	total_agari_jun  = d.get("total_agari_jun", 0)
	total_agari_han  = d.get("total_agari_han", 0)
	total_agari_chip = d.get("total_agari_chip", 0)
	total_score    = d.get("total_score", 0)
	total_chip     = d.get("total_chip", 0)
	player_name               = d.get("player_name", "あなた")
	selected_player_character = d.get("selected_player_character", "hachimi")
	selected_npc              = _normalize_npc_ids(d.get("selected_npc", DEFAULT_NPC_IDS))
	selected_empty_seat       = d.get("selected_empty_seat", "top")
	selected_npc_seats        = _normalize_npc_seats(d.get("selected_npc_seats", selected_npc_seats))
	npc_games      = d.get("npc_games", {"kuma_black": 0, "kuma_def": 0, "kuma_hiyake": 0, "kuma_hokkyoku": 0, "kuma_megane": 0, "kuma_saibo": 0})
	for npc_id: String in NPC_DEFS.keys():
		if not npc_games.has(npc_id):
			npc_games[npc_id] = 0
	bgm_volume     = d.get("bgm_volume", AudioManager.DEFAULT_BGM_VOLUME)
	se_volume      = d.get("se_volume", AudioManager.DEFAULT_SE_VOLUME)
	assist_enabled = d.get("assist_enabled", true)
	assist_mode    = clampi(int(d.get("assist_mode", 1)), 0, 2)
	reach_cutin_enabled = d.get("reach_cutin_enabled", true)
	if is_equal_approx(bgm_volume, 0.15) and is_equal_approx(se_volume, 0.5):
		bgm_volume = AudioManager.DEFAULT_BGM_VOLUME
		se_volume = AudioManager.DEFAULT_SE_VOLUME

func _normalize_npc_ids(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		var npc_id := _legacy_npc_id(str(id))
		if NPC_DEFS.has(npc_id) and npc_id not in result:
			result.append(npc_id)
	for fallback in DEFAULT_NPC_IDS:
		if result.size() >= 2:
			break
		if fallback not in result:
			result.append(fallback)
	return result.slice(0, 2)

func _normalize_npc_seats(seats: Dictionary) -> Dictionary:
	var result := {"bottom": "", "right": "", "top": ""}
	for seat in result.keys():
		var npc_id := _legacy_npc_id(str(seats.get(seat, "")))
		result[seat] = npc_id if NPC_DEFS.has(npc_id) else ""
	var filled := []
	for seat in ["bottom", "right", "top"]:
		if result[seat] != "":
			filled.append(result[seat])
	if filled.size() != 2:
		result = DEFAULT_NPC_SEATS.duplicate()
	selected_empty_seat = _find_empty_seat(result)
	selected_npc = _seat_npc_ids(result)
	return result

func _legacy_npc_id(id: String) -> String:
	match id:
		"npc_01": return "kuma_def"
		"npc_02": return "kuma_hiyake"
		"npc_03": return "kuma_black"
		"npc_04": return "kuma_hokkyoku"
		"npc_05": return "kuma_megane"
		"npc_06": return "kuma_saibo"
	return id

func _find_empty_seat(seats: Dictionary) -> String:
	for seat in ["bottom", "right", "top"]:
		if str(seats.get(seat, "")) == "":
			return seat
	return "top"

func _seat_npc_ids(seats: Dictionary) -> Array:
	var ids: Array = []
	for seat in ["bottom", "right", "top"]:
		var npc_id := str(seats.get(seat, ""))
		if npc_id != "":
			ids.append(npc_id)
	return ids

func set_npc_seats(seats: Dictionary) -> void:
	selected_npc_seats = _normalize_npc_seats(seats)
	selected_empty_seat = _find_empty_seat(selected_npc_seats)
	selected_npc = _seat_npc_ids(selected_npc_seats)
	save_data()

func get_npc_name(npc_id: String) -> String:
	return NPC_DEFS.get(npc_id, {}).get("name", npc_id)

func get_npc_path(npc_id: String) -> String:
	return NPC_DEFS.get(npc_id, {}).get("path", "res://chara/kuma_def.webp")

func get_npc_path_game(npc_id: String) -> String:
	return NPC_DEFS.get(npc_id, {}).get("path_game", "res://chara/kuma_def2a.webp")

func get_npc_path_menu(npc_id: String) -> String:
	return NPC_DEFS.get(npc_id, {}).get("path_menu", "res://chara/kuma_def2b.webp")

# ============================================================
# 対局後の統計更新
# ============================================================
# npc_ids: 今回の対局に参加したNPCのID配列（例: ["npc_01", "npc_02"]）
func update_after_game(rank: int, total_p_delta: int, chip_delta: int,
		kyoku_count: int, second_score: int, npc_ids: Array = [],
		agari_count: int = 0, houjuu_count: int = 0,
		agari_jun_sum: int = 0, agari_han_sum: int = 0,
		agari_chip_sum: int = 0, score_delta: int = 0) -> void:
	total_games += 1
	rank_count[rank - 1] += 1
	total_p    += total_p_delta
	total_chip += chip_delta
	total_kyoku += kyoku_count
	total_agari += agari_count
	total_houjuu += houjuu_count
	total_agari_jun += agari_jun_sum
	total_agari_han += agari_han_sum
	total_agari_chip += agari_chip_sum
	total_score += score_delta
	# NPC別対戦回数を更新
	for npc_id: String in npc_ids:
		if npc_games.has(npc_id):
			npc_games[npc_id] += 1
	_update_dan(rank, second_score)
	save_data()

func _update_dan(rank: int, second_score: int) -> void:
	var change: int = 0
	if rank == 1:
		change = 4
	elif rank == 2:
		change = 1 if second_score >= 40000 else -1
	else:
		change = -5 if second_score >= 40000 else -3

	dan_points += change

	while dan_points >= 10:
		dan_points -= 10
		if dan <= 10:
			dan += 1
		else:
			dan_plus += 1

	while dan_points < 0:
		dan_points += 10
		if dan_plus > 0:
			dan_plus -= 1
		elif dan > 1:
			dan -= 1
			dan_points = 9
		else:
			dan_points = 0  # 初段0pが下限

func get_dan_name() -> String:
	if dan <= 10:
		return str(dan) + "段"
	return "10段+" + str(dan_plus)

func get_stats_summary() -> String:
	if total_games == 0:
		return "対局なし"
	var avg_rank: float = 0.0
	for i in range(rank_count.size()):
		avg_rank += (i + 1) * rank_count[i]
	avg_rank /= float(total_games)
	var agari_rate: float = 0.0
	if total_kyoku > 0:
		agari_rate = float(total_agari) / float(total_kyoku) * 100.0
	return "対局数: %d  平均着順: %.2f  和了率: %.1f%%  累計P: %d" % [
		total_games, avg_rank, agari_rate, total_p
	]
