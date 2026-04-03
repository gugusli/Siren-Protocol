extends "res://entities/player/player.gd"
## FORTALEZA - El Tanque (GDD §7.2)
## 180 HP, 3.5 m/s, 8 daño, 0.8 disp/s. Armadura -25% daño. Escudo Reflectante 20s cd, 3s duración.

var _shield_active := false
var _shield_cooldown := 0.0
const SHIELD_COOLDOWN_MAX := 20.0
const SHIELD_DURATION := 3.0
var _shield_vfx: Node2D = null
var _shield_tween: Tween = null

func _ready() -> void:
	character_type = "FORTALEZA"
	ability_cooldown_max = SHIELD_COOLDOWN_MAX
	damageable.max_health = 180.0
	damageable.health = 180.0
	base_speed = 154.0   # 3.5 m/s
	base_bullet_damage = 8.0
	character_base_fire_interval = 1.0 / 0.8  # 0.8 disparos/s
	super._ready()

func _process(delta: float) -> void:
	if not GameManager or GameManager.game_state != GameManager.GameState.PLAYING:
		return
	super._process(delta)
	if _shield_cooldown > 0:
		_shield_cooldown -= delta

func preprocess_damage(amount: float, attacker: Node = null) -> float:
	# Armadura Pesada: -25% daño
	amount *= 0.75
	if _shield_active:
		# Escudo Reflectante: no recibe daño, refleja al atacante (GDD §7.2)
		if VFXManager and VFXManager.has_method("play_shield_ripple_effect"):
			VFXManager.play_shield_ripple_effect(global_position)
		elif VFXManager:
			VFXManager.shake_screen(2.0, 0.08)
		if attacker and is_instance_valid(attacker):
			var target_dmg = attacker.get_node_or_null("Damageable")
			if target_dmg and target_dmg.has_method("take_damage"):
				target_dmg.take_damage(amount, null)
		return 0.0
	return amount

func use_ability() -> void:
	if ability_cooldown_remaining > 0 or _shield_cooldown > 0 or _shield_active:
		return
	_shield_active = true
	ability_cooldown_remaining = ability_cooldown_max
	_shield_cooldown = SHIELD_COOLDOWN_MAX
	_show_shield_vfx()
	await get_tree().create_timer(SHIELD_DURATION).timeout
	_shield_active = false
	_hide_shield_vfx()

func _show_shield_vfx() -> void:
	var shield := Polygon2D.new()
	shield.name = "Shield"
	shield.z_index = 5
	shield.color = Color(1.0, 0.4, 0.0, 0.6)

	# Círculo con 24 segmentos, sin set_pixel()
	var pts := PackedVector2Array()
	const SEG := 24
	const SHIELD_RADIUS := 28.0
	for i in range(SEG):
		var angle := (float(i) / float(SEG)) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * SHIELD_RADIUS)
	shield.polygon = pts
	add_child(shield)
	_shield_vfx = shield

	# Guardar referencia al tween para poder matarlo
	if _shield_tween:
		_shield_tween.kill()
	_shield_tween = create_tween().set_loops()
	_shield_tween.tween_property(shield, "modulate:a", 0.35, 0.5)
	_shield_tween.tween_property(shield, "modulate:a", 0.9, 0.5)

func _hide_shield_vfx() -> void:
	# Matar el tween ANTES de liberar el nodo
	if _shield_tween:
		_shield_tween.kill()
		_shield_tween = null
	if _shield_vfx and is_instance_valid(_shield_vfx):
		_shield_vfx.queue_free()
	_shield_vfx = null
