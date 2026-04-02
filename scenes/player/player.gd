extends CharacterBody2D

const SPEED := 150.0
const CLIMB_SPEED := 120.0
const GRAVITY := 980.0

const MAX_STAMINA := 100.0
const STAMINA_REGEN := 15.0  # per second
const ATTACK_COST := 25.0
const ATTACK_RANGE := 60.0
const ATTACK_DAMAGE := 1
const ATTACK_COOLDOWN := 0.5

var has_target := false
var on_ladder := false
var ladder_count := 0
var stamina := MAX_STAMINA
var attack_cooldown_timer := 0.0
var is_attacking := false
var attack_timer := 0.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var visual: ColorRect = $Visual
@onready var ladder_detector: Area2D = $LadderDetector
@onready var stamina_bar: ColorRect = $StaminaBar
@onready var stamina_bg: ColorRect = $StaminaBg

func _ready() -> void:
	add_to_group("player")
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.avoidance_enabled = false
	nav_agent.navigation_finished.connect(_on_navigation_finished)
	ladder_detector.area_entered.connect(_on_ladder_entered)
	ladder_detector.area_exited.connect(_on_ladder_exited)

func _on_ladder_entered(area: Area2D) -> void:
	if area.is_in_group("ladders"):
		ladder_count += 1

func _on_ladder_exited(area: Area2D) -> void:
	if area.is_in_group("ladders"):
		ladder_count -= 1
		if ladder_count <= 0:
			ladder_count = 0
			on_ladder = false

func set_move_target(target: Vector2) -> void:
	has_target = true
	nav_agent.target_position = target

func _on_navigation_finished() -> void:
	has_target = false

func try_attack(click_pos: Vector2) -> bool:
	if attack_cooldown_timer > 0:
		return false
	if stamina < ATTACK_COST:
		return false

	# Find closest enemy to click position
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_dist := ATTACK_RANGE * 2.0
	for enemy in enemies:
		var dist_to_click: float = enemy.global_position.distance_to(click_pos)
		var dist_to_player: float = enemy.global_position.distance_to(global_position)
		if dist_to_click < 40.0 and dist_to_player < ATTACK_RANGE:
			if dist_to_click < best_dist:
				best_dist = dist_to_click
				best_enemy = enemy

	if best_enemy == null:
		return false

	# Attack!
	stamina -= ATTACK_COST
	attack_cooldown_timer = ATTACK_COOLDOWN
	is_attacking = true
	attack_timer = 0.15

	# Face the enemy
	if best_enemy.global_position.x < global_position.x:
		visual.scale.x = -1
	else:
		visual.scale.x = 1

	# Deal damage
	if best_enemy.has_method("take_damage"):
		best_enemy.take_damage(ATTACK_DAMAGE)

	return true

func _physics_process(delta: float) -> void:
	# Stamina regen
	if stamina < MAX_STAMINA:
		stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)

	# Attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# Attack flash
	if is_attacking:
		attack_timer -= delta
		visual.color = Color(1.0, 1.0, 1.0, 1.0)
		if attack_timer <= 0:
			is_attacking = false
			visual.color = Color(0.2, 0.55, 0.8, 1.0)

	# Update stamina bar
	var bar_ratio := stamina / MAX_STAMINA
	stamina_bar.scale.x = bar_ratio
	if stamina < ATTACK_COST:
		stamina_bar.color = Color(0.8, 0.3, 0.2, 0.9)
	else:
		stamina_bar.color = Color(0.2, 0.8, 0.3, 0.9)

	# Movement
	var input_h := Input.get_axis("move_left", "move_right")
	var input_v := Input.get_axis("move_up", "move_down")

	if ladder_count > 0 and input_v != 0.0:
		on_ladder = true
		has_target = false

	if on_ladder:
		velocity.y = input_v * CLIMB_SPEED
		velocity.x = input_h * SPEED
		_flip(input_h)
		if ladder_count <= 0:
			on_ladder = false
	elif input_h != 0.0:
		has_target = false
		velocity.x = input_h * SPEED
		velocity.y = _gravity(delta)
		_flip(input_h)
	elif has_target and not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		velocity.x = dir.x * SPEED
		velocity.y = dir.y * SPEED if absf(dir.y) > 0.3 else _gravity(delta)
		_flip(dir.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10)
		velocity.y = _gravity(delta)

	move_and_slide()

func _flip(dir_x: float) -> void:
	if dir_x < -0.1:
		visual.scale.x = -1
	elif dir_x > 0.1:
		visual.scale.x = 1

func _gravity(delta: float) -> float:
	if not is_on_floor():
		return velocity.y + GRAVITY * delta
	return 0.0
