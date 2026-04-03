extends Node2D

# Límites del mundo (en píxeles). El jugador se restringe a este rectángulo.
@export var world_limit_min := Vector2(-1800, -1000)
@export var world_limit_max := Vector2(1800, 1000)

# Si true, se rellena el suelo con tiles de assets/map al iniciar (amplía el fondo).
@export var fill_floor_on_ready := true

# Escenas para object pooling (GDD §11.3). Si no se asignan, se usan estas por defecto.
const DEFAULT_EXP_GEM := preload("res://entities/items/ExperienceGem.tscn")
const DEFAULT_HEALTH_POTION := preload("res://entities/items/HealthPotion.tscn")
const DEFAULT_DEATH_FX := preload("res://assets/effects/FutureEnemies/EnemyDeathFX.tscn")

var player: Node = null
@onready var hud = $HUD

# Eventos especiales (GDD §8.3): overlay oscuridad para TOTAL_DARKNESS
var _darkness_overlay: CanvasModulate = null

const CHARACTER_SCENES := {
	"RECLUTA": "",  # usa el Player por defecto de la escena
	"FORTALEZA": "res://entities/player/Fortaleza.tscn",
	"VÉRTICE": "res://entities/player/Vertice.tscn",
	"REVERBERACIÓN": "res://entities/player/Reverberacion.tscn",
	"ECO": "res://entities/player/Eco.tscn"
}

func _ready() -> void:
	_spawn_player_by_character()
	player = get_node_or_null("Player")
	if not player:
		push_error("Arena: No se encontró nodo Player.")
	_setup_darkness_overlay()
	hud.connect_player(player)
	add_to_group("world_border")
	if DirectorAI and DirectorAI.special_event_triggered.is_connected(_on_special_event) == false:
		DirectorAI.special_event_triggered.connect(_on_special_event)
	var wm = get_node_or_null("WaveManager")
	if wm:
		if "vertical_slice_mode" in wm:
			wm.vertical_slice_mode = true
		if wm.has_signal("wave_completed") and wm.wave_completed.is_connected(_on_wave_completed) == false:
			wm.wave_completed.connect(_on_wave_completed)
	if PoolManager and player.bullet_scene:
		PoolManager.init_pools(
			self,
			player.bullet_scene,
			player.bouncing_bullet_scene,
			DEFAULT_EXP_GEM,
			DEFAULT_HEALTH_POTION,
			DEFAULT_DEATH_FX
		)
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)
	if fill_floor_on_ready:
		_fill_floor_with_map_tiles()

func _spawn_player_by_character() -> void:
	var character_id: String = GameManager.DEFAULT_CHARACTER_ID
	if GameManager:
		character_id = GameManager.current_session.get(GameManager.SESSION_KEY_CHARACTER, GameManager.DEFAULT_CHARACTER_ID)
	var scene_path: String = CHARACTER_SCENES.get(character_id, "")
	if scene_path.is_empty():
		return  # RECLUTA: usar el Player ya presente en la escena
	var existing := get_node_or_null("Player")
	if not existing:
		return
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("Arena: No se pudo cargar escena de personaje: " + scene_path)
		return
	existing.get_parent().remove_child(existing)
	existing.queue_free()
	var new_player: Node = scene.instantiate()
	new_player.name = "Player"
	add_child(new_player)

func _setup_darkness_overlay() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 5
	_darkness_overlay = CanvasModulate.new()
	_darkness_overlay.color = Color(0.35, 0.35, 0.4)
	_darkness_overlay.visible = false
	layer.add_child(_darkness_overlay)
	add_child(layer)

func _on_special_event(event_id: String) -> void:
	if event_id == "TOTAL_DARKNESS" and _darkness_overlay:
		_darkness_overlay.visible = true

func _on_wave_completed() -> void:
	if _darkness_overlay:
		_darkness_overlay.visible = false

func _on_game_state_changed(state: int) -> void:
	if state != GameManager.GameState.GAME_OVER and state != GameManager.GameState.VICTORY:
		return
	var end_screen = get_node_or_null("EndScreen")
	if not end_screen or not end_screen.has_method("setup_and_show"):
		return
	var session: Dictionary = GameManager.current_session
	var duration: float = (Time.get_ticks_msec() / 1000.0) - session.get("start_time", 0.0)
	var synergy_text: String = ""
	if UpgradeManager:
		var count: int = UpgradeManager.active_synergies_l2.size() + UpgradeManager.active_synergies_l3.size()
		synergy_text = str(count) + " activas" if count > 0 else "Ninguna"
	end_screen.setup_and_show({
		"victory": state == GameManager.GameState.VICTORY,
		"time": GameManager.format_time(duration),
		"kills": session.get("kills", 0),
		"sinergy": synergy_text
	})
# Usa varios atlas_coords del tileset para dar variedad al suelo.
func _fill_floor_with_map_tiles() -> void:
	var layer = get_node_or_null("TileMapLayer")
	if not layer or not layer.tile_set:
		return
	if layer.tile_set.get_source_count() == 0:
		return
	var source_id: int = layer.tile_set.get_source_id(0)
	# Variación de suelo: tiles del atlas (0,0), (1,0), (0,1), (2,0), (1,1)
	var atlas_variants: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 0), Vector2i(1, 1)
	]
	# Área: ±100 en X y ±60 en Y (aprox. 3200×1920 px con tiles 16×16)
	for tx in range(-100, 100):
		for ty in range(-60, 60):
			var idx: int = (tx + ty) % atlas_variants.size()
			if idx < 0:
				idx += atlas_variants.size()
			var atlas: Vector2i = atlas_variants[idx]
			layer.set_cell(Vector2i(tx, ty), source_id, atlas, 0)
