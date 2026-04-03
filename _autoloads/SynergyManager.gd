extends Node

## =========================
## AFTERSHOCK - Synergy Manager (GDD §6)
## Diccionario de sinergias, verificación y señales.
## =========================

signal synergy_activated(synergy_id: String, level: int)

# =========================
# LAS 15 SINERGIAS DEL GDD §6.2
# =========================
# requires = array de upgrade_id que debe tener el jugador (todos)
# name = nombre para UI, desc = descripción, color = nivel 2 dorado / nivel 3 arcoíris

const SYNERGIES_L2: Dictionary = {
	# --- OFENSIVAS ---
	"artilleria_infernal": {
		"name": "ARTILLERÍA INFERNAL",
		"desc": "Explosiones en cadena",
		"requires": ["explosive_ammo", "area_damage"],
		"color": Color("#FFD700")
	},
	"lluvia_de_plomo": {
		"name": "LLUVIA DE PLOMO",
		"desc": "Ráfaga automática",
		"requires": ["fire_rate", "extra_projectiles"],
		"color": Color("#FFD700")
	},
	"puntos_criticos": {
		"name": "PUNTOS CRÍTICOS",
		"desc": "Críticos que atraviesan",
		"requires": ["crit_chance", "pierce"],
		"color": Color("#FFD700")
	},
	"tormenta_electrica": {
		"name": "TORMENTA ELÉCTRICA",
		"desc": "Arcos eléctricos entre enemigos",
		"requires": ["chain_lightning", "fire_rate"],
		"color": Color("#FFD700")
	},
	# --- DEFENSIVAS ---
	"fortaleza_viviente": {
		"name": "FORTALEZA VIVIENTE",
		"desc": "Escudo temporal al tener mucha vida",
		"requires": ["health", "regen"],
		"color": Color("#FFD700")
	},
	"campo_de_fuerza": {
		"name": "CAMPO DE FUERZA",
		"desc": "Daño de retorno en área",
		"requires": ["shield", "area_damage"],
		"color": Color("#FFD700")
	},
	"vampirismo_mejorado": {
		"name": "VAMPIRISMO MEJORADO",
		"desc": "Críticos curan más",
		"requires": ["lifesteal", "crit_chance"],
		"color": Color("#FFD700")
	},
	"resiliencia_total": {
		"name": "RESILIENCIA TOTAL",
		"desc": "Inmunidad temporal al combinar escudo y regen",
		"requires": ["shield", "regen"],
		"color": Color("#FFD700")
	},
	# --- HÍBRIDAS ---
	"maestro_de_armas": {
		"name": "MAESTRO DE ARMAS",
		"desc": "3+ armas equipadas: todas mejoran",
		"requires": ["garlic", "bouncing", "extra_projectiles"],
		"color": Color("#FFD700")
	},
	"especializacion": {
		"name": "ESPECIALIZACIÓN",
		"desc": "Build enfocado: bonificaciones masivas",
		"requires": ["pierce", "crit_damage"],
		"color": Color("#FFD700")
	},
	"berserk": {
		"name": "BERSERK",
		"desc": "Más rápido con menos vida",
		"requires": ["speed", "health"],
		"color": Color("#FFD700")
	},
	"drenaje_espectral": {
		"name": "DRENAJE ESPECTRAL",
		"desc": "Cada impacto cura",
		"requires": ["lifesteal", "fire_rate"],
		"color": Color("#FFD700")
	},
	# --- UTILITARIAS ---
	"iman_mejorado": {
		"name": "IMÁN MEJORADO",
		"desc": "Rango de recogida + velocidad: imán automático",
		"requires": ["speed", "regen"],
		"color": Color("#FFD700")
	},
	"avaricia_infinita": {
		"name": "AVARICIA INFINITA",
		"desc": "Más daño y proyectiles: más drops raros",
		"requires": ["extra_projectiles", "dmg"],
		"color": Color("#FFD700")
	},
	"segunda_oportunidad": {
		"name": "SEGUNDA OPORTUNIDAD",
		"desc": "Vida máxima + escudo: más margen de supervivencia",
		"requires": ["health", "shield"],
		"color": Color("#FFD700")
	},
	# === SINERGIAS SISTEMA UNIFICADO (UpgradeManager.SYNERGIES_LEVEL_2) ===
	"deadly_burst": {
		"name": "RÁFAGA MORTAL",
		"desc": "Proyectiles que penetran ganan +15% daño por enemigo (máx. +60%)",
		"requires": ["fire_rate", "pierce"],
		"color": Color("#FFD700")
	},
	"adaptive_shield": {
		"name": "ESCUDO ADAPTATIVO",
		"desc": "Al romperse el escudo, regeneración 3x durante 5s",
		"requires": ["regen", "shield"],
		"color": Color("#FFD700")
	},
	"deep_freeze": {
		"name": "CONGELACIÓN PROFUNDA",
		"desc": "Críticos a enemigos ralentizados los congelan 2s y explotan al romperse",
		"requires": ["ice_ammo", "crit_damage"],
		"color": Color("#FFD700")
	},
	"toxic_drain": {
		"name": "DRENAJE TÓXICO",
		"desc": "El daño de veneno también cura al jugador 20%",
		"requires": ["poison_ammo", "lifesteal"],
		"color": Color("#FFD700")
	},
	"infinite_ammo": {
		"name": "FRECUENCIA LIBRE",
		"desc": "10% de probabilidad de disparo gratis (sin cooldown)",
		"requires": ["extra_projectiles", "dmg"],
		"color": Color("#FFD700")
	},
	"deadly_reflex": {
		"name": "REFLEJO MORTAL",
		"desc": "Después de un dash, los próximos 3 disparos son críticos garantizados",
		"requires": ["dash_upgrade", "crit_damage"],
		"color": Color("#FFD700")
	}
}

# Sinergias nivel 3 (3 mejoras) - GDD: burst arcoíris, shimmer 3s, slowmotion
const SYNERGIES_L3: Dictionary = {
	"apocalipsis_explosivo": {
		"name": "APOCALIPSIS EXPLOSIVO",
		"desc": "Explosiones en cadena + área masiva",
		"requires": ["explosive_ammo", "area_damage", "fire_ammo"],
		"color": Color("#9933FF")
	},
	"tormenta_perfecta": {
		"name": "TORMENTA PERFECTA",
		"desc": "Rayos con crítico y cadenas extra",
		"requires": ["chain_lightning", "fire_rate", "crit_chance"],
		"color": Color("#9933FF")
	},
	"maquina_de_muerte": {
		"name": "MÁQUINA DE MUERTE",
		"desc": "Proyectiles que penetran se multiplican",
		"requires": ["fire_rate", "pierce", "extra_projectiles"],
		"color": Color("#9933FF")
	},
	"inmortalidad_vampirica": {
		"name": "INMORTALIDAD VAMPÍRICA",
		"desc": "Bajo 25% HP: críticos curan doble",
		"requires": ["lifesteal", "regen", "crit_chance"],
		"color": Color("#9933FF")
	},
	"zona_muerta": {
		"name": "ZONA MUERTA",
		"desc": "Veneno + área + hielo: nubes tóxicas",
		"requires": ["poison_ammo", "area_damage", "ice_ammo"],
		"color": Color("#9933FF")
	}
}

# Estado: sinergias actualmente activas
var active_l2: Array[String] = []
var active_l3: Array[String] = []
var discovered: Array[String] = []

# =========================
# VERIFICACIÓN
# =========================
func recheck(equipped_upgrades: Dictionary) -> void:
	# CORRECCIÓN CRÍTICA: Primero limpiar sinergias que ya no se cumplen
	var to_remove_l2: Array[String] = []
	var to_remove_l3: Array[String] = []
	
	# Verificar sinergias L2 activas - eliminar si ya no cumplen requisitos
	for syn_id in active_l2:
		var syn: Dictionary = SYNERGIES_L2.get(syn_id, {})
		if syn.is_empty():
			push_error("SynergyManager: sinergia L2 inválida: " + str(syn_id))
			to_remove_l2.append(syn_id)
			continue
		var has_all = true
		for req in syn.get("requires", []):
			if not (req in equipped_upgrades and equipped_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if not has_all:
			to_remove_l2.append(syn_id)
	
	# Verificar sinergias L3 activas - eliminar si ya no cumplen requisitos
	for syn_id in active_l3:
		var syn: Dictionary = SYNERGIES_L3.get(syn_id, {})
		if syn.is_empty():
			push_error("SynergyManager: sinergia L3 inválida: " + str(syn_id))
			to_remove_l3.append(syn_id)
			continue
		var has_all = true
		for req in syn.get("requires", []):
			if not (req in equipped_upgrades and equipped_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if not has_all:
			to_remove_l3.append(syn_id)
	
	# Eliminar sinergias que ya no se cumplen
	for syn_id in to_remove_l2:
		active_l2.erase(syn_id)
	for syn_id in to_remove_l3:
		active_l3.erase(syn_id)
	
	# Ahora buscar nuevas sinergias que se puedan activar
	var newly_l2: Array[String] = []
	var newly_l3: Array[String] = []

	for syn_id in SYNERGIES_L2:
		if syn_id in active_l2:
			continue
		var syn: Dictionary = SYNERGIES_L2.get(syn_id, {})
		if syn.is_empty():
			continue
		var has_all = true
		for req in syn.get("requires", []):
			if not (req in equipped_upgrades and equipped_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if has_all:
			active_l2.append(syn_id)
			newly_l2.append(syn_id)
			if not syn_id in discovered:
				discovered.append(syn_id)

	for syn_id in SYNERGIES_L3:
		if syn_id in active_l3:
			continue
		var syn: Dictionary = SYNERGIES_L3.get(syn_id, {})
		if syn.is_empty():
			continue
		var has_all = true
		for req in syn.get("requires", []):
			if not (req in equipped_upgrades and equipped_upgrades.get(req, 0) > 0):
				has_all = false
				break
		if has_all:
			active_l3.append(syn_id)
			newly_l3.append(syn_id)
			if not syn_id in discovered:
				discovered.append(syn_id)

	# Emitir señales solo para sinergias nuevas
	for id in newly_l2:
		synergy_activated.emit(id, 2)
		_play_synergy_vfx(2)
	for id in newly_l3:
		synergy_activated.emit(id, 3)
		_play_synergy_vfx(3)

func _play_synergy_vfx(level: int) -> void:
	if VFXManager and VFXManager.has_method("play_synergy_unlock_effect"):
		VFXManager.play_synergy_unlock_effect(level)

# =========================
# CONSULTAS
# =========================
func get_active_l2() -> Array:
	return active_l2.duplicate()

func get_active_l3() -> Array:
	return active_l3.duplicate()

func get_synergy_data(synergy_id: String) -> Dictionary:
	if synergy_id in SYNERGIES_L2:
		return SYNERGIES_L2.get(synergy_id, {})
	if synergy_id in SYNERGIES_L3:
		return SYNERGIES_L3.get(synergy_id, {})
	return {}

func get_synergy_name(synergy_id: String) -> String:
	var d = get_synergy_data(synergy_id)
	return d.get("name", synergy_id)

func has_synergy(synergy_id: String) -> bool:
	return synergy_id in active_l2 or synergy_id in active_l3

func is_synergy_l2(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES_L2

func is_synergy_l3(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES_L3

# ¿Esta mejora completaría alguna sinergia que aún no está activa?
func check_would_complete(upgrade_id: String, current_upgrades: Dictionary) -> Dictionary:
	var temp = current_upgrades.duplicate()
	temp[upgrade_id] = temp.get(upgrade_id, 0) + 1

	# Verificar sinergias L2
	for syn_id in SYNERGIES_L2:
		if syn_id in active_l2:
			continue
		var syn: Dictionary = SYNERGIES_L2.get(syn_id, {})
		if syn.is_empty():
			continue
		var has_all = true
		for req in syn.get("requires", []):
			if not (req in temp and temp.get(req, 0) > 0):
				has_all = false
				break
		if has_all:
			return {"synergy_id": syn_id, "level": 2, "data": syn}

	# Verificar sinergias L3
	for syn_id in SYNERGIES_L3:
		if syn_id in active_l3:
			continue
		var syn: Dictionary = SYNERGIES_L3.get(syn_id, {})
		if syn.is_empty():
			continue
		var has_all = true
		for req in syn.get("requires", []):
			if not (req in temp and temp.get(req, 0) > 0):
				has_all = false
				break
		if has_all:
			return {"synergy_id": syn_id, "level": 3, "data": syn}

	return {}

# =========================
# RESET (nueva partida)
# =========================
func reset() -> void:
	active_l2.clear()
	active_l3.clear()
	# discovered se mantiene para el códice entre partidas si se desea
