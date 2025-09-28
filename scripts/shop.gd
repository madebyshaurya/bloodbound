extends Sprite2D

const LAYER_GROUND_INDEX := 1
const LAYER_INTERACT_INDEX := 2
const SHOP_MENU_GROUP := "shop_menu"

@onready var area: Area2D = $Area2D
var _active_player: Node2D
var _shop_menu: Node

func _ready() -> void:
	if not area:
		push_warning("Shop area missing; interactions disabled")
		return
	set_physics_process(false)
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_layer_value(LAYER_INTERACT_INDEX, true)
	area.set_collision_mask_value(LAYER_GROUND_INDEX, false)
	area.set_collision_mask_value(LAYER_INTERACT_INDEX, true)
	if not area.body_entered.is_connected(_on_area_2d_body_entered):
		area.body_entered.connect(_on_area_2d_body_entered)
	if not area.body_exited.is_connected(_on_area_2d_body_exited):
		area.body_exited.connect(_on_area_2d_body_exited)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if not body.has_method("purchase_shop_upgrade"):
		return
	_active_player = body
	var menu := _get_shop_menu()
	if menu and menu.has_method("open_shop"):
		menu.call("open_shop", body)
	else:
		push_warning("Shop UI not found in scene tree.")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == null or body != _active_player:
		return
	var menu := _get_shop_menu()
	if menu and menu.has_method("close_shop"):
		menu.call("close_shop", body)
	_active_player = null

func _get_shop_menu() -> Node:
	if _shop_menu and is_instance_valid(_shop_menu):
		return _shop_menu
	_shop_menu = get_tree().get_first_node_in_group(SHOP_MENU_GROUP)
	return _shop_menu
