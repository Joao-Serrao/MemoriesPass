extends CharacterBody3D

@export var speed = 2.0
@export var max_distance_lock = 100
@export var give_up_time_chase = 5.0
@export var give_up_time_caution = 2.0
@export var give_up_time_stuck = 2.0  
@export var sight_range = 20.0
@export var fov_degrees = 90.0
@export var debug = false

@onready var player = null
@onready var playerVisibility = get_tree().get_first_node_in_group("Player")
@onready var height: float = $Pivot/enemyMesh.get_aabb().size.y
@onready var origin: Vector3 = self.global_position

enum State { IDLE, CAUTION, CHECKING, CHASING, RETURNING }
var state = State.IDLE
var previousState = State.IDLE

var health = 100
var onScreen = false

var caution_timer := 0.0
var checking_pos := Vector3.ZERO
var chase_timer := 0.0

var stuck_timer := 0.0
var last_position := Vector3.ZERO
var stuck_distance = 0.1 

func _physics_process(delta: float) -> void:
	if state != State.CHASING and playerVisibility:
		if can_see_player():
			previousState = state
			state = State.CHASING
			chase_timer = 0.0
			player = playerVisibility
	
	if state == State.CHASING or state == State.CHECKING or state == State.RETURNING:
		if global_position.distance_to(last_position) < stuck_distance:
			stuck_timer += delta
			if stuck_timer >= give_up_time_stuck:
				stuck_timer = 0.0
				previousState = state
				state = State.RETURNING
		else:
			stuck_timer = 0.0
		last_position = global_position
	
	match state:
		State.IDLE:
			$NavigationAgent3D.set_velocity(Vector3.ZERO)
			
		State.CAUTION:
			caution_timer += delta
			if caution_timer >= give_up_time_caution:
				caution_timer = 0.0
				previousState = state
				state = State.IDLE
		
		State.CHECKING:
			$NavigationAgent3D.set_target_position(checking_pos)
			
			var next_pos = $NavigationAgent3D.get_next_path_position()
			var new_velocity = (next_pos - global_position).normalized() * speed
			$NavigationAgent3D.set_velocity(new_velocity)
			
			if $NavigationAgent3D.is_target_reached() or self.global_position.is_equal_approx($NavigationAgent3D.get_final_position()):
				previousState = state
				state = State.RETURNING
		
		State.CHASING:
			$NavigationAgent3D.set_target_position(player.global_position)
			
			if not can_see_player() or !$NavigationAgent3D.is_target_reachable():
				chase_timer += delta
				if chase_timer >= give_up_time_chase:
					chase_timer = 0.0
					previousState = state
					state = State.RETURNING
					player = null
					return
			else:
				chase_timer = 0.0
			
			var next_pos = $NavigationAgent3D.get_next_path_position()
			var new_velocity = (next_pos - global_position).normalized() * speed
			$NavigationAgent3D.set_velocity(new_velocity)
					
		State.RETURNING:
			$NavigationAgent3D.set_target_position(origin)
			if $NavigationAgent3D.is_navigation_finished():
				previousState = state
				state = State.IDLE
				return
				
			var next_pos = $NavigationAgent3D.get_next_path_position()
			var new_velocity = (next_pos - global_position).normalized() * speed
			$NavigationAgent3D.set_velocity(new_velocity)


func can_see_player() -> bool:
	if not playerVisibility:
		return false
	
	var eye_pos = global_position + Vector3.UP * (height * 0.9)  
	var player_pos = playerVisibility.global_position + Vector3.UP * (height * 0.9)  
	
	var to_player = player_pos - eye_pos  
	var distance = to_player.length()
	
	if distance > sight_range:
		return false
	
	var forward = -global_transform.basis.z
	if debug:
		var half_fov = deg_to_rad(fov_degrees / 2.0)
		var left  = forward.rotated(Vector3.UP, half_fov)
		var right = forward.rotated(Vector3.UP, -half_fov)
		DebugDraw3D.draw_line(eye_pos, eye_pos + forward * sight_range, Color.GREEN, 0.1)
		DebugDraw3D.draw_line(eye_pos, eye_pos + left * sight_range, Color.YELLOW, 0.1)
		DebugDraw3D.draw_line(eye_pos, eye_pos + right * sight_range, Color.YELLOW, 0.1)
	
	var angle = rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > fov_degrees / 2.0:
		return false
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(eye_pos, player_pos)
	query.exclude = [self, playerVisibility]
	query.collision_mask = 1 << 2
	
	var result = space.intersect_ray(query)
	return result.is_empty()


func is_visible_to_player(target) -> bool:
	if playerVisibility:
		var space_state = get_world_3d().direct_space_state
		var from = playerVisibility.global_transform.origin + Vector3.UP * playerVisibility.getHeight()
		var to = target.global_transform.origin + Vector3.UP * 0.5

		var param = PhysicsRayQueryParameters3D.create(from, to)
		param.exclude = [playerVisibility, target]
		param.collision_mask = 1 << 2

		var result = space_state.intersect_ray(param)
		
		if result and result.collider != target:
			return false
		return true
	return false

func _on_visible_on_screen_notifier_3d_screen_entered():
	onScreen = true
	var player_pos = playerVisibility.global_position
	var pos = global_position
			
	if (pos.distance_to(player_pos) < max_distance_lock):
		add_to_group("VisibleCloseEnemies")

func _on_visible_on_screen_notifier_3d_screen_exited():
	onScreen = false
	remove_from_group("VisibleCloseEnemies")

func getHeight():
	return height

func takeDamage(damage):
	health -= damage
	if health <= 0:
		remove_from_group("VisibleCloseEnemies")
		$CheckVisibility.stop()
		$Death.start()

func setCaution(checkPos: Vector3) -> void:
	if state == State.CHECKING:
		checking_pos = checkPos
	elif state == State.CAUTION and caution_timer >= 0.25:
		checking_pos = checkPos
		previousState = state
		state = State.CHECKING
		caution_timer = 0.0
	elif state == State.IDLE or state == State.RETURNING:
		caution_timer = 0.0
		previousState = state
		state = State.CAUTION

func _on_timer_timeout() -> void:
	if playerVisibility:
		var player_pos = playerVisibility.global_position
		var pos = global_position
		if is_in_group("VisibleCloseEnemies"):
			if (pos.distance_to(player_pos) > max_distance_lock) or not is_visible_to_player(self):
				remove_from_group("VisibleCloseEnemies")
		else:
			if (pos.distance_to(player_pos) < max_distance_lock) and is_visible_to_player(self) and onScreen:
				add_to_group("VisibleCloseEnemies")

func _on_death_timeout() -> void:
	queue_free()
	
func _on_detection_area_body_entered(body: Node3D) -> void:
	if body == playerVisibility:
		player = body

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == player:
		if state == State.CHASING:
			previousState = state
			state = State.RETURNING
		player = null

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = velocity.move_toward(safe_velocity, 0.25)
	move_and_slide()
	
	if velocity.length() > 0.1:
		var target_basis = Basis.looking_at(velocity.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, 0.15).orthonormalized()
