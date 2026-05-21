extends Control

var _dan_label: Label
var _stats_label: Label
var _rank_label: Label

func _ready() -> void:
	_build_ui()
	_refresh_stats()
	AudioManager.play_bgm("bgm_menyu.wav")

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load("res://assets/bg/bg_title.webp")
	add_child(bg)

	var bg_mask := ColorRect.new()
	bg_mask.position = Vector2.ZERO
	bg_mask.size = Vector2(1920, 1080)
	bg_mask.color = Color(0, 0, 0, 0.35)
	bg_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_mask)

	# タイトルバー
	var header := _make_panel(Color(0, 0, 0, 0.5), Rect2(0, 0, 1920, 100))
	add_child(header)
	var header_lbl := _make_label("三麻シミュレーション", Vector2(760, 20), 48)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	header.add_child(header_lbl)

	# 段位パネル
	var dan_panel := _make_panel(Color(0.1, 0.1, 0.3, 0.8), Rect2(60, 140, 500, 200))
	add_child(dan_panel)
	_make_label("段位", Vector2(20, 10), 24).add_theme_color_override("font_color", Color(0.8, 0.8, 1))
	dan_panel.add_child(_make_label("段位", Vector2(20, 10), 24))
	_dan_label = _make_label("--段", Vector2(20, 60), 56)
	_dan_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	dan_panel.add_child(_dan_label)
	var dan_pt_lbl := _make_label("段位ポイント: --/10", Vector2(20, 140), 20)
	dan_panel.add_child(dan_pt_lbl)
	# 参照保持して後で更新できるよう独立変数に
	_dan_label.set_meta("pt_label", dan_pt_lbl)

	# 戦績パネル
	var stats_panel := _make_panel(Color(0.05, 0.15, 0.05, 0.8), Rect2(60, 360, 800, 340))
	add_child(stats_panel)
	stats_panel.add_child(_make_label("戦績", Vector2(20, 10), 26))
	_stats_label = _make_label("", Vector2(20, 60), 22)
	_stats_label.custom_minimum_size = Vector2(760, 260)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_panel.add_child(_stats_label)

	# 着順分布パネル
	var rank_panel := _make_panel(Color(0.15, 0.05, 0.05, 0.8), Rect2(900, 140, 460, 280))
	add_child(rank_panel)
	rank_panel.add_child(_make_label("着順分布", Vector2(20, 10), 24))
	_rank_label = _make_label("", Vector2(20, 60), 22)
	_rank_label.custom_minimum_size = Vector2(420, 200)
	rank_panel.add_child(_rank_label)

	# 累計Pパネル
	var p_panel := _make_panel(Color(0.15, 0.10, 0.0, 0.8), Rect2(900, 450, 460, 130))
	add_child(p_panel)
	p_panel.add_child(_make_label("累計P", Vector2(20, 10), 22))
	var p_val_label := _make_label("0 P", Vector2(20, 60), 40)
	p_val_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	p_val_label.set_meta("is_p_label", true)
	p_panel.add_child(p_val_label)
	# 後でアクセスするためにメタデータに格納
	p_panel.set_meta("p_label", p_val_label)
	set_meta("p_panel", p_panel)

	# ボタン群
	var btn_play := _make_button("対局開始", Color(0.15, 0.5, 0.15))
	btn_play.position = Vector2(1400, 400)
	btn_play.custom_minimum_size = Vector2(460, 100)
	btn_play.add_theme_font_size_override("font_size", 42)
	btn_play.pressed.connect(_on_play_pressed)
	add_child(btn_play)

	var btn_title := _make_button("タイトルへ", Color(0.3, 0.3, 0.3))
	btn_title.position = Vector2(1400, 540)
	btn_title.custom_minimum_size = Vector2(460, 70)
	btn_title.add_theme_font_size_override("font_size", 28)
	btn_title.pressed.connect(func(): get_tree().change_scene_to_file("res://Title.tscn"))
	add_child(btn_title)

func _refresh_stats() -> void:
	_dan_label.text = SaveData.get_dan_name()
	var pt_lbl: Label = _dan_label.get_meta("pt_label")
	pt_lbl.text = "段位ポイント: " + str(SaveData.dan_points) + " / 10"

	var tg: int = SaveData.total_games
	var lines := ""
	if tg == 0:
		lines = "対局なし\n（対局後に統計が表示されます）"
	else:
		var avg_rank: float = 0.0
		for i in range(SaveData.rank_count.size()):
			avg_rank += (i + 1) * SaveData.rank_count[i]
		avg_rank /= float(tg)
		var agari_rate: float = 0.0
		if SaveData.total_kyoku > 0:
			agari_rate = float(SaveData.total_agari) / float(SaveData.total_kyoku) * 100.0
		lines += "対局数: " + str(tg) + "\n"
		lines += "平均着順: " + "%.2f" % avg_rank + "\n"
		lines += "和了率: " + "%.1f" % agari_rate + "%\n"
		lines += "総局数: " + str(SaveData.total_kyoku)
	_stats_label.text = lines

	var rc: Array = SaveData.rank_count
	var rank_lines := ""
	if SaveData.total_games > 0:
		rank_lines += "1位: " + str(rc[0]) + "回\n"
		rank_lines += "2位: " + str(rc[1]) + "回\n"
		rank_lines += "3位: " + str(rc[2]) + "回"
	else:
		rank_lines = "データなし"
	_rank_label.text = rank_lines

	var p_panel: Panel = get_meta("p_panel")
	var p_val: Label = p_panel.get_meta("p_label")
	p_val.text = str(SaveData.total_p) + " P"

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Game.tscn")

func _make_panel(color: Color, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_label(text: String, pos: Vector2, font_size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	return l

func _make_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	return btn
