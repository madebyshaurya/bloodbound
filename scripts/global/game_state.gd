extends Node

var _player_state: Dictionary = {}
var _has_state := false

func capture_player(player: Node) -> void:
	if player == null or not player.has_method("export_state"):
		return
	_player_state = player.export_state()
	_has_state = true

func apply_to_player(player: Node) -> void:
	if not _has_state:
		return
	if player and player.has_method("apply_state"):
		player.apply_state(_player_state)

func clear_state() -> void:
	_player_state.clear()
	_has_state = false

func has_saved_state() -> bool:
	return _has_state

func get_state() -> Dictionary:
	return _player_state
