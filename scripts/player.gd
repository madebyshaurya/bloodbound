extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal ammo_changed(current_ammo: int, max_ammo: int)

const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const CAMERA_DEFAULT_ZOOM := Vector2(5, 5)
const IDLE_VARIANT_DELAY := 4.0
const WALK_STOP_THRESHOLD := 5.0
const RUN_SPEED_THRESHOLD := SPEED + 1.0
const HURT_LOCK_TIME := 0.25
const RECHARGE_LOCK_TIME := 0.35

const LAYER_GROUND_INDEX := 1
const LAYER_INTERACT_INDEX := 2
const LAYER_GROUND := 1 << (LAYER_GROUND_INDEX - 1)
const LAYER_INTERACT := 1 << (LAYER_INTERACT_INDEX - 1)

const SHOP_ABILITY_VIEW := "view"
const SHOP_ABILITY_JUMP := "jump"
const SHOP_ABILITY_SPEED := "speed"
const SHOP_MAX_LEVEL := 5
const SPEED_UPGRADE_STEP := 0.12
const JUMP_UPGRADE_STEP := 0.1
const VIEW_ZOOM_LEVELS := [
	Vector2(5, 5),
	Vector2(4.5, 4.5),
	Vector2(4.0, 4.0),
	Vector2(3.5, 3.5),
	Vector2(3.2, 3.2),
	Vector2(3.0, 3.0)
]

const HAZARD_TILES := [
	{"source": 0, "atlas": Vector2i(5, 0)}
]

@export var max_health := 100
@export var bullet_scene: PackedScene = preload("res://scenes/player_bullet.tscn")
@export var shoot_cooldown: float = 0.35
@export var shoot_spawn_offset := Vector2(28, -12)
@export var max_ammo := 10
var health: int = 0
var is_dead := false

@onready var anim = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = get_node_or_null("Camera2D")

var tilemap: TileMapLayer
var killzone_area: Node
var speed := SPEED
var jump_velocity := JUMP_VELOCITY
var purchased_upgrades: Dictionary = {}
var current_animation := ""
var locked_animation := ""
var animation_lock_timer := 0.0
var animation_lock_waits_for_finish := false
var idle_time := 0.0
var idle_variant_active := false
var shoot_timer: float = 0.0
var facing_direction_sign: int = 1
var ammo: int = 0

func _ready() -> void:
	is_dead = false
	set_physics_process(true)
	if not is_in_group("player"):
		add_to_group("player")
	speed = SPEED
	jump_velocity = JUMP_VELOCITY
	purchased_upgrades = {
		SHOP_ABILITY_VIEW: 0,
		SHOP_ABILITY_JUMP: 0,
		SHOP_ABILITY_SPEED: 0
	}
	health = max_health
	tilemap = _find_tilemap()
	killzone_area = _find_killzone()
	_ensure_collision_layers()
	if camera:
		camera.zoom = CAMERA_DEFAULT_ZOOM
	current_animation = anim.animation if anim else ""
	locked_animation = ""
	idle_time = 0.0
	idle_variant_active = false
	animation_lock_timer = 0.0
	animation_lock_waits_for_finish = false
	shoot_timer = 0.0
	facing_direction_sign = 1
	ammo = max_ammo
	if anim:
		var frames: SpriteFrames = anim.sprite_frames
		if frames:
			for name in ["attack1", "die", "hurt", "idle2", "recharge", "shoot"]:
				if frames.has_animation(name):
					frames.set_animation_loop(name, false)
		if not anim.animation_finished.is_connected(_on_animation_finished):
			anim.animation_finished.connect(_on_animation_finished)
	if GameState.has_saved_state():
		GameState.apply_to_player(self)
	else:
		_emit_health_changed()
	_recalculate_upgrades()
	_emit_ammo_changed()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	shoot_timer = max(shoot_timer - delta, 0.0)
	_update_animation_lock(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		_cancel_idle_variant()
		if locked_animation == "":
			_play_anim("jump", true)
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * speed
		if anim:
			anim.flip_h = direction < 0
		facing_direction_sign = int(sign(direction))
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
	_update_animation_state(delta, direction)
	_handle_shoot_input()
	move_and_slide()
	_check_hazard_tiles()

func _update_animation_state(delta: float, direction: float) -> void:
	if locked_animation != "":
		return
	if not is_on_floor():
		_cancel_idle_variant(false)
		_play_anim("jump")
		return
	var horizontal_speed: float = absf(velocity.x)
	var is_moving: bool = direction != 0.0 or horizontal_speed > WALK_STOP_THRESHOLD
	if is_moving:
		_cancel_idle_variant()
		var target_animation := "walk"
		if horizontal_speed > RUN_SPEED_THRESHOLD:
			target_animation = "run"
		_play_anim(target_animation)
	else:
		_handle_idle_animation(delta)

func _update_animation_lock(delta: float) -> void:
	if locked_animation == "":
		animation_lock_timer = 0.0
		return
	if animation_lock_timer > 0.0:
		animation_lock_timer = max(animation_lock_timer - delta, 0.0)
		if animation_lock_timer == 0.0 and not animation_lock_waits_for_finish:
			locked_animation = ""
			animation_lock_waits_for_finish = false

func _handle_idle_animation(delta: float) -> void:
	idle_time += delta
	if idle_variant_active:
		return
	if idle_time >= IDLE_VARIANT_DELAY and anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle2"):
		idle_variant_active = true
		_play_anim("idle2", true)
	else:
		_play_anim("idle")

func _cancel_idle_variant(reset_timer: bool = true) -> void:
	if idle_variant_active and current_animation == "idle2" and anim:
		anim.stop()
	idle_variant_active = false
	if reset_timer:
		idle_time = 0.0

func _play_anim(name: String, force: bool = false) -> void:
	if not anim:
		return
	if anim.sprite_frames and not anim.sprite_frames.has_animation(name):
		return
	if not force and current_animation == name:
		return
	anim.play(name)
	current_animation = name

func _play_locked_animation(name: String, minimum_lock_time: float, wait_for_finish: bool) -> void:
	_cancel_idle_variant()
	locked_animation = name
	animation_lock_timer = max(minimum_lock_time, 0.0)
	animation_lock_waits_for_finish = wait_for_finish
	_play_anim(name, true)

func _play_hurt_animation() -> void:
	if is_dead:
		return
	_play_locked_animation("hurt", HURT_LOCK_TIME, false)

func _play_death_animation() -> void:
	_play_locked_animation("die", 0.0, true)

func _play_recharge_animation() -> void:
	if is_dead:
		return
	_play_locked_animation("recharge", RECHARGE_LOCK_TIME, false)

func play_shoot_animation(lock_time: float = 0.2) -> void:
	if is_dead:
		return
	_play_locked_animation("shoot", lock_time, false)

func _on_animation_finished(anim_name: StringName) -> void:
	var name := String(anim_name)
	if name == "idle2":
		idle_variant_active = false
		idle_time = 0.0
		if locked_animation == "":
			_play_anim("idle", true)
	if locked_animation != "" and name == locked_animation and animation_lock_waits_for_finish:
		locked_animation = ""
		animation_lock_waits_for_finish = false
		animation_lock_timer = 0.0

func _handle_shoot_input() -> void:
	if bullet_scene == null:
		return
	if ammo <= 0:
		return
	if shoot_timer > 0.0:
		return
	if locked_animation != "" and locked_animation != "shoot":
		return
	if not Input.is_action_just_pressed("player_shoot"):
		return
	var bullet_direction := Vector2(float(facing_direction_sign), 0.0)
	if bullet_direction == Vector2.ZERO:
		bullet_direction = Vector2.LEFT if anim and anim.flip_h else Vector2.RIGHT
	var spawn_position := _get_shoot_spawn_position()
	var parent_node := get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		return
	var bullet_instance := bullet_scene.instantiate()
	if bullet_instance == null:
		return
	parent_node.add_child(bullet_instance)
	if bullet_instance is PlayerBullet:
		bullet_instance.launch(spawn_position, bullet_direction)
	elif bullet_instance.has_method("launch"):
		bullet_instance.call("launch", spawn_position, bullet_direction)
	elif bullet_instance is Node2D:
		var bullet_node := bullet_instance as Node2D
		bullet_node.global_position = spawn_position
	shoot_timer = shoot_cooldown
	ammo = max(ammo - 1, 0)
	_emit_ammo_changed()
	play_shoot_animation()

func _get_shoot_spawn_position() -> Vector2:
	var offset := shoot_spawn_offset
	if facing_direction_sign < 0:
		offset.x = -offset.x
	return global_position + offset

func _check_hazard_tiles() -> void:
	if is_dead or not collision_shape:
		return
	if collision_shape.shape == null or tilemap == null:
		return
	var rect_shape := collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		return
	var half_extents := rect_shape.size * 0.5
	var center := collision_shape.global_position
	var padding := Vector2(1.5, 1.5)
	var min_point := center + Vector2(-half_extents.x, -half_extents.y) - padding
	var max_point := center + Vector2(half_extents.x, half_extents.y) + padding
	var map_min := tilemap.local_to_map(tilemap.to_local(min_point))
	var map_max := tilemap.local_to_map(tilemap.to_local(max_point))
	if map_min.x > map_max.x:
		var temp_x := map_min.x
		map_min.x = map_max.x
		map_max.x = temp_x
	if map_min.y > map_max.y:
		var temp_y := map_min.y
		map_min.y = map_max.y
		map_max.y = temp_y
	for x in range(map_min.x, map_max.x + 1):
		for y in range(map_min.y, map_max.y + 1):
			var cell := Vector2i(x, y)
			var source_id := tilemap.get_cell_source_id(cell)
			if source_id == -1:
				continue
			var atlas_coords := tilemap.get_cell_atlas_coords(cell)
			var alt := tilemap.get_cell_alternative_tile(cell)
			if _is_hazard_tile(source_id, atlas_coords, alt):
				if killzone_area and killzone_area.has_method("trigger_death"):
					killzone_area.call("trigger_death", self)
				else:
					die()
				return

func _is_hazard_tile(source_id: int, atlas_coords: Vector2i, alt: int) -> bool:
	for hazard in HAZARD_TILES:
		if hazard.get("source") == source_id and hazard.get("atlas") == atlas_coords:
			if not hazard.has("alts"):
				return true
			var allowed_alts = hazard["alts"]
			return alt in allowed_alts
	return false

func _find_tilemap() -> TileMapLayer:
	var current: Node = get_parent()
	while current:
		for child in current.get_children():
			if child is TileMapLayer:
				return child
		current = current.get_parent()
	return null

func _find_killzone() -> Node:
	var current: Node = get_parent()
	while current:
		for child in current.get_children():
			if child.has_method("trigger_death"):
				return child
		current = current.get_parent()
	return null

func is_alive() -> bool:
	return not is_dead

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = max(health - amount, 0)
	if health == 0:
		if killzone_area and killzone_area.has_method("trigger_death"):
			killzone_area.call("trigger_death", self)
		else:
			die()
	else:
		_play_hurt_animation()
		_emit_health_changed()

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = min(health + amount, max_health)
	if locked_animation == "" and is_on_floor() and abs(velocity.x) <= WALK_STOP_THRESHOLD:
		_play_recharge_animation()
	_emit_health_changed()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0
	_emit_health_changed()
	velocity = Vector2.ZERO
	_play_death_animation()
	set_physics_process(false)
	GameState.clear_state()

func _emit_health_changed() -> void:
	emit_signal("health_changed", health, max_health)

func _emit_ammo_changed() -> void:
	emit_signal("ammo_changed", ammo, max_ammo)

func can_spend_health(cost: int, keep_minimum: int = 1) -> bool:
	if is_dead or cost <= 0:
		return false
	var minimum: int = max(keep_minimum, 0)
	return health - cost >= minimum

func spend_health(cost: int, keep_minimum: int = 1) -> bool:
	if not can_spend_health(cost, keep_minimum):
		return false
	health -= cost
	_emit_health_changed()
	return true

func has_shop_upgrade(id: StringName) -> bool:
	return get_shop_upgrade_level(id) > 0

func get_shop_upgrade_level(id: StringName) -> int:
	var key := String(id)
	if not purchased_upgrades.has(key):
		return 0
	return int(purchased_upgrades[key])

func purchase_shop_upgrade(id: StringName, cost: int, max_level: int = SHOP_MAX_LEVEL) -> bool:
	var key := String(id)
	var current_level := get_shop_upgrade_level(id)
	if current_level >= max_level:
		return false
	if not spend_health(cost):
		return false
	purchased_upgrades[key] = current_level + 1
	_recalculate_upgrades()
	return true

func _recalculate_upgrades() -> void:
	var speed_level := get_shop_upgrade_level(SHOP_ABILITY_SPEED)
	speed = SPEED * (1.0 + float(speed_level) * SPEED_UPGRADE_STEP)
	var jump_level := get_shop_upgrade_level(SHOP_ABILITY_JUMP)
	jump_velocity = JUMP_VELOCITY * (1.0 + float(jump_level) * JUMP_UPGRADE_STEP)
	if camera:
		var view_level: int = clampi(get_shop_upgrade_level(SHOP_ABILITY_VIEW), 0, VIEW_ZOOM_LEVELS.size() - 1)
		camera.zoom = VIEW_ZOOM_LEVELS[view_level]

func _ensure_collision_layers() -> void:
	var required_layers := LAYER_GROUND | LAYER_INTERACT
	collision_layer |= required_layers
	collision_mask |= required_layers
	set_collision_layer_value(LAYER_GROUND_INDEX, true)
	set_collision_layer_value(LAYER_INTERACT_INDEX, true)
	set_collision_mask_value(LAYER_GROUND_INDEX, true)
	set_collision_mask_value(LAYER_INTERACT_INDEX, true)

func export_state() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"purchased_upgrades": purchased_upgrades.duplicate(true),
		"max_ammo": max_ammo,
		"ammo": ammo
	}

func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	max_health = int(state.get("max_health", max_health))
	health = clamp(int(state.get("health", max_health)), 0, max_health)
	max_ammo = max(int(state.get("max_ammo", max_ammo)), 1)
	ammo = clamp(int(state.get("ammo", max_ammo)), 0, max_ammo)
	speed = SPEED
	jump_velocity = JUMP_VELOCITY
	if camera:
		camera.zoom = CAMERA_DEFAULT_ZOOM
	purchased_upgrades.clear()
	purchased_upgrades[SHOP_ABILITY_VIEW] = 0
	purchased_upgrades[SHOP_ABILITY_JUMP] = 0
	purchased_upgrades[SHOP_ABILITY_SPEED] = 0
	var saved_upgrades_variant: Variant = state.get("purchased_upgrades", {})
	if saved_upgrades_variant is Dictionary:
		var saved_upgrades: Dictionary = saved_upgrades_variant as Dictionary
		for ability_variant in saved_upgrades.keys():
			var key := String(ability_variant)
			var level_value: int = int(saved_upgrades.get(ability_variant, 0))
			var level: int = clampi(level_value, 0, SHOP_MAX_LEVEL)
			purchased_upgrades[key] = level
	_recalculate_upgrades()
	_emit_health_changed()
	_emit_ammo_changed()
