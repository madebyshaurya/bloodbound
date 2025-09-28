extends CharacterBody2D
class_name SkeletonEnemy

enum State {
	PATROL,
	CHASE,
	ATTACK,
	DEAD
}

@export var patrol_speed: float = 40.0
@export var chase_speed: float = 70.0
@export var detection_range: float = 200.0
@export var chase_memory_time: float = 1.25
@export var attack_range: float = 34.0
@export var attack_height_tolerance: float = 28.0
@export var attack_cooldown: float = 1.1
@export var attack_damage: int = 15
@export var max_health: int = 60
@export var hurt_stun_time: float = 0.3
@export var edge_check_padding: float = 8.0
@export var edge_check_depth: float = 26.0
@export var gravity_override: float = -1.0

var state: State = State.PATROL
var facing_direction: int = -1
var health: int = 0
var attack_timer: float = 0.0
var chase_timer: float = 0.0
var hurt_timer: float = 0.0
var playing_attack: bool = false
var target_player: Node = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var health_bar: ProgressBar = null

var _gravity: float = 0.0

func _ready() -> void:
	health = max_health
	_gravity = gravity_override if gravity_override >= 0.0 else float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	add_to_group("enemies")
	_ensure_health_bar()
	_update_health_bar()
	if anim and not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)
	_play_anim("idle")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return
	attack_timer = max(attack_timer - delta, 0.0)
	chase_timer = max(chase_timer - delta, 0.0)
	hurt_timer = max(hurt_timer - delta, 0.0)
	_apply_gravity(delta)
	if hurt_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, chase_speed)
		move_and_slide()
		return
	if target_player == null or not _is_player_targetable(target_player):
		target_player = _acquire_player()
	if target_player:
		var to_player := target_player.global_position - global_position
		var horizontal_distance := absf(to_player.x)
		var vertical_distance := absf(to_player.y)
		if horizontal_distance <= detection_range and vertical_distance <= detection_range:
			chase_timer = chase_memory_time
		if chase_timer > 0.0:
			if horizontal_distance <= attack_range and vertical_distance <= attack_height_tolerance:
				_attempt_attack(target_player)
			else:
				_move_towards_player(to_player)
		else:
			_run_patrol()
	else:
		_run_patrol()
	move_and_slide()
	if state != State.DEAD and not playing_attack:
		if is_on_wall():
			_turn_around()
		elif not _has_floor_ahead(facing_direction):
			_turn_around()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

func _move_towards_player(direction: Vector2) -> void:
	if playing_attack:
		return
	var dir := 1 if direction.x > 0.0 else -1
	_set_facing(dir)
	if not _has_floor_ahead(dir):
		velocity.x = move_toward(velocity.x, 0.0, chase_speed)
		_play_anim("idle")
		return
	state = State.CHASE
	velocity.x = dir * chase_speed
	_play_anim("walk")

func _run_patrol() -> void:
	if playing_attack:
		return
	state = State.PATROL
	if not _has_floor_ahead(facing_direction):
		_turn_around()
	velocity.x = facing_direction * patrol_speed
	if absf(velocity.x) < 1.0:
		_play_anim("idle")
	else:
		_play_anim("walk")

func _attempt_attack(player: Node) -> void:
	if playing_attack or attack_timer > 0.0:
		return
	if not _is_player_targetable(player):
		return
	var dir := 1 if player.global_position.x > global_position.x else -1
	_set_facing(dir)
	velocity.x = 0.0
	state = State.ATTACK
	playing_attack = true
	attack_timer = attack_cooldown
	_play_attack_animation()
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return
	health = clamp(health - amount, 0, max_health)
	_update_health_bar()
	if health == 0:
		_die()
	else:
		hurt_timer = hurt_stun_time
		_play_anim("hurt", true)

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	playing_attack = false
	if collision_shape:
		collision_shape.disabled = true
	set_collision_layer(0)
	set_collision_mask(0)
	set_physics_process(false)
	_play_anim("dead", true)
	if health_bar:
		health_bar.visible = false

func _turn_around() -> void:
	if playing_attack:
		return
	_set_facing(-facing_direction)

func _set_facing(direction: int) -> void:
	var clamped := direction if direction != 0 else (facing_direction if facing_direction != 0 else 1)
	facing_direction = clamped
	if anim:
		anim.flip_h = facing_direction < 0

func _play_anim(name: String, force: bool = false) -> void:
	if not anim:
		return
	if anim.sprite_frames and not anim.sprite_frames.has_animation(name):
		return
	if not force and anim.animation == name and anim.is_playing():
		return
	anim.play(name)

func _play_attack_animation() -> void:
	if not anim:
		playing_attack = false
		return
	var target_animation := "attack1"
	if not anim.sprite_frames or not anim.sprite_frames.has_animation(target_animation):
		target_animation = anim.sprite_frames.get_animation_names()[0]
	_play_anim(target_animation, true)

func _on_animation_finished(anim_name: StringName) -> void:
	var name := String(anim_name)
	if state == State.DEAD and name == "dead":
		queue_free()
	elif playing_attack and (name.begins_with("attack")):
		playing_attack = false
		state = State.CHASE if chase_timer > 0.0 else State.PATROL
	elif name == "hurt" and state != State.DEAD:
		_play_anim("idle")

func _acquire_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if _is_player_targetable(p):
			return p
	return null

func _is_player_targetable(player: Node) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	if player.has_method("is_alive"):
		return player.is_alive()
	return true

func _has_floor_ahead(direction: int) -> bool:
	if direction == 0:
		return true
	var start := _edge_check_start(direction)
	var end := start + Vector2(0, edge_check_depth)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start, end)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	return not result.is_empty()

func _edge_check_start(direction: int) -> Vector2:
	var base_position := global_position
	if collision_shape:
		base_position = collision_shape.global_position
	var offset_x := direction * (_collision_half_width() + edge_check_padding)
	var offset_y := _collision_half_height() - 2.0
	return Vector2(base_position.x + offset_x, base_position.y + offset_y)

func _collision_half_width() -> float:
	if collision_shape and collision_shape.shape:
		var shape := collision_shape.shape
		if shape is RectangleShape2D:
			return (shape as RectangleShape2D).size.x * 0.5
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			return capsule.radius
		elif shape is CircleShape2D:
			return (shape as CircleShape2D).radius
		elif shape is RoundedRectangleShape2D:
			return (shape as RoundedRectangleShape2D).size.x * 0.5
	return 12.0

func _collision_half_height() -> float:
	if collision_shape and collision_shape.shape:
		var shape := collision_shape.shape
		if shape is RectangleShape2D:
			return (shape as RectangleShape2D).size.y * 0.5
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			return capsule.height * 0.5 + capsule.radius
		elif shape is CircleShape2D:
			return (shape as CircleShape2D).radius
		elif shape is RoundedRectangleShape2D:
			return (shape as RoundedRectangleShape2D).size.y * 0.5
	return 16.0

func _ensure_health_bar() -> void:
	health_bar = get_node_or_null("HealthBar")
	if health_bar == null:
		health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
	health_bar.position = Vector2(-24, -48)
	health_bar.size = Vector2(48, 6)
	health_bar.custom_minimum_size = Vector2(48, 6)
	health_bar.pivot_offset = Vector2.ZERO
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = max_health
	health_bar.step = 1
	health_bar.show_percentage = false
		health_bar.z_index = 5
		add_child(health_bar)
	if health_bar:
		health_bar.visible = true
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_health_bar() -> void:
	if not health_bar:
		return
	health_bar.max_value = max_health
	health_bar.value = health
