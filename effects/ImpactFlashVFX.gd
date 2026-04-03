extends Sprite2D

## Flash de impacto pooleable para críticos (GDD §11.3).
## VFXManager llama play() y al terminar el tween se devuelve al pool.

const SIZE := 32
const ANIM_DURATION := 0.1

var _in_pool := false

func _ready() -> void:
	z_index = 60
	if not texture:
		texture = PlaceholderTexture2D.new()
		texture.size = Vector2(SIZE, SIZE)
	scale = Vector2(0.5, 0.5)
	set_process(false)

func restart_for_reuse() -> void:
	_in_pool = false
	modulate.a = 0.8
	scale = Vector2(0.5, 0.5)
	visible = true

func play(pos: Vector2, color: Color) -> void:
	modulate = Color(color.r, color.g, color.b, 0.8)
	global_position = pos
	scale = Vector2(0.5, 0.5)
	visible = true

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), ANIM_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	tween.chain().tween_callback(_release)

func _release() -> void:
	if _in_pool:
		return
	_in_pool = true
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_IMPACT_FLASH):
		PoolManager.return_to_pool(self)
	else:
		queue_free()
