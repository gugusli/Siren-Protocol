extends Area2D

## =========================
## Proyectil del jugador
## VERSIÓN CORREGIDA: Memory leaks arreglados + Object pooling mejorado
## =========================

# =========================
# CONFIGURACIÓN
# =========================
@export var speed: float = 800.0
@export var lifetime: float = 3.0

var damage: float = 60.0
var direction: Vector2 = Vector2.ZERO
var pierce_count: int = 0
var _in_pool := false
var _lifetime_remaining := 0.0

# Sistema de críticos
var crit_chance: float = 0.05  # 5% base
var crit_damage_mult: float = 1.5  # 150% base

# VÉRTICE backstab (GDD §7.3): jugador que disparó (para detección por la espalda)
var source_player: Node = null

# RÁFAGA MORTAL: contar cuántos enemigos ha atravesado esta bala
var _pierced_enemies_count: int = 0

# =========================
# SETTERS
# =========================
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func set_damage(amount: float) -> void:
	damage = amount

func set_pierce(amount: int) -> void:
	pierce_count = amount

func set_source_player(player: Node) -> void:
	source_player = player

# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	# ⚠️ IMPORTANTE: NO conectar señales aquí cuando se usa pooling
	# Las señales se conectan en restart_for_reuse()
	_lifetime_remaining = lifetime
	set_physics_process(false)  # Desactivado hasta restart_for_reuse

## ⭐ NUEVO: Método crítico para object pooling
## Se llama cada vez que la bala sale del pool
func restart_for_reuse() -> void:
	_in_pool = false
	_lifetime_remaining = lifetime
	pierce_count = 0
	source_player = null
	_pierced_enemies_count = 0
	
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

func _physics_process(delta: float) -> void:
	if _in_pool:  # Si está en el pool, no procesar
		return
	
	global_position += direction * speed * delta
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_release_to_pool()

# =========================
# COLISIÓN
# =========================
func _on_body_entered(body: Node2D) -> void:
	if !is_inside_tree() or _in_pool:
		return

	var damageable = body.get_node_or_null("Damageable")
	if damageable:
		# Obtener stats de UpgradeManager
		if UpgradeManager:
			crit_chance = UpgradeManager.stats.crit_chance
			crit_damage_mult = UpgradeManager.stats.crit_damage
		
		# RÁFAGA MORTAL: bonus de daño por enemigos ya atravesados
		var base_damage := damage
		if UpgradeManager and UpgradeManager.has_synergy("deadly_burst") and _pierced_enemies_count > 0:
			var bonus_mult: float = 1.0 + min(0.15 * float(_pierced_enemies_count), 0.60)
			base_damage *= bonus_mult
		
		var is_critical := false
		# REFLEJO MORTAL: críticos garantizados post-dash
		if source_player and source_player.has_method("consume_post_dash_crit") and source_player.consume_post_dash_crit():
			is_critical = true
		else:
			is_critical = randf() < crit_chance
		
		var final_damage := base_damage * (crit_damage_mult if is_critical else 1.0)
		
		# VÉRTICE (GDD §7.3): ataque por la espalda +50% daño y crítico garantizado
		if source_player and source_player.get("character_type") == "VÉRTICE":
			if _is_backstab(body.global_position, global_position, direction):
				final_damage *= 1.5
				is_critical = true
		
		# Aplicar daño
		damageable.take_damage(final_damage)
		
		# Efectos elementales (UpgradeManager)
		if UpgradeManager:
			if UpgradeManager.stats.has_fire and body.has_method("apply_burn"):
				body.apply_burn(3.0, 15.0)
			if UpgradeManager.stats.has_ice and body.has_method("apply_slow"):
				body.apply_slow(2.0, 0.7)
			if UpgradeManager.stats.has_poison and body.has_method("apply_poison"):
				body.apply_poison(5.0, 10.0)
			# CONGELACIÓN PROFUNDA: críticos en enemigos ralentizados los congelan
			if UpgradeManager.has_synergy("deep_freeze") and is_critical and body.has_method("is_slowed") and body.has_method("apply_freeze"):
				if body.is_slowed():
					body.apply_freeze(2.0)
			if UpgradeManager.stats.has_chain_lightning:
				_apply_chain_lightning(body, final_damage * 0.6)
			if UpgradeManager.stats.has_explosive:
				_apply_explosion(body.global_position, final_damage * 0.5)
		
		# VFX según GDD §6.2
		if VFXManager:
			var hit_pos := body.global_position
			var hit_dir := (hit_pos - global_position).normalized()
			if is_critical:
				VFXManager.shake_on_critical_hit()
				VFXManager.slowmo_on_critical()
				VFXManager.hitstop_critical()
				VFXManager.flash_on_critical()
				VFXManager.spawn_impact_sparks_critical(hit_pos, hit_dir)
				VFXManager.spawn_damage_number(hit_pos, int(final_damage), true)
			else:
				VFXManager.shake_on_bullet_impact()
				VFXManager.hitstop_normal()
				VFXManager.spawn_impact_sparks_normal(hit_pos, hit_dir)
				VFXManager.spawn_damage_number(hit_pos, int(final_damage), false)
		
		# ✅ FIX: Tipo explícito float para heal_amount (línea 143)
		if UpgradeManager and UpgradeManager.stats.lifesteal > 0:
			var heal_amount: float = final_damage * UpgradeManager.stats.lifesteal
			if is_critical and UpgradeManager.has_synergy("vampirismo_mejorado"):
				heal_amount *= 3.0
			var player := get_tree().get_first_node_in_group("player")
			if player:
				var player_damageable = player.get_node_or_null("Damageable")
				if player_damageable:
					player_damageable.heal(heal_amount)

		# ✅ FIX: Tipo explícito Vector2 para kb_dir (línea 210)
		if body.has_method("apply_knockback"):
			var kb_dir: Vector2 = (body.global_position - global_position).normalized()
			var kb_strength := 1.5 if is_critical else 1.0
			body.apply_knockback(kb_dir * kb_strength)

		# Perforación
		if pierce_count > 0:
			pierce_count -= 1
			damage = damage * 0.8
			_pierced_enemies_count += 1
		else:
			_release_to_pool()

func _apply_chain_lightning(exclude_body: Node2D, chain_damage: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var near_enemies: Array[Node2D] = []
	for node in enemies:
		if not node is Node2D or node == exclude_body or not is_instance_valid(node):
			continue
		var dmg = node.get_node_or_null("Damageable")
		if dmg and node.global_position.distance_squared_to(global_position) < 120000.0:  # ~346 px
			near_enemies.append(node)
	near_enemies.sort_custom(func(a, b): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	for i in range(min(3, near_enemies.size())):
		var target_dmg = near_enemies[i].get_node_or_null("Damageable")
		if target_dmg:
			target_dmg.take_damage(chain_damage)
			if VFXManager:
				VFXManager.play_hit_effect(near_enemies[i].global_position, chain_damage, false)

func _find_nearest_enemy_for_chain(center: Vector2, search_radius: float) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_pos := center
	var best_dist_sq := search_radius * search_radius
	for node in enemies:
		if not node is Node2D or not is_instance_valid(node):
			continue
		var d_sq := center.distance_squared_to(node.global_position)
		if d_sq < best_dist_sq and node.get_node_or_null("Damageable"):
			best_dist_sq = d_sq
			best_pos = node.global_position
	return best_pos

func _apply_explosion_damage_only(center: Vector2, radius: float, explosion_damage: float) -> void:
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
		var dmg = collider.get_node_or_null("Damageable")
		if dmg:
			dmg.take_damage(explosion_damage)
		if collider.has_method("apply_knockback"):
			var kb_dir: Vector2 = (collider.global_position - center).normalized()
			collider.apply_knockback(kb_dir)

func _apply_explosion(center: Vector2, explosion_damage: float) -> void:
	var area_mult := 1.0
	if UpgradeManager:
		area_mult = UpgradeManager.stats.area_mult
	var radius := 80.0 * area_mult
	_apply_explosion_damage_only(center, radius, explosion_damage)
	if VFXManager:
		VFXManager.shake_on_explosion()
		VFXManager.hitstop_explosion()
		VFXManager.spawn_explosion_particles(center, radius)
		VFXManager.play_explosion_effect(center, radius)
	
	# Sinergia ARTILLERÍA INFERNAL: 40% probabilidad de segunda explosión
	if UpgradeManager and UpgradeManager.has_synergy("artilleria_infernal") and randf() < 0.40:
		var second_center := _find_nearest_enemy_for_chain(center, radius * 2.0)
		if second_center != center:
			var second_radius := radius * 0.75
			var second_damage := explosion_damage * 0.6
			_apply_explosion_damage_only(second_center, second_radius, second_damage)
			if VFXManager:
				VFXManager.play_explosion_effect(second_center, second_radius)

func _is_backstab(enemy_position: Vector2, bullet_origin: Vector2, shot_direction: Vector2) -> bool:
	# El enemigo "mira" hacia el jugador (donde vino la bala). Por la espalda = disparo desde atrás.
	var to_attacker := (bullet_origin - enemy_position).normalized()
	var enemy_facing := to_attacker  # enemigo mira al atacante
	# Ataque por la espalda: el disparo viene en dirección opuesta a donde mira el enemigo
	var dot_val := shot_direction.dot(enemy_facing)
	return dot_val < -0.5

## ⭐ ARREGLADO: Ahora desconecta señales para evitar memory leaks
func _release_to_pool() -> void:
	if _in_pool:
		return
	_in_pool = true
	
	# ⭐ CRÍTICO: Desconectar TODAS las señales antes de devolver al pool
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	
	# Desactivar física (optimización)
	set_physics_process(false)
	
	# Devolver al pool
	if PoolManager and PoolManager.is_initialized():
		PoolManager.release_bullet(self)
	else:
		queue_free()
