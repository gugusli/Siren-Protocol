extends CanvasLayer

## Menú de opciones: volumen, pantalla, screen shake, números de daño.
## Lee/escribe GameManager.settings.

@onready var panel := $Panel
@onready var back_button: Button = $Panel/Margin/VBox/BackButton
@onready var master_slider: HSlider = $Panel/Margin/VBox/MasterVolume/MasterSlider
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicVolume/MusicSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxVolume/SfxSlider
@onready var screen_shake_check: CheckButton = $Panel/Margin/VBox/ScreenShakeCheck
@onready var damage_numbers_check: CheckButton = $Panel/Margin/VBox/DamageNumbersCheck
@onready var fullscreen_check: CheckButton = $Panel/Margin/VBox/FullscreenCheck

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_settings()
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _load_settings() -> void:
	if not GameManager:
		return
	var s: Dictionary = GameManager.settings
	master_slider.value = s.get("master_volume", 1.0)
	music_slider.value = s.get("music_volume", 0.7)
	sfx_slider.value = s.get("sfx_volume", 1.0)
	screen_shake_check.button_pressed = s.get("screen_shake_enabled", true)
	damage_numbers_check.button_pressed = s.get("show_damage_numbers", true)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_apply_audio()
	if VFXManager:
		VFXManager.screen_shake_enabled = s.get("screen_shake_enabled", true)
		VFXManager.damage_numbers_enabled = s.get("show_damage_numbers", true)

func _on_master_changed(value: float) -> void:
	GameManager.settings["master_volume"] = value
	_apply_audio()

func _on_music_changed(value: float) -> void:
	GameManager.settings["music_volume"] = value
	_apply_audio()

func _on_sfx_changed(value: float) -> void:
	GameManager.settings["sfx_volume"] = value
	_apply_audio()

func _apply_audio() -> void:
	if AudioManager:
		AudioManager.refresh_volumes_from_settings()

func _on_screen_shake_toggled(pressed: bool) -> void:
	GameManager.settings["screen_shake_enabled"] = pressed
	if VFXManager:
		VFXManager.screen_shake_enabled = pressed

func _on_damage_numbers_toggled(pressed: bool) -> void:
	GameManager.settings["show_damage_numbers"] = pressed
	if VFXManager:
		VFXManager.damage_numbers_enabled = pressed

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	GameManager.save_game()
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.2)
	await t.finished
	queue_free()
