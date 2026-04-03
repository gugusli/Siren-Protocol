extends Node2D

## Efecto de muerte de enemigo (pooleable).
## Al reutilizar se reemite el one-shot y luego se devuelve al pool.

@onready var particles: CPUParticles2D = $CPUParticles2D

func restart_for_reuse() -> void:
	if particles:
		particles.emitting = true
	var lifetime := 0.5
	if particles:
		lifetime = particles.lifetime
	await get_tree().create_timer(lifetime).timeout
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_DEATH_FX):
		PoolManager.return_to_pool(self)
	else:
		queue_free()
