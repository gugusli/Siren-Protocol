extends CanvasLayer

# --- REFERENCIAS DE UI ---
@onready var main_control = $MainControl
@onready var panel = $MainControl/Panel
@onready var title = $MainControl/Panel/VBox/Title
@onready var status_msg = $MainControl/Panel/VBox/StatusMsg

@onready var value_time = $MainControl/Panel/VBox/StatsGrid/ValueTime
@onready var value_kills = $MainControl/Panel/VBox/StatsGrid/ValueKills
@onready var value_sinergy = $MainControl/Panel/VBox/StatsGrid/ValueSinergy

@onready var retry_btn = $MainControl/Panel/VBox/Buttons/RetryBtn
@onready var quit_btn = $MainControl/Panel/VBox/Buttons/QuitBtn
@onready var bg_overlay = $BackgroundBlur

const FONT_ORBITRON := "res://assets/fonts/Orbitron/static/Orbitron-Bold.ttf"
const FONT_ROBOTO := "res://assets/fonts/Roboto/static/Roboto-Regular.ttf"

# --- CONFIGURACIÓN ---
var is_victory := false
var defeat_messages: Array[String] = [
	"ABRUMADO POR LAS MUTACIONES",
	"SISTEMAS CRÍTICOS DAÑADOS",
	"CONEXIÓN NEURAL INTERRUMPIDA",
	"BIOMASA CONSUMIDA POR EL DISTRITO 0",
	"FALLO EN EL NÚCLEO DE PODER"
]

func _ready() -> void:
	hide()
	main_control.modulate.a = 0

	var font_orb := load(FONT_ORBITRON) as FontFile
	var font_roboto := load(FONT_ROBOTO) as FontFile
	if font_orb and title:
		title.add_theme_font_override("font", font_orb)
	if font_roboto:
		if status_msg:
			status_msg.add_theme_font_override("font", font_roboto)
		for lbl in [value_time, value_kills, value_sinergy]:
			if lbl:
				lbl.add_theme_font_override("font", font_roboto)

	# Conectar señales
	retry_btn.pressed.connect(_on_retry_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Efectos de hover para botones
	for btn in [retry_btn, quit_btn]:
		btn.mouse_entered.connect(func(): _animate_button(btn, true))
		btn.mouse_exited.connect(func(): _animate_button(btn, false))

# Función principal para disparar la pantalla
func setup_and_show(stats: Dictionary) -> void:
	is_victory = stats.get("victory", false)
	
	# 1. Configurar textos según el resultado
	if is_victory:
		title.text = "PROTOCOLO COMPLETADO"
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4)) # Verde Neón
		status_msg.text = "DATOS EXPORTADOS - DISTRITO 0 ASEGURADO"
	else:
		title.text = "PROTOCOLO ABORTADO"
		title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15)) # Rojo Alerta
		status_msg.text = defeat_messages.pick_random()

	# 2. Resetear valores para la animación
	value_time.text = stats.get("time", "00:00")
	value_kills.text = "0"
	value_sinergy.text = stats.get("sinergy", "Ninguna")

	# 3. Mostrar y Pausar
	show()
	var tree = get_tree()
	if tree:
		tree.paused = true
	_animate_entrance(stats.get("kills", 0))

func _animate_entrance(final_kills: int) -> void:
	var tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Aparecer fondo con glitch
	tween.tween_property(main_control, "modulate:a", 1.0, 0.4)
	bg_overlay.material.set_shader_parameter("intensity", 0.05)
	
	# Efecto "Pop" del panel
	panel.scale = Vector2(0.8, 0.8)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animar el conteo de bajas (Dopamina rápida)
	var count_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	count_tween.tween_method(func(v): value_kills.text = str(v), 0, final_kills, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	retry_btn.grab_focus()

func _animate_button(btn: Button, hovered: bool) -> void:
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if hovered:
		t.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.1) # Brillo neón
	else:
		t.tween_property(btn, "modulate", Color.WHITE, 0.1)

# --- ACCIONES ---
func _on_retry_pressed() -> void:
	var tree = get_tree()
	if not tree:
		push_warning("EndScreen: get_tree() no disponible")
		return
	# Evitar múltiples clics
	retry_btn.disabled = true
	# Efecto de "Apagado" antes de reiniciar; usar callback en vez de await para no depender del árbol pausado
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(main_control, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_QUART)
	t.tween_callback(_do_retry_reload)

func _do_retry_reload() -> void:
	var tree = get_tree()
	if not tree:
		return
	tree.paused = false
	tree.reload_current_scene()

func _on_quit_pressed() -> void:
	var tree = get_tree()
	if not tree:
		push_warning("EndScreen: get_tree() no disponible")
		return
	if GameManager and GameManager.has_method("set_menu"):
		GameManager.set_menu()
	tree.paused = false
	tree.change_scene_to_file("res://ui/menus/main_menu/MainMenu.tscn")
