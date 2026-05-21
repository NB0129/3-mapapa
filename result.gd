extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.15)
	add_child(bg)

	# ヘッダー
	var header := _make_panel(Color(0, 0, 0, 0.6), Rect2(0, 0, 1920, 100))
	add_child(header)
	var title := _make_label("精　算", Vector2(840, 18), 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	header.add_child(title)

	# 精算テーブル
	var session: Dictionary = GameState.session_result
	var results: Array = session.get("player_results", [])
	_build_result_table(results)

	# 段位変動（プレイヤー0のみ）
	_build_dan_panel()

	# ボタン
	var btn_menu := _make_button("メニューへ", Color(0.2, 0.4, 0.7))
	btn_menu.position = Vector2(600, 950)
	btn_menu.custom_minimum_size = Vector2(320, 80)
	btn_menu.add_theme_font_size_override("font_size", 32)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Menu.tscn"))
	add_child(btn_menu)

	var btn_again := _make_button("もう一度", Color(0.15, 0.5, 0.15))
	btn_again.position = Vector2(1000, 950)
	btn_again.custom_minimum_size = Vector2(320, 80)
	btn_again.add_theme_font_size_override("font_size", 32)
	btn_again.pressed.connect(func(): get_tree().change_scene_to_file("res://Game.tscn"))
	add_child(btn_again)

func _build_result_table(results: Array) -> void:
	if results.is_empty(): return

	# ヘッダー行
	var col_x: Array = [60, 140, 380, 600, 780, 980, 1140, 1340, 1560, 1760]
	var headers: Array = ["着", "名前", "最終点", "点数±", "ウマ", "収支計", "チップ", "点棒P", "チップP", "合計P"]
	var header_row := _make_panel(Color(0.1, 0.1, 0.3, 0.9), Rect2(40, 110, 1840, 60))
	add_child(header_row)
	for i in range(headers.size()):
		var lbl := _make_label(headers[i], Vector2(col_x[i] - 40, 12), 20)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		header_row.add_child(lbl)

	# データ行（着順でソート済み）
	var sorted_results: Array = results.duplicate()
	sorted_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank < b.rank)

	var row_colors: Array = [Color(0.8, 0.7, 0.1, 0.15), Color(0.5, 0.5, 0.5, 0.1),
							  Color(0.5, 0.1, 0.1, 0.15)]
	for ri in range(sorted_results.size()):
		var pr: Dictionary = sorted_results[ri]
		var row_y: float = 180.0 + ri * 120.0
		var row_bg := _make_panel(row_colors[min(ri, 2)], Rect2(40, row_y, 1840, 110))
		add_child(row_bg)

		var rank_text: String = str(pr.rank) + "位"
		var score_delta_text: String = ("+" if pr.score_delta >= 0 else "") + str(pr.score_delta)
		var uma_text: String = ("+" if pr.uma >= 0 else "") + str(pr.uma)
		var chips_text: String = ("+" if pr.chips >= 0 else "") + str(pr.chips) + "枚"
		var score_p_text: String = ("+" if pr.score_p >= 0 else "") + str(pr.score_p) + "P"
		var chip_p_text: String = ("+" if pr.chip_p >= 0 else "") + str(pr.chip_p) + "P"
		var total_p_text: String = ("+" if pr.total_p >= 0 else "") + str(pr.total_p) + "P"

		var values: Array = [
			rank_text, pr.name, str(pr.final_score) + "点",
			score_delta_text, uma_text,
			("+" if (pr.score_delta) >= 0 else "") + str(pr.score_delta) + "点",
			chips_text, score_p_text, chip_p_text, total_p_text
		]

		for ci in range(values.size()):
			var cell_x: float = col_x[ci] - 40.0
			var cell_lbl := _make_label(values[ci], Vector2(cell_x, 28), 22)
			# 色分け
			var val_color := Color(0.95, 0.95, 0.9)
			if ci == 0:
				val_color = Color(1.0, 0.9, 0.3) if ri == 0 else Color(0.8, 0.8, 0.8)
			elif ci >= 3 and ci <= 5:
				if values[ci].begins_with("+"):
					val_color = Color(0.4, 1.0, 0.5)
				elif values[ci].begins_with("-"):
					val_color = Color(1.0, 0.4, 0.4)
			elif ci == 9:
				if pr.total_p >= 0:
					val_color = Color(0.4, 1.0, 0.5)
				else:
					val_color = Color(1.0, 0.4, 0.4)
			cell_lbl.add_theme_color_override("font_color", val_color)
			row_bg.add_child(cell_lbl)

func _build_dan_panel() -> void:
	var dan_panel := _make_panel(Color(0.1, 0.05, 0.2, 0.8), Rect2(40, 560, 880, 360))
	add_child(dan_panel)
	dan_panel.add_child(_make_label("段位", Vector2(20, 10), 24))
	var dan_lbl := _make_label(SaveData.get_dan_name(), Vector2(20, 60), 56)
	dan_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	dan_panel.add_child(dan_lbl)

	var pt_text: String = "段位ポイント: " + str(SaveData.dan_points) + " / 10"
	dan_panel.add_child(_make_label(pt_text, Vector2(20, 150), 24))

	# 着順分布
	var rc: Array = SaveData.rank_count
	var tg: int = SaveData.total_games
	var dist_text := ""
	if tg > 0:
		dist_text = "通算 %d局  1位: %d  2位: %d  3位: %d" % [tg, rc[0], rc[1], rc[2]]
		var avg_rank: float = float(rc[0] * 1 + rc[1] * 2 + rc[2] * 3) / float(tg)
		dist_text += "\n平均着順: %.2f" % avg_rank
	else:
		dist_text = "戦績なし"
	dan_panel.add_child(_make_label(dist_text, Vector2(20, 240), 22))

	# 累計P
	var p_panel := _make_panel(Color(0.15, 0.10, 0.0, 0.8), Rect2(960, 560, 940, 360))
	add_child(p_panel)
	p_panel.add_child(_make_label("累計P", Vector2(20, 10), 24))
	var p_lbl := _make_label(str(SaveData.total_p) + " P", Vector2(20, 60), 64)
	var p_color := Color(0.4, 1.0, 0.5) if SaveData.total_p >= 0 else Color(1.0, 0.4, 0.4)
	p_lbl.add_theme_color_override("font_color", p_color)
	p_panel.add_child(p_lbl)

	var today_session: Dictionary = GameState.session_result
	var player_results: Array = today_session.get("player_results", [])
	if not player_results.is_empty():
		var pr: Dictionary = player_results[0]
		var today_text := "今回: " + ("+" if pr.total_p >= 0 else "") + str(pr.total_p) + " P"
		var today_lbl := _make_label(today_text, Vector2(20, 200), 30)
		var tc := Color(0.4, 1.0, 0.5) if pr.total_p >= 0 else Color(1.0, 0.4, 0.4)
		today_lbl.add_theme_color_override("font_color", tc)
		p_panel.add_child(today_lbl)

func _make_panel(color: Color, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
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
