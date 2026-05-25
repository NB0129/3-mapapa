extends CanvasLayer

signal cutin_finished

const REACH_STICK_PATH := "res://ui/ritibo.webp"
const KATTOIN_BASE_PATH := "res://ui/kattoin2.webp"
const KATTOIN_SCROLL_PATH := "res://ui/kattoin2a.webp"
const REACH_STICK_TILT_PATH := "res://ui/ritibo_ztilt_half_shadow/ritibo_ztilt_half_shadow_%02d.webp"
const BAND_W := 1052.0
const BAND_X := (1920.0 - BAND_W) * 0.5
const BAND_H := 1080.0
const STICK_CENTER_ROTATION := 8.0
const CUTIN_HOLD_SEC := 3.0
const CUTIN_FADE_END_SEC := 3.18
const STICK_LAND_SEC := 3.5

@onready var band_root: Control = $BandRoot
@onready var reveal_clip: Control = $BandRoot/RevealClip
@onready var base_background: TextureRect = $BandRoot/RevealClip/BaseBackground
@onready var scroll_root: Control = $BandRoot/RevealClip/ScrollRoot
@onready var kattoin_scrolls: Array[TextureRect] = [
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollA,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollB,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollC,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollD,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollE,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollF,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollG,
	$BandRoot/RevealClip/ScrollRoot/KattoinScrollH,
]
@onready var character_sprite: TextureRect = $BandRoot/RevealClip/CharacterSprite
@onready var white_frame_left: ColorRect = $BandRoot/WhiteFrameLeft
@onready var white_frame_right: ColorRect = $BandRoot/WhiteFrameRight
@onready var reach_stick_sprite: Sprite2D = $ReachStickSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var stick_frame_index: int = 0:
	set(value):
		stick_frame_index = clampi(value, 0, max(0, _stick_frames.size() - 1))
		_apply_stick_frame()

var _stick_frames: Array[Texture2D] = []
var _reach_stick_texture: Texture2D

func _ready() -> void:
	visible = false
	_setup_animation(Vector2(960, 540))

func play_cutin(character_path: String, target_position: Vector2) -> void:
	visible = true
	character_sprite.texture = _load_texture_resource_or_file(character_path)
	base_background.texture = _load_texture_resource_or_file(KATTOIN_BASE_PATH)
	var scroll_tex: Texture2D = _load_texture_resource_or_file(KATTOIN_SCROLL_PATH)
	var add_material := CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for scroll: TextureRect in kattoin_scrolls:
		scroll.texture = scroll_tex
		scroll.material = add_material
	_load_stick_frames()
	_reach_stick_texture = _load_texture_resource_or_file(REACH_STICK_PATH)
	stick_frame_index = 0
	_setup_animation(target_position)
	animation_player.play("reach_cutin")
	await animation_player.animation_finished
	visible = false
	emit_signal("cutin_finished")

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

func _load_stick_frames() -> void:
	if not _stick_frames.is_empty():
		return
	for i in range(2, 21):
		var texture: Texture2D = _load_texture_resource_or_file(REACH_STICK_TILT_PATH % i)
		if texture != null:
			_stick_frames.append(texture)

func _apply_stick_frame() -> void:
	if reach_stick_sprite == null:
		return
	if stick_frame_index >= 0 and stick_frame_index < _stick_frames.size():
		reach_stick_sprite.texture = _stick_frames[stick_frame_index]

func _setup_animation(target_position: Vector2) -> void:
	if animation_player.has_animation("reach_cutin"):
		animation_player.remove_animation_library("")
	var anim: Animation = Animation.new()
	anim.length = STICK_LAND_SEC
	anim.loop_mode = Animation.LOOP_NONE

	_add_track(anim, "BandRoot:position", [
		[0.00, Vector2(BAND_X, BAND_H)],
		[0.10, Vector2(BAND_X, 0)],
		[CUTIN_HOLD_SEC, Vector2(BAND_X, 0)],
	])
	_add_track(anim, "BandRoot:modulate", [
		[0.00, Color(1, 1, 1, 1.0)],
		[CUTIN_HOLD_SEC, Color(1, 1, 1, 1.0)],
		[CUTIN_FADE_END_SEC, Color(1, 1, 1, 0.0)],
	])

	_add_track(anim, "BandRoot/RevealClip:position", [
		[0.00, Vector2(0, 0)],
		[CUTIN_HOLD_SEC, Vector2(0, 0)],
	])
	_add_track(anim, "BandRoot/RevealClip:size", [
		[0.00, Vector2(BAND_W, BAND_H)],
		[CUTIN_HOLD_SEC, Vector2(BAND_W, BAND_H)],
	])
	_add_track(anim, "BandRoot/RevealClip/ScrollRoot:position", [
		[0.00, Vector2(0, 0)],
		[CUTIN_HOLD_SEC, Vector2(0, -BAND_H * 7.0)],
	])
	_add_track(anim, "BandRoot/RevealClip/BaseBackground:modulate", [
		[0.00, Color(1, 1, 1, 0.0)],
		[0.08, Color(1, 1, 1, 1.0)],
		[CUTIN_HOLD_SEC, Color(1, 1, 1, 1.0)],
		[CUTIN_FADE_END_SEC, Color(1, 1, 1, 0.0)],
	])
	_add_track(anim, "BandRoot/RevealClip/ScrollRoot:modulate", [
		[0.00, Color(1, 1, 1, 0.0)],
		[0.08, Color(1, 1, 1, 1.0)],
		[CUTIN_HOLD_SEC, Color(1, 1, 1, 1.0)],
		[CUTIN_FADE_END_SEC, Color(1, 1, 1, 0.0)],
	])
	_add_track(anim, "BandRoot/RevealClip/CharacterSprite:position", [
		[0.00, Vector2(-964, -1240)],
		[CUTIN_HOLD_SEC, Vector2(-964, -1290)],
	])
	_add_track(anim, "BandRoot/RevealClip/CharacterSprite:modulate", [
		[0.00, Color(1, 1, 1, 0.0)],
		[0.08, Color(1, 1, 1, 1.0)],
		[CUTIN_HOLD_SEC, Color(1, 1, 1, 1.0)],
		[CUTIN_FADE_END_SEC, Color(1, 1, 1, 0.0)],
	])

	_add_track(anim, "ReachStickSprite:position", [
		[0.00, Vector2(960, 540)],
		[CUTIN_HOLD_SEC, Vector2(960, 540)],
		[STICK_LAND_SEC, target_position],
	])
	_add_track(anim, "ReachStickSprite:scale", [
		[0.00, Vector2(1.155, 1.155)],
		[0.24, Vector2(1.155, 1.155)],
		[CUTIN_HOLD_SEC, Vector2(1.65, 1.65)],
		[STICK_LAND_SEC, Vector2(0.28, 0.28)],
	])
	_add_track(anim, "ReachStickSprite:rotation", [
		[0.00, deg_to_rad(0.0)],
		[CUTIN_HOLD_SEC, deg_to_rad(STICK_CENTER_ROTATION)],
		[STICK_LAND_SEC, deg_to_rad(STICK_CENTER_ROTATION + 1080.0)],
	])
	_add_track(anim, "ReachStickSprite:modulate", [
		[0.00, Color(1, 1, 1, 0.0)],
		[0.25, Color(1, 1, 1, 1.0)],
		[STICK_LAND_SEC, Color(1, 1, 1, 1.0)],
	])
	var stick_frame_keys: Array = [[0.00, 0], [0.25, 0]]
	for i in range(19):
		var t := 0.25 + ((CUTIN_HOLD_SEC - 0.40) * float(i) / 18.0)
		stick_frame_keys.append([t, i])
	stick_frame_keys.append([CUTIN_HOLD_SEC, 18])
	_add_discrete_track(anim, ".:stick_frame_index", stick_frame_keys)
	_add_discrete_track(anim, "ReachStickSprite:texture", [
		[CUTIN_HOLD_SEC, _reach_stick_texture],
	])

	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("reach_cutin", anim)
	animation_player.add_animation_library("", library)

func _add_track(anim: Animation, path: String, keys: Array) -> void:
	var idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(path))
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		anim.track_insert_key(idx, float(key[0]), key[1])

func _add_discrete_track(anim: Animation, path: String, keys: Array) -> void:
	var idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(path))
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(idx, Animation.UPDATE_DISCRETE)
	for key in keys:
		anim.track_insert_key(idx, float(key[0]), key[1])
