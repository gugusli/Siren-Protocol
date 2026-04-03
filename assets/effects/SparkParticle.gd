extends Sprite2D

## Partícula de chispa pooleable (GDD §11.3).
## VFXManager llama play() y al terminar el tween se devuelve al pool.

const SPEED_MIN := 80.0
const SPEED_MAX := 150.0
const TRAVEL_MULT := 0.3
const ANIM_DURATION := 0.25

var _in_pool := false

func _ready() -> void:
	z_index = 50
	if not texture:
		texture = PlaceholderTexture2D.new()
		texture.size = Vector2(4, 4)
	set_process(false)

func restart_for_reuse() -> void:
	_in_pool = false
	modulate.a = 1.0
	scale = Vector2.ONE
	visible = true

func play(pos: Vector2, color: Color) -> void:
	modulate = color
	modulate.a = 1.0
	global_position = pos
	scale = Vector2.ONE
	visible = true

	var angle: float = randf() * TAU
	var speed: float = randf_range(SPEED_MIN, SPEED_MAX)
	var direction: Vector2 = Vector2(cos(angle), sin(angle))
	var target_pos: Vector2 = pos + direction * speed * TRAVEL_MULT

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, ANIM_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.1)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), ANIM_DURATION)
	tween.chain().tween_callback(_release)

func _release() -> void:
	if _in_pool:
		return
	_in_pool = true
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_SPARK):
		PoolManager.return_to_pool(self)
	else:
		queue_free()
