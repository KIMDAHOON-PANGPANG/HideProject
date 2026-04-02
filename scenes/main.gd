extends Node

## Main scene manager — handles transitions between shelter and dungeons.

const SHELTER_SCENE := "res://scenes/shelter/shelter.tscn"
const DUNGEON_SCENES := {
	"dungeon_01": "res://scenes/world/world.tscn",
}

var hud_scene := preload("res://scenes/ui/hud.tscn")
var dungeon_select_scene := preload("res://scenes/ui/dungeon_select.tscn")

var current_scene: Node = null
var hud: CanvasLayer = null
var dungeon_select: CanvasLayer = null
var is_in_shelter := true

func _ready() -> void:
	# Setup HUD
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.dungeon_button_pressed.connect(_on_dungeon_button)

	# Setup dungeon select
	dungeon_select = dungeon_select_scene.instantiate()
	add_child(dungeon_select)
	dungeon_select.dungeon_selected.connect(_on_dungeon_selected)

	# Load shelter
	_load_scene(SHELTER_SCENE)
	_update_hud_visibility()

func _on_dungeon_button() -> void:
	if is_in_shelter:
		dungeon_select.show_panel()

func _on_dungeon_selected(dungeon_id: String) -> void:
	dungeon_select.visible = false
	if DUNGEON_SCENES.has(dungeon_id):
		is_in_shelter = false
		_load_scene(DUNGEON_SCENES[dungeon_id])
		_update_hud_visibility()

func _update_hud_visibility() -> void:
	hud.visible = is_in_shelter

func _unhandled_input(event: InputEvent) -> void:
	# ESC in dungeon → return to shelter
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not is_in_shelter:
			is_in_shelter = true
			_load_scene(SHELTER_SCENE)
			_update_hud_visibility()

func _load_scene(path: String) -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene := load(path) as PackedScene
	current_scene = scene.instantiate()
	add_child(current_scene)
