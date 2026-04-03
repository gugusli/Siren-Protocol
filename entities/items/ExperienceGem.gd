extends Area2D

# =========================
# GEMA DE EXPERIENCIA
# VERSIÓN CORREGIDA: Memory leaks arreglados + Object pooling mejorado
# =========================

@export var experience_value := 10
@export var attraction_speed := 400.0

var target: Node2D = null
var being_collected := false
var _in_pool := false

func _ready() -> void:
	# Agregamos al grupo para que el imán pueda encontrarlas
	add_to_group("experience_gem")
	# ⚠️ IMPORTANTE: NO conectar señales aquí cuando se usa pooling
	# Las señales se conectan en restart_for_reuse()
	set_process(false)  # Desactivado hasta restart_for_reuse

## ⭐ NUEVO: Método crítico para object pooling
func restart_for_reuse() -> void:
	_in_pool = false
	target = null
	being_collected = false
	
	# Reconectar señales (pueden haberse desconectado en _release_to_pool)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Restaurar collision layers
	# Gemas detectan jugador (capa 1), no enemigos
	collision_layer = 4   # Items layer
	collision_mask = 1    # Player layer
	monitoring = true
	monitorable = true
	
	# Resetear visual
	modulate = Color.WHITE
	scale = Vector2.ONE
	
	# Activar proceso
	set_process(true)

func set_attraction_speed(new_speed: float) -> void:
	attraction_speed = new_speed

func _on_body_entered(body: Node2D) -> void:
	if _in_pool:
		return
	
	# Verificamos que sea el jugador
	if body.name == "Player" or body.has_method("add_experience"):
		target = body
		being_collected = true

func _process(delta: float) -> void:
	if _in_pool:  # Si está en el pool, no procesar
		return
	
	# Si el jugador entró en el área, la gema se mueve hacia él
	if being_collected and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		global_position += direction * attraction_speed * delta
		
		# Si está lo suficientemente cerca, se consume
		if global_position.distance_to(target.global_position) < 15.0:
			collect()

func collect() -> void:
	if _in_pool:
		return
	
	if target and target.has_method("add_experience"):
		target.add_experience(experience_value)
	_release_to_pool()

## ⭐ ARREGLADO: Ahora desconecta señales para evitar memory leaks
func _release_to_pool() -> void:
	if _in_pool:
		return
	_in_pool = true
	
	# ⭐ CRÍTICO: Desconectar TODAS las señales antes de devolver al pool
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	
	# Limpiar referencia al target
	target = null
	being_collected = false
	
	# Desactivar proceso
	set_process(false)
	
	# Devolver al pool
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_EXPERIENCE_GEM):
		PoolManager.return_to_pool(self)
	else:
		queue_free()
