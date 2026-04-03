extends Node

# =========================
# SEÑALES
# =========================
signal game_state_changed(new_state)
signal fragments_changed(new_amount)
signal player_stats_updated()

# =========================
# GRUPOS Y NODOS (lógica; evitar strings mágicos)
# =========================
const GROUP_PLAYER := "player"
const GROUP_ENEMIES := "enemies"
const GROUP_CAMERA := "camera"
const GROUP_EXPERIENCE_GEM := "experience_gem"
const NODE_NAME_DAMAGEABLE := "Damageable"
const NODE_NAME_WAVE_MANAGER := "WaveManager"
const NODE_NAME_UPGRADE_MENU := "UpgradeMenu"
const NODE_NAME_PLAYER := "Player"

# Keys de sesión y guardado (métricas centralizadas)
const SESSION_KEY_KILLS := "kills"
const SESSION_KEY_WAVE := "wave"
const SESSION_KEY_CHARACTER := "character"
const SESSION_KEY_START_TIME := "start_time"
const SESSION_KEY_UPGRADES_TAKEN := "upgrades_taken"
const STATS_KEY_TOTAL_KILLS := "total_kills"
const STATS_KEY_TOTAL_DEATHS := "total_deaths"
const STATS_KEY_HIGHEST_WAVE := "highest_wave"
const STATS_KEY_TOTAL_PLAYTIME := "total_playtime"
const STATS_KEY_TOTAL_GAMES := "total_games"
const STATS_KEY_ENEMIES_BY_TYPE := "enemies_killed_by_type"
const STATS_KEY_FAVORITE_CHARACTER := "favorite_character"
const STATS_KEY_SYNERGIES_DISCOVERED := "synergies_discovered"
const SAVE_KEY_VERSION := "version"
const SAVE_KEY_FRAGMENTS := "fragments"
const SAVE_KEY_TOTAL_FRAGMENTS := "total_fragments"
const SAVE_KEY_STATS := "stats"
const SAVE_KEY_UNLOCKED_CHARACTERS := "unlocked_characters"
const SAVE_KEY_WORKSHOP_PURCHASES := "workshop_purchases"
const SAVE_KEY_SETTINGS := "settings"
const SAVE_KEY_LAST_PLAYED := "last_played"
const SAVE_KEY_NARRATIVE_CODEX := "narrative_codex"
const DEFAULT_CHARACTER_ID := "RECLUTA"

# =========================
# ESTADOS DEL JUEGO
# =========================
enum GameState {
	MENU,        # Nuevo: para saber cuando estamos en menú
	PLAYING,
	PAUSED,      # Nuevo: para pausas explícitas
	GAME_OVER,
	VICTORY
}

# =========================
# ESTADO ACTUAL
# =========================
var game_state : GameState = GameState.MENU

# =========================
# META-PROGRESIÓN (Fragmentos de Resonancia)
# =========================
var resonance_fragments := 0  # Moneda del juego
var total_fragments_earned := 0  # Estadística total

# =========================
# ESTADÍSTICAS GLOBALES
# =========================
var stats: Dictionary = {
	STATS_KEY_TOTAL_KILLS: 0,
	STATS_KEY_TOTAL_DEATHS: 0,
	STATS_KEY_HIGHEST_WAVE: 0,
	STATS_KEY_TOTAL_PLAYTIME: 0.0,
	STATS_KEY_TOTAL_GAMES: 0,
	STATS_KEY_ENEMIES_BY_TYPE: {},
	STATS_KEY_FAVORITE_CHARACTER: DEFAULT_CHARACTER_ID,
	STATS_KEY_SYNERGIES_DISCOVERED: []
}

# =========================
# PERSONAJES DESBLOQUEADOS
# =========================
var unlocked_characters: Array[String] = [DEFAULT_CHARACTER_ID]
var workshop_purchases := {}  # Mejoras permanentes compradas en el Taller {id: level}
var narrative_codex_entries: Array[String] = []  # Entradas de códice narrativo (SEREN, primera run, etc.)

# =========================
# SESIÓN ACTUAL
# =========================
var current_session: Dictionary = {
	SESSION_KEY_KILLS: 0,
	SESSION_KEY_WAVE: 0,
	SESSION_KEY_CHARACTER: DEFAULT_CHARACTER_ID,
	SESSION_KEY_START_TIME: 0.0,
	SESSION_KEY_UPGRADES_TAKEN: [],
	"damage_taken": false,
	"run_index": 0
}

# =========================
# CONFIGURACIÓN
# =========================
var settings := {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 0.7,
	"screen_shake_enabled": true,
	"show_damage_numbers": true
}

# =========================
# READY
# =========================
func _ready() -> void:
	_load_player_data()
	_apply_settings_to_systems()
	set_menu()

func _apply_settings_to_systems() -> void:
	if AudioManager:
		AudioManager.refresh_volumes_from_settings()
	if VFXManager:
		VFXManager.screen_shake_enabled = settings.get("screen_shake_enabled", true)
		VFXManager.damage_numbers_enabled = settings.get("show_damage_numbers", true)

# =========================
# CAMBIOS DE ESTADO
# =========================
func set_menu() -> void:
	game_state = GameState.MENU
	game_state_changed.emit(game_state)

func set_playing() -> void:
	game_state = GameState.PLAYING
	_start_new_session()
	if UpgradeManager and UpgradeManager.has_method("reset_upgrades"):
		UpgradeManager.reset_upgrades()
	game_state_changed.emit(game_state)

func set_paused() -> void:
	game_state = GameState.PAUSED
	game_state_changed.emit(game_state)

func set_game_over() -> void:
	game_state = GameState.GAME_OVER
	_end_session(false)
	game_state_changed.emit(game_state)

func set_victory() -> void:
	game_state = GameState.VICTORY
	_end_session(true)
	game_state_changed.emit(game_state)

# =========================
# GESTIÓN DE SESIÓN
# =========================
func _start_new_session() -> void:
	var preserved_character: String = current_session.get(SESSION_KEY_CHARACTER, DEFAULT_CHARACTER_ID)
	var next_run_index: int = current_session.get("run_index", 0) + 1
	current_session = {
		SESSION_KEY_KILLS: 0,
		SESSION_KEY_WAVE: 0,
		SESSION_KEY_CHARACTER: preserved_character,
		SESSION_KEY_START_TIME: Time.get_ticks_msec() / 1000.0,
		SESSION_KEY_UPGRADES_TAKEN: [],
		"damage_taken": false,
		"run_index": next_run_index
	}
	stats[STATS_KEY_TOTAL_GAMES] = stats.get(STATS_KEY_TOTAL_GAMES, 0) + 1

func mark_player_damage_taken() -> void:
	current_session["damage_taken"] = true

func _end_session(victory: bool) -> void:
	var session_start: float = current_session.get(SESSION_KEY_START_TIME, 0.0)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var session_duration: float = end_time - session_start

	var session_kills: int = current_session.get(SESSION_KEY_KILLS, 0)
	var session_wave: int = current_session.get(SESSION_KEY_WAVE, 0)
	stats[STATS_KEY_TOTAL_KILLS] = stats.get(STATS_KEY_TOTAL_KILLS, 0) + session_kills
	if not victory:
		stats[STATS_KEY_TOTAL_DEATHS] = stats.get(STATS_KEY_TOTAL_DEATHS, 0) + 1
	if session_wave > stats.get(STATS_KEY_HIGHEST_WAVE, 0):
		stats[STATS_KEY_HIGHEST_WAVE] = session_wave
	stats[STATS_KEY_TOTAL_PLAYTIME] = stats.get(STATS_KEY_TOTAL_PLAYTIME, 0.0) + session_duration

	# Códice: primera run completa (ganar o perder) — GDD §10.4
	if current_session.get("run_index", 0) == 1 and SerenManager and not SerenManager.first_run_codex_unlocked:
		SerenManager.first_run_codex_unlocked = true
		add_narrative_codex_entry("SEREN: Primera conexión registrada. El sistema recuerda.")

	var fragments_earned: int = _calculate_fragments_reward(victory)
	add_fragments(fragments_earned)

	_save_player_data()
	player_stats_updated.emit()

func _calculate_fragments_reward(victory: bool) -> int:
	var base_reward: int = 50
	var wave_bonus: int = current_session.get(SESSION_KEY_WAVE, 0) * 5
	var kill_bonus: int = int(current_session.get(SESSION_KEY_KILLS, 0) * 0.5)
	var victory_bonus: int = 50 if victory else 0
	return base_reward + wave_bonus + kill_bonus + victory_bonus

# =========================
# FRAGMENTOS DE RESONANCIA
# =========================
func add_fragments(amount: int) -> void:
	resonance_fragments += amount
	total_fragments_earned += amount
	fragments_changed.emit(resonance_fragments)

func spend_fragments(amount: int) -> bool:
	if resonance_fragments >= amount:
		resonance_fragments -= amount
		fragments_changed.emit(resonance_fragments)
		return true
	return false

func can_afford(amount: int) -> bool:
	return resonance_fragments >= amount

# =========================
# PERSONAJES
# =========================
func unlock_character(character_name: String) -> bool:
	if character_name in unlocked_characters:
		return false
	
	# Leer el coste desde la misma base de datos que usa el menú de selección
	var cost: int = -1
	var file := FileAccess.open("res://ui/menus/character_select/character_data.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var parse_result := json.parse(file.get_as_text())
		if parse_result == OK and typeof(json.data) == TYPE_DICTIONARY:
			var db: Dictionary = json.data
			if db.has(character_name):
				var char_data: Dictionary = db.get(character_name, {})
				cost = int(char_data.get("unlock_cost", -1))
		file.close()
	
	if cost < 0:
		push_error("GameManager: Coste de personaje desconocido para: " + str(character_name))
		return false

	if spend_fragments(cost):
		unlocked_characters.append(character_name)
		_save_player_data()
		return true
	else:
		return false

func is_character_unlocked(character_name: String) -> bool:
	return character_name in unlocked_characters

# =========================
# ESTADÍSTICAS
# =========================
func add_kill(enemy_type: String = "generic") -> void:
	var kills: int = current_session.get(SESSION_KEY_KILLS, 0) + 1
	current_session[SESSION_KEY_KILLS] = kills
	var by_type: Dictionary = stats.get(STATS_KEY_ENEMIES_BY_TYPE, {})
	by_type[enemy_type] = by_type.get(enemy_type, 0) + 1
	stats[STATS_KEY_ENEMIES_BY_TYPE] = by_type

func set_current_wave(wave_number: int) -> void:
	current_session[SESSION_KEY_WAVE] = wave_number

func add_upgrade_to_session(upgrade_id: String) -> void:
	var taken: Array = current_session.get(SESSION_KEY_UPGRADES_TAKEN, [])
	taken.append(upgrade_id)
	current_session[SESSION_KEY_UPGRADES_TAKEN] = taken

# =========================
# SISTEMA DE GUARDADO
# =========================
const SAVE_PATH := "user://aftershock_save.dat"

func _save_player_data() -> void:
	var save_data: Dictionary = {
		SAVE_KEY_VERSION: "1.0",
		SAVE_KEY_FRAGMENTS: resonance_fragments,
		SAVE_KEY_TOTAL_FRAGMENTS: total_fragments_earned,
		SAVE_KEY_STATS: stats,
		SAVE_KEY_UNLOCKED_CHARACTERS: unlocked_characters,
		SAVE_KEY_WORKSHOP_PURCHASES: workshop_purchases,
		SAVE_KEY_SETTINGS: settings,
		SAVE_KEY_LAST_PLAYED: Time.get_datetime_string_from_system(),
		SAVE_KEY_NARRATIVE_CODEX: narrative_codex_entries
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
	else:
		push_error("GameManager: Error al guardar datos")

func reload_player_data() -> void:
	_load_player_data()

func _load_player_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data: Variant = file.get_var()
		file.close()
		if save_data and typeof(save_data) == TYPE_DICTIONARY and save_data.has(SAVE_KEY_VERSION):
			resonance_fragments = save_data.get(SAVE_KEY_FRAGMENTS, 0)
			total_fragments_earned = save_data.get(SAVE_KEY_TOTAL_FRAGMENTS, 0)
			stats = save_data.get(SAVE_KEY_STATS, stats)
			var loaded_unlocked: Array = save_data.get(SAVE_KEY_UNLOCKED_CHARACTERS, [DEFAULT_CHARACTER_ID])
			if typeof(loaded_unlocked) == TYPE_ARRAY:
				var uc: Array[String] = []
				for v in loaded_unlocked:
					uc.append(str(v))
				unlocked_characters = uc
			else:
				unlocked_characters = [DEFAULT_CHARACTER_ID]
			workshop_purchases = save_data.get(SAVE_KEY_WORKSHOP_PURCHASES, {})
			settings = save_data.get(SAVE_KEY_SETTINGS, settings)
			var loaded_narrative: Array = save_data.get(SAVE_KEY_NARRATIVE_CODEX, [])
			if typeof(loaded_narrative) == TYPE_ARRAY:
				narrative_codex_entries.clear()
				for v in loaded_narrative:
					narrative_codex_entries.append(str(v))
		else:
			push_warning("GameManager: Archivo de guardado corrupto, usando valores por defecto")
	else:
		push_error("GameManager: Error al cargar datos")

func save_game() -> void:
	_save_player_data()

func reset_all_data() -> void:
	resonance_fragments = 0
	total_fragments_earned = 0
	workshop_purchases.clear()
	stats = {
		STATS_KEY_TOTAL_KILLS: 0,
		STATS_KEY_TOTAL_DEATHS: 0,
		STATS_KEY_HIGHEST_WAVE: 0,
		STATS_KEY_TOTAL_PLAYTIME: 0.0,
		STATS_KEY_TOTAL_GAMES: 0,
		STATS_KEY_ENEMIES_BY_TYPE: {},
		STATS_KEY_FAVORITE_CHARACTER: DEFAULT_CHARACTER_ID,
		STATS_KEY_SYNERGIES_DISCOVERED: []
	}
	unlocked_characters = [DEFAULT_CHARACTER_ID]
	narrative_codex_entries.clear()
	_save_player_data()

# =========================
# UTILIDADES
# =========================
func format_time(seconds: float) -> String:
	var mins := int(seconds / 60.0)
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func get_stats_summary() -> Dictionary:
	var total_games: int = stats.get(STATS_KEY_TOTAL_GAMES, 0)
	var total_deaths: int = stats.get(STATS_KEY_TOTAL_DEATHS, 0)
	return {
		"fragments": resonance_fragments,
		"total_kills": stats.get(STATS_KEY_TOTAL_KILLS, 0),
		"highest_wave": stats.get(STATS_KEY_HIGHEST_WAVE, 0),
		"total_games": total_games,
		"playtime_formatted": format_time(stats.get(STATS_KEY_TOTAL_PLAYTIME, 0.0)),
		"win_rate": (total_games - total_deaths) / float(max(total_games, 1)) * 100.0
	}

func get_collection_progress() -> int:
	if UpgradeManager:
		return UpgradeManager.discovered_synergies.size()
	return 0

func add_narrative_codex_entry(text: String) -> void:
	if text.is_empty() or text in narrative_codex_entries:
		return
	narrative_codex_entries.append(text)
	_save_player_data()
