extends Node2D
## Torreta de REVERBERACIÓN (GDD §7.4). Orbita al jugador y dispara al enemigo más cercano.

@export var fire_rate := 1.0
@export var turret_damage := 6.0
@export var range_distance := 300.0

var fire_rate_mult := 1.0
var target_offset := Vector2.ZERO  # offset desde el jugador (posición en órbita)
var _time_since_shot := 0.0
var _overcharge_vfx: Node2D = null

func _process(delta: float) -> void:
	if not GameManager or GameManager.game_state != GameManager.GameState.PLAYING:
		return
	# Suavemente moverse hacia target_offset (órbita alrededor del jugador)
	position = position.lerp(target_offset, delta * 5.0)
	
	var player := get_parent()
	if not is_instance_valid(player) or not player.has_method("get_tree"):
		return
	var tree := player.get_tree()
	if not tree or not tree.current_scene:
		return
	
	_time_since_shot += delta
	var actual_fire_rate := fire_rate * fire_rate_mult
	if actual_fire_rate <= 0.0:
		return
	var interval := 1.0 / actual_fire_rate
	if _time_since_shot < interval:
		return

	var nearest := _find_nearest_enemy()
	if nearest:
		_shoot_at(nearest, tree, player, interval)

func _find_nearest_enemy() -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var enemies := tree.get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_dist_sq := range_distance * range_distance
	var origin := global_position
	for node in enemies:
		if not node is Node2D or not is_instance_valid(node):
			continue
		var d_sq := origin.distance_squared_to(node.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = node
	return best

func _shoot_at(enemy: Node2D, tree: SceneTree, player: Node, interval: float) -> void:
	# Obtener escena de bala del jugador
	var bullet_scene: PackedScene = null
	if player.get("bullet_scene"):
		bullet_scene = player.bullet_scene
	if not bullet_scene:
		return
	
	var use_pool := PoolManager != null and PoolManager.is_initialized()
	var bullet: Node = null
	if use_pool:
		bullet = PoolManager.get_bullet()
	else:
		bullet = bullet_scene.instantiate()
		if not bullet:
			return
		tree.current_scene.add_child(bullet)
	if not bullet:
		return

	bullet.global_position = global_position
	var dir := (enemy.global_position - global_position).normalized()
	bullet.set_direction(dir)
	bullet.set_damage(turret_damage)
	bullet.set_pierce(0)
	if bullet.has_method("set_source_player"):
		bullet.set_source_player(player)
	
	_time_since_shot = 0.0

func show_overcharge_vfx() -> void:
	if _overcharge_vfx and is_instance_valid(_overcharge_vfx):
		return
	var glow := Polygon2D.new()
	glow.name = "OverchargeGlow"
	glow.color = Color(1.0, 0.9, 0.2, 0.7)
	glow.z_index = -1
	var pts := PackedVector2Array()
	const SEG := 16
	const R := 12.0
	for i in range(SEG):
		var angle := (float(i) / float(SEG)) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * R)
	glow.polygon = pts
	add_child(glow)
	_overcharge_vfx = glow

func hide_overcharge_vfx() -> void:
	if _overcharge_vfx and is_instance_valid(_overcharge_vfx):
		_overcharge_vfx.queue_free()
	_overcharge_vfx = null
