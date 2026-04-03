extends Area2D

@onready var damageable := get_parent().get_node_or_null("Damageable")

func receive_hit(amount: float) -> void:
	if damageable:
		damageable.take_damage(amount)
