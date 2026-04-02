extends Camera2D

@export var follow_target: Node2D
@export var follow_speed := 5.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.5
@export var max_zoom := 2.0

var is_panning := false
var pan_start := Vector2.ZERO
var pan_offset := Vector2.ZERO
var returning_to_target := false

func _ready() -> void:
	zoom = Vector2(1.0, 1.0)
	# Snap to target immediately on first frame
	if follow_target:
		global_position = follow_target.global_position

func _process(delta: float) -> void:
	if not follow_target:
		return

	if is_panning:
		returning_to_target = false
	elif returning_to_target:
		pan_offset = pan_offset.lerp(Vector2.ZERO, delta * 3.0)
		if pan_offset.length() < 1.0:
			pan_offset = Vector2.ZERO
			returning_to_target = false

	var target_pos := follow_target.global_position + pan_offset
	global_position = global_position.lerp(target_pos, delta * follow_speed)

func _unhandled_input(event: InputEvent) -> void:
	# Right-click drag panning
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				is_panning = true
				pan_start = mb.global_position
			else:
				is_panning = false
				returning_to_target = true

		# Zoom with mouse wheel
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var new_zoom := clampf(zoom.x + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var new_zoom := clampf(zoom.x - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)

	if event is InputEventMouseMotion and is_panning:
		var motion := event as InputEventMouseMotion
		pan_offset -= motion.relative / zoom
