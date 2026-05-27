class_name GameLogViewerScreen
extends Control

static var log_path: String = ""

const SCREEN_SIZE := Vector2(1920, 1080)
const TILE_W_HAND := 52.0
const TILE_H_HAND := 72.0
const TILE_W_DISC := 30.0
const TILE_H_DISC := 42.0
const TILE_W_MELD := 34.0
const TILE_H_MELD := 48.0
const TILE_GAP := 3.0

var _log: Dictionary = {}
var _round_idx: int = 0
var _turn_idx: int = -1  # -1 = start of round state
var _sim_visible: bool = false
var _sim_results: Array = []
var _sim_selected: int = -1
var _tile_texture_cache: Dictionary = {}

# UI refs
var _info_bar_lbl: Label
var _hand_area: Control
var _discard_area: Control
var _meld_area: Control
var _result_info_lbl: Label
var _slider: HSlider
var _nav_prev_btn: Button
var _nav_next_btn: Button
var _study_btn: Button
var _tab_btns: Array = []
var _sim_panel: Control
var _sim_context_lbl: Label
var _sim_result_list: VBoxContainer
var _sim_detail_lbl: Label
var _sim_detail_tiles: Control

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
	bg.color = Color(0.05, 0.08, 0.12, 1.0)
	add_child(bg)

	_build_header()
	_build_tabs()
	_build_info_bar()
	_build_replay_area()
	_build_nav_bar()
	_build_sim_panel()

func _build_header() -> void:
	var header := _make_panel(Color(0.08, 0.12, 0.20, 0.95), Rect2(0, 0, 1920, 58))
	add_child(header)

	var date_str := str(_log.get("date", ""))
	var disp := _format_date(date_str)
	var players_arr: Array = _log.get("players", [])
	var names: Array = []
	for p: Dictionary in players_arr:
		names.append(str(p.get("name", "?")))
	var title_lbl := _make_label("牌譜: " + disp + "  " + " vs ".join(names), Vector2(24, 10), 26)
	title_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.70))
	header.add_child(title_lbl)

	var back_btn := _make_button("← 戻る", Color(0.22, 0.22, 0.30))
	back_btn.position = Vector2(1730, 4)
	back_btn.custom_minimum_size = Vector2(150, 50)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/gamelog/GameLogListScreen.tscn"))
	header.add_child(back_btn)

func _build_tabs() -> void:
	var tab_bar := _make_panel(Color(0.06, 0.10, 0.16, 0.90), Rect2(0, 58, 1920, 50))
	add_child(tab_bar)
	_tab_btns.clear()

	var rounds: Array = _log.get("rounds", [])
	var x := 12.0
	for i in range(rounds.size()):
		var r: Dictionary = rounds[i]
		var label := _round_label(int(r.get("wind", 0)), int(r.get("kyoku", 1)))
		var tbtn := _make_button(label, Color(0.14, 0.22, 0.36))
		tbtn.position = Vector2(x, 4)
		tbtn.custom_minimum_size = Vector2(110, 42)
		tbtn.add_theme_font_size_override("font_size", 18)
		tbtn.pressed.connect(func(idx := i): _select_round(idx))
		tab_bar.add_child(tbtn)
		_tab_btns.append(tbtn)
		x += 118.0

func _build_info_bar() -> void:
	var bar := _make_panel(Color(0.07, 0.11, 0.18, 0.80), Rect2(0, 108, 1920, 40))
	add_child(bar)
	_info_bar_lbl = _make_label("", Vector2(20, 8), 22)
	_info_bar_lbl.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	bar.add_child(_info_bar_lbl)
	_result_info_lbl = _make_label("", Vector2(900, 8), 22)
	_result_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	bar.add_child(_result_info_lbl)

func _build_replay_area() -> void:
	# Player 0 hand (left, x=0..720, y=148..348)
	var hand_panel := _make_panel(Color(0.07, 0.12, 0.10, 0.70), Rect2(0, 148, 720, 200))
	add_child(hand_panel)
	hand_panel.add_child(_make_label("手 牌（プレイヤー）", Vector2(14, 8), 20))
	_hand_area = Control.new()
	_hand_area.position = Vector2(14, 36)
	_hand_area.size = Vector2(700, 160)
	hand_panel.add_child(_hand_area)

	# Meld area (x=0..720, y=348..438)
	var meld_panel := _make_panel(Color(0.07, 0.10, 0.16, 0.70), Rect2(0, 348, 720, 90))
	add_child(meld_panel)
	meld_panel.add_child(_make_label("副露", Vector2(14, 6), 18))
	_meld_area = Control.new()
	_meld_area.position = Vector2(14, 30)
	_meld_area.size = Vector2(700, 56)
	meld_panel.add_child(_meld_area)

	# Discard area (x=720..1920, y=148..440)
	var disc_panel := _make_panel(Color(0.08, 0.10, 0.14, 0.70), Rect2(720, 148, 1200, 292))
	add_child(disc_panel)
	disc_panel.add_child(_make_label("捨て牌", Vector2(14, 8), 20))
	_discard_area = Control.new()
	_discard_area.position = Vector2(14, 36)
	_discard_area.size = Vector2(1180, 250)
	disc_panel.add_child(_discard_area)

func _build_nav_bar() -> void:
	var nav := _make_panel(Color(0.06, 0.10, 0.16, 0.90), Rect2(0, 442, 1920, 66))
	add_child(nav)

	_nav_prev_btn = _make_button("◀", Color(0.20, 0.25, 0.38))
	_nav_prev_btn.position = Vector2(20, 8)
	_nav_prev_btn.custom_minimum_size = Vector2(80, 50)
	_nav_prev_btn.add_theme_font_size_override("font_size", 28)
	_nav_prev_btn.pressed.connect(_on_prev_turn)
	nav.add_child(_nav_prev_btn)

	_nav_next_btn = _make_button("▶", Color(0.20, 0.25, 0.38))
	_nav_next_btn.position = Vector2(114, 8)
	_nav_next_btn.custom_minimum_size = Vector2(80, 50)
	_nav_next_btn.add_theme_font_size_override("font_size", 28)
	_nav_next_btn.pressed.connect(_on_next_turn)
	nav.add_child(_nav_next_btn)

	_slider = HSlider.new()
	_slider.position = Vector2(210, 16)
	_slider.size = Vector2(1360, 34)
	_slider.min_value = -1
	_slider.max_value = 0
	_slider.step = 1
	_slider.value = -1
	_slider.value_changed.connect(_on_slider_changed)
	nav.add_child(_slider)

	_study_btn = _make_button("🔍 検討", Color(0.30, 0.20, 0.10))
	_study_btn.position = Vector2(1600, 8)
	_study_btn.custom_minimum_size = Vector2(280, 50)
	_study_btn.add_theme_font_size_override("font_size", 24)
	_study_btn.pressed.connect(_toggle_sim_panel)
	nav.add_child(_study_btn)

func _build_sim_panel() -> void:
	_sim_panel = _make_panel(Color(0.06, 0.10, 0.18, 0.97), Rect2(0, 508, 1920, 572))
	add_child(_sim_panel)
	_sim_panel.visible = false
	_sim_panel.z_index = 20

	var close_btn := _make_button("✕ 閉じる", Color(0.30, 0.15, 0.15))
	close_btn.position = Vector2(1740, 8)
	close_btn.custom_minimum_size = Vector2(150, 46)
	close_btn.pressed.connect(func(): _sim_panel.visible = false; _sim_visible = false)
	_sim_panel.add_child(close_btn)

	_sim_context_lbl = _make_label("", Vector2(20, 14), 24)
	_sim_context_lbl.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	_sim_panel.add_child(_sim_context_lbl)

	var divider := ColorRect.new()
	divider.position = Vector2(0, 56)
	divider.size = Vector2(1920, 2)
	divider.color = Color(0.3, 0.4, 0.6, 0.4)
	_sim_panel.add_child(divider)

	# Left: result list
	var result_scroll := ScrollContainer.new()
	result_scroll.position = Vector2(10, 62)
	result_scroll.size = Vector2(960, 480)
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sim_panel.add_child(result_scroll)
	_sim_result_list = VBoxContainer.new()
	_sim_result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_scroll.add_child(_sim_result_list)

	# Right: detail
	var detail_bg := _make_panel(Color(0.05, 0.09, 0.16, 0.90), Rect2(984, 62, 930, 480))
	_sim_panel.add_child(detail_bg)
	detail_bg.add_child(_make_label("有効牌:", Vector2(14, 10), 22))
	_sim_detail_lbl = _make_label("", Vector2(120, 12), 22)
	_sim_detail_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	detail_bg.add_child(_sim_detail_lbl)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.position = Vector2(8, 44)
	detail_scroll.size = Vector2(912, 430)
	detail_bg.add_child(detail_scroll)
	_sim_detail_tiles = Control.new()
	_sim_detail_tiles.size = Vector2(4000, 400)
	detail_scroll.add_child(_sim_detail_tiles)

# ============================================================
# Round / Turn navigation
# ============================================================
func _select_round(idx: int) -> void:
	_round_idx = idx
	_turn_idx = -1
	_sim_visible = false
	_sim_panel.visible = false
	_sim_results.clear()
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
	_sim_visible = false
	_sim_panel.visible = false
	_refresh_display()

func _toggle_sim_panel() -> void:
	if _sim_visible:
		_sim_visible = false
		_sim_panel.visible = false
	else:
		_run_sim_analysis()

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
	_sim_selected = -1

	var round_data: Dictionary = _log.get("rounds", [])[_round_idx]
	var wind_str := _round_label(int(round_data.get("wind", 0)), int(round_data.get("kyoku", 1)))
	var draw_id: int = int(turn.get("draw", -1))
	var draw_name := MahjongLogic.get_tile_name({"id": draw_id, "is_red": bool(turn.get("draw_is_red", false)), "is_gold": bool(turn.get("draw_is_gold", false)), "is_haku_pochi": false}) if draw_id >= 0 else "（初手）"
	_sim_context_lbl.text = "%s  %d巡目  ツモ: %s" % [wind_str, _turn_idx + 1, draw_name]

	_rebuild_sim_list(int(turn.get("discard", -1)))

	_sim_visible = true
	_sim_panel.visible = true

func _rebuild_sim_list(actual_discard_id: int) -> void:
	for ch in _sim_result_list.get_children():
		ch.queue_free()

	for i in range(_sim_results.size()):
		var r: Dictionary = _sim_results[i]
		var is_best: bool = (i == 0)
		var is_actual: bool = (actual_discard_id >= 0 and int(r.get("tile_id", -1)) == actual_discard_id)
		var row := Panel.new()
		row.custom_minimum_size = Vector2(950, 72)
		var s := StyleBoxFlat.new()
		if is_best:
			s.bg_color = Color(0.10, 0.22, 0.12, 0.9)
			s.set_border_width_all(2)
			s.border_color = Color(0.4, 0.8, 0.4, 0.7)
		elif is_actual:
			s.bg_color = Color(0.22, 0.17, 0.06, 0.9)
			s.set_border_width_all(2)
			s.border_color = Color(0.9, 0.7, 0.2, 0.7)
		else:
			s.bg_color = Color(0.09, 0.12, 0.17, 0.85)
		s.set_corner_radius_all(5)
		row.add_theme_stylebox_override("panel", s)
		var captured_i := i

		if is_best:
			var star := _make_label("★", Vector2(8, 20), 24)
			star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			row.add_child(star)
		if is_actual:
			var act := _make_label("→", Vector2(8, 20), 24)
			act.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
			row.add_child(act)

		var tile_d := {"id": r.get("tile_id", -1), "is_red": false, "is_gold": false, "is_haku_pochi": false}
		var img := TextureRect.new()
		img.position = Vector2(36, 2)
		img.size = Vector2(46, 64)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = _get_tile_texture(tile_d)
		row.add_child(img)

		row.add_child(_make_label(str(r.get("tile_name", "")), Vector2(90, 18), 20))
		var shan_lbl := _make_label(str(r.get("shanten_text", "")), Vector2(260, 18), 20)
		shan_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if r.get("shanten", 99) == 0 else Color(0.9, 0.9, 0.7))
		row.add_child(shan_lbl)
		var eff_lbl := _make_label("有効牌 %d枚" % r.get("effective_count", 0), Vector2(420, 18), 20)
		eff_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		row.add_child(eff_lbl)
		var exp_chip: int = int(r.get("expected_chip_value", -1))
		if exp_chip > 0:
			var chip_lbl := _make_label("期待値 +%d pt" % exp_chip, Vector2(590, 18), 18)
			chip_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
			row.add_child(chip_lbl)
		elif exp_chip == -1:
			var chip_lbl := _make_label("—", Vector2(620, 18), 18)
			chip_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(chip_lbl)
		if is_actual:
			var act_tag := _make_label("←実際", Vector2(760, 18), 18)
			act_tag.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
			row.add_child(act_tag)

		var hit_btn := Button.new()
		hit_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit_btn.flat = true
		hit_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		hit_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		hit_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		hit_btn.pressed.connect(func(): _on_sim_row_pressed(captured_i))
		row.add_child(hit_btn)
		_sim_result_list.add_child(row)

	# 比較行
	if actual_discard_id >= 0 and _sim_results.size() > 1:
		var best: Dictionary = _sim_results[0]
		var actual: Dictionary = {}
		for r2: Dictionary in _sim_results:
			if r2.get("tile_id", -1) == actual_discard_id:
				actual = r2; break
		if not actual.is_empty() and actual.get("tile_id", -1) != best.get("tile_id", -1):
			var diff: int = best.get("effective_count", 0) - actual.get("effective_count", 0)
			var cmp := Panel.new()
			cmp.custom_minimum_size = Vector2(950, 46)
			var cs := StyleBoxFlat.new()
			cs.bg_color = Color(0.18, 0.10, 0.04, 0.9)
			cs.set_corner_radius_all(5)
			cmp.add_theme_stylebox_override("panel", cs)
			var txt := "実際: %s（%s・%d枚）　最善: %s（%s・%d枚）　差 -%d枚" % [
				actual.get("tile_name", "?"), actual.get("shanten_text", "?"), actual.get("effective_count", 0),
				best.get("tile_name", "?"), best.get("shanten_text", "?"), best.get("effective_count", 0),
				diff,
			]
			var cl := _make_label(txt, Vector2(12, 12), 18)
			cl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			cmp.add_child(cl)
			_sim_result_list.add_child(cmp)

func _on_sim_row_pressed(idx: int) -> void:
	_sim_selected = idx
	if idx < 0 or idx >= _sim_results.size():
		return
	var r: Dictionary = _sim_results[idx]
	_sim_detail_lbl.text = "%s を切った場合 (%s・%d枚)" % [r.get("tile_name", ""), r.get("shanten_text", ""), r.get("effective_count", 0)]
	for ch in _sim_detail_tiles.get_children():
		ch.queue_free()
	var x := 0.0
	var eff: Dictionary = r.get("effective_tiles", {})
	for gid: int in eff:
		var tex := _get_tile_texture({"id": gid, "is_red": false, "is_gold": false, "is_haku_pochi": false})
		if tex:
			var ti := TextureRect.new()
			ti.position = Vector2(x, 0)
			ti.size = Vector2(40, 56)
			ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ti.texture = tex
			_sim_detail_tiles.add_child(ti)
			x += 44
		var cl := _make_label("×" + str(eff[gid]), Vector2(x, 16), 16)
		cl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
		_sim_detail_tiles.add_child(cl)
		x += 34

# ============================================================
# Display refresh
# ============================================================
func _refresh_display() -> void:
	var turns: Array = _current_turns()
	_nav_prev_btn.disabled = (_turn_idx <= -1)
	_nav_next_btn.disabled = (_turn_idx >= turns.size() - 1)

	# InfoBar
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
			var draw_id: int = int(t.get("draw", -1))
			var info_txt := "%s%s  %d巡目  %s" % [wind_str, honba_str, _turn_idx + 1, p_name]
			if int(t.get("is_kita", false)):
				info_txt += " 北抜き"
			elif draw_id >= 0:
				var draw_tile := {"id": draw_id, "is_red": bool(t.get("draw_is_red", false)), "is_gold": bool(t.get("draw_is_gold", false)), "is_haku_pochi": false}
				info_txt += " ツモ: " + MahjongLogic.get_tile_name(draw_tile)
			var disc_id: int = int(t.get("discard", -1))
			if disc_id >= 0:
				var disc_tile := {"id": disc_id, "is_red": bool(t.get("discard_is_red", false)), "is_gold": bool(t.get("discard_is_gold", false)), "is_haku_pochi": false}
				info_txt += "  打: " + MahjongLogic.get_tile_name(disc_tile)
				if bool(t.get("is_riichi", false)):
					info_txt += " [立直]"
			_info_bar_lbl.text = info_txt

		# Round result at last turn
		if _turn_idx == turns.size() - 1:
			var result: Dictionary = rd.get("result", {})
			_result_info_lbl.text = _format_round_result(result, _log.get("players", []))
		else:
			_result_info_lbl.text = ""

	# Study button enabled only when player 0 draw with 14 tiles
	var can_study := false
	if _turn_idx >= 0 and _turn_idx < turns.size():
		var t: Dictionary = turns[_turn_idx]
		can_study = (int(t.get("player", -1)) == 0 and (t.get("hand_after_draw", []) as Array).size() == 14)
	_study_btn.disabled = not can_study

	# Rebuild hand/discard/meld areas
	_rebuild_hand_view(turns)
	_rebuild_discard_view(turns)
	_rebuild_meld_view(turns)

func _rebuild_hand_view(turns: Array) -> void:
	for ch in _hand_area.get_children():
		ch.queue_free()
	# Find last turn where player 0 drew (hand_after_draw has data)
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

	# If t_idx_found == _turn_idx: show hand after draw (before discard)
	# Otherwise we're past that turn, show hand minus discarded tile
	var discard_id_to_hide := -1
	if t_idx_found == _turn_idx:
		discard_id_to_hide = -1  # show full 14
	else:
		# show 13 tiles (after discard): remove discard tile from hand
		if t_idx_found >= 0 and t_idx_found < turns.size():
			discard_id_to_hide = int(turns[t_idx_found].get("discard", -1))

	var display_hand: Array = []
	var removed := false
	for td in hand_tiles:
		var tid := int((td as Dictionary).get("id", -1))
		if not removed and discard_id_to_hide >= 0 and tid == discard_id_to_hide:
			removed = true
			continue
		display_hand.append(td)

	display_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	var can_tap := (display_hand.size() == 14)
	var x := 0.0
	for tile_d in display_hand:
		var td: Dictionary = tile_d as Dictionary
		var tex := _get_tile_texture({"id": int(td.get("id", -1)), "is_red": bool(td.get("is_red", false)), "is_gold": bool(td.get("is_gold", false)), "is_haku_pochi": bool(td.get("is_haku_pochi", false))})
		var btn := Button.new()
		btn.flat = true
		btn.position = Vector2(x, 0)
		btn.custom_minimum_size = Vector2(TILE_W_HAND, TILE_H_HAND)
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0, 0, 0, 0)
		style_normal.set_corner_radius_all(3)
		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = Color(1.0, 0.95, 0.4, 0.25)
		style_hover.set_corner_radius_all(3)
		var style_pressed := StyleBoxFlat.new()
		style_pressed.bg_color = Color(1.0, 0.85, 0.2, 0.45)
		style_pressed.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		if can_tap:
			btn.pressed.connect(_toggle_sim_panel)
		else:
			btn.disabled = true
		var trect := TextureRect.new()
		trect.set_anchors_preset(Control.PRESET_FULL_RECT)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if tex:
			trect.texture = tex
		btn.add_child(trect)
		_hand_area.add_child(btn)
		x += TILE_W_HAND + TILE_GAP

func _rebuild_discard_view(turns: Array) -> void:
	for ch in _discard_area.get_children():
		ch.queue_free()
	var max_t := mini(_turn_idx + 1, turns.size())
	# Accumulate discards per player
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

	var players_arr: Array = _log.get("players", [])
	var row_y := 0.0
	for p in range(3):
		var pname := _player_name(p)
		var lbl := _make_label(pname + ":", Vector2(0, row_y + 2), 16)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		_discard_area.add_child(lbl)
		var x := 80.0
		var col := 0
		var local_y := row_y
		for td: Dictionary in discards[p]:
			var tex := _get_tile_texture(td)
			var trect := TextureRect.new()
			trect.position = Vector2(x + col * (TILE_W_DISC + TILE_GAP), local_y)
			trect.size = Vector2(TILE_W_DISC, TILE_H_DISC)
			trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if tex:
				trect.texture = tex
			if bool(td.get("is_riichi", false)):
				trect.modulate = Color(1.0, 0.85, 0.3)
			_discard_area.add_child(trect)
			col += 1
			if col >= 18:
				col = 0
				local_y += TILE_H_DISC + TILE_GAP
		row_y += TILE_H_DISC * 2.5 + 10

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
		var lbl := _make_label(pname + ":", Vector2(x, 0), 15)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		_meld_area.add_child(lbl)
		x += 60.0
		for meld: Dictionary in melds[p]:
			var tile_id: int = int(meld.get("tile_id", -1))
			var type_str: String = str(meld.get("type", ""))
			var count := 3 if (type_str == "pon") else (4 if type_str in ["ankan", "minkan", "kakan"] else 3)
			for _j in range(count):
				var tex := _get_tile_texture({"id": tile_id, "is_red": false, "is_gold": false, "is_haku_pochi": false})
				var trect := TextureRect.new()
				trect.position = Vector2(x, 4)
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

# ============================================================
# Tile texture
# ============================================================
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
