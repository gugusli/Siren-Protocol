extends CanvasLayer

# =========================
# REFERENCIAS
# =========================
# Referencia al contenedor que tiene las cartas
@onready var container = $Container 
# Referencia al fondo oscuro
@onready var backdrop = $Backdrop

# Lista de botones
@onready var buttons = [
	$Container/Panel/VBox/CardContainer/ButtonOption1,
	$Container/Panel/VBox/CardContainer/ButtonOption2,
	$Container/Panel/VBox/CardContainer/ButtonOption3
]

# =========================
# COLORES DEL GDD
# =========================
const COLOR_COMUN := Color("#FFFFFF")
const COLOR_RARO := Color("#0099FF")
const COLOR_EPICO := Color("#9933FF")
const COLOR_LEGENDARIO := Color("#FFD700")
const COLOR_SINERGIA := Color("#FFD700")

var current_options: Array[String] = []

# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	# Aseguramos que el contenedor tenga el pivote en el centro para animar bien
	container.pivot_offset = container.size / 2
	
	# Ocultamos al inicio
	visible = false
	
	# Inicializamos la transparencia en los hijos, no en el CanvasLayer
	container.modulate.a = 0
	backdrop.modulate.a = 0

	# Conectamos señales
	for i in range(buttons.size()):
		var btn = buttons[i]
		# Conexión para click
		btn.pressed.connect(_on_upgrade_selected.bind(i))
		
		# Conexiones para animaciones HOVER (Escalar al pasar ratón)
		btn.pivot_offset = btn.size / 2 # Importante para que crezca desde el centro
		btn.mouse_entered.connect(_anim_hover_enter.bind(btn))
		btn.mouse_exited.connect(_anim_hover_exit.bind(btn))

# =========================
# MOSTRAR MENÚ (ANIMADO)
# =========================
func show_menu() -> void:
	var tree = get_tree()
	if not tree:
		push_warning("UpgradeMenu: get_tree() no disponible")
		return
	visible = true
	tree.paused = true # Pausa el juego
	
	# === LÓGICA DE CARTAS ===
	_setup_cards()
	
	# === ANIMACIÓN DE ENTRADA ===
	container.scale = Vector2(0.8, 0.8) # Empieza pequeño
	
	# Reseteamos la transparencia inicial
	container.modulate.a = 0.0 
	backdrop.modulate.a = 0.0
	
	# Usamos Tween para animar (Pause Mode process para funcionar en pausa)
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animamos el POP del contenedor
	tween.tween_property(container, "scale", Vector2.ONE, 0.4) 
	
	# Animamos la opacidad del contenedor y del fondo
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.3)

func _setup_cards():
	for b in buttons:
		b.disabled = false
		b.scale = Vector2.ONE
		b.pivot_offset = b.size / 2

	current_options.clear()

	# Usar UpgradeManager para obtener mejoras disponibles
	var tree = get_tree()
	if not tree:
		push_warning("UpgradeMenu: get_tree() no disponible en _setup_cards")
		return
	var wave_manager = tree.current_scene.get_node_or_null("WaveManager")
	var current_wave := 1
	if wave_manager:
		current_wave = wave_manager.current_wave
	
	var available_upgrades: Array = []
	if UpgradeManager:
		available_upgrades = UpgradeManager.get_available_upgrades(3, current_wave)
	else:
		# Fallback si UpgradeManager no está disponible
		available_upgrades = [UpgradeManager.UPGRADE_DAMAGE, UpgradeManager.UPGRADE_SPEED, UpgradeManager.UPGRADE_HEALTH]
	
	for i in range(buttons.size()):
		if i < available_upgrades.size():
			buttons[i].visible = true
			var upgrade_id: String = available_upgrades[i]
			current_options.append(upgrade_id)

			# Obtener datos del UpgradeManager
			var data = {}
			if UpgradeManager:
				data = UpgradeManager.get_upgrade_data(upgrade_id)
			
			if data.is_empty():
				buttons[i].text = upgrade_id
				buttons[i].add_theme_color_override("font_color", COLOR_COMUN)
				continue
			
			# Formatear texto
			var level_text := ""
			if data.get("current_level", 0) > 0:
				level_text = " (Nv.%d)" % data.current_level
			
			var desc: String = str(data.get("desc", ""))
			buttons[i].text = "%s%s\n\n%s" % [data.get("name", upgrade_id), level_text, desc]
			
			# Color según rareza (tipo explícito para evitar Variant)
			var rarity: int = data.get("rarity", 0) as int
			var color := COLOR_COMUN
			match rarity:
				1: color = COLOR_RARO
				2: color = COLOR_EPICO
				3: color = COLOR_LEGENDARIO
			
			buttons[i].add_theme_color_override("font_color", color)
			
			# ¿Completa una sinergia?
			if UpgradeManager:
				var synergy_info = UpgradeManager.check_would_complete_synergy(upgrade_id)
				if not synergy_info.is_empty():
					buttons[i].text += "\n\n⚡ ¡SINERGIA DISPONIBLE!"
					buttons[i].add_theme_color_override("font_color", COLOR_SINERGIA)
			
			# Borde por rareza (GDD: gris/azul/púrpura/dorado)
			_apply_rarity_border(buttons[i], color)
		else:
			buttons[i].visible = false

func _apply_rarity_border(btn: Button, rarity_color: Color) -> void:
	var style_normal = btn.get_theme_stylebox("normal").duplicate()
	var style_hover = btn.get_theme_stylebox("hover").duplicate()
	var style_pressed = btn.get_theme_stylebox("pressed").duplicate()
	if style_normal is StyleBoxFlat:
		style_normal.border_color = rarity_color
	if style_hover is StyleBoxFlat:
		style_hover.border_color = rarity_color
		style_hover.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.5)
	if style_pressed is StyleBoxFlat:
		style_pressed.border_color = rarity_color
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)

# =========================
# SELECCIÓN Y CIERRE
# =========================
func _on_upgrade_selected(index: int) -> void:
	if index >= current_options.size(): return

	# Bloquear botones
	for btn in buttons: btn.disabled = true

	var upgrade_key = current_options[index]
	
	# Aplicar mejora via UpgradeManager (ya notifica al jugador internamente)
	if UpgradeManager:
		UpgradeManager.apply_upgrade(upgrade_key)

	# Animación de salida
	_close_menu_animated()

func _close_menu_animated():
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Se hace pequeño y transparente
	tween.tween_property(container, "scale", Vector2(0.8, 0.8), 0.2)
	
	# Desvanecemos el contenedor y el fondo
	tween.tween_property(container, "modulate:a", 0.0, 0.2)
	tween.tween_property(backdrop, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	visible = false
	var tree = get_tree()
	if tree:
		tree.paused = false # Reanudar juego

# =========================
# ANIMACIONES DE HOVER
# =========================
func _anim_hover_enter(btn: Button):
	if btn.disabled: return
	# Crece un poco
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _anim_hover_exit(btn: Button):
	if btn.disabled: return
	# Vuelve a tamaño normal
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.1)
