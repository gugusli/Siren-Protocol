extends "res://entities/player/player.gd"
## VÉRTICE - El Asesino (GDD §7.3)
## 75 HP, 6.5 m/s, 15 daño, 1.5 disp/s. Backstab +50% y crítico garantizado. Dash Mortal 8s cd, invisible 1s.

var _dash_mortal_invisible := false
const DASH_MORTAL_COOLDOWN := 8.0
const INVISIBILITY_DURATION := 1.0

func _ready() -> void:
	character_type = "VÉRTICE"
	ability_cooldown_max = DASH_MORTAL_COOLDOWN
	damageable.max_health = 75.0
	damageable.health = 75.0
	base_speed = 286.0   # 6.5 m/s
	base_bullet_damage = 15.0
	character_base_fire_interval = 1.0 / 1.5  # 1.5 disparos/s
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	# Actualizar visibilidad durante invisibilidad post-dash
	if _dash_mortal_invisible and sprite:
		sprite.visible = false
	elif sprite:
		sprite.visible = true

func use_ability() -> void:
	# Dash Mortal: dash rápido + invisible 1s (GDD §7.3)
	if ability_cooldown_remaining > 0:
		return
	var move_dir := get_movement_input()
	if move_dir == Vector2.ZERO:
		move_dir = last_direction
	if move_dir == Vector2.ZERO:
		move_dir = Vector2.DOWN
	ability_cooldown_remaining = ability_cooldown_max
	# Dash más largo y rápido que el dash normal
	can_dash = false
	is_dashing = true
	dash_direction = move_dir
	damageable.is_invulnerable = true
	_dash_mortal_invisible = true
	# Velocidad de dash mayor para "Dash Mortal"
	var dash_speed_override := 900.0
	var dash_duration_override := 0.2
	var tree := get_tree()
	if not tree:
		_dash_mortal_invisible = false
		return
	# Aplicar velocidad durante el dash (override temporal)
	var orig_dash_speed := dash_speed
	dash_speed = dash_speed_override
	await tree.create_timer(dash_duration_override).timeout
	dash_speed = orig_dash_speed
	is_dashing = false
	damageable.is_invulnerable = false
	# Invisible 1 segundo más (GDD §7.3)
	await tree.create_timer(INVISIBILITY_DURATION).timeout
	_dash_mortal_invisible = false
	# Burst de daño en área al salir del dash (GDD §7.3)
	_burst_dash_mortal()
	# Cooldown del dash normal (reusar variable base)
	await tree.create_timer(base_dash_cooldown).timeout
	can_dash = true

func _burst_dash_mortal() -> void:
	const BURST_RADIUS := 120.0
	const BURST_DAMAGE := 60.0
	var center := global_position
	_spawn_pulse_wave_vfx(center, BURST_RADIUS)
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BURST_RADIUS
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = 2
	var results := space.intersect_shape(query, 32)
	for result in results:
		var body = result.collider
		var dmg: Node = body.get_node_or_null("Damageable")
		if dmg:
			dmg.take_damage(BURST_DAMAGE)
		if body.has_method("apply_knockback"):
			var dir: Vector2 = (body.global_position - center).normalized()
			body.apply_knockback(dir * 1.5)
