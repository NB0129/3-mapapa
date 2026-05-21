extends Control

func _ready() -> void:
	_build_ui()
	AudioManager.play_bgm("bgm_title.wav")

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	var bg_tex: Texture2D = load("res://assets/bg/papataitle.webp")
	var scaled_w: float = bg_tex.get_width() * (1080.0 / bg_tex.get_height())
	bg.position = Vector2((1920.0 - scaled_w) / 2.0, 0.0)
	bg.size = Vector2(scaled_w, 1080.0)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = bg_tex
	add_child(bg)

	var btn_start := _make_button("ゲームスタート", Color(0.2, 0.5, 0.2))
	btn_start.position = Vector2(760, 500)
	btn_start.custom_minimum_size = Vector2(400, 70)
	btn_start.add_theme_font_size_override("font_size", 32)
	btn_start.pressed.connect(func(): get_tree().change_scene_to_file("res://Menu.tscn"))
	add_child(btn_start)

func _make_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   style)
	btn.add_theme_stylebox_override("pressed", style)
	return btn
