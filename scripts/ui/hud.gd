extends CanvasLayer

const INSTRUCTION_AUTO_HIDE_TIME := 6.0

@export var player_path: NodePath

@onready var bar_fill: ColorRect = %BarFill
@onready var bar_border: ColorRect = %BarBorder
@onready var percentage_label: Label = %PercentageLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var instructions_panel: Control = %InstructionsPanel

var player: Node
var max_bar_width: float = 0.0
var _instruction_timer: SceneTreeTimer
var _instructions_hidden := false

func _ready() -> void:
	player = get_node_or_null(player_path)
	max_bar_width = _calculate_max_width()
	_apply_pixel_filter()
	_show_instructions()

	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			_on_player_health_changed(_get_player_health(), _get_player_max_health())
		else:
			push_warning("Player at %s does not emit health_changed" % player_path)
		if player.has_signal("ammo_changed"):
			player.ammo_changed.connect(_on_player_ammo_changed)
			_on_player_ammo_changed(_get_player_ammo(), _get_player_max_ammo())
		else:
			push_warning("Player at %s does not emit ammo_changed" % player_path)
	else:
		push_warning("Player node not found for HUD at path %s" % player_path)
		_update_ammo_label(0, 0)

func _get_player_health() -> int:
	if player:
		return int(player.get("health"))
	return 0

func _get_player_max_health() -> int:
	if player:
		var value = int(player.get("max_health"))
		return value if value > 0 else 1
	return 1

func _get_player_ammo() -> int:
	if player:
		return int(player.get("ammo"))
	return 0

func _get_player_max_ammo() -> int:
	if player:
		return max(int(player.get("max_ammo")), 0)
	return 0

func _apply_pixel_filter() -> void:
	for node in [bar_border, bar_fill, percentage_label]:
		if node and node is CanvasItem:
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	if max_health <= 0:
		max_health = 1
	_update_bar(current_health, max_health)

func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	_update_ammo_label(current_ammo, max_ammo)

func _update_bar(current_health: int, max_health: int) -> void:
	var ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	if max_bar_width <= 0.0:
		max_bar_width = _calculate_max_width()
	bar_fill.size = Vector2(max_bar_width * ratio, bar_fill.size.y)
	bar_fill.visible = ratio > 0.0
	percentage_label.text = "%d%%" % int(round(ratio * 100.0))

func _update_ammo_label(current_ammo: int, max_ammo: int) -> void:
	if ammo_label == null:
		return
	var max_value: int = max(max_ammo, 0)
	var current_value: int = clampi(current_ammo, 0, max_value if max_value > 0 else 999)
	ammo_label.text = "Ammo: %d/%d" % [current_value, max_value]
	ammo_label.modulate = Color.WHITE if current_value > 0 else Color(1, 0.4, 0.4, 1)

func _calculate_max_width() -> float:
	var width := bar_fill.size.x
	if width <= 0.0:
		width = bar_fill.get_minimum_size().x
	if width <= 0.0 and bar_border:
		width = max(bar_border.size.x - 4.0, 0.0)
	if width <= 0.0:
		width = 100.0
	return width

func _show_instructions() -> void:
	if instructions_panel == null or _instructions_hidden:
		return
	instructions_panel.visible = true
	var tree := get_tree()
	if tree:
		_instruction_timer = tree.create_timer(INSTRUCTION_AUTO_HIDE_TIME)
		_instruction_timer.timeout.connect(_on_instruction_timeout)

func _on_instruction_timeout() -> void:
	_hide_instructions()

func _hide_instructions() -> void:
	if _instructions_hidden:
		return
	_instructions_hidden = true
	if instructions_panel:
		instructions_panel.visible = false
	_instruction_timer = null

func _unhandled_input(event: InputEvent) -> void:
	if _instructions_hidden:
		return
	if event is InputEventMouseButton and event.pressed:
		_hide_instructions()
	elif event is InputEventKey and event.pressed and not event.echo:
		_hide_instructions()
	elif event is InputEventJoypadButton and event.pressed:
		_hide_instructions()
