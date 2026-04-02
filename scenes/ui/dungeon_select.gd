extends CanvasLayer

signal dungeon_selected(dungeon_id: String)

@onready var panel: Panel = $Panel
@onready var close_btn: Button = $Panel/CloseButton
@onready var map_area: Control = $Panel/MapArea

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func() -> void: visible = false)
	_build_markers()

func show_panel() -> void:
	visible = true

func _build_markers() -> void:
	# Dungeon 01 — clickable
	_add_dungeon_marker(Vector2(250, 180), "던전 01\n폐건물", "dungeon_01", Color(0.9, 0.75, 0.3, 1), 24.0)

	# Unknown markers — disabled
	_add_static_marker(Vector2(550, 120), "???", Color(0.5, 0.5, 0.5, 0.6), 16.0)
	_add_static_marker(Vector2(450, 320), "???", Color(0.5, 0.5, 0.5, 0.6), 16.0)
	_add_static_marker(Vector2(700, 260), "???", Color(0.5, 0.5, 0.5, 0.6), 16.0)

	# Shelter (current location)
	_add_static_marker(Vector2(120, 380), "쉘터\n(현재 위치)", Color(0.3, 0.8, 0.4, 1), 20.0)

func _add_dungeon_marker(pos: Vector2, text: String, id: String, color: Color, radius: float) -> void:
	var container := Control.new()
	container.position = pos
	map_area.add_child(container)

	var circle := _CircleMarker.new()
	circle.radius = radius
	circle.circle_color = color
	container.add_child(circle)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.offset_left = -60
	lbl.offset_top = radius + 6
	lbl.offset_right = 60
	lbl.offset_bottom = radius + 50
	container.add_child(lbl)

	var btn := Button.new()
	btn.flat = true
	btn.offset_left = -32
	btn.offset_top = -32
	btn.offset_right = 32
	btn.offset_bottom = 32
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func() -> void: dungeon_selected.emit(id))
	container.add_child(btn)

func _add_static_marker(pos: Vector2, text: String, color: Color, radius: float) -> void:
	var container := Control.new()
	container.position = pos
	map_area.add_child(container)

	var circle := _CircleMarker.new()
	circle.radius = radius
	circle.circle_color = color
	container.add_child(circle)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.offset_left = -60
	lbl.offset_top = radius + 6
	lbl.offset_right = 60
	lbl.offset_bottom = radius + 50
	lbl.modulate = Color(0.6, 0.6, 0.6, 0.7)
	container.add_child(lbl)

class _CircleMarker extends Node2D:
	var radius := 20.0
	var circle_color := Color.WHITE

	func _draw() -> void:
		var segments := 32
		var points := PackedVector2Array()
		for i in range(segments + 1):
			var angle := float(i) / segments * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		for i in range(segments):
			draw_line(points[i], points[i + 1], circle_color, 2.0)
		var fill := circle_color
		fill.a = 0.2
		draw_circle(Vector2.ZERO, radius - 2, fill)
		draw_circle(Vector2.ZERO, 4, circle_color)
