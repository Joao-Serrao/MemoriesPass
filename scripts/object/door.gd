extends StaticBody3D

@export var animationPlayer: AnimationPlayer
@export var interactable := true
var openState = false
var inwardsDirection := false

func activate():
	if interactable:
		interactable = false
		
		if !openState:
			%NavigationLink3D.enabled = true
			self.set_collision_layer_value(3, false)
			if inwardsDirection:
				animationPlayer.play("Open")
			else:
				animationPlayer.play("OpenOutwards")
		else:
			%NavigationLink3D.enabled = false
			self.set_collision_layer_value(3, true)
			if inwardsDirection:
				animationPlayer.play("Close")
			else:
				animationPlayer.play("CloseOutwards")
		openState = !openState
