class_name GameLogStorage
extends RefCounted

const SAVE_DIR := "user://gamelogs/"

func save(log_data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var game_id: String = str(log_data.get("game_id", _make_game_id()))
	var path := SAVE_DIR + game_id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GameLogStorage: cannot open for write: " + path)
		return ""
	file.store_string(JSON.stringify(log_data, "\t"))
	file.close()
	return path

func list_logs() -> Array:
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var summary := _load_summary(SAVE_DIR + fname)
			if not summary.is_empty():
				result.append(summary)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("date", "")) > str(b.get("date", "")))
	return result

func load_log(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return {}
	return parsed

func delete_log(path: String) -> void:
	DirAccess.remove_absolute(path)

func _load_summary(path: String) -> Dictionary:
	var log := load_log(path)
	if log.is_empty():
		return {}
	return {
		"path": path,
		"game_id": log.get("game_id", ""),
		"date": log.get("date", ""),
		"players": log.get("players", []),
		"final_scores": log.get("final_scores", []),
		"final_chips": log.get("final_chips", []),
	}

func _make_game_id() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
