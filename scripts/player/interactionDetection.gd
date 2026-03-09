extends RayCast3D

@export var player : CharacterBody3D
@export var viewDistance := 2.0

@export var camera : Camera3D

func _process(delta: float) -> void:
	global_transform.basis = camera.global_transform.basis
	
	target_position = Vector3(0, 0, -viewDistance)

	
	if is_colliding():
		var hitObj = get_collider()
		
		if hitObj.has_method("activate") and Input.is_action_just_pressed("activate") and !(player.attacking or player.jumping or player.falling):
			hitObj.activate()
