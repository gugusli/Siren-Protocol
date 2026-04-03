extends CanvasLayer

## =========================
## HUD - Interfaz durante gameplay
## Actualizado según GDD Visual v4
## =========================

@onready var stats_panel := $StatsPanel
@onready var health_bar := $StatsPanel/Margin/Content/HPSection/HealthBar
@onready var health_label := $StatsPanel/Margin/Content/HPSection/HealthBar/HealthLabel
@onready var exp_bar := $StatsPanel/Margin/Content/ExpBar
@onready var level_label := $StatsPanel/Margin/Content/Header/LevelNumber
@onready var wave_label := $WaveLabel
@onready var synergy_icons := $SynergyIcons
@onready var seren_label: Label = $SerenLabel if has_node("SerenLabel") else null
@onready var intensity_label := $IntensityLabel
@onready var timer_label := $TimerLabel

var _fps_label: Label
var _fps_button: Button
var _show_fps: bool = false

const FONT_ORBITRON := "res://assets/fonts/Orbitron/static/Orbitron-Bold.ttf"
const FONT_ROBOTO := "res://assets/fonts/Roboto/static/Roboto-Regular.ttf"

var health_tween: Tween
var alert_tween: Tween
var is_low_hp := false
var _connected_player: Node = null
var _wave_manager_ref: Node = null

# Colores del GDD
const COLOR_CIAN := Color("#00D9FF")
const COLOR_VERDE := Color("#00FF66")
const COLOR_AMARILLO := Color("#FFFF00")
const COLOR_ROJO := Color("#CC0000")
const COLOR_DORADO := Color("#FFD700")
const COLOR_PURPURA := Color("#9933FF")

func _ready() -> void:
	# Validar nodos requeridos (@onready)
	var required_nodes: Array = [stats_panel, health_bar, health_label, exp_bar, level_label, wave_label]
	for node in required_nodes:
		if not is_instance_valid(node):
			push_error("HUD: Nodo requerido no encontrado o inválido")
			return

	visible = true
	level_label.pivot_offset = level_label.size / 2
	wave_label.pivot_offset = wave_label.size / 2

	var font_orb := load(FONT_ORBITRON) as FontFile
	var font_roboto := load(FONT_ROBOTO) as FontFile
	if font_orb:
		wave_label.add_theme_font_override("font", font_orb)
		level_label.add_theme_font_override("font", font_orb)
		if seren_label:
			seren_label.add_theme_font_override("font", font_orb)
	if font_roboto:
		health_label.add_theme_font_override("font", font_roboto)
		timer_label.add_theme_font_override("font", font_roboto)
		intensity_label.add_theme_font_override("font", font_roboto)
	var sys_label := get_node_or_null("StatsPanel/Margin/Content/Header/LevelLabel")
	if sys_label and font_roboto:
		sys_label.add_theme_font_override("font", font_roboto)

	# Botón y label para mostrar FPS en tiempo real
	_setup_fps_controls(font_roboto)

	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	if GameManager and GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)

	if UpgradeManager and not UpgradeManager.synergy_unlocked.is_connected(_on_synergy_unlocked):
		UpgradeManager.synergy_unlocked.connect(_on_synergy_unlocked)
	if SynergyManager and not SynergyManager.synergy_activated.is_connected(_on_synergy_activated):
		SynergyManager.synergy_activated.connect(_on_synergy_activated)

	var wm = tree.current_scene.get_node_or_null("WaveManager")
	if wm:
		_wave_manager_ref = wm
		set_wave(wm.current_wave)
		if not wm.wave_started.is_connected(set_wave):
			wm.wave_started.connect(set_wave)

func _setup_fps_controls(font_roboto: FontFile) -> void:
	_fps_button = Button.new()
	_fps_button.text = "FPS"
	_fps_button.toggle_mode = true
	_fps_button.focus_mode = Control.FOCUS_NONE
	add_child(_fps_button)
	_fps_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_button.offset_left = -90
	_fps_button.offset_right = -10
	_fps_button.offset_top = 10
	_fps_button.offset_bottom = 40
	_fps_button.pressed.connect(_on_fps_button_pressed)

	_fps_label = Label.new()
	_fps_label.text = "FPS: 0"
	_fps_label.visible = false
	if font_roboto:
		_fps_label.add_theme_font_override("font", font_roboto)
	add_child(_fps_label)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -200
	_fps_label.offset_right = -100
	_fps_label.offset_top = 12
	_fps_label.offset_bottom = 32

func _on_fps_button_pressed() -> void:
	_show_fps = _fps_button.button_pressed
	if _fps_label:
		_fps_label.visible = _show_fps

func connect_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
	_connected_player = player
	# Joystick virtual para móvil
	if "_virtual_joystick" in player:
		player._virtual_joystick = get_node_or_null("VirtualJoystick")
	var ability_btn = get_node_or_null("AbilityButton")
	if ability_btn and not ability_btn.pressed.is_connected(_on_ability_button_pressed):
		ability_btn.pressed.connect(_on_ability_button_pressed)
	var damageable = player.get_node_or_null("Damageable")
	if damageable and is_instance_valid(damageable):
		if damageable.health_changed.is_connected(_on_health_changed):
			damageable.health_changed.disconnect(_on_health_changed)
		damageable.health_changed.connect(_on_health_changed)
		_update_hp_visual(damageable.health, damageable.max_health)

	if player.has_signal("experience_changed"):
		player.experience_changed.connect(_on_experience_changed)
	if player.has_signal("leveled_up"):
		player.leveled_up.connect(_on_leveled_up)
	if player.has_signal("corruption_stacks_changed"):
		player.corruption_stacks_changed.connect(update_corruption_stacks)
		var stacks: int = player.get("corruption_stacks") if "corruption_stacks" in player else 0
		update_corruption_stacks(stacks, 10)
	_refresh_synergy_icons()

func _on_ability_button_pressed() -> void:
	if _connected_player and is_instance_valid(_connected_player) and _connected_player.has_method("request_ability"):
		_connected_player.request_ability()

func _on_health_changed(current: float, max_health: float) -> void:
	if not is_instance_valid(health_bar):
		return
	var old_val = health_bar.value
	_update_hp_visual(current, max_health)
	if health_tween: health_tween.kill()
	health_tween = create_tween().set_parallel(true)
	health_tween.tween_property(health_bar, "value", current, 0.2).set_trans(Tween.TRANS_CUBIC)
	if current < old_val:
		_apply_damage_fx()

func _update_hp_visual(curr: float, m_hp: float) -> void:
	health_bar.max_value = m_hp
	health_label.text = "%d / %d" % [int(curr), int(m_hp)]
	
	# Colores según GDD: verde > amarillo > rojo
	var health_percent := curr / m_hp
	if health_percent > 0.5:
		health_bar.modulate = COLOR_VERDE
	elif health_percent > 0.25:
		health_bar.modulate = COLOR_AMARILLO
	else:
		health_bar.modulate = COLOR_ROJO
	
	if health_percent <= 0.3:
		if not is_low_hp: _start_low_hp_alert()
	else:
		_stop_low_hp_alert()

func _apply_damage_fx() -> void:
	var t = create_tween()
	stats_panel.modulate = Color(2, 1, 1)
	t.tween_property(stats_panel, "modulate", Color.WHITE, 0.2)
	_shake_ui(stats_panel, 5.0)

func _start_low_hp_alert() -> void:
	is_low_hp = true
	if alert_tween: alert_tween.kill()
	alert_tween = create_tween().set_loops()
	alert_tween.tween_property(health_bar, "modulate", Color(2, 0.5, 0.5), 0.5)
	alert_tween.tween_property(health_bar, "modulate", Color.WHITE, 0.5)

func _stop_low_hp_alert() -> void:
	is_low_hp = false
	if alert_tween: 
		alert_tween.kill()
		health_bar.modulate = Color.WHITE

func _on_experience_changed(current: int, required: int) -> void:
	exp_bar.max_value = required
	create_tween().tween_property(exp_bar, "value", current, 0.3).set_trans(Tween.TRANS_SINE)

func _on_leveled_up(new_level: int) -> void:
	level_label.text = "LVL %02d" % new_level
	var t = create_tween()
	t.tween_property(level_label, "scale", Vector2(1.3, 1.3), 0.1)
	t.tween_property(level_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

func set_wave(number: int) -> void:
	wave_label.text = "— OLEADA %02d —" % number
	var t = create_tween()
	wave_label.modulate.a = 0
	t.tween_property(wave_label, "modulate:a", 1.0, 0.4)
	t.tween_property(wave_label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	t.tween_property(wave_label, "scale", Vector2.ONE, 0.2).set_delay(0.2)

func _shake_ui(node: Control, intensity: float) -> void:
	var orig_pos = node.position
	var t = create_tween()
	for i in range(4):
		var rand_pos = orig_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		t.tween_property(node, "position", rand_pos, 0.05)
	t.tween_property(node, "position", orig_pos, 0.05)

func _on_synergy_unlocked(synergy_name: String, level: int) -> void:
	show_synergy_popup(synergy_name, level)
	_refresh_synergy_icons()

func _on_synergy_activated(synergy_id: String, level: int) -> void:
	show_synergy_notification(synergy_id, level)
	_refresh_synergy_icons()

func _on_game_state_changed(state: int) -> void:
	if not GameManager:
		return
	match state:
		GameManager.GameState.PLAYING:
			visible = true
		_:
			visible = false
			_stop_low_hp_alert()

# =========================
# INDICADOR DE SINERGIAS
# =========================
func show_synergy_popup(synergy_name: String, level: int) -> void:
	var synergy_label := Label.new()
	synergy_label.text = "¡SINERGIA NIVEL %d!\n%s" % [level, synergy_name]
	synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synergy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if level == 2:
		synergy_label.modulate = COLOR_DORADO
	else:
		synergy_label.modulate = COLOR_PURPURA
	
	synergy_label.position = Vector2(get_viewport().size.x / 2 - 150, 200)
	synergy_label.size = Vector2(300, 80)
	
	add_child(synergy_label)
	
	var tween = create_tween()
	synergy_label.scale = Vector2(0.5, 0.5)
	synergy_label.modulate.a = 0
	tween.parallel().tween_property(synergy_label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(synergy_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(synergy_label, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(synergy_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(synergy_label.queue_free)

# =========================
# NOTIFICACIÓN DE SINERGIA (panel central, tocar para continuar)
# =========================
func show_synergy_notification(synergy_id: String, level: int) -> void:
	var panel := Panel.new()
	panel.name = "SynergyNotification"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel)
	
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -150
	panel.offset_bottom = 150
	panel.custom_minimum_size = Vector2(400, 300)
	
	var bg_color := COLOR_DORADO if level == 2 else COLOR_PURPURA
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.95)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "¡SINERGIA DESBLOQUEADA!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	var synergy_name := _get_synergy_display_name(synergy_id)
	var name_label := Label.new()
	name_label.text = synergy_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", bg_color)
	vbox.add_child(name_label)
	
	var description := _get_synergy_description(synergy_id)
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.y = 60
	vbox.add_child(desc_label)
	
	var continue_label := Label.new()
	continue_label.text = "[ Clic o Enter para continuar ]"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(continue_label)
	
	# Esperar input sin pausar el árbol (mejor UX)
	await get_tree().create_timer(0.5).timeout
	await _wait_for_synergy_input()
	panel.queue_free()

func _get_synergy_display_name(synergy_id: String) -> String:
	if SynergyManager:
		return SynergyManager.get_synergy_name(synergy_id)
	var data := UpgradeManager.get_synergy_data(synergy_id) if UpgradeManager else {}
	return data.get("name", synergy_id.capitalize())

func _get_synergy_description(synergy_id: String) -> String:
	if SynergyManager:
		var syn_data := SynergyManager.get_synergy_data(synergy_id)
		return syn_data.get("desc", "Sinergia activada.")
	var fallback_data: Dictionary = UpgradeManager.get_synergy_data(synergy_id) if UpgradeManager else {}
	return fallback_data.get("desc", "Sinergia activada.")

func _wait_for_synergy_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break

# =========================
# INDICADOR DE INTENSIDAD (Director IA)
# =========================
func update_intensity_indicator() -> void:
	if not DirectorAI or not is_instance_valid(intensity_label):
		return
	intensity_label.text = "DIRECTOR: %s" % DirectorAI.get_intensity_state_name()
	intensity_label.add_theme_color_override("font_color", DirectorAI.get_intensity_color())

func _update_timer() -> void:
	if not is_instance_valid(timer_label) or not GameManager:
		return
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return
	var elapsed = (Time.get_ticks_msec() / 1000.0) - GameManager.current_session.get("start_time", 0.0)
	timer_label.text = GameManager.format_time(elapsed)

func _process(_delta: float) -> void:
	if not GameManager:
		return
	if GameManager.game_state == GameManager.GameState.PLAYING:
		update_intensity_indicator()
		_update_timer()
		if _show_fps and _fps_label:
			_fps_label.text = "FPS: %d" % int(Engine.get_frames_per_second())

# =========================
# INDICADORES DE SINERGIAS ACTIVAS (GDD §2.5 - centro superior)
# =========================
func _refresh_synergy_icons() -> void:
	if not is_instance_valid(synergy_icons):
		return
	for c in synergy_icons.get_children():
		c.queue_free()
	if not UpgradeManager:
		return
	for syn_id in UpgradeManager.active_synergies_l2:
		var data = UpgradeManager.get_synergy_data(syn_id)
		if data.is_empty() and SynergyManager:
			data = SynergyManager.get_synergy_data(syn_id)
		_add_synergy_badge(data.get("name", syn_id), 2, data.get("color", COLOR_DORADO))
	for syn_id in UpgradeManager.active_synergies_l3:
		var data = UpgradeManager.get_synergy_data(syn_id)
		if data.is_empty() and SynergyManager:
			data = SynergyManager.get_synergy_data(syn_id)
		_add_synergy_badge(data.get("name", syn_id), 3, data.get("color", COLOR_PURPURA))

func _add_synergy_badge(name_text: String, level: int, color: Color) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(32, 32)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	# Glow dorado o arcoíris según nivel
	if level == 2:
		style.shadow_color = Color(color.r, color.g, color.b, 0.7)
		style.shadow_size = 6
	else:
		style.shadow_color = Color(1, 1, 1, 0.8)
		style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = str(level)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	synergy_icons.add_child(panel)
	panel.tooltip_text = name_text
	# L3: efecto arcoíris animado en el badge
	if level == 3:
		var tween := panel.create_tween().set_loops()
		tween.tween_property(panel, "modulate", Color(1.0, 0.6, 0.6), 0.25)
		tween.tween_property(panel, "modulate", Color(0.6, 1.0, 0.6), 0.25)
		tween.tween_property(panel, "modulate", Color(0.6, 0.6, 1.0), 0.25)
		tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.25)

# =========================
# ADVERTENCIAS DE EVENTOS ESPECIALES (GDD §8.3)
# =========================
func show_event_warning(text: String, color: Color) -> void:
	var warning_label := get_node_or_null("EventWarningLabel")
	if not warning_label:
		warning_label = Label.new()
		warning_label.name = "EventWarningLabel"
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(warning_label)
		warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		warning_label.anchor_top = 0.3
		warning_label.anchor_bottom = 0.3
		warning_label.offset_left = -300
		warning_label.offset_right = 300
		warning_label.offset_top = -50
		warning_label.offset_bottom = 50
	warning_label.text = text
	warning_label.add_theme_font_size_override("font_size", 48)
	warning_label.add_theme_color_override("font_color", color)
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.add_theme_constant_override("outline_size", 5)
	warning_label.modulate = Color.WHITE
	warning_label.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(warning_label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(warning_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	tween.chain().tween_callback(func(): warning_label.visible = false)

func update_king_of_hill_progress(progress: float) -> void:
	var bar := get_node_or_null("KingOfHillProgress")
	if not bar:
		return
	bar.visible = true
	bar.value = progress * 100.0
	if progress >= 1.0:
		var t := create_tween()
		t.tween_interval(1.0)
		t.tween_callback(func(): bar.visible = false)

# =========================
# STACKS DE CORRUPCIÓN (ECO - GDD §7.5)
# =========================
func update_corruption_stacks(stacks: int, max_stacks: int) -> void:
	var stack_container := get_node_or_null("CorruptionStacks")
	if not stack_container:
		stack_container = HBoxContainer.new()
		stack_container.name = "CorruptionStacks"
		add_child(stack_container)
		stack_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		stack_container.offset_left = -220
		stack_container.offset_top = 10
		stack_container.offset_right = -10
		stack_container.offset_bottom = 40
	for child in stack_container.get_children():
		child.queue_free()
	var circle_tex := _create_circle_texture(8)
	for i in range(max_stacks):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i < stacks:
			icon.modulate = COLOR_CIAN
		else:
			icon.modulate = Color(0.3, 0.3, 0.3)
		icon.texture = circle_tex
		stack_container.add_child(icon)

func _create_circle_texture(radius: int) -> ImageTexture:
	var image := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			if Vector2(x, y).distance_to(Vector2(radius, radius)) <= radius:
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)

func _exit_tree() -> void:
	# Desconectar señales para evitar leaks y lógica zombie
	if GameManager and GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.disconnect(_on_game_state_changed)
	if UpgradeManager and UpgradeManager.synergy_unlocked.is_connected(_on_synergy_unlocked):
		UpgradeManager.synergy_unlocked.disconnect(_on_synergy_unlocked)
	if SynergyManager and SynergyManager.synergy_activated.is_connected(_on_synergy_activated):
		SynergyManager.synergy_activated.disconnect(_on_synergy_activated)
	if _wave_manager_ref and is_instance_valid(_wave_manager_ref) and _wave_manager_ref.wave_started.is_connected(set_wave):
		_wave_manager_ref.wave_started.disconnect(set_wave)
	_wave_manager_ref = null
	if _connected_player and is_instance_valid(_connected_player):
		var damageable = _connected_player.get_node_or_null("Damageable")
		if damageable and is_instance_valid(damageable) and damageable.health_changed.is_connected(_on_health_changed):
			damageable.health_changed.disconnect(_on_health_changed)
		if _connected_player.has_signal("experience_changed") and _connected_player.experience_changed.is_connected(_on_experience_changed):
			_connected_player.experience_changed.disconnect(_on_experience_changed)
		if _connected_player.has_signal("leveled_up") and _connected_player.leveled_up.is_connected(_on_leveled_up):
			_connected_player.leveled_up.disconnect(_on_leveled_up)
		if _connected_player.has_signal("corruption_stacks_changed") and _connected_player.corruption_stacks_changed.is_connected(update_corruption_stacks):
			_connected_player.corruption_stacks_changed.disconnect(update_corruption_stacks)
	_connected_player = null
