extends Node2D

## EVENTO: REY DE LA COLINA (GDD §8.3)
signal event_ended

@export var required_time := 15.0
@export var zone_radius := 150.0
@export var reward_fragments := 50

var _arena: Node2D = null
var _player: Node2D = null
var _wave_manager: Node = null
var _zone_center: Vector2 = Vector2.ZERO
var _time_in_zone := 0.0
var _is_active := false
var _zone_sprite: Node2D = null  # Polygon2D (zona rellena)
var _zone_ring: Node2D = null   # Polygon2D (borde)

func activate(arena: Node2D, player: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_player = player
	_wave_manager = wave_manager
	if not _player or not is_instance_valid(_player):
		push_error("KingOfHillEvent: No hay jugador válido")
		event_ended.emit()
		return
	_show_warning()
	await get_tree().create_timer(2.0).timeout
	_zone_center = _player.global_position
	_create_zone_visual()
	_is_active = true
	var timeout_timer := get_tree().create_timer(60.0)
	timeout_timer.timeout.connect(func():
		if _is_active:
			_fail_event()
	)
	_run_event()
	await event_ended

func _show_warning() -> void:
	print("⚠️ EVENTO ESPECIAL: ¡REY DE LA COLINA!")
	if VFXManager:
		VFXManager.shake_screen(5.0, 0.3)
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("show_event_warning"):
			hud.show_event_warning("¡DEFIENDE LA ZONA!", Color("#FFD700"))

func _create_zone_visual() -> void:
	# Círculo relleno semi-transparente con Polygon2D
	var zone_poly := Polygon2D.new()
	zone_poly.color = Color(1.0, 0.84, 0.0, 0.18)
	zone_poly.global_position = _zone_center
	zone_poly.z_index = -1

	var pts := PackedVector2Array()
	const SEG := 48
	for i in range(SEG):
		var angle := (float(i) / float(SEG)) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * zone_radius)
	zone_poly.polygon = pts
	get_tree().current_scene.add_child(zone_poly)
	_zone_sprite = zone_poly

	# Borde exterior (anillo) como segundo Polygon2D más brillante
	var ring := Polygon2D.new()
	ring.color = Color(1.0, 0.84, 0.0, 0.5)
	ring.global_position = _zone_center
	ring.z_index = -1
	var ring_pts := PackedVector2Array()
	for i in range(SEG):
		var angle := (float(i) / float(SEG)) * TAU
		ring_pts.append(Vector2(cos(angle), sin(angle)) * (zone_radius - 5))
	ring.polygon = ring_pts
	get_tree().current_scene.add_child(ring)
	_zone_ring = ring

func _run_event() -> void:
	while _is_active:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(_player):
			_fail_event()
			return
		var dist := _player.global_position.distance_to(_zone_center)
		if dist <= zone_radius:
			_time_in_zone += 0.1
			_update_ui()
			if _time_in_zone >= required_time:
				_complete_event()
				return

func _update_ui() -> void:
	var tree := get_tree()
	if tree and tree.current_scene:
		var hud = tree.current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("update_king_of_hill_progress"):
			var progress := _time_in_zone / required_time
			hud.update_king_of_hill_progress(progress)

func _complete_event() -> void:
	_is_active = false
	print("✅ Rey de la Colina COMPLETADO - +%d Fragmentos" % reward_fragments)
	if GameManager:
		GameManager.add_fragments(reward_fragments)
	if VFXManager:
		VFXManager.play_success_effect(_zone_center)
	_cleanup()
	event_ended.emit()

func _fail_event() -> void:
	_is_active = false
	print("❌ Rey de la Colina FALLADO")
	_cleanup()
	event_ended.emit()

func _cleanup() -> void:
	if _zone_ring:
		_zone_ring.queue_free()
		_zone_ring = null
	if _zone_sprite:
		_zone_sprite.queue_free()
		_zone_sprite = null

func _exit_tree() -> void:
	_is_active = false
	_cleanup()
