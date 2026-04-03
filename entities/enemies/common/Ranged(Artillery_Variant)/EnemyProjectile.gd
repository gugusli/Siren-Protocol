extends Area2D

## =========================
## Proyectil de Enemigo (Artillero)
## =========================

var damage := 8.0
var speed := 200.0
var direction := Vector2.ZERO
var lifetime := 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Auto-destruir después de lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	# Solo daña al jugador
	if body.is_in_group("player") or body.name == "Player":
		var player_damageable = body.get_node_or_null("Damageable")
		if player_damageable:
			player_damageable.take_damage(damage, self)
		
		# Efecto visual de impacto
		_spawn_impact_effect()
		queue_free()

func _spawn_impact_effect() -> void:
	# Pequeño screen shake
	get_tree().call_group("camera", "shake", 3.0, 0.1)
