extends Node

## =========================
## AFTERSHOCK - Pool Manager
## Object pooling (GDD §11.3): balas, enemigos, efectos, items.
## =========================

# Tamaños por tipo (GDD)
const POOL_BULLET := 100
const POOL_BOUNCING := 50
const POOL_ENEMY_PER_TYPE := 30
const POOL_DEATH_FX := 20
const POOL_EXP_GEM := 50
const POOL_HEALTH_POTION := 10
const POOL_IMPACT_FX := 30
const POOL_DAMAGE_NUMBER := 40
const POOL_SPARK := 60
const POOL_IMPACT_FLASH := 20
const DEFAULT_IMPACT_FX := preload("res://assets/effects/ImpactFX.tscn")
const DEFAULT_DAMAGE_NUMBER := preload("res://assets/effects/DamageNumber.tscn")
const DEFAULT_SPARK := preload("res://assets/effects/SparkParticle.tscn")
const DEFAULT_IMPACT_FLASH := preload("res://assets/effects/ImpactFlashVFX.tscn")

# Keys de pools (evitar strings mágicos)
const POOL_KEY_BULLET := "bullet"
const POOL_KEY_BOUNCING_BULLET := "bouncing_bullet"
const POOL_KEY_EXPERIENCE_GEM := "experience_gem"
const POOL_KEY_HEALTH_POTION := "health_potion"
const POOL_KEY_DEATH_FX := "death_fx"
const POOL_KEY_IMPACT_FX := "impact_fx"
const POOL_KEY_DAMAGE_NUMBER := "damage_number"
const POOL_KEY_SPARK := "spark"
const POOL_KEY_IMPACT_FLASH := "impact_flash"

# Estructura por pool: { "available": Array[Node], "scene": PackedScene, "parent": Node, "max": int }
var _pools: Dictionary = {}
var _arena: Node = null

func _ready() -> void:
	pass

# -------------------------
# Inicialización (Arena llama esto)
# -------------------------
func init_pools(
	arena: Node,
	bullet_scene: PackedScene,
	bouncing_scene: PackedScene,
	exp_gem_scene: PackedScene = null,
	health_potion_scene: PackedScene = null,
	death_fx_scene: PackedScene = null
) -> void:
	if not arena:
		push_error("PoolManager: init_pools requiere arena no nula")
		return
	if not bullet_scene or not bouncing_scene:
		push_error("PoolManager: init_pools requiere bullet_scene y bouncing_scene no nulos")
		return
	# Al volver al menú y reentrar a la Arena, la arena anterior está liberada y los parents en _pools serían inválidos.
	# Reiniciar pools para la nueva arena.
	if _arena != arena or not _pools.is_empty():
		_pools.clear()
	_arena = arena

	_register_pool(POOL_KEY_BULLET, bullet_scene, _arena, POOL_BULLET, POOL_BULLET)
	_register_pool(POOL_KEY_BOUNCING_BULLET, bouncing_scene, _arena, POOL_BOUNCING, POOL_BOUNCING)

	if exp_gem_scene:
		_register_pool(POOL_KEY_EXPERIENCE_GEM, exp_gem_scene, _arena, POOL_EXP_GEM, POOL_EXP_GEM)
	if health_potion_scene:
		_register_pool(POOL_KEY_HEALTH_POTION, health_potion_scene, _arena, POOL_HEALTH_POTION, POOL_HEALTH_POTION)
	if death_fx_scene:
		_register_pool(POOL_KEY_DEATH_FX, death_fx_scene, _arena, POOL_DEATH_FX, POOL_DEATH_FX)
	_register_pool(POOL_KEY_IMPACT_FX, DEFAULT_IMPACT_FX, _arena, POOL_IMPACT_FX, POOL_IMPACT_FX)
	_register_pool(POOL_KEY_DAMAGE_NUMBER, DEFAULT_DAMAGE_NUMBER, _arena, POOL_DAMAGE_NUMBER, POOL_DAMAGE_NUMBER)
	_register_pool(POOL_KEY_SPARK, DEFAULT_SPARK, _arena, POOL_SPARK, POOL_SPARK)
	_register_pool(POOL_KEY_IMPACT_FLASH, DEFAULT_IMPACT_FLASH, _arena, POOL_IMPACT_FLASH, POOL_IMPACT_FLASH)

func _register_pool(key: String, scene: PackedScene, parent: Node, initial_count: int, max_count: int) -> void:
	if not scene or not parent:
		return
	if _pools.has(key):
		return
	var available: Array[Node] = []
	_pools[key] = {
		"available": available,
		"scene": scene,
		"parent": parent,
		"max": max_count
	}
	# Pre-warm
	for i in range(initial_count):
		var obj: Node = scene.instantiate()
		_disable_and_hide(obj)
		# adding deferred prevents "parent busy" errors when pools are initialized during tree setup
		parent.call_deferred("add_child", obj)
		available.append(obj)
		obj.set_meta("pool_key", key)

# Registrar pool de enemigos por tipo (WaveManager puede llamar)
func register_enemy_pool(key: String, scene: PackedScene, parent: Node) -> void:
	if not parent:
		parent = _arena
	if not parent or not scene:
		return
	_register_pool(key, scene, parent, POOL_ENEMY_PER_TYPE, POOL_ENEMY_PER_TYPE)

func _disable_and_hide(obj: Node) -> void:
	obj.set_process(false)
	obj.set_physics_process(false)
	if "visible" in obj:
		obj.visible = false
	if obj is Area2D:
		obj.collision_layer = 0
		obj.collision_mask = 0
	elif obj is CharacterBody2D:
		if "collision_layer" in obj:
			obj.collision_layer = 0
		if "collision_mask" in obj:
			obj.collision_mask = 0
	obj.global_position = Vector2(-9999, -9999)

# -------------------------
# API genérica (GDD: get_pooled_object / return_to_pool)
# -------------------------
func get_pooled_object(key: String) -> Node:
	if key.is_empty() or not key in _pools:
		push_error("PoolManager: Pool no existe o key vacía: " + str(key))
		return null

	var data: Dictionary = _pools.get(key, {})
	if data.is_empty():
		push_error("PoolManager: datos del pool inválidos para key: " + str(key))
		return null
	var available: Array[Node] = data.get("available", []) as Array[Node]
	var scene: PackedScene = data.get("scene", null) as PackedScene
	var parent: Node = data.get("parent", null) as Node
	var _max_count: int = data.get("max", 0)

	if not scene:
		push_error("PoolManager: Pool sin scene válida: " + str(key))
		return null
	if not parent or not is_instance_valid(parent):
		push_error("PoolManager: Pool sin parent válido: " + str(key))
		return null

	var obj: Node = null
	while available.size() > 0:
		var candidate: Node = available.pop_back()
		if is_instance_valid(candidate):
			obj = candidate
			break
	if obj == null:
		obj = scene.instantiate()
		# new instances also need to be parented deferred to avoid similar issues
		parent.call_deferred("add_child", obj)
		if obj.get_meta("pool_key", "") != key:
			obj.set_meta("pool_key", key)

	obj.set_process(true)
	obj.set_physics_process(true)
	if "visible" in obj:
		obj.visible = true
	if obj is Area2D:
		obj.collision_layer = 4
		obj.collision_mask = 2
	elif obj is CharacterBody2D:
		if "collision_layer" in obj:
			obj.collision_layer = 2
		if "collision_mask" in obj:
			obj.collision_mask = 4

	if obj.has_method("restart_for_reuse"):
		obj.restart_for_reuse()
	elif obj.has_method("reset"):
		obj.reset()
	return obj

func return_to_pool(obj: Node) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	var key: String = obj.get_meta("pool_key", "")
	if key.is_empty() or not key in _pools:
		push_warning("Intentando retornar a pool inexistente: " + key)
		obj.queue_free()
		return
	var data: Dictionary = _pools.get(key, {})
	if data.is_empty():
		push_error("PoolManager: datos del pool inválidos en return_to_pool: " + str(key))
		obj.queue_free()
		return
	var available: Array[Node] = data.get("available", []) as Array[Node]
	var max_count: int = data.get("max", 0)
	if available.has(obj):
		return
	_disable_and_hide(obj)
	if available.size() < max_count:
		available.append(obj)
	else:
		obj.queue_free()

# -------------------------
# API específica (retrocompatibilidad)
# -------------------------
func get_bullet() -> Node:
	return get_pooled_object(POOL_KEY_BULLET)

func get_bouncing_bullet() -> Node:
	return get_pooled_object(POOL_KEY_BOUNCING_BULLET)

func release_bullet(bullet: Node) -> void:
	return_to_pool(bullet)

func release_bouncing_bullet(bullet: Node) -> void:
	return_to_pool(bullet)

# -------------------------
# Utilidad
# -------------------------
func is_initialized() -> bool:
	return _arena != null and _pools.has(POOL_KEY_BULLET)

func has_pool(key: String) -> bool:
	return _pools.has(key)
