extends Node

# =========================
# SEÑALES
# =========================
signal wave_started(number)
signal wave_completed()
signal enemy_died_at_position(enemy_node: Node, position: Vector2)

# =========================
# CONFIGURACIÓN (Escenas)
# =========================
@export_group("Escenas de Enemigos")
@export var standard_enemy_scene: PackedScene
@export var fast_enemy_scene: PackedScene
@export var tank_enemy_scene: PackedScene
@export var artillery_enemy_scene: PackedScene  # Nuevo: Artillero
@export var explosive_enemy_scene: PackedScene  # Nuevo: Explosivo
@export var boss_scene: PackedScene

@export_group("Ajustes de Oleada")
@export var spawn_radius := 400.0
@export var base_enemies := 5
@export var max_waves := 15  # Default juego completo
@export var boss_wave := 15           
@export var wave_delay := 2.0

@export var vertical_slice_mode := false

# Eventos especiales
var current_special_event := ""

# Keys de pools de enemigos (GDD §11.3)
const POOL_KEY_ENEMY_STANDARD := "enemy_standard"
const POOL_KEY_ENEMY_FAST := "enemy_fast"
const POOL_KEY_ENEMY_TANK := "enemy_tank"
const POOL_KEY_ENEMY_ARTILLERY := "enemy_artillery"
const POOL_KEY_ENEMY_EXPLOSIVE := "enemy_explosive"
var _enemy_scene_to_pool_key: Dictionary = {}  # PackedScene -> key

# =========================
# REFERENCIAS
# =========================
var player: Node2D = null

# =========================
# ESTADO
# =========================
var current_wave := 0
var enemies_alive := 0
var wave_in_progress := false
var waiting_next_wave := false
var _chaos_clone_count := 0
const CHAOS_MAX_CLONES := 25

# =========================
# READY
# =========================
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
	
	if not player:
		push_error("WaveManager: No se encontró al jugador.")

	# Configuración específica para Vertical Slice: 10 oleadas, boss en 10
	if vertical_slice_mode:
		max_waves = 10
		boss_wave = 10
	
	# Registrar pools de enemigos (object pooling GDD §11.3)
	var tree := get_tree()
	var arena := tree.current_scene if tree else null
	if PoolManager and arena:
		if standard_enemy_scene:
			_enemy_scene_to_pool_key[standard_enemy_scene] = POOL_KEY_ENEMY_STANDARD
			PoolManager.register_enemy_pool(POOL_KEY_ENEMY_STANDARD, standard_enemy_scene, arena)
		if fast_enemy_scene and fast_enemy_scene != standard_enemy_scene:
			_enemy_scene_to_pool_key[fast_enemy_scene] = POOL_KEY_ENEMY_FAST
			PoolManager.register_enemy_pool(POOL_KEY_ENEMY_FAST, fast_enemy_scene, arena)
		if tank_enemy_scene and tank_enemy_scene != standard_enemy_scene:
			_enemy_scene_to_pool_key[tank_enemy_scene] = POOL_KEY_ENEMY_TANK
			PoolManager.register_enemy_pool(POOL_KEY_ENEMY_TANK, tank_enemy_scene, arena)
		if artillery_enemy_scene and artillery_enemy_scene != standard_enemy_scene:
			_enemy_scene_to_pool_key[artillery_enemy_scene] = POOL_KEY_ENEMY_ARTILLERY
			PoolManager.register_enemy_pool(POOL_KEY_ENEMY_ARTILLERY, artillery_enemy_scene, arena)
		if explosive_enemy_scene and explosive_enemy_scene != standard_enemy_scene:
			_enemy_scene_to_pool_key[explosive_enemy_scene] = POOL_KEY_ENEMY_EXPLOSIVE
			PoolManager.register_enemy_pool(POOL_KEY_ENEMY_EXPLOSIVE, explosive_enemy_scene, arena)
	
	# Iniciar Director de IA
	if DirectorAI:
		DirectorAI.start_monitoring()
		DirectorAI.special_event_triggered.connect(_on_special_event)
	
	call_deferred("start_next_wave")

func _on_special_event(event_type: String) -> void:
	current_special_event = event_type

# =========================
# OLEADAS
# =========================
func start_next_wave() -> void:
	if not GameManager:
		push_error("WaveManager: GameManager autoload no disponible")
		return
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return

	if wave_in_progress or waiting_next_wave:
		return

	if current_wave >= max_waves and enemies_alive == 0:
		if GameManager:
			GameManager.set_victory()
		return

	wave_in_progress = true
	current_wave += 1
	
	wave_started.emit(current_wave)
	_update_wave_ui()
	
	# Notificar al Director de IA
	if DirectorAI:
		DirectorAI.on_wave_started(current_wave)

	if current_wave == boss_wave:
		spawn_boss()
	else:
		var spawn_modifier := 1.0
		if DirectorAI:
			spawn_modifier = DirectorAI.get_spawn_count_modifier()
		
		var base_count = base_enemies + ((current_wave - 1) * 2)
		var enemies_to_spawn := int(base_count * spawn_modifier)
		
		# Ajustes por evento especial (GDD §8.3)
		if current_special_event == DirectorAI.EVENT_ID_STAMPEDE:
			enemies_to_spawn = randi_range(30, 40)
		elif current_special_event == DirectorAI.EVENT_ID_ARTILLERY_RAIN:
			enemies_to_spawn = randi_range(5, 8)
		elif current_special_event == DirectorAI.EVENT_ID_ELITE_WAVE:
			enemies_to_spawn = randi_range(3, 5)
		
		enemies_alive = enemies_to_spawn
		spawn_enemies(enemies_to_spawn)

func _update_wave_ui() -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var wave_label = tree.current_scene.find_child("WaveLabel", true, false)
	if wave_label and "text" in wave_label:
		wave_label.text = "OLEADA: " + str(current_wave)

func spawn_enemies(count: int) -> void:
	var tree := get_tree()
	if not tree:
		push_warning("WaveManager: get_tree() no disponible")
		return
	for i in range(count):
		if GameManager and GameManager.game_state != GameManager.GameState.PLAYING:
			break
		var scene_to_use := _get_random_enemy_by_wave()
		if scene_to_use != null:
			var spawn_pos := _get_random_spawn_point()
			if spawn_pos != Vector2.ZERO:
				_instantiate_enemy(scene_to_use, spawn_pos)
			else:
				push_error("WaveManager: No hay spawn points válidos, omitiendo enemigo")
		await tree.create_timer(0.2).timeout 

func _get_random_spawn_point() -> Vector2:
	if not player or not is_instance_valid(player):
		push_error("WaveManager: No hay jugador válido para calcular spawn point")
		return Vector2.ZERO
	var tree := get_tree()
	if not tree or not tree.current_scene:
		push_error("WaveManager: Árbol de escena no disponible para spawn")
		return Vector2.ZERO
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset

func _get_random_enemy_by_wave() -> PackedScene:
	if not standard_enemy_scene:
		push_error("WaveManager: standard_enemy_scene no asignado")
		return null
	var roll := randf()
	
	if current_special_event == DirectorAI.EVENT_ID_STAMPEDE:
		return fast_enemy_scene if fast_enemy_scene else standard_enemy_scene

	if current_special_event == DirectorAI.EVENT_ID_ARTILLERY_RAIN:
		return artillery_enemy_scene if artillery_enemy_scene else standard_enemy_scene

	if current_special_event == DirectorAI.EVENT_ID_ELITE_WAVE:
		var options: Array[PackedScene] = []
		if standard_enemy_scene: options.append(standard_enemy_scene)
		if fast_enemy_scene: options.append(fast_enemy_scene)
		if tank_enemy_scene: options.append(tank_enemy_scene)
		if artillery_enemy_scene: options.append(artillery_enemy_scene)
		if explosive_enemy_scene: options.append(explosive_enemy_scene)
		if options.is_empty():
			return standard_enemy_scene
		return options[randi() % options.size()]
	
	# Distribución normal según oleada y GDD
	if current_wave <= 2:
		return standard_enemy_scene
	elif current_wave <= 5:
		# Oleadas 3-5: 30% rápidos, 70% estándar
		if roll < 0.3: return fast_enemy_scene
		return standard_enemy_scene
	elif current_wave <= 8:
		# Oleadas 6-8: 20% tanques, 30% rápidos, 10% artilleros, 40% estándar
		if roll < 0.2: return tank_enemy_scene
		if roll < 0.5: return fast_enemy_scene
		if roll < 0.6 and artillery_enemy_scene: return artillery_enemy_scene
		return standard_enemy_scene
	else:
		# Oleadas 9+: Mix completo incluyendo explosivos
		if roll < 0.15: return tank_enemy_scene
		if roll < 0.35: return fast_enemy_scene
		if roll < 0.45 and artillery_enemy_scene: return artillery_enemy_scene
		if roll < 0.55 and explosive_enemy_scene: return explosive_enemy_scene
		return standard_enemy_scene

func spawn_boss() -> void:
	if boss_scene == null:
		push_warning("WaveManager: boss_scene no asignado")
		on_wave_completed()
		return
	var spawn_pos := _get_random_spawn_point()
	if spawn_pos == Vector2.ZERO:
		push_error("WaveManager: No hay spawn point válido para el boss")
		on_wave_completed()
		return
	enemies_alive = 1
	_instantiate_enemy(boss_scene, spawn_pos)
	# Señal SEREN #5: primera vez que se enfrenta al boss
	if SerenManager and not SerenManager.first_boss_message_shown:
		SerenManager.first_boss_message_shown = true
		SerenManager.create_log("SEREN: El proceso avanza.")

func _instantiate_enemy(scene: PackedScene, spawn_pos: Vector2) -> void:
	if not scene:
		push_error("WaveManager: Escena de enemigo nula")
		return
	if spawn_pos == Vector2.ZERO:
		push_error("WaveManager: Posición de spawn inválida")
		return
	var tree := get_tree()
	if not tree:
		push_warning("WaveManager: get_tree() no disponible")
		return
	if not tree.current_scene:
		push_error("WaveManager: current_scene no disponible para spawear")
		return
	if not player or not is_instance_valid(player):
		push_error("WaveManager: No hay jugador válido para spawear enemigos")
		return

	var enemy: Node
	var pool_key: String = _enemy_scene_to_pool_key.get(scene, "")
	if not pool_key.is_empty() and PoolManager and PoolManager.has_pool(pool_key):
		enemy = PoolManager.get_pooled_object(pool_key)
	else:
		enemy = scene.instantiate()
		tree.current_scene.call_deferred("add_child", enemy)
	enemy.set_meta("spawn_scene", scene)
	enemy.global_position = spawn_pos
	
	if "target" in enemy:
		enemy.target = player

	# Multiplicador de vida por oleada
	var multiplier := 1.0 + (current_wave - 1) * 0.1
	var damageable = enemy.get_node_or_null("Damageable")
	if damageable and "max_health" in damageable and "health" in damageable:
		var new_max := int(damageable.max_health * multiplier)
		damageable.max_health = new_max
		damageable.health = new_max
	
	# ¿Convertir en élite?
	var should_be_elite := false
	
	if current_special_event == DirectorAI.EVENT_ID_ELITE_WAVE:
		should_be_elite = true
	else:
		var elite_chance := 0.0
		if DirectorAI:
			elite_chance = DirectorAI.get_elite_chance()
		if current_wave >= 6 and randf() < elite_chance:
			should_be_elite = true
	
	if should_be_elite and enemy.has_method("make_elite"):
		enemy.make_elite()

	# Evitar conexiones duplicadas
	if enemy.has_signal("enemy_died"):
		if enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.disconnect(_on_enemy_died)
		enemy.enemy_died.connect(_on_enemy_died)

# =========================
# EVENTOS
# =========================
func _on_enemy_died(enemy: Node) -> void:
	if GameManager and GameManager.game_state != GameManager.GameState.PLAYING:
		return
	
	# ✅ FIX: Una sola declaración de "pos" en este scope
	var death_pos: Vector2 = enemy.global_position if enemy is Node2D else Vector2.ZERO
	enemy_died_at_position.emit(enemy, death_pos)

	# Evento CHAOS_DUPLICATION (GDD §8.3)
	# Evitar que los propios clones generen más clones (loop exponencial)
	if current_special_event == DirectorAI.EVENT_ID_CHAOS_DUPLICATION:
		var is_clone: bool = enemy.get_meta("is_chaos_clone", false)
		if not is_clone:
			var scene = enemy.get_meta("spawn_scene", null)
			if scene is PackedScene:
				var dmg = enemy.get_node_or_null("Damageable")
				var orig_max_hp := 50.0
				if dmg and "max_health" in dmg:
					orig_max_hp = float(dmg.max_health)
				# ✅ FIX: Reutilizamos death_pos en lugar de redeclarar "pos"
				call_deferred("spawn_chaos_clones_at", death_pos, scene, orig_max_hp)

	enemies_alive -= 1
	if enemies_alive <= 0:
		on_wave_completed()

func spawn_chaos_clones_at(position: Vector2, scene: PackedScene, original_max_hp: float) -> void:
	if not scene or not player or not is_instance_valid(player):
		return
	# Límite hard: no spawnar más clones si se alcanzó el máximo
	if _chaos_clone_count >= CHAOS_MAX_CLONES:
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		push_warning("WaveManager: Árbol o current_scene no disponible para spawn chaos clones")
		return
	var clone_hp := maxi(1, int(original_max_hp * 0.3))
	var clones_to_spawn := mini(2, CHAOS_MAX_CLONES - _chaos_clone_count)
	for i in range(clones_to_spawn):
		var clone = scene.instantiate()
		clone.set_meta("spawn_scene", scene)
		clone.set_meta("is_chaos_clone", true)  # marcar para no duplicar clones de clones
		clone.global_position = position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		if "target" in clone:
			clone.target = player
		var damageable = clone.get_node_or_null("Damageable")
		if damageable and "max_health" in damageable and "health" in damageable:
			damageable.max_health = clone_hp
			damageable.health = clone_hp
		tree.current_scene.add_child(clone)
		if clone.has_signal("enemy_died"):
			clone.enemy_died.connect(_on_enemy_died)
		enemies_alive += 1
		_chaos_clone_count += 1

func on_wave_completed() -> void:
	wave_in_progress = false
	current_special_event = ""
	_chaos_clone_count = 0
	wave_completed.emit()
	
	if current_wave >= max_waves:
		if GameManager:
			GameManager.set_victory()
		return
	start_wave_delay()

func start_wave_delay() -> void:
	if waiting_next_wave: return
	var tree := get_tree()
	if not tree:
		waiting_next_wave = false
		return
	waiting_next_wave = true
	await tree.create_timer(wave_delay).timeout
	waiting_next_wave = false
	start_next_wave()
