extends Node

## =========================
## AFTERSHOCK - Director de IA (GDD §8)
## Sistema de ajuste dinámico de dificultad
## =========================

signal intensity_changed(new_intensity: float)
signal special_event_triggered(event_type: String)

# =========================
# ESTADOS DEL DIRECTOR (GDD §8)
# =========================
# stress alto = jugador sufre → CALMAR (menos spawns, más drops)
# stress bajo = jugador domina → INTENSIFICAR (más spawns, más élites)
enum DirectorState { CALMAR, MANTENER, INTENSIFICAR }

# =========================
# CONFIGURACIÓN
# =========================
@export var update_interval := 2.0
@export var stress_calmar_threshold := 0.7   # stress > 0.7 → CALMAR
@export var stress_intensificar_threshold := 0.3  # stress < 0.3 → INTENSIFICAR

# Constantes (evitar magic numbers)
const ENEMY_COUNT_FOR_FULL_COVERAGE := 50
const STRESS_WINDOW_SECONDS := 10.0
const STRESS_WEIGHT_HEALTH := 0.3
const STRESS_WEIGHT_TIME_SINCE_HIT := 0.2
const STRESS_WEIGHT_KILLS := 0.25
const STRESS_KILLS_PER_SEC_FOR_MAX := 5.0  # kills/s que saturan contribución de stress
const STRESS_WEIGHT_COVERAGE := 0.25
const STRESS_LERP_SPEED := 0.2
const STRESS_CHANGE_EMIT_THRESHOLD := 0.05
const SPAWN_MULT_CALMAR := 0.7
const SPAWN_MULT_MANTENER := 1.0
const SPAWN_MULT_INTENSIFICAR := 1.4
const SPEED_MULT_CALMAR := 0.95
const SPEED_MULT_INTENSIFICAR := 1.05
const ELITE_CHANCE_MANTENER := 0.08
const ELITE_CHANCE_INTENSIFICAR := 0.22
const HEALTH_DROP_CALMAR := 1.4
const HEALTH_DROP_INTENSIFICAR := 0.75
const EVENT_BASE_CHANCE := 0.35
const EVENT_CHANCE_PER_WAVE := 0.015
const MIN_WAVE_FOR_EVENT := 3

# Keys de métricas (centralizadas; evitar strings sueltos)
const METRIC_PLAYER_HEALTH_PERCENT := "player_health_percent"
const METRIC_SECONDS_WITHOUT_HIT := "seconds_without_hit"
const METRIC_KILLS_PER_SECOND := "kills_per_second"
const METRIC_SCREEN_ENEMY_DENSITY := "screen_enemy_density"
const METRIC_ACTIVE_SYNERGIES := "active_synergies"
const METRIC_PLAYER_LEVEL := "player_level"
const METRIC_PLAYER_POWER_LEVEL := "player_power_level"

# IDs de eventos especiales (emitidos por signal)
const EVENT_ID_STAMPEDE := "STAMPEDE"
const EVENT_ID_ARTILLERY_RAIN := "ARTILLERY_RAIN"
const EVENT_ID_KING_OF_HILL := "KING_OF_HILL"
const EVENT_ID_TOTAL_DARKNESS := "TOTAL_DARKNESS"
const EVENT_ID_ELITE_WAVE := "ELITE_WAVE"
const EVENT_ID_CHAOS_DUPLICATION := "CHAOS_DUPLICATION"

# =========================
# MÉTRICAS (GDD §8)
# =========================
var player_health_percent := 1.0   # 0.0 a 1.0
var time_since_last_hit := 0.0    # segundos
var kills_per_second := 0.0       # promedio móvil
var screen_coverage := 0.0        # % de pantalla con enemigos
var active_synergies := 0
var player_power_level := 0.0    # estimación de poder del build

# Compatibilidad con código que lee metrics (keys centralizadas)
var metrics: Dictionary = {
	METRIC_PLAYER_HEALTH_PERCENT: 1.0,
	METRIC_SECONDS_WITHOUT_HIT: 0.0,
	METRIC_KILLS_PER_SECOND: 0.0,
	METRIC_SCREEN_ENEMY_DENSITY: 0.0,
	METRIC_ACTIVE_SYNERGIES: 0,
	METRIC_PLAYER_LEVEL: 1
}

var kill_history: Array[float] = []
var last_hit_time := 0.0

# =========================
# ESTADO ACTUAL
# =========================
var current_stress := 0.5  # 0.0 = jugador domina, 1.0 = jugador sufre
var current_state := DirectorState.MANTENER
var player_ref: Node2D = null
var wave_manager_ref: Node = null

# =========================
# AJUSTES DEL DIRECTOR (GDD)
# =========================
var spawn_multiplier := 1.0
var enemy_speed_multiplier := 1.0
var elite_spawn_chance := 0.0
var health_drop_boost := 1.0

# =========================
# EVENTOS ESPECIALES (6 del GDD §8.3)
# =========================
enum SpecialEvent {
	STAMPEDE,           # 30-40 enemigos rápidos desde bordes
	ARTILLERY_RAIN,     # 5-8 artilleros fijos
	KING_OF_HILL,       # Zona a defender 30s
	TOTAL_DARKNESS,     # Visibilidad 50%, spawns invisibles
	ELITE_WAVE,         # Solo 3-5 élites
	CHAOS_DUPLICATION   # Cada enemigo muerto spawns 2 débiles
}

var available_events: Array[SpecialEvent] = [
	SpecialEvent.STAMPEDE,
	SpecialEvent.ARTILLERY_RAIN,
	SpecialEvent.KING_OF_HILL,
	SpecialEvent.TOTAL_DARKNESS,
	SpecialEvent.ELITE_WAVE,
	SpecialEvent.CHAOS_DUPLICATION
]
var waves_since_event := 0
var event_cooldown_min := 3
var event_cooldown_max := 5
var next_event_in_waves := 3

# =========================
# INICIALIZACIÓN
# =========================
func _ready() -> void:
	set_process(false)  # Se activa cuando empieza el juego

func start_monitoring() -> void:
	player_ref = get_tree().get_first_node_in_group(GameManager.GROUP_PLAYER) as Node2D
	wave_manager_ref = get_tree().current_scene.get_node_or_null(GameManager.NODE_NAME_WAVE_MANAGER)

	if player_ref:
		var damageable: Node = player_ref.get_node_or_null(GameManager.NODE_NAME_DAMAGEABLE)
		if damageable and damageable.has_signal("health_changed"):
			damageable.health_changed.connect(_on_player_health_changed)
	
	set_process(true)
	_start_update_loop()

func stop_monitoring() -> void:
	set_process(false)

# =========================
# LOOP DE ACTUALIZACIÓN
# =========================
func _start_update_loop() -> void:
	while is_inside_tree():
		# Re-verificar estado DESPUÉS del await (puede haber cambiado durante la espera)
		if not GameManager or GameManager.game_state != GameManager.GameState.PLAYING:
			break
		_update_metrics()
		_calculate_intensity()
		_apply_adjustments()
		await get_tree().create_timer(update_interval).timeout
		# Verificación adicional post-await antes de continuar el loop
		if not is_inside_tree():
			break

func _update_metrics() -> void:
	if not is_instance_valid(player_ref):
		return
	
	var damageable: Node = player_ref.get_node_or_null(GameManager.NODE_NAME_DAMAGEABLE)
	if damageable:
		player_health_percent = damageable.health / damageable.max_health
		metrics[METRIC_PLAYER_HEALTH_PERCENT] = player_health_percent

	var now: float = Time.get_ticks_msec() / 1000.0
	time_since_last_hit = now - last_hit_time
	metrics[METRIC_SECONDS_WITHOUT_HIT] = time_since_last_hit

	_update_kill_rate()
	kills_per_second = metrics.get(METRIC_KILLS_PER_SECOND, 0.0)

	var enemies: Array[Node] = get_tree().get_nodes_in_group(GameManager.GROUP_ENEMIES)
	screen_coverage = clampf(float(enemies.size()) / float(ENEMY_COUNT_FOR_FULL_COVERAGE), 0.0, 1.0)
	metrics[METRIC_SCREEN_ENEMY_DENSITY] = screen_coverage

	active_synergies = 0
	if UpgradeManager:
		active_synergies = UpgradeManager.active_synergies_l2.size() + UpgradeManager.active_synergies_l3.size()
	metrics[METRIC_ACTIVE_SYNERGIES] = active_synergies

	var level: int = 1
	if "level" in player_ref:
		level = player_ref.level
	metrics[METRIC_PLAYER_LEVEL] = level
	var upgrade_count: int = 0
	if UpgradeManager:
		for _v in UpgradeManager.player_upgrades.values():
			upgrade_count += 1
	player_power_level = float(level) * 2.0 + float(active_synergies) * 3.0 + float(upgrade_count) * 0.5
	metrics[METRIC_PLAYER_POWER_LEVEL] = player_power_level

const KILL_HISTORY_MAX := 200  # Cap absoluto para evitar arrays gigantes

func _update_kill_rate() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	kill_history = kill_history.filter(func(t: float) -> bool: return current_time - t < STRESS_WINDOW_SECONDS)
	if kill_history.size() > 0:
		metrics[METRIC_KILLS_PER_SECOND] = kill_history.size() / STRESS_WINDOW_SECONDS
	else:
		metrics[METRIC_KILLS_PER_SECOND] = 0.0

func register_kill() -> void:
	if kill_history.size() < KILL_HISTORY_MAX:
		kill_history.append(Time.get_ticks_msec() / 1000.0)
	# Si se llega al cap, el rate se considera máximo y no se añade más

func _on_player_health_changed(current: float, max_health: float) -> void:
	var old_percent: float = metrics.get(METRIC_PLAYER_HEALTH_PERCENT, 1.0)
	metrics[METRIC_PLAYER_HEALTH_PERCENT] = current / max_health
	if metrics[METRIC_PLAYER_HEALTH_PERCENT] < old_percent:
		last_hit_time = Time.get_ticks_msec() / 1000.0

# =========================
# CÁLCULO DE STRESS (GDD §8)
# =========================
func calculate_stress() -> float:
	var stress := 0.0
	stress += (1.0 - player_health_percent) * STRESS_WEIGHT_HEALTH
	stress += minf(time_since_last_hit / STRESS_WINDOW_SECONDS, 1.0) * STRESS_WEIGHT_TIME_SINCE_HIT
	stress -= minf(kills_per_second / STRESS_KILLS_PER_SEC_FOR_MAX, 1.0) * STRESS_WEIGHT_KILLS
	stress += minf(screen_coverage, 1.0) * STRESS_WEIGHT_COVERAGE
	return clampf(stress, 0.0, 1.0)

func _calculate_intensity() -> void:
	var old_stress: float = current_stress
	var raw_stress: float = calculate_stress()
	current_stress = lerpf(old_stress, raw_stress, STRESS_LERP_SPEED)
	current_stress = clampf(current_stress, 0.0, 1.0)

	if current_stress > stress_calmar_threshold:
		current_state = DirectorState.CALMAR
	elif current_stress < stress_intensificar_threshold:
		current_state = DirectorState.INTENSIFICAR
	else:
		current_state = DirectorState.MANTENER

	if absf(current_stress - old_stress) > STRESS_CHANGE_EMIT_THRESHOLD:
		intensity_changed.emit(current_stress)

# =========================
# APLICAR AJUSTES (GDD §8)
# =========================
# CALMAR (stress > 0.7): Reducir spawns 30%, más health drops
# INTENSIFICAR (stress < 0.3): Aumentar spawns 40%, más élites
# MANTENER (0.3 ≤ stress ≤ 0.7): Dificultad balanceada
func _apply_adjustments() -> void:
	match current_state:
		DirectorState.CALMAR:
			spawn_multiplier = SPAWN_MULT_CALMAR
			enemy_speed_multiplier = SPEED_MULT_CALMAR
			elite_spawn_chance = 0.0
			health_drop_boost = HEALTH_DROP_CALMAR
		DirectorState.MANTENER:
			spawn_multiplier = SPAWN_MULT_MANTENER
			enemy_speed_multiplier = 1.0
			elite_spawn_chance = ELITE_CHANCE_MANTENER
			health_drop_boost = 1.0
		DirectorState.INTENSIFICAR:
			spawn_multiplier = SPAWN_MULT_INTENSIFICAR
			enemy_speed_multiplier = SPEED_MULT_INTENSIFICAR
			elite_spawn_chance = ELITE_CHANCE_INTENSIFICAR
			health_drop_boost = HEALTH_DROP_INTENSIFICAR

# =========================
# EVENTOS ESPECIALES (GDD §8.3 - cada 3-5 oleadas)
# =========================
func on_wave_started(wave_number: int) -> void:
	waves_since_event += 1

	if waves_since_event >= next_event_in_waves and wave_number > MIN_WAVE_FOR_EVENT:
		var event_chance: float = EVENT_BASE_CHANCE + (wave_number * EVENT_CHANCE_PER_WAVE)
		if randf() < event_chance:
			trigger_special_event()
			waves_since_event = 0
			next_event_in_waves = randi_range(event_cooldown_min, event_cooldown_max)

func trigger_special_event() -> void:
	var event: SpecialEvent = available_events[randi() % available_events.size()]
	match event:
		SpecialEvent.STAMPEDE:
			special_event_triggered.emit(EVENT_ID_STAMPEDE)
			_activate_stampede_event()
		SpecialEvent.ELITE_WAVE:
			special_event_triggered.emit(EVENT_ID_ELITE_WAVE)
			_activate_elite_event()
		SpecialEvent.TOTAL_DARKNESS:
			special_event_triggered.emit(EVENT_ID_TOTAL_DARKNESS)
			_activate_darkness_event()
		SpecialEvent.ARTILLERY_RAIN:
			special_event_triggered.emit(EVENT_ID_ARTILLERY_RAIN)
			_activate_artillery_event()
		SpecialEvent.KING_OF_HILL:
			special_event_triggered.emit(EVENT_ID_KING_OF_HILL)
			_activate_king_of_hill_event()
		SpecialEvent.CHAOS_DUPLICATION:
			special_event_triggered.emit(EVENT_ID_CHAOS_DUPLICATION)
			_activate_chaos_event()

# =========================
# GETTERS PARA OTROS SISTEMAS
# =========================
func get_spawn_count_modifier() -> float:
	return spawn_multiplier

func get_enemy_speed_modifier() -> float:
	return enemy_speed_multiplier

func get_elite_chance() -> float:
	return elite_spawn_chance

func get_health_drop_modifier() -> float:
	return health_drop_boost

func get_stress() -> float:
	return current_stress

func get_intensity_state_name() -> String:
	match current_state:
		DirectorState.CALMAR: return "Calmado"
		DirectorState.MANTENER: return "Equilibrado"
		DirectorState.INTENSIFICAR: return "Intenso"
	return "Desconocido"

func get_intensity_color() -> Color:
	match current_state:
		DirectorState.CALMAR: return Color.GREEN
		DirectorState.MANTENER: return Color.YELLOW
		DirectorState.INTENSIFICAR: return Color.RED
	return Color.WHITE

# =========================
# ACTIVADORES DE EVENTOS ESPECIALES
# =========================

func _activate_stampede_event() -> void:
	var stampede_scene := preload("res://levels/events/StampedeEvent.tscn")
	var event := stampede_scene.instantiate()
	get_tree().current_scene.add_child(event)
	var arena := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var wave_manager := arena.get_node_or_null("WaveManager")
	if event.has_method("activate"):
		event.activate(arena, player, wave_manager)
	event.event_ended.connect(func(): event.queue_free())

func _activate_elite_event() -> void:
	var elite_scene := preload("res://levels/events/EliteWaveEvent.tscn")
	var event := elite_scene.instantiate()
	get_tree().current_scene.add_child(event)
	var arena := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var wave_manager := arena.get_node_or_null("WaveManager")
	if event.has_method("activate"):
		event.activate(arena, player, wave_manager)
	event.event_ended.connect(func(): event.queue_free())

func _activate_darkness_event() -> void:
	var darkness_scene := preload("res://levels/events/DarknessEvent.tscn")
	var event := darkness_scene.instantiate()
	get_tree().current_scene.add_child(event)
	var arena := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var wave_manager := arena.get_node_or_null("WaveManager")
	if event.has_method("activate"):
		event.activate(arena, player, wave_manager)
	event.event_ended.connect(func(): event.queue_free())

func _activate_artillery_event() -> void:
	var artillery_scene := preload("res://levels/events/ArtilleryRainEvent.tscn")
	var event := artillery_scene.instantiate()
	get_tree().current_scene.add_child(event)
	var arena := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var wave_manager := arena.get_node_or_null("WaveManager")
	if event.has_method("activate"):
		event.activate(arena, player, wave_manager)
	event.event_ended.connect(func(): event.queue_free())

func _activate_king_of_hill_event() -> void:
	var koth_scene := preload("res://levels/events/KingOfHillEvent.tscn")
	var event := koth_scene.instantiate()
	get_tree().current_scene.add_child(event)
	var arena := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var wave_manager := arena.get_node_or_null("WaveManager")
	if event.has_method("activate"):
		event.activate(arena, player, wave_manager)
	event.event_ended.connect(func(): event.queue_free())

func _activate_chaos_event() -> void:
	var chaos_scene := preload("res://levels/events/ChaosEvent.tscn")
	var event := chaos_scene.instantiate()
	get_tree().current_scene.add_child(event)
	var arena := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var wave_manager := arena.get_node_or_null("WaveManager")
	if event.has_method("activate"):
		event.activate(arena, player, wave_manager)
	event.event_ended.connect(func(): event.queue_free())
