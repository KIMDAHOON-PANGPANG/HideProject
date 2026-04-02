extends CanvasLayer

signal dungeon_button_pressed

@onready var dungeon_btn: Button = $DungeonButton

func _ready() -> void:
	dungeon_btn.pressed.connect(func() -> void: dungeon_button_pressed.emit())
