extends PanelContainer
class_name CharacterPreview

## Panel lateral que muestra información detallada del personaje seleccionado

const COLOR_CIAN := Color("#00D9FF")
const COLOR_DORADO := Color("#FFD700")

@onready var character_name_label: Label = $Margin/VBox/NameLabel
@onready var lore_label: Label = $Margin/VBox/LoreLabel
@onready var sprite_display: TextureRect = $Margin/VBox/SpriteDisplay
@onready var stats_container: VBoxContainer = $Margin/VBox/StatsContainer
@onready var abilities_container: VBoxContainer = $Margin/VBox/AbilitiesContainer

var current_character_data: Dictionary

func display_character(char_name: String, data: Dictionary) -> void:
	current_character_data = data
	
	# Nombre
	character_name_label.text = data.get("display_name", char_name)
	
	# Lore
	lore_label.text = data.get("lore", "Sin información disponible.")
	
	# Sprite (placeholder si no existe)
	var sprite_path: String = data.get("sprite_idle", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite_display.texture = load(sprite_path)
	else:
		sprite_display.texture = null  # O un placeholder
	
	# Stats
	_display_stats(data.get("stats", {}))
	
	# Habilidades
	_display_abilities(data.get("abilities", []))
	
	# Animación de entrada
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _display_stats(stats: Dictionary) -> void:
	# Limpiar TODOS los hijos inmediatamente para evitar duplicados
	for child in stats_container.get_children():
		child.free()
	
	_add_stat_bar("HP", stats.get("hp", 0), 200)
	_add_stat_bar("Velocidad", stats.get("speed", 0), 10)
	_add_stat_bar("Armadura", stats.get("armor", 0), 50)

func _add_stat_bar(stat_name: String, value: float, max_value: float) -> void:
	var container := HBoxContainer.new()
	container.name = "Stat_" + stat_name
	container.custom_minimum_size.y = 24
	
	var label := Label.new()
	label.text = stat_name + ":"
	label.custom_minimum_size.x = 80
	label.add_theme_font_size_override("font_size", 14)
	container.add_child(label)
	
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	container.add_child(bar)
	
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.custom_minimum_size.x = 40
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", COLOR_DORADO)
	container.add_child(value_label)
	
	stats_container.add_child(container)

func _display_abilities(abilities: Array) -> void:
	# Limpiar TODOS los hijos inmediatamente para evitar duplicados
	for child in abilities_container.get_children():
		child.free()
	
	for ability in abilities:
		var ability_row := HBoxContainer.new()
		ability_row.custom_minimum_size.y = 32
		
		# Ícono (placeholder si no existe)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		var icon_path: String = ability.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		ability_row.add_child(icon)
		
		# Nombre de habilidad
		var ability_label := Label.new()
		ability_label.text = ability.get("name", "???")
		ability_label.add_theme_font_size_override("font_size", 14)
		ability_label.add_theme_color_override("font_color", COLOR_CIAN)
		ability_row.add_child(ability_label)
		
		abilities_container.add_child(ability_row)

func clear_preview() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	# Limpiar stats y habilidades al cerrar para evitar que reaparezcan
	for child in stats_container.get_children():
		child.queue_free()
	for child in abilities_container.get_children():
		child.queue_free()
