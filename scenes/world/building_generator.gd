class_name BuildingGenerator
extends RefCounted

## Generates grid-based rooms with walls and doors between them.

const CELL_W := 300.0
const CELL_H := 200.0
const WALL := 12.0
const FLOOR := 12.0
const LADDER_W := 50.0
const NAV_H := 15.0

const COL_FLOOR := Color(0.30, 0.25, 0.20, 1)
const COL_WALL := Color(0.25, 0.20, 0.18, 1)
const COL_BG := Color(0.12, 0.11, 0.14, 1)
const COL_LADDER := Color(0.55, 0.45, 0.25, 0.8)
const COL_RUNG := Color(0.50, 0.40, 0.20, 1)

static var _door_scene: PackedScene = null
static var _campfire_scene: PackedScene = null
static var _enemy_scene: PackedScene = null


static func generate_map(parent: Node2D, room_count: int) -> Dictionary:
	if _door_scene == null:
		_door_scene = load("res://scenes/interactables/door.tscn")
	if _campfire_scene == null:
		_campfire_scene = load("res://scenes/props/campfire.tscn")
	if _enemy_scene == null:
		_enemy_scene = load("res://scenes/enemies/enemy.tscn")

	# 1) Random walk to generate rooms
	var grid: Dictionary = {}
	var start := Vector2i(0, 0)
	grid[start] = true
	grid[Vector2i(-1, 0)] = true
	grid[Vector2i(1, 0)] = true

	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var current := start
	var max_iterations := room_count * 50
	var iterations := 0
	while grid.size() < room_count and iterations < max_iterations:
		iterations += 1
		var dir: Vector2i = dirs.pick_random()
		var next := current + dir
		# Prefer stepping onto new cells
		if not grid.has(next):
			grid[next] = true
			current = next
		else:
			# 50% chance to move anyway (keeps walk from getting stuck)
			if randf() > 0.5:
				current = next

	# 2) Post-process: dead-end rooms get a vertical neighbor
	var to_add: Array[Vector2i] = []
	for cell: Vector2i in grid:
		var has_h := grid.has(cell + Vector2i(-1, 0)) or grid.has(cell + Vector2i(1, 0))
		if not has_h:
			var has_v := grid.has(cell + Vector2i(0, -1)) or grid.has(cell + Vector2i(0, 1))
			if not has_v:
				if randi() % 2 == 0:
					to_add.append(cell + Vector2i(0, -1))
				else:
					to_add.append(cell + Vector2i(0, 1))
	for c in to_add:
		grid[c] = true

	# 3) Recenter grid so the median cell becomes (0,0)
	var all_cells: Array[Vector2i] = []
	for cell: Vector2i in grid:
		all_cells.append(cell)
	var sum_x := 0
	var sum_y := 0
	for cell in all_cells:
		sum_x += cell.x
		sum_y += cell.y
	var center_offset := Vector2i(
		roundi(float(sum_x) / all_cells.size()),
		roundi(float(sum_y) / all_cells.size())
	)
	if center_offset != Vector2i.ZERO:
		var new_grid: Dictionary = {}
		for cell in all_cells:
			new_grid[cell - center_offset] = true
		grid = new_grid

	# 4) Find shelter cell — closest to (0,0) with left+right neighbors
	var shelter := Vector2i(0, 0)
	if not grid.has(shelter):
		var best_dist := 9999.0
		for cell: Vector2i in grid:
			var d := Vector2(cell.x, cell.y).length()
			if d < best_dist and grid.has(cell + Vector2i(-1, 0)) and grid.has(cell + Vector2i(1, 0)):
				best_dist = d
				shelter = cell
		if not grid.has(shelter):
			# Fallback: just pick closest to origin
			var best_d2 := 9999.0
			for cell: Vector2i in grid:
				var d := Vector2(cell.x, cell.y).length()
				if d < best_d2:
					best_d2 = d
					shelter = cell

	# 5) Build rooms
	var room_nodes: Dictionary = {}
	var door_registry: Dictionary = {}

	var map_container := Node2D.new()
	map_container.name = "Map"
	parent.add_child(map_container)

	for cell: Vector2i in grid:
		var room := _build_room(map_container, cell, grid, door_registry)
		room_nodes[cell] = room

	# 6) Place campfire in shelter (avoid ladder overlap)
	var shelter_node: Node2D = room_nodes[shelter]
	var campfire: Node2D = _campfire_scene.instantiate()
	var shelter_tl := _cell_tl(shelter)
	var has_ladder := grid.has(shelter + Vector2i(0, -1)) or grid.has(shelter + Vector2i(0, 1))
	var fire_x: float
	if has_ladder:
		# Ladder is at center — place campfire to the left or right
		if grid.has(shelter + Vector2i(-1, 0)):
			fire_x = shelter_tl.x + CELL_W * 0.75
		else:
			fire_x = shelter_tl.x + CELL_W * 0.25
	else:
		fire_x = shelter_tl.x + CELL_W / 2.0
	campfire.position = Vector2(fire_x, shelter_tl.y + CELL_H - FLOOR)
	campfire.z_index = 2
	shelter_node.add_child(campfire)

	# 7) Spawn enemies in random rooms (not shelter or its direct neighbors)
	var enemy_nodes: Array[Node2D] = []
	var safe_cells: Array[Vector2i] = [shelter]
	for dir in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
		safe_cells.append(shelter + dir)

	for cell: Vector2i in grid:
		if cell in safe_cells:
			continue
		# ~40% chance to spawn enemy
		if randf() > 0.4:
			continue
		var cell_tl := _cell_tl(cell)
		var enemy_x := cell_tl.x + randf_range(WALL + 30, CELL_W - WALL - 30)
		var enemy_y := cell_tl.y + CELL_H - FLOOR - 2
		var enemy: CharacterBody2D = _enemy_scene.instantiate()
		enemy.position = Vector2(enemy_x, enemy_y)
		enemy.z_index = 8
		room_nodes[cell].add_child(enemy)
		enemy.setup(cell, cell_tl.x + WALL + 10, cell_tl.x + CELL_W - WALL - 10)
		enemy.facing = [-1, 1].pick_random()
		enemy_nodes.append(enemy)

	# 8) Spawn position
	var spawn := _cell_center(shelter)
	spawn.y += CELL_H / 2.0 - FLOOR - 2

	return {
		"grid": grid,
		"spawn": spawn,
		"shelter": shelter,
		"room_nodes": room_nodes,
		"doors": door_registry,
		"enemies": enemy_nodes,
	}


static func _cell_tl(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_W, cell.y * CELL_H)


static func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_W + CELL_W / 2.0, cell.y * CELL_H + CELL_H / 2.0)


static func _door_key(a: Vector2i, b: Vector2i) -> String:
	# Canonical key so A-B == B-A
	if a < b:
		return "%d,%d_%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d_%d,%d" % [b.x, b.y, a.x, a.y]


static func _build_room(map: Node2D, cell: Vector2i, grid: Dictionary, doors: Dictionary) -> Node2D:
	var tl := _cell_tl(cell)
	var room := Node2D.new()
	room.name = "Room_%d_%d" % [cell.x, cell.y]
	room.position = Vector2.ZERO
	map.add_child(room)

	# Background
	var bg := ColorRect.new()
	bg.offset_left = tl.x
	bg.offset_top = tl.y
	bg.offset_right = tl.x + CELL_W
	bg.offset_bottom = tl.y + CELL_H
	bg.color = COL_BG
	bg.z_index = -1
	room.add_child(bg)

	var has_l := grid.has(cell + Vector2i(-1, 0))
	var has_r := grid.has(cell + Vector2i(1, 0))
	var has_u := grid.has(cell + Vector2i(0, -1))
	var has_d := grid.has(cell + Vector2i(0, 1))

	# --- Ceiling ---
	if not has_u:
		_add_solid(room, tl.x, tl.y, CELL_W, FLOOR, COL_FLOOR)
	else:
		# Ceiling with gap for hatch/ladder
		var hatch_x := tl.x + CELL_W / 2.0 - LADDER_W / 2.0
		_add_solid(room, tl.x, tl.y, hatch_x - tl.x, FLOOR, COL_FLOOR)
		_add_solid(room, hatch_x + LADDER_W, tl.y, tl.x + CELL_W - (hatch_x + LADDER_W), FLOOR, COL_FLOOR)

	# --- Floor ---
	if not has_d:
		_add_solid(room, tl.x, tl.y + CELL_H - FLOOR, CELL_W, FLOOR, COL_FLOOR)
	else:
		# Floor with gap for hatch/ladder going down
		var hatch_x := tl.x + CELL_W / 2.0 - LADDER_W / 2.0
		_add_solid(room, tl.x, tl.y + CELL_H - FLOOR, hatch_x - tl.x, FLOOR, COL_FLOOR)
		_add_solid(room, hatch_x + LADDER_W, tl.y + CELL_H - FLOOR, tl.x + CELL_W - (hatch_x + LADDER_W), FLOOR, COL_FLOOR)
		# Hatch door at the floor opening (only create once per pair)
		var door_key := _door_key(cell, cell + Vector2i(0, 1))
		if not doors.has(door_key):
			var hatch_center := Vector2(tl.x + CELL_W / 2.0, tl.y + CELL_H - FLOOR / 2.0)
			var hatch_door := _create_hatch(map, hatch_center, cell, cell + Vector2i(0, 1), LADDER_W)
			doors[door_key] = hatch_door

	# --- Ladder visual + detection area (extends beyond room boundaries) ---
	if has_u or has_d:
		var hatch_x := tl.x + CELL_W / 2.0 - LADDER_W / 2.0
		# Visual: within the room
		var vis_top := tl.y + FLOOR
		var vis_bottom := tl.y + CELL_H - FLOOR
		_add_ladder_visual(room, hatch_x, vis_top, LADDER_W, vis_bottom - vis_top)
		# Area2D: extend 40px beyond room boundaries so player doesn't lose ladder state at transitions
		var area_top := tl.y - 40 if has_u else tl.y + FLOOR
		var area_bottom := tl.y + CELL_H + 40 if has_d else tl.y + CELL_H - FLOOR
		var area_center_y := (area_top + area_bottom) / 2.0
		var area_height := area_bottom - area_top
		_add_ladder_area(room, tl.x + CELL_W / 2.0, area_center_y, LADDER_W, area_height)

	# --- Left wall ---
	if not has_l:
		_add_solid(room, tl.x, tl.y, WALL, CELL_H, COL_WALL)
	else:
		# Wall with door gap
		var door_key := _door_key(cell, cell + Vector2i(-1, 0))
		if not doors.has(door_key):
			var door_y := tl.y + CELL_H - FLOOR - 80  # Door bottom aligns with floor
			# Wall above door
			_add_solid(room, tl.x, tl.y, WALL, door_y - tl.y, COL_WALL)
			# Wall below door (floor-level)
			# Door sits on the floor, no wall below needed
			var door := _create_door(map, Vector2(tl.x, door_y + 40), cell, cell + Vector2i(-1, 0))
			doors[door_key] = door

	# --- Right wall ---
	if not has_r:
		_add_solid(room, tl.x + CELL_W - WALL, tl.y, WALL, CELL_H, COL_WALL)
	else:
		var door_key := _door_key(cell, cell + Vector2i(1, 0))
		if not doors.has(door_key):
			var door_y := tl.y + CELL_H - FLOOR - 80
			_add_solid(room, tl.x + CELL_W - WALL, tl.y, WALL, door_y - tl.y, COL_WALL)
			var door := _create_door(map, Vector2(tl.x + CELL_W, door_y + 40), cell, cell + Vector2i(1, 0))
			doors[door_key] = door

	# --- Navigation (walkable floor) ---
	_add_nav(room, cell, tl)

	return room


static func _add_solid(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
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


static func _add_ladder_area(parent: Node2D, center_x: float, center_y: float, w: float, h: float) -> void:
	var area := Area2D.new()
	area.name = "LadderArea"
	area.add_to_group("ladders")
	parent.add_child(area)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w + 10, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(center_x, center_y)
	area.add_child(col)


static func _add_ladder_visual(parent: Node2D, x: float, y: float, w: float, span: float) -> void:
	# Rails
	_add_rect(parent, x, y, 4, span, COL_LADDER)
	_add_rect(parent, x + w - 4, y, 4, span, COL_LADDER)
	# Rungs
	var rung_spacing := 28.0
	var count := int(span / rung_spacing)
	for i in range(count):
		var ry := y + i * rung_spacing + rung_spacing / 2.0
		_add_rect(parent, x + 4, ry, w - 8, 3, COL_RUNG)


static func _add_rect(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.offset_left = x
	rect.offset_top = y
	rect.offset_right = x + w
	rect.offset_bottom = y + h
	rect.color = color
	parent.add_child(rect)


static func _create_door(parent: Node2D, pos: Vector2, a: Vector2i, b: Vector2i) -> Door:
	var door: Door = _door_scene.instantiate()
	door.position = pos
	door.room_a = a
	door.room_b = b
	door.z_index = 5
	parent.add_child(door)
	return door


static func _create_hatch(parent: Node2D, pos: Vector2, a: Vector2i, b: Vector2i, width: float) -> Door:
	var door: Door = _door_scene.instantiate()
	door.position = pos
	door.room_a = a
	door.room_b = b
	door.z_index = 5
	parent.add_child(door)
	door.setup_as_hatch(width)
	return door


static func _add_nav(parent: Node2D, cell: Vector2i, tl: Vector2) -> void:
	var nav := NavigationRegion2D.new()
	nav.name = "Nav_%d_%d" % [cell.x, cell.y]
	parent.add_child(nav)

	var x1 := tl.x + WALL
	var x2 := tl.x + CELL_W - WALL
	var floor_y := tl.y + CELL_H - FLOOR

	var nav_poly := NavigationPolygon.new()
	var verts := PackedVector2Array([
		Vector2(x1, floor_y - NAV_H),
		Vector2(x2, floor_y - NAV_H),
		Vector2(x2, floor_y),
		Vector2(x1, floor_y),
	])
	nav_poly.vertices = verts
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_poly.add_outline(verts)
	nav.navigation_polygon = nav_poly
