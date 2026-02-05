extends CharacterBody3D


## Movement Variables
@export var speed := 3.0
@export var speed_modifier := 1.0
@export var jump_force := 4.0
@export var gravity := -9.8
var target_velocity = Vector3.ZERO
var stopped = true
var running = false
var jumping = false
var falling = false
var blockMovement = false
var jump_tween: Tween = null

@onready var anim_tree = %AnimationPlayer

## Step Variables
const MAX_STEP_HEIGHT = 0.5
var _snapped_to_stair_last_frame := false
var _last_frame_was_on_floor = -INF

## Equipment Variables
@export var equipment := [null, null, null]
var equipmentIndice = -1
var equipped_weapon: Node3D = null
var sword_offset: Transform3D
var equip_tween: Tween = null

var attacking = false
var preparedAttack = false
var comboAttack = false
var attack_tween: Tween = null


func _ready():
	add_to_group("Player")
	$AnimationTree.active = true
	$AnimationPlayer.animation_finished.connect(Callable(self, "_on_animation_tree_animation_finished"))
	sword_offset = %HandBone.global_transform.affine_inverse() * %HandPivot.global_transform


func getHeight():
	var capsule = %CollisionWorld.shape
	return capsule.height + capsule.radius



func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _run_body_test_motion(from : Transform3D, motion : Vector3, result = null) -> bool:
	if not result: 
		result = PhysicsTestMotionResult3D.new()
		
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var floor_below : bool = %StairBelowRayCast3D.is_colliding() and not is_surface_too_steep(%StairBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stair_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			var translate_y = body_test_result.get_travel().y
			self.global_position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stair_last_frame = did_snap

func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stair_last_frame: return false
	
	var expected_move_motion = self.velocity * Vector3(1, 0, 1) * delta

	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT*2, 0))

	var down_check_result = PhysicsTestMotionResult3D.new()
	
	if (_run_body_test_motion(step_pos_with_clearance, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result) 
		and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
			var step_height = (step_pos_with_clearance.origin + down_check_result.get_travel()).y - self.global_position.y
			
			if step_height > MAX_STEP_HEIGHT or step_height < 0.01 or down_check_result.get_collision_point().y - self.global_position.y > MAX_STEP_HEIGHT: return false
			
			%StairAheadRayCast3D.global_position = down_check_result.get_collision_point() + Vector3(0, MAX_STEP_HEIGHT, 0) + expected_move_motion.normalized() * 0.1
			%StairAheadRayCast3D.force_raycast_update()
			
			if %StairAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairAheadRayCast3D.get_collision_normal()):
				self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
				apply_floor_snap()
				_snapped_to_stair_last_frame = true
				return true
	return false

func on_equip_tween_finished():
	equip_tween = create_tween()
	equip_tween.tween_property($AnimationTree, "parameters/WeaponBlend/blend_amount", 0.0,0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func weaponVisibility(visibility: bool):
	equipped_weapon.setVisibility(visibility)
	
func handleEquipment() -> void:
	if equip_tween != null and equip_tween.is_running():
		equip_tween.kill()
		$AnimationTree.set("parameters/WeaponBlend/blend_amount", 0.0)
	
	equipmentIndice += 1
	if equipmentIndice >= equipment.size():
		equipmentIndice = 0
	
	var weaponPath = equipment[equipmentIndice]
	var weaponEquip_node
	
	if equipped_weapon != null and weaponPath == null:
			weaponEquip_node = $%AnimationTree.tree_root.get_node("weaponEquip")
			weaponEquip_node.animation = equipped_weapon.getSheath()
			
			$AnimationTree.set("parameters/weaponEquipSeek/seek_request", 0.0)
		
			equip_tween = create_tween()
			equip_tween.tween_property($AnimationTree, "parameters/WeaponBlend/blend_amount", 1.0,0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await equip_tween.finished
			on_equip_tween_finished()
			
			equipped_weapon.queue_free()
			equipped_weapon = null
			return
	
	if weaponPath != null:
		if equipped_weapon != null:
			equipped_weapon.queue_free()
			equipped_weapon = null
		
		var weapon_scene = load(weaponPath)
		var weapon = weapon_scene.instantiate()
		weapon.inject_animations_into(self)
		%HandPivot.add_child(weapon)
		equipped_weapon = weapon
			
		weaponEquip_node = $%AnimationTree.tree_root.get_node("weaponEquip")
		weaponEquip_node.animation = equipped_weapon.getWithdraw()
		
		$AnimationTree.set("parameters/weaponEquipSeek/seek_request", 0.0)
		
		equip_tween = create_tween()
		equip_tween.tween_property($AnimationTree, "parameters/WeaponBlend/blend_amount", 1.0,0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await equip_tween.finished
		on_equip_tween_finished()
	return

func handleAttack() -> void:
	if preparedAttack:
		return
	
	preparedAttack = true
	attacking = true
	
	var attack_tuple = equipped_weapon.getNextAttack()
	var attack_name = attack_tuple[0]
	var attack_time = attack_tuple[1]
	
	var attack_node = $AnimationTree.tree_root.get_node("attack1")  # AnimationNodeAnimation
	attack_node.animation = attack_name
	
	$AnimationTree.set("parameters/attackTimed1/seek_request", attack_time)
	
	
	# Tween blend
	attack_tween = create_tween()
	attack_tween.tween_property($AnimationTree,"parameters/StartAttack/blend_amount",1.0,0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func handleCombo() -> void:
	if comboAttack:
		preparedAttack = false
		comboAttack = false
		
		var attack_node1 = $AnimationTree.tree_root.get_node("attack1")  # AnimationNodeAnimation
		var current_time = $AnimationTree.get("parameters/attack1/current_position")
		var attack_node2 = $AnimationTree.tree_root.get_node("attack2")  # AnimationNodeAnimation
		attack_node2.animation = attack_node1.animation
		$AnimationTree.set("parameters/attackTimed2/seek_request", current_time)
		
		var combo_tween = create_tween()
		$AnimationTree.set("parameters/ComboBlend/blend_amount", 0.0)
		combo_tween.tween_property(%AnimationTree,"parameters/ComboBlend/blend_amount",1.0,0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		handleAttack()

func handleJump() -> void:
	blockMovement = false
	target_velocity.y = jump_force
	
func handleFall() -> void:
	jumping = false
	blockMovement = false
	jump_tween = create_tween()
	jump_tween.tween_property(%AnimationTree, "parameters/AirBlend/blend_amount", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
func handleMovementGround(_delta) -> void:
	var direction = Vector3.ZERO
	var move_direction = Vector3.ZERO
	
	
	if Input.is_action_pressed("move_forward"):
		direction.z -= 1
	if Input.is_action_pressed("move_back"):
		direction.z += 1
	if Input.is_action_pressed("move_left"):
		direction.x += 1
	if Input.is_action_pressed("move_right"):
		direction.x -= 1
	if Input.is_action_just_pressed("jump") and is_on_floor() and jumping == false:
		jumping = true
		blockMovement = true
		jump_tween = create_tween()
		%AnimationTree.set("parameters/AirSeek/seek_request", 0.0)
		%AnimationTree.set("parameters/AirMovement/blend_position", -1.0)
		jump_tween.tween_property(%AnimationTree, "parameters/AirBlend/blend_amount", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		
	
	if direction != Vector3.ZERO:
		if running:
			var current = %AnimationTree.get("parameters/RunBlend/blend_amount")
			var target = 1.0
			var smoothed = lerp(current,target, 0.2) # adjust 0.1 → 0.2 for faster response
			%AnimationTree.set("parameters/RunBlend/blend_amount", smoothed)
		else:
			var currentRun = %AnimationTree.get("parameters/RunBlend/blend_amount")
			var targetRun = 0.0
			var smoothedRun = lerp(currentRun,targetRun, 0.2) # adjust 0.1 → 0.2 for faster response
			%AnimationTree.set("parameters/RunBlend/blend_amount", smoothedRun)
			
			var normDir = direction.normalized()
			if normDir.z == -1:
				speed_modifier = 0.5
				%AnimationTree.set("parameters/Speed/scale", 1.75*speed_modifier)
			elif normDir.z == 1:
				speed_modifier = 0.5
				%AnimationTree.set("parameters/Speed/scale", 5*speed_modifier)
			elif normDir.z < 0 or normDir.z > 0:
				speed_modifier = 0.5
				%AnimationTree.set("parameters/Speed/scale", 5*speed_modifier)
			else:
				speed_modifier = 0.5
				%AnimationTree.set("parameters/Speed/scale", (1/0.275)*speed_modifier)
			
			var current = %AnimationTree.get("parameters/WalkBlend/blend_position")
			var target = Vector2(-direction.z, direction.x)
			var smoothed = current.lerp(target, 0.1) # adjust 0.1 → 0.2 for faster response
			%AnimationTree.set("parameters/WalkBlend/blend_position", smoothed)

		var cam_transform = %SpringArm3D.global_transform.basis
		var forward = cam_transform.z
		forward.y = 0
		forward = forward.normalized()
		var right = forward.cross(Vector3.UP).normalized()

		move_direction = (forward * direction.z + right * direction.x).normalized()
		move_direction.y = 0

		%StairAheadRayCast3D.global_position = self.global_position + move_direction * 0.75
		%StairAheadRayCast3D.global_position.y = MAX_STEP_HEIGHT + MAX_STEP_HEIGHT * 0.1 + self.global_position.y
		%StairAheadRayCast3D.force_raycast_update()

		stopped = false
	else:
		speed_modifier = 1.0
		
		var currentR = %AnimationTree.get("parameters/RunBlend/blend_amount")
		var targetR = 0.0
		var smoothedR = lerp(currentR,targetR, 0.2) # adjust 0.1 → 0.2 for faster response
		%AnimationTree.set("parameters/RunBlend/blend_amount", smoothedR)
		
		%AnimationTree.set("parameters/Speed/scale", 1.0)
		
		var current = %AnimationTree.get("parameters/WalkBlend/blend_position")
		var target = Vector2.ZERO
		var smoothed = current.lerp(target, 0.1)
		%AnimationTree.set("parameters/WalkBlend/blend_position", smoothed)

		stopped = true

			
	target_velocity.x = move_direction.x * speed * speed_modifier
	target_velocity.z = move_direction.z * speed * speed_modifier

func handleMovementAir(delta) -> void:
	if target_velocity.y < 0 and !falling:
		falling = true
		var tween = create_tween()
		tween.tween_property(%AnimationTree, "parameters/AirBlend/blend_amount", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		jump_tween = create_tween()
		jump_tween.tween_property(%AnimationTree, "parameters/AirMovement/blend_position", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	target_velocity.y += gravity * delta

func _physics_process(delta):
	var bone_xform = %HandBone.global_transform
	bone_xform.basis = bone_xform.basis.orthonormalized()

	%HandPivot.global_transform = bone_xform * sword_offset
	
	if is_on_floor() and !jumping:
		_last_frame_was_on_floor = Engine.get_physics_frames()
		velocity.y = 0
		target_velocity.y = 0
	if is_on_floor() and falling:
		falling = false
		jump_tween = create_tween()
		%AnimationTree.set("parameters/AirSeek/seek_request", 0.0)
		jump_tween.tween_property(%AnimationTree, "parameters/AirMovement/blend_position", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	if attacking:
		target_velocity = Vector3.ZERO
		handleAttack()
	
	if Input.is_action_just_pressed("Equip") and !attacking:
		handleEquipment()
	
	if Input.is_action_just_pressed("attack") and equipped_weapon != null:
		if is_on_floor():
			if attacking:
				comboAttack = true
			else:
				handleAttack()
			
	if Input.is_action_just_pressed("run"):
		running = true
		speed_modifier *= 2
	elif Input.is_action_just_released("run"):
		running = false
		speed_modifier /= 2
		
	if (is_on_floor() or _snapped_to_stair_last_frame) and !attacking:
		handleMovementGround(delta)
	else:
		handleMovementAir(delta)
	
	if blockMovement:
		target_velocity = Vector3.ZERO
		
	velocity = target_velocity
		
	if not _snap_up_stairs_check(delta):
		move_and_slide()
		_snap_down_to_stairs_check()

func activateAttack() -> void:
	equipped_weapon.changeActive(true)

func deactivateAttack() -> void:
	equipped_weapon.changeActive(false)

func attackFinished() -> void:
	attacking = false 
	preparedAttack = false
	comboAttack = false
	
	var tween = create_tween()
	tween.tween_property(%AnimationTree, "parameters/StartAttack/blend_amount", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	
	equipped_weapon.resetCombo()


func flipBlockMovement() -> void:
	blockMovement = !blockMovement
