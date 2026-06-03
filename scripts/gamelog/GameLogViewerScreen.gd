class_name GameLogViewerScreen
extends Control

static var log_path: String = ""

const SCREEN_SIZE  := Vector2(1920, 1080)
const TILE_W_HAND  := 128.0
const TILE_H_HAND  := 176.0
const TILE_W_DISC  := 44.0
const TILE_H_DISC  := 61.0
const TILE_W_MELD  := 44.0
const TILE_H_MELD  := 61.0
const TILE_GAP     := 3.0
const EFF_W        := 33.0
const EFF_H        := 45.0
const LEFT_W       := 470.0
const RIGHT_X      := 1410.0
const RIGHT_W      := 498.0
const CONTENT_Y    := 148.0
const BOTTOM_Y     := 750.0

var _log: Dictionary = {}
var _round_idx: int = 0
var _turn_idx: int = -1
var _sim_results: Array = []
var _tile_texture_cache: Dictionary = {}

var _info_bar_lbl: Label
var _result_info_lbl: Label
var _hand_area: Control
var _upper_discard_area: Control
var _right_discard_area: Control
var _player_discard_area: Control
var _meld_area: Control
var _slider: HSlider
var _nav_prev_btn: Button
var _nav_next_btn: Button
var _study_btn: Button
var _tab_btns: Array = []
var _result_list: VBoxContainer
var _wall_lbl: Label
var _dead_info_vbox: VBoxContainer
var _center_round_lbl: Label
var _center_wall_lbl: Label
var _center_turn_lbl: Label


func _ready() -> void:
	_load_log()
	_build_ui()
	_select_round(0)


func _load_log() -> void:
	if log_path == "":
		return
	var storage := GameLogStorage.new()
	_log = storage.load_log(log_path)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = SCREEN_SIZE

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.28, 0.12, 1.0)
	bg.z_index = -30
	add_child(bg)

	if ResourceLoader.exists("res://assets/bg/bg_takujou.webp"):
		var table_tex := TextureRect.new()
		table_tex.texture = load("res://assets/bg/bg_takujou.webp")
		table_tex.position = Vector2(-288, -202)
		table_tex.size = Vector2(2496, 1404)
		table_tex.z_index = -20
		add_child(table_tex)

	_build_header()
	_build_tabs()
	_build_info_bar()
	_build_left_panel()
	_build_center_area()
	_build_right_panel()
	_build_bottom_area()


func _build_header() -> void:
	var header := _make_panel(Color(0.04, 0.10, 0.06, 0.92), Rect2(0, 0, 1920, 60))
	add_child(header)

	var date_str := str(_log.get("date", ""))
	var disp := _format_date(date_str)
	var players_arr: Array = _log.get("players", [])
	var names: Array = []
	for p: Dictionary in players_arr:
		names.append(str(p.get("name", "?")))
	var title_lbl := _make_label("牌譜: " + disp + "  " + " vs ".join(names), Vector2(24, 12), 24)
	title_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.70))
	header.add_child(title_lbl)

	var back_btn := _make_button("← 戻る", Color(0.15, 0.22, 0.15))
	back_btn.position = Vector2(1740, 6)
	back_btn.custom_minimum_size = Vector2(150, 48)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/gamelog/GameLogListScreen.tscn"))
	header.add_child(back_btn)


func _build_tabs() -> void:
	var tab_bar := _make_panel(Color(0.05, 0.14, 0.07, 0.88), Rect2(0, 60, 1920, 50))
	add_child(tab_bar)
	_tab_btns.clear()

	var rounds: Array = _log.get("rounds", [])
	var x := 12.0
	for i in range(rounds.size()):
		var r: Dictionary = rounds[i]
		var label := _round_label(int(r.get("wind", 0)), int(r.get("kyoku", 1)))
		var tbtn := _make_button(label, Color(0.10, 0.25, 0.12))
		tbtn.position = Vector2(x, 4)
		tbtn.custom_minimum_size = Vector2(110, 42)
		tbtn.add_theme_font_size_override("font_size", 18)
		tbtn.pressed.connect(func(idx := i): _select_round(idx))
		tab_bar.add_child(tbtn)
		_tab_btns.append(tbtn)
		x += 118.0


func _build_info_bar() -> void:
	var bar := _make_panel(Color(0.04, 0.12, 0.05, 0.78), Rect2(0, 110, 1920, 38))
	add_child(bar)
	_info_bar_lbl = _make_label("", Vector2(20, 6), 20)
	_info_bar_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 1.0))
	bar.add_child(_info_bar_lbl)
	_result_info_lbl = _make_label("", Vector2(900, 6), 20)
	_result_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	bar.add_child(_result_info_lbl)


func _build_left_panel() -> void:
	var panel := _make_panel(Color(0.02, 0.08, 0.03, 0.74), Rect2(12, CONTENT_Y, LEFT_W, 560))
	add_child(panel)
	panel.add_child(_make_label("打牌候補", Vector2(14, 8), 24))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 44)
	scroll.size = Vector2(LEFT_W - 12, 510)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_result_list = VBoxContainer.new()
	_result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_result_list)


func _build_center_area() -> void:
	var panel := Control.new()
	panel.position = Vector2.ZERO
	panel.size = SCREEN_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var upper_discard_panel := Control.new()
	upper_discard_panel.position = Vector2(820, 163)
	upper_discard_panel.size = Vector2(400, 170)
	panel.add_child(upper_discard_panel)
	_upper_discard_area = Control.new()
	_upper_discard_area.position = Vector2.ZERO
	_upper_discard_area.size = upper_discard_panel.size
	upper_discard_panel.add_child(_upper_discard_area)

	var right_discard_panel := Control.new()
	right_discard_panel.position = Vector2(1124, 366)
	right_discard_panel.size = Vector2(490, 260)
	panel.add_child(right_discard_panel)
	_right_discard_area = Control.new()
	_right_discard_area.position = Vector2.ZERO
	_right_discard_area.size = right_discard_panel.size
	right_discard_panel.add_child(_right_discard_area)

	var center := _make_panel(Color(0.0, 0.05, 0.15, 0.80), Rect2(810, 350, 300, 300))
	panel.add_child(center)
	_center_round_lbl = _make_label("", Vector2(20, 66), 70)
	_center_round_lbl.size = Vector2(260, 86)
	_center_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_round_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_round_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	center.add_child(_center_round_lbl)
	_center_wall_lbl = _make_label("", Vector2(20, 156), 40)
	_center_wall_lbl.size = Vector2(260, 54)
	_center_wall_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_wall_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_child(_center_wall_lbl)
	_center_turn_lbl = _make_label("", Vector2(20, 226), 34)
	_center_turn_lbl.size = Vector2(260, 48)
	_center_turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_turn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_turn_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 1.0))
	_center_turn_lbl.visible = false
	center.add_child(_center_turn_lbl)

	var player_discard_panel := Control.new()
	player_discard_panel.position = Vector2(820, 655)
	player_discard_panel.size = Vector2(400, 175)
	panel.add_child(player_discard_panel)
	_player_discard_area = Control.new()
	_player_discard_area.position = Vector2.ZERO
	_player_discard_area.size = player_discard_panel.size
	player_discard_panel.add_child(_player_discard_area)


func _build_right_panel() -> void:
	var panel := _make_panel(Color(0.02, 0.08, 0.03, 0.74), Rect2(RIGHT_X, CONTENT_Y, RIGHT_W, 560))
	add_child(panel)
	panel.add_child(_make_label("局情報", Vector2(14, 8), 36))

	_wall_lbl = _make_label("残り山: —", Vector2(14, 54), 20)
	_wall_lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	_wall_lbl.add_theme_font_size_override("font_size", 40)
	panel.add_child(_wall_lbl)

	panel.add_child(_make_label("見えている牌", Vector2(14, 116), 30))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 154)
	scroll.size = Vector2(RIGHT_W - 12, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_dead_info_vbox = VBoxContainer.new()
	_dead_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dead_info_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_dead_info_vbox)


func _build_bottom_area() -> void:
	var hand_mask := _make_panel(Color(0.0, 0.0, 0.0, 0.50), Rect2(10, 881, 1900, 199))
	add_child(hand_mask)

	var meld_bg := _make_panel(Color(0.04, 0.10, 0.05, 0.55), Rect2(20, 802, 1060, 72))
	add_child(meld_bg)
	meld_bg.add_child(_make_label("副露:", Vector2(8, 8), 15))
	_meld_area = Control.new()
	_meld_area.position = Vector2(64, 6)
	_meld_area.size = Vector2(988, 61)
	meld_bg.add_child(_meld_area)

	var hand_bg := Control.new()
	hand_bg.position = Vector2(10, 750)
	hand_bg.size = Vector2(1900, 330)
	add_child(hand_bg)
	_hand_area = Control.new()
	_hand_area.position = Vector2(10, 136)
	_hand_area.size = Vector2(1880, TILE_H_HAND)
	hand_bg.add_child(_hand_area)

	var nav := _make_panel(Color(0.04, 0.12, 0.05, 0.80), Rect2(530, 732, 860, 56))
	add_child(nav)

	_nav_prev_btn = _make_button("◀", Color(0.15, 0.28, 0.15))
	_nav_prev_btn.position = Vector2(10, 4)
	_nav_prev_btn.custom_minimum_size = Vector2(70, 48)
	_nav_prev_btn.add_theme_font_size_override("font_size", 26)
	_nav_prev_btn.pressed.connect(_on_prev_turn)
	nav.add_child(_nav_prev_btn)

	_nav_next_btn = _make_button("▶", Color(0.15, 0.28, 0.15))
	_nav_next_btn.position = Vector2(86, 4)
	_nav_next_btn.custom_minimum_size = Vector2(70, 48)
	_nav_next_btn.add_theme_font_size_override("font_size", 26)
	_nav_next_btn.pressed.connect(_on_next_turn)
	nav.add_child(_nav_next_btn)

	_slider = HSlider.new()
	_slider.position = Vector2(168, 14)
	_slider.size = Vector2(420, 30)
	_slider.min_value = -1
	_slider.max_value = 0
	_slider.step = 1
	_slider.value = -1
	_slider.value_changed.connect(_on_slider_changed)
	nav.add_child(_slider)

	_study_btn = _make_button("🔍 検討", Color(0.28, 0.18, 0.06))
	_study_btn.position = Vector2(602, 4)
	_study_btn.custom_minimum_size = Vector2(248, 48)
	_study_btn.add_theme_font_size_override("font_size", 22)
	_study_btn.pressed.connect(_run_sim_analysis)
	nav.add_child(_study_btn)


# ============================================================
# Round / Turn navigation
# ============================================================

func _select_round(idx: int) -> void:
	_round_idx = idx
	_turn_idx = -1
	_sim_results.clear()
	for ch in _result_list.get_children():
		ch.queue_free()
	_update_tab_highlight()
	var turns: Array = _current_turns()
	_slider.max_value = turns.size() - 1
	_slider.value = -1
	_refresh_display()


func _current_turns() -> Array:
	var rounds: Array = _log.get("rounds", [])
	if _round_idx >= rounds.size():
		return []
	return rounds[_round_idx].get("turns", [])


func _on_prev_turn() -> void:
	_go_to_turn(_turn_idx - 1)


func _on_next_turn() -> void:
	_go_to_turn(_turn_idx + 1)


func _on_slider_changed(val: float) -> void:
	var t := int(val)
	if t != _turn_idx:
		_go_to_turn(t)


func _go_to_turn(idx: int) -> void:
	var turns: Array = _current_turns()
	idx = clampi(idx, -1, turns.size() - 1)
	_turn_idx = idx
	_slider.set_value_no_signal(float(_turn_idx))
	_sim_results.clear()
	for ch in _result_list.get_children():
		ch.queue_free()
	_refresh_display()


# ============================================================
# Analysis
# ============================================================

func _run_sim_analysis() -> void:
	var turns: Array = _current_turns()
	if _turn_idx < 0 or _turn_idx >= turns.size():
		return
	var turn: Dictionary = turns[_turn_idx]
	if turn.get("player", -1) != 0:
		return
	var hand_arr: Array = turn.get("hand_after_draw", [])
	if hand_arr.size() != 14:
		return

	for ch in _result_list.get_children():
		ch.queue_free()
	var loading_lbl := _make_label("解析中...", Vector2(10, 20), 28)
	loading_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	_result_list.add_child(loading_lbl)

	call_deferred("_run_sim_analysis_deferred")

func _run_sim_analysis_deferred() -> void:
	var turns: Array = _current_turns()
	if _turn_idx < 0 or _turn_idx >= turns.size():
		return
	var turn: Dictionary = turns[_turn_idx]
	var hand_arr: Array = turn.get("hand_after_draw", [])

	var hand_typed: Array = []
	for t in hand_arr:
		hand_typed.append({
			"id": int(t.get("id", -1)),
			"is_red": bool(t.get("is_red", false)),
			"is_gold": bool(t.get("is_gold", false)),
			"is_haku_pochi": bool(t.get("is_haku_pochi", false)),
		})

	var dead_tiles := _build_dead_tiles_from_log(turns, _turn_idx)
	var remaining_wall := _calc_remaining_wall(turns, _turn_idx)

	var analyzer := SanmaAnalyzer.new()
	_sim_results = analyzer.evaluate_discards(hand_typed, remaining_wall, dead_tiles)

	_rebuild_sim_list(int(turn.get("discard", -1)))


func _rebuild_sim_list(actual_discard_id: int) -> void:
	for ch in _result_list.get_children():
		ch.queue_free()

	for i in range(_sim_results.size()):
		var r: Dictionary = _sim_results[i]
		var is_best: bool = (i == 0)
		var is_actual: bool = (actual_discard_id >= 0 and int(r.get("tile_id", -1)) == actual_discard_id)
		var shanten_val: int = int(r.get("shanten", 99))
		var eff: Dictionary = r.get("effective_tiles", {})
		var eff_keys: Array = eff.keys()
		var panel_w := 444.0
		var tile_slot := EFF_W + 36.0
		var eff_cols := maxi(1, int(panel_w / tile_slot))
		var eff_rows_n := ceili(float(eff_keys.size()) / float(eff_cols)) if eff_keys.size() > 0 else 0
		var row_h := 118.0 + float(eff_rows_n) * (EFF_H + 8.0) + 8.0

		var row := Panel.new()
		row.custom_minimum_size = Vector2(panel_w, row_h)

		var s := StyleBoxFlat.new()
		if is_best:
			s.bg_color = Color(0.08, 0.20, 0.10, 0.92)
			s.set_border_width_all(2)
			s.border_color = Color(0.4, 0.9, 0.4, 0.8)
		elif is_actual:
			s.bg_color = Color(0.20, 0.16, 0.05, 0.92)
			s.set_border_width_all(2)
			s.border_color = Color(0.9, 0.7, 0.2, 0.8)
		else:
			s.bg_color = Color(0.06, 0.10, 0.07, 0.85)
		s.set_corner_radius_all(5)
		row.add_theme_stylebox_override("panel", s)

		# 1行目: 牌画像 + マーカー + 打牌名 + 向聴テキスト
		var tile_d := {"id": int(r.get("tile_id", -1)), "is_red": false, "is_gold": false, "is_haku_pochi": false}
		var img := TextureRect.new()
		img.position = Vector2(6, 6)
		img.size = Vector2(66, 90)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = _get_tile_texture(tile_d)
		row.add_child(img)

		var text_x := 82.0
		if is_best:
			var star := _make_label("★", Vector2(text_x, 6), 22)
			star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			row.add_child(star)
			text_x += 34.0
		elif is_actual:
			var act := _make_label("→実", Vector2(text_x, 6), 18)
			act.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
			row.add_child(act)
			text_x += 42.0

		var name_lbl := _make_label(str(r.get("tile_name", "")), Vector2(text_x, 6), 32)
		row.add_child(name_lbl)

		var shan_lbl := _make_label(str(r.get("shanten_text", "")), Vector2(text_x, 44), 26)
		shan_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if shanten_val == 0 else Color(0.80, 0.80, 0.65))
		row.add_child(shan_lbl)

		# 2行目: 有効牌枚数 + 次巡確率
		var stat_txt := "有効牌%d枚（期待%.1f枚）　%s%.2f%%" % [
			int(r.get("effective_count", 0)),
			float(r.get("effective_count_expected", 0.0)),
			_next_turn_label(shanten_val),
			float(r.get("next_tenpai_rate", 0.0)) * 100.0,
		]
		var stat_lbl := _make_label(stat_txt, Vector2(8, 92), 22)
		stat_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
		row.add_child(stat_lbl)

		# 3行目以降: 有効牌グリッド（画像 + ×枚数、折り返しあり）
		var ex := 6.0
		var ey := 118.0
		var col := 0
		for gid: int in eff_keys:
			if col >= eff_cols:
				col = 0
				ex = 6.0
				ey += EFF_H + 8.0
			var tex := _get_tile_texture({"id": gid, "is_red": false, "is_gold": false, "is_haku_pochi": false})
			if tex:
				var ti := TextureRect.new()
				ti.position = Vector2(ex, ey)
				ti.size = Vector2(EFF_W, EFF_H)
				ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ti.texture = tex
				row.add_child(ti)
			var cnt_lbl := _make_label("×%d" % int(eff[gid]), Vector2(ex + EFF_W + 2, ey + int(EFF_H) - 18), 24)
			cnt_lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
			row.add_child(cnt_lbl)
			ex += tile_slot
			col += 1

		_result_list.add_child(row)

	if actual_discard_id >= 0 and _sim_results.size() > 1:
		var best: Dictionary = _sim_results[0]
		var actual: Dictionary = {}
		for r2: Dictionary in _sim_results:
			if r2.get("tile_id", -1) == actual_discard_id:
				actual = r2
				break
		if not actual.is_empty() and actual.get("tile_id", -1) != best.get("tile_id", -1):
			var diff: int = best.get("effective_count", 0) - actual.get("effective_count", 0)
			var cmp := Panel.new()
			cmp.custom_minimum_size = Vector2(LEFT_W - 20, 44)
			var cs := StyleBoxFlat.new()
			cs.bg_color = Color(0.18, 0.12, 0.04, 0.9)
			cs.set_corner_radius_all(5)
			cmp.add_theme_stylebox_override("panel", cs)
			var txt := "実際: %s（%s・%d枚）　最善: %s（%s・%d枚）　差 -%d枚" % [
				actual.get("tile_name", "?"), actual.get("shanten_text", "?"), actual.get("effective_count", 0),
				best.get("tile_name", "?"), best.get("shanten_text", "?"), best.get("effective_count", 0),
				diff,
			]
			var cl := _make_label(txt, Vector2(10, 10), 15)
			cl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			cmp.add_child(cl)
			_result_list.add_child(cmp)


# ============================================================
# Display refresh
# ============================================================

func _refresh_display() -> void:
	var turns: Array = _current_turns()
	_nav_prev_btn.disabled = (_turn_idx <= -1)
	_nav_next_btn.disabled = (_turn_idx >= turns.size() - 1)

	var rounds: Array = _log.get("rounds", [])
	if _round_idx < rounds.size():
		var rd: Dictionary = rounds[_round_idx]
		var wind_str := _round_label(int(rd.get("wind", 0)), int(rd.get("kyoku", 1)))
		var honba: int = int(rd.get("honba", 0))
		var honba_str := (" %d本場" % honba) if honba > 0 else ""
		if _turn_idx < 0:
			_info_bar_lbl.text = "%s%s  初期状態" % [wind_str, honba_str]
		elif _turn_idx < turns.size():
			var t: Dictionary = turns[_turn_idx]
			var p_name := _player_name(int(t.get("player", 0)))
			var info_txt := "%s%s  %d巡目  %s" % [wind_str, honba_str, _turn_idx + 1, p_name]
			if int(t.get("is_kita", false)):
				info_txt += " 北抜き"
			elif int(t.get("draw", -1)) >= 0:
				var draw_tile := {
					"id": int(t.get("draw", -1)),
					"is_red": bool(t.get("draw_is_red", false)),
					"is_gold": bool(t.get("draw_is_gold", false)),
					"is_haku_pochi": false
				}
				info_txt += " ツモ: " + MahjongLogic.get_tile_name(draw_tile)
			var disc_id: int = int(t.get("discard", -1))
			if disc_id >= 0:
				var disc_tile := {
					"id": disc_id,
					"is_red": bool(t.get("discard_is_red", false)),
					"is_gold": bool(t.get("discard_is_gold", false)),
					"is_haku_pochi": false
				}
				info_txt += "  打: " + MahjongLogic.get_tile_name(disc_tile)
				if bool(t.get("is_riichi", false)):
					info_txt += " [立直]"
			_info_bar_lbl.text = info_txt

		if _turn_idx == turns.size() - 1:
			var result: Dictionary = rd.get("result", {})
			_result_info_lbl.text = _format_round_result(result, _log.get("players", []))
		else:
			_result_info_lbl.text = ""

	var can_study := false
	if _turn_idx >= 0 and _turn_idx < turns.size():
		var t: Dictionary = turns[_turn_idx]
		var hand_size := (t.get("hand_after_draw", []) as Array).size()
		can_study = (int(t.get("player", -1)) == 0 and hand_size >= 1 and hand_size % 3 == 2)
	_study_btn.disabled = not can_study

	_rebuild_center_info(turns)
	_rebuild_hand_view(turns)
	_rebuild_discard_view(turns)
	_rebuild_meld_view(turns)
	_rebuild_right_info(turns)


func _rebuild_center_info(turns: Array) -> void:
	if _center_round_lbl == null:
		return
	var rounds: Array = _log.get("rounds", [])
	if _round_idx >= rounds.size():
		return
	var rd: Dictionary = rounds[_round_idx]
	var honba: int = int(rd.get("honba", 0))
	_center_round_lbl.text = _round_label(int(rd.get("wind", 0)), int(rd.get("kyoku", 1)))
	_center_wall_lbl.text = "%d本場\n残り山%d枚" % [honba, _calc_remaining_wall(turns, _turn_idx)]
	_center_turn_lbl.text = ""


func _rebuild_right_info(turns: Array) -> void:
	var remaining := _calc_remaining_wall(turns, _turn_idx)
	_wall_lbl.text = "残り山: %d枚" % remaining

	for ch in _dead_info_vbox.get_children():
		ch.queue_free()

	if _turn_idx < 0:
		return

	var dead := _build_dead_tiles_from_log(turns, _turn_idx)
	var counts: Dictionary = dead.get("counts", {})
	if counts.is_empty():
		return

	var sorted_ids: Array = counts.keys()
	sorted_ids.sort()
	var row_ctrl: Control = null
	var ex := 0.0
	var col := 0
	for gid: int in sorted_ids:
		var cnt: int = int(counts[gid])
		if cnt <= 0:
			continue
		if col == 0 or row_ctrl == null:
			row_ctrl = Control.new()
			row_ctrl.custom_minimum_size = Vector2(RIGHT_W - 12, 64)
			_dead_info_vbox.add_child(row_ctrl)
			ex = 0.0
		var tex := _get_tile_texture({"id": gid, "is_red": false, "is_gold": false, "is_haku_pochi": false})
		if tex:
			var ti := TextureRect.new()
			ti.position = Vector2(ex, 0)
			ti.size = Vector2(44, 60)
			ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ti.texture = tex
			row_ctrl.add_child(ti)
		var cl := _make_label("×%d" % cnt, Vector2(ex + 23, 6), 13)
		cl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		cl.position = Vector2(ex + 46, 18)
		cl.add_theme_font_size_override("font_size", 26)
		row_ctrl.add_child(cl)
		ex += 92.0
		col += 1
		if col >= 5:
			col = 0


func _rebuild_hand_view(turns: Array) -> void:
	for ch in _hand_area.get_children():
		ch.queue_free()

	var hand_tiles: Array = []
	var t_idx_found := -1
	for i in range(mini(_turn_idx + 1, turns.size()) - 1, -1, -1):
		var t: Dictionary = turns[i]
		if int(t.get("player", -1)) == 0:
			var h: Array = t.get("hand_after_draw", [])
			if h.size() > 0:
				hand_tiles = h
				t_idx_found = i
				break
	if hand_tiles.is_empty():
		return

	var discard_id_to_hide := -1
	if t_idx_found != _turn_idx and t_idx_found >= 0 and t_idx_found < turns.size():
		discard_id_to_hide = int(turns[t_idx_found].get("discard", -1))

	var display_hand: Array = []
	var removed := false
	for td in hand_tiles:
		var tid := int((td as Dictionary).get("id", -1))
		if not removed and discard_id_to_hide >= 0 and tid == discard_id_to_hide:
			removed = true
			continue
		display_hand.append(td)

	display_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0)))

	var x := 0.0
	for tile_d in display_hand:
		var td: Dictionary = tile_d as Dictionary
		var tex := _get_tile_texture({
			"id": int(td.get("id", -1)),
			"is_red": bool(td.get("is_red", false)),
			"is_gold": bool(td.get("is_gold", false)),
			"is_haku_pochi": bool(td.get("is_haku_pochi", false))
		})
		var trect := TextureRect.new()
		trect.position = Vector2(x, 0)
		trect.size = Vector2(TILE_W_HAND, TILE_H_HAND)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tex:
			trect.texture = tex
		_hand_area.add_child(trect)
		x += TILE_W_HAND + TILE_GAP


func _rebuild_discard_view(turns: Array) -> void:
	for area in [_player_discard_area, _right_discard_area, _upper_discard_area]:
		if area == null:
			continue
		for ch in area.get_children():
			ch.queue_free()
	var max_t := mini(_turn_idx + 1, turns.size())
	var discards: Array = [[], [], []]
	for i in range(max_t):
		var t: Dictionary = turns[i]
		var p: int = int(t.get("player", -1))
		if p < 0 or p >= 3:
			continue
		var disc_id: int = int(t.get("discard", -1))
		if disc_id >= 0:
			discards[p].append({
				"id": disc_id,
				"is_red": bool(t.get("discard_is_red", false)),
				"is_gold": bool(t.get("discard_is_gold", false)),
				"is_riichi": bool(t.get("is_riichi", false)),
				"is_haku_pochi": false,
			})

	_draw_discard_grid(_player_discard_area, discards[0], 0.0, false, false, false, false)
	_draw_discard_grid(_right_discard_area, discards[1], -90.0, true, false, false, true)
	_draw_discard_grid(_upper_discard_area, discards[2], 180.0, false, true, true, false)


func _draw_discard_grid(area: Control, discards: Array, rotation_deg: float, vertical_first: bool, bottom_up: bool, reverse_x: bool, reverse_y: bool) -> void:
	if area == null:
		return
	var max_per_stripe := 6
	var tile_w := TILE_W_DISC
	var tile_h := TILE_H_DISC
	var x_step := tile_w + TILE_GAP
	var y_step := tile_h + TILE_GAP
	if vertical_first:
		x_step = tile_h + TILE_GAP
		y_step = tile_w + TILE_GAP
	var total_stripes := maxi(1, int(ceil(discards.size() / float(max_per_stripe))))
	var col := 0
	var row := 0
	for td: Dictionary in discards:
		var display_row := row
		var display_col := col
		if bottom_up:
			display_row = 2 - row
		if reverse_y:
			display_row = max_per_stripe - 1 - row
		if reverse_x:
			display_col = (total_stripes - 1 - col) if vertical_first else (max_per_stripe - 1 - col)
		var center := Vector2(display_col * x_step + tile_w / 2.0, display_row * y_step + tile_h / 2.0)
		var trect := TextureRect.new()
		trect.position = center - Vector2(tile_w, tile_h) / 2.0
		trect.size = Vector2(tile_w, tile_h)
		trect.pivot_offset = Vector2(tile_w / 2.0, tile_h / 2.0)
		trect.rotation_degrees = rotation_deg + (90.0 if bool(td.get("is_riichi", false)) else 0.0)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trect.texture = _get_tile_texture(td)
		if bool(td.get("is_riichi", false)):
			trect.modulate = Color(1.0, 0.85, 0.3)
		area.add_child(trect)
		if vertical_first:
			row += 1
			if row >= max_per_stripe:
				row = 0
				col += 1
		else:
			col += 1
			if col >= max_per_stripe:
				col = 0
				row += 1


func _rebuild_meld_view(turns: Array) -> void:
	for ch in _meld_area.get_children():
		ch.queue_free()
	var max_t := mini(_turn_idx + 1, turns.size())
	var melds: Array = [[], [], []]
	for i in range(max_t):
		var t: Dictionary = turns[i]
		var p: int = int(t.get("player", -1))
		if p < 0 or p >= 3:
			continue
		var meld = t.get("meld", null)
		if meld != null and meld is Dictionary:
			melds[p].append(meld)

	var x := 0.0
	for p in range(3):
		if melds[p].is_empty():
			continue
		var pname := _player_name(p)
		var lbl := _make_label(pname + ":", Vector2(x, 0), 14)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
		_meld_area.add_child(lbl)
		x += 58.0
		for meld: Dictionary in melds[p]:
			var tile_id: int = int(meld.get("tile_id", -1))
			var type_str: String = str(meld.get("type", ""))
			var count := 4 if type_str in ["ankan", "minkan", "kakan"] else 3
			for _j in range(count):
				var tex := _get_tile_texture({"id": tile_id, "is_red": false, "is_gold": false, "is_haku_pochi": false})
				var trect := TextureRect.new()
				trect.position = Vector2(x, 0)
				trect.size = Vector2(TILE_W_MELD, TILE_H_MELD)
				trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				if tex:
					trect.texture = tex
				_meld_area.add_child(trect)
				x += TILE_W_MELD + 2
			x += 8


# ============================================================
# Helpers
# ============================================================

func _build_dead_tiles_from_log(turns: Array, up_to_turn_idx: int) -> Dictionary:
	var counts: Dictionary = {}
	var red: Dictionary = {}
	var gold: Dictionary = {}
	var max_t := mini(up_to_turn_idx, turns.size())
	for i in range(max_t):
		var t: Dictionary = turns[i]
		var did: int = int(t.get("discard", -1))
		if did >= 0:
			counts[did] = counts.get(did, 0) + 1
			if bool(t.get("discard_is_red", false)):
				red[did] = red.get(did, 0) + 1
			if bool(t.get("discard_is_gold", false)):
				gold[did] = gold.get(did, 0) + 1
		var meld = t.get("meld", null)
		if meld != null and meld is Dictionary:
			var mid: int = int(meld.get("tile_id", -1))
			if mid >= 0:
				counts[mid] = counts.get(mid, 0) + 1
	return {"counts": counts, "red": red, "gold": gold}


func _calc_remaining_wall(turns: Array, up_to_turn_idx: int) -> int:
	var draws := 0
	var max_t := mini(up_to_turn_idx + 1, turns.size())
	for i in range(max_t):
		var t: Dictionary = turns[i]
		if int(t.get("draw", -1)) >= 0:
			draws += 1
	return maxi(1, 61 - draws)


func _update_tab_highlight() -> void:
	for i in range(_tab_btns.size()):
		(_tab_btns[i] as Button).modulate = Color(1.0, 0.85, 0.2) if i == _round_idx else Color(1, 1, 1)


func _round_label(wind: int, kyoku: int) -> String:
	var w: String = "東" if wind == MahjongLogic.EAST else "南"
	return "%s%d局" % [w, kyoku]


func _player_name(idx: int) -> String:
	var players_arr: Array = _log.get("players", [])
	if idx < players_arr.size():
		return str((players_arr[idx] as Dictionary).get("name", "P%d" % idx))
	return "P%d" % idx


func _format_round_result(result: Dictionary, players_arr: Array) -> String:
	var type_str: String = str(result.get("type", ""))
	if type_str == "draw":
		return "流局"
	var winner: int = int(result.get("winner", -1))
	var yaku_arr: Array = result.get("yaku", [])
	var han: int = int(result.get("han", 0))
	var w_name := _player_name(winner)
	var yaku_str := ", ".join(yaku_arr) if not yaku_arr.is_empty() else ""
	return "%s %s和了 %s %d翻" % [w_name, "ツモ" if type_str == "tsumo" else "ロン", yaku_str, han]


func _format_date(raw: String) -> String:
	if raw.length() < 16:
		return raw
	var d := raw.replace("T", " ")
	return d.substr(0, 4) + "/" + d.substr(5, 2) + "/" + d.substr(8, 2) + " " + d.substr(11, 5)


# ============================================================
# UI helpers
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
	btn.add_theme_font_size_override("font_size", 18)
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


# ============================================================
# Tile texture
# ============================================================

func _next_turn_label(shanten: int) -> String:
	match shanten:
		0: return "次巡和了確率"
		1: return "次巡聴牌確率"
		2: return "次巡一向聴確率"
		_: return "次巡繰り上げ確率"


func _get_tile_texture_path(tile: Dictionary) -> String:
	var id: int = tile.id
	var is_red: bool = tile.get("is_red", false)
	var is_gold: bool = tile.get("is_gold", false)
	var is_haku_pochi: bool = tile.get("is_haku_pochi", false)
	match id:
		11: return "res://assets/tiles/hai_m_1.webp"
		19: return "res://assets/tiles/hai_m_9.webp"
		21: return "res://assets/tiles/hai_pi_1.webp"
		22: return "res://assets/tiles/hai_pi_2.webp"
		23: return "res://assets/tiles/hai_pi_3.webp"
		24: return "res://assets/tiles/hai_pi_4.webp"
		25: return "res://assets/tiles/hai_pi_5a.webp" if is_red else "res://assets/tiles/hai_pi_5.webp"
		26: return "res://assets/tiles/hai_pi_6.webp"
		27: return "res://assets/tiles/hai_pi_7.webp"
		28: return "res://assets/tiles/hai_pi_8k.webp" if is_gold else "res://assets/tiles/hai_pi_8.webp"
		29: return "res://assets/tiles/hai_pi_9.webp"
		31: return "res://assets/tiles/hai_so_1.webp"
		32: return "res://assets/tiles/hai_so_2.webp"
		33: return "res://assets/tiles/hai_so_3.webp"
		34: return "res://assets/tiles/hai_so_4.webp"
		35: return "res://assets/tiles/hai_so_5a.webp" if is_red else "res://assets/tiles/hai_so_5.webp"
		36: return "res://assets/tiles/hai_so_6.webp"
		37: return "res://assets/tiles/hai_so_7.webp"
		38: return "res://assets/tiles/hai_so_8k.webp" if is_gold else "res://assets/tiles/hai_so_8.webp"
		39: return "res://assets/tiles/hai_so_9.webp"
		41: return "res://assets/tiles/hai_ji_ton.webp"
		42: return "res://assets/tiles/hai_ji_nan.webp"
		43: return "res://assets/tiles/hai_ji_sya.webp"
		44: return "res://assets/tiles/hai_ji_pea.webp" if is_red else "res://assets/tiles/hai_ji_pe.webp"
		45: return "res://assets/tiles/hai_ji_hakup.webp" if is_haku_pochi else "res://assets/tiles/hai_ji_haku.webp"
		46: return "res://assets/tiles/hai_ji_hatu.webp"
		47: return "res://assets/tiles/hai_ji_tyun.webp"
	return ""


func _get_tile_texture(tile: Dictionary) -> Texture2D:
	var path := _get_tile_texture_path(tile)
	if path == "":
		return null
	if not _tile_texture_cache.has(path):
		if ResourceLoader.exists(path):
			_tile_texture_cache[path] = load(path)
		else:
			return null
	return _tile_texture_cache[path]
