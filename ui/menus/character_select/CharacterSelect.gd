extends CanvasLayer

## Menu de seleccion de personaje mejorado con preview, filtros y sistema modular

const CharacterRowScene := preload("res://ui/menus/character_select/CharacterRow.tscn")
const COLOR_CIAN := Color("#00D9FF")

@onready var panel := $Panel
@onready var list_container: VBoxContainer = $Panel/Margin/HBox/LeftPanel/VBox/ScrollContainer/CharacterList
@onready var back_button: Button = $Panel/Margin/HBox/LeftPanel/VBox/BackButton
@onready var fragments_label: Label = $Panel/Margin/HBox/LeftPanel/VBox/TopBar/FragmentsLabel
@onready var filter_buttons: HBoxContainer = $Panel/Margin/HBox/LeftPanel/VBox/TopBar/FilterButtons
@onready var character_preview: CharacterPreview = $Panel/Margin/HBox/CharacterPreview

var character_database: Dictionary = {}
var current_filter: String = "all"  # all, tank, assassin, controller, hybrid, balanced

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_character_data()
	_setup_filters()
	_build_character_list()
	_update_fragments()

func _load_character_data() -> void:
	var file := FileAccess.open("res://ui/menus/character_select/character_data.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var parse_result := json.parse(file.get_as_text())
		if parse_result == OK:
			character_database = json.data
		else:
			push_error("Error parseando character_data.json: " + json.get_error_message())
		file.close()
	else:
		push_error("No se pudo cargar character_data.json")

func _setup_filters() -> void:
	var filters := [
		{"id": "all", "label": "TODOS"},
		{"id": "tank", "label": "TANQUE"},
		{"id": "assassin", "label": "ASESINO"},
		{"id": "controller", "label": "CONTROL"},
		{"id": "hybrid", "label": "HÍBRIDO"},
		{"id": "balanced", "label": "EQUILIBRADO"}
	]
	
	for filter_data in filters:
		var btn := Button.new()
		btn.text = filter_data.label
		btn.toggle_mode = true
		btn.button_pressed = (filter_data.id == "all")
		btn.pressed.connect(_on_filter_pressed.bind(filter_data.id, btn))
		filter_buttons.add_child(btn)

func _on_filter_pressed(filter_id: String, button: Button) -> void:
	current_filter = filter_id
	
	# Desactivar otros botones
	for btn in filter_buttons.get_children():
		if btn != button:
			btn.button_pressed = false
	
	_build_character_list()

func _build_character_list() -> void:
	# Limpiar lista
	for child in list_container.get_children():
		child.queue_free()
	
	var order: Array = ["RECLUTA", "FORTALEZA", "VÉRTICE", "REVERBERACIÓN", "ECO"]
	var current_selected: String = GameManager.current_session.get("character", "")
	
	for char_name in order:
		var data: Dictionary = character_database.get(char_name, {})
		if data.is_empty():
			continue
		
		# Filtrar por rol
		if current_filter != "all":
			if data.get("role", "") != current_filter:
				continue
		
		var unlocked: bool = GameManager.is_character_unlocked(char_name)
		var selected: bool = (current_selected == char_name)
		
		# Crear fila
		var row: CharacterRow = CharacterRowScene.instantiate()
		# Añadir al árbol antes de usar @onready en el script de la fila
		list_container.add_child(row)
		row.setup(char_name, data, unlocked, selected)
		row.character_selected.connect(_on_character_selected)
		row.character_unlocked.connect(_on_character_unlocked)
		row.row_hovered.connect(_on_row_hovered)

func _on_character_selected(char_name: String) -> void:
	GameManager.current_session["character"] = char_name
	_play_select_sound()
	_close()

func _on_character_unlocked(char_name: String) -> void:
	if GameManager.unlock_character(char_name):
		_play_unlock_effect(char_name)
		_update_fragments()
		_build_character_list()

func _on_row_hovered(char_name: String) -> void:
	var data: Dictionary = character_database.get(char_name, {})
	if not data.is_empty():
		character_preview.display_character(char_name, data)

func _update_fragments() -> void:
	fragments_label.text = "FRAGMENTOS: %d" % GameManager.resonance_fragments

func _play_select_sound() -> void:
	# TODO: Añadir audio
	pass

func _play_unlock_effect(char_name: String) -> void:
	# TODO: Partículas, shake, sonido
	print("¡Personaje desbloqueado: ", char_name, "!")

func _on_back_pressed() -> void:
	_close()

func _close() -> void:
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.2)
	await t.finished
	queue_free()
