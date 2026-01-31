extends Node3D

var damage = 10
var active = false

@export var combo  = []
@export var comboTimeStart = []
var comboIndice = 0

@export var withdraw = ""
@export var sheath = ""

func _ready() -> void:
	%CollisionShape3D.disabled = true

func changeActive(newActive):
	active = newActive
	if active:
		%CollisionShape3D.disabled = false
	else:
		%CollisionShape3D.disabled = true

	

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Enemy"):
		if active:
			print("damage")
			body.takeDamage(damage)



func inject_animations_into(character: Node):
	var char_anim_player = character.get_node("AnimationPlayer")
	var weapon_anim_player = self.get_node("AnimationPlayer")
	
	var lib_name = "weapon"
	
	# Create library if it doesn't exist
	if not char_anim_player.has_animation_library(lib_name):
		var new_lib = AnimationLibrary.new()
		char_anim_player.add_animation_library(lib_name, new_lib)
		
	# Now safely get it
	var lib = char_anim_player.get_animation_library(lib_name)
	  
	# Clear old animations
	for anim_name in lib.get_animation_list():
		lib.remove_animation(anim_name)
	
	# Copy all animations from weapon
	for anim_name in weapon_anim_player.get_animation_list():
		var anim = weapon_anim_player.get_animation(anim_name)
		if anim:
			var clean_name = anim_name.get_file()  # strips any library-like prefix
			lib.add_animation(clean_name, anim.duplicate())



func getNextAttack():
	var attack_name = combo[comboIndice]
	var attack_time = comboTimeStart[comboIndice]
	
	comboIndice += 1
	if comboIndice >= combo.size():
		comboIndice = 0
	return [attack_name, attack_time]  



func getAttack() -> String:
	return combo[comboIndice]

func getAttackTime() -> float:
	return comboTimeStart[comboIndice]

func incrementCombo() -> void:
	comboIndice += 1
	if comboIndice >= combo.size():
		comboIndice = 0

func resetCombo() -> void:
	comboIndice = 0

func getWithdraw() -> String:
	return withdraw

func getSheath() -> String:
	return sheath

func setVisibility(visibility: bool) -> void:
	self.visible = visibility
