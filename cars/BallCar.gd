extends Spatial

var red_paint = preload("res://assets/kenney_car_kit/paintBlue.material")

onready var ball = $Ball
onready var car_mesh = $CarMesh
onready var ground_ray = $CarMesh/RayCast
onready var right_wheel = $CarMesh/tmpParent/truck/wheel_frontRight
onready var left_wheel = $CarMesh/tmpParent/truck/wheel_frontLeft
onready var body_mesh = $CarMesh/tmpParent/truck/body

export (bool) var show_debug = false
var sphere_offset = Vector3(0, -1.5, .5)
var acceleration = 45
var steering = 40
var turn_speed = 20
var turn_stop_limit = 0.75
var body_tilt = 35

var speed_input = 0
var rotate_input = 0

# AI
var num_rays = 32
var look_ahead = 12.0
var brake_distance = 5.0
var interest = []
var danger = []
var chosen_dir = Vector3.ZERO
var forward_ray

# Reinforcement Learning variables
var epsilon = 0.2  # Exploration rate
var max_epsilon = 1.0
var min_epsilon = 0.01
var decay_rate = 0.999  # Factor for decaying epsilon
var alpha = 0.3    # Increased learning rate
var gamma = 0.8    # Adjusted discount factor
var q_table = {}   # Q-table for storing state-action values
var stuck_counter = 0  # Counter for how long the car is stuck
var stuck_threshold = 50  # Threshold for being considered stuck
var performance_threshold = 10  # Threshold for good performance
var total_reward = 0
var collision_count = 0


# New variables for improving steering and movement
var min_speed = 5.0  # Minimum speed to maintain while turning
var steering_smooth_factor = 0.1  # Smooth factor for steering
var forward_force = 50.0  # Increased forward force
var min_velocity_threshold = 0.5  # Minimum speed to maintain
var brake_threshold = 2.0 # Distance threshold for braking to engage
var friction_coefficient = 0.1 # Friction coefficient for deceleration

var last_velocity = 0.0 # Variable to track last velocity for stuck_counter


func _ready():
	$CarMesh/tmpParent/truck/body.mesh.surface_set_material(1, red_paint)
	$Ball/DebugMesh.visible = show_debug
	ground_ray.add_exception(ball)
	randomize()
	acceleration *= rand_range(0.9, 1.1)
	interest.resize(num_rays)
	danger.resize(num_rays)
	add_rays()
	DebugOverlay.stats.add_property(ball, "linear_velocity", "length")
	DebugOverlay.stats.add_property(ball, "angular_velocity", "length")
	DebugOverlay.stats.add_property(self, "speed", "")
	DebugOverlay.stats.add_property(self, "total_reward", "")
	DebugOverlay.stats.add_property(self, "collision_count", "")
	DebugOverlay.stats.add_property(self, "action", "")
	DebugOverlay.stats.add_property(self, "gamma", "")
	DebugOverlay.stats.add_property(self, "alpha", "")
	DebugOverlay.stats.add_property(self, "epsilon", "")
func get_indexed(property):
	match property:
		"speed":
			return ball.linear_velocity.length()
		"total_reward":
			return total_reward
		"collision_count":
			return collision_count
		"action":
			return rotate_input
	return null

func add_rays():
	var angle = 2 * PI / num_rays
	for i in range(num_rays):
		var r = RayCast.new()
		$CarMesh/ContextRays.add_child(r)
		r.cast_to = Vector3.FORWARD * look_ahead
		r.rotation.y = -angle * i
		r.enabled = true
	forward_ray = $CarMesh/ContextRays.get_child(0)

func set_interest():
	var path_direction = -car_mesh.transform.basis.z
	if owner and owner.has_method("get_path_direction"):
		path_direction = owner.get_path_direction(ball.global_transform.origin)
	for i in range(num_rays):
		var d = -$CarMesh/ContextRays.get_child(i).global_transform.basis.z
		d = d.dot(path_direction)
		interest[i] = max(0, d)

func set_danger():
	for i in range(num_rays):
		var ray = $CarMesh/ContextRays.get_child(i)
		danger[i] = 1.0 if ray.is_colliding() else 0.0

func choose_direction():
	for i in range(num_rays):
		if danger[i] > 0.0:
			interest[i] = 0.0
	chosen_dir = Vector3.ZERO
	for i in range(num_rays):
		chosen_dir += -$CarMesh/ContextRays.get_child(i).global_transform.basis.z * interest[i]
	chosen_dir = chosen_dir.normalized()

	var d = INF
	if forward_ray.is_colliding():
		d = ball.global_transform.origin.distance_to(forward_ray.get_collision_point())

	if forward_ray.is_colliding() and d < 1.0:
		reset_position()

func reset_position():
	ball.global_transform.origin = Vector3(0, 0, 0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func angle_dir(fwd, target, up):
	var p = fwd.cross(target)
	var dir = p.dot(up)
	return dir

func _process(delta):
	if not ground_ray.is_colliding():
		return

	set_interest()
	set_danger()
	choose_direction()

	# Forward input
	speed_input = acceleration

	# Choose action using epsilon-greedy strategy
	var state = get_state()
	if randf() < epsilon:
		rotate_input = (randf() * 2 - 1) * deg2rad(steering)  # Random action
	else:
		rotate_input = get_best_action(state)  # Best action from Q-table

	# Velocity-dependent steering
	var turn_speed_factor = 1.0 - min(ball.linear_velocity.length() / 20.0, 0.8) # Reduce steering at higher speeds
	rotate_input *= turn_speed_factor

	# Smoothing the steering input
	rotate_input = lerp_angle(rotate_input, rotate_input, steering_smooth_factor)

	# Rotate wheels for effect
	right_wheel.rotation.y = rotate_input * 2
	left_wheel.rotation.y = rotate_input * 2

	# Update Q-table
	update_q_table(state, rotate_input)

	# Apply forward force to maintain movement
	if ball.linear_velocity.length() < min_velocity_threshold:
		ball.add_central_force(car_mesh.global_transform.basis.z * forward_force)

	# Apply friction
	var friction_force = -ball.linear_velocity.normalized() * friction_coefficient * ball.linear_velocity.length()
	ball.add_central_force(friction_force)

	# Braking logic - improved threshold
	var d = INF
	if forward_ray.is_colliding():
		d = ball.global_transform.origin.distance_to(forward_ray.get_collision_point())
		if d < brake_threshold:
			speed_input -= 10 * acceleration * (1 - d / brake_distance)

	# Improved stuck counter
	var current_velocity = ball.linear_velocity.length()
	if abs(current_velocity - last_velocity) < 0.1:
		stuck_counter += 1
	else:
		stuck_counter = 0
	last_velocity = current_velocity

	# Rotate car mesh
	if ball.linear_velocity.length() > turn_stop_limit:
		var new_basis = car_mesh.global_transform.basis.rotated(car_mesh.global_transform.basis.y, rotate_input)
		car_mesh.global_transform.basis = car_mesh.global_transform.basis.slerp(new_basis, turn_speed * delta)
		car_mesh.global_transform = car_mesh.global_transform.orthonormalized()

		# Tilt body for effect
		var t = -rotate_input * ball.linear_velocity.length() / body_tilt
		body_mesh.rotation.z = lerp(body_mesh.rotation.z, t, 10 * delta)

	# Align mesh with ground normal
	var n = ground_ray.get_collision_normal()
	var xform = align_with_y(car_mesh.global_transform, n.normalized())
	car_mesh.global_transform = car_mesh.global_transform.interpolate_with(xform, 10 * delta)

func get_state():
	var state = ""
	for i in range(num_rays):
		state += str(interest[i]) + "_" + str(danger[i]) + "|"
	state += str(ball.linear_velocity.length()) + "_" + str(ball.angular_velocity.y) # Add velocity and angular velocity
	return state

func get_best_action(state):
	if not q_table.has(state):
		return 0  # Default action

	var best_action = 0
	var best_value = -INF
	for action in q_table[state].keys():
		if q_table[state][action] > best_value:
			best_value = q_table[state][action]
			best_action = action
	return best_action

func update_q_table(state, action):
	var reward = get_reward()
	total_reward += reward
	if reward < 0:
		collision_count += 1
	if not q_table.has(state):
		q_table[state] = {}
	if not q_table[state].has(action):
		q_table[state][action] = 0

	var future_state = get_state()
	var future_best_action = get_best_action(future_state)
	var future_reward = q_table[future_state].get(future_best_action, 0)

	q_table[state][action] += alpha * (reward + gamma * future_reward - q_table[state][action])

func get_reward():
	var reward = 0.0
	if forward_ray.is_colliding():
		reward -= 1  # Collision penalty
	if stuck_counter > stuck_threshold:
		reward -= 10 # Increased penalty for being stuck
	var speed = ball.linear_velocity.length()
	if speed > 2.0:
		reward += 0.2 # Reward for higher speed
	elif speed < 0.5:
		reward -= 0.1 # Penalty for low speed
	return reward

func _physics_process(delta):
	car_mesh.transform.origin.x = ball.transform.origin.x + sphere_offset.x
	car_mesh.transform.origin.z = ball.transform.origin.z + sphere_offset.z
	car_mesh.transform.origin.y = lerp(car_mesh.transform.origin.y, ball.transform.origin.y + sphere_offset.y, 1 * delta)

	ball.add_central_force(-car_mesh.global_transform.basis.z * speed_input)

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

