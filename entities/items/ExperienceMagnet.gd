extends Node2D

# =========================
# IMÁN DE EXPERIENCIA
# =========================
@export var duration := 10.0
@export var attraction_radius := 500.0
@export var attraction_speed_multiplier := 3.0

var player: Node2D = null
var is_active := false

func _ready() -> void:
	# Buscamos al jugador
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
	
	if not player:
		push_error("ExperienceMagnet: No se encontró al jugador")
		return
	
	activate()

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		global_position = player.global_position
		
		if is_active:
			attract_experience_gems()

func activate() -> void:
	is_active = true
	# Después de la duración, se desactiva
	await get_tree().create_timer(duration).timeout
	is_active = false
	queue_free()

func attract_experience_gems() -> void:
	# Buscamos todas las gemas de experiencia en la escena
	var gems = get_tree().get_nodes_in_group("experience_gem")
	
	for gem in gems:
		if not is_instance_valid(gem):
			continue
		
		var distance = global_position.distance_to(gem.global_position)
		if distance <= attraction_radius:
			# Aceleramos la gema hacia el jugador
			if gem.has_method("set_attraction_speed"):
				gem.set_attraction_speed(gem.attraction_speed * attraction_speed_multiplier)
