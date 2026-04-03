extends Node2D

## =========================
## EVENTO: OLEADA DE ÉLITE
## GDD §8.3 - Solo 3-5 enemigos pero todos son élites
## =========================

signal event_ended

# Configuración del evento
@export var elite_count_min := 3
@export var elite_count_max := 5
@export var spawn_radius := 500.0
@export var spawn_delay := 0.4  # Más lento - cada élite es una amenaza

# Referencias
var _arena: Node2D = null
var _player: Node2D = null
var _wave_manager: Node = null
var _spawned_elites: Array[Node] = []

## Método principal - llamado por DirectorAI
func activate(arena: Node2D, player: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_player = player
	_wave_manager = wave_manager
	
	if not _player or not is_instance_valid(_player):
		push_error("EliteWaveEvent: No hay jugador válido")
		event_ended.emit()
		return
	
	if not _wave_manager:
		push_error("EliteWaveEvent: No hay WaveManager válido")
		event_ended.emit()
		return
	
	# Notificar al jugador
	_show_warning()
	
	# Esperar 2 segundos para que el jugador se prepare
	await get_tree().create_timer(2.0).timeout
	
	# Spawnar élites
	await _spawn_elite_wave()
	
	# Evento completo
	event_ended.emit()

## Muestra advertencia en pantalla
func _show_warning() -> void:
	print("⚠️ EVENTO ESPECIAL: ¡OLEADA DE ÉLITE!")
	
	# Screen shake de advertencia (más intenso que Stampede)
	if VFXManager:
		VFXManager.shake_screen(8.0, 0.4)
	
	# Mostrar advertencia en HUD
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("show_event_warning"):
			hud.show_event_warning("¡ÉLITES DETECTADAS!", Color("#CC0000"))

## Spawn de 3-5 élites mezclados
func _spawn_elite_wave() -> void:
	var elite_count := randi_range(elite_count_min, elite_count_max)
	
	# Obtener pool de escenas de enemigos disponibles
	var available_scenes: Array[PackedScene] = []
	
	if _wave_manager.standard_enemy_scene:
		available_scenes.append(_wave_manager.standard_enemy_scene)
	if _wave_manager.fast_enemy_scene:
		available_scenes.append(_wave_manager.fast_enemy_scene)
	if _wave_manager.tank_enemy_scene:
		available_scenes.append(_wave_manager.tank_enemy_scene)
	if _wave_manager.artillery_enemy_scene:
		available_scenes.append(_wave_manager.artillery_enemy_scene)
	if _wave_manager.explosive_enemy_scene:
		available_scenes.append(_wave_manager.explosive_enemy_scene)
	
	if available_scenes.is_empty():
		push_error("EliteWaveEvent: No hay escenas de enemigos disponibles")
		return
	
	print("EliteWaveEvent: Spawneando %d élites..." % elite_count)
	
	for i in range(elite_count):
		# Elegir tipo aleatorio
		var enemy_scene := available_scenes[randi() % available_scenes.size()]
		
		# Spawn en círculo alrededor del jugador
		var angle := (float(i) / float(elite_count)) * TAU + randf_range(-0.3, 0.3)
		var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
		var spawn_pos := _player.global_position + offset
		
		# Instanciar enemigo (usando pooling si está disponible)
		var enemy: Node = null
		var pool_key := _get_pool_key_for_scene(enemy_scene)
		
		if pool_key and PoolManager and PoolManager.has_pool(pool_key):
			enemy = PoolManager.get_pooled_object(pool_key)
		else:
			enemy = enemy_scene.instantiate()
			get_tree().current_scene.add_child(enemy)
		
		if enemy:
			# Configurar posición
			enemy.global_position = spawn_pos
			
			# Asegurar que tiene referencia al jugador
			if "target" in enemy:
				enemy.target = _player
			
			# ⭐ CONVERTIR EN ÉLITE
			if enemy.has_method("make_elite"):
				enemy.make_elite()
			elif "is_elite" in enemy:
				# Fallback: activar élite manualmente
				enemy.is_elite = true
				enemy._apply_elite_modifiers()
			
			# VFX especial de spawn de élite
			if VFXManager:
				VFXManager.play_elite_spawn_effect(spawn_pos)
			
			_spawned_elites.append(enemy)
		
		# Delay entre spawns (más dramático)
		await get_tree().create_timer(spawn_delay).timeout
	
	print("EliteWaveEvent: Oleada de élite completada - %d élites spawneados" % _spawned_elites.size())

## Mapeo de escena a pool key (debe coincidir con WaveManager)
func _get_pool_key_for_scene(scene: PackedScene) -> String:
	if not _wave_manager:
		return ""
	
	# Usar el diccionario _enemy_scene_to_pool_key de WaveManager si existe
	if "_enemy_scene_to_pool_key" in _wave_manager:
		return _wave_manager._enemy_scene_to_pool_key.get(scene, "")
	
	# Fallback manual
	if scene == _wave_manager.standard_enemy_scene:
		return "enemy_standard"
	elif scene == _wave_manager.fast_enemy_scene:
		return "enemy_fast"
	elif scene == _wave_manager.tank_enemy_scene:
		return "enemy_tank"
	elif scene == _wave_manager.artillery_enemy_scene:
		return "enemy_artillery"
	elif scene == _wave_manager.explosive_enemy_scene:
		return "enemy_explosive"
	
	return ""

## Limpieza
func _exit_tree() -> void:
	_spawned_elites.clear()
