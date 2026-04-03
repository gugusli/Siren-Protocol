extends "res://entities/player/player.gd"
## REVERBERACIÓN - El Controlador (GDD §7.4)
## 90 HP, 4 m/s, 6 daño (solo torretas). Maestro de torretas: mejoras de disparo → torretas. Sobrecarga 25s cd, 5s 3x fire rate.

const TurretScene := preload("res://entities/turrets/Turret.tscn")
const MAX_TORRETAS := 8
const SOBRECARGA_COOLDOWN := 25.0
const SOBRECARGA_DURATION := 5.0
const SOBRECARGA_FIRE_MULT := 3.0

var turrets: Array[Node] = []

func _ready() -> void:
	character_type = "REVERBERACIÓN"
	ability_cooldown_max = SOBRECARGA_COOLDOWN
	can_shoot_directly = false
	damageable.max_health = 90.0
	damageable.health = 90.0
	base_speed = 176.0   # 4 m/s
	base_bullet_damage = 6.0  # usado por torretas
	super._ready()
	# Conectar a señales de mejoras para spawn de torretas
	if UpgradeManager and not UpgradeManager.upgrade_applied.is_connected(_on_upgrade_applied):
		UpgradeManager.upgrade_applied.connect(_on_upgrade_applied)

func _exit_tree() -> void:
	if UpgradeManager and UpgradeManager.upgrade_applied.is_connected(_on_upgrade_applied):
		UpgradeManager.upgrade_applied.disconnect(_on_upgrade_applied)

func _on_upgrade_applied(upgrade_id: String) -> void:
	# Cada mejora de disparo/daño/cadencia/proyectiles → nueva torreta (GDD §7.4)
	if upgrade_id in [UpgradeManager.UPGRADE_FIRE_RATE, UpgradeManager.UPGRADE_DAMAGE, UpgradeManager.UPGRADE_EXTRA_PROJECTILES]:
		_spawn_turret()

func _spawn_turret() -> void:
	if turrets.size() >= MAX_TORRETAS:
		return
	var turret := TurretScene.instantiate()
	add_child(turret)
	turrets.append(turret)
	_update_turret_positions()

func _update_turret_positions() -> void:
	var count := turrets.size()
	for i in range(count):
		var t := turrets[i]
		if not is_instance_valid(t) or not t.has_method("set"):
			continue
		var angle := (float(i) / float(count)) * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 80.0
		t.target_offset = offset

func _process(delta: float) -> void:
	super._process(delta)
	# Limpiar torretas inválidas y redistribuir
	var valid: Array[Node] = []
	for t in turrets:
		if is_instance_valid(t):
			valid.append(t)
	if valid.size() != turrets.size():
		turrets = valid
		_update_turret_positions()

func use_ability() -> void:
	if ability_cooldown_remaining > 0:
		return
	ability_cooldown_remaining = ability_cooldown_max
	# Sobrecarga: torretas disparan 3x más rápido, 5s (GDD §7.4)
	for t in turrets:
		if not is_instance_valid(t):
			continue
		t.fire_rate_mult = SOBRECARGA_FIRE_MULT
		t.show_overcharge_vfx()
	
	await get_tree().create_timer(SOBRECARGA_DURATION).timeout
	
	for t in turrets:
		if not is_instance_valid(t):
			continue
		t.fire_rate_mult = 1.0
		t.hide_overcharge_vfx()
