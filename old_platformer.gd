extends KinematicBody2D
# Member variables
const GRAVITY = 1000.0 # Pixels/second

# Angle in degrees towards either side that the player can consider "floor"
const FLOOR_ANGLE_TOLERANCE = 20
const WALK_FORCE = 1200
const WALK_MIN_SPEED = 10
const WALK_MAX_SPEED = 200
const STOP_FORCE = 2300
const JUMP_SPEED = 400
const JUMP_MAX_AIRBORNE_TIME = 0.4

const SLIDE_STOP_VELOCITY = 25.0 # One pixel per second
const SLIDE_STOP_MIN_TRAVEL =25.0 # One pixel

var velocity = Vector2()
var on_air_time = 100
var jumping = false

var prev_jump_pressed = false
var act_move_left = "move_left"
var act_move_right = "move_right"
var act_jump = "jump"


func handle_update(delta):
	# Create forces
	var force = Vector2(0, GRAVITY)
	
	var walk_left = Input.is_action_pressed( act_move_left )
	var walk_right = Input.is_action_pressed( act_move_right )
	var jump = Input.is_action_pressed( act_jump )
	
	var stop = true # shall we slow down?
	var against_right = false # if there is a wall to our right 
	var against_left = false # wall to our left
	
	# If can move right
	if get_node("right_ray").is_colliding():
		var n = get_node("right_ray").get_collision_normal()
		var angle = rad2deg(acos(n.dot(Vector2(0, -1))))
		against_right = angle > FLOOR_ANGLE_TOLERANCE
		if angle < 90 : on_air_time = 0.0
	# If can move left
	if get_node("left_ray").is_colliding():
		var n = get_node("left_ray").get_collision_normal()
		var angle = rad2deg(acos(n.dot(Vector2(0, -1))))
		against_left = angle > FLOOR_ANGLE_TOLERANCE
		if angle < 90 : on_air_time = 0.0
		
	# if actually moving
	if walk_left && !against_left:
		if (velocity.x <= WALK_MIN_SPEED and velocity.x > -WALK_MAX_SPEED):
			force.x -= WALK_FORCE
			stop = false
	elif walk_right && !against_right:
		if (velocity.x >= -WALK_MIN_SPEED and velocity.x < WALK_MAX_SPEED):
			force.x += WALK_FORCE
			stop = false
	
	# Slows down movement speed 
	if stop:
		var vsign = sign(velocity.x)
		var vlen = abs(velocity.x)
		vlen -= STOP_FORCE*delta
		if (vlen < 0):
			vlen = 0
		velocity.x = vlen*vsign
	
	# Integrate forces to velocity
	velocity += force*delta
	
	# Integrate velocity into motion and move
	var motion = velocity*delta
	
	# Move and consume motion
	motion = move(motion)
	
	var floor_velocity = Vector2()
	
	if (is_colliding()):
		# You can check which tile was collision against with this
		# print(get_collider_metadata())
		
		# Ran against something, is it the floor? Get normal
		var n = get_collision_normal()
		
		#if (rad2deg(acos(n.dot(Vector2(0, -1)))) < 90):
			# If angle to the "up" vectors is < angle tolerance
			# char is on floor
		#	on_air_time = 0
		#	floor_velocity = get_collider_velocity()
		
		if on_air_time == 0 and force.x == 0 and get_travel().length() < SLIDE_STOP_MIN_TRAVEL and abs(velocity.x) < SLIDE_STOP_VELOCITY and get_collider_velocity() == Vector2():
			# Since this formula will always slide the character around, 
			# a special case must be considered to to stop it from moving 
			# if standing on an inclined floor. Conditions are:
			# 1) Standing on floor (on_air_time == 0)
			# 2) Did not move more than one pixel (get_travel().length() < SLIDE_STOP_MIN_TRAVEL)
			# 3) Not moving horizontally (abs(velocity.x) < SLIDE_STOP_VELOCITY)
			# 4) Collider is not moving
			
			revert_motion()
			velocity.y = 0.0
		else:
			# For every other case of motion, our motion was interrupted.
			# Try to complete the motion by "sliding" by the normal
			motion = n.slide(motion)
			velocity = n.slide(velocity)
			# Then move again
			move(motion)
	
	if (floor_velocity != Vector2()):
		# If floor moves, move with floor
		move(floor_velocity*delta)
	
	if (jumping and velocity.y > 0):
		# If falling, no longer jumping
		jumping = false
	
	if (on_air_time < JUMP_MAX_AIRBORNE_TIME && jump && !prev_jump_pressed && !jumping):
		# Jump must also be allowed to happen if the character left the floor a little bit ago.
		# Makes controls more snappy.
		velocity.y = -JUMP_SPEED
		jumping = true
	
	on_air_time += delta
	prev_jump_pressed = jump

# Requests a left ray node and a right ray node
func _setup( leftRay, rightRay ):
	rightRay.add_exception( self )
	leftRay.add_exception( self )
