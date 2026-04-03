extends CharacterBody2D

## =========================
## ARTILLERO - Enemigo a Distancia
## Según GDD: Flotante, mantiene distancia, dispara proyectiles lentos
## Vida: 30 HP | Daño: 8 por proyectil
## =========================

signal enemy_died(enemy)

# =========================
# CONFIGURACIÓN
# =========================
@export_group("Movimiento")
@export var speed := 60.0
@export var preferred_distance := 300.0  # Distancia que intenta mantener
@export var distance_tolerance := 50.0   # Margen de distancia

@export_group("Combate")
@export var projectile_damage := 8.0
@export var fire_rate := 2.0  # Segundos entre disparos
@export var projectile_speed := 200.0

@export_group("Drops")
@export var exp_gem_scene: PackedScene
@export var health_potion_scene: PackedScene
@export var drop_chance_health := 0.08  # 8% (más que enemigo normal)

# =========================
# REFERENCIAS
# =========================
@onready var sprite_visual: AnimatedSprite2D = $AnimatedSprite2D
@onready var damageable := $Damageable

var target: Node2D = null
var dead := false
var can_fire := true
var is_moving := false
var is_attacking := false

# =========================
# READY
# =========================
func _ready() -> void:
	# Agregar al grupo de enemigos
	add_to_group("enemies")
	
	# Buscar target (jugador)
	target = get_tree().get_first_node_in_group("player")
	if not target:
		target = get_tree().current_scene.get_node_or_null("Player")
	
	# Configurar animaciones
	if sprite_visual:
		_setup_animations()
		if sprite_visual.material:
			sprite_visual.material = sprite_visual.material.duplicate()
	
	damageable.died.connect(_on_died)
	damageable.health_changed.connect(_on_health_changed)
	
	# Configurar stats según GDD
	damageable.max_health = 30
	damageable.health = 30
	
	# Iniciar loop de disparo
	_fire_loop()
	
	# Iniciar con animación idle
	_update_animation()

func _setup_animations() -> void:
	if not sprite_visual:
		return
	
	# Crear SpriteFrames si no existe
	if not sprite_visual.sprite_frames:
		sprite_visual.sprite_frames = SpriteFrames.new()
	
	var frames = sprite_visual.sprite_frames
	
	# Animación Idle
	if not frames.has_animation("idle"):
		frames.add_animation("idle")
		frames.set_animation_speed("idle", 4.0)
		frames.set_animation_loop("idle", true)
		var idle_texture = load("res://assets/sprites/enemies/artillery/Idle.png")
		if idle_texture:
			frames.add_frame("idle", idle_texture)
	
	# Animación Walk
	if not frames.has_animation("walk"):
		frames.add_animation("walk")
		frames.set_animation_speed("walk", 6.0)
		frames.set_animation_loop("walk", true)
		var walk_texture = load("res://assets/sprites/enemies/artillery/Walk.png")
		if walk_texture:
			frames.add_frame("walk", walk_texture)
	
	# Animación Attack
	if not frames.has_animation("attack"):
		frames.add_animation("attack")
		frames.set_animation_speed("attack", 8.0)
		frames.set_animation_loop("attack", false)
		var attack1 = load("res://assets/sprites/enemies/artillery/Attack1.png")
		var attack2 = load("res://assets/sprites/enemies/artillery/Attack2.png")
		var attack3 = load("res://assets/sprites/enemies/artillery/Attack3.png")
		var attack4 = load("res://assets/sprites/enemies/artillery/Attack4.png")
		if attack1: frames.add_frame("attack", attack1)
		if attack2: frames.add_frame("attack", attack2)
		if attack3: frames.add_frame("attack", attack3)
		if attack4: frames.add_frame("attack", attack4)
	
	# Animación Hurt
	if not frames.has_animation("hurt"):
		frames.add_animation("hurt")
		frames.set_animation_speed("hurt", 10.0)
		frames.set_animation_loop("hurt", false)
		var hurt_texture = load("res://assets/sprites/enemies/artillery/Hurt.png")
		if hurt_texture:
			frames.add_frame("hurt", hurt_texture)
	
	# Animación Death
	if not frames.has_animation("death"):
		frames.add_animation("death")
		frames.set_animation_speed("death", 6.0)
		frames.set_animation_loop("death", false)
		var death_texture = load("res://assets/sprites/enemies/artillery/Death.png")
		if death_texture:
			frames.add_frame("death", death_texture)
	
	# Conectar señal de animación terminada
	if sprite_visual.animation_finished.is_connected(_on_animation_finished) == false:
		sprite_visual.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta: float) -> void:
	if target == null or dead:
		return
	
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	var direction := to_target.normalized()
	
	# Movimiento: mantener distancia preferida
	var was_moving = is_moving
	if distance < preferred_distance - distance_tolerance:
		# Muy cerca: alejarse
		velocity = -direction * speed
		is_moving = true
	elif distance > preferred_distance + distance_tolerance:
		# Muy lejos: acercarse
		velocity = direction * speed * 0.7
		is_moving = true
	else:
		# Distancia correcta: orbitar lentamente
		var perpendicular := Vector2(-direction.y, direction.x)
		velocity = perpendicular * speed * 0.3
		is_moving = velocity.length() > 10.0
	
	move_and_slide()
	
	# Siempre mirar al jugador
	if sprite_visual:
		sprite_visual.rotation = direction.angle() + PI/2
	
	# Actualizar animación si cambió el estado de movimiento
	if was_moving != is_moving:
		_update_animation()

# =========================
# DISPARO
# =========================
func _fire_loop() -> void:
	while is_inside_tree() and not dead:
		var tree := get_tree()
		if not tree:
			break
		await tree.create_timer(fire_rate).timeout
		if dead or not is_instance_valid(target):
			continue
		if can_fire:
			_shoot()

func _shoot() -> void:
	if not target or dead:
		return
	var tree := get_tree()
	if not tree:
		return
	
	# Reproducir animación de ataque
	is_attacking = true
	_update_animation()
	
	# Esperar un frame para que la animación empiece
	await get_tree().process_frame
	
	# Crear proyectil enemigo
	var projectile = _create_enemy_projectile()
	if projectile:
		tree.current_scene.add_child(projectile)
		projectile.global_position = global_position
		
		var direction = (target.global_position - global_position).normalized()
		projectile.set_direction(direction)
		
		# Visual feedback
		_flash_shoot()

func _create_enemy_projectile() -> Node2D:
	# Crear proyectil simple como Area2D
	var proj = Area2D.new()
	proj.set_script(preload("res://entities/enemies/common/Ranged(Artillery_Variant)/EnemyProjectile.gd"))
	
	# Sprite del proyectil
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.texture.size = Vector2(12, 12)
	sprite.modulate = Color("#FF6600")  # Naranja
	proj.add_child(sprite)
	
	# Colisión
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 6
	collision.shape = shape
	proj.add_child(collision)
	
	# Configurar
	proj.set("damage", projectile_damage)
	proj.set("speed", projectile_speed)
	
	return proj

func _flash_shoot() -> void:
	# El flash ahora se maneja con la animación de ataque
	# Mantener para compatibilidad pero simplificado
	if sprite_visual and sprite_visual.material:
		sprite_visual.material.set_shader_parameter("flash_modifier", 1.0)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite_visual) and sprite_visual.material:
			sprite_visual.material.set_shader_parameter("flash_modifier", 0.0)

# =========================
# DAÑO Y MUERTE
# =========================
func _on_health_changed(current: float, max_hp: float) -> void:
	if current < max_hp and current > 0:
		_flash()
		# Reproducir animación de daño
		if sprite_visual and sprite_visual.sprite_frames.has_animation("hurt"):
			sprite_visual.play("hurt")

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
				sprite_visual.modulate = Color.WHITE

func _on_died() -> void:
	if dead:
		return
	
	dead = true
	can_fire = false
	set_physics_process(false)
	
	# Reproducir animación de muerte
	if sprite_visual and sprite_visual.sprite_frames.has_animation("death"):
		sprite_visual.play("death")
		await sprite_visual.animation_finished
	
	# Drops
	if exp_gem_scene:
		_spawn_drop(exp_gem_scene)
	
	if health_potion_scene and randf() < drop_chance_health:
		_spawn_drop(health_potion_scene)
	
	emit_signal("enemy_died", self)
	
	# Registrar kill en DirectorAI
	if DirectorAI:
		DirectorAI.register_kill()
	
	visible = false
	queue_free()

func _spawn_drop(scene: PackedScene) -> void:
	var tree := get_tree()
	if not tree:
		return
	var drop = scene.instantiate()
	tree.current_scene.call_deferred("add_child", drop)
	drop.global_position = global_position

# =========================
# KNOCKBACK
# =========================
var knockback_velocity := Vector2.ZERO
var knockback_friction := 900.0

func apply_knockback(from_direction: Vector2) -> void:
	knockback_velocity += from_direction.normalized() * 150.0

# =========================
# ANIMACIONES
# =========================
func _update_animation() -> void:
	if not sprite_visual or dead:
		return
	
	if is_attacking:
		if sprite_visual.sprite_frames.has_animation("attack"):
			sprite_visual.play("attack")
		return
	
	# Enemigo estático: siempre usar idle cuando no está atacando
	if sprite_visual.sprite_frames.has_animation("idle"):
		sprite_visual.play("idle")

func _on_animation_finished() -> void:
	if not sprite_visual:
		return
	
	# Cuando termina la animación de ataque, volver a idle/walk
	if sprite_visual.animation == "attack":
		is_attacking = false
		_update_animation()
	elif sprite_visual.animation == "hurt":
		# Después de hurt, volver a la animación anterior
		_update_animation()
