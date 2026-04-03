extends CanvasLayer

# =========================
# REFERENCIAS
# =========================
@onready var overlay = $Overlay
@onready var main_control = $MainControl
@onready var side_panel = $MainControl/SidePanel

@onready var resume_button = $MainControl/SidePanel/VBox/ResumeButton
@onready var restart_button = $MainControl/SidePanel/VBox/RestartButton
@onready var main_menu_button = $MainControl/SidePanel/VBox/MainMenuButton
@onready var quit_button = $MainControl/SidePanel/VBox/QuitButton

var is_paused := false
var buttons: Array[Button] = []

# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	# Importante: El Menú de Pausa debe poder procesar aunque el juego esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	visible = false
	main_control.modulate.a = 0
	overlay.modulate.a = 0
	
	buttons = [resume_button, restart_button, main_menu_button, quit_button]
	
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Sincronizar visibilidad con estado de pausa del GameManager
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)
	
	for btn in buttons:
		btn.pivot_offset = btn.size / 2
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_exit.bind(btn))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if GameManager.game_state == GameManager.GameState.PLAYING or is_paused:
			_handle_pause_logic()

# =========================
# LÓGICA DE PAUSA (Sincronizada con GameManager)
# =========================
func _handle_pause_logic() -> void:
	is_paused = !is_paused
	
	if is_paused:
		GameManager.set_paused()
	else:
		GameManager.set_playing()
	
	if is_paused:
		visible = true
		_animate_entrance()
	else:
		_animate_exit()

# =========================
# ANIMACIONES
# =========================
func _animate_entrance() -> void:
	side_panel.position.x = -side_panel.size.x
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(main_control, "modulate:a", 1.0, 0.3)
	tween.tween_property(side_panel, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK)
	
	_animate_buttons_in()

func _animate_buttons_in() -> void:
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.modulate.a = 0
		var original_x = btn.position.x
		btn.position.x -= 20
		
		var bt = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		bt.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(0.1 + (i * 0.05))
		bt.tween_property(btn, "position:x", original_x, 0.3).set_delay(0.1 + (i * 0.05)).set_trans(Tween.TRANS_BACK)

func _animate_exit() -> void:
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.tween_property(side_panel, "position:x", -side_panel.size.x, 0.2)
	tween.tween_property(main_control, "modulate:a", 0.0, 0.2)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	visible = false

# =========================
# FEEDBACK BOTONES
# =========================
func _on_button_hover(btn: Button) -> void:
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(btn, "self_modulate", Color(1.4, 1.4, 1.4), 0.15)

func _on_button_exit(btn: Button) -> void:
	var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(btn, "self_modulate", Color.WHITE, 0.15)

# =========================
# SEÑALES
# =========================
func _on_resume_pressed() -> void:
	_handle_pause_logic()

func _on_restart_pressed() -> void:
	var tree = get_tree()
	if not tree:
		push_warning("PauseMenu: get_tree() no disponible")
		return
	tree.paused = false
	GameManager.set_playing()
	tree.reload_current_scene()

func _on_main_menu_pressed() -> void:
	var tree = get_tree()
	if not tree:
		push_warning("PauseMenu: get_tree() no disponible")
		return
	tree.paused = false
	GameManager.set_menu()
	tree.change_scene_to_file("res://ui/menus/main_menu/MainMenu.tscn")

func _on_game_state_changed(_state: int) -> void:
	if GameManager.game_state != GameManager.GameState.PAUSED and is_paused:
		is_paused = false
		visible = false

func _on_quit_pressed() -> void:
	var tree = get_tree()
	if not tree:
		push_warning("PauseMenu: get_tree() no disponible")
		return
	tree.quit()
