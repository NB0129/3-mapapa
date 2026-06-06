extends Control

const SCREEN_SIZE := Vector2(1920, 1080)
const RULE_BOOK := preload("res://rule_book_data.gd")
const LEFT_W := 512.0
const MID_W := 768.0
const RIGHT_W := 640.0
const SLIDE_SEC := 0.55
const SEATS := ["bottom", "right", "top"]
const NPC_DESCRIPTIONS := {
	"kuma_black": "くまぱぱの中に生まれた別の人格\nが具現化したくま",
	"kuma_def": "普通の白くま。",
	"kuma_hiyake": "南国在中のノリノリくま\n特性：ゼンツ",
	"kuma_hokkyoku": "麻雀ぱぱに紛れ込んだ野生の熊。\n熊なのでツモ切りしかできない",
	"kuma_megane": "眼鏡の分だけ賢い。\n特性：リーチにはオリ",
	"kuma_saibo": "AIによって命を吹き込まれた最強のNPC",
}

var _left_panel: Panel
var _stats_panel: Panel
var _start_panel: Panel
var _select_panel: Control
var _dan_label: Label
var _stats_label: Label
var _rank_label: Label
var _p_label: Label
var _seat_npcs: Dictionary = {}
var _empty_seat: String = "top"
var _selected_seat: String = "bottom"
var _slot_nodes: Dictionary = {}
var _role_labels: Dictionary = {}
var _intro_panel: Panel
var _candidate_seat: String = ""
var _candidate_npc: String = ""
var _rules_popup: Panel
var _rules_body_label: Label
var _rules_scroll: ScrollContainer
var _rules_tab_buttons: Array = []

func _ready() -> void:
	_seat_npcs = SaveData.selected_npc_seats.duplicate(true)
	_empty_seat = SaveData.selected_empty_seat
	if _seat_npcs.is_empty():
		_seat_npcs = SaveData.DEFAULT_NPC_SEATS.duplicate()
		_empty_seat = "top"
	_remove_unselectable_npcs()
	_build_ui()
	_refresh_stats()
	AudioManager.play_bgm("bgm_menyu.ogg")
	call_deferred("_play_entry_animation")

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = SCREEN_SIZE
	custom_minimum_size = SCREEN_SIZE

	var bg := TextureRect.new()
	bg.position = Vector2.ZERO
	bg.size = SCREEN_SIZE
	bg.texture = load("res://assets/bg/bg_title.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var mask := ColorRect.new()
	mask.position = Vector2.ZERO
	mask.size = SCREEN_SIZE
	mask.color = Color(0, 0, 0, 0.0)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)

	_left_panel = _build_character_panel()
	_stats_panel = _build_stats_panel()
	_start_panel = _build_start_panel()
	_left_panel.z_index = 10
	_stats_panel.z_index = 1
	_start_panel.z_index = 1
	add_child(_left_panel)
	add_child(_stats_panel)
	add_child(_start_panel)
	_rules_popup = _build_rules_popup()
	_rules_popup.z_index = 50
	_rules_popup.visible = false
	add_child(_rules_popup)

func _build_character_panel() -> Panel:
	var panel := _make_panel(Color(0.02, 0.12, 0.28, 0.34), Rect2(0, 0, LEFT_W, 1080))
	var img := TextureRect.new()
	img.texture = _make_used_rect_texture("res://chara/hatimi.webp")
	img.position = Vector2(38, 130)
	img.size = Vector2(640, 880)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	panel.add_child(img)
	return panel

func _build_stats_panel() -> Panel:
	var panel := _make_panel(Color(0.04, 0.08, 0.09, 0.30), Rect2(LEFT_W, 0, MID_W, 1080))
	panel.add_child(_make_label("成績", Vector2(50, 42), 40, Color(0.78, 0.94, 1.0)))

	var dan_box := _make_panel(Color(0.10, 0.10, 0.24, 0.82), Rect2(44, 120, 552, 190))
	panel.add_child(dan_box)
	dan_box.add_child(_make_label("段位", Vector2(26, 18), 24, Color(0.78, 0.82, 1.0)))
	_dan_label = _make_label("--", Vector2(26, 66), 54, Color(1.0, 0.84, 0.22))
	dan_box.add_child(_dan_label)

	var stats_box := _make_panel(Color(0.06, 0.18, 0.12, 0.82), Rect2(44, 350, 552, 360))
	panel.add_child(stats_box)
	stats_box.add_child(_make_label("通算", Vector2(26, 20), 26, Color(0.75, 1.0, 0.84)))
	_stats_label = _make_label("", Vector2(26, 72), 26)
	_stats_label.size = Vector2(500, 250)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_box.add_child(_stats_label)

	var rank_box := _make_panel(Color(0.18, 0.10, 0.08, 0.82), Rect2(44, 750, 258, 210))
	panel.add_child(rank_box)
	rank_box.add_child(_make_label("着順", Vector2(24, 18), 24))
	_rank_label = _make_label("", Vector2(24, 66), 24)
	rank_box.add_child(_rank_label)

	var p_box := _make_panel(Color(0.18, 0.15, 0.05, 0.82), Rect2(338, 750, 258, 210))
	panel.add_child(p_box)
	p_box.add_child(_make_label("累計P", Vector2(24, 18), 24))
	_p_label = _make_label("0 P", Vector2(24, 78), 38, Color(1.0, 0.88, 0.22))
	p_box.add_child(_p_label)
	return panel

func _build_start_panel() -> Panel:
	var panel := _make_panel(Color(0.08, 0.06, 0.06, 0.30), Rect2(LEFT_W + MID_W, 0, RIGHT_W, 1080))

	var btn_taikyoku := _make_image_button("res://ui/btn_taikyoku.webp", Vector2(640, 300))
	btn_taikyoku.position = Vector2(60, 46)
	btn_taikyoku.pressed.connect(_show_member_select)
	panel.add_child(btn_taikyoku)

	var btn_ruuruhyou := _make_image_button("res://ui/btn_ru-ruhyou.webp", Vector2(520, 110))
	btn_ruuruhyou.position = _right_panel_center_pos(btn_ruuruhyou.size, 388)
	btn_ruuruhyou.pressed.connect(_on_rules_pressed)
	panel.add_child(btn_ruuruhyou)

	var btn_haihu := _make_image_button("res://ui/btn_haihu.webp", Vector2(520, 110))
	btn_haihu.position = _right_panel_center_pos(btn_haihu.size, 534)
	btn_haihu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/gamelog/GameLogListScreen.tscn"))
	panel.add_child(btn_haihu)

	var btn_simyu := _make_image_button("res://ui/btn_simyu.webp", Vector2(520, 110))
	btn_simyu.position = _right_panel_center_pos(btn_simyu.size, 680)
	btn_simyu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/simulator/SimulatorScreen.tscn"))
	panel.add_child(btn_simyu)

	var icon_modoru := _make_image_button("res://ui/icon_modoru.webp", Vector2(300, 128))
	icon_modoru.position = Vector2(RIGHT_W - icon_modoru.size.x - 40, 910)
	icon_modoru.pressed.connect(func(): get_tree().change_scene_to_file("res://Title.tscn"))
	panel.add_child(icon_modoru)

	return panel

func _play_entry_animation() -> void:
	_left_panel.position.x = -LEFT_W
	_stats_panel.position.y = -1080
	_start_panel.position.x = SCREEN_SIZE.x
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_left_panel, "position", Vector2(0, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_stats_panel, "position", Vector2(LEFT_W, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_panel, "position", Vector2(LEFT_W + MID_W, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_stats() -> void:
	_dan_label.text = SaveData.get_dan_name() + "  " + str(SaveData.dan_points) + "/10"
	var tg: int = SaveData.total_games
	if tg <= 0:
		_stats_label.text = "対局なし\n対局後に成績が表示されます"
		_rank_label.text = "1位 0\n2位 0\n3位 0"
	else:
		var avg_rank := 0.0
		for i in range(SaveData.rank_count.size()):
			avg_rank += float(i + 1) * float(SaveData.rank_count[i])
		avg_rank /= float(tg)
		var agari_rate := 0.0
		if SaveData.total_kyoku > 0:
			agari_rate = float(SaveData.total_agari) / float(SaveData.total_kyoku) * 100.0
		_stats_label.text = "対局数: %d\n平均着順: %.2f\n和了率: %.1f%%\n総局数: %d" % [tg, avg_rank, agari_rate, SaveData.total_kyoku]
		_rank_label.text = "1位 %d\n2位 %d\n3位 %d" % [SaveData.rank_count[0], SaveData.rank_count[1], SaveData.rank_count[2]]
	_p_label.text = str(SaveData.total_p) + " P"

func _show_member_select() -> void:
	if _select_panel == null:
		_select_panel = _build_member_select_panel()
		_select_panel.position = Vector2(SCREEN_SIZE.x, 0)
		_select_panel.z_index = 2
		add_child(_select_panel)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_stats_panel, "position", Vector2(-MID_W, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_start_panel, "position", Vector2(-RIGHT_W, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_select_panel, "position", Vector2.ZERO, SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _show_main_menu() -> void:
	_candidate_seat = ""
	_candidate_npc = ""
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_stats_panel, "position", Vector2(LEFT_W, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_start_panel, "position", Vector2(LEFT_W + MID_W, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if _select_panel != null:
		tween.tween_property(_select_panel, "position", Vector2(SCREEN_SIZE.x, 0), SLIDE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _build_member_select_panel() -> Control:
	var root := Control.new()
	root.size = SCREEN_SIZE
	var bg_panel := _make_panel(Color(0.03, 0.05, 0.06, 0.12), Rect2(LEFT_W, 0, MID_W + RIGHT_W, 1080))
	root.add_child(bg_panel)

	var table := TextureRect.new()
	table.texture = _make_used_rect_texture("res://assets/bg/bg_takujou.webp")
	table.position = Vector2(LEFT_W + 10, 250)
	table.size = Vector2(760, 520)
	table.scale = Vector2(0.63, 0.63)
	table.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	table.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(table)

	_role_labels.clear()
	_role_labels["player"] = _make_player_role_label(Vector2(435, 350))
	_role_labels["top"] = _make_role_label(Vector2(680, 250))
	_role_labels["right"] = _make_side_role_label(Vector2(887, 350))
	_role_labels["bottom"] = _make_role_label(Vector2(680, 553))
	for key in _role_labels.keys():
		root.add_child(_role_labels[key].box)

	_slot_nodes.clear()
	_add_seat_slot(root, "top", Vector2(600, 20))
	_add_seat_slot(root, "right", Vector2(957, 325))
	_add_seat_slot(root, "bottom", Vector2(600, 623))

	_intro_panel = _make_panel(Color(0.09, 0.09, 0.13, 0.92), Rect2(1432, 40, 468, 731))
	_intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_intro_panel)

	var btn_start := _make_image_button("res://ui/btn_gamestart.webp", Vector2(540, 180))
	btn_start.position = Vector2(1430, 850)
	btn_start.pressed.connect(_on_match_start_pressed)
	root.add_child(btn_start)

	var btn_back := _make_image_button("res://ui/icon_modoru.webp", Vector2(220, 94))
	btn_back.position = Vector2(LEFT_W + 28, 940)
	btn_back.pressed.connect(_show_main_menu)
	root.add_child(btn_back)

	_refresh_member_select()
	return root

func _add_seat_slot(root: Control, seat: String, pos: Vector2) -> void:
	var slot_size := Vector2(340, 230)
	var panel := Panel.new()
	panel.position = pos
	panel.size = slot_size
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if _is_primary_press(ev):
			_selected_seat = seat
			_candidate_seat = ""
			_candidate_npc = ""
			_refresh_member_select()
	)
	root.add_child(panel)

	var dash := _make_dashed_border(slot_size, Color(0.80, 0.84, 0.88, 0.8))
	dash.visible = false
	panel.add_child(dash)

	var img := TextureRect.new()
	img.position = Vector2(18, 12)
	img.size = Vector2(304, 160)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(img)

	var name_lbl := _make_label("", Vector2(16, 132), 30)
	name_lbl.position = Vector2(18, 178)
	name_lbl.size = Vector2(200, 34)
	panel.add_child(name_lbl)

	var btn := _make_button("変更", Color(0.22, 0.34, 0.56), Vector2(96, 42), 20)
	btn.position = Vector2(230, 176)
	btn.pressed.connect(func(): _change_seat_npc(seat))
	panel.add_child(btn)
	_slot_nodes[seat] = {"panel": panel, "img": img, "label": name_lbl, "button": btn, "dash": dash}

func _refresh_member_select() -> void:
	for seat in SEATS:
		var nodes: Dictionary = _slot_nodes.get(seat, {})
		if nodes.is_empty():
			continue
		var panel: Panel = nodes.panel
		var img: TextureRect = nodes.img
		var label: Label = nodes.label
		var dash: Control = nodes.dash
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.09, 0.11, 0.82)
		style.border_color = Color(0.95, 0.85, 0.32) if seat == _selected_seat else Color(0.55, 0.62, 0.68)
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		if _seat_npcs.get(seat, "") == "":
			style.bg_color = Color(0, 0, 0, 0.18)
			style.set_border_width_all(0)
			dash.visible = true
			img.texture = null
			label.text = "空席"
			label.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
		else:
			dash.visible = false
			var npc_id := str(_seat_npcs[seat])
			img.texture = load(SaveData.get_npc_path_menu(npc_id))
			label.text = SaveData.get_npc_name(npc_id)
			label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		panel.add_theme_stylebox_override("panel", style)
	_refresh_role_labels()
	_update_intro()

func _make_dashed_border(size: Vector2, color: Color) -> Control:
	var root := Control.new()
	root.position = Vector2.ZERO
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dash_len := 16.0
	var gap := 10.0
	var thick := 3.0
	var x := 0.0
	while x < size.x:
		root.add_child(_dash_rect(Vector2(x, 0), Vector2(min(dash_len, size.x - x), thick), color))
		root.add_child(_dash_rect(Vector2(x, size.y - thick), Vector2(min(dash_len, size.x - x), thick), color))
		x += dash_len + gap
	var y := 0.0
	while y < size.y:
		root.add_child(_dash_rect(Vector2(0, y), Vector2(thick, min(dash_len, size.y - y)), color))
		root.add_child(_dash_rect(Vector2(size.x - thick, y), Vector2(thick, min(dash_len, size.y - y)), color))
		y += dash_len + gap
	return root

func _dash_rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _refresh_role_labels() -> void:
	for key in _role_labels.keys():
		var entry: Dictionary = _role_labels[key]
		var label: Label = entry.label
		var role_text := _role_for_position(str(key))
		label.text = _vertical_role_text(role_text) if str(key) == "right" else role_text
		if label.label_settings != null:
			label.label_settings.font_color = Color(0.62, 0.64, 0.68) if role_text == "空席" else Color(1.0, 0.90, 0.35)

func _vertical_role_text(text: String) -> String:
	if text.length() <= 1:
		return text
	return "\n".join(text.split(""))

func _role_for_position(pos: String) -> String:
	match _empty_seat:
		"top":
			return {"player": "起家", "bottom": "南", "right": "西", "top": "空席"}.get(pos, "")
		"bottom":
			return {"right": "起家", "top": "南", "player": "西", "bottom": "空席"}.get(pos, "")
		"right":
			return {"top": "起家", "player": "南", "bottom": "西", "right": "空席"}.get(pos, "")
	return ""

func _update_intro() -> void:
	for child in _intro_panel.get_children():
		child.queue_free()
	var npc_id := _candidate_npc if _candidate_seat == _selected_seat and _candidate_npc != "" else str(_seat_npcs.get(_selected_seat, ""))
	var pos := Vector2(1432, 40)
	_intro_panel.position = pos
	_intro_panel.size = Vector2(468, 731)
	var clip := Control.new()
	clip.position = Vector2(24, 24)
	clip.size = Vector2(420, 390)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_panel.add_child(clip)
	var img := TextureRect.new()
	img.position = Vector2(-250, -173)
	img.size = Vector2(420, 390)
	img.scale = Vector2(2.16, 2.16)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if npc_id != "":
		var intro_path: String
		if npc_id == "kuma_hokkyoku":
			intro_path = SaveData.get_npc_path_game(npc_id)
			img.position = Vector2(-115, -87)
			img.scale = Vector2(1.512, 1.512)
		else:
			intro_path = SaveData.get_npc_path(npc_id)
		img.texture = load(intro_path)
	clip.add_child(img)
	var prev_btn := _make_button("←", Color(0.22, 0.34, 0.56), Vector2(74, 52), 28)
	prev_btn.position = Vector2(130, 430)
	prev_btn.pressed.connect(func(): _cycle_candidate(-1))
	_intro_panel.add_child(prev_btn)
	var next_btn := _make_button("→", Color(0.22, 0.34, 0.56), Vector2(74, 52), 28)
	next_btn.position = Vector2(264, 430)
	next_btn.pressed.connect(func(): _cycle_candidate(1))
	_intro_panel.add_child(next_btn)
	var text := "空席" if npc_id == "" else SaveData.get_npc_name(npc_id)
	_intro_panel.add_child(_make_label(text, Vector2(34, 500), 40, Color(1.0, 0.92, 0.68)))
	var desc := _make_label(_get_npc_description(npc_id), Vector2(24, 558), 30, Color(0.90, 0.94, 1.0))
	desc.size = Vector2(420, 88)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_panel.add_child(desc)
	var confirm := _make_button("NPC選択", Color(0.15, 0.50, 0.24), Vector2(240, 64), 26)
	confirm.position = Vector2(114, 650)
	confirm.disabled = _candidate_seat == "" or _candidate_npc == ""
	confirm.pressed.connect(_confirm_candidate)
	_intro_panel.add_child(confirm)

func _get_npc_description(npc_id: String) -> String:
	if npc_id == "":
		return "空席"
	return NPC_DESCRIPTIONS.get(npc_id, SaveData.get_npc_name(npc_id))

func _change_seat_npc(seat: String) -> void:
	_selected_seat = seat
	_candidate_seat = seat
	_candidate_npc = ""
	_cycle_candidate(1)

func _cycle_candidate(direction: int) -> void:
	_candidate_seat = _selected_seat
	var ids: Array = _selectable_npc_ids()
	var current := _candidate_npc if _candidate_npc != "" else str(_seat_npcs.get(_selected_seat, ""))
	var start_idx: int = ids.find(current)
	for offset in range(1, ids.size() + 1):
		var idx: int = (start_idx + offset * direction) % ids.size()
		if idx < 0:
			idx += ids.size()
		var candidate: String = ids[idx]
		if _is_candidate_available(candidate, _selected_seat):
			_candidate_npc = candidate
			break
	_refresh_member_select()

func _confirm_candidate() -> void:
	if _candidate_seat == "" or _candidate_npc == "":
		return
	if str(_seat_npcs.get(_candidate_seat, "")) == "":
		_seat_npcs[_candidate_seat] = _candidate_npc
		_rotate_empty_after_fill(_candidate_seat)
	else:
		_seat_npcs[_candidate_seat] = _candidate_npc
	_empty_seat = _find_empty_seat()
	_candidate_seat = ""
	_candidate_npc = ""
	_refresh_member_select()

func _is_candidate_available(npc_id: String, target_seat: String) -> bool:
	var _unused_npc_id := npc_id
	var _unused_target_seat := target_seat
	return true

func _first_unused_npc(ids: Array) -> String:
	for id: String in ids:
		if id not in _seat_npcs.values():
			return id
	return "kuma_def"

func _rotate_empty_after_fill(filled_seat: String) -> void:
	var next_empty := "top"
	match filled_seat:
		"top": next_empty = "right"
		"right": next_empty = "bottom"
		"bottom": next_empty = "top"
	for seat in SEATS:
		if seat == next_empty:
			_seat_npcs[seat] = ""
		elif str(_seat_npcs.get(seat, "")) == "":
			_seat_npcs[seat] = _first_unused_npc(_selectable_npc_ids())
	_empty_seat = next_empty

func _selectable_npc_ids() -> Array:
	var ids: Array = SaveData.NPC_DEFS.keys()
	ids.erase("kuma_black")
	ids.erase("kuma_saibo")
	ids.sort()
	return ids

func _remove_unselectable_npcs() -> void:
	for seat in SEATS:
		if str(_seat_npcs.get(seat, "")) in ["kuma_black", "kuma_saibo"]:
			_seat_npcs[seat] = _first_unused_npc(_selectable_npc_ids())

func _find_empty_seat() -> String:
	for seat in SEATS:
		if str(_seat_npcs.get(seat, "")) == "":
			return seat
	return "top"

func _on_match_start_pressed() -> void:
	SaveData.set_npc_seats(_seat_npcs)
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_rules_pressed() -> void:
	_rules_popup.visible = true
	_select_rule_tab(0)

func _build_rules_popup() -> Panel:
	var panel := _make_panel(Color(0.07, 0.08, 0.12, 0.96), Rect2(250, 90, 1420, 900))
	panel.add_child(_make_label("ルール表", Vector2(36, 24), 50, Color(1.0, 0.92, 0.55)))
	var btn_close := _make_button("閉じる", Color(0.35, 0.25, 0.25), Vector2(130, 58), 24)
	btn_close.position = Vector2(1240, 28)
	btn_close.pressed.connect(func(): _rules_popup.visible = false)
	panel.add_child(btn_close)
	_rules_tab_buttons.clear()
	var tabs: Array = RULE_BOOK.tabs()
	var tab_x := 36.0
	for i in range(tabs.size()):
		var tab: Dictionary = tabs[i]
		var btn := _make_button(str(tab.get("title", "")), Color(0.18, 0.24, 0.34), Vector2(150, 56), 30)
		btn.position = Vector2(tab_x, 104)
		btn.pressed.connect(func(idx := i): _select_rule_tab(idx))
		panel.add_child(btn)
		_rules_tab_buttons.append(btn)
		tab_x += 158.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(36, 184)
	scroll.size = Vector2(1348, 670)
	panel.add_child(scroll)
	_rules_scroll = scroll
	_rules_body_label = Label.new()
	_rules_body_label.size = Vector2(1290, 1200)
	_rules_body_label.custom_minimum_size = Vector2(1290, 1200)
	_rules_body_label.add_theme_font_size_override("font_size", 40)
	_rules_body_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.90))
	_rules_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_rules_body_label)
	_select_rule_tab(0)
	return panel

func _select_rule_tab(idx: int) -> void:
	var tabs: Array = RULE_BOOK.tabs()
	if idx < 0 or idx >= tabs.size() or _rules_body_label == null:
		return
	for i in range(_rules_tab_buttons.size()):
		_rules_tab_buttons[i].modulate = Color(1.0, 0.92, 0.55) if i == idx else Color.WHITE
	_rules_body_label.text = str(tabs[idx].get("body", ""))
	call_deferred("_reset_rules_scroll")

func _reset_rules_scroll() -> void:
	if _rules_scroll != null:
		_rules_scroll.scroll_vertical = 0
		_rules_scroll.scroll_horizontal = 0

func _make_panel(color: Color, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_label(text: String, pos: Vector2, font_size: int = 18, color: Color = Color(0.95, 0.95, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_role_label(pos: Vector2) -> Dictionary:
	var box := _make_panel(Color(0.02, 0.02, 0.04, 0.72), Rect2(pos, Vector2(180, 70)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _make_label("", Vector2.ZERO, 50, Color(1.0, 0.90, 0.35))
	l.size = Vector2(180, 70)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := LabelSettings.new()
	shadow.font_size = 50
	shadow.font_color = Color(1.0, 0.90, 0.35)
	shadow.shadow_color = Color(0, 0, 0, 0.85)
	shadow.shadow_size = 5
	l.label_settings = shadow
	box.add_child(l)
	return {"box": box, "label": l}

func _make_side_role_label(pos: Vector2) -> Dictionary:
	var box := Control.new()
	box.position = pos
	box.size = Vector2(70, 180)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _make_panel(Color(0.02, 0.02, 0.04, 0.72), Rect2(Vector2(70, 0), Vector2(180, 70)))
	frame.rotation_degrees = 90.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var l := _make_label("", Vector2.ZERO, 50, Color(1.0, 0.90, 0.35))
	l.size = box.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := LabelSettings.new()
	shadow.font_size = 50
	shadow.font_color = Color(1.0, 0.90, 0.35)
	shadow.shadow_color = Color(0, 0, 0, 0.85)
	shadow.shadow_size = 5
	l.label_settings = shadow
	box.add_child(l)
	return {"box": box, "label": l}

func _make_player_role_label(pos: Vector2) -> Dictionary:
	var box := _make_panel(Color(0.02, 0.02, 0.04, 0.72), Rect2(pos, Vector2(180, 180)))
	box.z_index = 20
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub := _make_label("Player", Vector2(18, 34), 22, Color.WHITE)
	sub.size = Vector2(120, 28)
	box.add_child(sub)
	var l := _make_label("", Vector2(0, 55), 50, Color(1.0, 0.90, 0.35))
	l.size = Vector2(180, 70)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := LabelSettings.new()
	shadow.font_size = 50
	shadow.font_color = Color(1.0, 0.90, 0.35)
	shadow.shadow_color = Color(0, 0, 0, 0.85)
	shadow.shadow_size = 5
	l.label_settings = shadow
	box.add_child(l)
	return {"box": box, "label": l}

func _make_image_button(path: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.icon = _make_used_rect_texture(path)
	btn.expand_icon = true
	btn.custom_minimum_size = size
	btn.size = size
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	return btn

func _right_panel_center_pos(size: Vector2, y: float) -> Vector2:
	return Vector2((RIGHT_W - size.x) * 0.5, y)

func _make_button(text: String, bg_color: Color, min_size: Vector2 = Vector2(180, 56), font_size: int = 24) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.size = min_size
	btn.add_theme_font_size_override("font_size", font_size)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	return btn

func _is_primary_press(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		if OS.has_feature("mobile"):
			return false
		return ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	if ev is InputEventScreenTouch:
		return ev.pressed
	if ev is InputEventScreenDrag:
		return false
	return false

func _make_used_rect_texture(path: String) -> Texture2D:
	var base: Texture2D = load(path)
	if base == null:
		return null
	var img: Image = base.get_image()
	if img == null:
		return base
	var used_rect: Rect2i = img.get_used_rect()
	if used_rect.size == Vector2i.ZERO or used_rect.size == img.get_size():
		return base
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(Vector2(used_rect.position), Vector2(used_rect.size))
	return atlas
