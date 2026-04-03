extends CanvasLayer

## =========================
## MainMenu - Menú Principal
## Actualizado según GDD Visual v4
## =========================

# Colores del GDD
const COLOR_ROJO_ALERTA := Color("#CC0000")
const COLOR_NEGRO_PROFUNDO := Color("#1A1A1A")
const COLOR_CIAN_ENERGIA := Color("#00D9FF")
const COLOR_DORADO := Color("#FFD700")

# Feedback de botones (game feel)
const HOVER_SCALE := Vector2(1.03, 1.03)
const PRESS_SCALE := Vector2(0.96, 0.96)

# Fuentes (Orbitron títulos, Roboto Mono datos/terminal)
const FONT_ORBITRON := "res://assets/fonts/Orbitron/static/Orbitron-Bold.ttf"
const FONT_MONO := "res://assets/fonts/Roboto_Mono/static/RobotoMono-Regular.ttf"

# =========================
# REFERENCIAS A NODOS
# =========================
@onready var main_control = $MainControl
@onready var title = $MainControl/VBoxContainer/Title
@onready var subtitle = $MainControl/VBoxContainer/SubTitle

# Botones principales
@onready var start_button = $MainControl/VBoxContainer/Buttons/StartButton
@onready var characters_button = $MainControl/VBoxContainer/Buttons/CharactersButton
@onready var workshop_button = $MainControl/VBoxContainer/Buttons/WorkshopButton
@onready var collection_button = $MainControl/VBoxContainer/Buttons/CollectionButton
@onready var settings_button = $MainControl/VBoxContainer/Buttons/SettingsButton
@onready var quit_button = $MainControl/VBoxContainer/Buttons/QuitButton

# Efectos ambientales
@onready var city_silhouette = $Background/CitySilhouette
@onready var ash_particles = $Background/AshParticles
@onready var volumetric_light = $Background/VolumetricLight
@onready var vignette = $MainControl/Vignette

# Efecto de escaneo en botón principal (hover)
var _scan_line_overlay: ColorRect
var _scan_line_tween: Tween

# HUD decorativo
@onready var hud_decorativo = $MainControl/HUD_Decorativo
@onready var version_label = $MainControl/HUD_Decorativo/VersionInfo
@onready var stats_label = $MainControl/HUD_Decorativo/StatsInfo
@onready var date_label = $MainControl/HUD_Decorativo/DateInfo
@onready var fragments_label = $MainControl/HUD_Decorativo/FragmentsInfo

# =========================
# VARIABLES DE EFECTOS
# =========================
var glitch_timer := 0.0
var glitch_interval := randf_range(8.0, 12.0)
var title_glow_time := 0.0

# =========================
# READY
# =========================
func _ready() -> void:
	# Validar nodos críticos
	var required_nodes: Array = [
		main_control, title, subtitle, start_button,
		characters_button, workshop_button, collection_button,
		settings_button, quit_button
	]
	for node in required_nodes:
		if not node or not is_instance_valid(node):
			push_error("MainMenu: Nodo requerido no encontrado o inválido")
			return

	var font_orb := load(FONT_ORBITRON) as FontFile
	var font_mono := load(FONT_MONO) as FontFile
	if font_orb:
		title.add_theme_font_override("font", font_orb)
		subtitle.add_theme_font_override("font", font_orb)
	if font_mono:
		version_label.add_theme_font_override("font", font_mono)
		stats_label.add_theme_font_override("font", font_mono)
		date_label.add_theme_font_override("font", font_mono)
		fragments_label.add_theme_font_override("font", font_mono)

	# 1. Preparación para el "Boot Up"
	main_control.modulate.a = 0
	title.visible_ratio = 0
	subtitle.visible_characters = 0
	var tree := get_tree()
	if tree:
		tree.paused = false
	
	# 2. Conexiones de botones
	start_button.pressed.connect(_on_start_pressed)
	characters_button.pressed.connect(_on_characters_pressed)
	workshop_button.pressed.connect(_on_workshop_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 3. Hover + Press effects
	var all_buttons = [
		start_button,
		characters_button,
		workshop_button,
		collection_button,
		settings_button,
		quit_button
	]
	
	for btn in all_buttons:
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_exit.bind(btn))
		btn.pressed.connect(_on_button_pressed_feedback.bind(btn))
	
	# 4. Actualizar info del HUD
	_update_hud_info()
	
	# 5. Actualizar estado de botones según progreso
	_update_button_states()
	
	# 6. Iniciar efectos ambientales
	_start_ambient_effects()
	
	# 7. Música de fondo del menú (Sci-Fi 1 Loop)
	if AudioManager:
		AudioManager.play_menu_music(-8.0)
	else:
		push_warning("MainMenu: AudioManager no disponible")
	
	# 8. Overlay de líneas de escaneo en botón principal (hover)
	_setup_scan_line_effect()
	
	# 9. Secuencia de inicio
	_animate_boot_sequence()

# =========================
# EFECTO LÍNEAS DE ESCANEO (BOTÓN PRINCIPAL)
# =========================
func _setup_scan_line_effect() -> void:
	_scan_line_overlay = ColorRect.new()
	_scan_line_overlay.name = "ScanLineOverlay"
	_scan_line_overlay.color = Color(0, 0.851, 1, 0.35)
	_scan_line_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.add_child(_scan_line_overlay)
	_scan_line_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_scan_line_overlay.set_anchor(SIDE_LEFT, 0, 0)
	_scan_line_overlay.set_anchor(SIDE_TOP, 0, 0)
	_scan_line_overlay.set_anchor(SIDE_RIGHT, 1, 0)
	_scan_line_overlay.set_anchor(SIDE_BOTTOM, 0, 0)
	_scan_line_overlay.offset_left = 4
	_scan_line_overlay.offset_top = 0
	_scan_line_overlay.offset_right = -4
	_scan_line_overlay.offset_bottom = 4
	_scan_line_overlay.modulate.a = 0.0

func _run_scan_line_effect() -> void:
	if not _scan_line_overlay:
		return
	if _scan_line_tween and _scan_line_tween.is_valid():
		_scan_line_tween.kill()
	_scan_line_overlay.modulate.a = 0.0
	_scan_line_overlay.offset_top = 0
	_scan_line_overlay.offset_bottom = 4
	var h := maxf(4.0, float(start_button.size.y))
	_scan_line_tween = create_tween()
	_scan_line_tween.tween_property(_scan_line_overlay, "modulate:a", 1.0, 0.06)
	_scan_line_tween.tween_property(_scan_line_overlay, "offset_top", h - 4, 0.35).set_trans(Tween.TRANS_LINEAR)
	_scan_line_tween.parallel().tween_property(_scan_line_overlay, "offset_bottom", h, 0.35).set_trans(Tween.TRANS_LINEAR)
	_scan_line_tween.tween_property(_scan_line_overlay, "modulate:a", 0.0, 0.08)

# =========================
# EFECTOS AMBIENTALES
# =========================
func _start_ambient_effects() -> void:
	# Luz volumétrica: pulso sutil
	if volumetric_light:
		var light_tween = create_tween().set_loops()
		light_tween.tween_property(volumetric_light, "modulate:a", 0.18, 4.0)
		light_tween.tween_property(volumetric_light, "modulate:a", 0.26, 4.0)
	
	# Ciudad: breathing sutil (varía entre 0.22 y 0.28 para que siempre se vea)
	if city_silhouette:
		var city_tween = create_tween().set_loops()
		city_tween.tween_property(city_silhouette, "modulate:a", 0.22, 6.0).set_trans(Tween.TRANS_SINE)
		city_tween.tween_property(city_silhouette, "modulate:a", 0.3, 6.0).set_trans(Tween.TRANS_SINE)

# =========================
# ACTUALIZAR HUD DECORATIVO
# =========================
func _update_hud_info() -> void:
	version_label.text = "v1.0.0-ALPHA | BUILD 2026.01.30"
	
	if GameManager and GameManager.has_method("get_stats_summary"):
		var summary = GameManager.get_stats_summary()
		if summary:
			stats_label.text = "KILLS: %d | OLEADA_MAX: %d | W/L: %.1f%%" % [
				summary.get("total_kills", 0),
				summary.get("highest_wave", 0),
				summary.get("win_rate", 0.0)
			]
		else:
			stats_label.text = "KILLS: 0 | OLEADA_MAX: 0 | W/L: 0.0%"
	else:
		stats_label.text = "KILLS: 0 | OLEADA_MAX: 0 | W/L: 0.0%"
	
	var date = Time.get_datetime_dict_from_system()
	date_label.text = "ULTIMO DESPLIEGUE: %04d.%02d.%02d | %02d:%02d" % [
		date.year, date.month, date.day,
		date.hour, date.minute
	]
	
	fragments_label.text = "FRAGMENTOS: %d" % (GameManager.resonance_fragments if GameManager else 0)

# =========================
# ACTUALIZAR ESTADO DE BOTONES
# =========================
func _update_button_states() -> void:
	if not GameManager:
		return
	var unlocked_count: int = GameManager.unlocked_characters.size()
	characters_button.text = "SELECCION DE PERSONAJE [%d/5]" % unlocked_count
	
	var collected: int = GameManager.get_collection_progress()
	collection_button.text = "COLECCION [%d/23]" % collected

# =========================
# PROCESO (efectos continuos)
# =========================
func _process(delta: float) -> void:
	# Glitches periódicos cada 8-12 segundos
	glitch_timer += delta
	if glitch_timer >= glitch_interval:
		glitch_timer = 0.0
		glitch_interval = randf_range(8.0, 12.0)
		_trigger_screen_glitch()
	
	# Glow animado del título (solo modula outline_color)
	title_glow_time += delta
	var glow_intensity = 0.55 + sin(title_glow_time * 1.2) * 0.25
	title.add_theme_color_override("font_outline_color", Color(0.8, 0, 0, glow_intensity))

func _trigger_screen_glitch() -> void:
	var tween = create_tween().set_parallel(true)
	
	# Distorsión de color
	tween.tween_property(main_control, "modulate", Color(1.08, 0.93, 0.93), 0.04)
	tween.chain().tween_property(main_control, "modulate", Color.WHITE, 0.06)
	
	# Desplazamiento del título
	var original_x = title.position.x
	tween.tween_property(title, "position:x", original_x + randf_range(-4, 4), 0.025)
	tween.chain().tween_property(title, "position:x", original_x, 0.025)

# =========================
# SECUENCIA DE BOOT
# =========================
func _animate_boot_sequence() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Flicker inicial
	tween.tween_property(main_control, "modulate:a", 1.0, 0.04)
	tween.tween_property(main_control, "modulate:a", 0.1, 0.04)
	tween.tween_property(main_control, "modulate:a", 1.0, 0.08)
	tween.tween_property(main_control, "modulate:a", 0.25, 0.04)
	tween.tween_property(main_control, "modulate:a", 1.0, 0.12)
	
	# Título con efecto de typing
	tween.tween_property(title, "visible_ratio", 1.0, 1.0)
	
	# Subtítulo
	tween.tween_callback(func(): 
		var t := get_tree()
		if not t:
			return
		await t.create_timer(0.3).timeout
		if not is_instance_valid(subtitle):
			return
		var t_sub = create_tween()
		t_sub.tween_property(subtitle, "visible_characters", subtitle.text.length(), 1.5)
	)
	
	await tween.finished
	
	# Botones aparecen en cascada
	_animate_buttons_appear()
	
	var tree_post = get_tree()
	if not tree_post or not is_inside_tree():
		return
	await tree_post.create_timer(0.6).timeout
	if not is_instance_valid(start_button):
		return
	start_button.grab_focus()

func _animate_buttons_appear() -> void:
	var buttons = [start_button, characters_button, workshop_button, 
				   collection_button, settings_button, quit_button]
	
	for btn in buttons:
		btn.modulate.a = 0.0
	
	var delay = 0.0
	for btn in buttons:
		var tree_anim = get_tree()
		if not tree_anim or not is_inside_tree():
			return
		await tree_anim.create_timer(delay).timeout
		if not is_instance_valid(btn):
			continue
		var btn_tween = create_tween().set_parallel(true)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.35)
		btn_tween.tween_property(btn, "position:x", btn.position.x, 0.35).from(btn.position.x - 25)
		delay += 0.07

# =========================
# HOVER EFFECTS (solo animaciones; estilos vienen del Theme)
# =========================
func _on_button_hover(btn: Button) -> void:
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if btn == start_button:
		# Botón principal: escala, brillo y líneas de escaneo
		t.tween_property(btn, "scale", HOVER_SCALE, 0.2)
		t.tween_property(btn, "modulate", Color(1.15, 1.15, 1.15), 0.2)
		_run_scan_line_effect()
	else:
		# Botones secundarios: escala y brillo sutiles
		t.tween_property(btn, "scale", HOVER_SCALE * 0.99, 0.2)
		t.tween_property(btn, "modulate", Color(1.1, 1.1, 1.1), 0.2)

func _on_button_exit(btn: Button) -> void:
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "scale", Vector2.ONE, 0.2)
	t.tween_property(btn, "modulate", Color.WHITE, 0.2)

# =========================
# ACCIONES DE BOTONES
# =========================
func _on_button_pressed_feedback(btn: Button) -> void:
	AudioManager.play_ui("ui_confirm")
	var t = create_tween()
	t.tween_property(btn, "scale", PRESS_SCALE, 0.05)
	t.tween_property(btn, "scale", Vector2.ONE, 0.08)

func _on_start_pressed() -> void:
	AudioManager.stop_music()
	var t = create_tween().set_parallel(true)
	t.tween_property(main_control, "modulate:a", 0.0, 0.5)
	t.tween_property(title, "scale", Vector2(1.2, 1.2), 0.5)
	
	await t.finished

	var tree := get_tree()
	if not tree:
		push_warning("MainMenu: get_tree() no disponible")
		return
	if GameManager and GameManager.has_method("set_playing"):
		GameManager.set_playing()
	tree.change_scene_to_file("res://levels/Arenas/Arena.tscn")

func _on_characters_pressed() -> void:
	var scene = load("res://ui/menus/character_select/CharacterSelect.tscn") as PackedScene
	if scene:
		var inst = scene.instantiate()
		add_child(inst)

func _on_workshop_pressed() -> void:
	var scene = load("res://ui/menus/workshop_screen/WorkshopScreen.tscn") as PackedScene
	if scene:
		var inst = scene.instantiate()
		add_child(inst)

func _on_collection_pressed() -> void:
	var scene = load("res://ui/menus/collection_screen/CollectionScreen.tscn") as PackedScene
	if scene:
		var inst = scene.instantiate()
		add_child(inst)

func _on_settings_pressed() -> void:
	var scene = load("res://ui/menus/options_menu/OptionsMenu.tscn") as PackedScene
	if scene:
		var inst = scene.instantiate()
		add_child(inst)

func _on_quit_pressed() -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(main_control, "modulate:a", 0.0, 0.4)
	t.tween_property(main_control, "scale", Vector2(0.9, 0.9), 0.4)

	await t.finished
	var tree = get_tree()
	if tree:
		tree.quit()

# =========================
# PLACEHOLDER "PRÓXIMAMENTE"
# =========================
func _show_coming_soon(feature_name: String) -> void:
	var label = Label.new()
	label.text = "[%s]\nPROXIMAMENTE" % feature_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", COLOR_CIAN_ENERGIA)
	label.add_theme_color_override("font_outline_color", COLOR_NEGRO_PROFUNDO)
	label.add_theme_constant_override("outline_size", 5)
	
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -280
	label.offset_top = -70
	label.offset_right = 280
	label.offset_bottom = 70
	label.pivot_offset = Vector2(280, 70)
	
	main_control.add_child(label)
	
	label.modulate.a = 0.0
	label.scale = Vector2(0.3, 0.3)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_property(label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	
	await tween.finished
	var tree_coming = get_tree()
	if tree_coming and is_inside_tree():
		await tree_coming.create_timer(2.0).timeout
	
	if is_instance_valid(label):
		tween = create_tween().set_parallel(true)
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
		tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3)
		await tween.finished
		label.queue_free()

# =========================
# MÉTODOS AUXILIARES
# =========================
func show_menu() -> void:
	visible = true
	_update_hud_info()
	_update_button_states()
	_animate_boot_sequence()

func hide_menu() -> void:
	visible = false

func _exit_tree() -> void:
	# Desconectar botones
	if is_instance_valid(start_button) and start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.disconnect(_on_start_pressed)
	if is_instance_valid(characters_button) and characters_button.pressed.is_connected(_on_characters_pressed):
		characters_button.pressed.disconnect(_on_characters_pressed)
	if is_instance_valid(workshop_button) and workshop_button.pressed.is_connected(_on_workshop_pressed):
		workshop_button.pressed.disconnect(_on_workshop_pressed)
	if is_instance_valid(collection_button) and collection_button.pressed.is_connected(_on_collection_pressed):
		collection_button.pressed.disconnect(_on_collection_pressed)
	if is_instance_valid(settings_button) and settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.disconnect(_on_settings_pressed)
	if is_instance_valid(quit_button) and quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.disconnect(_on_quit_pressed)

	# Desconectar hover effects
	var all_buttons: Array = [start_button, characters_button, workshop_button,
		collection_button, settings_button, quit_button]

	for btn in all_buttons:
		if is_instance_valid(btn):
			var hover_callable = _on_button_hover.bind(btn)
			var exit_callable = _on_button_exit.bind(btn)
			var press_callable = _on_button_pressed_feedback.bind(btn)
			if btn.mouse_entered.is_connected(hover_callable):
				btn.mouse_entered.disconnect(hover_callable)
			if btn.mouse_exited.is_connected(exit_callable):
				btn.mouse_exited.disconnect(exit_callable)
			if btn.pressed.is_connected(press_callable):
				btn.pressed.disconnect(press_callable)
