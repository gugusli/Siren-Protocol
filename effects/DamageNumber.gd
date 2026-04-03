extends Label

## Número de daño flotante pooleable (GDD §11.3).
## VFXManager llama play() y al terminar el tween se devuelve al pool.

const FLOAT_HEIGHT := 50.0
const FADE_DELAY := 0.3
const FADE_DURATION := 0.4
const ANIM_DURATION := 0.6
const OUTLINE_SIZE := 3
const FONT_MONO := "res://assets/fonts/Roboto_Mono/static/RobotoMono-Regular.ttf"

var _in_pool := false

func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font_mono := load(FONT_MONO) as FontFile
	if font_mono:
		add_theme_font_override("font", font_mono)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)
	z_index = 100
	set_process(false)

func restart_for_reuse() -> void:
	_in_pool = false
	modulate.a = 1.0
	visible = true

func play(damage_text: String, pos: Vector2, color: Color, font_size: int, scale_mult: float = 1.0, add_exclaim: bool = false) -> void:
	text = damage_text
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	global_position = pos + Vector2(randf_range(-10, 10), -20)
	scale = Vector2(scale_mult, scale_mult)
	modulate.a = 1.0
	visible = true

	var tree := get_tree()
	if not tree:
		_release()
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - FLOAT_HEIGHT, ANIM_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_delay(FADE_DELAY)
	if add_exclaim:
		var st: Tween = create_tween()
		st.tween_property(self, "scale", Vector2(scale_mult * 1.3, scale_mult * 1.3), 0.1)
		st.tween_property(self, "scale", Vector2(scale_mult, scale_mult), 0.15)
	tween.chain().tween_callback(_release)

func _release() -> void:
	if _in_pool:
		return
	_in_pool = true
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_DAMAGE_NUMBER):
		PoolManager.return_to_pool(self)
	else:
		queue_free()
