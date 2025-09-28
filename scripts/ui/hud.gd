extends CanvasLayer

@export var player_path: NodePath

@onready var bar_fill: ColorRect = %BarFill
@onready var bar_border: ColorRect = %BarBorder
@onready var percentage_label: Label = %PercentageLabel

var player: Node
var max_bar_width: float = 0.0

func _ready() -> void:
	player = get_node_or_null(player_path)
	max_bar_width = _calculate_max_width()
	_apply_pixel_filter()

	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			_on_player_health_changed(_get_player_health(), _get_player_max_health())
		else:
			push_warning("Player at %s does not emit health_changed" % player_path)
	else:
		push_warning("Player node not found for HUD at path %s" % player_path)

func _get_player_health() -> int:
	if player:
		return int(player.get("health"))
	return 0

func _get_player_max_health() -> int:
	if player:
		var value = int(player.get("max_health"))
		return value if value > 0 else 1
	return 1

func _apply_pixel_filter() -> void:
	for node in [bar_border, bar_fill, percentage_label]:
		if node and node is CanvasItem:
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	if max_health <= 0:
		max_health = 1
	_update_bar(current_health, max_health)

func _update_bar(current_health: int, max_health: int) -> void:
	var ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	if max_bar_width <= 0.0:
		max_bar_width = _calculate_max_width()
	bar_fill.size = Vector2(max_bar_width * ratio, bar_fill.size.y)
	bar_fill.visible = ratio > 0.0
	percentage_label.text = "%d%%" % int(round(ratio * 100.0))

func _calculate_max_width() -> float:
	var width := bar_fill.size.x
	if width <= 0.0:
		width = bar_fill.get_minimum_size().x
	if width <= 0.0 and bar_border:
		width = max(bar_border.size.x - 4.0, 0.0)
	if width <= 0.0:
		width = 100.0
	return width
