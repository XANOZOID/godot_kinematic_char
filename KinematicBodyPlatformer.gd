extends KinematicBody2D
var GRAV_PULL = 1000.0 # Gravity Scale
var SLOPE_MAX = 89.0 setget set_slope_max # Angle at which slopes can be moved along
const SLOPE_CONVERSION_THRESHOLD = 0.18 # this value is strange.. but necessary for correctly moving down slopes based on speed..
var SLOPE_DOWN_CHECK = SLOPE_CONVERSION_THRESHOLD * SLOPE_MAX setget set_slope_down_check
var GRAVITY = GRAV_PULL
const WALK_SPEED = 200  # how far you can move horizontally per second
const JUMP_SPEED = - 400
const OVERLAP_FOR_CRUSH = 3
var MAX_DOWN_MOVE =  min( 3, tan( deg2rad(SLOPE_MAX) )) #how far you can move down per second
var velocity = Vector2()
onready var COL_MARGIN = get_collision_margin()
const _FEET_OFFSET = Vector2( 0, - .5)

var action_jump = "ui_up"
var action_left = "ui_left"
var action_right = "ui_right"
export(NodePath) var bottom_left_point2d
export(NodePath) var bottom_right_point2d 
onready var bot_l = get_node( bottom_left_point2d )
onready var bot_r = get_node( bottom_right_point2d )

signal crushed

func set_slope_max( val ): 
	SLOPE_MAX = val
	set_slope_down_check(val)
	print("WORKED!")
func set_slope_down_check(val): SLOPE_DOWN_CHECK = SLOPE_CONVERSION_THRESHOLD * SLOPE_MAX

func update_physics(delta):
	# Make sure gravity doesn't effect player when on a block
	if test_move(Vector2(0,4)):
		GRAVITY = 0
		velocity.y = 0
		if Input.is_action_pressed(action_jump):
			velocity.y = JUMP_SPEED
	else: GRAVITY = GRAV_PULL
	velocity.y += delta * GRAVITY
	
	# Handle input for moving and such
	if (Input.is_action_pressed(action_left)): velocity.x = - WALK_SPEED
	elif (Input.is_action_pressed(action_right)): velocity.x =   WALK_SPEED
	else: velocity.x = 0
	
	# Begin moving 
	var was_on_floor = test_move( Vector2( 0, 4) ) && velocity.y >= 0	
	var motion = velocity * delta
	var oldPos = get_global_pos()
	motion = move(motion)
	
	# Handle the priotized logic (Slopes moving up or down)
	if is_colliding() :
		# Attempt to correctly move UP slopes, sliding up them - speed non reduced
		# Get the collision normal to solve for angle
		var n = get_collision_normal()
		var angle = rad2deg(acos(n.dot(Vector2(0,-1))))	
		if angle < SLOPE_MAX: # can move up
			motion = Vector2( motion.x, 0)
			motion = n.slide(motion).normalized() * abs(motion.x)
		elif angle < 90 && angle >= SLOPE_MAX: # Can't move up, stop in tracks
			motion = Vector2(0, motion.y) 
			revert_motion()
		else: motion = n.slide(motion) # Naturally slide against all other cases
		if !test_move(Vector2()) && !test_move(motion):
			move(motion)
	elif was_on_floor && get_collision_at_feet( Vector2( 0, abs(velocity.x) * delta * SLOPE_DOWN_CHECK) ) != null:
		# We can potentially move down, we will try if there's a collision amongst one of our bottom edges
		var col = get_collision_at_feet( Vector2( 0, abs(velocity.x) * delta * SLOPE_DOWN_CHECK) )
		if col != null:
			var pos = get_global_pos()
			var point = get_collision_point_below(col)
			# can move down is based on the change in y from our FEET to the desired position
			var can_move_down = ( abs((pos.y+8)-point.y)  <= (MAX_DOWN_MOVE * delta * abs(velocity.x)) )
			if can_move_down:
				# forcefully push ourselves to the nearest collided point on an edge (IF Accepted slope)
				set_global_pos( point - Vector2(0,8))
				if !feet_are_free() : set_global_pos( pos ) #reset position on spiked inclines
				
	# Update the player's position for moving blocks...
	was_on_floor = test_move( Vector2( 0, 9) ) && velocity.y >= 0
	if was_on_floor :
		var saved = get_global_pos()
		move( Vector2( 0, 9 ) )
		if is_colliding():
			set_global_pos(saved)
			var vel = get_collider_velocity() * delta
			move( vel )
		else: set_global_pos(saved)
		
	set_collision_margin( -OVERLAP_FOR_CRUSH )
	if test_move(Vector2()): emit_signal("crushed")
	set_collision_margin( COL_MARGIN )
	
func vector_angle( a, b ): return rad2deg(acos(b.dot(a)))	
func feet_are_free(): 
	var space = get_world_2d().get_direct_space_state()
	var left = bot_l.get_global_pos() + _FEET_OFFSET
	var right = bot_r.get_global_pos() + _FEET_OFFSET
	var col1 = space.intersect_ray( left, right, [self])
	return col1.empty()
	
func get_collision_at_feet(pushDown = WALK_SPEED * SLOPE_DOWN_CHECK ):
	var space = get_world_2d().get_direct_space_state()
	var left = bot_l.get_global_pos()
	var right = bot_r.get_global_pos()
	var col1 = space.intersect_ray( right, pushDown + right, [self])
	var col2 = space.intersect_ray( left,  pushDown + left, [self])
	if col1.empty() and col2.empty() : return null
	elif col1.empty() : return col2
	elif col2.empty() : return col1
	elif col1.position.y < col2.position.y: return col1
	else: return col2	
func get_slope_on( colMap ): return rad2deg(acos(colMap.normal.dot(Vector2(0,-1))))
func get_collision_point_below( colMap ): return Vector2( get_global_pos().x, colMap.position.y )