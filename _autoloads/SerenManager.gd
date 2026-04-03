extends Node

signal seren_log_created(text: String)

var first_boss_message_shown: bool = false
var first_boss_message_displayed_in_workshop: bool = false
var first_run_codex_unlocked: bool = false

func get_current_run_index() -> int:
	if not GameManager:
		return 0
	return int(GameManager.current_session.get("run_index", 0))

func should_show_workshop_run3_message() -> bool:
	return get_current_run_index() == 3

func is_perfect_run() -> bool:
	if not GameManager:
		return false
	return not GameManager.current_session.get("damage_taken", false)

func create_log(text: String) -> void:
	seren_log_created.emit(text)

