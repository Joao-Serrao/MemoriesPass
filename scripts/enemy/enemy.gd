extends CharacterBody3D

var max_distance_lock = 100

var health = 100

var onScreen = false

func is_visible_to_player(player, target) -> bool:
	var space_state = get_world_3d().direct_space_state
	var from = player.global_transform.origin + Vector3.UP * player.getHeight()
	var to = target.global_transform.origin + Vector3.UP * 0.5

	var param = PhysicsRayQueryParameters3D.create(from, to)
	param.exclude = [player, target]
	param.collision_mask = 1 << 2

	var result = space_state.intersect_ray(param)
	
	# If something is hit, and it's not the target, it's hidden
	if result and result.collider != target:
		return false
	return true

func _on_visible_on_screen_notifier_3d_screen_entered():
	onScreen = true
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var player_pos = player.global_position
		var pos = global_position
		
		if (pos.distance_to(player_pos) < max_distance_lock):
			add_to_group("VisibleCloseEnemies")

func _on_visible_on_screen_notifier_3d_screen_exited():
	onScreen = false
	remove_from_group("VisibleCloseEnemies")

func getHeight():
	return $Pivot/enemyMesh.get_aabb().size.y

func takeDamage(damage):
	health -= damage
	if health <= 0:
		remove_from_group("VisibleCloseEnemies")
		$CheckVisibility.stop()
		$Death.start()


func _on_timer_timeout() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var player_pos = player.global_position
		var pos = global_position
		if is_in_group("VisibleCloseEnemies"):
			if (pos.distance_to(player_pos) > max_distance_lock) or not is_visible_to_player(player, self):
				remove_from_group("VisibleCloseEnemies")
		else:
			if (pos.distance_to(player_pos) < max_distance_lock) and is_visible_to_player(player, self) and onScreen:
				add_to_group("VisibleCloseEnemies")


func _on_death_timeout() -> void:
	queue_free()
