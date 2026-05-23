extends Node

var bgm_player: AudioStreamPlayer
var bgm_volume: float = 0.15
var se_volume: float = 0.5
var current_bgm: String = ""

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)

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
	bgm_player.volume_db = linear_to_db(bgm_volume)
	bgm_player.play()

# 1回だけ再生（ループなし）
func play_bgm_once(filename: String) -> void:
	var stream = load("res://assets/bgm/" + filename)
	if stream == null:
		return
	current_bgm = ""
	bgm_player.stream = stream
	bgm_player.volume_db = linear_to_db(bgm_volume)
	bgm_player.play()

func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()
	current_bgm = ""

func play_se(_filename: String) -> void:
	pass
