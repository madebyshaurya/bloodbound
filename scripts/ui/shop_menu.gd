extends CanvasLayer

const ABILITY_VIEW := "view"
const ABILITY_JUMP := "jump"
const ABILITY_SPEED := "speed"

const MESSAGE_DEFAULT := "Trade health for forbidden power."
const MESSAGE_NOT_ENOUGH := "You lack the blood to pay this price."
const MESSAGE_OWNED := "Already etched into your veins."
const MESSAGE_PURCHASED := "The pact is sealed."

var panel: PanelContainer
var hp_label: Label
var message_label: Label
var close_button: Button
var view_button: Button
var jump_button: Button
var speed_button: Button
var view_description: Label
var jump_description: Label
var speed_description: Label

var player: Node
var is_open := false
var abilities := {}

func _ready() -> void:
	add_to_group("shop_menu")
	set_process_unhandled_input(true)
	panel = get_node_or_null("Panel")
	hp_label = get_node_or_null("Panel/Margin/VBox/HpLabel")
	message_label = get_node_or_null("Panel/Margin/VBox/MessageLabel")
	close_button = get_node_or_null("Panel/Margin/VBox/CloseButton")
	view_button = get_node_or_null("Panel/Margin/VBox/Abilities/ViewRow/ViewButton")
	jump_button = get_node_or_null("Panel/Margin/VBox/Abilities/JumpRow/JumpButton")
	speed_button = get_node_or_null("Panel/Margin/VBox/Abilities/SpeedRow/SpeedButton")
	view_description = get_node_or_null("Panel/Margin/VBox/Abilities/ViewRow/ViewDescription")
	jump_description = get_node_or_null("Panel/Margin/VBox/Abilities/JumpRow/JumpDescription")
	speed_description = get_node_or_null("Panel/Margin/VBox/Abilities/SpeedRow/SpeedDescription")
	if panel == null:
		push_warning("ShopMenu panel not found; UI disabled.")
		return
	panel.visible = false
	if message_label:
		message_label.text = MESSAGE_DEFAULT
	abilities = {
		ABILITY_VIEW: {
			"name": "Widen Sight",
			"cost": 10,
			"button": view_button,
			"description": view_description
		},
		ABILITY_JUMP: {
			"name": "High Leap",
			"cost": 20,
			"button": jump_button,
			"description": jump_description
		},
		ABILITY_SPEED: {
			"name": "Swift Steps",
			"cost": 15,
			"button": speed_button,
			"description": speed_description
		}
	}
	if view_button:
		view_button.pressed.connect(func(): _attempt_purchase(ABILITY_VIEW))
	if jump_button:
		jump_button.pressed.connect(func(): _attempt_purchase(ABILITY_JUMP))
	if speed_button:
		speed_button.pressed.connect(func(): _attempt_purchase(ABILITY_SPEED))
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	_update_descriptions()

func open_shop(target_player: Node) -> void:
	if panel == null:
		push_warning("Shop UI unavailable; panel missing.")
		return
	if player != target_player:
		_disconnect_player()
	player = target_player
	if player and player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed, CONNECT_REFERENCE_COUNTED)
	panel.visible = true
	is_open = true
	if message_label:
		message_label.text = MESSAGE_DEFAULT
	_update_buttons()
	_focus_default()

func close_shop(leaving_player: Node = null) -> void:
	if leaving_player and leaving_player != player:
		return
	_disconnect_player()
	if panel:
		panel.visible = false
	is_open = false
	if message_label:
		message_label.text = MESSAGE_DEFAULT

func _disconnect_player() -> void:
	if player and player.has_signal("health_changed") and player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.disconnect(_on_player_health_changed)
	player = null

func _attempt_purchase(ability_id: String) -> void:
	if not is_open:
		return
	if not player:
		message_label.text = "No hunter to bargain with."
		return
	if not player.has_method("purchase_shop_upgrade") or not player.has_method("has_shop_upgrade") or not player.has_method("can_spend_health"):
		message_label.text = "This vessel cannot contain our wares."
		return
	var data = abilities.get(ability_id)
	if data == null:
		return
	if player.has_shop_upgrade(ability_id):
		message_label.text = MESSAGE_OWNED
		return
	var cost: int = data.get("cost", 0)
	if not player.can_spend_health(cost):
		message_label.text = MESSAGE_NOT_ENOUGH
		return
	if player.purchase_shop_upgrade(ability_id, cost):
		message_label.text = MESSAGE_PURCHASED
		_update_buttons()
	else:
		message_label.text = "The bargain failed."

func _update_buttons() -> void:
	var current_health := 0
	var max_health := 0
	if player and player.has_method("get"):
		current_health = int(player.get("health"))
		max_health = int(player.get("max_health"))
	if hp_label:
		hp_label.text = "Health: %d / %d" % [current_health, max_health]
	for ability_id in abilities.keys():
		var entry = abilities[ability_id]
		var button: Button = entry["button"]
		if button == null:
			continue
		var cost: int = entry.get("cost", 0)
		var label_text: String = entry.get("name", ability_id.capitalize())
		var owned: bool = player != null and player.has_method("has_shop_upgrade") and player.has_shop_upgrade(ability_id)
		if owned:
			button.text = "%s (Owned)" % label_text
			button.disabled = true
		else:
			button.text = "%s (-%d HP)" % [label_text, cost]
			button.disabled = not player or not player.can_spend_health(cost)

func _update_descriptions() -> void:
	if view_description:
		view_description.text = "Widen your view of the battlefield."
	if jump_description:
		jump_description.text = "Launch higher for safer traversal."
	if speed_description:
		speed_description.text = "Run faster to outmaneuver foes."

func _on_player_health_changed(_current_health: int, _max_health: int) -> void:
	_update_buttons()

func _on_close_pressed() -> void:
	close_shop()

func _focus_default() -> void:
	if view_button and not view_button.disabled:
		view_button.grab_focus()
	elif jump_button and not jump_button.disabled:
		jump_button.grab_focus()
	elif speed_button:
		speed_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
