extends Area2D

# =========================
# PROYECTIL QUE REBOTA
# VERSIÓN CORREGIDA: Memory leaks arreglados + Object pooling mejorado
# =========================
@export var speed: float = 800.0
@export var lifetime: float = 5.0
@export var max_bounces := 3

var damage: float = 10.0
var direction: Vector2 = Vector2.ZERO
var bounces_left: int = 3
var has_hit_enemies: Array[Node2D] = []
var _in_pool := false 
var _lifetime_remaining := 0.0

# =========================
# SETTERS
# =========================
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func set_damage(amount: float) -> void:
	damage = amount

func set_bounces(amount: int) -> void:
	bounces_left = amount
	max_bounces = amount

# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	# ⚠️ IMPORTANTE: NO conectar señales aquí cuando se usa pooling
	# Las señales se conectan en restart_for_reuse()
	_lifetime_remaining = lifetime
	set_physics_process(false)  # Desactivado hasta restart_for_reuse

## ⭐ NUEVO: Método crítico para object pooling
func restart_for_reuse() -> void:
	_in_pool = false
	has_hit_enemies.clear()
	bounces_left = max_bounces
	_lifetime_remaining = lifetime
	
	# Reconectar señales (pueden haberse desconectado en _release_to_pool)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Restaurar collision layers (PoolManager las pone en 0)
	collision_layer = 4   # Bullets layer
	collision_mask = 2    # Enemies layer
	monitoring = true
	monitorable = true
	
	# Resetear visual
	modulate = Color.WHITE
	scale = Vector2.ONE
	
	# Activar física
	set_physics_process(true)

## ⭐ ARREGLADO: Ahora desconecta señales para evitar memory leaks
func _release_to_pool() -> void:
	if _in_pool:
		return
	_in_pool = true
	
	# ⭐ CRÍTICO: Desconectar TODAS las señales antes de devolver al pool
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	
	# Limpiar array de enemigos golpeados
	has_hit_enemies.clear()
	
	# Desactivar física
	set_physics_process(false)
	
	# Devolver al pool
	if PoolManager and PoolManager.is_initialized():
		PoolManager.release_bouncing_bullet(self)
	else:
		queue_free()

# =========================
# FÍSICA Y REBOTES
# =========================
func _physics_process(delta: float) -> void:
	if _in_pool:  # Si está en el pool, no procesar
		return
	
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_release_to_pool()
		return
	var movement = direction * speed * delta
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + movement)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		if bounces_left > 0:
			var normal = result.normal
			direction = direction.bounce(normal)
			bounces_left -= 1
			rotation = direction.angle()
		else:
			_release_to_pool()
	else:
		global_position += movement

# =========================
# DAÑO (Área2D) + críticos, lifesteal, elementales
# =========================
func _on_body_entered(body: Node2D) -> void:
	if !is_inside_tree() or _in_pool:
		return
	
	var damageable = body.get_node_or_null("Damageable")
	if not damageable or body in has_hit_enemies:
		return
	
	has_hit_enemies.append(body)
	
	var crit_chance := 0.05
	var crit_mult := 1.5
	if UpgradeManager:
		crit_chance = UpgradeManager.stats.crit_chance
		crit_mult = UpgradeManager.stats.crit_damage
	var is_crit := randf() < crit_chance
	var final_damage := damage * (crit_mult if is_crit else 1.0)
	
	damageable.take_damage(final_damage)
	
	if UpgradeManager:
		if UpgradeManager.stats.has_fire and body.has_method("apply_burn"):
			body.apply_burn(3.0, 15.0)
		if UpgradeManager.stats.has_ice and body.has_method("apply_slow"):
			body.apply_slow(2.0, 0.7)
		if UpgradeManager.stats.has_poison and body.has_method("apply_poison"):
			body.apply_poison(5.0, 10.0)
		if UpgradeManager.stats.lifesteal > 0:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				var pd = player.get_node_or_null("Damageable")
				if pd:
					pd.heal(final_damage * UpgradeManager.stats.lifesteal)
	
	if body.has_method("apply_knockback"):
		var kb_dir: Vector2 = (body.global_position - global_position).normalized()
		body.apply_knockback(kb_dir)
	
	if VFXManager:
		VFXManager.play_hit_effect(body.global_position, final_damage, is_crit)
