extends Node

func _ready() -> void:
	print("=== TEST: RECLUTA ===")
	
	var recluta_scene := load("res://entities/player/player.tscn") as PackedScene
	if not recluta_scene:
		push_error("No se pudo cargar player.tscn (RECLUTA)")
		_finish(false)
		return
	
	var recluta = recluta_scene.instantiate()
	add_child(recluta)
	await get_tree().process_frame
	
	# Test 1: Estadísticas base
	var damageable = recluta.get_node_or_null("Damageable")
	var max_hp_ok: bool = damageable != null and damageable.max_health == 100
	var speed_ok: bool = recluta.base_speed == 220.0
	var dmg_ok: bool = recluta.base_bullet_damage == 10.0
	
	assert(max_hp_ok, "RECLUTA HP incorrecto")
	assert(speed_ok, "RECLUTA Velocidad incorrecta")
	assert(dmg_ok, "RECLUTA Daño base incorrecto")
	assert(recluta.character_type == "RECLUTA", "character_type debe ser RECLUTA")
	print("  Estadísticas base correctas")
	
	# Test habilidad activa
	recluta.ability_cooldown_remaining = 0.0
	recluta.use_ability()
	await get_tree().create_timer(0.5).timeout
	
	var cooldown_set: bool = recluta.ability_cooldown_remaining > 0
	assert(cooldown_set, "Tras use_ability el cooldown debe estar activo")
	print("  Habilidad activa ejecutada y cooldown aplicado")
	
	print("=== RECLUTA: TODOS LOS TESTS PASARON ===")
	_finish(true)


func _finish(success: bool) -> void:
	if success:
		get_tree().quit()
	else:
		push_error("TEST FALLÓ")
