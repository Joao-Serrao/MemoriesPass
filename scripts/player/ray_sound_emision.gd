extends Node3D

@export var rayNumber := 0
@export var debug := false
var rays: Array[Vector3] = []

func fibonacci_sphere(num_rays: int) -> void:
	var golden_ratio = (1.0 + sqrt(5.0)) / 2.0
	
	var upper_count = int(num_rays * 0.9)
	var lower_count = num_rays - upper_count
	
	for i in range(upper_count):
		var t = float(i) / float(upper_count)
		var theta = acos(1.0 - t) 
		var phi = 2.0 * PI * i / golden_ratio
		rays.append(Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi)))
	
	for i in range(lower_count):
		var t = float(i) / float(lower_count)
		var theta = acos(1.0 - t)  
		var phi = 2.0 * PI * i / golden_ratio
		rays.append(Vector3(sin(theta) * cos(phi), -cos(theta), sin(theta) * sin(phi)))
		

func _ready() -> void:
	fibonacci_sphere(rayNumber)
	
func update(maxDistance: int, maxBounces: int) -> void:
	var hitEnimies = {}
	
	for direction in rays:
		var pos = global_position
		var dir_vec = direction
		var remaining = maxDistance
		var bounces = 0
		
		while bounces < maxBounces:
			var query = PhysicsRayQueryParameters3D.create(pos, pos + dir_vec * remaining)
			query.collision_mask = (1 << 1) | (1 << 2)
			var result = get_world_3d().direct_space_state.intersect_ray(query)
			
			if result.is_empty():
				if debug:
					DebugDraw3D.draw_line(pos, pos + dir_vec * remaining, Color.GREEN, 0.1)
				break
			
			var hit_point = result.position
			var hit_normal = result.normal
			
			remaining -= pos.distance_to(hit_point)
			var intensity = remaining/maxDistance
			var collider = result.collider
			
			if collider.is_in_group("Enemy"):
				if hitEnimies.has(collider):
					if hitEnimies[collider][1] < intensity:
						hitEnimies[collider][0] = pos
						hitEnimies[collider][1] = intensity
				else:
					hitEnimies[collider] = [pos, intensity]
				
				
				print("enemy")
			
			if pos.distance_to(hit_point) < 0.001:
				break
			
			if debug:
				DebugDraw3D.draw_line(pos, hit_point, Color.YELLOW, 0.1)
			
			dir_vec = (dir_vec - 2.0 * dir_vec.dot(hit_normal) * hit_normal).normalized()
			pos = hit_point + dir_vec * 0.001  
			bounces += 1
			
		if debug and bounces == maxBounces:
			DebugDraw3D.draw_line(pos, pos + dir_vec * remaining, Color.RED, 0.1)
	for enemy in hitEnimies.keys():
		enemy.setCaution(hitEnimies[enemy][0])




func update2(maxDistance: int, maxBounces: int) -> void:
	var space = get_world_3d().direct_space_state
	var threads = []
	
	for direction in rays:
		var thread = Thread.new()
		thread.start(_trace_ray.bind(space, self.global_position, direction, maxDistance, maxBounces))
		threads.append(thread)
	
	# Wait for all threads to finish
	for thread in threads:
		thread.wait_to_finish()

func _trace_ray(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, maxDistance: float, maxBounces: int) -> void:
	var pos = origin
	var dir = direction
	var remaining = maxDistance
	var bounces = 0
	
	while bounces < maxBounces:
		var query = PhysicsRayQueryParameters3D.create(pos, pos + dir * remaining)
		var result = space.intersect_ray(query)  # ✅ thread-safe
		
		if result.is_empty(): break
		
		var hit_point = result.position
		var hit_normal = result.normal
		var dist = pos.distance_to(hit_point)
		
		var reflected = (dir - 2.0 * dir.dot(hit_normal) * hit_normal).normalized()
		
		pos = hit_point
		dir = reflected
		remaining -= dist
		bounces += 1
