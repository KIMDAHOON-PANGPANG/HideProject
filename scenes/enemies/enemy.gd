extends CharacterBody2D

enum { PATROL, CHASE, RETURN }

const PATROL_SPEED = 60.0
const CHASE_SPEED = 110.0
const GRAVITY = 980.0
const VIEW_RANGE = 150.0
const VIEW_ANGLE = 55.0
const LOST_SIGHT_TIMEOUT = 2.0

var current_state = PATROL
var facing = 1
var patrol_timer = 0.0
var patrol_pause = false
var chase_target: Node2D = null
var room_cell = Vector2i.ZERO
var lost_sight_time = 0.0
var room_left = 0.0
var room_right = 0.0
var prev_facing = 1
var prev_state = PATROL
var redraw_timer = 0.0
var hp = 3
var hit_flash_timer = 0.0

@onready var visual: ColorRect = $Visual
@onready var vision_cone: Node2D = $VisionCone

func _ready() -> void:
	add_to_group("enemies")

func take_damage(amount: int) -> void:
	hp -= amount
	hit_flash_timer = 0.15
	# Aggro on attacker
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		chase_target = players[0]
		current_state = CHASE
		lost_sight_time = 0.0
	if hp <= 0:
		queue_free()

func setup(cell: Vector2i, left_bound: float, right_bound: float) -> void:
	room_cell = cell
	room_left = left_bound
	room_right = right_bound

func _physics_process(delta: float) -> void:
	# Hit flash
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		visual.color = Color(1.0, 0.6, 0.6, 1.0)
	else:
		visual.color = Color(0.8, 0.2, 0.15, 1.0)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if current_state == PATROL:
		do_patrol(delta)
	elif current_state == CHASE:
		do_chase(delta)
	elif current_state == RETURN:
		do_return(delta)

	check_vision()
	move_and_slide()

	var needs_redraw = false
	if facing != prev_facing or current_state != prev_state:
		needs_redraw = true
		prev_facing = facing
		prev_state = current_state
	redraw_timer -= delta
	if redraw_timer <= 0:
		needs_redraw = true
		redraw_timer = 0.1
	if needs_redraw:
		vision_cone.queue_redraw()

func do_patrol(delta: float) -> void:
	if patrol_pause:
		velocity.x = 0.0
		patrol_timer -= delta
		if patrol_timer <= 0:
			patrol_pause = false
			facing = -facing
			patrol_timer = randf_range(2.0, 5.0)
		return

	velocity.x = facing * PATROL_SPEED
	patrol_timer -= delta

	if global_position.x <= room_left + 20:
		facing = 1
		patrol_timer = randf_range(2.0, 5.0)
	elif global_position.x >= room_right - 20:
		facing = -1
		patrol_timer = randf_range(2.0, 5.0)

	if patrol_timer <= 0:
		patrol_pause = true
		patrol_timer = randf_range(1.0, 2.5)

	visual.scale.x = facing

func do_chase(delta: float) -> void:
	if not is_instance_valid(chase_target):
		current_state = RETURN
		return

	var dir = (chase_target.global_position - global_position).normalized()
	velocity.x = dir.x * CHASE_SPEED
	if dir.x > 0:
		visual.scale.x = 1
		facing = 1
	else:
		visual.scale.x = -1
		facing = -1

	if not can_see(chase_target.global_position):
		lost_sight_time += delta
		if lost_sight_time >= LOST_SIGHT_TIMEOUT:
			current_state = RETURN
			chase_target = null
			lost_sight_time = 0.0
	else:
		lost_sight_time = 0.0

func do_return(_delta: float) -> void:
	var room_center_x = (room_left + room_right) / 2.0
	var dist = absf(global_position.x - room_center_x)
	if dist < 10:
		current_state = PATROL
		patrol_timer = randf_range(1.0, 3.0)
		return
	var dir_sign = signf(room_center_x - global_position.x)
	velocity.x = dir_sign * PATROL_SPEED
	visual.scale.x = dir_sign
	if dir_sign > 0:
		facing = 1
	else:
		facing = -1

func check_vision() -> void:
	if current_state == CHASE:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	if can_see(player.global_position):
		chase_target = player
		current_state = CHASE
		lost_sight_time = 0.0

func can_see(target_pos: Vector2) -> bool:
	var to_target = target_pos - global_position
	var dist = to_target.length()
	if dist > VIEW_RANGE:
		return false

	var forward = Vector2(facing, 0)
	var angle = rad_to_deg(forward.angle_to(to_target))
	if absf(angle) > VIEW_ANGLE:
		return false

	var space = get_world_2d().direct_space_state
	if space == null:
		return false
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_dist = (result.position - global_position).length()
	return hit_dist >= dist - 5.0
