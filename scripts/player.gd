extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

@export var max_health := 100
var health: int = 0
var is_dead := false

@onready var anim = $AnimatedSprite2D  # adjust if your node name is different

func _ready() -> void:
	is_dead = false
	set_physics_process(true)
	health = max_health
	_emit_health_changed()

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

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = max(health - amount, 0)
	if health == 0:
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
