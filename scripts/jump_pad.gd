extends Area2D

@export var jump_force: float = -525.0
@export var reset_delay: float = 0.25

@onready var cooldown_timer: Timer = $CooldownTimer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true

func _on_body_entered(body: Node2D) -> void:
	if cooldown_timer.time_left > 0.0:
		return
	if not body is CharacterBody2D:
		return
	var player := body as CharacterBody2D
	player.velocity.y = jump_force
	if player.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
		sprite.play("jump")
	cooldown_timer.start(reset_delay)
