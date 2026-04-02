extends Node2D

## Shelter — home base. All rooms fully visible. Fixed 3x2 layout.

const CELL_W := 300.0
const CELL_H := 200.0
const WALL := 12.0
const FLOOR_T := 12.0
const LADDER_W := 50.0

const COL_FLOOR := Color(0.32, 0.28, 0.22, 1)
const COL_WALL := Color(0.28, 0.24, 0.20, 1)
const COL_BG := Color(0.14, 0.13, 0.16, 1)
const COL_LADDER := Color(0.55, 0.45, 0.25, 0.8)
const COL_RUNG := Color(0.50, 0.40, 0.20, 1)

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera

func _ready() -> void:
	camera.follow_target = player
	_build_shelter()

func _build_shelter() -> void:
	# Fixed 3 columns x 2 rows shelter
	var cols := 3
	var rows := 2
	var container := Node2D.new()
	container.name = "ShelterMap"
	add_child(container)

	for row in range(rows):
		for col in range(cols):
			_build_room(container, col, row, cols, rows)

	# Ladders between floors (center column)
	var ladder_col := 1
	var hatch_x := ladder_col * CELL_W + CELL_W / 2.0 - LADDER_W / 2.0
	var top := FLOOR_T
	var bottom := rows * CELL_H - FLOOR_T
	_add_ladder_visual(container, hatch_x, top, LADDER_W, bottom - top)
	_add_ladder_area(container, ladder_col * CELL_W + CELL_W / 2.0, (top + bottom) / 2.0, LADDER_W, bottom - top + 80)

	# Campfire in bottom-left room
	var campfire_scene := load("res://scenes/props/campfire.tscn")
	var campfire: Node2D = campfire_scene.instantiate()
	campfire.position = Vector2(CELL_W * 0.5, CELL_H * 2.0 - FLOOR_T)
	campfire.z_index = 2
	container.add_child(campfire)

	# Spawn player
	player.global_position = Vector2(CELL_W * 1.5, CELL_H * 2.0 - FLOOR_T - 2)
	camera.global_position = player.global_position

	# Background
	var bg := $Background as ColorRect
	bg.offset_left = -500
	bg.offset_top = -300
	bg.offset_right = cols * CELL_W + 500
	bg.offset_bottom = rows * CELL_H + 300

func _build_room(parent: Node2D, col: int, row: int, cols: int, rows: int) -> void:
	var tl := Vector2(col * CELL_W, row * CELL_H)
	var has_l := col > 0
	var has_r := col < cols - 1
	var has_u := row > 0
	var has_d := row < rows - 1
	var is_ladder_col := (col == 1)

	# Room bg
	var bg := ColorRect.new()
	bg.offset_left = tl.x
	bg.offset_top = tl.y
	bg.offset_right = tl.x + CELL_W
	bg.offset_bottom = tl.y + CELL_H
	bg.color = COL_BG
	bg.z_index = -1
	parent.add_child(bg)

	# Ceiling
	if not has_u:
		_add_solid(parent, tl.x, tl.y, CELL_W, FLOOR_T, COL_FLOOR)
	elif is_ladder_col:
		var hx := tl.x + CELL_W / 2.0 - LADDER_W / 2.0
		_add_solid(parent, tl.x, tl.y, hx - tl.x, FLOOR_T, COL_FLOOR)
		_add_solid(parent, hx + LADDER_W, tl.y, tl.x + CELL_W - (hx + LADDER_W), FLOOR_T, COL_FLOOR)

	# Floor
	if not has_d:
		_add_solid(parent, tl.x, tl.y + CELL_H - FLOOR_T, CELL_W, FLOOR_T, COL_FLOOR)
	elif is_ladder_col:
		var hx := tl.x + CELL_W / 2.0 - LADDER_W / 2.0
		_add_solid(parent, tl.x, tl.y + CELL_H - FLOOR_T, hx - tl.x, FLOOR_T, COL_FLOOR)
		_add_solid(parent, hx + LADDER_W, tl.y + CELL_H - FLOOR_T, tl.x + CELL_W - (hx + LADDER_W), FLOOR_T, COL_FLOOR)
	else:
		_add_solid(parent, tl.x, tl.y + CELL_H - FLOOR_T, CELL_W, FLOOR_T, COL_FLOOR)

	# Left wall
	if not has_l:
		_add_solid(parent, tl.x, tl.y, WALL, CELL_H, COL_WALL)

	# Right wall
	if not has_r:
		_add_solid(parent, tl.x + CELL_W - WALL, tl.y, WALL, CELL_H, COL_WALL)

	# Nav
	var nav := NavigationRegion2D.new()
	parent.add_child(nav)
	var x1 := tl.x + (WALL if not has_l else 0.0)
	var x2 := tl.x + CELL_W - (WALL if not has_r else 0.0)
	var fy := tl.y + CELL_H - FLOOR_T
	var nav_poly := NavigationPolygon.new()
	var verts := PackedVector2Array([
		Vector2(x1, fy - 15), Vector2(x2, fy - 15),
		Vector2(x2, fy), Vector2(x1, fy),
	])
	nav_poly.vertices = verts
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_poly.add_outline(verts)
	nav.navigation_polygon = nav_poly

func _add_solid(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var body := StaticBody2D.new()
	parent.add_child(body)
	var visual := ColorRect.new()
	visual.offset_left = x
	visual.offset_top = y
	visual.offset_right = x + w
	visual.offset_bottom = y + h
	visual.color = color
	body.add_child(visual)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(x + w / 2.0, y + h / 2.0)
	body.add_child(col)

func _add_ladder_visual(parent: Node2D, x: float, y: float, w: float, span: float) -> void:
	var rect := func(px: float, py: float, pw: float, ph: float, c: Color) -> void:
		var r := ColorRect.new()
		r.offset_left = px; r.offset_top = py; r.offset_right = px + pw; r.offset_bottom = py + ph
		r.color = c
		parent.add_child(r)
	rect.call(x, y, 4, span, COL_LADDER)
	rect.call(x + w - 4, y, 4, span, COL_LADDER)
	var spacing := 28.0
	var count := int(span / spacing)
	for i in range(count):
		var ry := y + i * spacing + spacing / 2.0
		rect.call(x + 4, ry, w - 8, 3, COL_RUNG)

func _add_ladder_area(parent: Node2D, cx: float, cy: float, w: float, h: float) -> void:
	var area := Area2D.new()
	area.add_to_group("ladders")
	parent.add_child(area)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w + 10, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(cx, cy)
	area.add_child(col)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			player.set_move_target(get_global_mouse_position())
