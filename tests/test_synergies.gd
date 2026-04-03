extends Node

## Test automatizado de sinergias L2 y L3 (SynergyManager).
## Ejecutar con: godot --path . --script tests/test_synergies.gd
## O desde editor: escena con este script como nodo raíz.

func _ready() -> void:
	print("=== TESTING DE SINERGIAS ===\n")
	
	await test_all_l2_synergies()
	await test_all_l3_synergies()
	
	print("\n=== TODOS LOS TESTS COMPLETADOS ===")
	get_tree().quit()

func _apply_required(ids: Array) -> void:
	UpgradeManager.reset_upgrades()
	for id in ids:
		UpgradeManager.apply_upgrade(id)

func _assert_synergy_active(syn_id: String, level: int) -> void:
	var ok := SynergyManager.has_synergy(syn_id)
	assert(ok, "Sinergia '%s' (nivel %d) debería estar activa" % [syn_id, level])

# =========================
# SINERGIAS NIVEL 2 (SynergyManager.SYNERGIES_L2)
# =========================
func test_all_l2_synergies() -> void:
	print("--- SINERGIAS NIVEL 2 ---")
	
	await test_artilleria_infernal()
	await test_lluvia_de_plomo()
	await test_puntos_criticos()
	await test_tormenta_electrica()
	await test_fortaleza_viviente()
	await test_campo_de_fuerza()
	await test_vampirismo_mejorado()
	await test_resiliencia_total()
	await test_maestro_de_armas()
	await test_especializacion()
	await test_berserk()
	await test_drenaje_espectral()
	await test_iman_mejorado()
	await test_avaricia_infinita()
	await test_segunda_oportunidad()
	
	print("  Todas las sinergias L2 pasaron\n")

func test_artilleria_infernal() -> void:
	print("  Test: ARTILLERÍA INFERNAL (explosive_ammo + area_damage)")
	_apply_required(["explosive_ammo", "area_damage"])
	_assert_synergy_active("artilleria_infernal", 2)
	print("    PASS")

func test_lluvia_de_plomo() -> void:
	print("  Test: LLUVIA DE PLOMO (fire_rate + extra_projectiles)")
	_apply_required(["fire_rate", "extra_projectiles"])
	_assert_synergy_active("lluvia_de_plomo", 2)
	print("    PASS")

func test_puntos_criticos() -> void:
	print("  Test: PUNTOS CRÍTICOS (crit_chance + pierce)")
	_apply_required(["crit_chance", "pierce"])
	_assert_synergy_active("puntos_criticos", 2)
	print("    PASS")

func test_tormenta_electrica() -> void:
	print("  Test: TORMENTA ELÉCTRICA (chain_lightning + fire_rate)")
	_apply_required(["chain_lightning", "fire_rate"])
	_assert_synergy_active("tormenta_electrica", 2)
	print("    PASS")

func test_fortaleza_viviente() -> void:
	print("  Test: FORTALEZA VIVIENTE (health + regen)")
	_apply_required(["health", "regen"])
	_assert_synergy_active("fortaleza_viviente", 2)
	print("    PASS")

func test_campo_de_fuerza() -> void:
	print("  Test: CAMPO DE FUERZA (shield + area_damage)")
	_apply_required(["shield", "area_damage"])
	_assert_synergy_active("campo_de_fuerza", 2)
	print("    PASS")

func test_vampirismo_mejorado() -> void:
	print("  Test: VAMPIRISMO MEJORADO (lifesteal + crit_chance)")
	_apply_required(["lifesteal", "crit_chance"])
	_assert_synergy_active("vampirismo_mejorado", 2)
	print("    PASS")

func test_resiliencia_total() -> void:
	print("  Test: RESILIENCIA TOTAL (shield + regen)")
	_apply_required(["shield", "regen"])
	_assert_synergy_active("resiliencia_total", 2)
	print("    PASS")

func test_maestro_de_armas() -> void:
	print("  Test: MAESTRO DE ARMAS (garlic + bouncing + extra_projectiles)")
	_apply_required(["garlic", "bouncing", "extra_projectiles"])
	_assert_synergy_active("maestro_de_armas", 2)
	print("    PASS")

func test_especializacion() -> void:
	print("  Test: ESPECIALIZACIÓN (pierce + crit_damage)")
	_apply_required(["pierce", "crit_damage"])
	_assert_synergy_active("especializacion", 2)
	print("    PASS")

func test_berserk() -> void:
	print("  Test: BERSERK (speed + health)")
	_apply_required(["speed", "health"])
	_assert_synergy_active("berserk", 2)
	print("    PASS")

func test_drenaje_espectral() -> void:
	print("  Test: DRENAJE ESPECTRAL (lifesteal + fire_rate)")
	_apply_required(["lifesteal", "fire_rate"])
	_assert_synergy_active("drenaje_espectral", 2)
	print("    PASS")

func test_iman_mejorado() -> void:
	print("  Test: IMÁN MEJORADO (speed + regen)")
	_apply_required(["speed", "regen"])
	_assert_synergy_active("iman_mejorado", 2)
	print("    PASS")

func test_avaricia_infinita() -> void:
	print("  Test: AVARICIA INFINITA (extra_projectiles + dmg)")
	_apply_required(["extra_projectiles", "dmg"])
	_assert_synergy_active("avaricia_infinita", 2)
	print("    PASS")

func test_segunda_oportunidad() -> void:
	print("  Test: SEGUNDA OPORTUNIDAD (health + shield)")
	_apply_required(["health", "shield"])
	_assert_synergy_active("segunda_oportunidad", 2)
	print("    PASS")

# =========================
# SINERGIAS NIVEL 3 (SynergyManager.SYNERGIES_L3)
# =========================
func test_all_l3_synergies() -> void:
	print("--- SINERGIAS NIVEL 3 ---")
	
	await test_apocalipsis_explosivo()
	await test_tormenta_perfecta()
	await test_maquina_de_muerte()
	await test_inmortalidad_vampirica()
	await test_zona_muerta()
	
	print("  Todas las sinergias L3 pasaron\n")

func test_apocalipsis_explosivo() -> void:
	print("  Test: APOCALIPSIS EXPLOSIVO (explosive_ammo + area_damage + fire_ammo)")
	_apply_required(["explosive_ammo", "area_damage", "fire_ammo"])
	_assert_synergy_active("apocalipsis_explosivo", 3)
	print("    PASS")

func test_tormenta_perfecta() -> void:
	print("  Test: TORMENTA PERFECTA (chain_lightning + fire_rate + crit_chance)")
	_apply_required(["chain_lightning", "fire_rate", "crit_chance"])
	_assert_synergy_active("tormenta_perfecta", 3)
	print("    PASS")

func test_maquina_de_muerte() -> void:
	print("  Test: MÁQUINA DE MUERTE (fire_rate + pierce + extra_projectiles)")
	_apply_required(["fire_rate", "pierce", "extra_projectiles"])
	_assert_synergy_active("maquina_de_muerte", 3)
	print("    PASS")

func test_inmortalidad_vampirica() -> void:
	print("  Test: INMORTALIDAD VAMPÍRICA (lifesteal + regen + crit_chance)")
	_apply_required(["lifesteal", "regen", "crit_chance"])
	_assert_synergy_active("inmortalidad_vampirica", 3)
	print("    PASS")

func test_zona_muerta() -> void:
	print("  Test: ZONA MUERTA (poison_ammo + area_damage + ice_ammo)")
	_apply_required(["poison_ammo", "area_damage", "ice_ammo"])
	_assert_synergy_active("zona_muerta", 3)
	print("    PASS")
