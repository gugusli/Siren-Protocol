extends Node2D

# =========================
# ARMA: AJO (Área de Daño)
# =========================
@export var damage := 15.0
@export var radius := 150.0
@export var tick_rate := 0.5 # Cada cuánto tiempo hace daño
@export var damage_interval := 0.5

var player: Node2D = null
var damage_area: Area2D = null
var enemies_inside: Array[Node2D] = []
var is_active := false

func _ready() -> void:
	# Buscamos al jugador
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
	
	if not player:
		push_error("GarlicWeapon: No se encontró al jugador")
		return
	
	# Creamos el área de daño
	damage_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision.shape = circle_shape
	damage_area.add_child(collision)
	add_child(damage_area)
	
	# Configuramos las capas de colisión
	damage_area.collision_layer = 0
	damage_area.collision_mask = 2 # Capa de enemigos
	
	# Conectamos señales
	damage_area.body_entered.connect(_on_body_entered)
	damage_area.body_exited.connect(_on_body_exited)
	
	# Iniciamos el loop de daño
	start_damage_loop()

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		global_position = player.global_position

func _on_body_entered(body: Node2D) -> void:
	if body.has_node("Damageable") and body != player:
		if body not in enemies_inside:
			enemies_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	enemies_inside.erase(body)

func start_damage_loop() -> void:
	while is_inside_tree():
		if GameManager.game_state == GameManager.GameState.PLAYING:
			deal_damage_to_enemies()
		await get_tree().create_timer(tick_rate).timeout

func deal_damage_to_enemies() -> void:
	for enemy in enemies_inside.duplicate():
		if not is_instance_valid(enemy):
			enemies_inside.erase(enemy)
			continue
		
		var damageable = enemy.get_node_or_null("Damageable")
		if damageable:
			damageable.take_damage(damage)
			
			# Knockback (tipo explícito para evitar error de inferencia)
			if enemy.has_method("apply_knockback"):
				var kb_dir: Vector2 = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(kb_dir)
