extends PanelContainer
class_name CharacterRow

## Componente individual para cada fila de personaje en la lista de selección

signal character_selected(char_name: String)
signal character_unlocked(char_name: String)
signal row_hovered(char_name: String)

const COLOR_CIAN := Color("#00D9FF")
const COLOR_DORADO := Color("#FFD700")
const COLOR_GRIS := Color("#444444")
const COLOR_VERDE := Color("#33FF66")
const FONT_ORBITRON := "res://assets/fonts/Orbitron/static/Orbitron-Bold.ttf"
const FONT_ROBOTO := "res://assets/fonts/Roboto/static/Roboto-Regular.ttf"

var character_name: String
var character_data: Dictionary
var is_unlocked: bool
var is_selected: bool

@onready var name_label: Label = $Margin/HBox/NameLabel
@onready var role_badge: Label = $Margin/HBox/RoleBadge
@onready var desc_label: Label = $Margin/HBox/DescLabel
@onready var difficulty_container: HBoxContainer = $Margin/HBox/DifficultyStars
@onready var status_label: Label = $Margin/HBox/StatusLabel
@onready var action_button: Button = $Margin/HBox/ActionButton

func setup(char_name: String, data: Dictionary, unlocked: bool, selected: bool) -> void:
	character_name = char_name
	character_data = data
	is_unlocked = unlocked
	is_selected = selected
	
	_update_display()

func _update_display() -> void:
	# Nombre
	name_label.text = character_data.get("display_name", character_name)
	name_label.add_theme_color_override("font_color", COLOR_DORADO if is_unlocked else COLOR_GRIS)
	
	# Role badge
	var role_text := _get_role_text(character_data.get("role", ""))
	role_badge.text = role_text
	role_badge.add_theme_color_override("font_color", _get_role_color(character_data.get("role", "")))
	
	# Descripción
	desc_label.text = character_data.get("description", "")
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if is_unlocked else Color(0.4, 0.4, 0.4))
	
	# Dificultad (estrellas)
	_setup_difficulty_stars(character_data.get("difficulty", 1))
	
	# Status
	if is_unlocked:
		status_label.text = "DESBLOQUEADO"
		status_label.add_theme_color_override("font_color", COLOR_VERDE)
	else:
		var cost: int = character_data.get("unlock_cost", 0)
		status_label.text = "%d F" % cost
		status_label.add_theme_color_override("font_color", COLOR_CIAN)
	
	# Botón
	_update_button()

func _update_button() -> void:
	if is_selected:
		action_button.text = "SELECCIONADO"
		action_button.disabled = true
	else:
		if is_unlocked:
			action_button.text = "SELECCIONAR"
			action_button.disabled = false
		else:
			var cost: int = character_data.get("unlock_cost", 0)
			var can_afford: bool = GameManager.can_afford(cost)
			action_button.text = "DESBLOQUEAR"
			action_button.disabled = not can_afford

func _setup_difficulty_stars(difficulty: int) -> void:
	for child in difficulty_container.get_children():
		child.queue_free()
	
	var font_roboto := load(FONT_ROBOTO) as FontFile
	for i in range(3):
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 16)
		if font_roboto:
			star.add_theme_font_override("font", font_roboto)
		if i < difficulty:
			star.add_theme_color_override("font_color", COLOR_DORADO)
		else:
			star.add_theme_color_override("font_color", COLOR_GRIS)
		difficulty_container.add_child(star)

func _get_role_text(role: String) -> String:
	match role:
		"tank": return "[TANQUE]"
		"assassin": return "[ASESINO]"
		"controller": return "[CONTROL]"
		"hybrid": return "[HÍBRIDO]"
		"balanced": return "[EQUILIBRADO]"
		_: return "[???]"

func _get_role_color(role: String) -> Color:
	match role:
		"tank": return Color("#4169E1")  # Azul
		"assassin": return Color("#DC143C")  # Rojo
		"controller": return Color("#9370DB")  # Púrpura
		"hybrid": return Color("#FF8C00")  # Naranja
		"balanced": return Color("#32CD32")  # Verde
		_: return COLOR_GRIS

func _ready() -> void:
	var font_orb := load(FONT_ORBITRON) as FontFile
	var font_roboto := load(FONT_ROBOTO) as FontFile
	if font_orb and name_label:
		name_label.add_theme_font_override("font", font_orb)
	if font_roboto:
		for lbl in [role_badge, desc_label, status_label]:
			if lbl:
				lbl.add_theme_font_override("font", font_roboto)

	action_button.pressed.connect(_on_action_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_action_pressed() -> void:
	if is_unlocked:
		character_selected.emit(character_name)
	else:
		var cost: int = character_data.get("unlock_cost", 0)
		if GameManager.can_afford(cost):
			character_unlocked.emit(character_name)

func _on_mouse_entered() -> void:
	row_hovered.emit(character_name)
	# Efecto hover
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1)

func _on_mouse_exited() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
