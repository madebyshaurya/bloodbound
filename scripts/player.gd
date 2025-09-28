extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

const HAZARD_TILES := [
	{"source": 0, "atlas": Vector2i(5, 0)}
]

@export var max_health := 100
var health: int = 0
var is_dead := false

@onready var anim = $AnimatedSprite2D  # adjust if your node name is different
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var tilemap: TileMapLayer
var killzone_area: Node

func _ready() -> void:
	is_dead = false
	set_physics_process(true)
	health = max_health
	_emit_health_changed()
	tilemap = _find_tilemap()
	killzone_area = _find_killzone()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		anim.play("jump")

	# Handle horizontal movement
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		if is_on_floor():
			anim.play("run")
		# Flip sprite depending on direction
		anim.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			anim.play("idle")

	# If mid-air but not pressing jump, ensure "jump" anim stays
	if not is_on_floor() and anim.animation != "jump":
		anim.play("jump")

	move_and_slide()
	_check_hazard_tiles()

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
		_emit_health_changed()

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = min(health + amount, max_health)
	_emit_health_changed()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0
	_emit_health_changed()
	velocity = Vector2.ZERO
	set_physics_process(false)

func _emit_health_changed() -> void:
	emit_signal("health_changed", health, max_health)
