extends Node2D

## =========================
## EVENTO: LLUVIA DE ARTILLERÍA
## GDD §8.3 - Proyectiles caen marcados con círculos rojos
## =========================

signal event_ended

@export var duration := 20.0
@export var projectile_spawn_rate := 0.8
@export var warning_time := 1.5
@export var damage_per_projectile := 50.0
@export var explosion_radius := 80.0
@export var artillery_count := 5

var _arena: Node2D = null
var _player: Node2D = null
var _wave_manager: Node = null
var _is_active := false
var _spawned_artillery: Array[Node] = []

const WARNING_CIRCLE_SCENE := preload("res://assets/effects/WarningCircle.tscn")

func activate(arena: Node2D, player: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_player = player
	_wave_manager = wave_manager

	if not _player or not is_instance_valid(_player):
		push_error("ArtilleryRainEvent: No hay jugador válido")
		event_ended.emit()
		return

	_show_warning()
	await get_tree().create_timer(2.0).timeout

	_spawn_artillery_units()
	_is_active = true
	_start_projectile_rain()

	await get_tree().create_timer(duration).timeout

	_is_active = false
	event_ended.emit()

func _show_warning() -> void:
	print("⚠️ EVENTO ESPECIAL: ¡LLUVIA DE ARTILLERÍA!")
	if VFXManager:
		VFXManager.shake_screen(6.0, 0.3)
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("show_event_warning"):
			hud.show_event_warning("¡BOMBARDEO INMINENTE!", Color("#FF6600"))

func _spawn_artillery_units() -> void:
	if not _wave_manager or not _wave_manager.artillery_enemy_scene:
		return
	for i in range(artillery_count):
		var angle := (float(i) / float(artillery_count)) * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 600.0
		var spawn_pos := _player.global_position + offset
		var pool_key := "enemy_artillery"
		var artillery: Node = null
		if PoolManager and PoolManager.has_pool(pool_key):
			artillery = PoolManager.get_pooled_object(pool_key)
		else:
			artillery = _wave_manager.artillery_enemy_scene.instantiate()
			get_tree().current_scene.add_child(artillery)
		if artillery:
			artillery.global_position = spawn_pos
			if "target" in artillery:
				artillery.target = _player
			_spawned_artillery.append(artillery)
		await get_tree().create_timer(0.3).timeout

func _start_projectile_rain() -> void:
	var projectiles_spawned := 0
	var max_projectiles := int(duration / projectile_spawn_rate)
	while _is_active and projectiles_spawned < max_projectiles:
		_spawn_falling_projectile()
		await get_tree().create_timer(projectile_spawn_rate).timeout
		projectiles_spawned += 1

func _spawn_falling_projectile() -> void:
	var random_offset := Vector2(randf_range(-400, 400), randf_range(-400, 400))
	var impact_pos := _player.global_position + random_offset
	_show_warning_circle(impact_pos)
	await get_tree().create_timer(warning_time).timeout
	_apply_projectile_damage(impact_pos)

func _show_warning_circle(pos: Vector2) -> void:
	var circle = WARNING_CIRCLE_SCENE.instantiate()
	get_tree().current_scene.add_child(circle)
	circle.global_position = pos
	if circle.has_method("play"):
		circle.play(warning_time)

func _apply_projectile_damage(center: Vector2) -> void:
	if VFXManager:
		VFXManager.play_explosion_effect(center, explosion_radius)
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = 1 | 2
	var results := space.intersect_shape(query, 32)
	for result in results:
		var collider = result.collider
		var damageable = collider.get_node_or_null("Damageable")
		if damageable and damageable.has_method("take_damage"):
			damageable.take_damage(damage_per_projectile)
			if collider.has_method("apply_knockback"):
				var kb_dir: Vector2 = (collider.global_position - center).normalized()
				collider.apply_knockback(kb_dir * 2.0)

func _exit_tree() -> void:
	_is_active = false
	_spawned_artillery.clear()
