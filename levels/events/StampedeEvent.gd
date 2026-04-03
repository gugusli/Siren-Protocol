extends Node2D

## =========================
## EVENTO: ESTAMPIDA DE CORREDORES
## GDD §8.3 - 30-40 enemigos rápidos desde los bordes
## =========================

signal event_ended

# Configuración del evento
@export var enemy_count_min := 30
@export var enemy_count_max := 40
@export var spawn_radius := 700.0  # Más lejos que spawns normales
@export var spawn_delay := 0.08    # Muy rápido para crear sensación de horda
@export var speed_multiplier := 1.5  # Los corredores van 50% más rápido

# Referencias
var _arena: Node2D = null
var _player: Node2D = null
var _wave_manager: Node = null
var _spawned_enemies: Array[Node] = []

## Método principal - llamado por DirectorAI
func activate(arena: Node2D, player: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_player = player
	_wave_manager = wave_manager
	
	if not _player or not is_instance_valid(_player):
		push_error("StampedeEvent: No hay jugador válido")
		event_ended.emit()
		return
	
	if not _wave_manager:
		push_error("StampedeEvent: No hay WaveManager válido")
		event_ended.emit()
		return
	
	# Notificar al jugador
	_show_warning()
	
	# Esperar 2 segundos para que el jugador se prepare
	await get_tree().create_timer(2.0).timeout
	
	# Spawnar la estampida
	await _spawn_stampede()
	
	# Evento completo
	event_ended.emit()

## Muestra advertencia en pantalla
func _show_warning() -> void:
	# TODO: Cuando tengas UI de notificaciones, úsala aquí
	# Por ahora, print + VFX
	print("⚠️ EVENTO ESPECIAL: ¡ESTAMPIDA INMINENTE!")
	
	# Screen shake de advertencia
	if VFXManager:
		VFXManager.shake_screen(5.0, 0.3)
	
	# Si hay HUD, mostrar texto grande
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("show_event_warning"):
			hud.show_event_warning("¡ESTAMPIDA!", Color("#FF6600"))

## Spawn de 30-40 enemigos rápidos
func _spawn_stampede() -> void:
	var enemy_count := randi_range(enemy_count_min, enemy_count_max)
	
	# Determinar qué escena usar (fast_enemy o estándar con velocidad aumentada)
	var enemy_scene: PackedScene = null
	if _wave_manager.fast_enemy_scene:
		enemy_scene = _wave_manager.fast_enemy_scene
	elif _wave_manager.standard_enemy_scene:
		enemy_scene = _wave_manager.standard_enemy_scene
	else:
		push_error("StampedeEvent: No hay escenas de enemigos disponibles")
		return
	
	print("StampedeEvent: Spawneando %d corredores..." % enemy_count)
	
	for i in range(enemy_count):
		# Spawn desde círculo alrededor del jugador (más lejos que normal)
		var angle := (float(i) / float(enemy_count)) * TAU + randf_range(-0.2, 0.2)
		var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
		var spawn_pos := _player.global_position + offset
		
		# Instanciar enemigo (usando sistema de pooling si está disponible)
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
			
			# Aumentar velocidad (ESTAMPIDA = MÁS RÁPIDO)
			if "speed" in enemy:
				var base_speed: float = enemy.speed
				enemy.speed = base_speed * speed_multiplier
			
			# Visual: Color rojo tinte para distinguir de enemigos normales
			if "modulate" in enemy:
				enemy.modulate = Color(1.3, 0.8, 0.8)  # Tinte rojo pálido
			
			_spawned_enemies.append(enemy)
		
		# Delay corto entre spawns (da sensación de oleada continua)
		await get_tree().create_timer(spawn_delay).timeout
	
	print("StampedeEvent: Estampida completada - %d enemigos spawneados" % _spawned_enemies.size())

## Mapeo de escena a pool key (debe coincidir con WaveManager)
func _get_pool_key_for_scene(scene: PackedScene) -> String:
	if not _wave_manager:
		return ""
	
	# Intentar obtener el pool key desde WaveManager
	if _wave_manager.has_method("get_pool_key_for_scene"):
		return _wave_manager.get_pool_key_for_scene(scene)
	
	# Fallback: asumir que es fast_enemy si existe
	if scene == _wave_manager.fast_enemy_scene:
		return "enemy_fast"
	elif scene == _wave_manager.standard_enemy_scene:
		return "enemy_standard"
	
	return ""

## Limpieza (opcional - los enemigos se limpian solos al morir)
func _exit_tree() -> void:
	_spawned_enemies.clear()
