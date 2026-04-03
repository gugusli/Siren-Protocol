extends CharacterBody2D

signal enemy_died(enemy: Node)

const PHASE_1 := 0
const PHASE_2 := 1

@onready var damageable: Node = $Damageable
@onready var sprite: Sprite2D = $Sprite2D

var phase: int = PHASE_1
var player: Node2D = null
var punch_cooldown: float = 0.0
var energy_burst_cooldown: float = 0.0
var _walk_shake_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	if damageable and damageable.has_signal("health_changed"):
		damageable.health_changed.connect(_on_health_changed)
	if damageable and damageable.has_signal("died"):
		damageable.died.connect(_on_died)
	# Movimiento pesado inicial
	phase = PHASE_1
	punch_cooldown = 1.5
	energy_burst_cooldown = 5.0

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	var to_player := (player.global_position - global_position)
	var dir := to_player.normalized()
	var speed := 60.0 if phase == PHASE_1 else 80.0
	velocity = dir * speed
	move_and_slide()
	# Temblor al caminar solo cada ~0.15s para no matar FPS
	_walk_shake_timer -= delta
	if _walk_shake_timer <= 0.0 and VFXManager and VFXManager.has_method("shake_screen_advanced"):
		VFXManager.shake_screen_advanced(1.2, 0.02, 5.0)
		_walk_shake_timer = 0.15
	# Ataques según fase
	if phase == PHASE_1:
		_process_phase_1(delta, to_player.length())
	else:
		_process_phase_2(delta, to_player.length())

func _process_phase_1(delta: float, dist_to_player: float) -> void:
	punch_cooldown -= delta
	if punch_cooldown <= 0.0 and dist_to_player < 140.0:
		_perform_ground_punch()
		punch_cooldown = 2.5

func _process_phase_2(delta: float, dist_to_player: float) -> void:
	# Movimiento un poco más agresivo
	punch_cooldown -= delta
	energy_burst_cooldown -= delta
	if punch_cooldown <= 0.0 and dist_to_player < 160.0:
		_perform_ground_punch()
		punch_cooldown = 2.0
	if energy_burst_cooldown <= 0.0:
		_perform_energy_burst()
		energy_burst_cooldown = 5.0

func _perform_ground_punch() -> void:
	var center := global_position
	var radius := 120.0
	var damage := 30.0
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = 1  # capa jugador
	var results := space.intersect_shape(query, 8)
	for result in results:
		var body: Node2D = result.collider
		if body and body.has_node("Damageable"):
			var dmg = body.get_node_or_null("Damageable")
			if dmg:
				dmg.take_damage(damage, self)
			if body.has_method("apply_knockback"):
				var dir: Vector2 = (body.global_position - center).normalized()
				body.apply_knockback(dir * 2.0)
	if VFXManager:
		VFXManager.shake_on_explosion()

func _perform_energy_burst() -> void:
	var center := global_position
	var radius := 260.0
	var damage := 20.0
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = 1
	var results := space.intersect_shape(query, 16)
	for result in results:
		var body: Node2D = result.collider
		if body and body.has_node("Damageable"):
			var dmg = body.get_node_or_null("Damageable")
			if dmg:
				dmg.take_damage(damage * 3.0, self)
			if body.has_method("apply_knockback"):
				var dir: Vector2 = (body.global_position - center).normalized()
				body.apply_knockback(dir * 3.0)
	if VFXManager:
		VFXManager.shake_screen_advanced(6.0, 0.35, 14.0)

func preprocess_damage(amount: float, _attacker: Node = null) -> float:
	# Fase 2: núcleo expuesto, recibe x3 daño (GDD §5)
	if phase == PHASE_2:
		return amount * 3.0
	return amount

func _on_health_changed(current: float, max_hp: float) -> void:
	if phase == PHASE_1 and current <= max_hp * 0.5:
		_enter_phase_2()

func _enter_phase_2() -> void:
	phase = PHASE_2
	if sprite:
		sprite.modulate = Color(1.2, 0.6, 0.6)
	if VFXManager and VFXManager.has_method("play_boss_phase_transition"):
		VFXManager.play_boss_phase_transition(global_position)

func _on_died() -> void:
	enemy_died.emit(self)
	if DirectorAI:
		DirectorAI.register_kill()
	if GameManager:
		GameManager.add_kill("BOSS_PRIMER_SEDIMENTO")
	queue_free()

