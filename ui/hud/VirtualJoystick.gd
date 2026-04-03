extends Node2D
## Joystick virtual para input táctil (móvil)

signal joystick_moved(direction: Vector2)
@warning_ignore("unused_signal")
signal ability_pressed

@export var joystick_radius := 80.0
@export var knob_radius := 35.0

var _touch_index := -1
var _origin := Vector2.ZERO
var _current_direction := Vector2.ZERO

@onready var base_circle: Node2D = $Base      # Polygon2D o Sprite2D
@onready var knob: Node2D = $Knob             # Polygon2D o Sprite2D

func _ready() -> void:
	visible = false  # Solo visible con touch

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			# Solo registrar toques en la mitad izquierda de la pantalla
			var screen_size := get_viewport().get_visible_rect().size
			if event.position.x < screen_size.x * 0.5:
				_touch_index = event.index
				_origin = event.position
				global_position = _origin
				visible = true
		elif not event.pressed and event.index == _touch_index:
			_release()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			var offset: Vector2 = event.position - _origin
			var clamped: Vector2 = offset.limit_length(joystick_radius)
			_current_direction = offset.normalized() if offset.length() > 5.0 else Vector2.ZERO
			if knob:
				knob.position = clamped
			joystick_moved.emit(_current_direction)

func _release() -> void:
	_touch_index = -1
	_current_direction = Vector2.ZERO
	visible = false
	if knob:
		knob.position = Vector2.ZERO
	joystick_moved.emit(Vector2.ZERO)

func get_direction() -> Vector2:
	return _current_direction
