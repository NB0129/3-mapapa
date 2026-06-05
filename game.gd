extends Control

# ============================================================
# UI ノード参照
# ============================================================
var _bg: ColorRect
var _info_label: Label       # 何場表示：局・本場
var _wall_label: Label       # 何場表示：残り枚数
var _upper_score_label: Label  # 何場表示：上家スコア
var _right_score_label: Label  # 何場表示：右家スコア
var _upper_discard_box: Control
var _right_discard_box: Control
var _player_score_label: Label
var _hand_box: Control
var _tenpai_assist_box: Control
var _player_discard_box: Control
var _btn_discard: Button
var _btn_tsumo: Button
var _btn_ron: Button
var _btn_open_riichi: Button
var _btn_riichi: Button
var _btn_pon: Button
var _btn_kita: Button
var _btn_kan: Button
var _btn_skip: Button
var _action_box: Control
var _win_overlay: ColorRect
var _msg_panel: Panel
var _msg_label: Label
var _msg_ok: Button
var _btn_table_view: Button
var _btn_result_back: Button
var _status_label: Label
var _haku_pochi_lbl: Label
var _haku_pochi_img: TextureRect
var _npc_left_chara: TextureRect
var _npc_right_chara: TextureRect
var _result_dynamic_nodes: Array = []
var _double_ron_result_queue: Array = []
var _double_ron_result_index: int = -1
var _reach_cutin: CanvasLayer
var _riichi_stick_layer: Node2D
var _reach_stick_texture: Texture2D
var _empty_riichi_stick_count: int = 0

var _upper_hand_box: Control
var _upper_meld_box: Control
var _right_hand_box: Control
var _right_meld_box: Control
var _player_meld_box: Control
var _haimen_texture: Texture2D

var _tile_buttons: Array = []
var _tile_texture_cache: Dictionary = {}
var _selected_idx: int = -1
var _riichi_mode: bool = false
var _riichi_is_open: bool = false
var _riichi_selectable: Array = []
var _show_player_hand_as_touhai: bool = false
var _pon_select_mode: bool = false
var _pon_selectable: Array = []
var _kan_select_mode: bool = false
var _kan_selectable: Array = []
var _player_drew: bool = false
var _riichi_kan_ready: bool = false
var _btn_riichi_cancel: Button
var _player_nukita_box: Control
var _upper_nukita_box: Control
var _right_nukita_box: Control
var _wanpai_box: Control
var _wanpai_dora_rect: TextureRect
var _wanpai_dora_rects: Array = []
var _wanpai_ura_rects: Array = []
var _wanpai_rinshan_rects: Array = []
var _wanpai_use_count: int = 0
var _btn_settings_icon: Button
var _btn_home_icon: Button
var _btn_rules_icon: Button
var _settings_popup: Panel
var _home_confirm_popup: Panel
var _rules_popup: Panel
var _rules_body_label: Label
var _rules_scroll: ScrollContainer
var _rules_tab_buttons: Array = []
var _bgm_slider: HSlider
var _bgm_title_label: Label
var _se_slider: HSlider
var _assist_mode_option: OptionButton
var _reach_cutin_btn: Button
var _reach_cutin_knob: Panel
var _reach_cutin_knob_label: Label
var _debug_panel: Panel
var _debug_hand_tiles: Array = []   # 13要素、{} = 空スロット（id/is_red/is_gold/is_haku_pochi）
var _debug_draw_tile: Dictionary = {}
var _debug_next_draw_tile: Dictionary = {}
var _debug_cursor: int = 0          # 0-12:手牌 13:ツモ 14:次順ツモ
var _debug_slot_panels: Array = []
var _debug_slot_textures: Array = []
var _debug_error_label: Label
var _debug_target_idx: int = 0
var _debug_title_label: Label
var _debug_rinshan_panel: Panel
var _debug_rinshan_tiles: Array = []
var _debug_rinshan_cursor: int = 0
var _debug_rinshan_slot_panels: Array = []
var _debug_rinshan_slot_textures: Array = []
var _debug_rinshan_error_label: Label

# アシスト関連
var _assist_btn: Button = null
var _assist_mode_label: Label = null
var _assist_toggle_knob: Panel = null
var _assist_toggle_knob_label: Label = null
var _assist_panel: Panel = null
var _assist_star_labels: Array = []
var _assist_visible: bool = false
var _assist_analyzer: SanmaAnalyzer = null
var _assist_cached_dead_tiles: Dictionary = {}
var _assist_cached_total_wall: int = 0
var _assist_cache_ready: bool = false
var _assist_request_serial: int = 0
var _debug_buttons_box: Control
var _debug_show_npc_hands: bool = false
var _player_riichi_cutin_count: int = 0
var _riichi_cutin_running: bool = false
var _riichi_tsumogiri_timer_pending: bool = false
var _npc_riichi_cutin_running: bool = false

const UPPER_IDX := 2
const RIGHT_IDX := 1
const LEFT_IDX  := -1
const CUTIN_REACH_SCENE := preload("res://CutinReach.tscn")
const RULE_BOOK := preload("res://rule_book_data.gd")
const ACTION_IMAGE_BUTTON_SIZE := Vector2(480, 200)
const SCREEN_SIZE := Vector2(1920, 1080)
const RESULT_PANEL_RECT := Rect2(530, 20, 1370, 1040)
const RESULT_STEP_DELAY := 0.2
const NPC_HAND_TEXTURE_PATHS := {
	"kami": [
		"res://assets/tiles/hai_tati_kami.webp",
		"res://assets/tiles/hai_tati_kami1.webp",
		"res://assets/tiles/hai_tati_kami2.webp",
		"res://assets/tiles/hai_tati_kami3.webp",
		"res://assets/tiles/hai_tati_kami4.webp",
	],
	"toi": [
		"res://assets/tiles/hai_tati_toi.webp",
		"res://assets/tiles/hai_tati_toi1.webp",
		"res://assets/tiles/hai_tati_toi2.webp",
		"res://assets/tiles/hai_tati_toi3.webp",
		"res://assets/tiles/hai_tati_toi4.webp",
	],
}

const EAST_BGM_TRACKS := [
	{"path": "res://BGM/bgm_ton1_morinosirokuma.ogg", "title": "森の白くま", "group": ""},
	{"path": "res://BGM/bgm_ton2_syoppingukuma.ogg", "title": "ショッピング白くま", "group": ""},
	{"path": "res://BGM/bgm_ton3_de-tokuma.ogg", "title": "デート白くま", "group": ""},
	{"path": "res://BGM/bgm_ton4_houkadonosirokuma.ogg", "title": "放課後の白くま", "group": ""},
	{"path": "res://BGM/bgm_ton5_gekounosirokuma.ogg", "title": "下校の白くま", "group": ""},
	{"path": "res://BGM/bgm_ton6_madogiwanokuma.ogg", "title": "窓際の白くま", "group": ""},
	{"path": "res://BGM/bgm_ton7_soratobukuma.ogg", "title": "空飛ぶ白くま", "group": ""},
	{"path": "res://BGM/bgm_ton8_youkikuma.ogg", "title": "陽気な白くま", "group": ""},
	{"path": "res://assets/bgm/bgm_neotora.ogg", "title": "トランポリン白くま", "group": ""},
]

const SOUTH_BGM_TRACKS := [
	{"path": "res://BGM/bgm_nan1_akazukinnomondou.ogg", "title": "赤ずきんの問答", "group": "akazukin"},
	{"path": "res://BGM/bgm_nan2_akazukintonotatakai.ogg", "title": "赤ずきんとの闘い", "group": "akazukin"},
	{"path": "res://BGM/bgm_nan3_tanteinomaturo.ogg", "title": "探偵の末路", "group": "tantei"},
	{"path": "res://BGM/bgm_nan4_nerawaretatantei.ogg", "title": "狙われた探偵", "group": "tantei"},
	{"path": "res://BGM/bgm_nan5_rojiuranobakuto.ogg", "title": "路地裏の博徒", "group": ""},
	{"path": "res://BGM/bgm_nan6_hyouzansatujinjiken.ogg", "title": "氷山殺人事件", "group": ""},
]

const OORASU_BGM_TRACKS := [
	{"path": "res://BGM/bgm_ora_wazukanatensa.ogg", "title": "僅かな点差", "group": ""},
	{"path": "res://BGM/bgm_ora2_baityokujouken.ogg", "title": "倍直条件", "group": ""},
	{"path": "res://BGM/bgm_ora3_situyounaosananajimi.ogg", "title": "執拗な幼馴染", "group": ""},
]

const HACHIMI_RIICHI_BGMS := [
	{"path": "res://BGM/bgm_ritia1_otomenoyokoyari.ogg", "title": "乙女の横槍"},
	{"path": "res://BGM/bgm_ritia2_ri-tinomai.ogg", "title": "リーチの舞"},
	{"path": "res://BGM/bgm_ritia3_1000tennnocandy.ogg", "title": "1000点棒キャンディ"},
]

const NPC_VOICE_DEFS := {
	"kuma_def": {
		"folder": "npc1_くまぱぱ", "prefix": "senpc1vo",
		"actions": {"riti": "riti", "ron": "ron", "tumo": "tumo", "pon": "pon", "kan": "kan", "siropotti": "siropotti", "noten": "noten", "tenpai": "tenpai"}
	},
	"kuma_hokkyoku": {
		"folder": "npc2_北極熊", "prefix": "senpc2vo",
		"actions": {"riti": "riti", "ron": "ron", "tumo": "tumo", "noten": "noten", "tenpai": "tenpai"}
	},
	"kuma_megane": {
		"folder": "npc3_眼鏡くま", "prefix": "senpc3vo",
		"actions": {"riti": "riti", "ron": "ron", "tumo": "tumo", "pon": "pon", "kan": "kan", "siropotti": "siropo", "noten": "no-ten", "tenpai": "tenpai"}
	},
	"kuma_hiyake": {
		"folder": "npc4_日焼けくま", "prefix": "senpc4vo",
		"actions": {"riti": "riti", "ron": "ron", "tumo": "tumo", "pon": "pon", "kan": "kan", "siropotti": "siropotti", "noten": "noten", "tenpai": "tenpai"}
	},
	"kuma_black": {
		"folder": "npc5_ブラックくま", "prefix": "senpc5vo",
		"actions": {"riti": "riti", "ron": "ron", "tumo": "tumo", "pon": "pon", "kan": "kan", "siropotti": "siropotti", "noten": "noten", "tenpai": "tenpai"}
	},
	"kuma_saibo": {
		"folder": "npc6_サイボーグくま", "prefix": "senpc6vo",
		"actions": {"riti": "riti", "ron": "ron", "tumo": "tumo", "pon": "pon", "kan": "kan", "siropotti": "siropotti", "noten": "noten", "tenpai": "tenpai"}
	},
}

const NPC_RIICHI_BGMS := {
	"kuma_def": {"path": "res://BGM/bgm_ritinpc1_sirokumari-ti.ogg", "title": "白くまリーチ"},
	"kuma_hokkyoku": {"path": "res://BGM/bgm_ritinpc2_sitteitaka.ogg", "title": "知っていたか？普段ツモ切りしかできない俺でもダブルリーチは打てる～得意な役は天和で和了したら君は死ぬ～"},
	"kuma_megane": {"path": "res://BGM/bgm_ritinpc3_waruikedo.ogg", "title": "先手必勝リーチ"},
	"kuma_hiyake": {"path": "res://BGM/bgm_ritinpc4_hawairi-ti.ogg", "title": "ハワイリーチ"},
	"kuma_black": {"path": "res://BGM/bgm_ritinpc5_ri-tinoame.ogg", "title": "リーチの雨"},
	"kuma_saibo": {"path": "res://BGM/bgm_ritinpc6_mutekinoai.ogg", "title": "無敵のAI"},
}

const NPC_VOICE_VOLUME_SCALE := {
	"kuma_hiyake": 0.7,
}

var _east_bgm_playlist: Array = []
var _south_bgm_playlist: Array = []
var _oorasu_bgm_playlist: Array = []
var _east_bgm_index: int = 0
var _south_bgm_index: int = 0
var _oorasu_bgm_index: int = 0

# ============================================================
# 初期化
# ============================================================
func _ready() -> void:
	_build_ui()
	_connect_signals()
	_build_bgm_playlists()
	GameState.start_game()

# ============================================================
# UI 構築
# ============================================================
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.08, 0.28, 0.12)
	_bg.z_index = -30
	add_child(_bg)

	var bg_tex := TextureRect.new()
	bg_tex.position = Vector2(-288, -202)
	bg_tex.size = Vector2(2496, 1404)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.texture = load("res://assets/bg/bg_takujou.webp")
	bg_tex.z_index = -20
	add_child(bg_tex)
	_build_npc_standing_art()

	# --- 上家 鳴きエリア（画面左上＝上家の右端） ---
	var upper_meld_panel := _make_control_rect(Rect2(430, 10, 260, 160))
	add_child(upper_meld_panel)
	_upper_meld_box = Control.new()
	_upper_meld_box.position = Vector2(10, 10)
	upper_meld_panel.add_child(_upper_meld_box)

	# --- 上家 手牌エリア（上部中央、180° 表示） ---
	var upper_hand_panel := _make_control_rect(Rect2(280, 10, 1130, 160))
	add_child(upper_hand_panel)
	_upper_hand_box = Control.new()
	_upper_hand_box.position = Vector2(400, 20)
	upper_hand_panel.add_child(_upper_hand_box)

	# --- 右家 手牌エリア（右列、-90° 表示）---
	var right_hand_panel := _make_control_rect(Rect2(1670, 10, 240, 500))
	add_child(right_hand_panel)
	_right_hand_box = Control.new()
	_right_hand_box.position = Vector2(-230, 270)
	right_hand_panel.add_child(_right_hand_box)

	_right_meld_box = Control.new()
	_right_meld_box.position = Vector2(1440, 100)
	add_child(_right_meld_box)

	# --- 上家 捨て牌エリア（上家視点の何場表示左下） ---
	var upper_discard_panel := _make_control_rect(Rect2(820, 220, 400, 170))
	add_child(upper_discard_panel)
	_upper_discard_box = Control.new()
	_upper_discard_box.position = Vector2.ZERO
	upper_discard_panel.add_child(_upper_discard_box)

	# --- 右家 捨て牌エリア（右家視点の何場表示左下） ---
	var right_discard_panel := _make_control_rect(Rect2(1124, 366, 490, 260))
	add_child(right_discard_panel)
	_right_discard_box = Control.new()
	_right_discard_box.position = Vector2.ZERO
	right_discard_panel.add_child(_right_discard_box)

	# --- 何場表示（画面中央の正方形）---
	var jouba_panel := _make_panel(Color(0.0, 0.05, 0.15, 0.80), Rect2(830, 370, 260, 260))
	add_child(jouba_panel)
	# 上家スコア（上家視点で手前）
	_upper_score_label = _make_label("", Vector2(50, 7), 19)
	_upper_score_label.size = Vector2(160, 32)
	_upper_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upper_score_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_upper_score_label.pivot_offset = Vector2(80, 16)
	_upper_score_label.rotation_degrees = 180.0
	_upper_score_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	jouba_panel.add_child(_upper_score_label)
	# 局・本場（中央）
	_info_label = _make_label("東一局", Vector2(20, 86), 38)
	_info_label.size = Vector2(220, 54)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	jouba_panel.add_child(_info_label)
	# 残り枚数（中央下）
	_wall_label = _make_label("0本場  残り--枚", Vector2(20, 144), 23)
	_wall_label.size = Vector2(220, 36)
	_wall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wall_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jouba_panel.add_child(_wall_label)
	# 右家スコア（右家視点で手前）
	_right_score_label = _make_label("", Vector2(170, 54), 17)
	_right_score_label.size = Vector2(160, 38)
	_right_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_right_score_label.pivot_offset = Vector2(80, 19)
	_right_score_label.rotation_degrees = -90.0
	_right_score_label.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	jouba_panel.add_child(_right_score_label)
	# プレイヤースコア（下辺）
	_player_score_label = _make_label("", Vector2(50, 224), 19)
	_player_score_label.size = Vector2(160, 32)
	_player_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_score_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_player_score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	jouba_panel.add_child(_player_score_label)

	# --- プレイヤー 捨て牌エリア（プレイヤー視点の何場表示左下） ---
	var player_discard_panel := _make_control_rect(Rect2(820, 655, 400, 175))
	add_child(player_discard_panel)
	_player_discard_box = Control.new()
	_player_discard_box.position = Vector2.ZERO
	player_discard_panel.add_child(_player_discard_box)

	# --- 上家 北抜き表示エリア（上家鳴きパネルの下半分） ---
	# 上家視点では上（画面上）=手牌方向、下=ポン方向なので下半分が「ポンの上の行」
	_upper_nukita_box = Control.new()
	_upper_nukita_box.position = Vector2(10, 90)
	upper_meld_panel.add_child(_upper_nukita_box)

	# --- 右家 北抜き表示エリア（右家手牌パネルの下） ---
	_right_nukita_box = Control.new()
	_right_nukita_box.position = Vector2(1370, 100)
	add_child(_right_nukita_box)

	# --- プレイヤー 北抜き表示エリア（手牌の1行上、右寄せ） ---
	_player_nukita_box = Control.new()
	_player_nukita_box.position = Vector2(1810, 720)
	add_child(_player_nukita_box)

	# --- 王牌エリア（空席=左家位置、背景なし） ---
	_wanpai_box = Control.new()
	_wanpai_box.position = Vector2(460, 355)
	_wanpai_box.scale = Vector2(0.7, 0.7)
	add_child(_wanpai_box)
	# 王牌表示を初期化（左4つ=嶺上牌, 右端=ドラ表示牌）
	_build_wanpai_display()

	# --- プレイヤーエリア ---
	var player_hand_mask := _make_panel(Color(0, 0, 0, 0.5), Rect2(10, 841, 1900, 239))
	add_child(player_hand_mask)

	var player_panel := _make_control_rect(Rect2(10, 710, 1900, 330))
	add_child(player_panel)

	_hand_box = Control.new()
	_hand_box.position = Vector2(10, 136)
	player_panel.add_child(_hand_box)

	_tenpai_assist_box = Control.new()
	_tenpai_assist_box.position = Vector2(1280, -16)
	_tenpai_assist_box.size = Vector2(620, 112)
	player_panel.add_child(_tenpai_assist_box)

	# アシストボタン
	_assist_mode_label = _make_label("アシスト", Vector2(1532, 646), 28)
	_assist_mode_label.size = Vector2(140, 40)
	_assist_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_assist_mode_label.add_theme_color_override("font_color", Color(0.88, 0.95, 0.90))
	_assist_mode_label.visible = false
	add_child(_assist_mode_label)

	_assist_btn = _make_button("", Color(0.2, 0.3, 0.6))
	_assist_btn.custom_minimum_size = Vector2(198, 87)
	_assist_btn.size = _assist_btn.custom_minimum_size
	_assist_btn.position = Vector2(1682, 620)
	_assist_btn.clip_contents = false
	_assist_btn.focus_mode = Control.FOCUS_NONE
	_set_assist_toggle_visible(false)
	_assist_btn.pressed.connect(_on_assist_pressed)
	add_child(_assist_btn)
	_assist_toggle_knob = Panel.new()
	_assist_toggle_knob.size = Vector2(81, 81)
	_assist_toggle_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_assist_btn.add_child(_assist_toggle_knob)
	_assist_toggle_knob_label = Label.new()
	_assist_toggle_knob_label.size = _assist_toggle_knob.size
	_assist_toggle_knob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_assist_toggle_knob_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_assist_toggle_knob_label.add_theme_font_size_override("font_size", 24)
	_assist_toggle_knob_label.add_theme_color_override("font_color", Color(0.08, 0.10, 0.10))
	_assist_toggle_knob_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_assist_toggle_knob.add_child(_assist_toggle_knob_label)
	_refresh_assist_toggle_button()

	# アシスト結果パネル（左キャラエリアに重ねる形で初期非表示）
	_assist_panel = _make_panel(Color(0.03, 0.10, 0.05, 0.92), Rect2(10, 10, 460, 828))
	_assist_panel.visible = false
	_assist_panel.z_index = 20
	add_child(_assist_panel)
	var assist_title := _make_label("─ アシスト ─", Vector2(10, 10), 24)
	assist_title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_assist_panel.add_child(assist_title)

	# プレイヤー 鳴き牌エリア（プレイヤーパネル右端から左へ伸びる）
	_player_meld_box = Control.new()
	_player_meld_box.position = Vector2(10, 136)
	player_panel.add_child(_player_meld_box)

	_action_box = Control.new()
	_action_box.position = Vector2(-10, -70)
	_action_box.size = Vector2(1920, 200)
	player_panel.add_child(_action_box)

	_btn_discard = _make_button("捨てる", Color(0.7, 0.3, 0.3))
	_btn_discard.custom_minimum_size = Vector2(120, 50)
	_btn_discard.pressed.connect(_on_discard_pressed)
	_btn_discard.visible = false
	_action_box.add_child(_btn_discard)

	_btn_tsumo = _make_button("ツモ", Color(0.2, 0.6, 0.2))
	_apply_button_image(_btn_tsumo, "res://assets/ui/btn_tumo.webp", "ツモ")
	_btn_tsumo.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_tsumo.pressed.connect(_on_tsumo_pressed)
	_action_box.add_child(_btn_tsumo)

	_btn_ron = _make_button("ロン", Color(0.7, 0.5, 0.1))
	_apply_button_image(_btn_ron, "res://assets/ui/btn_ron.webp", "ロン")
	_btn_ron.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_ron.pressed.connect(_on_ron_pressed)
	_action_box.add_child(_btn_ron)

	_btn_open_riichi = _make_button("", Color(0.5, 0.1, 0.7))
	_apply_button_image(_btn_open_riichi, "res://assets/ui/btn_ritiop.webp", "オープン立直")
	_btn_open_riichi.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_open_riichi.pressed.connect(_on_open_riichi_pressed)
	_action_box.add_child(_btn_open_riichi)

	_btn_riichi = _make_button("リーチ", Color(0.5, 0.1, 0.7))
	_apply_button_image(_btn_riichi, "res://assets/ui/btn_riti.webp", "リーチ")
	_btn_riichi.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_riichi.pressed.connect(_on_riichi_pressed)
	_action_box.add_child(_btn_riichi)

	_btn_pon = _make_button("ポン", Color(0.2, 0.4, 0.7))
	_apply_button_image(_btn_pon, "res://assets/ui/btn_pon.webp", "ポン")
	_btn_pon.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_pon.pressed.connect(_on_pon_pressed)
	_action_box.add_child(_btn_pon)

	_btn_kita = _make_button("北抜き", Color(0.1, 0.5, 0.5))
	_apply_button_image(_btn_kita, "res://assets/ui/btn_kita.webp", "北抜き")
	_btn_kita.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_kita.pressed.connect(_on_kita_pressed)
	_action_box.add_child(_btn_kita)

	_btn_kan = _make_button("カン", Color(0.5, 0.2, 0.6))
	_apply_button_image(_btn_kan, "res://assets/ui/btn_kan.webp", "カン")
	_btn_kan.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_kan.pressed.connect(_on_kan_pressed)
	_action_box.add_child(_btn_kan)

	_btn_skip = _make_button("スキップ", Color(0.4, 0.4, 0.4))
	_apply_button_image(_btn_skip, "res://assets/ui/btn_kyan.webp", "キャンセル")
	_btn_skip.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_skip.pressed.connect(_on_skip_pressed)
	_action_box.add_child(_btn_skip)

	# リーチモード中のみ表示されるキャンセルボタン
	_btn_riichi_cancel = _make_button("リーチキャンセル", Color(0.4, 0.1, 0.5))
	_apply_button_image(_btn_riichi_cancel, "res://assets/ui/btn_kyan.webp", "キャンセル")
	_btn_riichi_cancel.custom_minimum_size = ACTION_IMAGE_BUTTON_SIZE
	_btn_riichi_cancel.pressed.connect(_on_riichi_cancel_pressed)
	_btn_riichi_cancel.visible = false
	_action_box.add_child(_btn_riichi_cancel)

	_debug_buttons_box = _build_debug_buttons()
	_debug_buttons_box.position = Vector2(10, 88)
	_debug_buttons_box.z_index = 20
	_debug_buttons_box.visible = false
	player_panel.add_child(_debug_buttons_box)

	_status_label = _make_label("", Vector2(10, 680), 24)
	_status_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_status_label.visible = false
	add_child(_status_label)

	_bgm_title_label = _make_label("", Vector2(10, 88), 40)
	_bgm_title_label.size = Vector2(900, 50)
	_bgm_title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_bgm_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_bgm_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_bgm_title_label.add_theme_constant_override("shadow_offset_y", 2)
	player_panel.add_child(_bgm_title_label)

	# --- 結果オーバーレイ ---
	_win_overlay = ColorRect.new()
	_win_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.color = Color(0, 0, 0, 0.68)
	_win_overlay.visible = false
	_win_overlay.z_index = 50
	add_child(_win_overlay)

	_msg_panel = Panel.new()
	_msg_panel.custom_minimum_size = Vector2(860, 520)
	_msg_panel.position = Vector2(530, 280)
	_msg_panel.visible = false
	_msg_panel.z_index = 70
	var msg_style := StyleBoxFlat.new()
	msg_style.bg_color = Color(0.12, 0.12, 0.18)
	msg_style.border_color = Color(0.6, 0.5, 0.1)
	msg_style.set_border_width_all(3)
	msg_style.set_corner_radius_all(10)
	_msg_panel.add_theme_stylebox_override("panel", msg_style)
	add_child(_msg_panel)

	_msg_label = Label.new()
	_msg_label.position = Vector2(30, 30)
	_msg_label.custom_minimum_size = Vector2(620, 420)
	_msg_label.add_theme_font_size_override("font_size", 22)
	_msg_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_msg_panel.add_child(_msg_label)

	_haku_pochi_lbl = Label.new()
	_haku_pochi_lbl.position = Vector2(670, 30)
	_haku_pochi_lbl.add_theme_font_size_override("font_size", 18)
	_haku_pochi_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_haku_pochi_lbl.text = "白ポッチ\n→"
	_haku_pochi_lbl.visible = false
	_msg_panel.add_child(_haku_pochi_lbl)

	_haku_pochi_img = TextureRect.new()
	_haku_pochi_img.position = Vector2(670, 85)
	_haku_pochi_img.custom_minimum_size = Vector2(140, 190)
	_haku_pochi_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_haku_pochi_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_haku_pochi_img.visible = false
	_msg_panel.add_child(_haku_pochi_img)

	_msg_ok = _make_button("次の局へ", Color(0.15, 0.45, 0.75))
	_msg_ok.position = Vector2(350, 460)
	_msg_ok.custom_minimum_size = Vector2(160, 50)
	_msg_ok.pressed.connect(_on_msg_ok_pressed)
	_msg_panel.add_child(_msg_ok)

	_btn_table_view = _make_button("卓上を見る", Color(0.28, 0.34, 0.44))
	_btn_table_view.position = Vector2(350, 390)
	_btn_table_view.custom_minimum_size = Vector2(160, 50)
	_btn_table_view.pressed.connect(_on_table_view_pressed)
	_btn_table_view.visible = false
	_msg_panel.add_child(_btn_table_view)

	_btn_result_back = _make_button("戻る", Color(0.20, 0.32, 0.48))
	_btn_result_back.position = Vector2(1700, 990)
	_btn_result_back.custom_minimum_size = Vector2(160, 58)
	_btn_result_back.size = _btn_result_back.custom_minimum_size
	_btn_result_back.z_index = 90
	_btn_result_back.pressed.connect(_on_result_back_pressed)
	_btn_result_back.visible = false
	add_child(_btn_result_back)

	# --- アイコンボタン（ホーム・ルール・設定） ---
	var icon_area_mask := _make_panel(Color(0.02, 0.04, 0.06, 0.56), Rect2(1484, 0, 436, 142))
	icon_area_mask.z_index = 5
	add_child(icon_area_mask)

	_btn_home_icon = _make_icon_button("res://assets/bg/icon_home.webp")
	_btn_home_icon.position = Vector2(1506, 7)
	_btn_home_icon.size = Vector2(128, 128)
	_btn_home_icon.z_index = 6
	_btn_home_icon.pressed.connect(_on_home_icon_pressed)
	add_child(_btn_home_icon)

	_btn_rules_icon = _make_icon_button("res://ui/icon_ru-ru.webp")
	_btn_rules_icon.position = Vector2(1645, 7)
	_btn_rules_icon.size = Vector2(128, 128)
	_btn_rules_icon.z_index = 6
	_btn_rules_icon.pressed.connect(_on_rules_icon_pressed)
	add_child(_btn_rules_icon)

	_btn_settings_icon = _make_icon_button("res://assets/bg/icon_settei.webp")
	_btn_settings_icon.position = Vector2(1784, 7)
	_btn_settings_icon.size = Vector2(128, 128)
	_btn_settings_icon.z_index = 6
	_btn_settings_icon.pressed.connect(_on_settings_icon_pressed)
	add_child(_btn_settings_icon)

	# --- 設定ポップアップ ---
	_settings_popup = _build_settings_popup()
	add_child(_settings_popup)
	_settings_popup.visible = false

	# --- ホーム確認ポップアップ ---
	_home_confirm_popup = _build_home_confirm_popup()
	add_child(_home_confirm_popup)
	_home_confirm_popup.visible = false

	_rules_popup = _build_rules_popup()
	add_child(_rules_popup)
	_rules_popup.visible = false

	# --- デバッグパネル ---
	_debug_panel = _build_debug_panel()
	add_child(_debug_panel)
	_debug_panel.visible = false

	# --- 嶺上牌デバッグパネル ---
	_debug_rinshan_panel = _build_rinshan_debug_panel()
	add_child(_debug_rinshan_panel)
	_debug_rinshan_panel.visible = false

	_riichi_stick_layer = Node2D.new()
	_riichi_stick_layer.z_index = -5
	add_child(_riichi_stick_layer)

	_reach_cutin = CUTIN_REACH_SCENE.instantiate()
	add_child(_reach_cutin)

	_set_action_buttons_state(false, false, false, false, false, false, false, false)

func _build_npc_standing_art() -> void:
	var standing_ids: Dictionary = _get_standing_npc_ids()
	var left_id: String = standing_ids.left
	var right_id: String = standing_ids.right
	_npc_left_chara = _make_standing_texture(SaveData.get_npc_path_game(left_id), Vector2(-70, 95), Vector2(520, 960))
	_npc_right_chara = _make_standing_texture(SaveData.get_npc_path_game(right_id), Vector2(1470, -120), Vector2(520, 960))
	add_child(_npc_left_chara)
	add_child(_npc_right_chara)

func _get_standing_npc_ids() -> Dictionary:
	var seats: Dictionary = SaveData.selected_npc_seats
	var bottom_id := str(seats.get("bottom", ""))
	var right_id := str(seats.get("right", ""))
	var top_id := str(seats.get("top", ""))
	if bottom_id == "":
		return {
			"left": top_id if top_id != "" else "kuma_def",
			"right": right_id if right_id != "" else "kuma_hiyake",
		}
	var left_id := right_id if right_id != "" else top_id
	return {
		"left": left_id if left_id != "" else "kuma_def",
		"right": bottom_id,
	}

func _make_standing_texture(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.position = pos
	rect.size = size
	rect.texture = _make_used_rect_texture(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = -25
	return rect

# ============================================================
# シグナル接続
# ============================================================
func _connect_signals() -> void:
	GameState.game_started.connect(_on_game_started)
	GameState.turn_started.connect(_on_turn_started)
	GameState.tile_drawn.connect(_on_tile_drawn)
	GameState.tile_discarded.connect(_on_tile_discarded)
	GameState.tsumo_declared.connect(_on_tsumo_declared)
	GameState.ron_opportunity.connect(_on_ron_opportunity)
	GameState.pon_opportunity.connect(_on_pon_opportunity)
	GameState.riichi_declared.connect(_on_riichi_declared)
	GameState.kita_removed.connect(_on_kita_removed)
	GameState.ankan_done.connect(_on_ankan_done)
	GameState.minkan_done.connect(_on_minkan_done)
	GameState.kakan_done.connect(_on_kakan_done)
	GameState.naki_done.connect(_on_naki_done)
	GameState.game_ended.connect(_on_game_ended)
	GameState.match_ended.connect(_on_match_ended)
	GameState.wall_count_changed.connect(_on_wall_count_changed)
	GameState.npc_thinking.connect(_on_npc_thinking)

# ============================================================
# シグナルハンドラ
# ============================================================
func _on_game_started() -> void:
	_update_round_bgm()
	_selected_idx = -1
	_riichi_mode = false
	_riichi_is_open = false
	_riichi_selectable.clear()
	_pon_select_mode = false
	_pon_selectable.clear()
	_kan_select_mode = false
	_kan_selectable.clear()
	_player_drew = false
	_riichi_kan_ready = false
	_show_player_hand_as_touhai = false
	_wanpai_use_count = 0
	# 王牌をリセット（局開始ごとに嶺上牌4表示に戻す）
	_wanpai_use_count = 0
	for tr in _wanpai_rinshan_rects:
		if is_instance_valid(tr):
			tr.visible = true
	_refresh_wanpai_dora()
	_refresh_all()
	_refresh_assist_toggle_button()
	if _assist_btn != null:
		_set_assist_toggle_visible(false)
	_hide_assist()
	_status_label.text = "ゲーム開始！"
	if GameState.kyoku == 1 and GameState.round_wind == MahjongLogic.EAST and GameState.honba == 0:
		_play_chara_voice("seplavo_yoro2")

func _update_round_bgm() -> void:
	var track: Dictionary = _next_bgm_track()
	if track.is_empty():
		return
	AudioManager.play_bgm_path(track.path)
	_bgm_title_label.text = "♪" + str(track.title)

func _build_bgm_playlists() -> void:
	_east_bgm_playlist = _shuffle_bgm_tracks(EAST_BGM_TRACKS)
	_south_bgm_playlist = _shuffle_bgm_tracks(SOUTH_BGM_TRACKS, true)
	_oorasu_bgm_playlist = _shuffle_bgm_tracks(OORASU_BGM_TRACKS)
	_east_bgm_index = 0
	_south_bgm_index = 0
	_oorasu_bgm_index = 0

func _shuffle_bgm_tracks(source_tracks: Array, avoid_same_group_neighbors: bool = false) -> Array:
	var tracks: Array = source_tracks.duplicate(true)
	if not avoid_same_group_neighbors:
		tracks.shuffle()
		return tracks

	var best: Array = tracks.duplicate(true)
	var best_conflicts: int = 999
	for _try_i in range(40):
		var candidate: Array = tracks.duplicate(true)
		candidate.shuffle()
		var conflicts: int = _count_bgm_group_conflicts(candidate)
		if conflicts < best_conflicts:
			best = candidate
			best_conflicts = conflicts
			if conflicts == 0:
				break
	return best

func _count_bgm_group_conflicts(tracks: Array) -> int:
	var conflicts := 0
	for i in range(1, tracks.size()):
		var prev_group: String = tracks[i - 1].get("group", "")
		var current_group: String = tracks[i].get("group", "")
		if current_group != "" and current_group == prev_group:
			conflicts += 1
	return conflicts

func _next_bgm_track() -> Dictionary:
	if GameState.round_wind == MahjongLogic.SOUTH and GameState.kyoku == 3:
		return _next_track_from_playlist(_oorasu_bgm_playlist, "_oorasu_bgm_index")
	if GameState.round_wind == MahjongLogic.SOUTH:
		return _next_track_from_playlist(_south_bgm_playlist, "_south_bgm_index")
	return _next_track_from_playlist(_east_bgm_playlist, "_east_bgm_index")

func _next_track_from_playlist(playlist: Array, index_property: String) -> Dictionary:
	if playlist.is_empty():
		return {}
	var idx: int = get(index_property)
	var track: Dictionary = playlist[idx % playlist.size()]
	set(index_property, idx + 1)
	return track

func _on_turn_started(player_idx: int) -> void:
	_hide_assist()
	if player_idx == 0:
		_refresh_hand()
		if GameState.phase == GameState.Phase.AFTER_PON:
			_status_label.text = "ポン！捨て牌を選んでください"
		else:
			_status_label.text = "あなたのターン"
		_check_tsumo_auto()
		if GameState.players[0].is_riichi and GameState.phase == GameState.Phase.PLAYER_TURN:
			_handle_riichi_draw()
	else:
		var p_name: String = GameState.players[player_idx].name
		_status_label.text = p_name + "が考え中..."
	_refresh_npc_areas()

func _on_tile_drawn(player_idx: int) -> void:
	if player_idx == 0:
		_player_drew = true
		_assist_cached_dead_tiles = _build_assist_dead_tiles()
		_assist_cached_total_wall = GameState.wall.size()
		_assist_cache_ready = true
		_refresh_hand()
		call_deferred("_refresh_player_draw_actions")
		if GameState.phase == GameState.Phase.PLAYER_TURN:
			_check_tsumo_auto()
			if GameState.players[0].is_riichi:
				_handle_riichi_draw()

func _refresh_player_draw_actions() -> void:
	if not _player_drew:
		return
	if GameState.current_player != 0:
		return
	if GameState.phase != GameState.Phase.PLAYER_TURN and GameState.phase != GameState.Phase.AFTER_PON:
		return
	_check_tsumo_auto()
	if GameState.players[0].is_riichi and GameState.phase == GameState.Phase.PLAYER_TURN:
		_handle_riichi_draw()
	if _assist_btn != null:
		_set_assist_toggle_visible(_can_show_assist_toggle())
	_refresh_auto_assist()

func _on_tile_discarded(_player_idx: int, _tile: Dictionary) -> void:
	_player_drew = false
	_riichi_kan_ready = false
	_riichi_tsumogiri_timer_pending = false
	_riichi_mode = false
	_riichi_is_open = false
	_riichi_selectable.clear()
	_pon_select_mode = false
	_pon_selectable.clear()
	_kan_select_mode = false
	_kan_selectable.clear()
	_selected_idx = -1
	_clear_tenpai_assist()
	_btn_skip.tooltip_text = "キャンセル"
	_refresh_all()
	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	if _assist_btn != null:
		_set_assist_toggle_visible(false)
	_hide_assist()

func _on_tsumo_declared(_player_idx: int, _result: Dictionary) -> void:
	_riichi_tsumogiri_timer_pending = false
	if _player_idx == 0 and _result.has("haku_pochi_best_tile"):
		_play_chara_voice("seplavo_potti")
	_refresh_all()

func _on_ron_opportunity(_winner_idx: int, loser_idx: int, tile: Dictionary) -> void:
	_riichi_tsumogiri_timer_pending = false
	var tile_name := MahjongLogic.get_tile_name(tile)
	var discarder: Dictionary = GameState.players[loser_idx]
	var discarder_name: String = discarder.name
	_status_label.text = discarder_name + " が " + tile_name + " を捨てました"
	var can_pon: bool = GameState.action_pon_from >= 0
	var can_minkan: bool = GameState.action_minkan_possible
	_set_action_buttons_state(false, false, true, true, false, can_pon, false, can_minkan)

func _on_pon_opportunity(_player_idx: int, from_idx: int, tile: Dictionary) -> void:
	var tile_name := MahjongLogic.get_tile_name(tile)
	var discarder: Dictionary = GameState.players[from_idx]
	var discarder_name: String = discarder.name
	var can_minkan: bool = GameState.action_minkan_possible
	var suffix: String = "　ポン可" + ("・大明槓可" if can_minkan else "")
	_status_label.text = discarder_name + " が " + tile_name + " を捨てました" + suffix
	_set_action_buttons_state(false, false, false, true, false, true, false, can_minkan)

func _on_riichi_declared(player_idx: int) -> void:
	_refresh_scores()
	_refresh_npc_areas()
	_refresh_riichi_stick_display()
	if player_idx == 0:
		_status_label.text = "リーチ！"
		var npc_riichi: bool = GameState.players[1].is_riichi or GameState.players[2].is_riichi
		_play_chara_voice("seplavo_gote" if npc_riichi else "seplavo_sennsei")
		_play_riichi_bgm()
	else:
		var npc_id := _get_npc_id_for_player(player_idx)
		if not SaveData.reach_cutin_enabled:
			_play_npc_voice(player_idx, "riti")
			_play_npc_riichi_bgm(player_idx)
			GameState.emit_signal("riichi_cutin_finished")
			return
		if npc_id == "kuma_hiyake":
			await _run_npc_riichi_cutin_hiyake(player_idx)
		elif npc_id == "kuma_megane":
			await _run_npc_riichi_cutin_megane(player_idx)
		elif npc_id == "kuma_saibo":
			await _run_npc_riichi_cutin_saibo(player_idx)
		else:
			_play_npc_voice(player_idx, "riti")
			_play_npc_riichi_bgm(player_idx)
			GameState.emit_signal("riichi_cutin_finished")

func _run_npc_riichi_cutin_hiyake(player_idx: int) -> void:
	if _npc_riichi_cutin_running:
		GameState.emit_signal("riichi_cutin_finished")
		return
	_npc_riichi_cutin_running = true

	_set_action_buttons_state(false, false, false, false, false, false, false, false)

	AudioManager.stop_bgm()

	var wave_tex: Texture2D = load("res://chara/nami.webp")
	var wave_img := TextureRect.new()
	wave_img.texture = wave_tex
	wave_img.position = Vector2(-1920, 0)
	wave_img.size = Vector2(1920, 1080)
	wave_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wave_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wave_img.z_index = 100
	add_child(wave_img)

	AudioManager.play_se("se_riti_nami.ogg")

	var tween_in := create_tween()
	tween_in.tween_property(wave_img, "position", Vector2(0, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished

	await get_tree().create_timer(0.3).timeout

	var tween_out := create_tween()
	tween_out.tween_property(wave_img, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)

	_play_npc_voice(player_idx, "riti")
	_play_npc_riichi_bgm(player_idx)

	await tween_out.finished
	wave_img.queue_free()

	_npc_riichi_cutin_running = false
	GameState.emit_signal("riichi_cutin_finished")

func _run_npc_riichi_cutin_megane(player_idx: int) -> void:
	if _npc_riichi_cutin_running:
		GameState.emit_signal("riichi_cutin_finished")
		return
	_npc_riichi_cutin_running = true

	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	AudioManager.stop_bgm()

	var blackout := ColorRect.new()
	blackout.color = Color(0, 0, 0, 0.0)
	blackout.position = Vector2.ZERO
	blackout.size = SCREEN_SIZE
	blackout.z_index = 100
	add_child(blackout)

	var megane_tex: Texture2D = load("res://chara/megane.webp")
	var megane_img := TextureRect.new()
	megane_img.texture = megane_tex
	megane_img.size = megane_tex.get_size()
	megane_img.position = (SCREEN_SIZE - megane_img.size) * 0.5
	megane_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	megane_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	megane_img.modulate.a = 0.0
	megane_img.z_index = 101
	add_child(megane_img)

	var kira_tex: Texture2D = load("res://chara/kira.webp")
	var kira_img := TextureRect.new()
	kira_img.texture = kira_tex
	kira_img.size = kira_tex.get_size()
	kira_img.pivot_offset = kira_img.size * 0.5
	var kira_center := Vector2(megane_img.position.x + megane_img.size.x, megane_img.position.y + megane_img.size.y * 0.42)
	kira_img.position = kira_center - kira_img.pivot_offset
	kira_img.scale = Vector2(0.05, 0.05)
	kira_img.modulate.a = 0.0
	kira_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kira_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kira_img.z_index = 102
	add_child(kira_img)

	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(blackout, "color:a", 0.72, 0.3)
	fade_in.tween_property(megane_img, "modulate:a", 1.0, 0.3)
	await fade_in.finished

	kira_img.modulate.a = 1.0
	AudioManager.play_se("se_riti_megane.ogg")

	for scale_value in [0.15, 0.30, 0.45, 0.60, 0.75, 0.90]:
		var scale_tween := create_tween()
		scale_tween.tween_property(kira_img, "scale", Vector2(scale_value, scale_value), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await scale_tween.finished

	var kira_out := create_tween()
	kira_out.tween_property(kira_img, "modulate:a", 0.0, 0.18)
	await kira_out.finished

	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(blackout, "color:a", 0.0, 0.35)
	fade_out.tween_property(megane_img, "modulate:a", 0.0, 0.35)

	_play_npc_voice(player_idx, "riti")
	_play_npc_riichi_bgm(player_idx)

	await fade_out.finished
	blackout.queue_free()
	megane_img.queue_free()
	kira_img.queue_free()

	_npc_riichi_cutin_running = false
	GameState.emit_signal("riichi_cutin_finished")

func _run_npc_riichi_cutin_saibo(player_idx: int) -> void:
	if _npc_riichi_cutin_running:
		GameState.emit_signal("riichi_cutin_finished")
		return
	_npc_riichi_cutin_running = true

	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	AudioManager.stop_bgm()

	var blackout := ColorRect.new()
	blackout.color = Color(0, 0, 0, 0.0)
	blackout.position = Vector2.ZERO
	blackout.size = SCREEN_SIZE
	blackout.z_index = 100
	add_child(blackout)

	var taminaru_tex: Texture2D = load("res://chara/taminaru.webp")
	var taminaru_img := TextureRect.new()
	taminaru_img.texture = taminaru_tex
	taminaru_img.size = taminaru_tex.get_size()
	taminaru_img.scale = Vector2(7.0, 7.0)
	taminaru_img.position = (SCREEN_SIZE - taminaru_img.size * 7.0) * 0.5 + Vector2(0, 80)
	taminaru_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	taminaru_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	taminaru_img.modulate.a = 0.0
	taminaru_img.z_index = 101
	add_child(taminaru_img)

	AudioManager.play_se("se_riti_ai.ogg")

	var cutin := create_tween()
	cutin.set_parallel(true)
	cutin.tween_property(blackout, "color:a", 0.72, 0.25)
	cutin.tween_property(blackout, "color:a", 0.0, 0.70).set_delay(2.30)
	cutin.tween_property(taminaru_img, "modulate:a", 1.0, 0.35)
	cutin.tween_property(taminaru_img, "position", taminaru_img.position + Vector2(0, -220), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cutin.tween_property(taminaru_img, "modulate:a", 0.0, 1.15).set_delay(1.85)
	await cutin.finished

	_play_npc_voice(player_idx, "riti")
	_play_npc_riichi_bgm(player_idx)

	blackout.queue_free()
	taminaru_img.queue_free()
	_npc_riichi_cutin_running = false
	GameState.emit_signal("riichi_cutin_finished")

func _play_riichi_bgm() -> void:
	var bgms: Array = []
	match SaveData.selected_player_character:
		"hachimi":
			bgms = HACHIMI_RIICHI_BGMS
	if bgms.is_empty():
		return
	var track: Dictionary = bgms.pick_random()
	AudioManager.play_bgm_path(track.path)
	_bgm_title_label.text = "♪" + track.title

func _play_chara_voice(voice_name: String) -> void:
	match SaveData.selected_player_character:
		"hachimi":
			AudioManager.play_se("charavo/pl1_hatimi/" + voice_name)

func _get_npc_id_for_player(player_idx: int) -> String:
	if player_idx < 0 or player_idx >= GameState.players.size():
		return ""
	return str(GameState.players[player_idx].get("npc_id", ""))

func _play_npc_voice(player_idx: int, action: String) -> bool:
	var npc_id := _get_npc_id_for_player(player_idx)
	var def: Dictionary = NPC_VOICE_DEFS.get(npc_id, {})
	if def.is_empty():
		return false
	var actions: Dictionary = def.get("actions", {})
	var suffix := str(actions.get(action, ""))
	if suffix == "":
		return false
	var path := "charavo/%s/%s_%s.ogg" % [str(def.get("folder", "")), str(def.get("prefix", "")), suffix]
	AudioManager.play_se(path, float(NPC_VOICE_VOLUME_SCALE.get(npc_id, 1.0)))
	return true

func _play_npc_riichi_bgm(player_idx: int) -> void:
	var npc_id := _get_npc_id_for_player(player_idx)
	var track: Dictionary = NPC_RIICHI_BGMS.get(npc_id, {})
	if track.is_empty():
		return
	AudioManager.play_bgm_path(str(track.path))
	_bgm_title_label.text = "♪" + str(track.title)

func _on_kita_removed(player_idx: int) -> void:
	_refresh_info()
	_wanpai_consume()  # 北抜きで嶺上牌消費
	if player_idx == 0:
		_refresh_hand()
	else:
		_refresh_npc_areas()

func _on_ankan_done(player_idx: int) -> void:
	_refresh_info()
	_wanpai_consume()  # 槓で嶺上牌消費
	_refresh_wanpai_dora()
	if player_idx == 0:
		_refresh_hand()
		_check_tsumo_auto()
		if GameState.players[0].is_riichi and GameState.phase == GameState.Phase.PLAYER_TURN:
			_handle_riichi_draw()
	else:
		_play_npc_voice(player_idx, "kan")
		_refresh_npc_areas()

func _on_minkan_done(player_idx: int) -> void:
	# 大明槓後：嶺上ツモでプレイヤーターンに移行
	_refresh_info()
	_wanpai_consume()  # 槓で嶺上牌消費
	_refresh_wanpai_dora()
	if player_idx == 0:
		_player_drew = true
		_refresh_hand()
		_check_tsumo_auto()
	else:
		_play_npc_voice(player_idx, "kan")
		_refresh_npc_areas()

func _on_kakan_done(player_idx: int) -> void:
	# 加槓後：嶺上ツモでプレイヤーターンに移行（チャンカン経由でも呼ばれる）
	_refresh_info()
	_wanpai_consume()  # 槓で嶺上牌消費
	_refresh_wanpai_dora()
	if player_idx == 0:
		_player_drew = true
		_refresh_hand()
		_check_tsumo_auto()
		if GameState.players[0].is_riichi and GameState.phase == GameState.Phase.PLAYER_TURN:
			_handle_riichi_draw()
	else:
		_play_npc_voice(player_idx, "kan")
		_refresh_npc_areas()

func _on_naki_done(player_idx: int) -> void:
	if player_idx == 0:
		_refresh_hand()
	else:
		var naki: Array = GameState.players[player_idx].get("naki", [])
		if not naki.is_empty() and naki[-1].get("type", "") == "pon":
			_play_npc_voice(player_idx, "pon")
		_refresh_npc_areas()

func _on_game_ended(result: Dictionary) -> void:
	_hide_assist()
	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	_refresh_all()
	_double_ron_result_queue.clear()
	_double_ron_result_index = -1
	if not result.get("draw", false):
		_refresh_wanpai_dora(result.get("winner_idx", -1))
	_refresh_riichi_stick_display(result)
	_show_result_sequence(result)

func _on_match_ended(_session: Dictionary) -> void:
	get_tree().change_scene_to_file("res://Result.tscn")

func _on_wall_count_changed(count: int) -> void:
	_wall_label.text = str(GameState.honba) + "本場  残り" + str(count) + "枚"

func _on_npc_thinking(player_idx: int) -> void:
	var p_name: String = GameState.players[player_idx].name
	_status_label.text = p_name + "が考え中..."

# ============================================================
# プレイヤー入力ハンドラ
# ============================================================
func _on_tile_button_pressed(idx: int) -> void:
	if _riichi_cutin_running:
		return
	if _pon_select_mode:
		if idx in _pon_selectable:
			_pon_select_mode = false
			_pon_selectable.clear()
			_play_chara_voice("seplavo_pon")
			GameState.player_pon(idx)
			_set_action_buttons_state(false, false, false, false, false, false, false, false)
			_refresh_hand()
		return
	if _kan_select_mode:
		if idx in _kan_selectable:
			var kan_id: int = GameState.players[0].hand[idx].id
			_kan_select_mode = false
			_kan_selectable.clear()
			_play_chara_voice("seplavo_kan")
			if GameState.can_player_kakan() and _player_has_kakan_id(kan_id):
				GameState.player_kakan(kan_id)
			else:
				GameState.player_ankan(kan_id)
			_refresh_hand()
		return
	if _riichi_mode:
		if idx in _riichi_selectable:
			if _selected_idx == idx:
				await _run_player_riichi_cutin_sequence(idx, _riichi_is_open)
			else:
				_selected_idx = idx
				_refresh_hand()
		return
	if GameState.phase != GameState.Phase.PLAYER_TURN and \
			GameState.phase != GameState.Phase.AFTER_PON:
		return
	var tile: Dictionary = GameState.players[0].hand[idx]
	if tile.id == MahjongLogic.NORTH:
		GameState.player_kita()
		return
	# 食い変え禁止チェック（ポン直後に同種牌は選択不可）
	if GameState.phase == GameState.Phase.AFTER_PON:
		var forbidden_id: int = GameState.players[0].get("pon_forbidden_id", -1)
		if forbidden_id >= 0 and tile.id == forbidden_id:
			return
	# In riichi: cannot manually select/discard tiles
	if GameState.players[0].is_riichi:
		return
	if _selected_idx == idx:
		_selected_idx = -1
		_clear_tenpai_assist()
		GameState.player_discard(idx)
	else:
		_selected_idx = idx
		_refresh_hand()

func _on_discard_pressed() -> void:
	_hide_assist()
	if _riichi_cutin_running:
		return
	if _selected_idx < 0:
		return
	if _riichi_mode:
		return
	GameState.player_discard(_selected_idx)
	_selected_idx = -1
	_clear_tenpai_assist()
	_set_action_buttons_state(false, false, false, false, false, false, false, false)

func _on_tsumo_pressed() -> void:
	_hide_assist()
	if _riichi_cutin_running:
		return
	_show_player_hand_as_touhai = true
	_refresh_hand()
	_play_chara_voice("seplavo_tumo")
	GameState.player_tsumo()

func _on_ron_pressed() -> void:
	if _riichi_cutin_running:
		return
	_show_player_hand_as_touhai = true
	_refresh_hand()
	_play_chara_voice("seplavo_ron")
	GameState.player_ron()

func _on_open_riichi_pressed() -> void:
	if _riichi_cutin_running:
		return
	if not GameState.can_player_open_riichi():
		return
	_show_player_hand_as_touhai = true
	_start_riichi_selection(true)

func _on_riichi_pressed() -> void:
	_hide_assist()
	if _riichi_cutin_running:
		return
	_start_riichi_selection(false)

func _run_player_riichi_cutin_sequence(hand_idx: int, is_open: bool) -> void:
	if _riichi_cutin_running:
		return
	_riichi_cutin_running = true
	_riichi_mode = false
	_riichi_is_open = false
	_riichi_selectable.clear()
	_selected_idx = -1
	_clear_tenpai_assist()
	_btn_riichi_cancel.visible = false
	_show_player_hand_as_touhai = is_open
	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	if not GameState.prepare_player_riichi(hand_idx, is_open):
		_riichi_cutin_running = false
		_show_player_hand_as_touhai = false
		_refresh_all()
		_check_tsumo_auto()
		return
	_refresh_scores()
	_refresh_hand()

	# 宣言牌がロン可能な場合はカットインをスキップ
	if GameState.player_pending_riichi_discard_has_ron():
		GameState.finish_player_riichi()
		_riichi_cutin_running = false
		return

	# ロン不可の場合は通常通りカットインを再生
	_status_label.text = "リーチ！"
	_play_riichi_bgm()
	var npc_riichi: bool = GameState.players[1].is_riichi or GameState.players[2].is_riichi
	_play_chara_voice("seplavo_gote" if npc_riichi else "seplavo_sennsei")
	if SaveData.reach_cutin_enabled and _reach_cutin != null:
		await _reach_cutin.play_cutin(_get_player_riichi_cutin_path(npc_riichi), _get_riichi_stick_target_position(0))
	_refresh_riichi_stick_display()
	GameState.finish_player_riichi()
	_riichi_cutin_running = false

func _get_player_riichi_cutin_path(is_okkake: bool) -> String:
	return "res://chara/hatimiriti1.webp" if is_okkake else "res://chara/hatimiriti2.webp"

func _start_riichi_selection(is_open: bool) -> void:
	_riichi_mode = true
	_riichi_is_open = is_open
	_riichi_selectable = GameState.get_riichi_selectable_indices()
	_pon_select_mode = false
	_pon_selectable.clear()
	_kan_select_mode = false
	_kan_selectable.clear()
	_selected_idx = -1
	_refresh_hand()
	_status_label.text = "リーチ：捨てる牌を選んでください"
	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	_btn_riichi_cancel.visible = true
	_layout_action_buttons()

func _on_riichi_cancel_pressed() -> void:
	_riichi_mode = false
	_riichi_is_open = false
	_riichi_selectable.clear()
	_show_player_hand_as_touhai = false
	_selected_idx = -1
	_clear_tenpai_assist()
	_btn_riichi_cancel.visible = false
	_refresh_hand()
	_check_tsumo_auto()
	_status_label.text = "あなたのターン"

func _on_pon_pressed() -> void:
	if _should_select_pon_tile():
		_pon_select_mode = true
		_pon_selectable = _get_pon_selectable_indices()
		_selected_idx = -1
		_refresh_hand()
		_set_action_buttons_state(false, false, false, true, false, false, false, false)
		return
	_play_chara_voice("seplavo_pon")
	GameState.player_pon()
	_set_action_buttons_state(false, false, false, false, false, false, false, false)

func _on_kita_pressed() -> void:
	GameState.player_kita()

func _on_kan_pressed() -> void:
	_riichi_kan_ready = false
	var kan_indices: Array = GameState.get_player_kan_selectable_indices()
	var kan_ids: Array = []
	for idx: int in kan_indices:
		var tid: int = GameState.players[0].hand[idx].id
		if tid not in kan_ids:
			kan_ids.append(tid)
	if kan_ids.size() > 1:
		_kan_select_mode = true
		_kan_selectable = kan_indices
		_selected_idx = -1
		_refresh_hand()
		_set_action_buttons_state(false, false, false, true, false, false, false, false)
		return
	_play_chara_voice("seplavo_kan")
	_btn_skip.tooltip_text = "キャンセル"
	# ACTION_WAIT中に大明槓可なら大明槓、次に加槓、それ以外は暗槓
	if GameState.phase == GameState.Phase.ACTION_WAIT and GameState.action_minkan_possible:
		GameState.player_minkan()
	elif GameState.can_player_kakan():
		GameState.player_kakan()
	else:
		GameState.player_ankan()

func _on_skip_pressed() -> void:
	if GameState.phase == GameState.Phase.PLAYER_TURN:
		var hand_ids: Array = MahjongLogic.get_ids(GameState.players[0].hand)
		if MahjongLogic.is_complete_hand(hand_ids):
			_show_player_hand_as_touhai = false
			_set_action_buttons_state(false, false, false, false, false, false, false, false)
			GameState.player_decline_tsumo()
			return
	_pon_select_mode = false
	_pon_selectable.clear()
	_kan_select_mode = false
	_kan_selectable.clear()
	if _riichi_kan_ready:
		_riichi_kan_ready = false
		_btn_skip.tooltip_text = "キャンセル"
		_set_action_buttons_state(false, false, false, false, false, false, false, false)
		_status_label.text = "立直中：ツモ切り"
		get_tree().create_timer(0.2).timeout.connect(func():
			if GameState.phase == GameState.Phase.PLAYER_TURN and GameState.players[0].is_riichi:
				GameState.player_discard(GameState.players[0].hand.size() - 1)
		, CONNECT_ONE_SHOT)
		return
	GameState.player_skip()
	_set_action_buttons_state(false, false, false, false, false, false, false, false)

func _on_msg_ok_pressed() -> void:
	if _double_ron_result_index >= 0 and _double_ron_result_index + 1 < _double_ron_result_queue.size():
		_double_ron_result_index += 1
		var next_result: Dictionary = _double_ron_result_queue[_double_ron_result_index]
		_clear_result_dynamic_nodes()
		_win_overlay.visible = false
		_msg_panel.visible = false
		_btn_result_back.visible = false
		_btn_table_view.visible = false
		_show_result_sequence(next_result, false)
		return
	_double_ron_result_queue.clear()
	_double_ron_result_index = -1
	_clear_result_dynamic_nodes()
	_win_overlay.visible = false
	_msg_panel.visible = false
	_btn_result_back.visible = false
	_btn_table_view.visible = false
	GameState.advance_game()

func _on_table_view_pressed() -> void:
	_set_result_display_visible(false)
	_btn_result_back.visible = true

func _on_result_back_pressed() -> void:
	_btn_result_back.visible = false
	_set_result_display_visible(true)

func _set_result_display_visible(visible: bool) -> void:
	_win_overlay.visible = visible
	_msg_panel.visible = visible
	for node in _result_dynamic_nodes:
		if is_instance_valid(node) and node is CanvasItem:
			(node as CanvasItem).visible = visible

# ============================================================
# ツモ和了・アクション自動チェック（プレイヤーのターン開始時）
# ============================================================
func _tile_variant_key(tile: Dictionary) -> String:
	return str(tile.get("is_red", false)) + ":" + str(tile.get("is_gold", false)) + ":" + str(tile.get("is_haku_pochi", false))

func _get_pon_selectable_indices() -> Array:
	var result: Array = []
	if GameState.action_pon_from < 0 or GameState.last_discarded_tile.is_empty():
		return result
	var tile_id: int = GameState.last_discarded_tile.id
	var hand: Array = GameState.players[0].hand
	for i in range(hand.size()):
		if hand[i].id == tile_id:
			result.append(i)
	return result

func _should_select_pon_tile() -> bool:
	var indices: Array = _get_pon_selectable_indices()
	if indices.size() != 3:
		return false
	var variants := {}
	var hand: Array = GameState.players[0].hand
	for idx: int in indices:
		variants[_tile_variant_key(hand[idx])] = true
	return variants.size() > 1

func _player_has_kakan_id(tile_id: int) -> bool:
	var p: Dictionary = GameState.players[0]
	for m: Dictionary in p.naki:
		if m.get("type") == "pon" and m.tile_ids[0] == tile_id:
			return true
	return false

func _check_tsumo_auto() -> void:
	var player: Dictionary = GameState.players[0]
	var hand_ids: Array = MahjongLogic.get_ids(player.hand)
	var can_tsumo: bool = _can_player_tsumo_with_yaku(hand_ids)
	var can_riichi: bool = GameState.can_player_riichi()
	var can_kita: bool = GameState.can_player_kita()
	var can_kan: bool = GameState.can_player_ankan() or GameState.can_player_kakan()
	if GameState.phase == GameState.Phase.AFTER_PON:
		_set_action_buttons_state(true, false, false, false, false, false, false, false)
		if _assist_btn != null:
			_set_assist_toggle_visible(false)
		_hide_assist()
	else:
		_set_action_buttons_state(false, can_tsumo, false, can_tsumo, can_riichi, false, can_kita, can_kan)
		if _assist_btn != null:
			_set_assist_toggle_visible(_can_show_assist_toggle())
		_refresh_auto_assist()

func _can_player_tsumo_with_yaku(hand_ids: Array) -> bool:
	if not MahjongLogic.is_complete_hand(hand_ids):
		return false
	if GameState.players[0].hand.is_empty():
		return false
	var winning_id: int = GameState.players[0].hand[GameState.players[0].hand.size() - 1].id
	var context: Dictionary = GameState._build_context(0, true, winning_id)
	return not MahjongLogic.check_yaku(hand_ids, context).is_empty()

func _handle_riichi_draw() -> void:
	var player: Dictionary = GameState.players[0]
	var hand: Array = player.hand
	if hand.is_empty(): return
	var drawn_tile: Dictionary = hand[hand.size() - 1]
	var hand_ids: Array = MahjongLogic.get_ids(hand)

	# 北 → kita button only
	if drawn_tile.id == MahjongLogic.NORTH:
		if MahjongLogic.is_complete_hand(hand_ids):
			_set_action_buttons_state(false, true, false, true, false, false, false, false)
			_status_label.text = "立直！ツモ和了！"
		else:
			_set_action_buttons_state(false, false, false, false, false, false, true, false)
			_status_label.text = "立直中：北をツモりました"
		return

	# Winning tile → tsumo button only
	if MahjongLogic.is_complete_hand(hand_ids):
		_set_action_buttons_state(false, true, false, true, false, false, false, false)
		_status_label.text = "立直！ツモ和了！"
		return

	# Ankan possible → kan + skip buttons
	if GameState.can_player_ankan():
		_riichi_kan_ready = true
		_btn_skip.tooltip_text = "キャンセル"
		_set_action_buttons_state(false, false, false, true, false, false, false, true)
		_status_label.text = "立直中：カン可（スキップでツモ切り）"
		return

	# Auto tsumo-giri after short delay
	if _riichi_tsumogiri_timer_pending:
		return
	_riichi_tsumogiri_timer_pending = true
	_set_action_buttons_state(false, false, false, false, false, false, false, false)
	_status_label.text = "立直中：ツモ切り..."
	get_tree().create_timer(0.5).timeout.connect(func():
		_riichi_tsumogiri_timer_pending = false
		if GameState.players[0].is_riichi and GameState.phase == GameState.Phase.PLAYER_TURN:
			GameState.player_riichi_tsumogiri()
	, CONNECT_ONE_SHOT)

# ============================================================
# 表示更新
# ============================================================
func _refresh_all() -> void:
	_refresh_info()
	_refresh_hand()
	_refresh_npc_areas()
	_refresh_discard_area()
	_refresh_riichi_stick_display()

func _refresh_info() -> void:
	var round_name := MahjongLogic.get_wind_name(GameState.round_wind)
	_info_label.text = round_name + str(GameState.kyoku) + "局"
	_wall_label.text = str(GameState.honba) + "本場  残り" + str(GameState.get_wall_count()) + "枚"
	_refresh_scores()

func _refresh_scores() -> void:
	# players[0]=東(player), [1]=南(right), [2]=西(upper)
	var p0: Dictionary = GameState.players[0]
	var p1: Dictionary = GameState.players[RIGHT_IDX]
	var p2: Dictionary = GameState.players[UPPER_IDX]
	var r0 := "★" if p0.is_riichi else ""
	var r1 := "★" if p1.is_riichi else ""
	var r2 := "★" if p2.is_riichi else ""
	_upper_score_label.text = "【" + MahjongLogic.get_wind_name(p2.wind) + "】" + r2 + str(p2.score)
	_right_score_label.text  = "【" + MahjongLogic.get_wind_name(p1.wind) + "】" + r1 + str(p1.score)
	_player_score_label.text = "【" + MahjongLogic.get_wind_name(p0.wind) + "】" + r0 + str(p0.score)

func _refresh_riichi_stick_display(result: Dictionary = {}) -> void:
	if _riichi_stick_layer == null:
		return
	for child in _riichi_stick_layer.get_children():
		_riichi_stick_layer.remove_child(child)
		child.queue_free()
	_empty_riichi_stick_count = 0
	var is_draw_result: bool = bool(result.get("draw", false))
	var total_kyotaku: int = int(result.get("kyotaku_before_collection", GameState.kyotaku))
	var active_count: int = 0
	if not is_draw_result:
		for player_idx in range(GameState.players.size()):
			var player: Dictionary = GameState.players[player_idx]
			if not bool(player.get("is_riichi", false)):
				continue
			var sticks: int = int(player.get("riichi_sticks", 0))
			if sticks <= 0:
				sticks = 1
			active_count += sticks
			_add_riichi_sticks_for_player(player_idx, sticks)
	var deposit_count: int = total_kyotaku if is_draw_result else max(0, total_kyotaku - active_count)
	_add_deposit_riichi_sticks(deposit_count)

func _add_riichi_sticks_for_player(player_idx: int, count: int) -> void:
	var base: Vector2 = _get_riichi_stick_target_position(player_idx)
	_add_riichi_stick(base, _get_riichi_stick_rotation(player_idx), 0.161)
	for i in range(1, count):
		_add_empty_riichi_stick(0.161)

func _add_deposit_riichi_sticks(count: int) -> void:
	for i in range(count):
		_add_empty_riichi_stick(0.126)

func _add_empty_riichi_stick(scale_value: float) -> void:
	var base: Vector2 = _get_empty_riichi_stick_target_position()
	var offset: Vector2 = _get_empty_riichi_stick_offset()
	var rotation_deg: float = _get_empty_riichi_stick_rotation()
	_add_riichi_stick(base + offset * _empty_riichi_stick_count, rotation_deg, scale_value)
	_empty_riichi_stick_count += 1

func _add_riichi_stick(pos: Vector2, rotation_deg: float, scale_value: float) -> void:
	if _riichi_stick_layer == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _get_reach_stick_texture()
	sprite.position = pos
	sprite.rotation_degrees = rotation_deg
	sprite.scale = Vector2.ONE * scale_value
	sprite.z_index = 0
	_riichi_stick_layer.add_child(sprite)

func _get_reach_stick_texture() -> Texture2D:
	if _reach_stick_texture == null:
		_reach_stick_texture = _load_texture_resource_or_file("res://ui/ritibo.webp")
	return _reach_stick_texture

func _load_texture_resource_or_file(path: String) -> Texture2D:
	if path.get_extension().to_lower() == "png":
		return _load_texture_file(path)
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	return _load_texture_file(path)

func _load_texture_file(path: String) -> Texture2D:
	var image: Image = Image.new()
	var err: Error = image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _get_riichi_stick_target_position(player_idx: int) -> Vector2:
	match player_idx:
		0:
			return Vector2(964, 637)
		RIGHT_IDX:
			return Vector2(1101, 514)
		UPPER_IDX:
			return Vector2(964, 356)
		LEFT_IDX:
			return Vector2(822, 514)
	return Vector2(960, 540)

func _get_riichi_stick_rotation(player_idx: int) -> float:
	match player_idx:
		0:
			return 0.0
		RIGHT_IDX:
			return 90.0
		UPPER_IDX:
			return 180.0
		LEFT_IDX:
			return -90.0
	return 0.0

func _get_riichi_stick_offset(player_idx: int) -> Vector2:
	match player_idx:
		0:
			return Vector2(42, 0)
		RIGHT_IDX:
			return Vector2(0, 42)
		UPPER_IDX:
			return Vector2(-42, 0)
		LEFT_IDX:
			return Vector2(0, -42)
	return Vector2(42, 0)

func _get_empty_riichi_stick_target_position() -> Vector2:
	return _get_riichi_stick_target_position(_get_empty_riichi_stick_slot_idx())

func _get_empty_riichi_stick_rotation() -> float:
	return _get_riichi_stick_rotation(_get_empty_riichi_stick_slot_idx())

func _get_empty_riichi_stick_offset() -> Vector2:
	return _get_riichi_stick_offset(_get_empty_riichi_stick_slot_idx())

func _get_empty_riichi_stick_slot_idx() -> int:
	match SaveData.selected_empty_seat:
		"bottom":
			return RIGHT_IDX
		"right":
			return LEFT_IDX
		"top":
			return LEFT_IDX
	return LEFT_IDX

func _tile_sort_key(tile: Dictionary) -> int:
	var variant := 0
	if tile.get("is_red", false): variant = 1
	elif tile.get("is_gold", false): variant = 2
	return tile.id * 10 + variant

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
		_tile_texture_cache[path] = load(path)
	return _tile_texture_cache[path]

func _get_touhai_texture_path(tile: Dictionary) -> String:
	var id: int = tile.id
	var is_red: bool = tile.get("is_red", false)
	var is_gold: bool = tile.get("is_gold", false)
	var is_haku_pochi: bool = tile.get("is_haku_pochi", false)
	match id:
		11: return "res://assets/tiles/touhai_m_1_auto.webp"
		19: return "res://assets/tiles/touhai_m_9_auto.webp"
		21: return "res://assets/tiles/touhai_pi_1_auto.webp"
		22: return "res://assets/tiles/touhai_pi_2_auto.webp"
		23: return "res://assets/tiles/touhai_pi_3_auto.webp"
		24: return "res://assets/tiles/touhai_pi_4_auto.webp"
		25: return "res://assets/tiles/touhai_pi_5a_auto.webp" if is_red else "res://assets/tiles/touhai_pi_5_auto.webp"
		26: return "res://assets/tiles/touhai_pi_6_auto.webp"
		27: return "res://assets/tiles/touhai_pi_7_auto.webp"
		28: return "res://assets/tiles/touhai_pi_8k_auto.webp" if is_gold else "res://assets/tiles/touhai_pi_8_auto.webp"
		29: return "res://assets/tiles/touhai_pi_9_auto.webp"
		31: return "res://assets/tiles/touhai_so_1_auto.webp"
		32: return "res://assets/tiles/touhai_so_2_auto.webp"
		33: return "res://assets/tiles/touhai_so_3_auto.webp"
		34: return "res://assets/tiles/touhai_so_4_auto.webp"
		35: return "res://assets/tiles/touhai_so_5a_auto.webp" if is_red else "res://assets/tiles/touhai_so_5_auto.webp"
		36: return "res://assets/tiles/touhai_so_6_auto.webp"
		37: return "res://assets/tiles/touhai_so_7_auto.webp"
		38: return "res://assets/tiles/touhai_so_8k_auto.webp" if is_gold else "res://assets/tiles/touhai_so_8_auto.webp"
		39: return "res://assets/tiles/touhai_so_9_auto.webp"
		41: return "res://assets/tiles/touhai_ji_ton_auto.webp"
		42: return "res://assets/tiles/touhai_ji_nan_auto.webp"
		43: return "res://assets/tiles/touhai_ji_sya_auto.webp"
		44: return "res://assets/tiles/touhai_ji_pea_auto.webp" if is_red else "res://assets/tiles/touhai_ji_pe_auto.webp"
		45: return "res://assets/tiles/touhai_ji_hakup_auto.webp" if is_haku_pochi else "res://assets/tiles/hai_hai2.webp"
		46: return "res://assets/tiles/touhai_ji_hatu_auto.webp"
		47: return "res://assets/tiles/touhai_ji_tyun_auto.webp"
	return ""

func _get_player_hand_texture(tile: Dictionary) -> Texture2D:
	if not _show_player_hand_as_touhai:
		return _get_tile_texture(tile)
	var path := _get_touhai_texture_path(tile)
	if path == "":
		return _get_tile_texture(tile)
	return _make_used_rect_texture(path)

func _refresh_hand() -> void:
	for btn in _tile_buttons:
		if is_instance_valid(btn):
			_hand_box.remove_child(btn)
			btn.queue_free()
	_tile_buttons.clear()

	var player: Dictionary = GameState.players[0]
	var hand: Array = player.hand

	var sort_count := hand.size() - 1 if (_player_drew and hand.size() >= 2) else hand.size()
	var display_indices := range(sort_count)
	display_indices.sort_custom(func(a: int, b: int) -> bool:
		return _tile_sort_key(hand[a]) < _tile_sort_key(hand[b])
	)
	if _player_drew and hand.size() >= 2:
		display_indices.append(hand.size() - 1)

	const TILE_W := 128
	const TILE_H := 176
	const TILE_GAP := 4
	const TSUMO_GAP := 15
	const RAISE_H := 18

	var x_pos := 0
	for i in range(display_indices.size()):
		var orig_idx: int = display_indices[i]
		var tile: Dictionary = hand[orig_idx]
		var is_selected: bool = (orig_idx == _selected_idx)

		if _player_drew and i == display_indices.size() - 1:
			x_pos += TSUMO_GAP
		var container := Panel.new()
		container.position = Vector2(x_pos, 0 if is_selected else RAISE_H)
		container.size = Vector2(TILE_W, TILE_H)
		container.mouse_filter = Control.MOUSE_FILTER_STOP

		var style: StyleBox = StyleBoxEmpty.new()
		if is_selected:
			var selected_style := StyleBoxFlat.new()
			selected_style.bg_color = Color(0.3, 0.6, 1.0, 0.35)
			selected_style.border_color = Color(0.1, 0.3, 0.9, 0.85)
			selected_style.set_border_width_all(3)
			selected_style.set_corner_radius_all(4)
			style = selected_style
		container.add_theme_stylebox_override("panel", style)

		var tex_rect := TextureRect.new()
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = _get_player_hand_texture(tile)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(tex_rect)

		if _riichi_mode and orig_idx not in _riichi_selectable:
			var overlay := ColorRect.new()
			overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			overlay.color = Color(0.1, 0.1, 0.1, 0.6)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(overlay)
		if (_pon_select_mode and orig_idx not in _pon_selectable) or (_kan_select_mode and orig_idx not in _kan_selectable):
			var select_overlay := ColorRect.new()
			select_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			select_overlay.color = Color(0.1, 0.1, 0.1, 0.6)
			select_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(select_overlay)
		# 食い変え禁止牌（ポン直後に同種牌は切れない）を赤いオーバーレイで示す
		if GameState.phase == GameState.Phase.AFTER_PON:
			var forbidden_id: int = GameState.players[0].get("pon_forbidden_id", -1)
			if forbidden_id >= 0 and tile.id == forbidden_id:
				var forbidden_overlay := ColorRect.new()
				forbidden_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				forbidden_overlay.color = Color(0.9, 0.1, 0.1, 0.5)
				forbidden_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				container.add_child(forbidden_overlay)

		var captured_orig := orig_idx
		container.gui_input.connect(func(event: InputEvent) -> void:
			if _is_primary_press(event):
				_on_tile_button_pressed(captured_orig)
		)
		_hand_box.add_child(container)
		_tile_buttons.append(container)
		x_pos += TILE_W + TILE_GAP

	_refresh_scores()
	_refresh_discard_area()
	_refresh_tenpai_assist()

func _clear_tenpai_assist() -> void:
	if _tenpai_assist_box == null:
		return
	for child in _tenpai_assist_box.get_children():
		_tenpai_assist_box.remove_child(child)
		child.queue_free()

func _refresh_tenpai_assist() -> void:
	_clear_tenpai_assist()
	if _selected_idx < 0:
		return
	if GameState.players.is_empty():
		return
	var hand: Array = GameState.players[0].hand
	if _selected_idx >= hand.size():
		return
	if GameState.players[0].is_riichi:
		return
	if GameState.phase != GameState.Phase.PLAYER_TURN and GameState.phase != GameState.Phase.AFTER_PON:
		return

	var test_ids: Array = MahjongLogic.get_ids(hand)
	test_ids.remove_at(_selected_idx)
	var waiting_ids: Array = MahjongLogic.find_waiting_tiles(test_ids)
	if waiting_ids.is_empty():
		return
	waiting_ids.sort()

	const ASSIST_TILE_W := 75
	const ASSIST_TILE_H := 104
	const ASSIST_GAP := 12

	var content_w: float = ASSIST_TILE_W * waiting_ids.size() + ASSIST_GAP * max(waiting_ids.size() - 1, 0) + 100
	var content_x: float = maxf(0.0, _tenpai_assist_box.size.x - content_w)

	var bg := ColorRect.new()
	bg.position = Vector2(content_x, 0)
	bg.size = Vector2(content_w, 112)
	bg.color = Color(0.0, 0.0, 0.0, 0.45)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tenpai_assist_box.add_child(bg)

	var x := content_x + 8
	for tid: int in waiting_ids:
		var rect := TextureRect.new()
		rect.position = Vector2(x, 4)
		rect.size = Vector2(ASSIST_TILE_W, ASSIST_TILE_H)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = _get_tile_texture(MahjongLogic.make_tile(tid))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tenpai_assist_box.add_child(rect)
		x += ASSIST_TILE_W + ASSIST_GAP

	var wait_count := 0
	for tid: int in waiting_ids:
		wait_count += _remaining_wait_tile_count(tid)

	var wait_label := Label.new()
	wait_label.text = "待ち"
	wait_label.position = Vector2(x + 2, 12)
	wait_label.size = Vector2(90, 44)
	wait_label.add_theme_font_size_override("font_size", 36)
	wait_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72))
	wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tenpai_assist_box.add_child(wait_label)

	var wall_cnt_lbl := Label.new()
	wall_cnt_lbl.text = "残%d枚" % wait_count
	wall_cnt_lbl.position = Vector2(x + 2, 62)
	wall_cnt_lbl.size = Vector2(90, 28)
	wall_cnt_lbl.add_theme_font_size_override("font_size", 20)
	wall_cnt_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	wall_cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wall_cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tenpai_assist_box.add_child(wall_cnt_lbl)

func _remaining_wait_tile_count(tile_id: int) -> int:
	var visible := 0
	for p in GameState.players:
		for t: Dictionary in p.discards:
			if int(t.get("id", -1)) == tile_id:
				visible += 1
		for t: Dictionary in p.nukita:
			if int(t.get("id", -1)) == tile_id:
				visible += 1
		for m: Dictionary in p.naki:
			for mid in m.get("tile_ids", []):
				if int(mid) == tile_id:
					visible += 1
	for t: Dictionary in GameState.players[0].hand:
		if int(t.get("id", -1)) == tile_id:
			visible += 1
	for t: Dictionary in GameState.dora_indicators:
		if int(t.get("id", -1)) == tile_id:
			visible += 1
	return max(0, 4 - visible)

func _refresh_npc_areas() -> void:
	var upper: Dictionary = GameState.players[UPPER_IDX]
	_fill_npc_hand_box(_upper_hand_box, upper, "toi", 617, 76)
	# 上家捨て牌: プレイヤー視点では下段開始、上家視点では上段開始
	_fill_discard_box(_upper_discard_box, upper.discards, 44, 61, 6, 180.0, false, true, true, 2)
	_fill_meld_box(_upper_meld_box, upper.naki, UPPER_IDX, 180.0, 48, 66)
	_fill_nukita_box(_upper_nukita_box, upper.nukita, 180.0, 44, 60)

	var right: Dictionary = GameState.players[RIGHT_IDX]
	_fill_npc_hand_box(_right_hand_box, right, "toi", 180, 540, 90.0)
	# 右家: 右家視点で左から右（プレイヤー視点では下から上）へ並べる
	_fill_discard_box(_right_discard_box, right.discards, 44, 61, 6, -90.0, true, false, false, 0, true)
	_fill_meld_box(_right_meld_box, right.naki, RIGHT_IDX, 90.0, 48, 66)
	_fill_nukita_box(_right_nukita_box, right.nukita, 90.0, 44, 60)

func _refresh_discard_area() -> void:
	_fill_discard_box(_player_discard_box, GameState.players[0].discards, 44, 61, 6)
	var p0: Dictionary = GameState.players[0]
	# 鳴き + 抜き北 を右アンカーで表示（新しいものが左）
	_fill_meld_box(_player_meld_box, p0.naki, 0, 0.0, 102, 141)
	# 北抜き画像を手牌の1行上へ右詰め表示（新しいものが左へ伸びる）
	_fill_nukita_box(_player_nukita_box, p0.nukita, 0.0, 90, 123, true)

func _get_haimen_texture() -> Texture2D:
	if _haimen_texture == null:
		var base: Texture2D = load("res://assets/tiles/hai_haimen2.webp")
		var atlas := AtlasTexture.new()
		atlas.atlas = base
		var img: Image = base.get_image()
		var used_rect: Rect2i = img.get_used_rect() if img != null else Rect2i()
		atlas.region = Rect2(used_rect.position.x, used_rect.position.y, used_rect.size.x, used_rect.size.y) if used_rect.size != Vector2i.ZERO else Rect2(Vector2.ZERO, base.get_size())
		_haimen_texture = atlas
	return _haimen_texture

# NPCの伏せ手牌を、鳴き回数に応じた1枚絵で表示
func _fill_npc_hand_box(box: Control, player: Dictionary, seat_key: String, max_w: int, max_h: int, rotation_degrees: float = 0.0) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if _debug_show_npc_hands:
		_fill_npc_debug_hand_box(box, player.hand, max_w, max_h, rotation_degrees)
		return
	var paths: Array = NPC_HAND_TEXTURE_PATHS.get(seat_key, [])
	if paths.is_empty():
		return
	var naki_count: int = clamp(player.naki.size(), 0, paths.size() - 1)
	var path: String = paths[naki_count]
	var cache_key := path + "#used"
	if not _tile_texture_cache.has(cache_key):
		_tile_texture_cache[cache_key] = _make_used_rect_texture(path)
	var tex: Texture2D = _tile_texture_cache[cache_key]
	if tex == null:
		return
	var base_cache_key := str(paths[0]) + "#used"
	if not _tile_texture_cache.has(base_cache_key):
		_tile_texture_cache[base_cache_key] = _make_used_rect_texture(str(paths[0]))
	var base_tex: Texture2D = _tile_texture_cache[base_cache_key]
	var tex_size: Vector2 = tex.get_size()
	var base_size: Vector2 = base_tex.get_size() if base_tex != null else tex_size
	var rotated: bool = not is_zero_approx(fmod(absf(rotation_degrees), 180.0))
	var visual_base := Vector2(base_size.y, base_size.x) if rotated else base_size
	var scale_ratio: float = min(float(max_w) / visual_base.x, float(max_h) / visual_base.y)
	var current_visual_base := Vector2(tex_size.y, tex_size.x) if rotated else tex_size
	var visual_size := current_visual_base * scale_ratio
	var tex_rect := TextureRect.new()
	tex_rect.size = tex_size * scale_ratio
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = tex
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.rotation_degrees = rotation_degrees
	var offset := Vector2(
		maxf(0.0, (float(max_w) - visual_size.x) * 0.5),
		maxf(0.0, (float(max_h) - visual_size.y) * 0.5)
	)
	if rotated and rotation_degrees < 0.0:
		tex_rect.position = Vector2(offset.x, tex_rect.size.x + offset.y)
	elif is_equal_approx(absf(rotation_degrees), 180.0):
		tex_rect.position.x = offset.x + visual_size.x
		tex_rect.position.y = offset.y + visual_size.y
	elif rotated:
		tex_rect.position.x = tex_rect.size.y
		if rotation_degrees > 0.0:
			tex_rect.position.y = offset.y
	else:
		tex_rect.position = offset
	box.add_child(tex_rect)

func _fill_npc_debug_hand_box(box: Control, hand: Array, max_w: int, max_h: int, rotation_degrees: float = 0.0) -> void:
	if hand.is_empty():
		return
	var tile_w := 44
	var tile_h := 61
	var gap := 2
	var vertical: bool = not is_zero_approx(fmod(absf(rotation_degrees), 180.0))
	var sorted_hand: Array = hand.duplicate(true)
	sorted_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _tile_sort_key(a) < _tile_sort_key(b)
	)
	var start_y := 0.0
	if vertical and rotation_degrees > 0.0:
		var hand_visual_h: float = sorted_hand.size() * tile_w + max(0, sorted_hand.size() - 1) * gap
		start_y = max(0.0, float(max_h) - hand_visual_h)
	for i in range(sorted_hand.size()):
		var tile: Dictionary = sorted_hand[i]
		var rect := TextureRect.new()
		rect.size = Vector2(tile_w, tile_h)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = _get_tile_texture(tile)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.rotation_degrees = rotation_degrees
		if vertical:
			rect.position = Vector2(0, start_y + i * (tile_w + gap))
			if rotation_degrees > 0.0:
				rect.position.x += tile_h
		else:
			rect.position = Vector2(i * (tile_w + gap), 0)
			if is_equal_approx(absf(rotation_degrees), 180.0):
				rect.position.x = max_w - i * (tile_w + gap)
				rect.position.y = tile_h
		box.add_child(rect)

func _make_used_rect_texture(path: String) -> Texture2D:
	var tex: Texture2D = _tile_texture_cache[path] if _tile_texture_cache.has(path) else null
	if tex == null:
		tex = load(path)
		_tile_texture_cache[path] = tex
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var used_rect: Rect2i = img.get_used_rect()
	if used_rect.size == Vector2i.ZERO or used_rect.size == img.get_size():
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(Vector2(used_rect.position), Vector2(used_rect.size))
	return atlas

# naki を画像で表示。プレイヤー（base_angle=0）は右アンカーで右から左へ配置
func _fill_meld_box(box: Control, naki: Array, holder_idx: int, base_angle: float, tile_w: int, tile_h: int) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var gap := 2
	var meld_gap := 6
	var is_vertical: bool = absf(fmod(absf(base_angle), 180.0) - 90.0) < 1.0
	var is_player: bool = absf(base_angle) < 1.0  # プレイヤー（0°）は右アンカー

	# 総幅を先に計算してプレイヤー用オフセットを決定
	var total_w := 0.0
	if is_player:
		for meld: Dictionary in naki:
			var mtype_w: String = meld.get("type", "")
			var order_w: Array = _build_meld_display_order(meld, holder_idx)
			for data_idx: int in order_w:
				var is_src: bool = (data_idx == 0 and mtype_w != "ankan")
				total_w += (tile_h if is_src else tile_w) + gap
			total_w += meld_gap

	# プレイヤーは右端 (1880px) から逆算した起点、それ以外は 0 から
	var cursor := (1880.0 - total_w) if is_player else 0.0

	# プレイヤーは新しい鳴きが左（naki 逆順表示）、それ以外は正順
	var display_naki: Array = naki.duplicate()
	if is_player:
		display_naki.reverse()

	for meld: Dictionary in display_naki:
		var mtype: String = meld.get("type", "")
		var tile_ids: Array = meld.get("tile_ids", [])
		var tiles_list: Array = meld.get("tiles", [])
		var order: Array = _build_meld_display_order(meld, holder_idx)
		var n: int = order.size()
		var kakan_rotated_cursor := 0.0
		for vi in range(n):
			var data_idx: int = order[vi]
			var tid: int = tile_ids[data_idx] if data_idx < tile_ids.size() else -1
			# 鳴いた牌（data[0]）を回転。ankan は回転なし
			var is_src: bool = (data_idx == 0 and mtype != "ankan")
			if is_src and mtype == "kakan":
				kakan_rotated_cursor = cursor
			# ankan は視覚上の両端（vi==0 と vi==n-1）を裏向きにする
			var is_haimen: bool = (mtype == "ankan" and (vi == 0 or vi == n - 1))
			# 実際の牌辞書を使う（金牌などの属性を保持）
			var actual_tile: Dictionary
			if data_idx < tiles_list.size() and tiles_list[data_idx] is Dictionary:
				actual_tile = tiles_list[data_idx]
			else:
				actual_tile = MahjongLogic.make_tile(tid)
			var tex: Texture2D = _get_haimen_texture() if is_haimen else _get_tile_texture(actual_tile)
			var tex_rect := TextureRect.new()
			tex_rect.size = Vector2(tile_w, tile_h)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			# haimen も通常牌と同じく縦横比を保持（透過部分を含めず実寸で表示）
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.texture = tex
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.pivot_offset = Vector2(tile_w / 2.0, tile_h / 2.0)
			tex_rect.rotation_degrees = base_angle + (90.0 if is_src else 0.0)
			var span: float = tile_h if is_src else tile_w
			if is_vertical:
				tex_rect.position = Vector2(0.0, cursor)
			else:
				if is_src:
					# 回転牌: 視覚的左端をcursorに揃え、底辺を通常牌に合わせる
					tex_rect.position = Vector2(cursor + (tile_h - tile_w) / 2.0, float(tile_h - tile_w))
				else:
					tex_rect.position = Vector2(cursor, float(tile_h - tile_w))
			cursor += span + gap
			box.add_child(tex_rect)

		# 加槓: 横向き牌の中央X上に4枚目(data[3])を上端揃えで重ねる
		if mtype == "kakan" and tile_ids.size() >= 4:
			var k_data_idx := 3
			var k_tid: int = tile_ids[k_data_idx]
			var k_tile: Dictionary
			if k_data_idx < tiles_list.size() and tiles_list[k_data_idx] is Dictionary:
				k_tile = tiles_list[k_data_idx]
			else:
				k_tile = MahjongLogic.make_tile(k_tid)
			var k_tex: Texture2D = _get_tile_texture(k_tile)
			var k_rect := TextureRect.new()
			k_rect.size = Vector2(tile_w, tile_h)
			k_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			k_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			k_rect.texture = k_tex
			k_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			k_rect.pivot_offset = Vector2(tile_w / 2.0, tile_h / 2.0)
			k_rect.rotation_degrees = base_angle + 90.0
			if is_vertical:
				k_rect.position = Vector2(0.0, kakan_rotated_cursor)
			else:
				k_rect.position = Vector2(kakan_rotated_cursor + (tile_h - tile_w) / 2.0, float(tile_h - 2*tile_w))
			box.add_child(k_rect)

		cursor += meld_gap


# 鳴き牌の視覚表示順（data インデックスの配列）を返す
# 鳴いた牌（data[0]）をカーソル上の START / MIDDLE / END に配置して
# 鳴き元の方向を示す。ankan はそのまま [0,1,2,3]。
# holder ごとのカーソル方向:
#   holder=0 (bottom, 0°, L→R):  from RIGHT_IDX→END, from UPPER_IDX→MIDDLE
#   holder=1 (right,  90°, T→B): from UPPER_IDX→START, from 0→END
#   holder=2 (top,  180°, L→R):  from player(0)→START, from RIGHT_IDX→END
func _build_meld_display_order(meld: Dictionary, holder_idx: int) -> Array:
	var mtype: String = meld.get("type", "")
	var n: int = meld.get("tile_ids", []).size()
	var identity: Array = []
	for i in range(n):
		identity.append(i)
	if mtype == "ankan":
		return identity
	var from_player: int = meld.get("from_player", -1)
	if from_player < 0:
		return identity
	var base_n: int = 3 if mtype == "kakan" else n

	var placement := "end"
	if holder_idx == 0:
		placement = "end" if from_player == RIGHT_IDX else "middle"
	elif holder_idx == RIGHT_IDX:
		placement = "start" if from_player == UPPER_IDX else "end"
	elif holder_idx == UPPER_IDX:
		placement = "start" if from_player == 0 else "end"

	match placement:
		"start":  # 鳴いた牌をカーソル先頭（data[0], 1, 2...）
			var r: Array = []
			for i in range(base_n):
				r.append(i)
			return r
		"middle":  # 鳴いた牌を中央（3枚: [1,0,2]、4枚: [1,2,0,3]）
			if base_n == 3:
				return [1, 0, 2]
			return [1, 2, 0, 3]
		_:  # "end": 鳴いた牌をカーソル末尾（1, 2..., 0）
			var r: Array = []
			for i in range(1, base_n):
				r.append(i)
			r.append(0)
			return r

# 抜き北を画像で表示する
func _fill_nukita_box(box: Control, nukita: Array, base_angle: float, tile_w: int, tile_h: int, right_to_left: bool = false) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if nukita.is_empty():
		return
	var gap := 4
	var is_vertical: bool = absf(fmod(absf(base_angle), 180.0) - 90.0) < 1.0
	var north_tile := {"id": MahjongLogic.NORTH}
	for i in range(nukita.size()):
		var t: Dictionary = nukita[i]
		# 実際の北牌の属性（赤北など）を保持
		var tex: Texture2D = _get_tile_texture(t if not t.is_empty() else north_tile)
		var tr := TextureRect.new()
		tr.size = Vector2(tile_w, tile_h)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.pivot_offset = Vector2(tile_w / 2.0, tile_h / 2.0)
		tr.rotation_degrees = base_angle
		if is_vertical:
			tr.position = Vector2(0, i * (tile_w + gap))
		else:
			var x := -i * (tile_w + gap) if right_to_left else i * (tile_w + gap)
			tr.position = Vector2(x, 0)
		box.add_child(tr)

# 王牌表示を初期化（嶺上牌4×hai_haimen2 + 右端ドラ表示牌）
func _build_wanpai_display() -> void:
	for child in _wanpai_box.get_children():
		_wanpai_box.remove_child(child)
		child.queue_free()
	_wanpai_rinshan_rects.clear()
	_wanpai_dora_rects.clear()
	_wanpai_ura_rects.clear()
	var tw := 63
	var th := 87
	var gap := 0
	var start_x := 0
	# 左から嶺上牌4つを表示（各々hai_haimen2、2枚重ね=1表示）
	for i in range(4):
		var tr := TextureRect.new()
		tr.size = Vector2(tw, th)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = _get_haimen_texture()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.position = Vector2(start_x + i * (tw + gap), 28)
		_wanpai_box.add_child(tr)
		_wanpai_rinshan_rects.append(tr)
	# 右端からドラ表示牌を最大5枚（初期1枚 + 槓ドラ4枚）まで表示
	for i in range(5):
		var dora_rect := TextureRect.new()
		dora_rect.size = Vector2(tw, th)
		dora_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dora_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dora_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dora_rect.position = Vector2(start_x + (4 + i) * (tw + gap), 28)
		dora_rect.visible = false
		_wanpai_box.add_child(dora_rect)
		_wanpai_dora_rects.append(dora_rect)
		if i == 0:
			_wanpai_dora_rect = dora_rect
		var ura_rect := TextureRect.new()
		ura_rect.size = Vector2(tw, th)
		ura_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ura_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ura_rect.position = Vector2(start_x + (4 + i) * (tw + gap), 28 + th)
		ura_rect.visible = false
		_wanpai_box.add_child(ura_rect)
		_wanpai_ura_rects.append(ura_rect)

# 嶺上牌消費カウントを増やし、2回ごとに1表示削除
func _wanpai_consume() -> void:
	_wanpai_use_count += 1
	if _wanpai_use_count >= 2:
		_wanpai_use_count = 0
		# 左から1つ削除（非表示にする）
		for i in range(_wanpai_rinshan_rects.size()):
			var tr: TextureRect = _wanpai_rinshan_rects[i]
			if is_instance_valid(tr) and tr.visible:
				tr.visible = false
				break

# ドラ表示牌テクスチャを更新
func _refresh_wanpai_dora(show_ura_for_winner: int = -1) -> void:
	var show_ura := false
	if show_ura_for_winner >= 0 and show_ura_for_winner < GameState.players.size():
		show_ura = GameState.players[show_ura_for_winner].is_riichi
	for i in range(_wanpai_dora_rects.size()):
		var rect: TextureRect = _wanpai_dora_rects[i]
		if not is_instance_valid(rect):
			continue
		if i < GameState.dora_indicators.size() and i < 5:
			rect.texture = _get_tile_texture(GameState.dora_indicators[i])
			rect.visible = true
		else:
			rect.visible = false
		if i < _wanpai_ura_rects.size():
			var ura_rect: TextureRect = _wanpai_ura_rects[i]
			if not is_instance_valid(ura_rect):
				continue
			if show_ura and i < GameState.ura_dora_indicators.size() and i < 5:
				ura_rect.texture = _get_tile_texture(GameState.ura_dora_indicators[i])
				ura_rect.visible = true
			else:
				ura_rect.visible = false

# 捨て牌ボックスを牌画像で埋める
# vertical_first: 縦方向に max_per_stripe 枚並べてから横折り返し（右家用）
# bottom_up:      行の順序を逆にして、固定行数があれば下段から開始する（上家用）
func _fill_discard_box(box: Control, discards: Array, tile_w: int, tile_h: int, max_per_stripe: int, rotation_deg: float = 0.0, vertical_first: bool = false, bottom_up: bool = false, reverse_x: bool = false, fixed_stripes: int = 0, reverse_y: bool = false) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var gap := 2
	var col := 0
	var row := 0
	# bottom_up / reverse_x 用に総ストライプ数を事前計算
	var total_stripes := 0
	if bottom_up or (reverse_x and vertical_first):
		total_stripes = int(ceil(discards.size() / float(max_per_stripe)))
		if fixed_stripes > 0:
			total_stripes = max(total_stripes, fixed_stripes)
	# vertical_first 時は回転後の実寸でステップを計算
	var x_step := tile_w + gap
	var y_step := tile_h + gap
	if vertical_first:
		# -90° 回転後: 視覚 width = tile_h, 視覚 height = tile_w
		x_step = tile_h + gap
		y_step = tile_w + gap
	var riichi_extra := absi(tile_h - tile_w)
	var line_extra := 0.0
	var axis_sign := 1.0
	if vertical_first:
		axis_sign = -1.0 if reverse_y else 1.0
	else:
		axis_sign = -1.0 if reverse_x else 1.0
	for tile: Dictionary in discards:
		var tex_rect := TextureRect.new()
		tex_rect.size = Vector2(tile_w, tile_h)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = _get_tile_texture(tile)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.pivot_offset = Vector2(tile_w / 2.0, tile_h / 2.0)
		var deg := rotation_deg
		var is_riichi_tile: bool = tile.get("is_riichi_tile", false)
		if is_riichi_tile:
			deg += 90.0
		tex_rect.rotation_degrees = deg
		var display_row: int = row
		if bottom_up:
			var anchor_stripes := fixed_stripes if fixed_stripes > 0 else total_stripes
			display_row = anchor_stripes - 1 - row
		if reverse_y:
			display_row = max_per_stripe - 1 - row
		# reverse_x: 各プレイヤー視点で左から右になるよう列を逆順にする
		var reverse_base := total_stripes if vertical_first else max_per_stripe
		var display_col: int = max(reverse_base - 1 - col, 0) if reverse_x else col
		var cx: float = display_col * x_step + tile_w / 2.0
		var cy: float = display_row * y_step + tile_h / 2.0
		var pos := Vector2(cx - tile_w / 2.0, cy - tile_h / 2.0)
		var riichi_center_offset: float = riichi_extra / 2.0 if is_riichi_tile else 0.0
		if vertical_first:
			pos.y += axis_sign * (line_extra + riichi_center_offset)
		else:
			pos.x += axis_sign * (line_extra + riichi_center_offset)
		tex_rect.position = pos
		box.add_child(tex_rect)
		if tile.get("is_taken", false):
			var mask := ColorRect.new()
			mask.position = Vector2.ZERO
			mask.size = Vector2(tile_w, tile_h)
			mask.color = Color(0, 0, 0, 0.65)
			mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.add_child(mask)
		if vertical_first:
			if is_riichi_tile:
				line_extra += riichi_extra
			row += 1
			if row >= max_per_stripe:
				row = 0
				col += 1
				line_extra = 0.0
		else:
			if is_riichi_tile:
				line_extra += riichi_extra
			col += 1
			if col >= max_per_stripe:
				col = 0
				row += 1
				line_extra = 0.0

func _discards_text(discards: Array, vertical: bool = false) -> String:
	var parts: Array = []
	for t: Dictionary in discards:
		parts.append(MahjongLogic.get_tile_name(t))
	if vertical:
		return "\n".join(parts)
	return "  ".join(parts)

func _naki_text(naki: Array) -> String:
	var parts: Array = []
	for m: Dictionary in naki:
		var type_str: String = m.get("type", "?")
		var tile_ids: Array = m.get("tile_ids", [])
		var tiles_str := ""
		for tid: int in tile_ids:
			tiles_str += MahjongLogic.get_tile_name(MahjongLogic.make_tile(tid))
		parts.append("[" + type_str + ":" + tiles_str + "]")
	return "  ".join(parts)

func _naki_text_vertical(naki: Array) -> String:
	var parts: Array = []
	for m: Dictionary in naki:
		var type_str: String = m.get("type", "?")
		var tile_ids: Array = m.get("tile_ids", [])
		var tiles_str := ""
		for tid: int in tile_ids:
			tiles_str += MahjongLogic.get_tile_name(MahjongLogic.make_tile(tid))
		parts.append("[" + type_str + ":" + tiles_str + "]")
	return "\n".join(parts)

# ============================================================
# 結果表示
# ============================================================
func _show_result_sequence(result: Dictionary, play_call_animation: bool = true) -> void:
	if result.get("draw", false):
		await _reveal_draw_tenpai_hands(result)
		_clear_result_dynamic_nodes()
		_msg_panel.position = Vector2(530, 280)
		_msg_panel.size = Vector2(860, 520)
		_msg_panel.custom_minimum_size = Vector2(860, 520)
		_msg_label.position = Vector2(30, 30)
		_msg_label.size = Vector2(620, 420)
		_msg_label.visible = true
		_msg_ok.position = Vector2(350, 460)
		_msg_ok.custom_minimum_size = Vector2(160, 50)
		_msg_ok.size = _msg_ok.custom_minimum_size
		_btn_table_view.position = Vector2(350, 350)
		_btn_table_view.custom_minimum_size = Vector2(160, 50)
		_btn_table_view.size = _btn_table_view.custom_minimum_size
		_btn_table_view.visible = true
		_show_result(result)
		await _play_draw_npc_tenpai_voices(result)
		if result.get("oorasu_choice_required", false):
			_show_oorasu_choice_prompt()
		return
	var animation_result := result
	if result.get("is_double_ron", false) and _double_ron_result_queue.is_empty():
		_double_ron_result_queue = _ordered_double_ron_results(result)
		_double_ron_result_index = 0
		if not _double_ron_result_queue.is_empty():
			result = _double_ron_result_queue[0]
	_clear_result_dynamic_nodes()
	_haku_pochi_lbl.visible = false
	_haku_pochi_img.visible = false
	_msg_panel.visible = false
	_win_overlay.visible = false
	_msg_ok.visible = false
	_btn_table_view.visible = false
	_btn_result_back.visible = false
	_msg_label.text = ""
	if play_call_animation:
		await _play_win_call_animation(animation_result)
	_win_overlay.visible = true
	await _play_result_chara_animation(result)
	var _bust_ids: Array = result.get("bust_player_indices", [])
	if _bust_ids.is_empty() and result.get("bust_player_idx", -1) >= 0:
		_bust_ids = [result.get("bust_player_idx")]
	if 0 in _bust_ids:
		_play_chara_voice("seplavo_make")
	_prepare_win_result_panel(result)
	await _reveal_win_result(result)
	_finish_win_result_panel(result)

func _ordered_double_ron_results(main_result: Dictionary) -> Array:
	var results: Array = main_result.get("double_ron_results", [])
	var ordered: Array = results.duplicate(true)
	var loser_idx: int = int(main_result.get("loser_idx", -1))
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _double_ron_display_priority(int(a.get("winner_idx", -1)), loser_idx) < _double_ron_display_priority(int(b.get("winner_idx", -1)), loser_idx)
	)
	for r: Dictionary in ordered:
		r["is_double_ron"] = true
		r["match_will_end"] = main_result.get("match_will_end", false)
		r["oorasu_choice_required"] = main_result.get("oorasu_choice_required", false)
		r["bust_player_idx"] = main_result.get("bust_player_idx", -1)
		r["bust_player_indices"] = main_result.get("bust_player_indices", [])
		r["score_after"] = main_result.get("score_after", r.get("score_after", []))
		r["player_winds"] = main_result.get("player_winds", r.get("player_winds", []))
	return ordered

func _double_ron_display_priority(player_idx: int, loser_idx: int) -> int:
	for step in range(1, GameState.players.size()):
		if (loser_idx + step) % GameState.players.size() == player_idx:
			return step
	return 99

func _reveal_draw_tenpai_hands(result: Dictionary) -> void:
	var ti: Dictionary = result.get("tenpai_info", {})
	if ti.is_empty():
		return
	var tenpai: Array = ti.get("tenpai", [])
	if tenpai.is_empty():
		return
	if 0 in tenpai:
		_show_player_hand_as_touhai = true
		_refresh_hand()
	if UPPER_IDX in tenpai:
		for child in _upper_hand_box.get_children():
			_upper_hand_box.remove_child(child)
			child.queue_free()
		_fill_npc_debug_hand_box(_upper_hand_box, GameState.players[UPPER_IDX].hand, 617, 76)
	if RIGHT_IDX in tenpai:
		for child in _right_hand_box.get_children():
			_right_hand_box.remove_child(child)
			child.queue_free()
		_fill_npc_debug_hand_box(_right_hand_box, GameState.players[RIGHT_IDX].hand, 180, 540, 90.0)
	await get_tree().create_timer(3.0).timeout

func _play_win_call_animation(result: Dictionary) -> void:
	if result.get("is_double_ron", false) and not result.get("is_tsumo", false):
		await _play_double_ron_call_animation(result)
		return
	var winner_idx: int = result.get("winner_idx", 0)
	if winner_idx == 0:
		AudioManager.play_se("plhora")
	elif not _play_npc_win_voice(winner_idx, result):
		AudioManager.play_se("npchora")
	var call_sprite := Sprite2D.new()
	call_sprite.texture = load("res://ui/hassei_tumo.webp" if result.get("is_tsumo", false) else "res://ui/hassei_ron.webp")
	call_sprite.centered = true
	call_sprite.z_index = 80
	if call_sprite.texture:
		var texture_size: Vector2 = call_sprite.texture.get_size()
		var target_size := Vector2(663, 347)
		call_sprite.scale = Vector2.ONE * min(target_size.x / texture_size.x, target_size.y / texture_size.y)
	add_child(call_sprite)
	_result_dynamic_nodes.append(call_sprite)
	var pos: Dictionary = _win_call_positions(winner_idx)
	var start_center: Vector2 = pos.get("start", Vector2.ZERO)
	var end_center: Vector2 = pos.get("end", Vector2.ZERO)
	call_sprite.rotation_degrees = float(pos.get("rotation", 0.0))
	call_sprite.position = start_center
	var tween := create_tween()
	tween.tween_property(call_sprite, "position", end_center, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(1.65).timeout
	_result_dynamic_nodes.erase(call_sprite)
	call_sprite.queue_free()

func _play_double_ron_call_animation(result: Dictionary) -> void:
	var results: Array = _ordered_double_ron_results(result)
	if results.is_empty():
		return
	var sprites: Array = []
	var tween := create_tween().set_parallel(true)
	for sub: Dictionary in results:
		var winner_idx: int = int(sub.get("winner_idx", 0))
		if winner_idx == 0:
			AudioManager.play_se("plhora")
		elif not _play_npc_win_voice(winner_idx, sub):
			AudioManager.play_se("npchora")
		var call_sprite := _make_win_call_sprite(false)
		var pos: Dictionary = _win_call_positions(winner_idx)
		call_sprite.position = pos.get("start", Vector2.ZERO)
		call_sprite.rotation_degrees = float(pos.get("rotation", 0.0))
		add_child(call_sprite)
		_result_dynamic_nodes.append(call_sprite)
		sprites.append(call_sprite)
		tween.tween_property(call_sprite, "position", pos.get("end", Vector2.ZERO), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(1.65).timeout
	for sprite: Sprite2D in sprites:
		_result_dynamic_nodes.erase(sprite)
		sprite.queue_free()

func _make_win_call_sprite(is_tsumo: bool) -> Sprite2D:
	var call_sprite := Sprite2D.new()
	call_sprite.texture = load("res://ui/hassei_tumo.webp" if is_tsumo else "res://ui/hassei_ron.webp")
	call_sprite.centered = true
	call_sprite.z_index = 80
	if call_sprite.texture:
		var texture_size: Vector2 = call_sprite.texture.get_size()
		var target_size := Vector2(663, 347)
		call_sprite.scale = Vector2.ONE * min(target_size.x / texture_size.x, target_size.y / texture_size.y)
	return call_sprite

func _win_call_positions(winner_idx: int) -> Dictionary:
	var end_center := Vector2(SCREEN_SIZE.x * 0.5, 880)
	var start_center := Vector2(end_center.x, 960)
	var rotation := 0.0
	if winner_idx == RIGHT_IDX:
		end_center = Vector2(1440, SCREEN_SIZE.y * 0.5)
		start_center = Vector2(1760, SCREEN_SIZE.y * 0.5)
		rotation = -90.0
	elif winner_idx == UPPER_IDX:
		end_center = Vector2(SCREEN_SIZE.x * 0.5, 190)
		start_center = Vector2(end_center.x, -130)
		rotation = 180.0
	return {"start": start_center, "end": end_center, "rotation": rotation}

func _play_npc_win_voice(winner_idx: int, result: Dictionary) -> bool:
	if result.get("is_tsumo", false):
		if result.has("haku_pochi_best_tile") and _play_npc_voice(winner_idx, "siropotti"):
			return true
		return _play_npc_voice(winner_idx, "tumo")
	return _play_npc_voice(winner_idx, "ron")

func _play_draw_npc_tenpai_voices(result: Dictionary) -> void:
	var ti: Dictionary = result.get("tenpai_info", {})
	if ti.is_empty():
		return
	var tenpai: Array = ti.get("tenpai", [])
	var noten: Array = ti.get("noten", [])
	for wind: int in [MahjongLogic.EAST, MahjongLogic.SOUTH, MahjongLogic.WEST]:
		var player_idx := _find_player_index_by_wind(wind)
		if player_idx <= 0:
			continue
		var played := false
		if player_idx in tenpai:
			played = _play_npc_voice(player_idx, "tenpai")
		elif player_idx in noten:
			played = _play_npc_voice(player_idx, "noten")
		if played:
			await get_tree().create_timer(0.9).timeout

func _find_player_index_by_wind(wind: int) -> int:
	for i in range(GameState.players.size()):
		if int(GameState.players[i].get("wind", -1)) == wind:
			return i
	return -1

func _play_result_chara_animation(result: Dictionary) -> void:
	var winner_idx: int = int(result.get("winner_idx", 0))
	var chara_sprite := Sprite2D.new()
	chara_sprite.texture = _make_used_rect_texture(_get_result_chara_path(result))
	if chara_sprite.texture == null:
		return
	var chara_size := _get_result_chara_size(result)
	var chara_y := _get_result_chara_y(result, chara_size.y)
	chara_sprite.centered = false
	chara_sprite.position = Vector2(SCREEN_SIZE.x, chara_y)
	chara_sprite.scale = _get_result_chara_scale(result, chara_sprite.texture.get_size(), chara_size)
	chara_sprite.z_index = 60
	add_child(chara_sprite)
	_result_dynamic_nodes.append(chara_sprite)
	var tween := create_tween()
	var dest_x := 0.0
	tween.tween_property(chara_sprite, "position", Vector2(dest_x, chara_y), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if winner_idx == 0:
		_play_chara_voice("seplavo_hora")

func _get_result_chara_size(result: Dictionary) -> Vector2:
	match _get_result_winner_npc_id(result):
		"kuma_hiyake":
			return Vector2(500, 459)
		"kuma_saibo":
			return Vector2(500, 896)
	return Vector2(500, 970)

func _get_result_chara_y(result: Dictionary, chara_h: float) -> float:
	var winner_idx: int = int(result.get("winner_idx", 0))
	match _get_result_winner_npc_id(result):
		"kuma_hiyake":
			return (SCREEN_SIZE.y - chara_h) * 0.5
		"kuma_saibo":
			return 92.0
	return 65.0 if winner_idx == 0 else 415.0

func _get_result_chara_scale(result: Dictionary, texture_size: Vector2, target_size: Vector2) -> Vector2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE
	if _get_result_winner_npc_id(result) in ["kuma_hiyake", "kuma_saibo"]:
		return Vector2(target_size.x / texture_size.x, target_size.y / texture_size.y)
	var s: float = minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	return Vector2.ONE * s

func _prepare_win_result_panel(result: Dictionary) -> void:
	_msg_panel.position = RESULT_PANEL_RECT.position
	_msg_panel.size = RESULT_PANEL_RECT.size
	_msg_panel.custom_minimum_size = RESULT_PANEL_RECT.size
	_msg_panel.visible = true
	_msg_label.text = ""
	_msg_label.visible = false
	_haku_pochi_lbl.visible = false
	_haku_pochi_img.visible = false
	_msg_ok.visible = false
	_msg_ok.position = Vector2(1100, 955)
	_msg_ok.custom_minimum_size = Vector2(220, 58)
	_msg_ok.size = _msg_ok.custom_minimum_size
	_msg_ok.text = "次へ" if _double_ron_has_next_result() else ("精算へ" if result.get("match_will_end", false) else "次の局へ")
	_btn_table_view.position = Vector2(1100, 835)
	_btn_table_view.custom_minimum_size = Vector2(220, 58)
	_btn_table_view.size = _btn_table_view.custom_minimum_size
	_btn_table_view.visible = false

func _finish_win_result_panel(_result: Dictionary) -> void:
	_btn_table_view.visible = true
	if _result.get("oorasu_choice_required", false) and not _double_ron_has_next_result():
		_show_oorasu_choice_prompt()
	else:
		_msg_ok.visible = true

func _double_ron_has_next_result() -> bool:
	return _double_ron_result_index >= 0 and _double_ron_result_index + 1 < _double_ron_result_queue.size()

func _show_oorasu_choice_prompt() -> void:
	_msg_ok.visible = false
	_btn_table_view.position = Vector2(_msg_panel.size.x - 340.0, _msg_panel.size.y - 236.0)
	_btn_table_view.visible = true
	var label := Label.new()
	label.text = "ゲームを続行しますか？"
	label.position = Vector2(_msg_panel.size.x - 470.0, _msg_panel.size.y - 172.0)
	label.size = Vector2(420, 44)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_panel.add_child(label)
	_result_dynamic_nodes.append(label)
	var btn_yes := _make_button("はい", Color(0.15, 0.50, 0.24))
	btn_yes.position = Vector2(_msg_panel.size.x - 430.0, _msg_panel.size.y - 104.0)
	btn_yes.custom_minimum_size = Vector2(150, 58)
	btn_yes.size = btn_yes.custom_minimum_size
	btn_yes.pressed.connect(_on_oorasu_continue_yes_pressed)
	_msg_panel.add_child(btn_yes)
	_result_dynamic_nodes.append(btn_yes)
	var btn_no := _make_button("いいえ", Color(0.42, 0.20, 0.20))
	btn_no.position = Vector2(_msg_panel.size.x - 250.0, _msg_panel.size.y - 104.0)
	btn_no.custom_minimum_size = Vector2(150, 58)
	btn_no.size = btn_no.custom_minimum_size
	btn_no.pressed.connect(_on_oorasu_continue_no_pressed)
	_msg_panel.add_child(btn_no)
	_result_dynamic_nodes.append(btn_no)

func _on_oorasu_continue_yes_pressed() -> void:
	_clear_result_dynamic_nodes()
	_win_overlay.visible = false
	_msg_panel.visible = false
	_btn_result_back.visible = false
	_btn_table_view.visible = false
	GameState.resolve_oorasu_player_choice(true)

func _on_oorasu_continue_no_pressed() -> void:
	_clear_result_dynamic_nodes()
	_win_overlay.visible = false
	_msg_panel.visible = false
	_btn_result_back.visible = false
	_btn_table_view.visible = false
	GameState.resolve_oorasu_player_choice(false)

func _reveal_win_result(result: Dictionary) -> void:
	var winner_idx: int = result.get("winner_idx", 0)
	var winner: Dictionary = GameState.players[winner_idx]
	var sd: Dictionary = result.get("score_data", {})
	var is_yakuman: bool = result.get("is_yakuman", false)
	var yaku_list: Array = result.get("yaku", [])
	var filtered_yaku: Array = []
	for yaku: Dictionary in yaku_list:
		if not is_yakuman or int(yaku.get("han", 0)) >= 13:
			filtered_yaku.append(yaku)
	var meld_start_x := _add_result_hand(result.get("winning_display_tiles", winner.get("hand", [])))
	meld_start_x = _add_result_haku_pochi_conversion(result, meld_start_x)
	meld_start_x = _add_result_nukita(result, meld_start_x)
	_add_result_melds(result.get("winning_display_melds", []), meld_start_x, winner_idx)
	await _result_delay()
	_add_result_label("ツモ" if result.get("is_tsumo", false) else "ロン", Vector2(80, 172), Vector2(220, 54), 42, Color(1.0, 0.88, 0.44))
	await _result_delay()
	_add_result_wanpai(winner_idx)
	var y := 250.0
	for yaku: Dictionary in filtered_yaku:
		var yaku_han: int = int(yaku.get("han", 0))
		var suffix := " 役満" if yaku_han >= 13 else " " + str(yaku_han) + "飜"
		if yaku.get("no_yakuman_chip", false):
			suffix = " " + str(yaku_han) + "飜"
		_add_result_label(str(yaku.get("name", "")) + suffix, Vector2(80, y), Vector2(780, 38), 30)
		AudioManager.play_se("wav/yakuhyouji.wav", 1.5)
		y += 42.0
		await _result_delay()
	_add_result_label(str(result.get("han", 0)) + "飜", Vector2(80, y + 8), Vector2(260, 48), 38, Color(1.0, 0.94, 0.62))
	await _result_delay()
	var limit_name := _get_limit_name(int(result.get("han", 0)), is_yakuman)
	var score_text := str(int(sd.get("total", 0))) + "点"
	var honba_val: int = int(result.get("honba", 0))
	var honba_bonus_val: int = int(result.get("honba_bonus", 0))
	if limit_name != "":
		_add_result_label(limit_name, Vector2(80, y + 70), Vector2(420, 64), 48, Color(1.0, 0.78, 0.25))
		_add_result_label(score_text, Vector2(540, y + 76), Vector2(280, 54), 42, Color(1.0, 0.96, 0.85))
		if honba_val > 0:
			_add_result_label("+%d点" % honba_bonus_val, Vector2(830, y + 82), Vector2(260, 44), 34, Color(1.0, 0.80, 0.50))
		AudioManager.play_se("gangan")
		await get_tree().create_timer(1.0).timeout
	else:
		_add_result_label(score_text, Vector2(80, y + 72), Vector2(260, 54), 42, Color(1.0, 0.96, 0.85))
		if honba_val > 0:
			_add_result_label("+%d点" % honba_bonus_val, Vector2(350, y + 78), Vector2(260, 44), 34, Color(1.0, 0.80, 0.50))
		await _result_delay()
	var chips_per: int = int(result.get("chips_per_player", 0))
	var is_tsumo: bool = result.get("is_tsumo", false)
	var chip_text: String = ("チップ %d枚×２" % chips_per) if is_tsumo else ("チップ %d枚" % chips_per)
	_add_result_label(chip_text, Vector2(80, y + 150), Vector2(420, 42), 30, Color(0.86, 1.0, 0.88))
	await _result_delay()
	var scores_y := y + 215.0
	for i in range(GameState.players.size()):
		var row: String = _result_score_transition_text(result, i)
		_add_result_label(row, Vector2(80, scores_y + i * 42.0), Vector2(1040, 38), 26)
	await _result_delay()

func _result_delay() -> void:
	await get_tree().create_timer(RESULT_STEP_DELAY).timeout

func _result_score_transition_text(result: Dictionary, player_idx: int) -> String:
	var p: Dictionary = GameState.players[player_idx]
	var before_scores: Array = result.get("score_before", [])
	var after_scores: Array = result.get("score_after", [])
	var before: int = int(before_scores[player_idx]) if player_idx < before_scores.size() else int(p.score)
	var after: int = int(after_scores[player_idx]) if player_idx < after_scores.size() else int(p.score)
	var wind: int = _get_result_player_wind(result, player_idx)
	return MahjongLogic.get_wind_name(wind) + "家 " + p.name + ": " + str(before) + "点→" + str(after) + "点"

func _get_result_player_wind(result: Dictionary, player_idx: int) -> int:
	var player_winds: Array = result.get("player_winds", [])
	if player_idx >= 0 and player_idx < player_winds.size():
		return int(player_winds[player_idx])
	if player_idx >= 0 and player_idx < GameState.players.size():
		return int(GameState.players[player_idx].wind)
	return MahjongLogic.EAST

func _add_result_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color = Color(1.0, 0.96, 0.85), align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_panel.add_child(label)
	_result_dynamic_nodes.append(label)
	return label

func _add_result_action_image(is_tsumo: bool) -> void:
	var rect := TextureRect.new()
	rect.texture = load("res://ui/hassei_tumo.webp" if is_tsumo else "res://ui/hassei_ron.webp")
	rect.position = Vector2(80, 150)
	rect.size = Vector2(260, 96)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_panel.add_child(rect)
	_result_dynamic_nodes.append(rect)

func _add_result_wanpai(winner_idx: int) -> void:
	var tile_w := 44
	var tile_h := 61
	var gap := 4
	var dora_count: int = min(GameState.dora_indicators.size(), 5)
	if dora_count <= 0:
		return
	var show_ura: bool = winner_idx >= 0 and winner_idx < GameState.players.size() and GameState.players[winner_idx].is_riichi
	var right_margin: float = 44.0
	var dora_y := 250.0
	var start_x: float = RESULT_PANEL_RECT.size.x - right_margin - dora_count * tile_w - max(0, dora_count - 1) * gap
	var rinshan_count: int = min(GameState.rinshan.size(), 4)
	var rinshan_start_x: float = start_x - 18.0 - rinshan_count * tile_w - max(0, rinshan_count - 1) * gap
	for i in range(rinshan_count):
		var rect := _make_result_wanpai_back_tile(Vector2(rinshan_start_x + i * (tile_w + gap), dora_y), Vector2(tile_w, tile_h))
		_msg_panel.add_child(rect)
		_result_dynamic_nodes.append(rect)
	for i in range(dora_count):
		var rect := _make_result_wanpai_tile(GameState.dora_indicators[i], Vector2(start_x + i * (tile_w + gap), dora_y), Vector2(tile_w, tile_h))
		_msg_panel.add_child(rect)
		_result_dynamic_nodes.append(rect)
	if not show_ura:
		return
	var ura_count: int = min(GameState.ura_dora_indicators.size(), dora_count)
	var ura_start_x: float = RESULT_PANEL_RECT.size.x - right_margin - ura_count * tile_w - max(0, ura_count - 1) * gap
	for i in range(ura_count):
		var rect := _make_result_wanpai_tile(GameState.ura_dora_indicators[i], Vector2(ura_start_x + i * (tile_w + gap), dora_y + tile_h + 6), Vector2(tile_w, tile_h))
		_msg_panel.add_child(rect)
		_result_dynamic_nodes.append(rect)

func _make_result_wanpai_tile(tile: Dictionary, pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.position = pos
	rect.size = size
	rect.texture = _get_tile_texture(tile)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _make_result_wanpai_back_tile(pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.position = pos
	rect.size = size
	rect.texture = _get_haimen_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _add_result_hand(hand: Array) -> float:
	var display_tiles := _get_result_display_tiles(hand)
	var tile_w := 60
	var tile_h := 80
	var gap := 4
	var base := Vector2(80, 42)
	if display_tiles.size() > 14:
		tile_w = 54
		tile_h = 72
	for i in range(display_tiles.size()):
		var rect := TextureRect.new()
		rect.position = base + Vector2(i * (tile_w + gap), 0)
		if i == display_tiles.size() - 1 and display_tiles.size() >= 2:
			rect.position.x = base.x + i * (tile_w + gap) + 26
		rect.size = Vector2(tile_w, tile_h)
		rect.texture = _get_tile_texture(display_tiles[i])
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_msg_panel.add_child(rect)
		_result_dynamic_nodes.append(rect)
	if display_tiles.is_empty():
		return base.x
	var last_i := display_tiles.size() - 1
	var last_x := base.x + last_i * (tile_w + gap)
	if display_tiles.size() >= 2:
		last_x += 26
	return last_x + tile_w + 20

func _add_result_nukita(result: Dictionary, start_x: float) -> float:
	var nukita_tiles: Array = result.get("nukita_tiles", [])
	var count: int = nukita_tiles.size()
	if count <= 0:
		count = int(result.get("nukita_count", 0))
	if count <= 0:
		return start_x
	var tile_w := 54.0
	var tile_h := 72.0
	var gap := 4.0
	var draw_count: int = mini(count, 4)
	for i in range(draw_count):
		var tile: Dictionary = nukita_tiles[i] if i < nukita_tiles.size() and nukita_tiles[i] is Dictionary else MahjongLogic.make_tile(MahjongLogic.NORTH)
		var rect := TextureRect.new()
		rect.position = Vector2(start_x + i * (tile_w + gap), 46.0)
		rect.size = Vector2(tile_w, tile_h)
		rect.texture = _get_tile_texture(tile)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_msg_panel.add_child(rect)
		_result_dynamic_nodes.append(rect)
	var label_x := start_x + draw_count * (tile_w + gap) + 4.0
	if count > draw_count:
		_add_result_label("×" + str(count), Vector2(label_x, 58.0), Vector2(66, 42), 32, Color(1.0, 0.96, 0.85))
		return label_x + 70.0
	return label_x + 16.0

func _add_result_haku_pochi_conversion(result: Dictionary, start_x: float) -> float:
	if not result.has("haku_pochi_best_tile"):
		return start_x
	var arrow := _add_result_label("→", Vector2(start_x - 2.0, 48.0), Vector2(42, 64), 42, Color(1.0, 0.94, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rect := TextureRect.new()
	rect.position = Vector2(start_x + 44.0, 42.0)
	rect.size = Vector2(60, 80)
	rect.texture = _get_tile_texture(MahjongLogic.make_tile(int(result.get("haku_pochi_best_tile", 45))))
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_panel.add_child(rect)
	_result_dynamic_nodes.append(rect)
	return start_x + 124.0

func _add_result_melds(melds: Array, start_x: float, winner_idx: int) -> void:
	if melds.is_empty():
		return
	var tile_w := 54
	var tile_h := 72
	var tile_gap := 4
	var meld_gap := 18
	var cursor_x := start_x
	var y := 46.0
	for meld: Dictionary in melds:
		var tiles: Array = meld.get("tiles", [])
		if tiles.is_empty():
			var tile_ids: Array = meld.get("tile_ids", [])
			for tid in tile_ids:
				tiles.append(MahjongLogic.make_tile(int(tid)))
		var order: Array = _build_meld_display_order(meld, winner_idx)
		var mtype: String = str(meld.get("type", ""))
		var kakan_rotated_x := cursor_x
		for vi in range(order.size()):
			var data_idx: int = int(order[vi])
			if data_idx < 0 or data_idx >= tiles.size():
				continue
			var rotated := data_idx == 0 and mtype != "ankan"
			var is_haimen: bool = mtype == "ankan" and (vi == 0 or vi == order.size() - 1)
			var rect := TextureRect.new()
			rect.position = Vector2(cursor_x, y)
			rect.size = Vector2(tile_w, tile_h)
			rect.texture = _get_haimen_texture() if is_haimen else _get_tile_texture(tiles[data_idx])
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if rotated:
				kakan_rotated_x = cursor_x
				rect.pivot_offset = Vector2(tile_w * 0.5, tile_h * 0.5)
				rect.rotation_degrees = 90.0
				rect.position += Vector2((tile_h - tile_w) * 0.5, -2.0)
			_msg_panel.add_child(rect)
			_result_dynamic_nodes.append(rect)
			cursor_x += (tile_h if rotated else tile_w) + tile_gap
		if mtype == "kakan" and tiles.size() >= 4:
			var add_rect := TextureRect.new()
			add_rect.position = Vector2(kakan_rotated_x + (tile_h - tile_w) * 0.5, y - tile_w + 6.0)
			add_rect.size = Vector2(tile_w, tile_h)
			add_rect.texture = _get_tile_texture(tiles[3])
			add_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			add_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			add_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_rect.pivot_offset = Vector2(tile_w * 0.5, tile_h * 0.5)
			add_rect.rotation_degrees = 90.0
			_msg_panel.add_child(add_rect)
			_result_dynamic_nodes.append(add_rect)
		cursor_x += meld_gap

func _get_result_display_tiles(hand: Array) -> Array:
	var tiles := hand.duplicate(true)
	if tiles.size() <= 1:
		return tiles
	var winning_tile: Dictionary = tiles.pop_back()
	tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	if hand.size() >= 14:
		while tiles.size() > 13:
			tiles.pop_back()
	tiles.append(winning_tile)
	return tiles

func _get_limit_name(han: int, is_yakuman: bool) -> String:
	if is_yakuman or han >= 13:
		return "役満"
	if han >= 11:
		return "三倍満"
	if han >= 8:
		return "倍満"
	if han >= 6:
		return "跳満"
	if han >= 4:
		return "満貫"
	return ""

func _get_result_chara_path(result: Dictionary) -> String:
	var winner_idx: int = int(result.get("winner_idx", 0))
	if winner_idx == 0:
		return "res://chara/hatimi2.webp"
	var npc_id := _get_result_winner_npc_id(result)
	match npc_id:
		"kuma_hiyake":
			return "res://chara/riza_hiyake.webp"
		"kuma_saibo":
			return "res://chara/riza_saibo.webp"
		"kuma_megane":
			return "res://chara/riza_megane.webp"
	if npc_id != "":
		return SaveData.get_npc_path_game(npc_id)
	return "res://chara/kuma_def2a.webp"

func _get_winner_npc_id(winner_idx: int) -> String:
	if winner_idx > 0 and winner_idx < GameState.players.size():
		return str(GameState.players[winner_idx].get("npc_id", ""))
	return ""

func _get_result_winner_npc_id(result: Dictionary) -> String:
	var npc_id := str(result.get("winner_npc_id", ""))
	if npc_id != "":
		return npc_id
	return _get_winner_npc_id(int(result.get("winner_idx", 0)))

func _clear_result_dynamic_nodes() -> void:
	for node in _result_dynamic_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_result_dynamic_nodes.clear()
	if _msg_label:
		_msg_label.visible = true
	if _msg_ok:
		_msg_ok.visible = true

func _show_result(result: Dictionary) -> void:
	var msg := ""
	_haku_pochi_lbl.visible = false
	_haku_pochi_img.visible = false
	if result.get("draw", false):
		msg = "流局！\n\n"
		var ti: Dictionary = result.get("tenpai_info", {})
		if not ti.is_empty() and ti.get("payment", 0) > 0:
			var tp: Array = ti.get("tenpai", [])
			var nt: Array = ti.get("noten", [])
			var tp_names := ""
			for i: int in tp: tp_names += GameState.players[i].name + " "
			var nt_names := ""
			for i: int in nt: nt_names += GameState.players[i].name + " "
			msg += "テンパイ: " + tp_names + "\nノーテン: " + nt_names + "\n\n"
		else:
			msg += "（テンパイ精算なし）\n\n"
		for i in range(GameState.players.size()):
			msg += _result_score_transition_text(result, i) + "\n"
	else:
		var winner: Dictionary = GameState.players[result.winner_idx]
		var sd: Dictionary = result.score_data
		var is_yakuman: bool = result.get("is_yakuman", false)
		msg = ("【ツモ！】" if result.is_tsumo else ("【ダブロン！】" if result.get("is_double_ron", false) else "【ロン！】")) + "\n\n"
		msg += "和了: " + winner.name + " (" + MahjongLogic.get_wind_name(_get_result_player_wind(result, int(result.winner_idx))) + "家)\n"
		if result.get("is_double_ron", false):
			var subs: Array = result.get("double_ron_results", [])
			for sub: Dictionary in subs:
				if int(sub.get("winner_idx", -1)) == int(result.get("winner_idx", -1)):
					continue
				var sp: Dictionary = GameState.players[int(sub.get("winner_idx", -1))]
				msg += "和了: " + sp.name + " (" + MahjongLogic.get_wind_name(_get_result_player_wind(result, int(sub.get("winner_idx", -1)))) + "家)\n"
		if result.has("yaku") and not result.yaku.is_empty():
			if is_yakuman:
				for y: Dictionary in result.yaku:
					if y.han >= 13:
						if y.get("no_yakuman_chip", false):
							msg += "  " + y.name + "  " + str(y.han) + "飜\n"
						else:
							msg += "  " + y.name + "  役満\n"
			else:
				for y: Dictionary in result.yaku:
					msg += "  " + y.name + "  " + str(y.han) + "ハン\n"
		if is_yakuman:
			msg += "\n役満\n"
		else:
			msg += "\n" + str(result.han) + "ハン（30符固定）\n"
		msg += "獲得点数: " + str(sd.total) + "点"
		if result.honba > 0:
			msg += "  (+積み棒 " + str(result.honba_bonus) + "点)"
		if result.get("chips_per_player", 0) > 0:
			msg += "  チップ: " + str(result.chips_per_player) + "枚/人"
		msg += "\n\n"
		for i in range(GameState.players.size()):
			msg += _result_score_transition_text(result, i) + "\n"
		if result.has("haku_pochi_best_tile"):
			_haku_pochi_lbl.text = "白ポッチ\nツモ牌："
			_haku_pochi_img.texture = _get_tile_texture(MahjongLogic.make_tile(result.haku_pochi_best_tile))
			_haku_pochi_lbl.visible = true
			_haku_pochi_img.visible = true
		else:
			_haku_pochi_lbl.visible = false
			_haku_pochi_img.visible = false

	var bust_indices: Array = result.get("bust_player_indices", [])
	if bust_indices.is_empty() and result.get("bust_player_idx", -1) >= 0:
		bust_indices = [result.bust_player_idx]
	for bust_idx: int in bust_indices:
		var bust_p: Dictionary = GameState.players[bust_idx]
		msg += "\n【飛び！】" + bust_p.name + " が持ち点を失いました"

	_msg_label.text = msg
	var will_end: bool = result.get("match_will_end", false)
	_msg_ok.text = "精算へ" if will_end else "次の局へ"
	_win_overlay.visible = true
	_msg_panel.visible = true

# ============================================================
# ボタン状態管理
# ============================================================
func _set_action_buttons_state(
		can_discard: bool, can_tsumo: bool, can_ron: bool, can_skip: bool,
		can_riichi: bool, can_pon: bool, can_kita: bool, can_kan: bool) -> void:
	_btn_discard.disabled = not can_discard
	_btn_tsumo.disabled   = not can_tsumo
	_btn_ron.disabled     = not can_ron
	_btn_skip.disabled    = not can_skip
	_btn_riichi.disabled  = not can_riichi
	_btn_open_riichi.disabled = not can_riichi or not GameState.can_player_open_riichi()
	_btn_pon.disabled     = not can_pon
	_btn_kita.disabled    = not can_kita
	_btn_kan.disabled     = not can_kan
	_btn_discard.visible = can_discard
	_btn_tsumo.visible   = can_tsumo
	_btn_ron.visible     = can_ron
	_btn_skip.visible    = can_skip
	_btn_riichi.visible  = can_riichi
	_btn_open_riichi.visible = can_riichi
	_btn_pon.visible     = can_pon
	_btn_kita.visible    = can_kita
	_btn_kan.visible     = can_kan
	# リーチモードが終了した場合はキャンセルボタンも非表示
	if not _riichi_mode:
		_btn_riichi_cancel.visible = false
	if _riichi_mode:
		_btn_open_riichi.visible = false
	_layout_action_buttons()
	if _assist_btn != null and not _can_show_assist_toggle():
		_set_assist_toggle_visible(false)
	if not _can_show_auto_assist():
		_hide_assist()

func _layout_action_buttons() -> void:
	if _action_box == null:
		return
	if _btn_tsumo.visible and _btn_open_riichi.visible and _btn_riichi.visible:
		var center_x := (_action_box.size.x - _btn_tsumo.custom_minimum_size.x) / 2.0
		var button_y := 0.0
		_btn_open_riichi.position = Vector2(center_x - _btn_open_riichi.custom_minimum_size.x, button_y)
		_btn_tsumo.position = Vector2(center_x, button_y)
		_btn_riichi.position = Vector2(center_x + _btn_tsumo.custom_minimum_size.x, button_y)
		_btn_open_riichi.size = _btn_open_riichi.custom_minimum_size
		_btn_tsumo.size = _btn_tsumo.custom_minimum_size
		_btn_riichi.size = _btn_riichi.custom_minimum_size
		return
	var visible_buttons: Array = []
	for btn: Button in [_btn_discard, _btn_tsumo, _btn_ron, _btn_open_riichi, _btn_riichi, _btn_pon, _btn_kita, _btn_kan, _btn_skip, _btn_riichi_cancel]:
		if btn.visible:
			visible_buttons.append(btn)
	var gap := 0.0
	var rows: Array = []
	var current_row: Array = []
	var current_w := 0.0
	for btn: Button in visible_buttons:
		var btn_w: float = btn.custom_minimum_size.x
		var next_w: float = btn_w if current_row.is_empty() else current_w + gap + btn_w
		if not current_row.is_empty() and next_w > _action_box.size.x:
			rows.append(current_row)
			current_row = []
			current_w = 0.0
		current_row.append(btn)
		current_w = btn_w if current_w == 0.0 else current_w + gap + btn_w
	if not current_row.is_empty():
		rows.append(current_row)

	var y := 0.0
	for row: Array in rows:
		var row_w := 0.0
		var row_h := 0.0
		for i in range(row.size()):
			var btn: Button = row[i]
			row_w += btn.custom_minimum_size.x
			row_h = max(row_h, btn.custom_minimum_size.y)
			if i > 0:
				row_w += gap
		var x := (_action_box.size.x - row_w) / 2.0
		for btn: Button in row:
			btn.position = Vector2(x, y)
			btn.size = btn.custom_minimum_size
			x += btn.custom_minimum_size.x + gap
		y += row_h + gap

# ============================================================
# デバッグ
# ============================================================
const _DEBUG_PALETTE: Array = [
	[21,22,23,24,25,26,27,28,29],
	[31,32,33,34,35,36,37,38,39],
	[11,19, 41,42,43,44,45,46,47],
]
const _DEBUG_ROW_LABELS: Array = ["筒子", "索子", "萬/字牌"]
# 特殊牌（赤牌・金牌・白ポッチ）のパレット行
const _DEBUG_PALETTE_SPECIAL: Array = [
	{"id": 25, "is_red": true},
	{"id": 35, "is_red": true},
	{"id": 28, "is_gold": true},
	{"id": 38, "is_gold": true},
	{"id": 45, "is_haku_pochi": true},
]
const _DBG_SW := 58
const _DBG_SH := 80
const _DBG_GAP := 4
const _DBG_DGAP := 14

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_open_debug_for(0)
		elif event.keycode == KEY_F2:
			_open_debug_for(RIGHT_IDX)
		elif event.keycode == KEY_F3:
			_open_debug_for(UPPER_IDX)
		elif event.keycode == KEY_F4:
			_toggle_rinshan_debug()
		elif event.keycode == KEY_F5:
			_toggle_npc_hand_debug()

func _build_debug_buttons() -> Control:
	var box := Control.new()
	box.size = Vector2(320, 40)
	var button_defs: Array = [
		{"text": "F1", "tooltip": "プレイヤー手牌デバッグ", "target": 0},
		{"text": "F2", "tooltip": "NPC1・右家手牌デバッグ", "target": RIGHT_IDX},
		{"text": "F3", "tooltip": "NPC2・上家手牌デバッグ", "target": UPPER_IDX},
	]
	for i in range(button_defs.size()):
		var def: Dictionary = button_defs[i]
		var btn := _make_debug_button(def.text, def.tooltip)
		btn.position = Vector2(i * 58, 0)
		var target_idx: int = def.target
		btn.pressed.connect(func() -> void: _open_debug_for(target_idx))
		box.add_child(btn)

	var btn_f4 := _make_debug_button("F4", "嶺上牌デバッグ")
	btn_f4.position = Vector2(3 * 58, 0)
	btn_f4.pressed.connect(_toggle_rinshan_debug)
	box.add_child(btn_f4)

	var btn_f5 := _make_debug_button("F5", "NPC謇狗煙陦ｨ遉ｺ")
	btn_f5.position = Vector2(4 * 58, 0)
	btn_f5.pressed.connect(_toggle_npc_hand_debug)
	box.add_child(btn_f5)
	return box

func _make_debug_button(text: String, tooltip: String) -> Button:
	var btn := _make_button(text, Color(0.08, 0.10, 0.14, 0.88))
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(52, 36)
	btn.size = btn.custom_minimum_size
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _toggle_rinshan_debug() -> void:
	_debug_rinshan_panel.visible = not _debug_rinshan_panel.visible
	if _debug_rinshan_panel.visible:
		_rinshan_debug_init()

func _toggle_npc_hand_debug() -> void:
	_debug_show_npc_hands = not _debug_show_npc_hands
	_refresh_npc_areas()

func _open_debug_for(target_idx: int) -> void:
	if _debug_panel.visible and _debug_target_idx == target_idx:
		_debug_panel.visible = false
		return
	_debug_target_idx = target_idx
	_debug_panel.visible = true
	_debug_init()

func _debug_init() -> void:
	_debug_hand_tiles.clear()
	for _i in range(13):
		_debug_hand_tiles.append({})
	_debug_draw_tile = {}
	_debug_next_draw_tile = {}
	_debug_cursor = 0
	var p: Dictionary = GameState.players[_debug_target_idx]
	var hand: Array = p.hand
	if is_instance_valid(_debug_title_label):
		var lbl_names := ["プレイヤー(F1)", "NPC1・右家(F2)", "NPC2・上家(F3)"]
		_debug_title_label.text = "デバッグモード - " + lbl_names[_debug_target_idx]
	if _debug_target_idx == 0:
		# プレイヤー0: 鳴き後は13枚未満でもOK
		var sort_end: int = hand.size() - 1 if (_player_drew and hand.size() >= 2) else hand.size()
		var sorted_hand: Array = hand.slice(0, sort_end)
		sorted_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _tile_sort_key(a) < _tile_sort_key(b)
		)
		for i in range(min(sorted_hand.size(), 13)):
			_debug_hand_tiles[i] = sorted_hand[i].duplicate()
		if _player_drew and hand.size() >= 2:
			_debug_draw_tile = hand[hand.size() - 1].duplicate()
			# NPC2人が先に引くので wall[2] が自分の次順ツモ
			if GameState.wall.size() > 2:
				_debug_next_draw_tile = GameState.wall[2].duplicate()
		else:
			if GameState.wall.size() > 0:
				_debug_draw_tile = GameState.wall[0].duplicate()
	else:
		# NPC: 全手牌をスロット0〜N-1に配置（ツモ牌も手牌に含む）
		for i in range(min(hand.size(), 13)):
			_debug_hand_tiles[i] = hand[i].duplicate()
		if hand.size() > 13:
			_debug_draw_tile = hand[hand.size() - 1].duplicate()
		var next_wall_idx: int = GameState.debug_next_draw_wall_index(_debug_target_idx, _debug_draw_tile.get("id", 0) > 0)
		if next_wall_idx >= 0 and next_wall_idx < GameState.wall.size():
			_debug_next_draw_tile = GameState.wall[next_wall_idx].duplicate()
	_debug_refresh_slots()
	if is_instance_valid(_debug_error_label):
		_debug_error_label.text = ""

func _debug_slot_tile(slot: int) -> Dictionary:
	if slot < 13: return _debug_hand_tiles[slot]
	if slot == 13: return _debug_draw_tile
	return _debug_next_draw_tile

func _debug_refresh_slots() -> void:
	for i in range(15):
		var sp: Panel = _debug_slot_panels[i]
		var st: TextureRect = _debug_slot_textures[i]
		var tile: Dictionary = _debug_slot_tile(i)
		var tid: int = tile.get("id", 0)
		var sty := StyleBoxFlat.new()
		sty.set_corner_radius_all(4)
		if i == _debug_cursor:
			sty.set_border_width_all(3)
			sty.border_color = Color(0.2, 0.9, 1.0)
			sty.bg_color = Color(0.15, 0.35, 0.45, 0.9) if tid == 0 else Color(0.95, 0.92, 0.80)
		elif tid > 0:
			sty.set_border_width_all(2)
			sty.border_color = Color(0.4, 0.3, 0.1)
			sty.bg_color = Color(0.95, 0.92, 0.80)
		else:
			sty.set_border_width_all(2)
			sty.border_color = Color(0.45, 0.45, 0.45)
			sty.bg_color = Color(0.25, 0.25, 0.25, 0.8)
		sp.add_theme_stylebox_override("panel", sty)
		if tid > 0:
			st.texture = _get_tile_texture(tile)
			st.modulate = Color(1, 1, 1, 1)
		else:
			st.texture = null

func _debug_advance_cursor() -> void:
	for i in range(_debug_cursor + 1, 15):
		if _debug_slot_tile(i).get("id", 0) == 0:
			_debug_cursor = i
			return
	for i in range(15):
		if _debug_slot_tile(i).get("id", 0) == 0:
			_debug_cursor = i
			return

func _debug_on_palette_click(tile: Dictionary) -> void:
	if _debug_cursor < 13:
		_debug_hand_tiles[_debug_cursor] = tile
	elif _debug_cursor == 13:
		_debug_draw_tile = tile
	else:
		_debug_next_draw_tile = tile
	_debug_advance_cursor()
	_debug_refresh_slots()

func _debug_on_slot_click(slot_idx: int) -> void:
	_debug_cursor = slot_idx
	_debug_refresh_slots()

func _debug_clear_cursor_slot() -> void:
	if _debug_cursor < 13:
		_debug_hand_tiles[_debug_cursor] = {}
	elif _debug_cursor == 13:
		_debug_draw_tile = {}
	else:
		_debug_next_draw_tile = {}
	_debug_refresh_slots()

func _on_debug_apply() -> void:
	var hand_tiles: Array = []
	for tile: Dictionary in _debug_hand_tiles:
		if tile.get("id", 0) > 0:
			hand_tiles.append(tile)
	# 鳴き後など13枚未満でも適用可能（0枚の場合のみ弾く）
	if hand_tiles.is_empty():
		if is_instance_valid(_debug_error_label):
			_debug_error_label.text = "手牌が0枚です"
		return
	if is_instance_valid(_debug_error_label):
		_debug_error_label.text = ""
	if _debug_target_idx == 0:
		GameState.debug_set_hand(hand_tiles, _debug_draw_tile, _debug_next_draw_tile, 0)
		_player_drew = (_debug_draw_tile.get("id", 0) > 0)
		_riichi_mode = false
		_riichi_selectable.clear()
		_selected_idx = -1
		_refresh_hand()
		_check_tsumo_auto()
		call_deferred("_refresh_player_draw_actions")
	else:
		GameState.debug_set_hand(hand_tiles, _debug_draw_tile, _debug_next_draw_tile, _debug_target_idx)
		_refresh_npc_areas()
	_debug_panel.visible = false

func _debug_make_slot(panel: Panel, slot_idx: int) -> void:
	var sx: int
	if slot_idx < 13:
		sx = 20 + slot_idx * (_DBG_SW + _DBG_GAP)
	elif slot_idx == 13:
		sx = 20 + 13 * (_DBG_SW + _DBG_GAP) + _DBG_DGAP
	else:
		sx = 20 + 13 * (_DBG_SW + _DBG_GAP) + _DBG_DGAP + (_DBG_SW + _DBG_GAP) + _DBG_DGAP

	var sp := Panel.new()
	sp.position = Vector2(sx, 68)
	sp.size = Vector2(_DBG_SW, _DBG_SH)
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.25, 0.25, 0.25, 0.8)
	sty.border_color = Color(0.45, 0.45, 0.45)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(4)
	sp.add_theme_stylebox_override("panel", sty)

	var st := TextureRect.new()
	st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st.offset_left = 2; st.offset_top = 2; st.offset_right = -2; st.offset_bottom = -2
	st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(st)

	var ci := slot_idx
	sp.gui_input.connect(func(ev: InputEvent) -> void:
		if _is_primary_press(ev):
			_debug_on_slot_click(ci)
	)
	panel.add_child(sp)
	_debug_slot_panels.append(sp)
	_debug_slot_textures.append(st)

func _rinshan_debug_init() -> void:
	_debug_rinshan_tiles.clear()
	for _i in range(8):
		_debug_rinshan_tiles.append({})
	_debug_rinshan_cursor = 0
	var rs: Array = GameState.rinshan
	# rs[-1] = 1st draw, rs[-2] = 2nd draw, ...
	for i in range(min(rs.size(), 8)):
		_debug_rinshan_tiles[i] = rs[rs.size() - 1 - i].duplicate()
	_rinshan_debug_refresh_slots()
	if is_instance_valid(_debug_rinshan_error_label):
		_debug_rinshan_error_label.text = ""

func _rinshan_debug_refresh_slots() -> void:
	for i in range(8):
		if i >= _debug_rinshan_slot_panels.size(): break
		var sp: Panel = _debug_rinshan_slot_panels[i]
		var st: TextureRect = _debug_rinshan_slot_textures[i]
		var tile: Dictionary = _debug_rinshan_tiles[i]
		var tid: int = tile.get("id", 0)
		var sty := StyleBoxFlat.new()
		sty.set_corner_radius_all(4)
		if i == _debug_rinshan_cursor:
			sty.set_border_width_all(3)
			sty.border_color = Color(0.2, 0.9, 1.0)
			sty.bg_color = Color(0.15, 0.35, 0.45, 0.9) if tid == 0 else Color(0.95, 0.92, 0.80)
		elif tid > 0:
			sty.set_border_width_all(2)
			sty.border_color = Color(0.4, 0.3, 0.1)
			sty.bg_color = Color(0.95, 0.92, 0.80)
		else:
			sty.set_border_width_all(2)
			sty.border_color = Color(0.45, 0.45, 0.45)
			sty.bg_color = Color(0.25, 0.25, 0.25, 0.8)
		sp.add_theme_stylebox_override("panel", sty)
		if tid > 0:
			st.texture = _get_tile_texture(tile)
		else:
			st.texture = null

func _rinshan_debug_on_palette_click(tile: Dictionary) -> void:
	if _debug_rinshan_cursor < 8:
		_debug_rinshan_tiles[_debug_rinshan_cursor] = tile
	# 次の空スロットへカーソル移動
	for i in range(_debug_rinshan_cursor + 1, 8):
		if _debug_rinshan_tiles[i].get("id", 0) == 0:
			_debug_rinshan_cursor = i
			_rinshan_debug_refresh_slots()
			return
	for i in range(8):
		if _debug_rinshan_tiles[i].get("id", 0) == 0:
			_debug_rinshan_cursor = i
			_rinshan_debug_refresh_slots()
			return
	_rinshan_debug_refresh_slots()

func _on_rinshan_debug_apply() -> void:
	GameState.debug_set_rinshan(_debug_rinshan_tiles)
	_debug_rinshan_panel.visible = false

func _build_rinshan_debug_panel() -> Panel:
	_debug_rinshan_tiles.clear()
	for _i in range(8):
		_debug_rinshan_tiles.append({})

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(1000, 630)
	panel.position = Vector2(460, 275)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.15, 0.05, 0.97)
	bg.border_color = Color(0.1, 0.9, 0.3)
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", bg)

	var title := Label.new()
	title.text = "嶺上牌デバッグ（F4で閉じる）　①=1回目ツモ → ⑧=8回目ツモ"
	title.position = Vector2(20, 12)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	panel.add_child(title)

	var btn_clear_all := Button.new()
	btn_clear_all.text = "全クリア"
	btn_clear_all.position = Vector2(700, 10)
	btn_clear_all.size = Vector2(120, 36)
	btn_clear_all.add_theme_font_size_override("font_size", 16)
	btn_clear_all.pressed.connect(func() -> void:
		for i in range(8):
			_debug_rinshan_tiles[i] = {}
		_debug_rinshan_cursor = 0
		_rinshan_debug_refresh_slots()
		if is_instance_valid(_debug_rinshan_error_label): _debug_rinshan_error_label.text = ""
	)
	panel.add_child(btn_clear_all)

	var btn_del := Button.new()
	btn_del.text = "選択削除"
	btn_del.position = Vector2(830, 10)
	btn_del.size = Vector2(140, 36)
	btn_del.add_theme_font_size_override("font_size", 16)
	btn_del.pressed.connect(func() -> void:
		if _debug_rinshan_cursor < 8:
			_debug_rinshan_tiles[_debug_rinshan_cursor] = {}
		_rinshan_debug_refresh_slots()
	)
	panel.add_child(btn_del)

	# 8スロット
	var slot_labels := ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧"]
	_debug_rinshan_slot_panels.clear()
	_debug_rinshan_slot_textures.clear()
	for i in range(8):
		var sx: int = 20 + i * (_DBG_SW + _DBG_GAP)
		var lbl_s := Label.new()
		lbl_s.text = slot_labels[i]
		lbl_s.position = Vector2(sx, 50)
		lbl_s.add_theme_font_size_override("font_size", 13)
		lbl_s.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		panel.add_child(lbl_s)
		var sp := Panel.new()
		sp.position = Vector2(sx, 68)
		sp.size = Vector2(_DBG_SW, _DBG_SH)
		sp.mouse_filter = Control.MOUSE_FILTER_STOP
		var sty := StyleBoxFlat.new()
		sty.bg_color = Color(0.25, 0.25, 0.25, 0.8)
		sty.border_color = Color(0.45, 0.45, 0.45)
		sty.set_border_width_all(2)
		sty.set_corner_radius_all(4)
		sp.add_theme_stylebox_override("panel", sty)
		var st := TextureRect.new()
		st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		st.offset_left = 2; st.offset_top = 2; st.offset_right = -2; st.offset_bottom = -2
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.add_child(st)
		var ci := i
		sp.gui_input.connect(func(ev: InputEvent) -> void:
			if _is_primary_press(ev):
				_debug_rinshan_cursor = ci
				_rinshan_debug_refresh_slots()
		)
		panel.add_child(sp)
		_debug_rinshan_slot_panels.append(sp)
		_debug_rinshan_slot_textures.append(st)

	# パレット（手牌デバッグと同じ牌セット）
	var lbl_palette := Label.new()
	lbl_palette.text = "── 牌パレット（クリックで追加・スロットをクリックで選択） ──"
	lbl_palette.position = Vector2(20, 158)
	lbl_palette.add_theme_font_size_override("font_size", 14)
	lbl_palette.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	panel.add_child(lbl_palette)

	for row_i in range(3):
		var row_y: int = 180 + row_i * (_DBG_SH + 8)
		var row_lbl := Label.new()
		row_lbl.text = _DEBUG_ROW_LABELS[row_i]
		row_lbl.position = Vector2(20, row_y + 30)
		row_lbl.add_theme_font_size_override("font_size", 13)
		row_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		panel.add_child(row_lbl)
		var ids: Array = _DEBUG_PALETTE[row_i]
		for col_i in range(ids.size()):
			var pid: int = ids[col_i]
			var tile_dict := {"id": pid}
			var px: int = 100 + col_i * (_DBG_SW + _DBG_GAP)
			var pt := Panel.new()
			pt.position = Vector2(px, row_y)
			pt.size = Vector2(_DBG_SW, _DBG_SH)
			pt.mouse_filter = Control.MOUSE_FILTER_STOP
			var psty := StyleBoxFlat.new()
			psty.bg_color = Color(0.95, 0.92, 0.80)
			psty.border_color = Color(0.4, 0.3, 0.1)
			psty.set_border_width_all(2)
			psty.set_corner_radius_all(4)
			pt.add_theme_stylebox_override("panel", psty)
			var ptex := TextureRect.new()
			ptex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ptex.offset_left = 2; ptex.offset_top = 2; ptex.offset_right = -2; ptex.offset_bottom = -2
			ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ptex.texture = _get_tile_texture(MahjongLogic.make_tile(pid))
			ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pt.add_child(ptex)
			var ctile := tile_dict.duplicate()
			pt.gui_input.connect(func(ev: InputEvent) -> void:
				if _is_primary_press(ev):
					_rinshan_debug_on_palette_click(ctile)
			)
			panel.add_child(pt)

	var special_row_y: int = 180 + 3 * (_DBG_SH + 8)
	var special_lbl := Label.new()
	special_lbl.text = "特殊牌"
	special_lbl.position = Vector2(20, special_row_y + 22)
	special_lbl.add_theme_font_size_override("font_size", 13)
	special_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	panel.add_child(special_lbl)
	var special_names := ["赤5筒", "赤5索", "金8筒", "金8索", "白ポッチ"]
	for col_i in range(_DEBUG_PALETTE_SPECIAL.size()):
		var stile: Dictionary = _DEBUG_PALETTE_SPECIAL[col_i]
		var px: int = 100 + col_i * (_DBG_SW + _DBG_GAP)
		var pt := Panel.new()
		pt.position = Vector2(px, special_row_y)
		pt.size = Vector2(_DBG_SW, _DBG_SH)
		pt.mouse_filter = Control.MOUSE_FILTER_STOP
		var psty := StyleBoxFlat.new()
		psty.bg_color = Color(0.95, 0.92, 0.80)
		psty.border_color = Color(0.8, 0.5, 0.1)
		psty.set_border_width_all(2)
		psty.set_corner_radius_all(4)
		pt.add_theme_stylebox_override("panel", psty)
		var ptex := TextureRect.new()
		ptex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ptex.offset_left = 2; ptex.offset_top = 2; ptex.offset_right = -2; ptex.offset_bottom = -2
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptex.texture = _get_tile_texture(MahjongLogic.make_tile(
			stile.id, stile.get("is_red", false), stile.get("is_gold", false), stile.get("is_haku_pochi", false)
		))
		ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.add_child(ptex)
		var name_lbl := Label.new()
		name_lbl.text = special_names[col_i]
		name_lbl.position = Vector2(0, _DBG_SH - 18)
		name_lbl.size = Vector2(_DBG_SW, 18)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.add_child(name_lbl)
		var cstile := stile.duplicate()
		pt.gui_input.connect(func(ev: InputEvent) -> void:
			if _is_primary_press(ev):
				_rinshan_debug_on_palette_click(cstile)
		)
		panel.add_child(pt)

	var buttons_y: int = 180 + 4 * (_DBG_SH + 8) + 10
	_debug_rinshan_error_label = Label.new()
	_debug_rinshan_error_label.text = ""
	_debug_rinshan_error_label.position = Vector2(20, buttons_y - 22)
	_debug_rinshan_error_label.add_theme_font_size_override("font_size", 15)
	_debug_rinshan_error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	panel.add_child(_debug_rinshan_error_label)

	var btn_apply := Button.new()
	btn_apply.text = "適用"
	btn_apply.position = Vector2(20, buttons_y)
	btn_apply.size = Vector2(160, 50)
	btn_apply.add_theme_font_size_override("font_size", 20)
	btn_apply.pressed.connect(_on_rinshan_debug_apply)
	panel.add_child(btn_apply)

	var btn_close := Button.new()
	btn_close.text = "閉じる"
	btn_close.position = Vector2(200, buttons_y)
	btn_close.size = Vector2(160, 50)
	btn_close.add_theme_font_size_override("font_size", 20)
	btn_close.pressed.connect(func() -> void: _debug_rinshan_panel.visible = false)
	panel.add_child(btn_close)

	return panel

func _build_debug_panel() -> Panel:
	_debug_hand_tiles.clear()
	for _i in range(13):
		_debug_hand_tiles.append({})
	_debug_draw_tile = {}
	_debug_next_draw_tile = {}

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(1000, 630)
	panel.position = Vector2(460, 275)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.15, 0.97)
	bg.border_color = Color(0.9, 0.7, 0.1)
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", bg)

	var title := Label.new()
	title.text = "デバッグモード（F1で閉じる）"
	title.position = Vector2(20, 12)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_debug_title_label = title
	panel.add_child(title)

	var btn_clear_all := Button.new()
	btn_clear_all.text = "全クリア"
	btn_clear_all.position = Vector2(700, 10)
	btn_clear_all.size = Vector2(120, 36)
	btn_clear_all.add_theme_font_size_override("font_size", 16)
	btn_clear_all.pressed.connect(func() -> void:
		for i in range(13):
			_debug_hand_tiles[i] = {}
		_debug_draw_tile = {}
		_debug_next_draw_tile = {}
		_debug_cursor = 0
		_debug_refresh_slots()
		if is_instance_valid(_debug_error_label): _debug_error_label.text = ""
	)
	panel.add_child(btn_clear_all)

	var btn_del := Button.new()
	btn_del.text = "選択削除"
	btn_del.position = Vector2(830, 10)
	btn_del.size = Vector2(140, 36)
	btn_del.add_theme_font_size_override("font_size", 16)
	btn_del.pressed.connect(_debug_clear_cursor_slot)
	panel.add_child(btn_del)

	var lbl_hand := Label.new()
	lbl_hand.text = "手牌 (13枚)"
	lbl_hand.position = Vector2(20, 50)
	lbl_hand.add_theme_font_size_override("font_size", 14)
	lbl_hand.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(lbl_hand)

	var draw_x: int = 20 + 13 * (_DBG_SW + _DBG_GAP) + _DBG_DGAP
	var lbl_draw := Label.new()
	lbl_draw.text = "ツモ牌"
	lbl_draw.position = Vector2(draw_x, 50)
	lbl_draw.add_theme_font_size_override("font_size", 14)
	lbl_draw.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(lbl_draw)

	var next_x: int = draw_x + (_DBG_SW + _DBG_GAP) + _DBG_DGAP
	var lbl_next := Label.new()
	lbl_next.text = "次順ツモ"
	lbl_next.position = Vector2(next_x, 50)
	lbl_next.add_theme_font_size_override("font_size", 14)
	lbl_next.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(lbl_next)

	_debug_slot_panels.clear()
	_debug_slot_textures.clear()
	for i in range(15):
		_debug_make_slot(panel, i)

	var lbl_palette := Label.new()
	lbl_palette.text = "── 牌パレット（クリックで追加・スロットをクリックで選択） ──"
	lbl_palette.position = Vector2(20, 158)
	lbl_palette.add_theme_font_size_override("font_size", 14)
	lbl_palette.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	panel.add_child(lbl_palette)

	for row_i in range(3):
		var row_y: int = 180 + row_i * (_DBG_SH + 8)
		var row_lbl := Label.new()
		row_lbl.text = _DEBUG_ROW_LABELS[row_i]
		row_lbl.position = Vector2(20, row_y + 30)
		row_lbl.add_theme_font_size_override("font_size", 13)
		row_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		panel.add_child(row_lbl)

		var ids: Array = _DEBUG_PALETTE[row_i]
		for col_i in range(ids.size()):
			var pid: int = ids[col_i]
			var tile_dict := {"id": pid}
			var px: int = 100 + col_i * (_DBG_SW + _DBG_GAP)
			var pt := Panel.new()
			pt.position = Vector2(px, row_y)
			pt.size = Vector2(_DBG_SW, _DBG_SH)
			pt.mouse_filter = Control.MOUSE_FILTER_STOP
			var psty := StyleBoxFlat.new()
			psty.bg_color = Color(0.95, 0.92, 0.80)
			psty.border_color = Color(0.4, 0.3, 0.1)
			psty.set_border_width_all(2)
			psty.set_corner_radius_all(4)
			pt.add_theme_stylebox_override("panel", psty)
			var ptex := TextureRect.new()
			ptex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ptex.offset_left = 2; ptex.offset_top = 2; ptex.offset_right = -2; ptex.offset_bottom = -2
			ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ptex.texture = _get_tile_texture(MahjongLogic.make_tile(pid))
			ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pt.add_child(ptex)
			var ctile := tile_dict.duplicate()
			pt.gui_input.connect(func(ev: InputEvent) -> void:
				if _is_primary_press(ev):
					_debug_on_palette_click(ctile)
			)
			panel.add_child(pt)

	# 特殊牌行（赤5筒・赤5索・金8筒・金8索・白ポッチ）
	var special_row_y: int = 180 + 3 * (_DBG_SH + 8)
	var special_lbl := Label.new()
	special_lbl.text = "特殊牌"
	special_lbl.position = Vector2(20, special_row_y + 22)
	special_lbl.add_theme_font_size_override("font_size", 13)
	special_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	panel.add_child(special_lbl)

	var special_names := ["赤5筒", "赤5索", "金8筒", "金8索", "白ポッチ"]
	for col_i in range(_DEBUG_PALETTE_SPECIAL.size()):
		var stile: Dictionary = _DEBUG_PALETTE_SPECIAL[col_i]
		var px: int = 100 + col_i * (_DBG_SW + _DBG_GAP)
		var pt := Panel.new()
		pt.position = Vector2(px, special_row_y)
		pt.size = Vector2(_DBG_SW, _DBG_SH)
		pt.mouse_filter = Control.MOUSE_FILTER_STOP
		var psty := StyleBoxFlat.new()
		psty.bg_color = Color(0.95, 0.92, 0.80)
		psty.border_color = Color(0.8, 0.5, 0.1)
		psty.set_border_width_all(2)
		psty.set_corner_radius_all(4)
		pt.add_theme_stylebox_override("panel", psty)
		var ptex := TextureRect.new()
		ptex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ptex.offset_left = 2; ptex.offset_top = 2; ptex.offset_right = -2; ptex.offset_bottom = -2
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptex.texture = _get_tile_texture(MahjongLogic.make_tile(
			stile.id,
			stile.get("is_red", false),
			stile.get("is_gold", false),
			stile.get("is_haku_pochi", false)
		))
		ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.add_child(ptex)
		# 名前ラベル
		var name_lbl := Label.new()
		name_lbl.text = special_names[col_i]
		name_lbl.position = Vector2(0, _DBG_SH - 18)
		name_lbl.size = Vector2(_DBG_SW, 18)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.add_child(name_lbl)
		var cstile := stile.duplicate()
		pt.gui_input.connect(func(ev: InputEvent) -> void:
			if _is_primary_press(ev):
				_debug_on_palette_click(cstile)
		)
		panel.add_child(pt)

	var buttons_y: int = 180 + 4 * (_DBG_SH + 8) + 10

	_debug_error_label = Label.new()
	_debug_error_label.text = ""
	_debug_error_label.position = Vector2(20, buttons_y - 22)
	_debug_error_label.add_theme_font_size_override("font_size", 15)
	_debug_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	panel.add_child(_debug_error_label)

	var btn_apply := Button.new()
	btn_apply.text = "適用"
	btn_apply.position = Vector2(20, buttons_y)
	btn_apply.size = Vector2(160, 50)
	btn_apply.add_theme_font_size_override("font_size", 20)
	btn_apply.pressed.connect(_on_debug_apply)
	panel.add_child(btn_apply)

	var btn_close := Button.new()
	btn_close.text = "閉じる"
	btn_close.position = Vector2(200, buttons_y)
	btn_close.size = Vector2(160, 50)
	btn_close.add_theme_font_size_override("font_size", 20)
	btn_close.pressed.connect(func() -> void: _debug_panel.visible = false)
	panel.add_child(btn_close)

	return panel

# ============================================================
# UI ヘルパー
# ============================================================
func _make_panel(color: Color, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size     = rect.size
	var style  := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_control_rect(rect: Rect2) -> Control:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	return c

func _make_label(text: String, pos: Vector2, font_size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	return l

func _make_icon_button(icon_path: String) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.flat = true
	if ResourceLoader.exists(icon_path):
		btn.icon = _make_used_rect_texture(icon_path)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return btn

func _make_text_icon_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	btn.focus_mode = Control.FOCUS_NONE
	return btn

func _build_settings_popup() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(1120, 900)
	panel.size = panel.custom_minimum_size
	panel.position = Vector2(400, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.border_color = Color(0.6, 0.5, 0.1)
	style.set_border_width_all(6)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var title_lbl := _make_label("設  定", Vector2(440, 44), 56)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	panel.add_child(title_lbl)

	panel.add_child(_make_label("BGM音量", Vector2(60, 188), 44))
	_bgm_slider = HSlider.new()
	_bgm_slider.min_value = 0.0
	_bgm_slider.max_value = 1.0
	_bgm_slider.step = 0.05
	_bgm_slider.position = Vector2(380, 196)
	_bgm_slider.size = Vector2(640, 60)
	_bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	panel.add_child(_bgm_slider)

	panel.add_child(_make_label("SE音量", Vector2(60, 308), 44))
	_se_slider = HSlider.new()
	_se_slider.min_value = 0.0
	_se_slider.max_value = 1.0
	_se_slider.step = 0.05
	_se_slider.position = Vector2(380, 316)
	_se_slider.size = Vector2(640, 60)
	_se_slider.value_changed.connect(_on_se_slider_changed)
	panel.add_child(_se_slider)

	panel.add_child(_make_label("打牌アシスト", Vector2(60, 440), 44))
	_assist_mode_option = OptionButton.new()
	_assist_mode_option.position = Vector2(380, 432)
	_assist_mode_option.size = Vector2(640, 84)
	_assist_mode_option.add_theme_font_size_override("font_size", 36)
	_assist_mode_option.add_item("OFF", 0)
	_assist_mode_option.add_item("★だけ表示", 1)
	_assist_mode_option.add_item("★＋左パネル常時表示", 2)
	_assist_mode_option.get_popup().add_theme_font_size_override("font_size", 36)
	_assist_mode_option.item_selected.connect(_on_assist_mode_selected)
	panel.add_child(_assist_mode_option)

	panel.add_child(_make_label("リーチ演出", Vector2(60, 582), 44))
	_reach_cutin_btn = _make_button("", Color(0.2, 0.3, 0.6))
	_reach_cutin_btn.position = Vector2(520, 556)
	_reach_cutin_btn.custom_minimum_size = Vector2(198, 87)
	_reach_cutin_btn.size = _reach_cutin_btn.custom_minimum_size
	_reach_cutin_btn.focus_mode = Control.FOCUS_NONE
	_reach_cutin_btn.pressed.connect(_on_reach_cutin_toggle_pressed)
	panel.add_child(_reach_cutin_btn)
	_reach_cutin_knob = Panel.new()
	_reach_cutin_knob.size = Vector2(81, 81)
	_reach_cutin_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reach_cutin_btn.add_child(_reach_cutin_knob)
	_reach_cutin_knob_label = Label.new()
	_reach_cutin_knob_label.size = _reach_cutin_knob.size
	_reach_cutin_knob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reach_cutin_knob_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reach_cutin_knob_label.add_theme_font_size_override("font_size", 24)
	_reach_cutin_knob_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reach_cutin_knob.add_child(_reach_cutin_knob_label)
	_refresh_reach_cutin_toggle_button()

	var btn_close := _make_button("閉じる", Color(0.35, 0.35, 0.35))
	btn_close.position = Vector2(410, 728)
	btn_close.custom_minimum_size = Vector2(300, 100)
	btn_close.size = btn_close.custom_minimum_size
	btn_close.add_theme_font_size_override("font_size", 40)
	btn_close.pressed.connect(_on_settings_close_pressed)
	panel.add_child(btn_close)

	return panel

func _build_home_confirm_popup() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(580, 240)
	panel.position = Vector2(670, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.border_color = Color(0.6, 0.5, 0.1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	panel.add_child(_make_label("ゲームを中断してメニューへ\n戻りますか？", Vector2(90, 40), 26))

	var btn_yes := _make_button("はい", Color(0.65, 0.2, 0.2))
	btn_yes.position = Vector2(70, 160)
	btn_yes.custom_minimum_size = Vector2(180, 55)
	btn_yes.pressed.connect(_on_home_confirm_yes_pressed)
	panel.add_child(btn_yes)

	var btn_no := _make_button("いいえ", Color(0.25, 0.35, 0.55))
	btn_no.position = Vector2(330, 160)
	btn_no.custom_minimum_size = Vector2(180, 55)
	btn_no.pressed.connect(_on_home_confirm_no_pressed)
	panel.add_child(btn_no)

	return panel

func _build_rules_popup() -> Panel:
	var panel := _make_panel(Color(0.07, 0.08, 0.12, 0.96), Rect2(250, 90, 1420, 900))
	panel.z_index = 120
	var title := _make_label("ルール表", Vector2(36, 24), 50)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	panel.add_child(title)
	var btn_close := _make_button("閉じる", Color(0.35, 0.25, 0.25))
	btn_close.position = Vector2(1240, 28)
	btn_close.custom_minimum_size = Vector2(130, 58)
	btn_close.pressed.connect(func(): _rules_popup.visible = false)
	panel.add_child(btn_close)
	_rules_tab_buttons.clear()
	var tab_x := 36.0
	var tabs: Array = RULE_BOOK.tabs()
	for i in range(tabs.size()):
		var tab: Dictionary = tabs[i]
		var btn := _make_button(str(tab.get("title", "")), Color(0.18, 0.24, 0.34))
		btn.position = Vector2(tab_x, 104)
		btn.custom_minimum_size = Vector2(150, 56)
		btn.add_theme_font_size_override("font_size", 30)
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

# ============================================================
# 設定・ホームアイコン シグナルハンドラ
# ============================================================
func _on_settings_icon_pressed() -> void:
	_bgm_slider.value = AudioManager.bgm_volume
	_se_slider.value  = AudioManager.se_volume
	_assist_mode_option.select(SaveData.assist_mode)
	_refresh_reach_cutin_toggle_button()
	_settings_popup.visible = true

func _on_rules_icon_pressed() -> void:
	_rules_popup.visible = true
	_select_rule_tab(0)

func _on_bgm_slider_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)

func _on_se_slider_changed(value: float) -> void:
	AudioManager.set_se_volume(value)

func _on_assist_mode_selected(index: int) -> void:
	SaveData.assist_mode = int(_assist_mode_option.get_item_id(index))
	if SaveData.assist_mode > 0:
		SaveData.assist_enabled = true
	SaveData.save_data()
	_refresh_assist_toggle_button()
	call_deferred("_refresh_auto_assist")

func _on_reach_cutin_toggle_pressed() -> void:
	SaveData.reach_cutin_enabled = not SaveData.reach_cutin_enabled
	SaveData.save_data()
	_refresh_reach_cutin_toggle_button()

func _refresh_reach_cutin_toggle_button() -> void:
	if _reach_cutin_btn == null:
		return
	var is_on: bool = SaveData.reach_cutin_enabled
	_reach_cutin_btn.text = ""
	_reach_cutin_btn.tooltip_text = "リーチ演出 ON" if is_on else "リーチ演出 OFF"
	var base_color := Color(0.18, 0.72, 0.42) if is_on else Color(0.35, 0.35, 0.35)
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(44)
	style.set_content_margin_all(0)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.12)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.18)
	_reach_cutin_btn.add_theme_stylebox_override("normal", style)
	_reach_cutin_btn.add_theme_stylebox_override("hover", hover)
	_reach_cutin_btn.add_theme_stylebox_override("pressed", pressed)
	if _reach_cutin_knob != null:
		_reach_cutin_knob.position = Vector2(114, 3) if is_on else Vector2(3, 3)
		var knob_style := StyleBoxFlat.new()
		knob_style.bg_color = Color(0.95, 1.0, 0.94) if is_on else Color(0.88, 0.88, 0.88)
		knob_style.set_corner_radius_all(41)
		knob_style.shadow_color = Color(0, 0, 0, 0.28)
		knob_style.shadow_size = 6
		_reach_cutin_knob.add_theme_stylebox_override("panel", knob_style)
	if _reach_cutin_knob_label != null:
		_reach_cutin_knob_label.text = "ON" if is_on else "OFF"
		_reach_cutin_knob_label.add_theme_color_override("font_color", Color(0.07, 0.36, 0.18) if is_on else Color(0.24, 0.24, 0.24))

func _on_settings_close_pressed() -> void:
	SaveData.bgm_volume = AudioManager.bgm_volume
	SaveData.se_volume  = AudioManager.se_volume
	SaveData.assist_mode = _assist_mode_option.get_selected_id()
	SaveData.save_data()
	_settings_popup.visible = false

func _on_home_icon_pressed() -> void:
	_home_confirm_popup.visible = true

func _on_home_confirm_yes_pressed() -> void:
	_home_confirm_popup.visible = false
	get_tree().change_scene_to_file("res://Menu.tscn")

func _on_home_confirm_no_pressed() -> void:
	_home_confirm_popup.visible = false

func _make_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left     = 5
	style.corner_radius_top_right    = 5
	style.corner_radius_bottom_left  = 5
	style.corner_radius_bottom_right = 5
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = bg_color.lightened(0.15)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = bg_color.darkened(0.2)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.35)
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    hover_style)
	btn.add_theme_stylebox_override("pressed",  pressed_style)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return btn

func _is_primary_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false

# ============================================================
# アシスト機能
# ============================================================

func _build_assist_dead_tiles() -> Dictionary:
	var counts := {}
	var red    := {}
	var gold   := {}
	for p in GameState.players:
		for tile: Dictionary in p.discards:
			var did: int = tile.id
			counts[did] = counts.get(did, 0) + 1
			if tile.get("is_red", false):
				red[did] = red.get(did, 0) + 1
			if tile.get("is_gold", false):
				gold[did] = gold.get(did, 0) + 1
		for meld in p.naki:
			for tile: Dictionary in meld.get("tiles", []):
				var mid: int = tile.id
				counts[mid] = counts.get(mid, 0) + 1
	return {"counts": counts, "red": red, "gold": gold}


func _show_assist_loading() -> void:
	_assist_visible = true
	_clear_assist_stars()
	for ch in _assist_panel.get_children():
		ch.queue_free()

	var title := _make_label("─ アシスト ─", Vector2(10, 10), 24)
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_assist_panel.add_child(title)

	var loading := _make_label("解析中...", Vector2(10, 60), 32)
	loading.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	_assist_panel.add_child(loading)

	_assist_panel.visible = true


func _on_assist_pressed() -> void:
	var is_on: bool = SaveData.assist_enabled and SaveData.assist_mode > 0
	SaveData.assist_enabled = not is_on
	if SaveData.assist_enabled and SaveData.assist_mode == 0:
		SaveData.assist_mode = 1
		if _assist_mode_option != null:
			_assist_mode_option.select(1)
	SaveData.save_data()
	_refresh_assist_toggle_button()
	_refresh_auto_assist()

func _refresh_auto_assist() -> void:
	_assist_request_serial += 1
	_clear_assist_stars()
	if _assist_panel != null:
		_assist_panel.visible = false
	if not _can_show_auto_assist():
		return
	if _assist_analyzer == null:
		_assist_analyzer = SanmaAnalyzer.new()
	var hand: Array = GameState.players[0].hand
	var dead_tiles := _assist_cached_dead_tiles if _assist_cache_ready else _build_assist_dead_tiles()
	var total_wall := _assist_cached_total_wall if _assist_cache_ready else GameState.wall.size()
	var meld_count: int = GameState.players[0].naki.size()
	var request_id := _assist_request_serial
	_run_auto_assist_deferred.call_deferred(request_id, hand, dead_tiles, total_wall, meld_count)

func _run_auto_assist_deferred(request_id: int, hand: Array, dead_tiles: Dictionary, total_wall: int, meld_count: int) -> void:
	await get_tree().process_frame
	if request_id != _assist_request_serial:
		return
	if not _can_show_auto_assist():
		return
	var results := _assist_analyzer.evaluate_discards(hand, total_wall, dead_tiles, meld_count)
	results = _apply_tiebreak_priority(results)
	if results.is_empty():
		return
	if SaveData.assist_mode >= 2:
		_show_assist(results, hand)
	else:
		_place_assist_star(hand, int(results[0].get("tile_id", -1)))

func _can_show_auto_assist() -> bool:
	if not SaveData.assist_enabled or SaveData.assist_mode <= 0:
		return false
	return _can_show_assist_toggle()

func _can_show_assist_toggle() -> bool:
	if GameState.players.is_empty() or GameState.current_player != 0:
		return false
	if GameState.phase != GameState.Phase.PLAYER_TURN:
		return false
	if _riichi_mode or _pon_select_mode or _kan_select_mode or _riichi_cutin_running:
		return false
	var hand: Array = GameState.players[0].hand
	if hand.size() < 2 or hand.size() % 3 != 2:
		return false
	if GameState.players[0].is_riichi:
		return false
	return true

func _run_manual_assist_panel() -> void:
	var hand: Array = GameState.players[0].hand
	if hand.size() < 2 or hand.size() % 3 != 2:
		return
	if _assist_analyzer == null:
		_assist_analyzer = SanmaAnalyzer.new()
	var dead_tiles := _assist_cached_dead_tiles if _assist_cache_ready else _build_assist_dead_tiles()
	var total_wall := _assist_cached_total_wall if _assist_cache_ready else GameState.wall.size()
	var meld_count: int = GameState.players[0].naki.size()
	_show_assist_loading()
	await get_tree().create_timer(0.05).timeout
	_run_assist_analysis(hand, dead_tiles, total_wall, meld_count)

func _run_assist_analysis(hand: Array, dead_tiles: Dictionary, total_wall: int, meld_count: int = 0) -> void:
	var results := _assist_analyzer.evaluate_discards(hand, total_wall, dead_tiles, meld_count)
	results = _apply_tiebreak_priority(results)
	_show_assist(results, hand)


func _show_assist(results: Array, hand: Array) -> void:
	_assist_visible = true
	for lbl in _assist_star_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_assist_star_labels.clear()
	for ch in _assist_panel.get_children():
		ch.queue_free()
	var assist_title := _make_label("─ アシスト ─", Vector2(10, 10), 24)
	assist_title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_assist_panel.add_child(assist_title)

	var top3 := results.slice(0, mini(3, results.size()))
	var best_tile_id: int = int(top3[0].get("tile_id", -1)) if top3.size() > 0 else -1

	var py := 46.0
	for i in range(top3.size()):
		var r: Dictionary = top3[i]
		var is_best: bool = (i == 0)
		var shanten_val: int = int(r.get("shanten", 99))

		var row_h: float
		if is_best:
			if shanten_val == 0:
				row_h = 310.0
			elif shanten_val <= 2:
				row_h = 355.0
			else:
				row_h = 270.0
		else:
			row_h = 270.0

		var row := Panel.new()
		row.position = Vector2(8, py)
		row.custom_minimum_size = Vector2(444, row_h)
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.10, 0.22, 0.12, 0.92) if is_best else Color(0.05, 0.12, 0.07, 0.85)
		if is_best:
			rs.set_border_width_all(2)
			rs.border_color = Color(0.4, 0.9, 0.4, 0.7)
		rs.set_corner_radius_all(5)
		row.add_theme_stylebox_override("panel", rs)
		_assist_panel.add_child(row)

		var dummy := {"id": int(r.get("tile_id", -1)), "is_red": false, "is_gold": false, "is_haku_pochi": false}
		var tex := _get_tile_texture(dummy)
		if tex:
			var ti := TextureRect.new()
			ti.position = Vector2(6, 6)
			ti.size = Vector2(66, 90)
			ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ti.texture = tex
			row.add_child(ti)

		if is_best:
			var star := _make_label("★", Vector2(76, 6), 36)
			star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			row.add_child(star)

		var name_lbl := _make_label(str(r.get("tile_name", "")), Vector2(100, 6), 32)
		row.add_child(name_lbl)
		var shan_lbl := _make_label(str(r.get("shanten_text", "")), Vector2(100, 44), 26)
		shan_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if shanten_val == 0 else Color(0.80, 0.80, 0.65))
		row.add_child(shan_lbl)

		var eff_raw: int = int(r.get("effective_count", 0))
		var eff_exp: float = float(r.get("effective_count_expected", 0.0))
		var ntr: float = float(r.get("next_tenpai_rate", 0.0)) * 100.0
		var eff_lbl := _make_label(
			"有効%d枚（期待%.1f枚）" % [eff_raw, eff_exp],
			Vector2(6, 100), 30)
		eff_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		row.add_child(eff_lbl)

		var next_label := _next_turn_label(shanten_val)
		var ntr_lbl := _make_label(
			"%s %.2f%%" % [next_label, ntr],
			Vector2(6, 154), 30)
		ntr_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		row.add_child(ntr_lbl)

		if is_best:
			var tenpai_r: float = float(r.get("tenpai_rate", -1.0))
			var agari_r: float  = float(r.get("agari_rate",  -1.0))
			if shanten_val == 0 and agari_r >= 0.0:
				var agari_lbl := _make_label("和了率 %.2f%%" % (agari_r * 100.0), Vector2(6, 200), 30)
				agari_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				row.add_child(agari_lbl)
			elif shanten_val == 1 and agari_r >= 0.0:
				var agari_lbl := _make_label("和了率 %.2f%%" % (agari_r * 100.0), Vector2(6, 200), 30)
				agari_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				row.add_child(agari_lbl)
			elif shanten_val == 2 and tenpai_r >= 0.0:
				var reach_lbl := _make_label("一向聴率 %.2f%%" % (tenpai_r * 100.0), Vector2(6, 200), 30)
				reach_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				row.add_child(reach_lbl)
				if agari_r >= 0.0:
					var tenpai_lbl := _make_label("テンパイ率 %.2f%%" % (agari_r * 100.0), Vector2(6, 244), 30)
					tenpai_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
					row.add_child(tenpai_lbl)

		# 有効牌画像のy座標（確率表示と被らないよう調整）
		var eff_y := 210.0
		if is_best:
			if shanten_val == 0:
				eff_y = 255.0
			elif shanten_val <= 2:
				eff_y = 300.0

		var ex := 6.0
		var eff: Dictionary = r.get("effective_tiles", {})
		for gid: int in eff:
			var eff_count: int = int(eff[gid])
			var is_zero_wait := eff_count <= 0
			var etex := _get_tile_texture({"id": gid, "is_red": false, "is_gold": false, "is_haku_pochi": false})
			if etex:
				var eti := TextureRect.new()
				eti.position = Vector2(ex, eff_y)
				eti.size = Vector2(33, 45)
				eti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				eti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				eti.texture = etex
				if is_zero_wait:
					eti.modulate = Color(0.42, 0.42, 0.42, 0.75)
				row.add_child(eti)
			var ecnt := _make_label("×%d" % eff_count, Vector2(ex + 36, eff_y + 12), 22)
			ecnt.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45) if is_zero_wait else Color(0.7, 0.8, 0.7))
			row.add_child(ecnt)
			ex += 65.0
			if ex > 390:
				break
		py += row_h + 8.0

	_place_assist_star(hand, best_tile_id)
	_assist_panel.visible = true


func _hide_assist() -> void:
	_assist_request_serial += 1
	_assist_visible = false
	_assist_cache_ready = false
	if _assist_panel != null:
		_assist_panel.visible = false
	_clear_assist_stars()

func _clear_assist_stars() -> void:
	for lbl in _assist_star_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_assist_star_labels.clear()

func _refresh_assist_toggle_button() -> void:
	if _assist_btn == null:
		return
	var is_on: bool = SaveData.assist_enabled and SaveData.assist_mode > 0
	_assist_btn.text = ""
	_assist_btn.tooltip_text = "打牌アシスト ON" if is_on else "打牌アシスト OFF"
	var base_color := Color(0.18, 0.72, 0.42) if is_on else Color(0.35, 0.35, 0.35)
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(44)
	style.set_content_margin_all(0)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.12)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.18)
	_assist_btn.add_theme_stylebox_override("normal", style)
	_assist_btn.add_theme_stylebox_override("hover", hover)
	_assist_btn.add_theme_stylebox_override("pressed", pressed)
	_assist_btn.add_theme_color_override("font_color", Color.WHITE)
	if _assist_mode_label != null:
		_assist_mode_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.58) if is_on else Color(0.78, 0.82, 0.80))
	if _assist_toggle_knob != null:
		_assist_toggle_knob.position = Vector2(114, 3) if is_on else Vector2(3, 3)
		var knob_style := StyleBoxFlat.new()
		knob_style.bg_color = Color(0.95, 1.0, 0.94) if is_on else Color(0.88, 0.88, 0.88)
		knob_style.set_corner_radius_all(41)
		knob_style.shadow_color = Color(0, 0, 0, 0.28)
		knob_style.shadow_size = 6
		_assist_toggle_knob.add_theme_stylebox_override("panel", knob_style)
	if _assist_toggle_knob_label != null:
		_assist_toggle_knob_label.text = "ON" if is_on else "OFF"
		_assist_toggle_knob_label.add_theme_color_override("font_color", Color(0.07, 0.36, 0.18) if is_on else Color(0.24, 0.24, 0.24))

func _set_assist_toggle_visible(visible: bool) -> void:
	if _assist_btn != null:
		_assist_btn.visible = visible
	if _assist_mode_label != null:
		_assist_mode_label.visible = visible


func _place_assist_star(hand: Array, best_tile_id: int) -> void:
	var sort_count := hand.size() - 1 if (_player_drew and hand.size() >= 2) else hand.size()
	var display_indices := range(sort_count)
	display_indices.sort_custom(func(a: int, b: int) -> bool:
		return _tile_sort_key(hand[a]) < _tile_sort_key(hand[b])
	)
	if _player_drew and hand.size() >= 2:
		display_indices.append(hand.size() - 1)

	for i in range(mini(_tile_buttons.size(), display_indices.size())):
		var orig_idx: int = display_indices[i]
		if hand[orig_idx].id == best_tile_id:
			var btn = _tile_buttons[i]
			var star := Label.new()
			star.text = "★"
			star.add_theme_font_size_override("font_size", 40)
			star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			star.position = Vector2(btn.size.x / 2.0 - 20, -44)
			star.z_index = 10
			btn.add_child(star)
			_assist_star_labels.append(star)
			break


func _next_turn_label(shanten: int) -> String:
	match shanten:
		0: return "次巡和了確率"
		1: return "次巡聴牌確率"
		2: return "次巡一向聴確率"
		_: return "次巡繰り上げ確率"


func _apply_tiebreak_priority(results: Array) -> Array:
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.shanten != b.shanten:
			return a.shanten < b.shanten
		if a.effective_count != b.effective_count:
			return a.effective_count > b.effective_count
		if abs(float(a.next_tenpai_rate) - float(b.next_tenpai_rate)) > 0.001:
			return float(a.next_tenpai_rate) > float(b.next_tenpai_rate)
		return _tile_discard_priority(int(a.tile_id)) > _tile_discard_priority(int(b.tile_id))
	)
	return results


func _tile_discard_priority(tile_id: int) -> int:
	var rw: int = GameState.round_wind
	var is_dealer: bool = (GameState.dealer == 0)
	var self_wind: int = GameState.players[0].wind  # 牌ID (41=東, 42=南, 43=西)

	match tile_id:
		11, 19:  # 1m, 9m
			return 60
		41:  # 東
			if rw == MahjongLogic.EAST:
				return 20 if is_dealer else 30
			else:
				return 80  # 南場では客風
		42:  # 南
			if rw == MahjongLogic.EAST:
				if is_dealer: return 90
				return 10 if self_wind == 42 else 80
			else:
				if is_dealer: return 40
				return 10 if self_wind == 42 else 40
		43:  # 西
			if rw == MahjongLogic.EAST:
				return 10 if self_wind == 43 else 80
			else:
				if is_dealer: return 80
				return 10 if self_wind == 43 else 70
		44:  # 北
			return 5
		45, 46, 47:  # 白発中
			return 40
		21: return 55  # 1p
		29: return 50  # 9p
		22: return 45  # 2p
		28: return 42  # 8p
		23: return 38  # 3p
		27: return 35  # 7p
		24: return 30  # 4p
		26: return 25  # 6p
		25: return 20  # 5p
		31: return 55  # 1s
		39: return 50  # 9s
		32: return 45  # 2s
		38: return 42  # 8s
		33: return 38  # 3s
		37: return 35  # 7s
		34: return 30  # 4s
		36: return 25  # 6s
		35: return 20  # 5s
	return 0


func _apply_button_image(btn: Button, icon_path: String, tooltip: String) -> void:
	btn.text = ""
	btn.tooltip_text = tooltip
	btn.icon = load(icon_path)
	btn.set("expand_icon", true)
	btn.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER)
	btn.set("vertical_icon_alignment", VERTICAL_ALIGNMENT_CENTER)
	btn.add_theme_constant_override("icon_max_width", 0)

	var transparent := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", transparent)
	btn.add_theme_stylebox_override("hover", transparent)
	btn.add_theme_stylebox_override("pressed", transparent)
	btn.add_theme_stylebox_override("disabled", transparent)
	btn.add_theme_stylebox_override("focus", transparent)
	btn.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("icon_pressed_color", Color(0.85, 0.85, 0.85, 1))
	btn.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
