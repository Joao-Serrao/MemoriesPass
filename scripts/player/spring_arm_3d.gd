extends SpringArm3D

## Camera Controls
@export var sensitivity := 0.003
@export var max_zoom := 1
@export var min_zoom := 10
var rotation_x := 0.0
var rotation_y := 0.0
var zoom = 5

## Lock on Variables
var locked = null



func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



func disableLockOn(forward) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - locked.getHeight()/2, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	rotation_y = atan2(-forward.x, -forward.z)
	rotation_x = asin(forward.y)
	
	locked = null

func handleLockOn(player_pos, forward) -> void:
	if locked == null:
		var enemies = get_tree().get_nodes_in_group("VisibleCloseEnemies") 
		
		if !enemies.is_empty():
			var most_centered = null
			var best_score = -INF
			
			for enemy in enemies:
				var pos = enemy.global_position
				pos.y = 0
				
				var dir_to_enemy = (pos - player_pos).normalized()
				
				var dot = forward.dot(dir_to_enemy)
				var dist = player_pos.distance_to(pos)
				
				var score = dot - dist * 0.001
			
				if score > best_score:
					best_score = score
					most_centered = enemy
				
			if most_centered != null:
				locked = most_centered
				var tween = get_tree().create_tween()
				var posY = global_position.y + locked.getHeight()/2
				posY = min(posY, global_position.y + 3.0)
				
				tween.tween_property(self, "global_position:y", posY, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		disableLockOn(forward)

func handleChangeTarget(player_pos, forward) -> void:
	var enemies = get_tree().get_nodes_in_group("VisibleCloseEnemies")
	
	var left = null
	var leftScore = -INF
	var right = null
	var rightScore = -INF
	
	var up = Vector3.UP
	
	for enemy in enemies:
		if enemy == locked:
			continue
				
		var dist = player_pos.distance_to(enemy.global_position)
		
		var locked_vector = (locked.global_position - player_pos).normalized()
		var enemy_vector = (enemy.global_position - player_pos).normalized()
		var dot = forward.dot(enemy_vector)
		
		var cross = locked_vector.cross(enemy_vector)
		var side = cross.dot(up)
		
		var score = dot - dist * 0.001
		
		if side > 0:
			if score > leftScore:
				leftScore = score
				left = enemy
		elif side < 0:
			if score > rightScore:
				rightScore = score
				right = enemy
		else:
			if score > leftScore:
				leftScore = score
				left = enemy
			if score > rightScore:
				rightScore = score
				right = enemy
		
	var previousHeight = locked.getHeight()/2
	if Input.is_action_just_pressed("change_lock_left") and left != null:
		locked = left
	elif right != null:
		locked = right
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - previousHeight + locked.getHeight()/2, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func handleCameraPosition(delta, forward, player) -> void:
	if player != null:
		if locked != null:
			if locked.is_in_group("VisibleCloseEnemies"):
				var target_dir = (locked.global_position - global_position).normalized()
				
				var desired = Basis.looking_at(target_dir, Vector3.UP)
				
				var current_forward = -basis.z
				current_forward.y = 0.0
				var desired_forward = -desired.z
				
				var angle = current_forward.angle_to(desired_forward)
				
				var max_angle = deg_to_rad(45.0)
				
				if angle > max_angle:
					var t = max_angle / angle
					var clamped_forward = current_forward.slerp(desired_forward, t)
					desired = Basis.looking_at(clamped_forward, Vector3.UP)
				
				basis = basis.slerp(desired, delta * 5.0)
				
				if not player.running:
					target_dir.y = 0
					var modelDesired = Basis.looking_at(-target_dir, Vector3.UP)
					%Armature.basis = %Armature.basis.slerp(modelDesired, delta * 5.0)
			else:
				disableLockOn(forward)
		
		if not player.stopped:
			var dir = -basis.z
			if player.running:
				dir = player.velocity.normalized()
			dir.y = 0
				
			if dir != Vector3.ZERO:
				var desired = Transform3D().looking_at(-dir, Vector3.UP).basis
				%Armature.basis = %Armature.basis.slerp(desired, delta * 5.0)

func _process(delta):
	var player = get_tree().get_first_node_in_group("Player")
	var player_pos = player.global_position
	player_pos.y = 0
	
	var cam_transform = global_transform.basis
	var forward = -cam_transform.z.normalized()
	
	if Input.is_action_just_pressed("scrool_up"):
		zoom -= sensitivity * 100
		if zoom < max_zoom:
			zoom = max_zoom
	if Input.is_action_just_pressed("scrool_down"):
		zoom += sensitivity * 100
		if zoom > min_zoom:
			zoom = min_zoom
	
	if Input.is_action_just_pressed("lock_on"):
		handleLockOn(player_pos, forward)
	
	if (Input.is_action_just_pressed("change_lock_left") or Input.is_action_just_pressed("change_lock_right")) and locked != null:
		handleChangeTarget(player_pos, forward)
	
	handleCameraPosition(delta, forward, player)
			
	spring_length = zoom



func _unhandled_input(event):
	if event is InputEventMouseMotion and locked == null:
		rotation_y -= event.relative.x * sensitivity
		rotation_x -= event.relative.y * sensitivity
		rotation_x = clamp(rotation_x, deg_to_rad(-60), deg_to_rad(20))
	
		rotation = Vector3(rotation_x, rotation_y, 0)
