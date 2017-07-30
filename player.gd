extends "res://KinematicBodyPlatformer.gd"
const  WALK_SPEED = 222

func _ready():
	set_fixed_process( true )
	self.SLOPE_MAX = 50
	print("WORKING!")
	
func _fixed_process(delta):
	update_physics( delta )