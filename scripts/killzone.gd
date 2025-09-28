extends Area2D

@onready var timer: Timer = $Timer
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var bw_overlay: ColorRect = $"../PostFX/BWOverlay"

var bw_tween: Tween

func _set_bw_strength(value: float) -> void:
	if not bw_overlay:
		return
	bw_overlay.visible = value > 0.001
	if bw_overlay.material is ShaderMaterial:
		var mat: ShaderMaterial = bw_overlay.material
		mat.set_shader_parameter("strength", clampf(value, 0.0, 1.0))

func _on_body_entered(body: Node2D) -> void:
	print("You Died.")
	if body.has_method("die"):
		body.die()
	if death_sound.stream:
		death_sound.play()
		
	if bw_tween:
		bw_tween.kill()
	_set_bw_strength(0.0)
	if bw_overlay.material is ShaderMaterial:
		bw_tween = create_tween()
		bw_tween.tween_method(_set_bw_strength, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	Engine.time_scale = 0.5
	body.get_node("CollisionShape2D").queue_free()
	timer.start()


func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	if bw_tween:
		bw_tween.kill()
	_set_bw_strength(0.0)
	get_tree().reload_current_scene()
