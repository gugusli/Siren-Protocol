extends Node2D
@onready var particles: CPUParticles2D = $CPUParticles2D

func restart_for_reuse() -> void:
	visible = true
	if particles:
		particles.emitting = true
	var lifetime := 0.3
	if particles:
		lifetime = particles.lifetime
	await get_tree().create_timer(lifetime).timeout
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_IMPACT_FX):
		PoolManager.return_to_pool(self)
	else:
		queue_free()

func set_color(c: Color) -> void:
	if particles:
		particles.color = c
