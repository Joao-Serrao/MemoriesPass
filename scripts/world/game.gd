extends Node3D

func _input(event):
	if event.is_action_pressed("close"):
		get_tree().quit()
	if event.is_action_pressed("Pause"):
		get_tree().paused = !get_tree().paused
