extends CharacterBody2D

# =========================
# CONSTANTES DE CONFIGURACIÓN
# =========================
const BASE_FIRE_RATE: float = 1.0
const FIRE_RATE_REDUCTION_PER_LEVEL: float = 0.1
const MIN_FIRE_RATE: float = 0.1
# Intervalo entre disparos en segundos (subclases pueden override para 0.8/s etc.)
var character_base_fire_interval: float = 1.0
const _GARLIC_SCENE := preload("res://entities/weapons/GarlicWeapon.tscn")

# =========================
# SEÑALES (HUD)
# =========================
signal health_changed(current, max)
signal experience_changed(current, required)
signal leveled_up(new_level)

# =========================
# MOVIMIENTO (base; multiplicadores vienen de UpgradeManager)
# GDD §7.1 RECLUTA: 5 m/s ≈ 220 px/s
# =========================
@export var base_speed := 220.0

# =========================
# DASH
# =========================
@export var dash_speed := 700.0
@export var dash_duration := 0.15
@export var base_dash_cooldown := 0.6

var is_dashing := false
var can_dash := true
var dash_direction := Vector2.ZERO

# =========================
# PROGRESIÓN
# =========================
var level := 1
var experience := 0
var experience_required := 10

# =========================
# DISPARO (base; multiplicadores vienen de UpgradeManager)
# GDD §7.1 RECLUTA: 10 daño base, 1 disparo/segundo
# =========================
@export var base_bullet_damage := 10.0
@export var base_fire_rate := 0.5

# =========================
# PERSONAJE Y HABILIDAD ACTIVA (GDD §7)
# =========================
var character_type := "RECLUTA"
var ability_cooldown_remaining := 0.0
var ability_cooldown_max := 15.0  # PULSO DE RESONANCIA 15s
# ADAPTABILIDAD (RECLUTA): cada 3 mejoras → boost aleatorio persistente
var _adaptabilidad_damage_bonus := 0.0
var _adaptabilidad_speed_bonus := 0.0
var _adaptabilidad_health_bonus := 0.0
var _adaptabilidad_last_milestone := 0

# =========================
# DISPARO & AUTO-AIM
# =========================
@export var bullet_scene: PackedScene
@export var bouncing_bullet_scene: PackedScene
var enemies_in_range: Array[Node2D] = []
var can_shoot_directly: bool = true  # REVERBERACIÓN lo pone a false (solo torretas)

# =========================
# SISTEMA DE ARMAS
# =========================
var active_weapons: Array[Node] = []
var has_garlic := false
var has_bouncing_bullets := false

# =========================
# REFERENCIAS
# =========================
@onready var damageable := $Damageable
@onready var sprite := $Sprite2D

# =========================
# CACHÉ DE TEXTURAS (evitar load() en runtime)
# =========================
var _tex_east: Texture2D
var _tex_west: Texture2D
var _tex_north: Texture2D
var _tex_south: Texture2D

# =========================
# ANIMACIONES
# =========================
var last_direction := Vector2.DOWN
var is_moving := false

# Variable de referencia al joystick (se asigna desde Arena o HUD)
var _virtual_joystick: Node = null

# =========================
# SINERGIAS ESPECÍFICAS
# =========================
var post_dash_crit_shots: int = 0
var adaptive_shield_regen_timer: float = 0.0

# =========================
# READY
# =========================
func _ready() -> void:
	if not has_node("AutoAim"):
		push_error("Player: Nodo AutoAim no encontrado")
		return
	if not has_node("Muzzle"):
		push_error("Player: Nodo Muzzle no encontrado")
		return

	$AutoAim.area_entered.connect(_on_enemy_entered)
	$AutoAim.area_exited.connect(_on_enemy_exited)

	if not is_instance_valid(damageable):
		push_error("Player: Componente Damageable no encontrado o inválido")
		return
	if not is_instance_valid(sprite):
		push_error("Player: Sprite2D no encontrado o inválido")
		return

	damageable.health_changed.connect(_on_health_changed)
	if damageable.has_signal("shield_broken"):
		damageable.shield_broken.connect(_on_shield_broken)
	damageable.died.connect(_on_died)

	auto_fire()
	call_deferred("_initialize_hud")

	# Cachear texturas de dirección (evita load() por frame)
	_tex_east  = load("res://assets/sprites/east.png")
	_tex_west  = load("res://assets/sprites/west.png")
	_tex_north = load("res://assets/sprites/north.png")
	_tex_south = load("res://assets/sprites/south.png")

func _initialize_hud() -> void:
	emit_signal("health_changed", damageable.health, damageable.max_health)
	emit_signal("experience_changed", experience, experience_required)
	emit_signal("leveled_up", level)
	# Sincronizar escudo si UpgradeManager ya tiene mejoras (p. ej. al cargar partida)
	if UpgradeManager and UpgradeManager.stats.shield_amount > 0:
		damageable.set_max_shield(UpgradeManager.stats.shield_amount)
	# Vida extra permanente del Taller (Workshop)
	if UpgradeManager:
		var health_bonus: float = float(UpgradeManager.stats.get("workshop_health_bonus", 0))
		if health_bonus > 0:
			damageable.max_health += health_bonus
			damageable.health = minf(damageable.health + health_bonus, damageable.max_health)
			emit_signal("health_changed", damageable.health, damageable.max_health)

func _get_speed() -> float:
	var mult := 1.0
	if UpgradeManager:
		mult = UpgradeManager.stats.speed_mult
	# RECLUTA Adaptabilidad: +15% velocidad
	mult += _adaptabilidad_speed_bonus
	return base_speed * mult

func _get_fire_rate() -> float:
	var fire_rate_level: int = 0
	if UpgradeManager:
		fire_rate_level = UpgradeManager.get_upgrade_level(UpgradeManager.UPGRADE_FIRE_RATE)
	var base_interval := character_base_fire_interval if character_base_fire_interval > 0 else BASE_FIRE_RATE
	return maxf(MIN_FIRE_RATE, base_interval - FIRE_RATE_REDUCTION_PER_LEVEL * fire_rate_level)

func _get_bullet_damage() -> float:
	var mult := 1.0
	if UpgradeManager:
		mult = UpgradeManager.stats.damage_mult
	# RECLUTA Adaptabilidad: +10% daño
	mult += _adaptabilidad_damage_bonus
	return base_bullet_damage * mult

func _get_pierce() -> int:
	if UpgradeManager:
		return UpgradeManager.stats.pierce
	return 0

func _get_dash_cooldown() -> float:
	if UpgradeManager:
		return base_dash_cooldown * UpgradeManager.stats.dash_cooldown_mult
	return base_dash_cooldown

# =========================
# REGENERACIÓN Y COOLDOWN DE HABILIDAD
# =========================
func _process(delta: float) -> void:
	if not GameManager or GameManager.game_state != GameManager.GameState.PLAYING:
		return
	if UpgradeManager and UpgradeManager.stats.regen_per_sec > 0 and damageable and damageable.health > 0:
		var regen_mult := 1.0
		# ESCUDO ADAPTATIVO: 3x regen durante 5s tras romper escudo
		if adaptive_shield_regen_timer > 0.0 and UpgradeManager.has_synergy("adaptive_shield"):
			adaptive_shield_regen_timer = maxf(adaptive_shield_regen_timer - delta, 0.0)
			regen_mult = 3.0
		damageable.heal(UpgradeManager.stats.regen_per_sec * regen_mult * delta)
	if ability_cooldown_remaining > 0:
		ability_cooldown_remaining -= delta

# =========================
# LOOP FÍSICO
# =========================
func _physics_process(_delta: float) -> void:
	if not GameManager or GameManager.game_state != GameManager.GameState.PLAYING:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO)
		return

	var move_dir := get_movement_input()

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		velocity = move_dir * _get_speed()

	move_and_slide()
	_clamp_to_world_border()
	update_animation(move_dir)

# =========================
# BORDER DEL MUNDO
# =========================
func _clamp_to_world_border() -> void:
	var tree = get_tree()
	if not tree:
		return
	var arena = tree.current_scene
	if arena == null:
		return
	var mn = arena.get("world_limit_min")
	var mx = arena.get("world_limit_max")
	if mn is Vector2 and mx is Vector2:
		global_position = global_position.clamp(mn, mx)

# =========================
# INPUT MOVIMIENTO
# =========================
func get_movement_input() -> Vector2:
	# Input de teclado (PC)
	var keyboard_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): keyboard_dir.x -= 1
	if Input.is_key_pressed(KEY_D): keyboard_dir.x += 1
	if Input.is_key_pressed(KEY_W): keyboard_dir.y -= 1
	if Input.is_key_pressed(KEY_S): keyboard_dir.y += 1

	# Si hay input de teclado, usarlo
	if keyboard_dir != Vector2.ZERO:
		return keyboard_dir.normalized()

	# Fallback a joystick virtual (móvil)
	if _virtual_joystick and is_instance_valid(_virtual_joystick):
		var touch_dir: Vector2 = _virtual_joystick.get_direction()
		if touch_dir != Vector2.ZERO:
			return touch_dir.normalized()

	return Vector2.ZERO

# =========================
# INPUT DASH
# =========================
func _input(event: InputEvent) -> void:
	if not GameManager or GameManager.game_state != GameManager.GameState.PLAYING:
		return
	# Input de teclado (PC)
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SHIFT:
			request_dash()
		if event.keycode == KEY_R:
			request_ability()

# Métodos públicos para que los botones UI de móvil puedan llamar
func request_dash() -> void:
	if can_dash and not is_dashing:
		start_dash()

func request_ability() -> void:
	if ability_cooldown_remaining <= 0:
		use_ability()

# =========================
# DASH
# =========================
func start_dash() -> void:
	var direction := get_movement_input()
	if direction == Vector2.ZERO:
		return

	can_dash = false
	is_dashing = true
	dash_direction = direction

	damageable.is_invulnerable = true
	var tree = get_tree()
	if not tree:
		can_dash = true
		return
	await tree.create_timer(dash_duration).timeout

	is_dashing = false
	damageable.is_invulnerable = false

	# REFLEJO MORTAL: tras el dash, los próximos 3 disparos son críticos
	if UpgradeManager and UpgradeManager.has_synergy("deadly_reflex"):
		post_dash_crit_shots = 3

	tree = get_tree()
	if not tree:
		can_dash = true
		return
	await tree.create_timer(_get_dash_cooldown()).timeout
	can_dash = true

func _on_shield_broken() -> void:
	# ESCUDO ADAPTATIVO: al romperse el escudo, regen 3x durante 5s
	if UpgradeManager and UpgradeManager.has_synergy("adaptive_shield"):
		adaptive_shield_regen_timer = 5.0

func consume_post_dash_crit() -> bool:
	if not UpgradeManager or not UpgradeManager.has_synergy("deadly_reflex"):
		return false
	if post_dash_crit_shots > 0:
		post_dash_crit_shots -= 1
		return true
	return false

# =========================
# EXPERIENCIA
# =========================
func add_experience(amount: int) -> void:
	experience += amount
	if experience >= experience_required:
		level_up()
	emit_signal("experience_changed", experience, experience_required)

func level_up() -> void:
	level += 1
	experience -= experience_required
	experience_required = int(experience_required * 1.5)
	emit_signal("leveled_up", level)

	var tree = get_tree()
	if not tree:
		return
	var menu = tree.current_scene.get_node_or_null("UpgradeMenu")
	if menu and menu.has_method("show_menu"):
		menu.show_menu()

# =========================
# MEJORAS (solo las que modifican nodos directos; el resto está en UpgradeManager.stats)
# =========================
func apply_upgrade(upgrade_type: String) -> void:
	match upgrade_type:
		UpgradeManager.UPGRADE_HEALTH:
			var current_level = UpgradeManager.get_upgrade_level(UpgradeManager.UPGRADE_HEALTH)
			damageable.max_health = 100.0 + _adaptabilidad_health_bonus + (20.0 * current_level)
			damageable.health = minf(damageable.health + 20.0, damageable.max_health)
			emit_signal("health_changed", damageable.health, damageable.max_health)
		UpgradeManager.UPGRADE_SHIELD:
			if UpgradeManager:
				damageable.set_max_shield(UpgradeManager.stats.shield_amount)
		UpgradeManager.UPGRADE_GARLIC:
			if not has_garlic and UpgradeManager.stats.has_garlic:
				has_garlic = true
				var tree = get_tree()
				if tree and tree.current_scene:
					var garlic = _GARLIC_SCENE.instantiate()
					tree.current_scene.add_child(garlic)
					active_weapons.append(garlic)
		UpgradeManager.UPGRADE_BOUNCING:
			if UpgradeManager.stats.has_bouncing:
				has_bouncing_bullets = true
		_:
			pass
	# RECLUTA: Adaptabilidad — cada 3 mejoras → boost aleatorio
	if character_type == "RECLUTA":
		_recluta_check_adaptabilidad()

func _recluta_check_adaptabilidad() -> void:
	if not UpgradeManager:
		return
	var total_levels := 0
	for _id in UpgradeManager.player_upgrades:
		total_levels += UpgradeManager.player_upgrades[_id]
	# ✅ FIX línea 331: evitar INTEGER_DIVISION usando módulo en lugar de división
	var milestone: int = total_levels - (total_levels % 3)
	if milestone <= 0 or milestone <= _adaptabilidad_last_milestone:
		return
	_adaptabilidad_last_milestone = milestone
	var r := randi() % 3
	if r == 0:
		_adaptabilidad_damage_bonus += 0.10
	elif r == 1:
		_adaptabilidad_speed_bonus += 0.15
	else:
		_adaptabilidad_health_bonus += 20.0
		damageable.max_health += 20.0
		damageable.health = minf(damageable.health + 20.0, damageable.max_health)
		emit_signal("health_changed", damageable.health, damageable.max_health)

# =========================
# HABILIDAD ACTIVA (override en subclases)
# =========================
func use_ability() -> void:
	if ability_cooldown_remaining > 0:
		return
	# RECLUTA: PULSO DE RESONANCIA — empuja enemigos, 50 daño en área
	if character_type == "RECLUTA":
		_ability_pulso_resonancia()
		ability_cooldown_remaining = ability_cooldown_max

func _spawn_pulse_wave_vfx(center: Vector2, radius: float) -> void:
	# Círculo con Polygon2D: sin Image.create(), sin loops de píxeles
	var ring := Polygon2D.new()
	ring.z_index = 35
	ring.global_position = center
	ring.color = Color(0.4, 0.6, 1.0, 0.5)

	# Generar polígono circular con 32 segmentos
	var points := PackedVector2Array()
	const SEGMENTS := 32
	for i in range(SEGMENTS):
		var angle := (float(i) / float(SEGMENTS)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius * 0.12)
	ring.polygon = points

	get_tree().current_scene.add_child(ring)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(8.0, 8.0), 0.3)
	t.tween_property(ring, "modulate:a", 0.0, 0.3)
	t.tween_callback(ring.queue_free)

func _ability_pulso_resonancia() -> void:
	const PULSE_RADIUS := 120.0
	const PULSE_DAMAGE := 50.0
	var center := global_position
	# VFX: onda expansiva
	_spawn_pulse_wave_vfx(center, PULSE_RADIUS)
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PULSE_RADIUS
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = 2  # enemigos
	var results := space.intersect_shape(query, 32)
	for result in results:
		var body = result.collider
		# ✅ FIX línea 394: tipo explícito Node para dmg
		var dmg: Node = body.get_node_or_null("Damageable")
		if dmg:
			dmg.take_damage(PULSE_DAMAGE)
		if body.has_method("apply_knockback"):
			var dir: Vector2 = (body.global_position - center).normalized()
			body.apply_knockback(dir)

# =========================
# AUTO-AIM
# =========================
func _on_enemy_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy not in enemies_in_range:
		enemies_in_range.append(enemy)

func _on_enemy_exited(area: Area2D) -> void:
	var enemy := area.get_parent()
	if is_instance_valid(enemy):
		enemies_in_range.erase(enemy)

func get_closest_enemy() -> Node2D:
	# Limpiar referencias inválidas (evita leaks y targets zombie)
	var to_remove: Array[Node2D] = []
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
	for e in to_remove:
		enemies_in_range.erase(e)
	if enemies_in_range.is_empty():
		return null
	var closest: Node2D = null
	var min_dist := INF
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	return closest

# =========================
# DISPARO
# =========================
func shoot() -> void:
	if not can_shoot_directly:
		return
	var target := get_closest_enemy()
	if not target or not is_instance_valid(target):
		return
	if not has_node("Muzzle"):
		return

	var tree := get_tree()
	if tree:
		tree.call_group("camera", "shake", 2.0, 0.1)

	var base_dir := Vector2(target.global_position - $Muzzle.global_position).normalized()
	var extra := _get_extra_projectiles()
	var spread_angle := 0.15  # radianes entre proyectiles

	if has_bouncing_bullets and bouncing_bullet_scene != null:
		_spawn_bouncing_bullets(base_dir, extra, spread_angle)
	else:
		_spawn_bullets(base_dir, extra, spread_angle)

func _get_extra_projectiles() -> int:
	if UpgradeManager:
		return UpgradeManager.stats.extra_projectiles
	return 0

func _spawn_bullets(base_dir: Vector2, extra_count: int, spread: float) -> void:
	if bullet_scene == null or not has_node("Muzzle"):
		return
	var use_pool := PoolManager != null and PoolManager.is_initialized()
	var tree := get_tree()
	if not use_pool and (not tree or not tree.current_scene):
		return
	var count := 1 + extra_count
	for i in range(count):
		var dir := base_dir
		if count > 1:
			var offset := (float(i) - (count - 1) * 0.5) * spread
			dir = base_dir.rotated(offset)
		var bullet: Node = null
		if use_pool:
			bullet = PoolManager.get_bullet()
		else:
			bullet = bullet_scene.instantiate()
			tree.current_scene.add_child(bullet)
		if not bullet:
			continue
		bullet.global_position = $Muzzle.global_position
		bullet.set_direction(dir)
		bullet.set_damage(_get_bullet_damage())
		bullet.set_pierce(_get_pierce())
		if bullet.has_method("set_source_player"):
			bullet.set_source_player(self)

func _spawn_bouncing_bullets(base_dir: Vector2, extra_count: int, spread: float) -> void:
	if bouncing_bullet_scene == null:
		return
	var use_pool := PoolManager != null and PoolManager.is_initialized()
	var count := 1 + extra_count
	for i in range(count):
		var dir := base_dir
		if count > 1:
			var offset := (float(i) - (count - 1) * 0.5) * spread
			dir = base_dir.rotated(offset)
		var bullet: Node = null
		if use_pool:
			bullet = PoolManager.get_bouncing_bullet()
		else:
			bullet = bouncing_bullet_scene.instantiate()
			var tree := get_tree()
			if tree and tree.current_scene:
				tree.current_scene.add_child(bullet)
		if not bullet:
			continue
		if has_node("Muzzle"):
			bullet.global_position = $Muzzle.global_position
		bullet.set_direction(dir)
		bullet.set_damage(_get_bullet_damage())
		bullet.set_bounces(3)

func auto_fire() -> void:
	while is_inside_tree():
		if GameManager and GameManager.game_state == GameManager.GameState.PLAYING:
			shoot()
		var tree := get_tree()
		if not tree:
			break
		var interval := _get_fire_rate()
		# FRECUENCIA LIBRE: 10% probabilidad de disparo gratis (cooldown mínimo)
		if UpgradeManager and UpgradeManager.has_synergy("infinite_ammo") and randf() < 0.10:
			interval = MIN_FIRE_RATE
		await tree.create_timer(interval).timeout
		if not is_inside_tree():
			break

# =========================
# VIDA & MUERTE
# =========================
func _on_health_changed(current: float, max_health_val: float) -> void:
	emit_signal("health_changed", current, max_health_val)
	if current < max_health_val:
		if GameManager and GameManager.game_state == GameManager.GameState.PLAYING:
			GameManager.mark_player_damage_taken()
		var tree = get_tree()
		if tree:
			tree.call_group("camera", "shake", 5.0, 0.2)
		modulate = Color(2.0, 2.0, 2.0)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_died() -> void:
	if GameManager:
		GameManager.set_game_over()

# =========================
# ANIMACIONES
# =========================
func update_animation(move_dir: Vector2) -> void:
	is_moving = move_dir.length() > 0.1
	if is_moving:
		last_direction = move_dir
		update_sprite_direction(move_dir)
	else:
		update_sprite_direction(last_direction)

func update_sprite_direction(dir: Vector2) -> void:
	var abs_x := absf(dir.x)
	var abs_y := absf(dir.y)
	if abs_x > abs_y:
		sprite.texture = _tex_east if dir.x > 0 else _tex_west
	else:
		sprite.texture = _tex_south if dir.y > 0 else _tex_north

func _exit_tree() -> void:
	# Desconectar signals de AutoAim
	if has_node("AutoAim"):
		var auto_aim = $AutoAim
		if auto_aim.area_entered.is_connected(_on_enemy_entered):
			auto_aim.area_entered.disconnect(_on_enemy_entered)
		if auto_aim.area_exited.is_connected(_on_enemy_exited):
			auto_aim.area_exited.disconnect(_on_enemy_exited)

	# Desconectar signals de Damageable
	if damageable and is_instance_valid(damageable):
		if damageable.health_changed.is_connected(_on_health_changed):
			damageable.health_changed.disconnect(_on_health_changed)
		if damageable.died.is_connected(_on_died):
			damageable.died.disconnect(_on_died)
