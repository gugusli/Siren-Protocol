extends Node2D

## =========================
## EVENTO: OSCURIDAD TOTAL
## GDD §8.3 - Visibilidad reducida drásticamente por 30 segundos
## =========================

signal event_ended

# Configuración del evento
@export var darkness_duration := 30.0  # 30 segundos de oscuridad
@export var light_reduction := 0.3     # Reducir luz a 30% (70% más oscuro)
@export var spawn_invisible := true    # Los spawns aparecen sin advertencia visual
@export var enemy_spawn_rate := 1.5    # Spawns cada 1.5 segundos

# Referencias
var _arena: Node2D = null
var _player: Node2D = null
var _wave_manager: Node = null
var _darkness_overlay: CanvasModulate = null
var _player_light: Node = null
var _original_light_energy: float = 1.0
var _is_active := false

## Método principal - llamado por DirectorAI
func activate(arena: Node2D, player: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_player = player
	_wave_manager = wave_manager
	
	if not _player or not is_instance_valid(_player):
		push_error("DarknessEvent: No hay jugador válido")
		event_ended.emit()
		return
	
	if not _arena:
		push_error("DarknessEvent: No hay arena válida")
		event_ended.emit()
		return
	
	# Notificar al jugador
	_show_warning()
	
	# Esperar 2 segundos antes de activar oscuridad
	await get_tree().create_timer(2.0).timeout
	
	# Activar oscuridad
	_activate_darkness()
	
	# Spawns durante la oscuridad (opcional - más difícil)
	if spawn_invisible:
		_start_darkness_spawns()
	
	# Esperar duración del evento
	await get_tree().create_timer(darkness_duration).timeout
	
	# Desactivar oscuridad
	_deactivate_darkness()
	
	# Evento completo
	event_ended.emit()

## Muestra advertencia en pantalla
func _show_warning() -> void:
	print("⚠️ EVENTO ESPECIAL: ¡OSCURIDAD TOTAL!")
	
	# Screen shake de advertencia
	if VFXManager:
		VFXManager.shake_screen(4.0, 0.3)
	
	# Mostrar advertencia en HUD
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("show_event_warning"):
			hud.show_event_warning("¡APAGÓN INMINENTE!", Color("#9900FF"))

## Activa el efecto de oscuridad
func _activate_darkness() -> void:
	_is_active = true
	
	# 1. Activar overlay oscuro de la arena (ya existe)
	if _arena and "_darkness_overlay" in _arena:
		_darkness_overlay = _arena._darkness_overlay
		if _darkness_overlay:
			_darkness_overlay.visible = true
			# Hacer más oscuro que el default
			_darkness_overlay.color = Color(0.2, 0.2, 0.25)  # Muy oscuro, tinte azul
	
	# 2. Reducir luz del jugador (si tiene PointLight2D)
	_player_light = _player.get_node_or_null("PointLight2D")
	if _player_light and "energy" in _player_light:
		_original_light_energy = _player_light.energy
		# Tween suave para reducir luz gradualmente
		var tween := create_tween()
		tween.tween_property(_player_light, "energy", _original_light_energy * light_reduction, 1.0)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Si hay cámara con efectos, añadir vignette oscuro (opcional)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("apply_darkness_effect"):
		camera.apply_darkness_effect(true)
	
	print("DarknessEvent: Oscuridad activada por %.1f segundos" % darkness_duration)

## Desactiva el efecto de oscuridad
func _deactivate_darkness() -> void:
	_is_active = false
	
	# 1. Desactivar overlay
	if _darkness_overlay:
		_darkness_overlay.visible = false
	
	# 2. Restaurar luz del jugador
	if _player_light and "energy" in _player_light:
		# Tween suave para restaurar luz gradualmente
		var tween := create_tween()
		tween.tween_property(_player_light, "energy", _original_light_energy, 1.5)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. Quitar efecto de cámara
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("apply_darkness_effect"):
		camera.apply_darkness_effect(false)
	
	print("DarknessEvent: Oscuridad desactivada")

## Spawns continuos durante la oscuridad (más difícil)
func _start_darkness_spawns() -> void:
	if not _wave_manager:
		return
	
	# Determinar cuántos spawns totales
	var total_spawns := int(darkness_duration / enemy_spawn_rate)
	
	print("DarknessEvent: Spawneando %d enemigos durante la oscuridad..." % total_spawns)
	
	for i in range(total_spawns):
		if not _is_active:  # Si se desactiva antes, parar
			break
		
		# Elegir tipo de enemigo aleatorio
		var enemy_scene: PackedScene = _wave_manager._get_random_enemy_by_wave()
		if not enemy_scene:
			continue
		
		# Spawn más cerca que normal (jugador no ve venir)
		var angle := randf() * TAU
		var distance := randf_range(250.0, 400.0)  # Más cerca que normal
		var offset := Vector2(cos(angle), sin(angle)) * distance
		var spawn_pos := _player.global_position + offset
		
		# Instanciar enemigo
		var pool_key := _get_pool_key_for_scene(enemy_scene)
		var enemy: Node = null
		
		if pool_key and PoolManager and PoolManager.has_pool(pool_key):
			enemy = PoolManager.get_pooled_object(pool_key)
		else:
			enemy = enemy_scene.instantiate()
			get_tree().current_scene.add_child(enemy)
		
		if enemy:
			enemy.global_position = spawn_pos
			if "target" in enemy:
				enemy.target = _player
			
			# NO hay VFX de spawn (aparecen "invisibles" en la oscuridad)
			# Esto hace el evento más tenso
		
		await get_tree().create_timer(enemy_spawn_rate).timeout

## Mapeo de escena a pool key
func _get_pool_key_for_scene(scene: PackedScene) -> String:
	if not _wave_manager:
		return ""
	
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
	# Asegurar que la oscuridad se desactiva si se destruye el nodo
	if _is_active:
		_deactivate_darkness()
