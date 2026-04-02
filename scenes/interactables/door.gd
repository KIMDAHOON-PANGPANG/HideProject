class_name Door
extends Node2D

enum State { CLOSED, PEEKED, OPEN }

signal state_changed(new_state: State)

## The two rooms this door connects
@export var room_a := Vector2i.ZERO
@export var room_b := Vector2i.ZERO

var current_state: State = State.CLOSED
var is_hatch := false
## Store original visual size for animation
var _orig_visual_rect := Rect2()

@onready var blocker: StaticBody2D = $Blocker
@onready var visual: ColorRect = $Visual
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

const COLOR_CLOSED := Color(0.38, 0.30, 0.22, 1)
const COLOR_PEEKED := Color(0.50, 0.40, 0.28, 0.85)
const COLOR_OPEN := Color(0.30, 0.25, 0.18, 0.35)
const COLOR_CRACK := Color(0.8, 0.7, 0.4, 0.6)

var _crack_line: ColorRect = null

func _ready() -> void:
	prompt_label.visible = false
	_orig_visual_rect = Rect2(
		visual.offset_left, visual.offset_top,
		visual.offset_right - visual.offset_left,
		visual.offset_bottom - visual.offset_top
	)
	# Create crack-of-light indicator (hidden initially)
	_crack_line = ColorRect.new()
	_crack_line.visible = false
	_crack_line.color = COLOR_CRACK
	_crack_line.z_index = 1
	add_child(_crack_line)
	_update_visual()

## Call after adding to scene tree to reshape as a horizontal hatch.
func setup_as_hatch(hatch_width: float) -> void:
	is_hatch = true
	var hw := hatch_width
	var hh := 12.0
	# Reshape visual
	visual.offset_left = -hw / 2.0
	visual.offset_top = -hh / 2.0
	visual.offset_right = hw / 2.0
	visual.offset_bottom = hh / 2.0
	_orig_visual_rect = Rect2(visual.offset_left, visual.offset_top, hw, hh)
	# Reshape blocker collision
	for child in blocker.get_children():
		if child is CollisionShape2D:
			var shape := RectangleShape2D.new()
			shape.size = Vector2(hw, hh)
			child.shape = shape
	# Reshape interaction area
	for child in interaction_area.get_children():
		if child is CollisionShape2D:
			var shape := RectangleShape2D.new()
			shape.size = Vector2(hw + 40, 60)
			child.shape = shape
	prompt_label.offset_left = -15
	prompt_label.offset_top = -40
	prompt_label.offset_right = 15
	prompt_label.offset_bottom = -22

func interact() -> void:
	match current_state:
		State.CLOSED:
			current_state = State.PEEKED
		State.PEEKED:
			current_state = State.OPEN
		State.OPEN:
			current_state = State.CLOSED
	_update_visual()
	state_changed.emit(current_state)

func show_prompt(show: bool) -> void:
	prompt_label.visible = show
	if show:
		match current_state:
			State.CLOSED:
				prompt_label.text = "[E] 엿보기"
			State.PEEKED:
				prompt_label.text = "[E] 열기"
			State.OPEN:
				prompt_label.text = "[E] 닫기"

func _update_visual() -> void:
	match current_state:
		State.CLOSED:
			visual.color = COLOR_CLOSED
			visual.visible = true
			_crack_line.visible = false
			_reset_visual_rect()
			_set_blocker_enabled(true)
		State.PEEKED:
			visual.color = COLOR_PEEKED
			visual.visible = true
			_show_crack()
			_set_blocker_enabled(true)
		State.OPEN:
			visual.visible = true
			visual.color = COLOR_OPEN
			_crack_line.visible = false
			_show_open()
			_set_blocker_enabled(false)
			prompt_label.visible = false

func _set_blocker_enabled(enabled: bool) -> void:
	if enabled:
		blocker.collision_layer = 1
		blocker.collision_mask = 1
	else:
		blocker.collision_layer = 0
		blocker.collision_mask = 0
	for child in blocker.get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled

func _reset_visual_rect() -> void:
	visual.offset_left = _orig_visual_rect.position.x
	visual.offset_top = _orig_visual_rect.position.y
	visual.offset_right = _orig_visual_rect.position.x + _orig_visual_rect.size.x
	visual.offset_bottom = _orig_visual_rect.position.y + _orig_visual_rect.size.y

func _show_crack() -> void:
	_crack_line.visible = true
	if is_hatch:
		# Horizontal crack along one edge
		_crack_line.offset_left = _orig_visual_rect.position.x + 2
		_crack_line.offset_top = _orig_visual_rect.position.y + _orig_visual_rect.size.y - 3
		_crack_line.offset_right = _orig_visual_rect.position.x + _orig_visual_rect.size.x - 2
		_crack_line.offset_bottom = _orig_visual_rect.position.y + _orig_visual_rect.size.y
	else:
		# Vertical crack down the middle
		_crack_line.offset_left = -1.5
		_crack_line.offset_top = _orig_visual_rect.position.y + 4
		_crack_line.offset_right = 1.5
		_crack_line.offset_bottom = _orig_visual_rect.position.y + _orig_visual_rect.size.y - 4

func _show_open() -> void:
	if is_hatch:
		# Hatch slides to one side — shrink to thin strip at the edge
		visual.offset_left = _orig_visual_rect.position.x
		visual.offset_top = _orig_visual_rect.position.y
		visual.offset_right = _orig_visual_rect.position.x + 6
		visual.offset_bottom = _orig_visual_rect.position.y + _orig_visual_rect.size.y
	else:
		# Door swings open — visual becomes thin strip on one side
		var orig_h := _orig_visual_rect.size.y
		visual.offset_left = _orig_visual_rect.position.x
		visual.offset_top = _orig_visual_rect.position.y
		visual.offset_right = _orig_visual_rect.position.x + _orig_visual_rect.size.x
		visual.offset_bottom = _orig_visual_rect.position.y + 8  # only top sliver remains (hinged open)
