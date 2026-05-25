extends Node

var bgm_player: AudioStreamPlayer
const DEFAULT_BGM_VOLUME := 0.35
const DEFAULT_SE_VOLUME := 0.30

var bgm_volume: float = DEFAULT_BGM_VOLUME
var se_volume: float = DEFAULT_SE_VOLUME
var current_bgm: String = ""

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)
	_apply_bgm_volume()

func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bgm_volume()

func set_se_volume(value: float) -> void:
	se_volume = clampf(value, 0.0, 1.0)

func set_volumes(new_bgm_volume: float, new_se_volume: float) -> void:
	set_bgm_volume(new_bgm_volume)
	set_se_volume(new_se_volume)

func _apply_bgm_volume() -> void:
	if bgm_player != null:
		bgm_player.volume_db = linear_to_db(bgm_volume)

# BGM終了時にループ再生
func _on_bgm_finished() -> void:
	if current_bgm != "":
		bgm_player.play()

# ループBGM再生（同じファイルが再生中なら何もしない）
func play_bgm(filename: String) -> void:
	play_bgm_path("res://assets/bgm/" + filename)

func play_bgm_path(path: String) -> void:
	if current_bgm == path and bgm_player.playing:
		return
	var stream = load(path)
	if stream == null:
		return
	current_bgm = path
	bgm_player.stream = stream
	_apply_bgm_volume()
	bgm_player.play()

# 1回だけ再生（ループなし）
func play_bgm_once(filename: String) -> void:
	var stream = load("res://assets/bgm/" + filename)
	if stream == null:
		return
	current_bgm = ""
	bgm_player.stream = stream
	_apply_bgm_volume()
	bgm_player.play()

func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()
	current_bgm = ""

func play_se(filename: String, volume_scale: float = 1.0) -> void:
	var path := filename
	if not path.begins_with("res://"):
		path = "res://se/" + filename
	if path.get_extension() == "":
		path += ".ogg"

	var stream = load(path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(clampf(se_volume * volume_scale, 0.0, 1.0))
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
