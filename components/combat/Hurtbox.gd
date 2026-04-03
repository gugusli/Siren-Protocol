extends Area2D

@export var damage: float = 10.0

func _ready():
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("receive_hit"):
		area.receive_hit(damage)
