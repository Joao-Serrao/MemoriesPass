extends Node3D

@export var inwardsDirection = false

func _ready() -> void:
	$Hinge/StaticBody3D.inwardsDirection = inwardsDirection
