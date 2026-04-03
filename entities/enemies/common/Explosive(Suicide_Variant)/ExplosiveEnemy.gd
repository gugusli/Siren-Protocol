extends CharacterBody2D

## =========================
## EXPLOSIVO - Enemigo Suicida
## Según GDD: Criatura pequeña e inestable
## Vida: 15 HP | Daño: 25 en área al explotar
## =========================

signal enemy_died(enemy)

# =========================
# CONFIGURACIÓN
# =========================
@export_group("Movimiento")
@export var speed := 120.0  # Más rápido que el normal

@export_group("Explosión")
@export var explosion_damage := 25.0
@export var explosion_radius := 80.0
@export var fuse_time := 0.5  # Tiempo antes de explotar al tocar

@export_group("Visual")
@export var warning_blink_speed := 0.15  # Velocidad de parpadeo de advertencia

@export_group("Drops")
@export var exp_gem_scene: PackedScene

# =========================
# REFERENCIAS
# =========================
@onready var sprite_visual: Sprite2D = $Sprite2D
@onready var damageable := $Damageable

var target: Node2D = null
var dead := false
var is_exploding := false
var touching_player := false

# =========================
# READY
# =========================
func _ready() -> void:
	# Agregar al grupo de enemigos
	add_to_group("enemies")
	
	if sprite_visual and sprite_visual.material:
		sprite_visual.material = sprite_visual.material.duplicate()
	
	damageable.died.connect(_on_died)
	damageable.health_changed.connect(_on_health_changed)
	
	# Configurar stats según GDD
	damageable.max_health = 15
	damageable.health = 15
	
	# Conectar colisión
	$Hurtbox.body_entered.connect(_on_body_entered)
	$Hurtbox.body_exited.connect(_on_body_exited)
	
	# Color distintivo (amarillo/naranja para indicar peligro)
	if sprite_visual:
		sprite_visual.modulate = Color("#FFAA00")

func _physics_process(_delta: float) -> void:
	if target == null or dead or is_exploding:
		return
	
	# Movimiento directo hacia el jugador (más rápido)
	var direction := (target.global_position - global_position).normalized()
	velocity = direction * speed
	
	move_and_slide()

# =========================
# COLISIÓN CON JUGADOR
# =========================
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player":
		touching_player = true
		_start_explosion()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player":
		touching_player = false

func _start_explosion() -> void:
	if is_exploding or dead:
		return
	
	is_exploding = true
	velocity = Vector2.ZERO
	
	# Parpadeo de advertencia
	_warning_blink()
	
	# Explotar después del tiempo de mecha
	await get_tree().create_timer(fuse_time).timeout
	
	if not dead:
		_explode()

func _warning_blink() -> void:
	var blinks := int(fuse_time / warning_blink_speed)
	for i in range(blinks):
		if dead:
			return
		sprite_visual.modulate = Color.RED
		await get_tree().create_timer(warning_blink_speed / 2).timeout
		sprite_visual.modulate = Color("#FFAA00")
		await get_tree().create_timer(warning_blink_speed / 2).timeout

# =========================
# EXPLOSIÓN
# =========================
func _explode() -> void:
	if dead:
		return
	
	dead = true
	
	if VFXManager:
		VFXManager.shake_on_explosion()
		VFXManager.hitstop_explosion()
	
	# Dañar a todo en el radio (incluyendo jugador)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0, global_position)
	
	# Buscar cuerpos en el área
	var results = space_state.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body.is_in_group("player") or body.name == "Player":
			var player_damageable = body.get_node_or_null("Damageable")
			if player_damageable:
				player_damageable.take_damage(explosion_damage, self)
	
	# Efecto visual de explosión
	_spawn_explosion_effect()
	
	# Drop gema (siempre)
	if exp_gem_scene:
		_spawn_drop(exp_gem_scene)
	
	emit_signal("enemy_died", self)
	
	# Registrar kill
	if DirectorAI:
		DirectorAI.register_kill()
	
	queue_free()

func _spawn_explosion_effect() -> void:
	# Crear efecto visual simple
	var explosion = Sprite2D.new()
	explosion.texture = PlaceholderTexture2D.new()
	explosion.texture.size = Vector2(explosion_radius * 2, explosion_radius * 2)
	explosion.modulate = Color("#FF6600", 0.8)
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	
	# Animar y destruir
	var tween = explosion.create_tween()
	tween.parallel().tween_property(explosion, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(explosion, "modulate:a", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)

# =========================
# DAÑO (Si lo matan antes de explotar)
# =========================
func _on_health_changed(current: float, max_hp: float) -> void:
	if current < max_hp and current > 0:
		_flash()

func _flash() -> void:
	if sprite_visual:
		if sprite_visual.material and sprite_visual.material.has_method("set_shader_parameter"):
			sprite_visual.material.set_shader_parameter("flash_modifier", 1.0)
			await get_tree().create_timer(0.08).timeout
			if is_instance_valid(sprite_visual) and sprite_visual.material:
				sprite_visual.material.set_shader_parameter("flash_modifier", 0.0)
		else:
			# Fallback: simple modulate flash
			sprite_visual.modulate = Color(2.0, 2.0, 2.0)
			await get_tree().create_timer(0.08).timeout
			if is_instance_valid(sprite_visual):
				sprite_visual.modulate = Color("#FFAA00")

func _on_died() -> void:
	if dead:
		return
	
	# Al morir, también explota!
	_explode()

func _spawn_drop(scene: PackedScene) -> void:
	var drop = scene.instantiate()
	get_tree().current_scene.call_deferred("add_child", drop)
	drop.global_position = global_position

# =========================
# KNOCKBACK (limitado)
# =========================
func apply_knockback(from_direction: Vector2) -> void:
	# Knockback reducido para explosivos
	velocity += from_direction.normalized() * 80.0
