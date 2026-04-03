extends Node2D

# Referencia a la cámara hija
@onready var camera := $Camera2D

# --- Variables para el Shake ---
var time_left := 0.0
var strength := 0.0
var shake_frequency := 15.0  # Hz para shake_advanced
var base_offset := Vector2.ZERO
var _shake_accum := 0.0

# --- Referencia al Jugador ---
var player: Node2D = null

func _ready():
	base_offset = camera.offset
	
	# Buscamos al jugador de forma segura (primero por grupo, luego por nombre)
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		push_warning("CameraController: No se encontró al jugador")
	
	# Se añade automáticamente al grupo para que el Player pueda llamarlo
	add_to_group("camera")

func _process(delta):
	# 1. SEGUIMIENTO DEL JUGADOR
	if is_instance_valid(player):
		# Usamos lerp para que el movimiento sea fluido (Game Feel)
		# 0.1 es la velocidad de seguimiento. Más alto = más rígido.
		global_position = global_position.lerp(player.global_position, 0.1)

	# 2. LÓGICA DE SHAKE
	if time_left > 0:
		time_left -= delta
		_shake_accum += delta * shake_frequency
		if _shake_accum >= 1.0 / maxf(shake_frequency, 1.0):
			_shake_accum = 0.0
			camera.offset = base_offset + Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
		else:
			# Mantener offset hasta próximo tick de frecuencia
			pass
	else:
		camera.offset = base_offset

func shake(amount: float, duration: float) -> void:
	strength = amount
	time_left = duration
	shake_frequency = 15.0

func shake_advanced(intensity: float, duration: float, frequency: float = 15.0) -> void:
	strength = intensity
	time_left = duration
	shake_frequency = clampf(frequency, 1.0, 30.0)
