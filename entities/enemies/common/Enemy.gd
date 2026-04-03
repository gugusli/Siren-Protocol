extends CharacterBody2D

# =========================
# SEÑALES
# =========================
signal enemy_died(enemy)

# =========================
# EXPORTACIONES Y VARIABLES
# =========================
@export_group("Movimiento")
@export var speed := 80.0

@export_group("Knockback")
@export var knockback_strength := 220.0
@export var knockback_friction := 900.0

@export_group("Lógica de Furia")
@export var can_enrage := false      
@export var enrage_threshold := 0.3  
@export var enrage_speed_mult := 1.8  

@export_group("Combate")
@export var contact_damage := 5.0
@export var damage_interval := 0.5
@export var exp_gem_scene: PackedScene
@export var health_potion_scene: PackedScene
@export var magnet_scene: PackedScene
@export var drop_chance_health := 0.05 # 5% de chance de dropear poción
@export var drop_chance_magnet := 0.02 # 2% de chance de dropear imán 

@export_group("Élite")
@export var is_elite := false
@export var elite_health_mult := 3.0    # x3 HP (GDD §8)
@export var elite_damage_mult := 1.5    # x1.5 daño (GDD §8)
@export var elite_speed_mult := 0.8     # 0.8x velocidad (GDD §8)
@export var elite_scale := 1.3          # Más grande visualmente

# =========================
# REFERENCIAS
# =========================
@onready var sprite_visual: Sprite2D = $Sprite2D 
@onready var damageable := $Damageable

var target: Node2D = null
var is_enraged := false
var dead := false
var enemy_type := "CORREDOR"  # Para estadísticas 

# Daño al jugador
var player_ref: Node = null
var dealing_damage := false
var _damage_loop_generation := 0  # Invalida coroutines de damage_loop anteriores

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

# DoT y slow (mejoras elementales: fuego, veneno, hielo)
var burn_remaining := 0.0
var burn_dps := 0.0
var poison_remaining := 0.0
var poison_dps := 0.0
var slow_remaining := 0.0
var slow_multiplier_value := 1.0  # 0.7 = 30% slow (hielo)
var dot_tick_timer := 0.0
const DOT_TICK_INTERVAL := 0.5

# Congelación profunda (sinergia CONGELACIÓN PROFUNDA)
var is_frozen := false
var frozen_remaining := 0.0

# Valores base para object pooling (restaurar tras élite/oleada)
var _base_max_health := 0.0
var _base_speed := 0.0
var _base_contact_damage := 0.0
var _base_drop_health := 0.05
var _base_drop_magnet := 0.02
var _base_scale := Vector2.ONE

# =========================
# MÉTODOS BASE
# =========================
func _ready() -> void:
	add_to_group("enemies")

	if not has_node("Hurtbox"):
		push_error("Enemy: Nodo Hurtbox no encontrado")
		return
	if not is_instance_valid(damageable):
		push_error("Enemy: Componente Damageable no encontrado o inválido")
		return
	if not is_instance_valid(sprite_visual):
		push_error("Enemy: Sprite2D no encontrado o inválido")
		return

	# Evita que el flash afecte a otros enemigos
	if sprite_visual and sprite_visual.material:
		sprite_visual.material = sprite_visual.material.duplicate()

	$Hurtbox.body_entered.connect(_on_body_entered)
	$Hurtbox.body_exited.connect(_on_body_exited)

	damageable.died.connect(_on_died)
	damageable.health_changed.connect(_on_health_changed)
	
	# Guardar valores base para object pooling (solo primera vez)
	if _base_max_health <= 0 and damageable:
		_base_max_health = damageable.max_health
		_base_speed = speed
		_base_contact_damage = contact_damage
		_base_drop_health = drop_chance_health
		_base_drop_magnet = drop_chance_magnet
		_base_scale = scale
	
	# Aplicar modificadores de élite si corresponde
	if is_elite:
		_apply_elite_modifiers()

func _apply_elite_modifiers() -> void:
	# Obtener Damageable: puede ser null si make_elite() se llama antes de _ready (ej. desde WaveManager al instanciar)
	var dmg = damageable if damageable else get_node_or_null("Damageable")
	if not dmg:
		return
	dmg.max_health *= elite_health_mult
	dmg.health = dmg.max_health
	contact_damage *= elite_damage_mult
	speed *= elite_speed_mult
	
	# Visual élite: más grande y con aura brillante
	scale *= elite_scale
	
	# Aura roja para élites (GDD §8)
	var elite_color := Color("#CC2222")
	modulate = elite_color
	
	# Drop garantizado: gema grande + health (GDD §8)
	drop_chance_health = 1.0
	drop_chance_magnet = 0.5

func make_elite() -> void:
	is_elite = true
	_apply_elite_modifiers()

## Object pooling: reiniciar estado para reutilización (GDD §11.3)
func restart_for_reuse() -> void:
	_damage_loop_generation += 1
	dead = false
	dealing_damage = false
	target = null
	player_ref = null
	is_enraged = false
	knockback_velocity = Vector2.ZERO
	burn_remaining = 0.0
	burn_dps = 0.0
	poison_remaining = 0.0
	poison_dps = 0.0
	slow_remaining = 0.0
	slow_multiplier_value = 1.0
	dot_tick_timer = 0.0
	is_frozen = false
	frozen_remaining = 0.0
	is_elite = false
	scale = _base_scale
	modulate = Color.WHITE
	visible = true
	speed = _base_speed
	contact_damage = _base_contact_damage
	drop_chance_health = _base_drop_health
	drop_chance_magnet = _base_drop_magnet
	var dmg = get_node_or_null("Damageable")
	if dmg:
		dmg.max_health = _base_max_health
		dmg.health = _base_max_health
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if target and not is_instance_valid(target):
		target = null
	if target == null or dead or not is_instance_valid(target):
		return

	# Aplicar DoT (fuego, veneno)
	dot_tick_timer += delta
	if dot_tick_timer >= DOT_TICK_INTERVAL:
		dot_tick_timer = 0.0
		if burn_remaining > 0:
			burn_remaining -= DOT_TICK_INTERVAL
			damageable.take_damage(burn_dps * DOT_TICK_INTERVAL)
		if poison_remaining > 0:
			poison_remaining -= DOT_TICK_INTERVAL
			var poison_tick := poison_dps * DOT_TICK_INTERVAL
			damageable.take_damage(poison_tick)
			if damageable.has_method("notify_dot_damage"):
				damageable.notify_dot_damage("poison", poison_tick)
	if is_frozen:
		frozen_remaining -= delta
		if frozen_remaining <= 0.0:
			_break_freeze(false)
		# Congelado: no se mueve ni actualiza animación de caminar
		return
	if slow_remaining > 0:
		slow_remaining -= delta
	else:
		slow_multiplier_value = 1.0

	# Movimiento: velocidad con slow (hielo)
	var effective_speed := speed * (slow_multiplier_value if slow_remaining > 0 else 1.0)
	var direction := (target.global_position - global_position).normalized()
	var move_velocity := direction * effective_speed

	# Aplicar knockback (se suma)
	velocity = move_velocity + knockback_velocity
	move_and_slide()

	# Reducir knockback progresivamente
	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_friction * delta
	)
	
	# Actualizar animación de caminar
	update_walk_animation(direction)

# =========================
# KNOCKBACK
# =========================
func apply_knockback(from_direction: Vector2) -> void:
	knockback_velocity += from_direction.normalized() * knockback_strength

# =========================
# DoT Y SLOW (mejoras elementales)
# =========================
func apply_burn(duration: float, dps: float) -> void:
	burn_remaining = maxf(burn_remaining, duration)
	burn_dps = maxf(burn_dps, dps)

func apply_poison(duration: float, dps: float) -> void:
	poison_remaining = maxf(poison_remaining, duration)
	poison_dps = maxf(poison_dps, dps)

func apply_slow(duration: float, multiplier: float) -> void:
	slow_remaining = maxf(slow_remaining, duration)
	slow_multiplier_value = minf(slow_multiplier_value, multiplier)

func apply_freeze(duration: float) -> void:
	is_frozen = true
	frozen_remaining = maxf(frozen_remaining, duration)
	# Feedback visual simple: tinte azulado
	if sprite_visual:
		sprite_visual.modulate = Color(0.6, 0.8, 1.3)

func is_slowed() -> bool:
	return slow_remaining > 0.0 and slow_multiplier_value < 1.0

func _break_freeze(_from_death: bool) -> void:
	if not is_frozen:
		return
	is_frozen = false
	frozen_remaining = 0.0
	if sprite_visual:
		sprite_visual.modulate = Color.WHITE
	# AoE al romper el hielo (CONGELACIÓN PROFUNDA)
	if UpgradeManager and UpgradeManager.has_synergy("deep_freeze"):
		var center := global_position
		var radius := 80.0
		var explosion_damage := 30.0
		var space := get_world_2d().direct_space_state
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		query.shape = circle
		query.transform = Transform2D(0, center)
		query.collision_mask = 2
		var results := space.intersect_shape(query, 32)
		for result in results:
			var collider = result.collider
			if collider == self:
				continue
			var dmg = collider.get_node_or_null("Damageable")
			if dmg:
				dmg.take_damage(explosion_damage)
			if collider.has_method("apply_knockback"):
				var kb_dir: Vector2 = (collider.global_position - center).normalized()
				collider.apply_knockback(kb_dir)
		if VFXManager:
			VFXManager.spawn_explosion_particles(center, radius)
			VFXManager.shake_on_explosion()

# =========================
# SISTEMA DE FLASH
# =========================
func flash() -> void:
	if not sprite_visual or not sprite_visual.material:
		return
	sprite_visual.material.set_shader_parameter("flash_modifier", 1.0)
	var tree := get_tree()
	if not tree:
		return
	await tree.create_timer(0.08).timeout
	if is_instance_valid(sprite_visual) and sprite_visual.material:
		sprite_visual.material.set_shader_parameter("flash_modifier", 0.0)

# =========================
# DAÑO Y ESTADOS
# =========================
func _on_health_changed(current: float, max_hp: float) -> void:
	if current < max_hp and current > 0:
		flash()

	if not can_enrage or is_enraged or current <= 0:
		return

	var health_pct := float(current) / float(max_hp)
	if health_pct <= enrage_threshold:
		enter_enrage_mode()

func enter_enrage_mode() -> void:
	is_enraged = true
	speed *= enrage_speed_mult
	modulate = Color(1.5, 0.3, 0.3) # Rojo intenso para modo furia (valores ajustados)

# =========================
# CONTACTO CON EL JUGADOR
# =========================
func _on_body_entered(body: Node) -> void:
	if body.has_node("Damageable"):
		player_ref = body
		if not dealing_damage:
			dealing_damage = true
			_damage_loop()

func _on_body_exited(body: Node) -> void:
	if body == player_ref:
		player_ref = null
		dealing_damage = false

func _damage_loop() -> void:
	var my_generation := _damage_loop_generation  # capturar generación al inicio
	while dealing_damage and player_ref and is_inside_tree():
		# Si la generación cambió, este loop es zombie: salir
		if _damage_loop_generation != my_generation:
			return
		if is_instance_valid(player_ref):
			var player_damageable = player_ref.get_node_or_null("Damageable")
			if player_damageable:
				player_damageable.take_damage(contact_damage, self)
		else:
			player_ref = null
			dealing_damage = false
			return
		var tree := get_tree()
		if not tree:
			dealing_damage = false
			return
		await tree.create_timer(damage_interval).timeout

# =========================
# MUERTE
# =========================
func _on_died() -> void:
	if dead: return

	dead = true
	dealing_damage = false
	set_physics_process(false)

	# Registrar kill en DirectorAI
	if DirectorAI:
		DirectorAI.register_kill()
	
	# Registrar kill en GameManager
	if GameManager:
		GameManager.add_kill(enemy_type)

	# Drops aleatorios (élites siempre dropean)
	if exp_gem_scene:
		call_deferred("_spawn_gem")
		# Élites dropean gemas extra
		if is_elite:
			call_deferred("_spawn_gem")
			call_deferred("_spawn_gem")
	
	# Drop de poción de vida
	if health_potion_scene and randf() < drop_chance_health:
		call_deferred("_spawn_health_potion")
	
	# Drop de imán
	if magnet_scene and randf() < drop_chance_magnet:
		call_deferred("_spawn_magnet")

	# Efecto de muerte desde pool (si existe)
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_DEATH_FX):
		var fx: Node = PoolManager.get_pooled_object(PoolManager.POOL_KEY_DEATH_FX)
		if fx:
			fx.global_position = global_position

	emit_signal("enemy_died", self)
	visible = false
	var pool_key: String = get_meta("pool_key", "")
	if not pool_key.is_empty() and PoolManager and PoolManager.has_pool(pool_key):
		set_physics_process(false)
		PoolManager.return_to_pool(self)
	else:
		call_deferred("queue_free")

func _spawn_gem() -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var gem: Node = null
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_EXPERIENCE_GEM):
		gem = PoolManager.get_pooled_object(PoolManager.POOL_KEY_EXPERIENCE_GEM)
	else:
		if exp_gem_scene:
			gem = exp_gem_scene.instantiate()
			tree.current_scene.add_child(gem)
	if gem:
		gem.global_position = global_position
		if "experience_value" in gem:
			gem.experience_value = 1

func _spawn_health_potion() -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var potion: Node = null
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_HEALTH_POTION):
		potion = PoolManager.get_pooled_object(PoolManager.POOL_KEY_HEALTH_POTION)
	else:
		potion = health_potion_scene.instantiate() if health_potion_scene else null
	if potion:
		if potion.get_parent():
			potion.get_parent().remove_child(potion)
		tree.current_scene.add_child(potion)
		potion.global_position = global_position

func _spawn_magnet() -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene or not magnet_scene:
		return
	var magnet = magnet_scene.instantiate()
	if magnet.get_parent():
		magnet.get_parent().remove_child(magnet)
	tree.current_scene.add_child(magnet)
	magnet.global_position = global_position

# =========================
# ANIMACIONES
# =========================
func update_walk_animation(_direction: Vector2) -> void:
	# Enemigos estáticos: sin rotación ni animación de caminar
	pass


func _exit_tree() -> void:
	# Desconectar signals para evitar leaks y lógica zombie
	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if hurtbox.body_entered.is_connected(_on_body_entered):
			hurtbox.body_entered.disconnect(_on_body_entered)
		if hurtbox.body_exited.is_connected(_on_body_exited):
			hurtbox.body_exited.disconnect(_on_body_exited)
	if damageable and is_instance_valid(damageable):
		if damageable.died.is_connected(_on_died):
			damageable.died.disconnect(_on_died)
		if damageable.health_changed.is_connected(_on_health_changed):
			damageable.health_changed.disconnect(_on_health_changed)
	dealing_damage = false
	player_ref = null
	target = null
