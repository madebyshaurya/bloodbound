extends Node2D

@export var damage: int = 10

@onready var damage_area: Area2D = $DamageArea

func _ready() -> void:
	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)

func _on_damage_area_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
