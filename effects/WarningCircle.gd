extends Sprite2D

## Círculo rojo de advertencia para impacto (ArtilleryRainEvent).
## Pulsa y se desvanece en duration segundos.

const DEFAULT_RADIUS := 80.0

func _ready() -> void:
	if not texture:
		var image := Image.create(int(DEFAULT_RADIUS * 2), int(DEFAULT_RADIUS * 2), false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var cx := DEFAULT_RADIUS
		var cy := DEFAULT_RADIUS
		for x in range(image.get_width()):
			for y in range(image.get_height()):
				if Vector2(x, y).distance_to(Vector2(cx, cy)) <= DEFAULT_RADIUS:
					image.set_pixel(x, y, Color(1.0, 0.0, 0.0, 0.6))
		texture = ImageTexture.create_from_image(image)
	modulate = Color(1, 1, 1, 1)

func play(duration: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	queue_free()
