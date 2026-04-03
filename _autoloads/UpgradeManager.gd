extends Node

## =========================
## AFTERSHOCK - Sistema de Mejoras y Sinergias
## Según GDD v4 Extended
## =========================

signal upgrade_applied(upgrade_id: String)
signal synergy_unlocked(synergy_id: String, level: int)
signal synergy_activated(synergy_id: String)

# =========================
# ENUMS
# =========================
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum UpgradeCategory { DAMAGE, DEFENSE, UTILITY, WEAPON, ELEMENT }

# =========================
# IDs DE UPGRADES (constantes para evitar errores tipográficos)
# =========================
const UPGRADE_DAMAGE := "dmg"
const UPGRADE_CRIT_CHANCE := "crit_chance"
const UPGRADE_CRIT_DAMAGE := "crit_damage"
const UPGRADE_AREA_DAMAGE := "area_damage"
const UPGRADE_SPEED := "speed"
const UPGRADE_FIRE_RATE := "fire_rate"
const UPGRADE_HEALTH := "health"
const UPGRADE_REGEN := "regen"
const UPGRADE_LIFESTEAL := "lifesteal"
const UPGRADE_SHIELD := "shield"
const UPGRADE_PIERCE := "pierce"
const UPGRADE_EXTRA_PROJECTILES := "extra_projectiles"
const UPGRADE_BOUNCING := "bouncing"
const UPGRADE_EXPLOSIVE_AMMO := "explosive_ammo"
const UPGRADE_FIRE_AMMO := "fire_ammo"
const UPGRADE_ICE_AMMO := "ice_ammo"
const UPGRADE_POISON_AMMO := "poison_ammo"
const UPGRADE_CHAIN_LIGHTNING := "chain_lightning"
const UPGRADE_GARLIC := "garlic"
const UPGRADE_DASH := "dash_upgrade"

# =========================
# ESTRUCTURA DE MEJORAS
# =========================
# Cada mejora tiene: id, nombre, descripción, rareza, categoría, max_level, tags
var ALL_UPGRADES := {
	# === DAÑO BÁSICO ===
	"dmg": {
		"name": "FUERZA BRUTA",
		"desc": "+25% Daño base",
		"rarity": Rarity.COMMON,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 5,
		"tags": ["damage"],
		"stackable": true
	},
	"crit_chance": {
		"name": "PRECISIÓN LETAL",
		"desc": "+10% Probabilidad de crítico",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 5,
		"tags": ["critical"],
		"stackable": true
	},
	"crit_damage": {
		"name": "GOLPE DEVASTADOR",
		"desc": "+50% Daño crítico",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 3,
		"tags": ["critical"],
		"stackable": true
	},
	"area_damage": {
		"name": "DAÑO DE ÁREA",
		"desc": "+20% Radio de explosiones",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 3,
		"tags": ["area", "explosion"],
		"stackable": true
	},
	
	# === VELOCIDAD Y MOVILIDAD ===
	"speed": {
		"name": "AGILIDAD",
		"desc": "+15% Velocidad de movimiento",
		"rarity": Rarity.COMMON,
		"category": UpgradeCategory.UTILITY,
		"max_level": 5,
		"tags": ["movement"],
		"stackable": true
	},
	"fire_rate": {
		"name": "CADENCIA",
		"desc": "+20% Velocidad de disparo",
		"rarity": Rarity.COMMON,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 5,
		"tags": ["attack_speed"],
		"stackable": true
	},
	"dash_upgrade": {
		"name": "DASH MEJORADO",
		"desc": "-20% Cooldown de dash",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.UTILITY,
		"max_level": 3,
		"tags": ["dash", "movement"],
		"stackable": true
	},
	
	# === DEFENSA Y SUPERVIVENCIA ===
	"health": {
		"name": "VITALIDAD",
		"desc": "+20 Vida máxima",
		"rarity": Rarity.COMMON,
		"category": UpgradeCategory.DEFENSE,
		"max_level": 10,
		"tags": ["health"],
		"stackable": true
	},
	"regen": {
		"name": "REGENERACIÓN",
		"desc": "+1 HP/segundo",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.DEFENSE,
		"max_level": 5,
		"tags": ["regeneration", "health"],
		"stackable": true
	},
	"lifesteal": {
		"name": "ROBO DE VIDA",
		"desc": "Cura 3% del daño causado",
		"rarity": Rarity.EPIC,
		"category": UpgradeCategory.DEFENSE,
		"max_level": 3,
		"tags": ["lifesteal", "health"],
		"stackable": true
	},
	"shield": {
		"name": "ESCUDO TEMPORAL",
		"desc": "Escudo de 20 HP cada 15s",
		"rarity": Rarity.EPIC,
		"category": UpgradeCategory.DEFENSE,
		"max_level": 3,
		"tags": ["shield"],
		"stackable": true
	},
	
	# === PROYECTILES ===
	"pierce": {
		"name": "PERFORACIÓN",
		"desc": "Balas atraviesan +1 enemigo",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 3,
		"tags": ["penetration", "projectile"],
		"stackable": true
	},
	"extra_projectiles": {
		"name": "PROYECTILES ADICIONALES",
		"desc": "+1 Proyectil por disparo",
		"rarity": Rarity.EPIC,
		"category": UpgradeCategory.DAMAGE,
		"max_level": 3,
		"tags": ["projectile"],
		"stackable": true
	},
	"bouncing": {
		"name": "REBOTES",
		"desc": "Proyectiles rebotan en paredes",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.WEAPON,
		"max_level": 1,
		"tags": ["projectile", "bouncing"],
		"stackable": false
	},
	
	# === MUNICIÓN ELEMENTAL ===
	"explosive_ammo": {
		"name": "MUNICIÓN EXPLOSIVA",
		"desc": "Balas explotan al impactar",
		"rarity": Rarity.EPIC,
		"category": UpgradeCategory.ELEMENT,
		"max_level": 3,
		"tags": ["explosion", "area"],
		"stackable": true
	},
	"fire_ammo": {
		"name": "MUNICIÓN INCENDIARIA",
		"desc": "Enemigos arden 3s (15 daño/s)",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.ELEMENT,
		"max_level": 3,
		"tags": ["fire", "dot"],
		"stackable": true
	},
	"ice_ammo": {
		"name": "MUNICIÓN HELADA",
		"desc": "Ralentiza enemigos 30%",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.ELEMENT,
		"max_level": 3,
		"tags": ["ice", "slow"],
		"stackable": true
	},
	"poison_ammo": {
		"name": "MUNICIÓN VENENOSA",
		"desc": "Veneno: 10 daño/s por 5s",
		"rarity": Rarity.RARE,
		"category": UpgradeCategory.ELEMENT,
		"max_level": 3,
		"tags": ["poison", "dot"],
		"stackable": true
	},
	"chain_lightning": {
		"name": "CADENA DE RAYOS",
		"desc": "Daño salta a 3 enemigos cercanos",
		"rarity": Rarity.EPIC,
		"category": UpgradeCategory.ELEMENT,
		"max_level": 3,
		"tags": ["electric", "chain"],
		"stackable": true
	},
	
	# === ARMAS ESPECIALES ===
	"garlic": {
		"name": "AJO TÓXICO",
		"desc": "Aura de daño constante",
		"rarity": Rarity.EPIC,
		"category": UpgradeCategory.WEAPON,
		"max_level": 1,
		"tags": ["area", "weapon"],
		"stackable": false
	}
}

# =========================
# SINERGIAS NIVEL 2 (2 mejoras)
# =========================
var SYNERGIES_LEVEL_2 := {
	"chain_reaction": {
		"name": "REACCIÓN EN CADENA",
		"desc": "Las explosiones tienen 40% de generar otra explosión",
		"requires": ["explosive_ammo", "area_damage"],
		"color": Color("#FFD700")
	},
	"vampiric_crit": {
		"name": "VAMPIRISMO CRÍTICO",
		"desc": "Los críticos curan 3x más vida",
		"requires": ["crit_chance", "lifesteal"],
		"color": Color("#FFD700")
	},
	"deadly_burst": {
		"name": "RÁFAGA MORTAL",
		"desc": "Proyectiles que penetran ganan +15% daño por enemigo",
		"requires": ["fire_rate", "pierce"],
		"color": Color("#FFD700")
	},
	"adaptive_shield": {
		"name": "ESCUDO ADAPTATIVO",
		"desc": "Al romperse escudo, regeneración 3x por 5s",
		"requires": ["regen", "shield"],
		"color": Color("#FFD700")
	},
	"electric_storm": {
		"name": "TEMPESTAD ELÉCTRICA",
		"desc": "Rayos saltan 2 veces más y +25% alcance",
		"requires": ["chain_lightning", "fire_rate"],
		"color": Color("#FFD700")
	},
	"fire_trail": {
		"name": "TORBELLINO DE FUEGO",
		"desc": "Al moverte dejas trail de fuego",
		"requires": ["speed", "fire_ammo"],
		"color": Color("#FFD700")
	},
	"deep_freeze": {
		"name": "CONGELACIÓN PROFUNDA",
		"desc": "Críticos a enemigos lentos los congelan 2s",
		"requires": ["ice_ammo", "crit_damage"],
		"color": Color("#FFD700")
	},
	"toxic_drain": {
		"name": "DRENAJE TÓXICO",
		"desc": "El daño de veneno también te cura 20%",
		"requires": ["poison_ammo", "lifesteal"],
		"color": Color("#FFD700")
	},
	"infinite_ammo": {
		"name": "MUNICIÓN INFINITA",
		"desc": "10% probabilidad de disparo gratis",
		"requires": ["extra_projectiles", "dmg"],
		"color": Color("#FFD700")
	},
	"deadly_reflex": {
		"name": "REFLEJO MORTAL",
		"desc": "Después de dash, 3 disparos son críticos",
		"requires": ["dash_upgrade", "crit_damage"],
		"color": Color("#FFD700")
	}
}

# =========================
# SINERGIAS NIVEL 3 (3+ mejoras)
# =========================
var SYNERGIES_LEVEL_3 := {
	"fire_apocalypse": {
		"name": "APOCALIPSIS DE FUEGO",
		"desc": "Explosiones dejan charcos de fuego persistentes",
		"requires": ["explosive_ammo", "fire_ammo", "area_damage"],
		"color": Color("#9933FF")
	},
	"perfect_storm": {
		"name": "TORMENTA PERFECTA",
		"desc": "Rayos tienen 50% crítico y generan cadenas extra",
		"requires": ["chain_lightning", "fire_rate", "crit_chance"],
		"color": Color("#9933FF")
	},
	"death_machine": {
		"name": "MÁQUINA DE MUERTE",
		"desc": "Al matar, proyectil se divide en 2",
		"requires": ["fire_rate", "pierce", "extra_projectiles"],
		"color": Color("#9933FF")
	},
	"vampiric_immortality": {
		"name": "INMORTALIDAD VAMPÍRICA",
		"desc": "Bajo 25% HP: críticos curan doble y +20% crit",
		"requires": ["lifesteal", "regen", "crit_chance"],
		"color": Color("#9933FF")
	},
	"death_zone": {
		"name": "ZONA MUERTA",
		"desc": "Enemigos envenenados dejan nubes tóxicas al morir",
		"requires": ["poison_ammo", "area_damage", "ice_ammo"],
		"color": Color("#9933FF")
	}
}

# =========================
# ESTADO DEL JUGADOR
# =========================
var player_upgrades: Dictionary = {}  # {upgrade_id: level}
var active_synergies_l2: Array[String] = []  # IDs de sinergias nivel 2 activas
var active_synergies_l3: Array[String] = []  # IDs de sinergias nivel 3 activas
var discovered_synergies: Array[String] = []  # Sinergias descubiertas (para códice)

# =========================
# STATS MODIFICADOS
# =========================
var stats: Dictionary = {
	"damage_mult": 1.0,
	"crit_chance": 0.05,  # 5% base
	"crit_damage": 1.5,   # 150% base
	"speed_mult": 1.0,
	"fire_rate_mult": 1.0,
	"area_mult": 1.0,
	"pierce": 0,
	"extra_projectiles": 0,
	"lifesteal": 0.0,
	"regen_per_sec": 0.0,
	"shield_amount": 0,
	"dash_cooldown_mult": 1.0,
	# Elementales
	"has_explosive": false,
	"has_fire": false,
	"has_ice": false,
	"has_poison": false,
	"has_chain_lightning": false,
	"has_bouncing": false,
	"has_garlic": false,
	"workshop_health_bonus": 0
}

# =========================
# FUNCIONES PRINCIPALES
# =========================
func _ready() -> void:
	_load_discovered_synergies_from_save()
	reset_upgrades()
	if SynergyManager:
		SynergyManager.synergy_activated.connect(_on_synergy_activated)

func _exit_tree() -> void:
	if SynergyManager and SynergyManager.synergy_activated.is_connected(_on_synergy_activated):
		SynergyManager.synergy_activated.disconnect(_on_synergy_activated)

func _on_synergy_activated(synergy_id: String, level: int) -> void:
	var display_name := synergy_id
	if SynergyManager:
		display_name = SynergyManager.get_synergy_name(synergy_id)
	# Registrar sinergia descubierta (para códice) solo la primera vez
	if not synergy_id in discovered_synergies:
		discovered_synergies.append(synergy_id)
		_save_discovered_synergy(synergy_id)
		synergy_unlocked.emit(display_name, level)
	synergy_activated.emit(synergy_id)

func _load_discovered_synergies_from_save() -> void:
	if not GameManager:
		return
	var saved: Variant = GameManager.stats.get(GameManager.STATS_KEY_SYNERGIES_DISCOVERED, [])
	if typeof(saved) != TYPE_ARRAY:
		return
	for s in saved:
		var sid := str(s)
		if sid not in discovered_synergies:
			discovered_synergies.append(sid)

func _save_discovered_synergy(syn_id: String) -> void:
	if not GameManager:
		return
	var arr: Array = GameManager.stats.get(GameManager.STATS_KEY_SYNERGIES_DISCOVERED, [])
	if typeof(arr) != TYPE_ARRAY:
		arr = []
	if syn_id not in arr:
		arr.append(syn_id)
		GameManager.stats[GameManager.STATS_KEY_SYNERGIES_DISCOVERED] = arr

func reset_upgrades() -> void:
	player_upgrades.clear()
	active_synergies_l2.clear()
	active_synergies_l3.clear()
	if SynergyManager:
		SynergyManager.reset()
	# No limpiar discovered_synergies: se persisten entre partidas
	stats = {
		"damage_mult": 1.0,
		"crit_chance": 0.05,
		"crit_damage": 1.5,
		"speed_mult": 1.0,
		"fire_rate_mult": 1.0,
		"area_mult": 1.0,
		"pierce": 0,
		"extra_projectiles": 0,
		"lifesteal": 0.0,
		"regen_per_sec": 0.0,
		"shield_amount": 0,
		"dash_cooldown_mult": 1.0,
		"has_explosive": false,
		"has_fire": false,
		"has_ice": false,
		"has_poison": false,
		"has_chain_lightning": false,
		"has_bouncing": false,
		"has_garlic": false,
		"workshop_health_bonus": 0
	}
	# Recalcular para asegurar consistencia (incluye mejoras del taller)
	_recalculate_all_stats()

func apply_upgrade(upgrade_id: String) -> bool:
	if not upgrade_id in ALL_UPGRADES:
		push_error("Upgrade desconocido: " + upgrade_id)
		return false
	
	var upgrade: Dictionary = ALL_UPGRADES.get(upgrade_id, {})
	if upgrade.is_empty():
		push_error("UpgradeManager: Error obteniendo datos de upgrade: " + upgrade_id)
		return false
	var current_level: int = player_upgrades.get(upgrade_id, 0)
	
	# Verificar si se puede subir más
	if current_level >= upgrade.max_level:
		return false
	
	# Aplicar mejora
	player_upgrades[upgrade_id] = current_level + 1
	_apply_stat_change(upgrade_id, current_level + 1)
	
	upgrade_applied.emit(upgrade_id)
	
	# Notificar al jugador para mejoras que requieren cambios en nodos directos
	_notify_player_upgrade(upgrade_id)
	
	# Verificar sinergias
	_check_synergies()
	
	# Notificar a GameManager
	if GameManager:
		GameManager.add_upgrade_to_session(upgrade_id)
	
	return true

func _notify_player_upgrade(upgrade_id: String) -> void:
	# Solo notificar mejoras que requieren cambios en nodos del jugador
	# Usar call_deferred para asegurar que el árbol de escenas esté listo
	call_deferred("_notify_player_upgrade_deferred", upgrade_id)

func _notify_player_upgrade_deferred(upgrade_id: String) -> void:
	var tree = get_tree()
	if not tree:
		return
	var player = tree.get_first_node_in_group("player")
	if player and player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade_id)

func _apply_stat_change(upgrade_id: String, _level: int) -> void:
	# MEJORADO: Recalcular stats desde cero para evitar acumulación incorrecta
	_recalculate_all_stats()
	
	# Las mejoras booleanas se activan una sola vez
	match upgrade_id:
		UPGRADE_BOUNCING:
			stats.has_bouncing = true
		UPGRADE_EXPLOSIVE_AMMO:
			stats.has_explosive = true
		UPGRADE_FIRE_AMMO:
			stats.has_fire = true
		UPGRADE_ICE_AMMO:
			stats.has_ice = true
		UPGRADE_POISON_AMMO:
			stats.has_poison = true
		UPGRADE_CHAIN_LIGHTNING:
			stats.has_chain_lightning = true
		UPGRADE_GARLIC:
			stats.has_garlic = true

func _recalculate_all_stats() -> void:
	# Resetear a valores base
	stats.damage_mult = 1.0
	stats.crit_chance = 0.05
	stats.crit_damage = 1.5
	stats.speed_mult = 1.0
	stats.fire_rate_mult = 1.0
	stats.area_mult = 1.0
	stats.pierce = 0
	stats.extra_projectiles = 0
	stats.lifesteal = 0.0
	stats.regen_per_sec = 0.0
	stats.shield_amount = 0
	stats.dash_cooldown_mult = 1.0
	
	# Recalcular desde cero según niveles actuales
	for upgrade_id in player_upgrades:
		var upgrade_data: Dictionary = ALL_UPGRADES.get(upgrade_id, {})
		if upgrade_data.is_empty():
			push_error("UpgradeManager: upgrade_id inválido en player_upgrades: " + str(upgrade_id))
			continue
		var level: int = player_upgrades.get(upgrade_id, 0)
		if level <= 0:
			continue
		
		match upgrade_id:
			UPGRADE_DAMAGE:
				stats.damage_mult += 0.25 * level
			UPGRADE_CRIT_CHANCE:
				stats.crit_chance += 0.10 * level
			UPGRADE_CRIT_DAMAGE:
				stats.crit_damage += 0.50 * level
			UPGRADE_AREA_DAMAGE:
				stats.area_mult += 0.20 * level
			UPGRADE_SPEED:
				stats.speed_mult += 0.15 * level
			UPGRADE_FIRE_RATE:
				stats.fire_rate_mult += 0.20 * level
			UPGRADE_DASH:
				stats.dash_cooldown_mult = maxf(0.1, stats.dash_cooldown_mult - 0.20 * level)
			UPGRADE_REGEN:
				stats.regen_per_sec += 1.0 * level
			UPGRADE_LIFESTEAL:
				stats.lifesteal += 0.03 * level
			UPGRADE_SHIELD:
				stats.shield_amount += 20 * level
			UPGRADE_PIERCE:
				stats.pierce += level
			UPGRADE_EXTRA_PROJECTILES:
				stats.extra_projectiles += level

	# Mejoras permanentes del Taller (Workshop): se aplican cada partida
	if GameManager:
		var w: Dictionary = GameManager.workshop_purchases
		stats.damage_mult += 0.05 * w.get("perm_dmg", 0)       # +5% por nivel (DAÑO BASE)
		stats.speed_mult += 0.03 * w.get("perm_speed", 0)       # +3% por nivel (VELOCIDAD)
		stats.workshop_health_bonus = 10 * w.get("perm_health", 0)  # +10 vida por nivel

func _check_synergies() -> void:
	if SynergyManager:
		# MEJORADO: Recheck limpia y actualiza todas las sinergias correctamente
		SynergyManager.recheck(player_upgrades)
		# Sincronizar arrays locales con SynergyManager
		active_synergies_l2.clear()
		for id in SynergyManager.get_active_l2():
			active_synergies_l2.append(id)
		active_synergies_l3.clear()
		for id in SynergyManager.get_active_l3():
			active_synergies_l3.append(id)
	else:
		_check_synergies_legacy()

func _check_synergies_legacy() -> void:
	# MEJORADO: Limpiar sinergias que ya no se cumplen
	var to_remove_l2: Array[String] = []
	var to_remove_l3: Array[String] = []
	
	# Verificar sinergias L2 activas
	for syn_id in active_synergies_l2:
		if not syn_id in SYNERGIES_LEVEL_2:
			to_remove_l2.append(syn_id)
			continue
		var synergy: Dictionary = SYNERGIES_LEVEL_2.get(syn_id, {})
		if synergy.is_empty():
			to_remove_l2.append(syn_id)
			continue
		var has_all = true
		for req in synergy.get("requires", []):
			if not (req in player_upgrades and player_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if not has_all:
			to_remove_l2.append(syn_id)
	
	# Verificar sinergias L3 activas
	for syn_id in active_synergies_l3:
		if not syn_id in SYNERGIES_LEVEL_3:
			to_remove_l3.append(syn_id)
			continue
		var synergy: Dictionary = SYNERGIES_LEVEL_3.get(syn_id, {})
		if synergy.is_empty():
			to_remove_l3.append(syn_id)
			continue
		var has_all = true
		for req in synergy.get("requires", []):
			if not (req in player_upgrades and player_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if not has_all:
			to_remove_l3.append(syn_id)
	
	# Eliminar sinergias que ya no se cumplen
	for syn_id in to_remove_l2:
		active_synergies_l2.erase(syn_id)
	for syn_id in to_remove_l3:
		active_synergies_l3.erase(syn_id)
	
	# Buscar nuevas sinergias L2
	for syn_id in SYNERGIES_LEVEL_2:
		if syn_id in active_synergies_l2:
			continue
		var synergy: Dictionary = SYNERGIES_LEVEL_2.get(syn_id, {})
		if synergy.is_empty():
			continue
		var has_all = true
		for req in synergy.get("requires", []):
			if not (req in player_upgrades and player_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if has_all:
			active_synergies_l2.append(syn_id)
			if not syn_id in discovered_synergies:
				discovered_synergies.append(syn_id)
				_save_discovered_synergy(syn_id)
			synergy_unlocked.emit(synergy.get("name", syn_id), 2)
			synergy_activated.emit(syn_id)
			if VFXManager:
				VFXManager.shake_on_synergy_activation()
				VFXManager.slowmo_on_synergy()
				VFXManager.flash_on_synergy()
	
	# Buscar nuevas sinergias L3
	for syn_id in SYNERGIES_LEVEL_3:
		if syn_id in active_synergies_l3:
			continue
		var synergy: Dictionary = SYNERGIES_LEVEL_3.get(syn_id, {})
		if synergy.is_empty():
			continue
		var has_all = true
		for req in synergy.get("requires", []):
			if not (req in player_upgrades and player_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if has_all:
			active_synergies_l3.append(syn_id)
			if not syn_id in discovered_synergies:
				discovered_synergies.append(syn_id)
				_save_discovered_synergy(syn_id)
			synergy_unlocked.emit(synergy.get("name", syn_id), 3)
			synergy_activated.emit(syn_id)
			if VFXManager:
				VFXManager.shake_screen_advanced(10.0, 0.5, 8.0)
				VFXManager.apply_slowmo(0.2, 0.3)
				VFXManager.flash_screen(Color("#9933FF"), 0.6, 0.4)

# =========================
# OBTENER MEJORAS DISPONIBLES
# =========================
func get_available_upgrades(count: int = 3, current_wave: int = 1) -> Array:
	var available: Array[String] = []
	
	for upgrade_id in ALL_UPGRADES:
		if not upgrade_id in ALL_UPGRADES:
			continue
		var upgrade: Dictionary = ALL_UPGRADES.get(upgrade_id, {})
		if upgrade.is_empty():
			continue
		var current_level = player_upgrades.get(upgrade_id, 0)
		
		# Verificar si aún puede mejorar
		if current_level >= upgrade.max_level:
			continue
		
		# Filtros por oleada (pierce aparece después de oleada 3)
		if upgrade_id == UPGRADE_PIERCE and current_wave < 3:
			continue
		
		# Filtros por rareza según oleada
		var rarity: int = upgrade.get("rarity", 0) as int
		if rarity == Rarity.EPIC and current_wave < 5:
			if randf() > 0.3:  # 30% probabilidad antes de oleada 5
				continue
		
		if rarity == Rarity.LEGENDARY and current_wave < 8:
			continue
		
		available.append(upgrade_id)
	
	# Mezclar y devolver cantidad solicitada
	available.shuffle()
	return available.slice(0, min(count, available.size()))

# =========================
# UTILIDADES PARA UI
# =========================
func get_upgrade_data(upgrade_id: String) -> Dictionary:
	var data: Dictionary = {}
	if upgrade_id in ALL_UPGRADES:
		data = ALL_UPGRADES.get(upgrade_id, {}).duplicate()
	if data.is_empty():
		return {}
	data["current_level"] = player_upgrades.get(upgrade_id, 0)
	return data

func get_synergy_data(synergy_id: String) -> Dictionary:
	if SynergyManager:
		var d = SynergyManager.get_synergy_data(synergy_id)
		if not d.is_empty():
			return d
	if synergy_id in SYNERGIES_LEVEL_2:
		return SYNERGIES_LEVEL_2.get(synergy_id, {})
	if synergy_id in SYNERGIES_LEVEL_3:
		return SYNERGIES_LEVEL_3.get(synergy_id, {})
	return {}

func check_would_complete_synergy(upgrade_id: String) -> Dictionary:
	if SynergyManager:
		var temp = player_upgrades.duplicate()
		temp[upgrade_id] = temp.get(upgrade_id, 0) + 1
		var result = SynergyManager.check_would_complete(upgrade_id, temp)
		if not result.is_empty():
			return result
	# Fallback legacy
	var temp_upgrades = player_upgrades.duplicate()
	temp_upgrades[upgrade_id] = temp_upgrades.get(upgrade_id, 0) + 1
	for syn_id in SYNERGIES_LEVEL_2:
		if syn_id in active_synergies_l2:
			continue
		var synergy: Dictionary = SYNERGIES_LEVEL_2.get(syn_id, {})
		if synergy.is_empty():
			continue
		var has_all = true
		for req in synergy.get("requires", []):
			if not req in temp_upgrades or temp_upgrades.get(req, 0) <= 0:
				has_all = false
				break
		if has_all:
			return {"synergy_id": syn_id, "level": 2, "data": synergy}
	for syn_id in SYNERGIES_LEVEL_3:
		if syn_id in active_synergies_l3:
			continue
		var synergy: Dictionary = SYNERGIES_LEVEL_3.get(syn_id, {})
		if synergy.is_empty():
			continue
		var has_all = true
		for req in synergy.get("requires", []):
			if not req in temp_upgrades or temp_upgrades.get(req, 0) <= 0:
				has_all = false
				break
		if has_all:
			return {"synergy_id": syn_id, "level": 3, "data": synergy}
	return {}

func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in player_upgrades

func get_upgrade_level(upgrade_id: String) -> int:
	return player_upgrades.get(upgrade_id, 0)

func has_synergy(synergy_id: String) -> bool:
	return synergy_id in active_synergies_l2 or synergy_id in active_synergies_l3
