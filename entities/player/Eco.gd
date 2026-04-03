extends "res://entities/player/player.gd"
## ECO - El Híbrido (GDD §7.5)
## 110 HP, 4.8 m/s, 12 daño, 1.2 disp/s. Resonancia Corrupta: +1 stack por enemigo muerto cerca (máx 10). Transformación consume stacks: explosión por stack + 5% vida por stack.

const MAX_STACKS := 10
const STACK_DAMAGE_BONUS := 0.05   # +5% por stack
const STACK_HEALTH_PENALTY := 0.01 # -1% vida máx por stack
const DETECTION_RADIUS := 150.0
const TRANSFORM_COOLDOWN := 30.0
const EXPLOSION_DAMAGE := 20.0
const EXPLOSION_RADIUS := 100.0
const HEAL_PER_STACK_PERCENT := 0.05  # 5% vida por stack

signal corruption_stacks_changed(stacks: int, max_stacks: int)

var corruption_stacks := 0
var base_max_health := 110.0
var damage_multiplier := 1.0  # aplicado además de UpgradeManager
var _wm_ref: Node = null

func _ready() -> void:
	character_type = "ECO"
	ability_cooldown_max = TRANSFORM_COOLDOWN
	base_max_health = 110.0
	damageable.max_health = 110.0
	damageable.health = 110.0
	base_speed = 211.0   # 4.8 m/s
	base_bullet_damage = 12.0
	character_base_fire_interval = 1.0 / 1.2  # 1.2 disparos/s
	super._ready()
	
	var tree := get_tree()
	if tree and tree.current_scene:
		var wm := tree.current_scene.get_node_or_null("WaveManager")
		if wm and wm.has_signal("enemy_died_at_position"):
			wm.enemy_died_at_position.connect(_on_enemy_died_at_position)
			_wm_ref = wm
	corruption_stacks_changed.emit(corruption_stacks, MAX_STACKS)

func _exit_tree() -> void:
	if _wm_ref and is_instance_valid(_wm_ref) and _wm_ref.has_signal("enemy_died_at_position"):
		if _wm_ref.enemy_died_at_position.is_connected(_on_enemy_died_at_position):
			_wm_ref.enemy_died_at_position.disconnect(_on_enemy_died_at_position)
	_wm_ref = null

func _on_enemy_died_at_position(_enemy: Node, position: Vector2) -> void:
	var dist := global_position.distance_to(position)
	if dist <= DETECTION_RADIUS:
		_add_corruption_stack()

func _add_corruption_stack() -> void:
	if corruption_stacks >= MAX_STACKS:
		return
	corruption_stacks += 1
	damage_multiplier = 1.0 + (corruption_stacks * STACK_DAMAGE_BONUS)
	var health_mult := 1.0 - (corruption_stacks * STACK_HEALTH_PENALTY)
	damageable.max_health = base_max_health * health_mult
	damageable.health = minf(damageable.health, damageable.max_health)
	_update_corruption_visual()
	corruption_stacks_changed.emit(corruption_stacks, MAX_STACKS)
	emit_signal("health_changed", damageable.health, damageable.max_health)

func _update_corruption_visual() -> void:
	if not sprite:
		return
	var ratio := float(corruption_stacks) / float(MAX_STACKS)
	sprite.modulate = Color.WHITE.lerp(Color("#00D9FF"), ratio)

func _get_bullet_damage() -> float:
	var base_dmg := super._get_bullet_damage()
	return base_dmg * damage_multiplier

func use_ability() -> void:
	if ability_cooldown_remaining > 0 or corruption_stacks == 0:
		return
	ability_cooldown_remaining = ability_cooldown_max
	var stacks_to_consume := corruption_stacks
	
	# Explosiones por cada stack (GDD §7.5)
	for i in range(stacks_to_consume):
		_trigger_corruption_explosion()
		await get_tree().create_timer(0.1).timeout
	
	# Curación 5% vida por stack
	var heal_amount := stacks_to_consume * HEAL_PER_STACK_PERCENT * base_max_health
	damageable.health = minf(damageable.health + heal_amount, base_max_health)
	emit_signal("health_changed", damageable.health, damageable.max_health)
	
	# Reset stacks y stats
	corruption_stacks = 0
	damage_multiplier = 1.0
	damageable.max_health = base_max_health
	if sprite:
		sprite.modulate = Color.WHITE
	corruption_stacks_changed.emit(corruption_stacks, MAX_STACKS)

func _trigger_corruption_explosion() -> void:
	var center := global_position
	if VFXManager:
		VFXManager.play_explosion_effect(center, EXPLOSION_RADIUS * 0.5)
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = EXPLOSION_RADIUS
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = 2
	var results := space.intersect_shape(query, 32)
	for result in results:
		var body = result.collider
		var dmg: Node = body.get_node_or_null("Damageable")
		if dmg:
			dmg.take_damage(EXPLOSION_DAMAGE)
