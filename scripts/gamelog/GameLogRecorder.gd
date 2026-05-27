class_name GameLogRecorder
extends RefCounted

var _log: Dictionary = {}
var _current_round: Dictionary = {}
var _current_turns: Array = []
var _current_turn: Dictionary = {}

func start_game(players_data: Array) -> void:
	_log = {
		"version": 1,
		"game_id": _make_game_id(),
		"date": Time.get_datetime_string_from_system(),
		"players": [],
		"final_scores": [],
		"final_chips": [],
		"rounds": [],
	}
	for p: Dictionary in players_data:
		_log["players"].append({
			"name": p.get("name", ""),
			"is_npc": p.get("is_npc", false),
			"npc_id": p.get("npc_id", ""),
		})

func start_round(wind: int, kyoku: int, honba: int, dealer: int, scores: Array) -> void:
	_current_round = {
		"wind": wind,
		"kyoku": kyoku,
		"honba": honba,
		"dealer": dealer,
		"initial_scores": scores.duplicate(),
		"turns": [],
		"result": {},
	}
	_current_turns = []
	_current_turn = {}

func record_draw(player: int, tile: Dictionary, hand_after_draw: Array) -> void:
	_flush_turn()
	_current_turn = {
		"player": player,
		"draw": tile.get("id", -1),
		"draw_is_red": tile.get("is_red", false),
		"draw_is_gold": tile.get("is_gold", false),
		"hand_after_draw": _copy_hand(hand_after_draw),
		"discard": -1,
		"discard_is_red": false,
		"discard_is_gold": false,
		"is_riichi": false,
		"is_kita": false,
		"meld": null,
	}

func record_kita(player: int, _kita_tile: Dictionary, hand_after_draw: Array) -> void:
	_flush_turn()
	_current_turn = {
		"player": player,
		"draw": -1,
		"draw_is_red": false,
		"draw_is_gold": false,
		"hand_after_draw": _copy_hand(hand_after_draw),
		"discard": -1,
		"discard_is_red": false,
		"discard_is_gold": false,
		"is_riichi": false,
		"is_kita": true,
		"meld": null,
	}

func record_discard(player: int, tile: Dictionary, is_riichi: bool) -> void:
	if _current_turn.is_empty():
		return
	_current_turn["discard"] = tile.get("id", -1)
	_current_turn["discard_is_red"] = tile.get("is_red", false)
	_current_turn["discard_is_gold"] = tile.get("is_gold", false)
	_current_turn["is_riichi"] = is_riichi
	_flush_turn()

func record_meld(player: int, meld_type: String, tile_id: int, from_player: int) -> void:
	if _current_turn.is_empty():
		_current_turn = {
			"player": player,
			"draw": -1,
			"draw_is_red": false,
			"draw_is_gold": false,
			"hand_after_draw": [],
			"discard": -1,
			"discard_is_red": false,
			"discard_is_gold": false,
			"is_riichi": false,
			"is_kita": false,
			"meld": null,
		}
	_current_turn["meld"] = {
		"type": meld_type,
		"tile_id": tile_id,
		"from_player": from_player,
	}
	_flush_turn()

func end_round(result: Dictionary) -> void:
	_flush_turn()
	_current_round["turns"] = _current_turns.duplicate(true)
	_current_round["result"] = _build_round_result(result)
	_log["rounds"].append(_current_round.duplicate(true))
	_current_round = {}
	_current_turns = []
	_current_turn = {}

func end_game(final_scores: Array, final_chips: Array) -> String:
	_log["final_scores"] = final_scores.duplicate()
	_log["final_chips"] = final_chips.duplicate()
	var storage := GameLogStorage.new()
	return storage.save(_log)

# ---- private ----

func _flush_turn() -> void:
	if not _current_turn.is_empty():
		_current_turns.append(_current_turn.duplicate(true))
		_current_turn = {}

func _copy_hand(hand: Array) -> Array:
	var out: Array = []
	for tile in hand:
		if not (tile is Dictionary):
			continue
		out.append({
			"id": int(tile.get("id", -1)),
			"is_red": bool(tile.get("is_red", false)),
			"is_gold": bool(tile.get("is_gold", false)),
			"is_haku_pochi": bool(tile.get("is_haku_pochi", false)),
		})
	return out

func _build_round_result(result: Dictionary) -> Dictionary:
	var score_before: Array = result.get("score_before", [])
	var score_after: Array = result.get("score_after", score_before)
	var changes := _calc_score_changes(score_before, score_after)

	if result.get("draw", false):
		return {
			"type": "draw",
			"winner": -1, "loser": -1,
			"winning_hand": [], "winning_tile_id": -1,
			"yaku": [], "han": 0,
			"score_changes": changes,
		}

	var winner: int = result.get("winner_idx", -1)
	var loser: int = result.get("loser_idx", -1)
	var type_str := "tsumo" if result.get("is_tsumo", false) else "ron"
	var yaku_names: Array = []
	for y in result.get("yaku", []):
		if y is Dictionary:
			yaku_names.append(str(y.get("name", "")))
		elif y is String:
			yaku_names.append(y)
	return {
		"type": type_str,
		"winner": winner, "loser": loser,
		"winning_hand": _copy_hand(result.get("winning_display_tiles", [])),
		"winning_tile_id": -1,
		"yaku": yaku_names,
		"han": result.get("han", 0),
		"score_changes": changes,
	}

func _calc_score_changes(before: Array, after: Array) -> Array:
	var out: Array = []
	var n := mini(before.size(), after.size())
	for i in range(n):
		out.append(int(after[i]) - int(before[i]))
	return out

func _make_game_id() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
