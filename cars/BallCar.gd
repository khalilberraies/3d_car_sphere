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

# Logique active
var use_script_1 = true

# Raycasts
var num_rays = 32
var look_ahead = 12.0
var interest = []
var danger = []
var forward_ray

# Q-learning
var epsilon = 1.0
var min_epsilon = 0.01
var decay_rate = 0.9995
var alpha = 0.3
var min_alpha = 0.01
var gamma = 0.9
var min_gamma = 0.01
var q_table = {}
var total_reward = 0
var collision_count = 0

# Episode timing
var episode_start_time = 0.0
var episode_elapsed_time = 0.0
var max_speed = 0.0  # Ajout de la variable pour la vitesse maximale

func _ready():
	$CarMesh/tmpParent/truck/body.mesh.surface_set_material(1, red_paint)
	$Ball/DebugMesh.visible = show_debug
	ground_ray.add_exception(ball)
	randomize()
	acceleration *= rand_range(0.9, 1.1)
	interest.resize(num_rays)
	danger.resize(num_rays)
	add_rays()

	# Debug stats
	DebugOverlay.stats.add_property(ball, "linear_velocity", "length")
	DebugOverlay.stats.add_property(self, "epsilon", "")
	DebugOverlay.stats.add_property(self, "alpha", "")
	DebugOverlay.stats.add_property(self, "gamma", "")
	DebugOverlay.stats.add_property(self, "total_reward", "")
	DebugOverlay.stats.add_property(self, "collision_count", "")
	DebugOverlay.stats.add_property(self, "rotate_input", "")
	DebugOverlay.stats.add_property(self, "episode_elapsed_time", "")
	DebugOverlay.stats.add_property(self, "max_speed", "") # Ajout du temps

	# Timer pour changer de logique
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = false
	timer.autostart = true
	timer.connect("timeout", self, "_on_timer_timeout")
	add_child(timer)

	# Début de l'épisode
	episode_start_time = OS.get_ticks_msec() / 1000.0

func _on_timer_timeout():
	use_script_1 = !use_script_1

func _process(delta):
	if not ground_ray.is_colliding():
		return

	# Mettre à jour le temps de l'épisode
	episode_elapsed_time = (OS.get_ticks_msec() / 1000.0) - episode_start_time

	# Mettre à jour la vitesse maximale
	var current_speed = ball.linear_velocity.length()
	max_speed = max(max_speed, current_speed)

	set_interest()
	set_danger()

	if use_script_1:
		script1_logic()
	else:
		script2_logic()

	speed_input = acceleration

	if current_speed > turn_stop_limit:
		var new_basis = car_mesh.global_transform.basis.rotated(car_mesh.global_transform.basis.y, rotate_input)
		car_mesh.global_transform.basis = car_mesh.global_transform.basis.slerp(new_basis, turn_speed * delta)
		car_mesh.global_transform = car_mesh.global_transform.orthonormalized()
		var t = -rotate_input * current_speed / body_tilt
		body_mesh.rotation.z = lerp(body_mesh.rotation.z, t, 10 * delta)

	var n = ground_ray.get_collision_normal()
	var xform = align_with_y(car_mesh.global_transform, n.normalized())
	car_mesh.global_transform = car_mesh.global_transform.interpolate_with(xform, 10 * delta)

func _physics_process(delta):
	car_mesh.transform.origin.x = ball.transform.origin.x + sphere_offset.x
	car_mesh.transform.origin.z = ball.transform.origin.z + sphere_offset.z
	car_mesh.transform.origin.y = lerp(car_mesh.transform.origin.y, ball.transform.origin.y + sphere_offset.y, 1 * delta)
	ball.add_central_force(-car_mesh.global_transform.basis.z * speed_input)

# ---------- LOGIQUES ------------

func script1_logic():
	choose_direction()
	right_wheel.rotation.y = rotate_input * 2
	left_wheel.rotation.y = rotate_input * 2

func script2_logic():
	var state = get_state()
	if randf() < epsilon:
		rotate_input = (randf() * 2 - 1) * deg2rad(steering)
	else:
		rotate_input = get_best_action(state)

	update_q_table(state, rotate_input)

	right_wheel.rotation.y = rotate_input * 2
	left_wheel.rotation.y = rotate_input * 2

# ---------- MÉTHODES COMMUNES ------------

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
		danger[i] = 1.0 if $CarMesh/ContextRays.get_child(i).is_colliding() else 0.0

func choose_direction():
	for i in range(num_rays):
		if danger[i] > 0.0:
			interest[i] = 0.0
	var chosen_dir = Vector3.ZERO
	for i in range(num_rays):
		chosen_dir += -$CarMesh/ContextRays.get_child(i).global_transform.basis.z * interest[i]
	chosen_dir = chosen_dir.normalized()
	rotate_input = angle_dir(-car_mesh.transform.basis.z, chosen_dir, car_mesh.transform.basis.y)

func angle_dir(fwd, target, up):
	var p = fwd.cross(target)
	var dir = p.dot(up)
	return dir

# ---------- Q-LEARNING ------------

func get_state():
	var state = ""
	for i in range(num_rays):
		state += str(interest[i]) + "_" + str(danger[i]) + "|"
	state += str(ball.linear_velocity.length()) + "_" + str(ball.angular_velocity.y)
	return state

func get_best_action(state):
	if not q_table.has(state):
		return 0
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
	epsilon = max(min_epsilon, epsilon * decay_rate)
	alpha = max(min_alpha, alpha * decay_rate)
	gamma = max(min_gamma, gamma * decay_rate)

func get_reward():
	var reward = 0.0
	if forward_ray.is_colliding():
		reward -= 1
	var speed = ball.linear_velocity.length()
	if speed > 2.0:
		reward += 0.5
	elif speed < 0.5:
		reward -= 0.2
	return reward

# ---------- INITIALISATION ------------

func add_rays():
	var angle = 2 * PI / num_rays
	for i in range(num_rays):
		var r = RayCast.new()
		$CarMesh/ContextRays.add_child(r)
		r.cast_to = Vector3.FORWARD * look_ahead
		r.rotation.y = -angle * i
		r.enabled = true
	forward_ray = $CarMesh/ContextRays.get_child(0)

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

# ---------- RESET ÉPISODE (optionnel) ------------

func start_new_episode():
	# Afficher les statistiques avant de reset
	print("========================")
	print(" Fin de l'épisode ")
	print("========================")
	print("Durée de l'épisode : ", round(episode_elapsed_time), " sec")
	print("Total Reward : ", round(total_reward), " ")
	print("Nombre de collisions : ", collision_count)
	print("Vitesse maximale : ", round(max_speed), " unités/s")
	print("Epsilon : ", String.format("%.3f", epsilon))
	print("========================\n")

	# Remise à zéro pour le nouvel épisode
	episode_start_time = OS.get_ticks_msec() / 1000.0
	episode_elapsed_time = 0.0
	total_reward = 0.0
	collision_count = 0
	max_speed = 0.0  # Réinitialiser la vitesse maximale

func _on_Area_body_entered(body):
	if body == ball:
		start_new_episode()
