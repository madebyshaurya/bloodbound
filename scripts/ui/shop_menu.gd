extends CanvasLayer

const ABILITY_VIEW := "view"
const ABILITY_JUMP := "jump"
const ABILITY_SPEED := "speed"
const MAX_LEVEL := 5

const MESSAGE_DEFAULT := "Trade health for forbidden power."
const MESSAGE_NOT_ENOUGH := "You lack the blood to pay this price."
const MESSAGE_MAXED := "This rite is already mastered."
const MESSAGE_PURCHASED := "The pact is sealed."
const MESSAGE_NO_PLAYER := "No hunter to bargain with."
const MESSAGE_INVALID := "This vessel cannot contain our wares."
const MESSAGE_FAILED := "The bargain failed."

const ABILITIES := [
	{
		"id": ABILITY_VIEW,
		"name": "Widen Sight",
		"description": "Sharpen perception to see farther into the gloom.",
		"icon": preload("res://assets/shop_assets/eye.png"),
		"base_cost": 12,
		"cost_step": 8
	},
	{
		"id": ABILITY_JUMP,
		"name": "High Leap",
		"description": "Uncoil sinew and vault above lurking threats.",
		"icon": preload("res://assets/shop_assets/high_jump.png"),
		"base_cost": 18,
		"cost_step": 10
	},
	{
		"id": ABILITY_SPEED,
		"name": "Swift Steps",
		"description": "Let blood fire your stride for relentless pursuit.",
		"icon": preload("res://assets/shop_assets/fast.png"),
		"base_cost": 15,
		"cost_step": 9
	}
]

var player: Node
var is_open := false
var current_index: int = 0

var panel: PanelContainer
var hp_label: Label
var message_label: Label
var prev_button: Button
var next_button: Button
var ability_icon: TextureRect
var level_bar: ProgressBar
var ability_name_label: Label
var ability_description_label: Label
var ability_cost_label: Label
var buy_button: Button
var close_button: Button

func _ready() -> void:
	add_to_group("shop_menu")
	set_process_unhandled_input(true)
	panel = get_node_or_null("Panel")
	hp_label = get_node_or_null("Panel/Margin/VBox/HpLabel")
	message_label = get_node_or_null("Panel/Margin/VBox/MessageLabel")
	prev_button = get_node_or_null("Panel/Margin/VBox/Selector/NavigationRow/PrevButton")
	next_button = get_node_or_null("Panel/Margin/VBox/Selector/NavigationRow/NextButton")
	ability_icon = get_node_or_null("Panel/Margin/VBox/Selector/NavigationRow/IconContainer/AbilityIcon")
	level_bar = get_node_or_null("Panel/Margin/VBox/Selector/NavigationRow/IconContainer/LevelBar")
	ability_name_label = get_node_or_null("Panel/Margin/VBox/Selector/AbilityName")
	ability_description_label = get_node_or_null("Panel/Margin/VBox/Selector/AbilityDescription")
	ability_cost_label = get_node_or_null("Panel/Margin/VBox/Selector/CostLabel")
	buy_button = get_node_or_null("Panel/Margin/VBox/ButtonRow/BuyButton")
	close_button = get_node_or_null("Panel/Margin/VBox/ButtonRow/CloseButton")
	if panel == null:
		push_warning("Shop menu UI not found; panel is missing.")
		return
	panel.visible = false
	if ability_icon:
		ability_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if level_bar:
		level_bar.max_value = MAX_LEVEL
	if prev_button:
		prev_button.pressed.connect(func(): _change_selection(-1))
	if next_button:
		next_button.pressed.connect(func(): _change_selection(1))
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	_update_message(MESSAGE_DEFAULT)
	_refresh_ui()

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
	current_index = clamp(current_index, 0, ABILITIES.size() - 1)
	_update_message(MESSAGE_DEFAULT)
	_refresh_ui()
	_focus_default()

func close_shop(leaving_player: Node = null) -> void:
	if leaving_player and leaving_player != player:
		return
	_disconnect_player()
	if panel:
		panel.visible = false
	is_open = false
	_update_message(MESSAGE_DEFAULT)

func _disconnect_player() -> void:
	if player and player.has_signal("health_changed") and player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.disconnect(_on_player_health_changed)
	player = null

func _change_selection(delta: int) -> void:
	if ABILITIES.is_empty():
		return
	current_index = wrapi(current_index + delta, 0, ABILITIES.size())
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_open or panel == null:
		return
	_update_hp_label()
	_show_current_ability()

func _update_hp_label() -> void:
	if hp_label == null:
		return
	var current_health := 0
	var max_health := 0
	if player and player.has_method("get"):
		current_health = int(player.get("health"))
		max_health = int(player.get("max_health"))
	hp_label.text = "Health: %d / %d" % [current_health, max_health]

func _show_current_ability() -> void:
	if ABILITIES.is_empty():
		return
	var ability: Dictionary = ABILITIES[current_index]
	var ability_id: String = ability.get("id", "")
	var ability_name: String = ability.get("name", "Unknown")
	var description: String = ability.get("description", "")
	var icon: Texture2D = ability.get("icon") as Texture2D
	if ability_icon:
		ability_icon.texture = icon
	if ability_name_label:
		ability_name_label.text = ability_name
	if ability_description_label:
		ability_description_label.text = description
	var ability_name_id := StringName(ability_id)
	var level := _get_player_level(ability_name_id)
	if level_bar:
		level_bar.max_value = MAX_LEVEL
		level_bar.value = level
	var cost_text := ""
	if level >= MAX_LEVEL:
		cost_text = "Maxed out"
	else:
		var next_level := level + 1
		var cost := _get_cost_for_level(ability, next_level)
		cost_text = "Cost: -%d HP" % cost
	if ability_cost_label:
		ability_cost_label.text = cost_text
	if buy_button:
		if player == null or level >= MAX_LEVEL:
			buy_button.disabled = true
			buy_button.text = "Fully Empowered"
		else:
			var next_level := level + 1
			var cost := _get_cost_for_level(ability, next_level)
			buy_button.disabled = not player.can_spend_health(cost)
			buy_button.text = "Absorb Power"

func _on_buy_pressed() -> void:
	if not is_open:
		return
	if player == null:
		_update_message(MESSAGE_NO_PLAYER)
		return
	if not player.has_method("purchase_shop_upgrade") or not player.has_method("get_shop_upgrade_level") or not player.has_method("can_spend_health"):
		_update_message(MESSAGE_INVALID)
		return
	var ability: Dictionary = ABILITIES[current_index]
	var ability_id: String = ability.get("id", "")
	if ability_id.is_empty():
		_update_message(MESSAGE_INVALID)
		return
	var ability_name_id := StringName(ability_id)
	var level := _get_player_level(ability_name_id)
	if level >= MAX_LEVEL:
		_update_message(MESSAGE_MAXED)
		return
	var next_level := level + 1
	var cost := _get_cost_for_level(ability, next_level)
	if not player.can_spend_health(cost):
		_update_message(MESSAGE_NOT_ENOUGH)
		return
	if player.purchase_shop_upgrade(ability_name_id, cost, MAX_LEVEL):
		_update_message(MESSAGE_PURCHASED)
	else:
		_update_message(MESSAGE_FAILED)
	_refresh_ui()

func _get_cost_for_level(ability: Dictionary, level: int) -> int:
	var base_cost := int(ability.get("base_cost", 0))
	var step := int(ability.get("cost_step", 0))
	return base_cost + max(level - 1, 0) * step

func _get_player_level(ability_id: StringName) -> int:
	if player == null or not player.has_method("get_shop_upgrade_level"):
		return 0
	return int(player.get_shop_upgrade_level(ability_id))

func _on_player_health_changed(_current_health: int, _max_health: int) -> void:
	_refresh_ui()

func _on_close_pressed() -> void:
	close_shop()

func _focus_default() -> void:
	if buy_button and not buy_button.disabled:
		buy_button.grab_focus()
	elif prev_button:
		prev_button.grab_focus()

func _update_message(text: String) -> void:
	if message_label:
		message_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_left"):
		_change_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_change_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
