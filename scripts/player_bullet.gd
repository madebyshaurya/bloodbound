extends Area2D
class_name PlayerBullet
	
@export var speed: float = 520.0
@export var max_distance: float = 200.0
@export var damage: int = 10
@export var radius: float = 1.5
@export var spawn_y_offset_range: Vector2 = Vector2(30, 35)

var direction: Vector2 = Vector2.RIGHT
var travelled: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if collision_shape and collision_shape.shape is CircleShape2D:
		var shape := collision_shape.shape as CircleShape2D
		shape.radius = radius
	queue_redraw()
	set_physics_process(true)

func launch(from_position: Vector2, dir: Vector2) -> void:
	var spawn_pos := from_position
	if spawn_y_offset_range != Vector2.ZERO:
		var min_y := minf(spawn_y_offset_range.x, spawn_y_offset_range.y)
		var max_y := maxf(spawn_y_offset_range.x, spawn_y_offset_range.y)
		if min_y != 0.0 or max_y != 0.0:
			spawn_pos.y += randf_range(min_y, max_y)
	global_position = spawn_pos
	if dir.length_squared() > 0.0001:
		direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	global_position += direction * step
	travelled += step
	if travelled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == null or body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color.WHITE)
