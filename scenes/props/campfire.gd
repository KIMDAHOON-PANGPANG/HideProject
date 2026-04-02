extends Node2D

## Simple animated campfire using draw calls.

var _time := 0.0

const FIRE_COLORS: Array[Color] = [
	Color(1.0, 0.6, 0.1, 0.9),
	Color(1.0, 0.4, 0.05, 0.8),
	Color(1.0, 0.8, 0.2, 0.7),
	Color(0.9, 0.3, 0.05, 0.6),
]

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Stone ring base
	draw_rect(Rect2(-18, -4, 36, 8), Color(0.35, 0.32, 0.28, 1))
	draw_rect(Rect2(-20, -2, 40, 4), Color(0.30, 0.28, 0.25, 1))

	# Wood logs
	draw_rect(Rect2(-12, -6, 8, 4), Color(0.4, 0.25, 0.12, 1))
	draw_rect(Rect2(4, -6, 8, 4), Color(0.38, 0.22, 0.10, 1))
	draw_rect(Rect2(-4, -7, 8, 3), Color(0.42, 0.27, 0.14, 1))

	# Flames (animated)
	for i in range(5):
		var phase := _time * 3.0 + i * 1.3
		var flicker := sin(phase) * 0.3 + 0.7
		var sway := sin(phase * 0.7) * 3.0
		var height := (12.0 + sin(phase * 1.2) * 5.0) * flicker
		var width := 4.0 + sin(phase * 0.9) * 2.0
		var x_off := (i - 2) * 5.0 + sway
		var color: Color = FIRE_COLORS[i % FIRE_COLORS.size()]
		color.a *= flicker
		draw_rect(Rect2(x_off - width / 2.0, -8 - height, width, height), color)

	# Ember glow on ground
	draw_rect(Rect2(-10, -5, 20, 3), Color(1.0, 0.5, 0.1, 0.3 + sin(_time * 2.0) * 0.15))
