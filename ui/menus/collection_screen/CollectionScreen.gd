extends CanvasLayer

## Códice de sinergias descubiertas.

const COLOR_DORADO := Color("#FFD700")
const COLOR_PURPURA := Color("#9933FF")
const FONT_ORBITRON := "res://assets/fonts/Orbitron/static/Orbitron-Bold.ttf"
const FONT_ROBOTO := "res://assets/fonts/Roboto/static/Roboto-Regular.ttf"

@onready var panel := $Panel
@onready var list_container: VBoxContainer = $Panel/Margin/VBox/ScrollContainer/SynergyList
@onready var back_button: Button = $Panel/Margin/VBox/BackButton
@onready var count_label: Label = $Panel/Margin/VBox/CountLabel

func _ready() -> void:
	var font_roboto := load(FONT_ROBOTO) as FontFile
	if font_roboto and count_label:
		count_label.add_theme_font_override("font", font_roboto)

	back_button.pressed.connect(_on_back_pressed)
	_refresh_list()

func _refresh_list() -> void:
	for c in list_container.get_children():
		c.queue_free()
	var syn_count: int = UpgradeManager.discovered_synergies.size() if UpgradeManager else 0
	var narrative_count: int = GameManager.narrative_codex_entries.size() if GameManager else 0
	count_label.text = "SINERGIAS: %d  |  CÓDICE: %d" % [syn_count, narrative_count]

	if UpgradeManager:
		var discovered: Array = UpgradeManager.discovered_synergies
		for syn_id in discovered:
			var data: Dictionary = UpgradeManager.get_synergy_data(syn_id)
			if data.is_empty():
				continue
			var level: int = 3 if syn_id in UpgradeManager.SYNERGIES_LEVEL_3 else 2
			var card := _make_synergy_card(data.get("name", syn_id), data.get("desc", ""), level)
			list_container.add_child(card)

	if GameManager:
		for entry_text in GameManager.narrative_codex_entries:
			var card := _make_narrative_card(entry_text)
			list_container.add_child(card)

	if syn_count == 0 and narrative_count == 0:
		var font_roboto := load(FONT_ROBOTO) as FontFile
		var empty_label := Label.new()
		empty_label.text = "Juega partidas y desbloquea sinergias para verlas aqui."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if font_roboto:
			empty_label.add_theme_font_override("font", font_roboto)
		list_container.add_child(empty_label)

func _make_synergy_card(name_str: String, desc: String, level: int) -> PanelContainer:
	var panel_card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = COLOR_DORADO if level == 2 else COLOR_PURPURA
	style.set_corner_radius_all(4)
	panel_card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(vbox)
	panel_card.add_child(margin)
	var font_orb := load(FONT_ORBITRON) as FontFile
	var font_roboto := load(FONT_ROBOTO) as FontFile
	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_DORADO if level == 2 else COLOR_PURPURA)
	if font_orb:
		title.add_theme_font_override("font", font_orb)
	vbox.add_child(title)
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	if font_roboto:
		desc_label.add_theme_font_override("font", font_roboto)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	return panel_card

func _make_narrative_card(entry_text: String) -> PanelContainer:
	var panel_card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0, 0.85, 1, 0.8)
	style.set_corner_radius_all(4)
	panel_card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var label := Label.new()
	label.text = entry_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	var font_roboto := load(FONT_ROBOTO) as FontFile
	if font_roboto:
		label.add_theme_font_override("font", font_roboto)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)
	panel_card.add_child(margin)
	return panel_card

func _on_back_pressed() -> void:
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.2)
	await t.finished
	queue_free()
