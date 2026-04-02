extends Node2D

const ROOM_COUNT := 12
const PEEK_RANGE := 100.0

const VIS_VISIBLE := Color(1, 1, 1, 1)
const VIS_PEEKED := Color(0.4, 0.4, 0.5, 0.7)
const VIS_REMEMBERED := Color(0.25, 0.25, 0.3, 1)
const VIS_HIDDEN := Color(0.05, 0.05, 0.08, 1)

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera

var room_nodes: Dictionary = {}
var room_state: Dictionary = {}
var door_registry: Dictionary = {}
var grid: Dictionary = {}
var current_room := Vector2i.ZERO
# Track which doors are actively being peeked (door_key -> other_room)
var peeked_doors: Dictionary = {}

func _ready() -> void:
	camera.follow_target = player
	_generate_map()

func _generate_map() -> void:
	var result := BuildingGenerator.generate_map(self, ROOM_COUNT)
	grid = result["grid"]
	room_nodes = result["room_nodes"]
	door_registry = result["doors"]
	player.global_position = result["spawn"]
	camera.global_position = player.global_position

	for cell: Vector2i in grid:
		room_state[cell] = "hidden"

	for key: String in door_registry:
		var door: Door = door_registry[key]
		door.state_changed.connect(_on_door_state_changed.bind(door, key))

	current_room = _pos_to_cell(player.global_position)
	_set_room_visibility(current_room, "visible")
	_update_all_visibility()
	_update_background()

func _physics_process(_delta: float) -> void:
	# Room transition
	var new_room := _pos_to_cell(player.global_position)
	if new_room != current_room and grid.has(new_room):
		var old_room := current_room
		current_room = new_room
		_set_room_visibility(old_room, "remembered")
		_set_room_visibility(new_room, "visible")
		_update_all_visibility()

	# Peek distance check — revert peeked rooms when player walks away
	var keys_to_remove: Array[String] = []
	for key: String in peeked_doors:
		var door: Door = door_registry[key]
		var dist := player.global_position.distance_to(door.global_position)
		if dist > PEEK_RANGE:
			var other_cell: Vector2i = peeked_doors[key]
			# Only revert if player is NOT in that room
			if other_cell != current_room:
				_set_room_visibility(other_cell, "hidden")
				keys_to_remove.append(key)
	for key in keys_to_remove:
		peeked_doors.erase(key)
	if keys_to_remove.size() > 0:
		_update_all_visibility()

	_update_door_prompts()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var click_pos := get_global_mouse_position()
			# Try attack first, then move
			if not player.try_attack(click_pos):
				player.set_move_target(click_pos)

	if event.is_action_pressed("interact"):
		if not _try_assassinate():
			_try_interact_door()

func _try_assassinate() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var dist: float = player.global_position.distance_to(enemy.global_position)
		if dist > 50.0:
			continue
		# Must not be detected (enemy not chasing)
		if enemy.current_state == enemy.CHASE:
			continue
		# Enemy must not currently see the player
		if enemy.can_see(player.global_position):
			continue
		# Assassinate!
		enemy.take_damage(999)
		return true
	return false

func _try_interact_door() -> void:
	var closest_door: Door = _get_closest_door()
	if closest_door:
		closest_door.interact()

func _get_closest_door() -> Door:
	var best: Door = null
	var best_dist := 80.0
	for key: String in door_registry:
		var door: Door = door_registry[key]
		var dist := player.global_position.distance_to(door.global_position)
		if dist < best_dist:
			best_dist = dist
			best = door
	return best

func _update_door_prompts() -> void:
	var closest := _get_closest_door()
	for key: String in door_registry:
		var door: Door = door_registry[key]
		door.show_prompt(door == closest)

func _on_door_state_changed(new_state: Door.State, door: Door, key: String) -> void:
	var other: Vector2i
	if current_room == door.room_a:
		other = door.room_b
	elif current_room == door.room_b:
		other = door.room_a
	else:
		if room_state.get(door.room_a, "hidden") == "visible":
			other = door.room_b
		else:
			other = door.room_a

	if new_state == Door.State.PEEKED:
		if room_state.get(other, "hidden") in ["hidden"]:
			_set_room_visibility(other, "peeked")
			peeked_doors[key] = other
			_update_all_visibility()
	elif new_state == Door.State.OPEN:
		peeked_doors.erase(key)
		if room_state.get(other, "hidden") in ["hidden", "peeked"]:
			_set_room_visibility(other, "remembered")
			_update_all_visibility()
	elif new_state == Door.State.CLOSED:
		# Close door — hide the other room again (unless player is in it)
		peeked_doors.erase(key)
		if other != current_room:
			_set_room_visibility(other, "hidden")
			_update_all_visibility()

func _set_room_visibility(cell: Vector2i, state: String) -> void:
	room_state[cell] = state

func _update_all_visibility() -> void:
	for cell: Vector2i in room_nodes:
		var node: Node2D = room_nodes[cell]
		var state: String = room_state.get(cell, "hidden")
		match state:
			"visible":
				node.modulate = VIS_VISIBLE
			"peeked":
				node.modulate = VIS_PEEKED
			"remembered":
				node.modulate = VIS_REMEMBERED
			_:
				node.modulate = VIS_HIDDEN

func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(pos.x / BuildingGenerator.CELL_W),
		floori(pos.y / BuildingGenerator.CELL_H)
	)

func _update_background() -> void:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for cell: Vector2i in grid:
		var x := cell.x * BuildingGenerator.CELL_W
		var y := cell.y * BuildingGenerator.CELL_H
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x + BuildingGenerator.CELL_W)
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y + BuildingGenerator.CELL_H)
	var bg := $Background as ColorRect
	var margin := 800.0
	bg.offset_left = min_x - margin
	bg.offset_top = min_y - margin
	bg.offset_right = max_x + margin
	bg.offset_bottom = max_y + margin
