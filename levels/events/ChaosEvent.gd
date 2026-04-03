extends Node2D

## =========================
## EVENTO: CAOS - DUPLICACIÓN
## GDD §8.3 - Enemigos se duplican al morir
## =========================

signal event_ended

@export var duration := 30.0
@export var spawn_count := 2
@export var duplicate_health_mult := 0.5

var _arena: Node2D = null
var _player: Node2D = null
var _wave_manager: Node = null
var _is_active := false
var _connected_enemies: Array[Node] = []

func activate(arena: Node2D, player: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_player = player
	_wave_manager = wave_manager

	if not _player:
		push_error("ChaosEvent: No hay jugador válido")
		event_ended.emit()
		return

	_show_warning()
	await get_tree().create_timer(2.0).timeout

	_is_active = true
	_connect_existing_enemies()

	await get_tree().create_timer(duration).timeout

	_is_active = false
	_disconnect_all_enemies()
	event_ended.emit()

func _show_warning() -> void:
	print("⚠️ EVENTO ESPECIAL: ¡CAOS - DUPLICACIÓN!")
	if VFXManager:
		VFXManager.shake_screen(7.0, 0.4)
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("show_event_warning"):
			hud.show_event_warning("¡LOS MUERTOS RETORNAN!", Color("#9933FF"))

func _connect_existing_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_signal("enemy_died") and not enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.connect(_on_enemy_died)
			_connected_enemies.append(enemy)

func _disconnect_all_enemies() -> void:
	for enemy in _connected_enemies:
		if is_instance_valid(enemy) and enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.disconnect(_on_enemy_died)
	_connected_enemies.clear()

func _on_enemy_died(dead_enemy: Node) -> void:
	if not _is_active:
		return
	if not is_instance_valid(dead_enemy):
		return
	var scene: PackedScene = null
	if dead_enemy.has_meta("spawn_scene"):
		scene = dead_enemy.get_meta("spawn_scene")
	if not scene:
		return
	var origin_pos: Vector2 = dead_enemy.global_position
	for i in range(spawn_count):
		call_deferred("_spawn_duplicate", scene, origin_pos)

func _spawn_duplicate(scene: PackedScene, origin: Vector2) -> void:
	var pool_key := _get_pool_key_for_scene(scene)
	var duplicated_enemy: Node = null
	if pool_key and PoolManager and PoolManager.has_pool(pool_key):
		duplicated_enemy = PoolManager.get_pooled_object(pool_key)
	else:
		duplicated_enemy = scene.instantiate()
		get_tree().current_scene.call_deferred("add_child", duplicated_enemy)

	if duplicated_enemy:
		var offset := Vector2(randf_range(-80, 80), randf_range(-80, 80))
		duplicated_enemy.global_position = origin + offset
		duplicated_enemy.set_meta("spawn_scene", scene)
		if "target" in duplicated_enemy:
			duplicated_enemy.target = _player
		var damageable = duplicated_enemy.get_node_or_null("Damageable")
		if damageable and "max_health" in damageable and "health" in damageable:
			damageable.max_health *= duplicate_health_mult
			damageable.health = damageable.max_health
		if "modulate" in duplicated_enemy:
			duplicated_enemy.modulate = Color(1.0, 1.0, 1.0, 0.6)
		if duplicated_enemy.has_signal("enemy_died") and not duplicated_enemy.enemy_died.is_connected(_on_enemy_died):
			duplicated_enemy.enemy_died.connect(_on_enemy_died)
			_connected_enemies.append(duplicated_enemy)
		if VFXManager:
			VFXManager.play_chaos_spawn_effect(duplicated_enemy.global_position)

func _get_pool_key_for_scene(scene: PackedScene) -> String:
	if not _wave_manager:
		return ""
	if "_enemy_scene_to_pool_key" in _wave_manager:
		return _wave_manager._enemy_scene_to_pool_key.get(scene, "")
	return ""

func _exit_tree() -> void:
	_is_active = false
	_disconnect_all_enemies()
