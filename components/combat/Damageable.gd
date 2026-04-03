extends Node

signal health_changed(current, max)
signal shield_changed(current, max)
signal died

@export var max_health := 100.0

var health: float
var is_invulnerable := false

# Escudo temporal (mejora "shield"): absorbe daño, se recarga cada 15s
var shield_points := 0.0
var max_shield := 0.0
var shield_recharge_timer := 0.0
const SHIELD_RECHARGE_INTERVAL := 15.0
const SHIELD_RECHARGE_AMOUNT := 20.0

signal shield_broken

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)
	if max_shield > 0:
		shield_points = max_shield
		emit_signal("shield_changed", shield_points, max_shield)

func _process(delta: float) -> void:
	if max_shield <= 0.0:
		return
	# Recarga de escudo cada 15s
	if shield_points < max_shield:
		shield_recharge_timer += delta
		if shield_recharge_timer >= SHIELD_RECHARGE_INTERVAL:
			shield_recharge_timer = 0.0
			shield_points = min(shield_points + SHIELD_RECHARGE_AMOUNT, max_shield)
			emit_signal("shield_changed", shield_points, max_shield)

func set_max_shield(amount: float) -> void:
	max_shield = amount
	shield_points = min(shield_points, max_shield)
	if max_shield > 0 and shield_points < max_shield and shield_recharge_timer <= 0:
		shield_points = max_shield
	emit_signal("shield_changed", shield_points, max_shield)

func take_damage(amount: float, attacker: Node = null) -> void:
	if is_invulnerable or health <= 0.0:
		return
	var parent = get_parent()
	if parent and parent.has_method("preprocess_damage"):
		amount = parent.preprocess_damage(amount, attacker)
	if amount <= 0:
		return

	# El escudo absorbe primero
	if shield_points > 0:
		var had_shield_before := shield_points > 0
		var absorbed = min(amount, shield_points)
		shield_points -= absorbed
		amount -= absorbed
		emit_signal("shield_changed", shield_points, max_shield)
		# Callback de rotura de escudo (Escudo Adaptativo, VFX, etc.)
		if had_shield_before and shield_points <= 0.0:
			shield_points = 0.0
			emit_signal("shield_broken")
			if parent and parent.has_method("on_shield_broken"):
				parent.on_shield_broken()
		if amount <= 0:
			return

	health -= amount
	health = max(health, 0.0)

	emit_signal("health_changed", health, max_health)

	if parent and parent.is_in_group("player") and VFXManager:
		VFXManager.flash_on_damage_taken()

	if health <= 0.0:
		emit_signal("died")

func heal(amount: float) -> void:
	if health <= 0.0:
		return  # No curar si está muerto
	
	health += amount
	health = min(health, max_health)  # No exceder vida máxima
	
	emit_signal("health_changed", health, max_health)

func notify_dot_damage(dot_type: String, amount: float) -> void:
	var parent = get_parent()
	if not parent:
		return
	# DRENAJE TÓXICO: veneno en enemigos cura al jugador
	if dot_type == "poison" and parent.is_in_group("enemies") and UpgradeManager and UpgradeManager.has_synergy("toxic_drain"):
		var tree := get_tree()
		if not tree:
			return
		var player := tree.get_first_node_in_group("player")
		if not player:
			return
		var player_damageable = player.get_node_or_null("Damageable")
		if player_damageable:
			player_damageable.heal(amount * 0.20)
