extends Area2D

@export var next_scene: PackedScene

var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered or next_scene == null:
		return
	if body == null or not body.has_method("export_state"):
		return
	_triggered = true
	GameState.capture_player(body)
	get_tree().change_scene_to_packed(next_scene)
