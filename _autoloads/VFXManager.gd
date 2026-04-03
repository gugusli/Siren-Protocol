extends Node

## =========================
## AFTERSHOCK - VFX Manager
## Sistema de efectos visuales según GDD
## =========================

# =========================
# COLORES DEL GDD
# =========================
const COLOR_CRITICO := Color("#FF0033")
const COLOR_NORMAL := Color("#FFFFFF")
const COLOR_FUEGO := Color("#FF6600")
const COLOR_HIELO := Color("#00BFFF")
const COLOR_VENENO := Color("#9900FF")
const COLOR_ELECTRICO := Color("#00BFFF")
const COLOR_DORADO := Color("#FFD700")

# =========================
# CONFIGURACIÓN DE EFECTOS (GDD §11.2: 60 FPS en mid-range)
# =========================
var hitstop_enabled := true
var screen_shake_enabled := true
var damage_numbers_enabled := true
var slowmo_on_crit := true
const MAX_SPARK_PARTICLES := 30  # Límite para mantener FPS en oleadas densas
var _active_spark_count := 0

# Constantes (evitar magic numbers)
const SHAKE_INTENSITY_NORMAL := 1.5
const SHAKE_DURATION_NORMAL := 0.08
const SHAKE_INTENSITY_CRIT := 4.0
const SHAKE_DURATION_CRIT := 0.12
const HITSTOP_DURATION_NORMAL := 0.02
const HITSTOP_DURATION_CRIT := 0.05
const SLOWMO_SCALE_CRIT := 0.3
const SLOWMO_DURATION_CRIT := 0.1
const DAMAGE_FONT_SIZE_NORMAL := 18
const DAMAGE_FONT_SIZE_CRIT := 26
const DAMAGE_LABEL_OUTLINE_SIZE := 3
const DAMAGE_LABEL_FLOAT_HEIGHT := 50.0
const DAMAGE_LABEL_FADE_DELAY := 0.3
const DAMAGE_LABEL_FADE_DURATION := 0.4
const DAMAGE_LABEL_ANIM_DURATION := 0.6
const SPARK_SPEED_MIN := 80.0
const SPARK_SPEED_MAX := 150.0
const SPARK_TRAVEL_MULT := 0.3
const SPARK_ANIM_DURATION := 0.25
const IMPACT_FLASH_SIZE := 32
const SYNERGY_SHAKE_INTENSITY := 8.0
const SYNERGY_SHAKE_DURATION := 0.3
const SYNERGY_SLOWMO_SCALE := 0.2
const SYNERGY_SLOWMO_DURATION := 0.3
const DEATH_SPARKS_NORMAL := 8
const DEATH_SPARKS_ELITE := 15
const DEATH_SHAKE_ELITE := 6.0
const EXPLOSION_SHAKE := 7.0
const COLOR_SYNERGY_L3 := Color("#9933FF")

# =========================
# REFERENCIAS
# =========================
var camera: Node = null

var _slowmo_active := false
var _flash_overlay: ColorRect = null

func _ready() -> void:
	_init_flash_overlay()

# =========================
# IMPACTO NORMAL
# =========================
func _use_screen_shake() -> bool:
	if GameManager:
		return GameManager.settings.get("screen_shake_enabled", screen_shake_enabled)
	return screen_shake_enabled

func _use_damage_numbers() -> bool:
	if GameManager:
		return GameManager.settings.get("show_damage_numbers", damage_numbers_enabled)
	return damage_numbers_enabled

func play_hit_effect(position: Vector2, damage: float, is_critical: bool = false) -> void:
	if is_critical:
		_play_critical_hit(position, damage)
	else:
		_play_normal_hit(position, damage)

func _play_normal_hit(position: Vector2, damage: float) -> void:
	if _use_damage_numbers():
		_spawn_damage_number(position, damage, COLOR_NORMAL, 1.0)
	
	# Chispas pequeñas
	_spawn_spark_particles(position, 5, COLOR_NORMAL)
	
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", SHAKE_INTENSITY_NORMAL, SHAKE_DURATION_NORMAL)

	# Hitstop breve (1-2 frames)
	if hitstop_enabled:
		_apply_hitstop(HITSTOP_DURATION_NORMAL)

func _play_critical_hit(position: Vector2, damage: float) -> void:
	if _use_damage_numbers():
		_spawn_damage_number(position, damage, COLOR_CRITICO, 1.5, true)
	
	# Más chispas
	_spawn_spark_particles(position, 15, COLOR_CRITICO)
	
	# Flash rojo en el punto de impacto
	_spawn_impact_flash(position, COLOR_CRITICO)
	
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", SHAKE_INTENSITY_CRIT, SHAKE_DURATION_CRIT)

	# Hitstop mayor (3-4 frames)
	if hitstop_enabled:
		_apply_hitstop(HITSTOP_DURATION_CRIT)

	# Slowmo breve
	if slowmo_on_crit:
		apply_slowmo(SLOWMO_SCALE_CRIT, SLOWMO_DURATION_CRIT)

# =========================
# NÚMEROS DE DAÑO FLOTANTE (object pooling GDD §11.3)
# =========================
func _spawn_damage_number(pos: Vector2, damage: float, color: Color, scale_mult: float = 1.0, add_exclaim: bool = false) -> void:
	var damage_text: String = str(int(damage))
	if add_exclaim:
		damage_text += "!"
	var base_size: int = int((DAMAGE_FONT_SIZE_CRIT if add_exclaim else DAMAGE_FONT_SIZE_NORMAL) * scale_mult)

	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_DAMAGE_NUMBER):
		var pooled_label = PoolManager.get_pooled_object(PoolManager.POOL_KEY_DAMAGE_NUMBER)
		if pooled_label and pooled_label.has_method("play"):
			pooled_label.play(damage_text, pos, color, base_size, scale_mult, add_exclaim)
		return

	var damage_label: Label = Label.new()
	damage_label.text = damage_text
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_size_override("font_size", base_size)
	damage_label.add_theme_color_override("font_color", color)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", DAMAGE_LABEL_OUTLINE_SIZE)
	damage_label.global_position = pos + Vector2(randf_range(-10, 10), -20)
	damage_label.z_index = 100
	damage_label.scale = Vector2(scale_mult, scale_mult)
	get_tree().current_scene.add_child(damage_label)
	var tween: Tween = damage_label.create_tween().set_parallel(true)
	tween.tween_property(damage_label, "global_position:y", damage_label.global_position.y - DAMAGE_LABEL_FLOAT_HEIGHT, DAMAGE_LABEL_ANIM_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "modulate:a", 0.0, DAMAGE_LABEL_FADE_DURATION).set_delay(DAMAGE_LABEL_FADE_DELAY)
	if add_exclaim:
		var scale_tween: Tween = damage_label.create_tween()
		scale_tween.tween_property(damage_label, "scale", Vector2(scale_mult * 1.3, scale_mult * 1.3), 0.1)
		scale_tween.tween_property(damage_label, "scale", Vector2(scale_mult, scale_mult), 0.15)
	tween.chain().tween_callback(damage_label.queue_free)

# =========================
# PARTÍCULAS DE CHISPAS (object pooling GDD §11.3, con límite para rendimiento)
# =========================
func _spawn_spark_particles(pos: Vector2, count: int, color: Color) -> void:
	if _active_spark_count >= MAX_SPARK_PARTICLES:
		count = 0
	else:
		count = mini(count, MAX_SPARK_PARTICLES - _active_spark_count)
	var use_pool: bool = PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_SPARK)
	for i in range(count):
		_active_spark_count += 1
		if use_pool:
			var pooled_spark = PoolManager.get_pooled_object(PoolManager.POOL_KEY_SPARK)
			if pooled_spark and pooled_spark.has_method("play"):
				pooled_spark.play(pos, color)
			_active_spark_count -= 1
			continue
		var spark_node: Sprite2D = Sprite2D.new()
		spark_node.texture = PlaceholderTexture2D.new()
		spark_node.texture.size = Vector2(4, 4)
		spark_node.modulate = color
		spark_node.global_position = pos
		spark_node.z_index = 50
		get_tree().current_scene.add_child(spark_node)
		var angle: float = randf() * TAU
		var speed: float = randf_range(SPARK_SPEED_MIN, SPARK_SPEED_MAX)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var target_pos: Vector2 = pos + direction * speed * SPARK_TRAVEL_MULT
		var tween: Tween = spark_node.create_tween().set_parallel(true)
		tween.tween_property(spark_node, "global_position", target_pos, SPARK_ANIM_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark_node, "modulate:a", 0.0, 0.2).set_delay(0.1)
		tween.tween_property(spark_node, "scale", Vector2(0.3, 0.3), SPARK_ANIM_DURATION)
		tween.chain().tween_callback(func(): _on_spark_freed(spark_node))

func _on_spark_freed(spark: Node) -> void:
	_active_spark_count = maxi(0, _active_spark_count - 1)
	spark.queue_free()

# =========================
# FLASH DE IMPACTO (object pooling GDD §11.3)
# =========================
func _spawn_impact_flash(pos: Vector2, color: Color) -> void:
	if PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_IMPACT_FLASH):
		var pooled_flash = PoolManager.get_pooled_object(PoolManager.POOL_KEY_IMPACT_FLASH)
		if pooled_flash and pooled_flash.has_method("play"):
			pooled_flash.play(pos, color)
		return
	var impact_flash: Sprite2D = Sprite2D.new()
	impact_flash.texture = PlaceholderTexture2D.new()
	impact_flash.texture.size = Vector2(IMPACT_FLASH_SIZE, IMPACT_FLASH_SIZE)
	impact_flash.modulate = Color(color.r, color.g, color.b, 0.8)
	impact_flash.global_position = pos
	impact_flash.z_index = 60
	impact_flash.scale = Vector2(0.5, 0.5)
	get_tree().current_scene.add_child(impact_flash)
	var tween: Tween = impact_flash.create_tween().set_parallel(true)
	tween.tween_property(impact_flash, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(impact_flash, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(impact_flash.queue_free)

# =========================
# HITSTOP (FRAME FREEZE) - GDD §6.2
# =========================
func _apply_hitstop(duration: float) -> void:
	if get_tree().paused:
		return
	Engine.time_scale = 0.02
	var timer := get_tree().create_timer(duration, true, false, true)
	await timer.timeout
	Engine.time_scale = 1.0

func hitstop_normal() -> void:
	_apply_hitstop(0.033)

func hitstop_critical() -> void:
	_apply_hitstop(0.066)

func hitstop_explosion() -> void:
	_apply_hitstop(0.050)

# =========================
# SLOWMO - GDD §6.2
# =========================
func apply_slowmo(timescale_val: float, duration: float) -> void:
	if _slowmo_active:
		return
	_slowmo_active = true
	var prev_scale := Engine.time_scale
	Engine.time_scale = timescale_val
	var timer := get_tree().create_timer(duration, true, false, true)
	await timer.timeout
	Engine.time_scale = prev_scale
	_slowmo_active = false

func slowmo_on_critical() -> void:
	apply_slowmo(0.3, 0.1)

func slowmo_on_synergy() -> void:
	apply_slowmo(0.3, 0.2)

func slowmo_on_boss_death() -> void:
	apply_slowmo(0.2, 0.5)

# =========================
# EFECTOS ESPECIALES
# =========================
func play_synergy_unlock_effect(level: int) -> void:
	var flash_color: Color = COLOR_DORADO if level == 2 else COLOR_SYNERGY_L3
	_screen_flash(flash_color, 0.2)
	# Mantener solo un pequeño shake, sin slowmo global para no colapsar FPS
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", SYNERGY_SHAKE_INTENSITY * 0.6, SYNERGY_SHAKE_DURATION * 0.6)

func play_death_effect(position: Vector2, is_elite: bool = false) -> void:
	var particle_count: int = DEATH_SPARKS_ELITE if is_elite else DEATH_SPARKS_NORMAL
	var color: Color = COLOR_FUEGO if not is_elite else COLOR_DORADO

	_spawn_spark_particles(position, particle_count, color)

	if is_elite:
		get_tree().call_group("camera", "shake", DEATH_SHAKE_ELITE, 0.2)
		apply_slowmo(0.4, 0.15)

func play_explosion_effect(position: Vector2, radius: float) -> void:
	var wave: Sprite2D = Sprite2D.new()
	wave.texture = PlaceholderTexture2D.new()
	wave.texture.size = Vector2(radius * 2, radius * 2)
	wave.modulate = Color(COLOR_FUEGO.r, COLOR_FUEGO.g, COLOR_FUEGO.b, 0.6)
	wave.global_position = position
	wave.z_index = 40
	wave.scale = Vector2(0.2, 0.2)

	get_tree().current_scene.add_child(wave)

	var tween: Tween = wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(wave, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(wave.queue_free)

	_spawn_spark_particles(position, 20, COLOR_FUEGO)
	get_tree().call_group("camera", "shake", EXPLOSION_SHAKE, 0.2)

func _screen_flash(color: Color, duration: float) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(color.r, color.g, color.b, 0.3)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(overlay)
	get_tree().current_scene.add_child(canvas)

	var tween: Tween = overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration)
	tween.tween_callback(canvas.queue_free)

# =========================
# SHAKE (wrapper para eventos)
# =========================
func shake_screen(intensity: float, duration: float) -> void:
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", intensity, duration)

# =========================
# EFECTOS ESPECÍFICOS DE EVENTOS (GDD §8.3)
# =========================
func play_elite_spawn_effect(position: Vector2) -> void:
	_spawn_impact_flash(position, Color("#CC0000"))
	_spawn_spark_particles(position, 20, Color("#FFD700"))
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", 5.0, 0.2)

func play_chaos_spawn_effect(position: Vector2) -> void:
	_spawn_spark_particles(position, 12, Color("#9933FF"))
	_apply_hitstop(0.05)

func show_danger_circle(position: Vector2, radius: float, duration: float) -> void:
	var circle: Sprite2D = Sprite2D.new()
	var image: Image = Image.create(int(radius * 2), int(radius * 2), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var cx: float = radius
			var cy: float = radius
			var dist: float = Vector2(x, y).distance_to(Vector2(cx, cy))
			if dist >= radius - 5 and dist <= radius:
				image.set_pixel(x, y, Color(1.0, 0.0, 0.0, 0.6))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	circle.texture = texture
	circle.global_position = position
	circle.z_index = 100
	get_tree().current_scene.add_child(circle)
	var tween_c: Tween = circle.create_tween().set_parallel(true).set_loops()
	tween_c.tween_property(circle, "scale", Vector2(1.1, 1.1), 0.5)
	tween_c.tween_property(circle, "modulate:a", 0.3, 0.5)
	get_tree().create_timer(duration).timeout.connect(func(): circle.queue_free())

func play_success_effect(position: Vector2) -> void:
	_spawn_spark_particles(position, 40, Color("#FFD700"))
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", 8.0, 0.4)
	apply_slowmo(0.3, 0.2)

# =========================
# SCREEN SHAKE MEJORADO (GDD §6.2)
# =========================
const SHAKE_WEAK := 0.5
const SHAKE_MEDIUM := 2.0
const SHAKE_STRONG := 5.0
const SHAKE_EXTREME := 8.0

func shake_screen_advanced(intensity: float, duration: float, frequency: float = 15.0) -> void:
	if not _use_screen_shake():
		return
	var cameras := get_tree().get_nodes_in_group("camera")
	for cam in cameras:
		if cam.has_method("shake_advanced"):
			cam.shake_advanced(intensity, duration, frequency)
		elif cam.has_method("shake"):
			cam.shake(intensity, duration)

func shake_on_bullet_impact() -> void:
	shake_screen_advanced(SHAKE_WEAK, 0.05, 20.0)

func shake_on_critical_hit() -> void:
	shake_screen_advanced(SHAKE_MEDIUM, 0.1, 15.0)

func shake_on_explosion() -> void:
	shake_screen_advanced(SHAKE_STRONG, 0.15, 12.0)

func shake_on_synergy_activation() -> void:
	shake_screen_advanced(SHAKE_EXTREME, 0.4, 10.0)

func shake_on_boss_death() -> void:
	shake_screen_advanced(10.0, 0.6, 8.0)

# =========================
# SCREEN FLASH (GDD §6.2)
# =========================
func _init_flash_overlay() -> void:
	if _flash_overlay:
		return
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "ScreenFlashOverlay"
	_flash_overlay.color = Color.WHITE
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.modulate = Color(1, 1, 1, 0)
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "FlashLayer"
	canvas_layer.layer = 100
	canvas_layer.add_child(_flash_overlay)
	if get_tree():
		get_tree().root.call_deferred("add_child", canvas_layer)

func flash_screen(color: Color, intensity: float, duration: float) -> void:
	if not _flash_overlay:
		_init_flash_overlay()
	if not _flash_overlay:
		return
	_flash_overlay.color = color
	_flash_overlay.modulate = Color(1, 1, 1, intensity)
	var tween := create_tween()
	tween.tween_property(_flash_overlay, "modulate:a", 0.0, duration)

func flash_on_critical() -> void:
	flash_screen(Color.WHITE, 0.3, 0.1)

func flash_on_synergy() -> void:
	flash_screen(Color("#FFD700"), 0.5, 0.3)

func flash_on_damage_taken() -> void:
	flash_screen(Color("#CC0000"), 0.4, 0.2)

func flash_on_boss_death() -> void:
	flash_screen(Color.WHITE, 0.7, 0.5)

# =========================
# ESCUDO REFLECTANTE (FORTALEZA - GDD §7.2)
# =========================
func play_shield_ripple_effect(position: Vector2) -> void:
	_spawn_impact_flash(position, Color("#FF6600"))
	_spawn_spark_particles(position, 8, Color("#FF6600"))
	if _use_screen_shake():
		get_tree().call_group("camera", "shake", 1.5, 0.06)

# =========================
# NÚMERO DE DAÑO PÚBLICO (para Bullet)
# =========================
func spawn_damage_number(pos: Vector2, amount: int, is_critical: bool) -> void:
	var col := COLOR_CRITICO if is_critical else COLOR_NORMAL
	var scale_mult := 1.5 if is_critical else 1.0
	_spawn_damage_number(pos, float(amount), col, scale_mult, is_critical)

# =========================
# PARTÍCULAS MEJORADAS (GDD §6.2)
# =========================
func spawn_impact_sparks_normal(position: Vector2, direction: Vector2) -> void:
	if _active_spark_count >= MAX_SPARK_PARTICLES:
		return
	var max_allowed := MAX_SPARK_PARTICLES - _active_spark_count
	var count := mini(randi_range(5, 8), max_allowed)
	for i in range(count):
		var angle_offset := randf_range(-0.5, 0.5)
		var spark_dir := direction.rotated(angle_offset) if direction.length_squared() > 0.01 else Vector2(randf() - 0.5, randf() - 0.5).normalized()
		_spawn_single_spark(position, spark_dir, COLOR_NORMAL)

func spawn_impact_sparks_critical(position: Vector2, direction: Vector2) -> void:
	if _active_spark_count >= MAX_SPARK_PARTICLES:
		return
	var max_allowed := MAX_SPARK_PARTICLES - _active_spark_count
	var count := mini(randi_range(8, 12), max_allowed)
	for i in range(count):
		var angle_offset := randf_range(-0.8, 0.8)
		var spark_dir := direction.rotated(angle_offset) if direction.length_squared() > 0.01 else Vector2(randf() - 0.5, randf() - 0.5).normalized()
		_spawn_single_spark(position, spark_dir, Color(1.0, 0.9, 0.3))

func spawn_explosion_particles(position: Vector2, radius: float) -> void:
	if _active_spark_count >= MAX_SPARK_PARTICLES:
		return
	var max_allowed := MAX_SPARK_PARTICLES - _active_spark_count
	var count := mini(randi_range(12, 18), max_allowed)
	for i in range(count):
		var angle := randf() * TAU
		var distance := randf_range(radius * 0.5, radius)
		var target := position + Vector2(cos(angle), sin(angle)) * distance
		var direction := (target - position).normalized()
		var col := Color(1.0, randf_range(0.4, 0.7), 0.0) if i % 2 == 0 else Color(1.0, 1.0, 0.0)
		_spawn_single_spark(position, direction, col)

func _spawn_single_spark(position: Vector2, direction: Vector2, color: Color) -> void:
	if _active_spark_count >= MAX_SPARK_PARTICLES:
		return
	_active_spark_count += 1
	var use_pool: bool = PoolManager and PoolManager.has_pool(PoolManager.POOL_KEY_SPARK)
	if use_pool:
		var pooled_spark = PoolManager.get_pooled_object(PoolManager.POOL_KEY_SPARK)
		if pooled_spark and pooled_spark.has_method("play_directional"):
			pooled_spark.play_directional(position, direction, color)
		_active_spark_count = maxi(0, _active_spark_count - 1)
		return
	var single_spark: Sprite2D = Sprite2D.new()
	single_spark.texture = PlaceholderTexture2D.new()
	single_spark.texture.size = Vector2(6, 6)
	single_spark.scale = Vector2(0.5, 0.5)
	single_spark.modulate = color
	single_spark.global_position = position
	single_spark.z_index = 50
	get_tree().current_scene.add_child(single_spark)
	var travel := 50.0
	var tween := single_spark.create_tween().set_parallel(true)
	tween.tween_property(single_spark, "global_position", position + direction * travel, 0.3)
	tween.tween_property(single_spark, "modulate:a", 0.0, 0.3)
	tween.tween_property(single_spark, "scale", Vector2.ZERO, 0.3)
	tween.chain().tween_callback(func():
		_active_spark_count = maxi(0, _active_spark_count - 1)
		single_spark.queue_free()
	)
