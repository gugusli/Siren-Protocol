extends Node

## Script de testing manual para eventos especiales (GDD §8.3).
## Ejecutar desde editor: crear escena con este script como root y reproducir,
## o ejecutar con: godot --path . --script tests/test_events.gd

func _ready() -> void:
	print("=== TESTING DE EVENTOS ESPECIALES ===\n")
	var arena_scene := load("res://levels/Arenas/Arena.tscn")
	var arena = arena_scene.instantiate()
	add_child(arena)
	await get_tree().process_frame
	var player = arena.get_node_or_null("Player")
	var wave_manager = arena.get_node_or_null("WaveManager")
	if not player or not wave_manager:
		print("ERROR: No se encontró Player o WaveManager en Arena")
		return

	# Test 1: Stampede
	print("Test 1: StampedeEvent")
	await test_stampede(arena, player, wave_manager)
	print("✅ Stampede completado\n")
	_clear_enemies()
	await get_tree().create_timer(1.0).timeout

	# Test 2: Elite Wave
	print("Test 2: EliteWaveEvent")
	await test_elite_wave(arena, player, wave_manager)
	print("✅ Elite Wave completado\n")
	_clear_enemies()
	await get_tree().create_timer(1.0).timeout

	# Test 3: Darkness
	print("Test 3: DarknessEvent")
	await test_darkness(arena, player, wave_manager)
	print("✅ Darkness completado\n")

	# Test 4: Artillery
	print("Test 4: ArtilleryRainEvent")
	await test_artillery(arena, player, wave_manager)
	print("✅ Artillery completado\n")
	_clear_enemies()
	await get_tree().create_timer(1.0).timeout

	# Test 5: King of the Hill
	print("Test 5: KingOfHillEvent")
	await test_king_of_hill(arena, player, wave_manager)
	print("✅ King of the Hill completado\n")

	# Test 6: Chaos
	print("Test 6: ChaosEvent")
	await test_chaos(arena, player, wave_manager)
	print("✅ Chaos completado\n")

	print("\n=== TODOS LOS TESTS COMPLETADOS ===")
	get_tree().quit()

func test_stampede(arena: Node, player: Node, wave_manager: Node) -> void:
	var event_scene := load("res://levels/events/StampedeEvent.tscn")
	var event = event_scene.instantiate()
	arena.add_child(event)
	event.activate(arena, player, wave_manager)
	await event.event_ended
	var enemies := get_tree().get_nodes_in_group("enemies")
	assert(enemies.size() >= 30, "Stampede debería spawnear al menos 30 enemigos")

func test_elite_wave(arena: Node, player: Node, wave_manager: Node) -> void:
	var event_scene := load("res://levels/events/EliteWaveEvent.tscn")
	var event = event_scene.instantiate()
	arena.add_child(event)
	event.activate(arena, player, wave_manager)
	await event.event_ended
	var enemies := get_tree().get_nodes_in_group("enemies")
	var elite_count := 0
	for enemy in enemies:
		if "is_elite" in enemy and enemy.is_elite:
			elite_count += 1
	assert(elite_count >= 3, "Elite Wave debería spawnear al menos 3 élites")

func test_darkness(arena: Node, player: Node, wave_manager: Node) -> void:
	var event_scene := load("res://levels/events/DarknessEvent.tscn")
	var event = event_scene.instantiate()
	arena.add_child(event)
	event.darkness_duration = 5.0
	event.activate(arena, player, wave_manager)
	await event.event_ended

func test_artillery(arena: Node, player: Node, wave_manager: Node) -> void:
	var event_scene := load("res://levels/events/ArtilleryRainEvent.tscn")
	var event = event_scene.instantiate()
	arena.add_child(event)
	event.duration = 5.0
	event.activate(arena, player, wave_manager)
	await event.event_ended

func test_king_of_hill(arena: Node, player: Node, wave_manager: Node) -> void:
	var event_scene := load("res://levels/events/KingOfHillEvent.tscn")
	var event = event_scene.instantiate()
	arena.add_child(event)
	event.required_time = 2.0
	event.activate(arena, player, wave_manager)
	await event.event_ended

func test_chaos(arena: Node, player: Node, wave_manager: Node) -> void:
	var event_scene := load("res://levels/events/ChaosEvent.tscn")
	var event = event_scene.instantiate()
	arena.add_child(event)
	event.duration = 5.0
	event.activate(arena, player, wave_manager)
	await event.event_ended

func _clear_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
