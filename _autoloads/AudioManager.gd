extends Node

# Este nodo manejará la música de fondo y SFX
var music_player: AudioStreamPlayer
var _music_loop_stream: AudioStream
var siren_player: AudioStreamPlayer

func _ready() -> void:
	# Configuramos el reproductor de música inicial
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music" # Opcional: si creas un bus en el Mezclador
	music_player.finished.connect(_on_music_finished)
	# Frecuencia de la Sirena: tono ~40Hz en bus dedicado
	siren_player = AudioStreamPlayer.new()
	siren_player.bus = "SirenFrequency"
	add_child(siren_player)
	if SIREN_FREQUENCY != null:
		siren_player.stream = SIREN_FREQUENCY
		siren_player.volume_db = -24.0
		siren_player.play()

# 🎵 Función para poner música de fondo (con loop automático)
func play_music(stream: AudioStream, volume := 0.0) -> void:
	if stream == null:
		return
	if not music_player:
		push_error("AudioManager: music_player no inicializado")
		return
	if music_player.stream == stream and music_player.playing:
		return
	_music_loop_stream = stream
	music_player.stream = stream
	_refresh_music_volume_db(volume)
	music_player.play()

func _refresh_music_volume_db(base_db: float = 0.0) -> void:
	if not music_player:
		return
	var mult := 1.0
	if GameManager:
		mult = GameManager.settings.get("master_volume", 1.0) * GameManager.settings.get("music_volume", 0.7)
	music_player.volume_db = base_db + (20.0 * log(mult) / log(10.0) if mult > 0.001 else -80.0)

func refresh_volumes_from_settings() -> void:
	if music_player:
		var base := -8.0 if music_player.stream == MENU_MUSIC else 0.0
		_refresh_music_volume_db(base)
	if siren_player:
		var mult := 1.0
		if GameManager:
			mult = GameManager.settings.get("master_volume", 1.0)
		siren_player.volume_db = -24.0 + (20.0 * log(mult) / log(10.0) if mult > 0.001 else -80.0)

func _on_music_finished() -> void:
	if music_player and _music_loop_stream != null and music_player.stream == _music_loop_stream:
		music_player.play()

# 🎵 Música del menú principal (Sci-Fi 1 Loop)
const MENU_MUSIC := preload("res://assets/audio/eyes.ogg")
const SIREN_FREQUENCY: AudioStream = null

func play_menu_music(volume := -8.0) -> void:
	play_music(MENU_MUSIC, volume)

func stop_music() -> void:
	_music_loop_stream = null
	if music_player:
		music_player.stop()

# 🔊 Función para efectos de sonido (disparos, gemas, etc.)
func play_sfx(stream: AudioStream, volume := 0.0) -> void:
	if stream == null:
		return
	var mult := 1.0
	if GameManager:
		mult = GameManager.settings.get("master_volume", 1.0) * GameManager.settings.get("sfx_volume", 1.0)
	var vol_db := volume + (20.0 * log(mult) / log(10.0) if mult > 0.001 else -80.0)
	var sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.stream = stream
	sfx_player.volume_db = vol_db
	sfx_player.play()
	
	# Cuando el sonido termine, el reproductor se destruye automáticamente
	sfx_player.finished.connect(sfx_player.queue_free)

const UI_SOUNDS := {
	"ui_confirm": null,
	"seren_signal": null
}

func play_ui(sound_name: String, volume := 0.0) -> void:
	var stream: AudioStream = UI_SOUNDS.get(sound_name, null)
	if stream == null:
		return
	var mult := 1.0
	if GameManager:
		mult = GameManager.settings.get("master_volume", 1.0) * GameManager.settings.get("sfx_volume", 1.0)
	var vol_db := volume + (20.0 * log(mult) / log(10.0) if mult > 0.001 else -80.0)
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX_UI"
	add_child(sfx_player)
	sfx_player.stream = stream
	sfx_player.volume_db = vol_db
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
