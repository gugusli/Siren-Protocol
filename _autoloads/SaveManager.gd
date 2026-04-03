extends Node
## AFTERSHOCK - Save Manager (GDD §12)
## Persistencia centralizada. Delega a GameManager para compatibilidad.

const SAVE_PATH = "user://aftershock_save.dat"
const BACKUP_PATH = "user://aftershock_save.bak"

signal save_completed
signal load_completed

func save_game() -> void:
	if GameManager:
		GameManager.save_game()
		save_completed.emit()

func load_game() -> void:
	if GameManager and GameManager.has_method("reload_player_data"):
		GameManager.reload_player_data()
		load_completed.emit()

func reset_save() -> void:
	if GameManager:
		GameManager.reset_all_data()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
