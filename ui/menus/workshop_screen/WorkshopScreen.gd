extends CanvasLayer

## Taller: gastar Fragmentos en desbloquear personajes (ya en CharacterSelect)
## y mejoras permanentes. GDD: mejoras básicas 200-400, avanzadas 600-1000.

const COLOR_CIAN := Color("#00D9FF")
const COLOR_DORADO := Color("#FFD700")
const FONT_ORBITRON := "res://assets/fonts/Orbitron/static/Orbitron-Bold.ttf"
const FONT_ROBOTO := "res://assets/fonts/Roboto/static/Roboto-Regular.ttf"
const FONT_MONO := "res://assets/fonts/Roboto_Mono/static/RobotoMono-Regular.ttf"

@onready var panel := $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var back_button: Button = $Panel/Margin/VBox/BackButton
@onready var fragments_label: Label = $Panel/Margin/VBox/FragmentsLabel
@onready var list_container: VBoxContainer = $Panel/Margin/VBox/ScrollContainer/ShopList
@onready var log_label: Label = $Panel/Margin/VBox/SerenLog if has_node("Panel/Margin/VBox/SerenLog") else null

# Mejoras permanentes de ejemplo (se pueden ampliar según GDD)
var permanent_upgrades := [
	{"id": "perm_dmg", "name": "DAÑO BASE +5%", "cost": 200, "max_level": 5},
	{"id": "perm_health", "name": "VIDA MÁX +10", "cost": 300, "max_level": 5},
	{"id": "perm_speed", "name": "VELOCIDAD +3%", "cost": 250, "max_level": 5},
]

var purchased_levels: Dictionary = {}  # {id: level}

func _ready() -> void:
	var font_orb := load(FONT_ORBITRON) as FontFile
	var font_roboto := load(FONT_ROBOTO) as FontFile
	var font_mono := load(FONT_MONO) as FontFile
	if font_orb and title_label:
		title_label.add_theme_font_override("font", font_orb)
	if font_roboto and fragments_label:
		fragments_label.add_theme_font_override("font", font_roboto)
	if font_mono and log_label:
		log_label.add_theme_font_override("font", font_mono)

	back_button.pressed.connect(_on_back_pressed)
	_load_purchased()
	_update_fragments()
	_build_shop_list()
	if SerenManager and log_label:
		if SerenManager.should_show_workshop_run3_message():
			_show_seren_message("SEREN: Patrón de build registrado. Ajuste de parámetros aplicado. Continúa.")
		elif SerenManager.is_perfect_run():
			var run_index := SerenManager.get_current_run_index()
			_show_seren_message("SEREN: Anomalía detectada en run #%d. Frecuencia excedió parámetros de modelo. SEREN tiene uno ahora." % run_index)
		elif SerenManager.first_boss_message_shown and not SerenManager.first_boss_message_displayed_in_workshop:
			_show_seren_message("SEREN: El proceso avanza.")
			SerenManager.first_boss_message_displayed_in_workshop = true
	if SerenManager:
		SerenManager.seren_log_created.connect(_on_seren_log_created)

func _load_purchased() -> void:
	purchased_levels.clear()
	purchased_levels = GameManager.workshop_purchases.duplicate()

func _build_shop_list() -> void:
	for c in list_container.get_children():
		c.queue_free()

	for upg in permanent_upgrades:
		var id_str: String = upg.id
		var current: int = purchased_levels.get(id_str, 0)
		var max_lv: int = upg.max_level
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 50

		var font_roboto := load(FONT_ROBOTO) as FontFile
		var name_label := Label.new()
		name_label.text = "%s (Nv.%d/%d)" % [upg.name, current, max_lv]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", COLOR_CIAN)
		if font_roboto:
			name_label.add_theme_font_override("font", font_roboto)
		name_label.custom_minimum_size.x = 320
		row.add_child(name_label)

		var cost_label := Label.new()
		cost_label.text = "%d F" % upg.cost
		cost_label.add_theme_font_size_override("font_size", 16)
		if font_roboto:
			cost_label.add_theme_font_override("font", font_roboto)
		row.add_child(cost_label)

		var buy_btn := Button.new()
		buy_btn.text = "COMPRAR"
		buy_btn.disabled = current >= max_lv or not GameManager.can_afford(upg.cost)
		buy_btn.pressed.connect(_on_buy_pressed.bind(id_str, upg.cost, max_lv))
		row.add_child(buy_btn)

		list_container.add_child(row)

func _on_buy_pressed(id_str: String, cost: int, max_lv: int) -> void:
	if not GameManager.can_afford(cost):
		return
	var current: int = purchased_levels.get(id_str, 0)
	if current >= max_lv:
		return
	if GameManager.spend_fragments(cost):
		purchased_levels[id_str] = current + 1
		GameManager.workshop_purchases[id_str] = purchased_levels[id_str]
		GameManager.save_game()
		_update_fragments()
		_build_shop_list()

func _update_fragments() -> void:
	fragments_label.text = "FRAGMENTOS: %d" % GameManager.resonance_fragments

func _show_seren_message(text: String) -> void:
	if not log_label:
		return
	log_label.text = text
	log_label.visible = true
	if AudioManager:
		AudioManager.play_ui("seren_signal")

func _on_seren_log_created(text: String) -> void:
	_show_seren_message(text)

func _on_back_pressed() -> void:
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.2)
	await t.finished
	queue_free()
