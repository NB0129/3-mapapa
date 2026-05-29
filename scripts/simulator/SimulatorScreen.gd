extends Control

# 牌譜閲覧画面から呼ばれる場合は事前にセットする
static var initial_hand: Array = []
static var actual_discard_id: int = -1
static var log_context_label: String = ""
static var initial_dead_tiles: Dictionary = {}
static var initial_total_wall: int = 61

const SCREEN_SIZE   := Vector2(1920, 1080)
const HAND_TILE_W   := 58.0
const HAND_TILE_H   := 80.0
const HAND_GAP      := 4.0
const PAL_TILE_W    := 68.0
const PAL_TILE_H    := 94.0
const PAL_GAP       := 5.0
const RESULT_ROW_H  := 108.0
const EFF_IMG_W     := 32.0
const EFF_IMG_H     := 44.0

# レイアウト境界
const LEFT_W        := 700.0   # 結果パネル幅
const RIGHT_X       := 1300.0  # 設定パネル左端
const RIGHT_W       := 620.0   # 設定パネル幅
const HAND_Y        := 660.0   # 手牌エリア上端

const PALETTE_MAN: Array = [
	{"id": 11, "is_red": false, "is_gold": false},
	{"id": 19, "is_red": false, "is_gold": false},
]
const PALETTE_PIN: Array = [
	{"id": 21}, {"id": 22}, {"id": 23}, {"id": 24},
	{"id": 25, "is_red": false}, {"id": 25, "is_red": true},
	{"id": 26}, {"id": 27},
	{"id": 28, "is_gold": false}, {"id": 28, "is_gold": true},
	{"id": 29},
]
const PALETTE_SOU: Array = [
	{"id": 31}, {"id": 32}, {"id": 33}, {"id": 34},
	{"id": 35, "is_red": false}, {"id": 35, "is_red": true},
	{"id": 36}, {"id": 37},
	{"id": 38, "is_gold": false}, {"id": 38, "is_gold": true},
	{"id": 39},
]
const PALETTE_JI: Array = [
	{"id": 41}, {"id": 42}, {"id": 43}, {"id": 44},
	{"id": 45}, {"id": 46}, {"id": 47},
]
const PALETTE_TABS: Array = ["萬子", "筒子", "索子", "字牌"]

const _SPECIAL_TILES: Array = [
	{"id": 25, "name": "5筒", "variant": "赤"},
	{"id": 28, "name": "8筒", "variant": "金"},
	{"id": 35, "name": "5索", "variant": "赤"},
	{"id": 38, "name": "8索", "variant": "金"},
	{"id": 44, "name": "北",  "variant": "赤"},
]
const _OTHER_TILES: Array = [
	11, 19, 21, 22, 23, 24, 26, 27, 29,
	31, 32, 33, 34, 36, 37, 39,
	41, 42, 43, 45, 46, 47,
]

var _hand: Array = []
var _results: Array = []
var _current_tab: int = 1
var _tile_texture_cache: Dictionary = {}

# 手牌スロット
var _hand_count_label: Label
var _hand_slot_btns: Array = []

# パレット
var _tab_btns: Array = []
var _palette_box: Control

# 結果パネル
var _result_scroll: ScrollContainer
var _result_list: VBoxContainer
var _no_result_lbl: Label

# 設定
var _dead_normal: Dictionary = {}
var _dead_red: Dictionary = {}
var _dead_gold: Dictionary = {}
var _dead_count_labels: Dictionary = {}
var _dead_plus_btns: Dictionary = {}
var _dead_panel: Control = null
var _dead_expanded: bool = false
var _dead_toggle_btn: Button = null
var _total_wall: int = 61
var _wall_spinbox: SpinBox = null

func _ready() -> void:
	_init_dead_dicts()
	_build_ui()
	if not initial_hand.is_empty():
		for t in initial_hand:
			if _hand.size() < 14:
				_hand.append(t.duplicate())
		initial_hand = []
		_refresh_hand_display()
		_refresh_palette()
	if not initial_dead_tiles.is_empty():
		_apply_dead_tiles_to_ui(initial_dead_tiles)
		initial_dead_tiles = {}
	if initial_total_wall != 61:
		_total_wall = initial_total_wall
		_wall_spinbox.value = initial_total_wall
		initial_total_wall = 61
	if actual_discard_id >= 0 and _hand.size() == 14:
		_run_analysis()

func _init_dead_dicts() -> void:
	for st: Dictionary in _SPECIAL_TILES:
		var tid: int = st.id
		_dead_normal[tid] = 0
		if st.variant == "赤":
			_dead_red[tid] = 0
		else:
			_dead_gold[tid] = 0
	for tid: int in _OTHER_TILES:
		_dead_normal[tid] = 0

# ============================================================
# UI 構築
# ============================================================
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = SCREEN_SIZE

	# 背景（game.gd と同じ）
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.28, 0.12)
	bg.z_index = -30
	add_child(bg)

	var bg_tex := TextureRect.new()
	bg_tex.position = Vector2(-288, -202)
	bg_tex.size = Vector2(2496, 1404)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/bg/bg_takujou.webp"):
		bg_tex.texture = load("res://assets/bg/bg_takujou.webp")
	bg_tex.z_index = -20
	add_child(bg_tex)

	_build_header()
	_build_result_panel()
	_build_settings_panel()
	_build_hand_area()

func _build_header() -> void:
	var header := _make_panel(Color(0.05, 0.10, 0.05, 0.92), Rect2(0, 0, 1920, 66))
	add_child(header)

	var title_lbl := _make_label("打牌シミュレーター", Vector2(36, 12), 34)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.55))
	header.add_child(title_lbl)

	if log_context_label != "":
		var ctx_lbl := _make_label(log_context_label, Vector2(460, 18), 24)
		ctx_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
		header.add_child(ctx_lbl)

	var back_btn := _make_button("← 戻る", Color(0.22, 0.22, 0.18))
	back_btn.position = Vector2(1740, 8)
	back_btn.custom_minimum_size = Vector2(150, 50)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

func _build_result_panel() -> void:
	var panel := _make_panel(Color(0.03, 0.12, 0.04, 0.82), Rect2(0, 66, LEFT_W, 1014))
	add_child(panel)

	var lbl := _make_label("解 析 結 果", Vector2(20, 12), 28)
	lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.7))
	panel.add_child(lbl)

	_no_result_lbl = _make_label("手牌を14枚入力して\n▶ 解析 を押してください", Vector2(80, 200), 26)
	_no_result_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	panel.add_child(_no_result_lbl)

	_result_scroll = ScrollContainer.new()
	_result_scroll.position = Vector2(6, 54)
	_result_scroll.size = Vector2(LEFT_W - 12, 952)
	_result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_result_scroll.visible = false
	panel.add_child(_result_scroll)

	_result_list = VBoxContainer.new()
	_result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_list.add_theme_constant_override("separation", 4)
	_result_scroll.add_child(_result_list)

func _build_settings_panel() -> void:
	var panel := _make_panel(Color(0.04, 0.10, 0.04, 0.85), Rect2(RIGHT_X, 66, RIGHT_W, 592))
	add_child(panel)

	if log_context_label != "":
		var ctx := _make_label(log_context_label, Vector2(16, 10), 20)
		ctx.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
		ctx.size = Vector2(RIGHT_W - 20, 32)
		panel.add_child(ctx)

	# 残り山
	var wall_lbl := _make_label("残り山:", Vector2(16, 48), 22)
	panel.add_child(wall_lbl)
	_wall_spinbox = SpinBox.new()
	_wall_spinbox.position = Vector2(112, 44)
	_wall_spinbox.size = Vector2(120, 34)
	_wall_spinbox.min_value = 1
	_wall_spinbox.max_value = 61
	_wall_spinbox.step = 1
	_wall_spinbox.value = 61
	_wall_spinbox.value_changed.connect(func(v: float): _total_wall = int(v))
	panel.add_child(_wall_spinbox)

	# 見えている牌トグル
	_dead_toggle_btn = _make_button("▶ 見えている牌", Color(0.14, 0.22, 0.14))
	_dead_toggle_btn.position = Vector2(16, 90)
	_dead_toggle_btn.custom_minimum_size = Vector2(280, 40)
	_dead_toggle_btn.add_theme_font_size_override("font_size", 20)
	_dead_toggle_btn.pressed.connect(_toggle_dead_panel)
	panel.add_child(_dead_toggle_btn)

	_dead_panel = _build_dead_panel()
	_dead_panel.position = Vector2(16, 138)
	_dead_panel.visible = false
	panel.add_child(_dead_panel)

func _build_dead_panel() -> Control:
	var panel := _make_panel(Color(0.05, 0.10, 0.05, 0.90), Rect2(0, 0, RIGHT_W - 32, 430))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 4)
	scroll.size = Vector2(RIGHT_W - 40, 422)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := Control.new()
	content.size = Vector2(RIGHT_W - 44, 560)
	scroll.add_child(content)

	var sp_lbl := _make_label("特殊牌（赤・金）", Vector2(4, 4), 17)
	sp_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.6))
	content.add_child(sp_lbl)

	var sp_y := 26.0
	for st: Dictionary in _SPECIAL_TILES:
		var tid: int = st.id
		var tname: String = st.name
		var variant: String = st.variant

		content.add_child(_make_label(tname, Vector2(4, sp_y + 5), 16))
		content.add_child(_make_label("通常", Vector2(64, sp_y + 5), 14))
		var nm_minus := _make_step_btn("−")
		nm_minus.position = Vector2(102, sp_y + 1)
		nm_minus.pressed.connect(func(t := tid): _on_dead_changed(t, "normal", -1))
		content.add_child(nm_minus)
		var nm_lbl := _make_label("0", Vector2(134, sp_y + 5), 16)
		nm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm_lbl.custom_minimum_size = Vector2(24, 24)
		content.add_child(nm_lbl)
		_dead_count_labels[str(tid) + "_normal"] = nm_lbl
		var nm_plus := _make_step_btn("+")
		nm_plus.position = Vector2(160, sp_y + 1)
		nm_plus.pressed.connect(func(t := tid): _on_dead_changed(t, "normal", +1))
		content.add_child(nm_plus)
		_dead_plus_btns[str(tid) + "_normal"] = nm_plus

		var var_lbl := _make_label(variant, Vector2(200, sp_y + 5), 14)
		var_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3) if variant == "赤" else Color(0.9, 0.8, 0.2))
		content.add_child(var_lbl)
		var sp_minus := _make_step_btn("−")
		sp_minus.position = Vector2(230, sp_y + 1)
		sp_minus.pressed.connect(func(t := tid, v := variant): _on_dead_changed(t, v, -1))
		content.add_child(sp_minus)
		var sp_lbl2 := _make_label("0", Vector2(262, sp_y + 5), 16)
		sp_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp_lbl2.custom_minimum_size = Vector2(24, 24)
		content.add_child(sp_lbl2)
		if variant == "赤":
			_dead_count_labels[str(tid) + "_red"] = sp_lbl2
		else:
			_dead_count_labels[str(tid) + "_gold"] = sp_lbl2
		var sp_plus := _make_step_btn("+")
		sp_plus.position = Vector2(288, sp_y + 1)
		sp_plus.pressed.connect(func(t := tid, v := variant): _on_dead_changed(t, v, +1))
		content.add_child(sp_plus)
		if variant == "赤":
			_dead_plus_btns[str(tid) + "_red"] = sp_plus
		else:
			_dead_plus_btns[str(tid) + "_gold"] = sp_plus
		sp_y += 32.0

	var ot_hdr := _make_label("その他の牌", Vector2(4, sp_y + 4), 17)
	ot_hdr.add_theme_color_override("font_color", Color(0.7, 0.9, 0.6))
	content.add_child(ot_hdr)
	sp_y += 26.0

	var col := 0
	var ot_row_y := sp_y
	for tid: int in _OTHER_TILES:
		var ox := float(col) * 100.0 + 4.0
		var tile_d := {"id": tid, "is_red": false, "is_gold": false, "is_haku_pochi": false}
		var tname: String = MahjongLogic.get_tile_name(tile_d)
		content.add_child(_make_label(tname, Vector2(ox, ot_row_y + 1), 13))
		var ot_minus := _make_step_btn("−")
		ot_minus.position = Vector2(ox + 38, ot_row_y)
		ot_minus.pressed.connect(func(t := tid): _on_dead_changed(t, "normal", -1))
		content.add_child(ot_minus)
		var ot_lbl := _make_label("0", Vector2(ox + 66, ot_row_y + 1), 15)
		ot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ot_lbl.custom_minimum_size = Vector2(22, 26)
		content.add_child(ot_lbl)
		_dead_count_labels[str(tid) + "_normal"] = ot_lbl
		var ot_plus := _make_step_btn("+")
		ot_plus.position = Vector2(ox + 86, ot_row_y)
		ot_plus.pressed.connect(func(t := tid): _on_dead_changed(t, "normal", +1))
		content.add_child(ot_plus)
		_dead_plus_btns[str(tid) + "_normal"] = ot_plus
		col += 1
		if col >= 5:
			col = 0
			ot_row_y += 28.0

	ot_row_y += 32.0
	var reset_btn := _make_button("リセット", Color(0.28, 0.14, 0.10))
	reset_btn.position = Vector2(4, ot_row_y)
	reset_btn.custom_minimum_size = Vector2(140, 36)
	reset_btn.add_theme_font_size_override("font_size", 17)
	reset_btn.pressed.connect(_on_dead_reset)
	content.add_child(reset_btn)

	return panel

func _build_hand_area() -> void:
	var area := _make_panel(Color(0.04, 0.14, 0.05, 0.88), Rect2(LEFT_W, 66, RIGHT_X - LEFT_W, 1014))
	add_child(area)

	# パレットタブ
	var tab_x := 10.0
	for i in range(PALETTE_TABS.size()):
		var tbtn := _make_button(PALETTE_TABS[i], Color(0.12, 0.22, 0.14))
		tbtn.position = Vector2(tab_x, 12)
		tbtn.custom_minimum_size = Vector2(138, 48)
		tbtn.pressed.connect(func(idx := i): _select_tab(idx))
		area.add_child(tbtn)
		_tab_btns.append(tbtn)
		tab_x += 146.0

	# パレットグリッド
	_palette_box = Control.new()
	_palette_box.position = Vector2(10, 70)
	_palette_box.size = Vector2(570, 210)
	area.add_child(_palette_box)

	# 手牌セクション
	var hand_lbl := _make_label("手 牌", Vector2(10, 298), 24)
	hand_lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	area.add_child(hand_lbl)
	_hand_count_label = _make_label("0 / 14枚", Vector2(120, 304), 20)
	_hand_count_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	area.add_child(_hand_count_label)

	var slot_x := 10.0
	for i in range(14):
		var btn := Button.new()
		btn.position = Vector2(slot_x + i * (HAND_TILE_W + HAND_GAP), 332)
		btn.custom_minimum_size = Vector2(HAND_TILE_W, HAND_TILE_H)
		btn.size = Vector2(HAND_TILE_W, HAND_TILE_H)
		btn.flat = true
		_style_slot_empty(btn)
		btn.pressed.connect(func(idx := i): _on_hand_tile_pressed(idx))
		area.add_child(btn)
		_hand_slot_btns.append(btn)

	# アクションボタン行
	var analyze_btn := _make_button("▶ 解析", Color(0.15, 0.42, 0.18))
	analyze_btn.position = Vector2(10, 434)
	analyze_btn.custom_minimum_size = Vector2(220, 60)
	analyze_btn.add_theme_font_size_override("font_size", 28)
	analyze_btn.pressed.connect(_run_analysis)
	area.add_child(analyze_btn)

	var clear_btn := _make_button("クリア", Color(0.35, 0.16, 0.10))
	clear_btn.position = Vector2(240, 434)
	clear_btn.custom_minimum_size = Vector2(150, 60)
	clear_btn.add_theme_font_size_override("font_size", 22)
	clear_btn.pressed.connect(_on_clear_pressed)
	area.add_child(clear_btn)

	var study_btn := _make_button("🔍 検討", Color(0.28, 0.22, 0.10))
	study_btn.position = Vector2(400, 434)
	study_btn.custom_minimum_size = Vector2(170, 60)
	study_btn.add_theme_font_size_override("font_size", 22)
	study_btn.pressed.connect(_toggle_dead_panel)
	area.add_child(study_btn)

	_select_tab(_current_tab)

# ============================================================
# 見えている牌パネル
# ============================================================
func _toggle_dead_panel() -> void:
	_dead_expanded = not _dead_expanded
	_dead_panel.visible = _dead_expanded
	_dead_toggle_btn.text = ("▼ 見えている牌" if _dead_expanded else "▶ 見えている牌")

func _on_dead_changed(tile_id: int, variant: String, delta: int) -> void:
	match variant:
		"normal":
			_dead_normal[tile_id] = clampi(_dead_normal.get(tile_id, 0) + delta, 0, _dead_max(tile_id, "normal"))
		"赤":
			_dead_red[tile_id] = clampi(_dead_red.get(tile_id, 0) + delta, 0, _dead_max(tile_id, "赤"))
		"金":
			_dead_gold[tile_id] = clampi(_dead_gold.get(tile_id, 0) + delta, 0, _dead_max(tile_id, "金"))
	_refresh_dead_labels()

func _dead_max(tile_id: int, variant: String) -> int:
	var hand_cnt := 0
	for t: Dictionary in _hand:
		if t.id == tile_id:
			hand_cnt += 1
	var total_seen: int = _dead_normal.get(tile_id, 0) + _dead_red.get(tile_id, 0) + _dead_gold.get(tile_id, 0)
	var slot_remaining: int = SanmaAnalyzer.DECK_SIZE - hand_cnt - total_seen
	match variant:
		"normal":
			return maxi(0, slot_remaining)
		"赤":
			var red_max: int = _red_total(tile_id)
			return maxi(0, mini(slot_remaining, red_max - _dead_red.get(tile_id, 0)))
		"金":
			var gold_max: int = _gold_total(tile_id)
			return maxi(0, mini(slot_remaining, gold_max - _dead_gold.get(tile_id, 0)))
	return 0

func _red_total(tile_id: int) -> int:
	match tile_id:
		25, 35: return 2
		44: return 1
	return 0

func _gold_total(tile_id: int) -> int:
	match tile_id:
		28, 38: return 1
	return 0

func _refresh_dead_labels() -> void:
	for key: String in _dead_count_labels:
		var lbl: Label = _dead_count_labels[key]
		var parts := key.split("_")
		var tid: int = int(parts[0])
		var vtype: String = parts[1]
		var val := 0
		match vtype:
			"normal": val = _dead_normal.get(tid, 0)
			"red":    val = _dead_red.get(tid, 0)
			"gold":   val = _dead_gold.get(tid, 0)
		lbl.text = str(val)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if val > 0 else Color(0.9, 0.9, 0.85))
	for key: String in _dead_plus_btns:
		var btn: Button = _dead_plus_btns[key]
		var parts := key.split("_")
		var tid: int = int(parts[0])
		var vtype: String = parts[1]
		var variant := ""
		match vtype:
			"normal": variant = "normal"
			"red":    variant = "赤"
			"gold":   variant = "金"
		btn.disabled = (_dead_max(tid, variant) <= 0)

func _on_dead_reset() -> void:
	for tid in _dead_normal: _dead_normal[tid] = 0
	for tid in _dead_red:    _dead_red[tid] = 0
	for tid in _dead_gold:   _dead_gold[tid] = 0
	_refresh_dead_labels()

func _build_dead_tiles() -> Dictionary:
	var counts: Dictionary = {}
	var red: Dictionary = {}
	var gold: Dictionary = {}
	for tid: int in _dead_normal:
		var n: int = _dead_normal[tid]
		if n > 0:
			counts[tid] = counts.get(tid, 0) + n
	for tid: int in _dead_red:
		var r: int = _dead_red[tid]
		if r > 0:
			counts[tid] = counts.get(tid, 0) + r
			red[tid] = r
	for tid: int in _dead_gold:
		var g: int = _dead_gold[tid]
		if g > 0:
			counts[tid] = counts.get(tid, 0) + g
			gold[tid] = g
	return {"counts": counts, "red": red, "gold": gold}

func _apply_dead_tiles_to_ui(dt: Dictionary) -> void:
	var dc: Dictionary = dt.get("counts", {})
	var dr: Dictionary = dt.get("red", {})
	var dg: Dictionary = dt.get("gold", {})
	for tid_v in dc:
		var tid: int = int(tid_v)
		var r_cnt: int = int(dr.get(tid, 0))
		var g_cnt: int = int(dg.get(tid, 0))
		var normal_cnt: int = int(dc.get(tid, 0)) - r_cnt - g_cnt
		if _dead_normal.has(tid):
			_dead_normal[tid] = maxi(0, normal_cnt)
		if _dead_red.has(tid) and r_cnt > 0:
			_dead_red[tid] = r_cnt
		if _dead_gold.has(tid) and g_cnt > 0:
			_dead_gold[tid] = g_cnt
	_refresh_dead_labels()

# ============================================================
# タブ・パレット
# ============================================================
func _select_tab(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_btns.size()):
		_tab_btns[i].modulate = (Color(1.0, 0.92, 0.3) if i == idx else Color(1, 1, 1))
	_rebuild_palette()

func _rebuild_palette() -> void:
	for child in _palette_box.get_children():
		child.queue_free()
	var tiles: Array = _get_palette_tiles(_current_tab)
	var col := 0
	var row := 0
	var cols_per_row := 8
	for tile_def in tiles:
		var tile := _make_tile_dict(tile_def)
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(PAL_TILE_W, PAL_TILE_H)
		btn.size = Vector2(PAL_TILE_W, PAL_TILE_H)
		btn.position = Vector2(col * (PAL_TILE_W + PAL_GAP), row * (PAL_TILE_H + PAL_GAP))
		var tex := _get_tile_texture(tile)
		if tex:
			btn.icon = tex
			btn.expand_icon = true
		else:
			btn.text = MahjongLogic.get_tile_name(tile)
			btn.add_theme_font_size_override("font_size", 13)
		var s_n := StyleBoxFlat.new()
		s_n.bg_color = Color(0.14, 0.22, 0.14, 0.85)
		s_n.set_corner_radius_all(4)
		var s_h := s_n.duplicate() as StyleBoxFlat
		s_h.bg_color = Color(0.28, 0.46, 0.28, 1.0)
		var s_d := s_n.duplicate() as StyleBoxFlat
		s_d.bg_color = Color(0.08, 0.12, 0.08, 0.4)
		btn.add_theme_stylebox_override("normal", s_n)
		btn.add_theme_stylebox_override("hover", s_h)
		btn.add_theme_stylebox_override("pressed", s_h)
		btn.add_theme_stylebox_override("disabled", s_d)
		var t_cap := tile.duplicate()
		btn.pressed.connect(func(): _on_palette_tile_pressed(t_cap))
		_palette_box.add_child(btn)
		col += 1
		if col >= cols_per_row:
			col = 0
			row += 1
	_refresh_palette()

func _get_palette_tiles(tab: int) -> Array:
	match tab:
		0: return PALETTE_MAN
		1: return PALETTE_PIN
		2: return PALETTE_SOU
		3: return PALETTE_JI
	return []

func _make_tile_dict(def: Dictionary) -> Dictionary:
	return {
		"id": int(def.get("id", 11)),
		"is_red": bool(def.get("is_red", false)),
		"is_gold": bool(def.get("is_gold", false)),
		"is_haku_pochi": false,
	}

# ============================================================
# 手牌操作
# ============================================================
func _on_palette_tile_pressed(tile: Dictionary) -> void:
	if _hand.size() >= 14:
		return
	_hand.append(tile.duplicate())
	_refresh_hand_display()
	_refresh_palette()

func _on_hand_tile_pressed(idx: int) -> void:
	if idx < 0 or idx >= _hand.size():
		return
	_hand.remove_at(idx)
	_refresh_hand_display()
	_refresh_palette()

func _on_clear_pressed() -> void:
	_hand.clear()
	_results.clear()
	_refresh_hand_display()
	_refresh_palette()
	_result_scroll.visible = false
	_no_result_lbl.visible = true

# ============================================================
# 表示更新
# ============================================================
func _refresh_hand_display() -> void:
	for i in range(14):
		var btn: Button = _hand_slot_btns[i]
		if i < _hand.size():
			var tile: Dictionary = _hand[i]
			var tex := _get_tile_texture(tile)
			if tex:
				btn.text = ""
				btn.icon = tex
				btn.expand_icon = true
			else:
				btn.icon = null
				btn.text = MahjongLogic.get_tile_name(tile)
				btn.add_theme_font_size_override("font_size", 12)
			_style_slot_filled(btn)
		else:
			btn.icon = null
			btn.text = ""
			_style_slot_empty(btn)
	_hand_count_label.text = str(_hand.size()) + " / 14枚"
	_refresh_dead_labels()

func _refresh_palette() -> void:
	var id_counts: Dictionary = {}
	for t: Dictionary in _hand:
		id_counts[t.id] = id_counts.get(t.id, 0) + 1
	var tiles: Array = _get_palette_tiles(_current_tab)
	var btns: Array = _palette_box.get_children()
	for i in range(mini(tiles.size(), btns.size())):
		var tile: Dictionary = _make_tile_dict(tiles[i])
		var cnt: int = id_counts.get(tile.id, 0)
		btns[i].disabled = (cnt >= 4 or _hand.size() >= 14)

func _style_slot_filled(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.32, 0.18, 0.9)
	s.set_corner_radius_all(4)
	s.set_border_width_all(2)
	s.border_color = Color(0.4, 0.8, 0.4, 0.6)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.28, 0.50, 0.30, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)

func _style_slot_empty(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.16, 0.08, 0.6)
	s.set_corner_radius_all(4)
	s.set_border_width_all(1)
	s.border_color = Color(0.2, 0.4, 0.2, 0.4)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)

# ============================================================
# 解析
# ============================================================
func _run_analysis() -> void:
	if _hand.size() != 14:
		return
	var analyzer := SanmaAnalyzer.new()
	var dead_tiles := _build_dead_tiles()
	_total_wall = int(_wall_spinbox.value)
	_results = analyzer.evaluate_discards(_hand, _total_wall, dead_tiles)
	_rebuild_result_list()
	_result_scroll.visible = true
	_no_result_lbl.visible = false

func _rebuild_result_list() -> void:
	for child in _result_list.get_children():
		child.queue_free()

	for i in range(_results.size()):
		var r: Dictionary = _results[i]
		var is_best: bool = (i == 0)
		var is_actual: bool = (actual_discard_id >= 0 and int(r.get("tile_id", -1)) == actual_discard_id)
		var shanten_val: int = int(r.get("shanten", 99))
		var breakdown: Dictionary = r.get("tile_breakdown", {})
		var breakdown_rows: int = breakdown.size() if shanten_val <= 2 else 0
		var row_h := 90.0 + float(breakdown_rows) * 68.0 + 8.0

		var row_panel := Panel.new()
		row_panel.custom_minimum_size = Vector2(LEFT_W - 16, row_h)
		var s := StyleBoxFlat.new()
		if is_best:
			s.bg_color = Color(0.08, 0.22, 0.10, 0.95)
			s.set_border_width_all(2)
			s.border_color = Color(0.4, 0.85, 0.4, 0.7)
		elif is_actual:
			s.bg_color = Color(0.20, 0.16, 0.06, 0.95)
			s.set_border_width_all(2)
			s.border_color = Color(0.9, 0.7, 0.2, 0.7)
		else:
			s.bg_color = Color(0.07, 0.14, 0.08, 0.88)
		s.set_corner_radius_all(5)
		row_panel.add_theme_stylebox_override("panel", s)

		# ★ マーク
		if is_best:
			var star := _make_label("★", Vector2(6, 8), 22)
			star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			row_panel.add_child(star)
		if is_actual:
			var act := _make_label("→", Vector2(6, 8), 22)
			act.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
			row_panel.add_child(act)

		# 牌画像
		var tile_dict := {"id": int(r.get("tile_id", -1)), "is_red": false, "is_gold": false, "is_haku_pochi": false}
		for ht: Dictionary in _hand:
			if ht.id == tile_dict.id:
				tile_dict = ht.duplicate(); break
		var tile_img := TextureRect.new()
		tile_img.position = Vector2(32, 8)
		tile_img.size = Vector2(44, 60)
		tile_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile_img.texture = _get_tile_texture(tile_dict)
		row_panel.add_child(tile_img)

		# 牌名
		var name_lbl := _make_label(str(r.get("tile_name", "")), Vector2(82, 4), 35)
		row_panel.add_child(name_lbl)

		# 向聴テキスト
		var shan_lbl := _make_label(str(r.get("shanten_text", "")), Vector2(250, 4), 35)
		shan_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45) if shanten_val == 0 else Color(0.9, 0.9, 0.7))
		row_panel.add_child(shan_lbl)

		# 有効牌枚数
		var eff_lbl := _make_label("有効牌 %d枚（期待%.1f枚）" % [r.get("effective_count", 0), float(r.get("effective_count_expected", 0.0))], Vector2(450, 8), 28)
		eff_lbl.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
		row_panel.add_child(eff_lbl)

		# テンパイ率・和了率
		var tenpai_r: float = float(r.get("tenpai_rate", -1.0))
		var agari_r: float  = float(r.get("agari_rate",  -1.0))
		if tenpai_r < 0.0:
			var dash := _make_label("—", Vector2(82, 52), 28)
			dash.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
			row_panel.add_child(dash)
		elif shanten_val == 0:
			var a_lbl := _make_label("和了率 %.2f%%" % (agari_r * 100.0), Vector2(82, 50), 35)
			a_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
			row_panel.add_child(a_lbl)
		elif shanten_val == 1:
			var t_lbl := _make_label("テンパイ率 %.2f%%" % (tenpai_r * 100.0), Vector2(82, 50), 35)
			t_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
			row_panel.add_child(t_lbl)
			var a_lbl := _make_label("和了率 %.2f%%" % (agari_r * 100.0), Vector2(380, 50), 28)
			a_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
			row_panel.add_child(a_lbl)
		elif shanten_val == 2:
			var t_lbl := _make_label("1シャンテン率 %.2f%%" % (tenpai_r * 100.0), Vector2(82, 50), 35)
			t_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
			row_panel.add_child(t_lbl)
			if agari_r >= 0.0:
				var a_lbl := _make_label("テンパイ率 %.2f%%" % (agari_r * 100.0), Vector2(390, 50), 28)
				a_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
				row_panel.add_child(a_lbl)
		else:
			var t_lbl := _make_label("1シャンテン率 %.2f%%" % (tenpai_r * 100.0), Vector2(82, 50), 35)
			t_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
			row_panel.add_child(t_lbl)

		if is_actual:
			var act_tag := _make_label("←実際", Vector2(620, 8), 22)
			act_tag.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
			row_panel.add_child(act_tag)

		# breakdown 行（牌画像＋テキスト横並び）
		var bd_y := 90.0
		for gid: int in breakdown:
			var bd: Dictionary = breakdown[gid]
			var dummy_t := {"id": gid, "is_red": false, "is_gold": false, "is_haku_pochi": false}
			var tex := _get_tile_texture(dummy_t)
			if tex:
				var ti := TextureRect.new()
				ti.position = Vector2(10, bd_y)
				ti.size = Vector2(44, 60)
				ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ti.texture = tex
				row_panel.add_child(ti)
			var w_cnt: int = int(bd.get("wall_count", 0))
			var exp_f: float = float(bd.get("expected", 0.0))
			var cnt_lbl := _make_label("×%d（期待%.1f枚）" % [w_cnt, exp_f], Vector2(60, bd_y + 16), 24)
			cnt_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
			row_panel.add_child(cnt_lbl)
			var draw_pct: float = float(bd.get("tenpai_rate", 0.0)) * 100.0
			var draw_lbl := _make_label("引く確率%.2f%%" % draw_pct, Vector2(260, bd_y + 16), 24)
			draw_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
			row_panel.add_child(draw_lbl)
			var ar_v: float = float(bd.get("agari_rate", -1.0))
			if ar_v >= 0.0:
				var rate_label: String = "テンパイ率" if shanten_val == 1 else "繰り上げ率"
				var rate_lbl := _make_label("%s%.2f%%" % [rate_label, minf(ar_v, 1.0) * 100.0], Vector2(460, bd_y + 16), 24)
				rate_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				row_panel.add_child(rate_lbl)
			bd_y += 68.0

		_result_list.add_child(row_panel)

	# 比較行
	if actual_discard_id >= 0 and _results.size() > 1:
		var best: Dictionary = _results[0]
		var actual: Dictionary = {}
		for rr: Dictionary in _results:
			if int(rr.get("tile_id", -1)) == actual_discard_id:
				actual = rr; break
		if not actual.is_empty() and actual.get("tile_id", -1) != best.get("tile_id", -1):
			var diff: int = best.get("effective_count", 0) - actual.get("effective_count", 0)
			var cmp := Panel.new()
			cmp.custom_minimum_size = Vector2(LEFT_W - 16, 48)
			var cs := StyleBoxFlat.new()
			cs.bg_color = Color(0.16, 0.09, 0.03, 0.92)
			cs.set_corner_radius_all(5)
			cmp.add_theme_stylebox_override("panel", cs)
			var txt := "実際: %s（%s・%d枚）　最善: %s（%s・%d枚）　差 -%d枚" % [
				actual.get("tile_name", "?"), actual.get("shanten_text", "?"), actual.get("effective_count", 0),
				best.get("tile_name", "?"), best.get("shanten_text", "?"), best.get("effective_count", 0),
				diff,
			]
			var cl := _make_label(txt, Vector2(10, 12), 18)
			cl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			cmp.add_child(cl)
			_result_list.add_child(cmp)

# ============================================================
# ナビゲーション
# ============================================================
func _on_back_pressed() -> void:
	actual_discard_id = -1
	log_context_label = ""
	get_tree().change_scene_to_file("res://Menu.tscn")

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

func _make_step_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(28, 26)
	btn.add_theme_font_size_override("font_size", 15)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.26, 0.16)
	s.set_corner_radius_all(4)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.26, 0.40, 0.26)
	var ds := s.duplicate() as StyleBoxFlat
	ds.bg_color = Color(0.10, 0.14, 0.10, 0.35)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("disabled", ds)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return btn

# ============================================================
# ヘルパー: 牌テクスチャ
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
