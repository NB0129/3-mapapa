extends Control

const SCREEN_SIZE := Vector2(1920, 1080)
const ENTRY_H := 130.0
const ENTRY_GAP := 8.0

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = SCREEN_SIZE

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.08, 0.12, 1.0)
	add_child(bg)

	# ヘッダー
	var header := _make_panel(Color(0.08, 0.12, 0.20, 0.95), Rect2(0, 0, 1920, 72))
	add_child(header)
	var title_lbl := _make_label("牌 譜", Vector2(40, 12), 36)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	header.add_child(title_lbl)
	var back_btn := _make_button("← 戻る", Color(0.22, 0.22, 0.30))
	back_btn.position = Vector2(1730, 10)
	back_btn.custom_minimum_size = Vector2(150, 52)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Menu.tscn"))
	header.add_child(back_btn)

	# スクロールエリア
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 90)
	scroll.size = Vector2(1760, 980)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", int(ENTRY_GAP))
	scroll.add_child(vbox)

	var storage := GameLogStorage.new()
	var logs: Array = storage.list_logs()

	if logs.is_empty():
		var empty_lbl := _make_label("保存された牌譜はありません", Vector2(0, 40), 28)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		vbox.add_child(empty_lbl)
		return

	for summary: Dictionary in logs:
		vbox.add_child(_build_entry(summary))

func _build_entry(summary: Dictionary) -> Panel:
	var entry := Panel.new()
	entry.custom_minimum_size = Vector2(1760, ENTRY_H)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.13, 0.20, 0.90)
	s.set_corner_radius_all(8)
	s.set_border_width_all(1)
	s.border_color = Color(0.25, 0.35, 0.55, 0.5)
	entry.add_theme_stylebox_override("panel", s)

	# 日時
	var raw_date: String = str(summary.get("date", ""))
	var disp_date := _format_date(raw_date)
	var date_lbl := _make_label(disp_date, Vector2(20, 12), 28)
	date_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	entry.add_child(date_lbl)

	# プレイヤー名
	var players_arr: Array = summary.get("players", [])
	var names: Array = []
	for p: Dictionary in players_arr:
		names.append(str(p.get("name", "?")))
	var name_str := " vs ".join(names)
	var name_lbl := _make_label(name_str, Vector2(20, 50), 24)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	entry.add_child(name_lbl)

	# スコア
	var final_scores: Array = summary.get("final_scores", [])
	var final_chips: Array = summary.get("final_chips", [])
	var score_parts: Array = []
	for i in range(players_arr.size()):
		var sc: int = int(final_scores[i]) if i < final_scores.size() else 0
		var ch: int = int(final_chips[i]) if i < final_chips.size() else 0
		score_parts.append("%s: %d点 / チップ%+d" % [names[i] if i < names.size() else "?", sc, ch])
	var score_lbl := _make_label("  ".join(score_parts), Vector2(20, 90), 20)
	score_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	entry.add_child(score_lbl)

	# 詳細ボタン
	var path: String = str(summary.get("path", ""))
	var detail_btn := _make_button("詳 細", Color(0.18, 0.32, 0.50))
	detail_btn.position = Vector2(1600, 30)
	detail_btn.custom_minimum_size = Vector2(140, 72)
	detail_btn.add_theme_font_size_override("font_size", 26)
	detail_btn.disabled = (path == "")
	detail_btn.pressed.connect(func(): _open_viewer(path))
	entry.add_child(detail_btn)

	return entry

func _open_viewer(path: String) -> void:
	GameLogViewerScreen.log_path = path
	get_tree().change_scene_to_file("res://scenes/gamelog/GameLogViewerScreen.tscn")

func _format_date(raw: String) -> String:
	# "2026-05-27T19:30:00" or "2026-05-27 19:30:00" → "2026/05/27 19:30"
	if raw.length() < 16:
		return raw
	var d := raw.replace("T", " ")
	return d.substr(0, 4) + "/" + d.substr(5, 2) + "/" + d.substr(8, 2) + " " + d.substr(11, 5)

# ============================================================
# ヘルパー: UI構築
# ============================================================
func _make_panel(color: Color, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_label(text: String, pos: Vector2, font_size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))
	return l

func _make_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(5)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = bg_color.lightened(0.2)
	var pressed_s := style.duplicate() as StyleBoxFlat
	pressed_s.bg_color = bg_color.darkened(0.2)
	var disabled_s := style.duplicate() as StyleBoxFlat
	disabled_s.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.35)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_stylebox_override("disabled", disabled_s)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return btn
