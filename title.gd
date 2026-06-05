extends Control

func _ready() -> void:
	_build_ui()
	AudioManager.play_bgm("bgm_title.ogg")

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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var tap_lbl := Label.new()
	tap_lbl.text = "画面をタップ"
	tap_lbl.add_theme_font_size_override("font_size", 48)
	tap_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tap_lbl.position = Vector2(660, 510)
	tap_lbl.size = Vector2(600, 60)
	add_child(tap_lbl)

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(tap_lbl, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tap_lbl, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_IN_OUT)

	var touch_area := Button.new()
	touch_area.position = Vector2(0, 0)
	touch_area.size = Vector2(1920, 1080)
	touch_area.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	touch_area.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	touch_area.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	touch_area.pressed.connect(func(): get_tree().change_scene_to_file("res://Menu.tscn"))
	add_child(touch_area)
