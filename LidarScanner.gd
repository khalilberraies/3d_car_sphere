extends Line2D

var num_lidar_rays = 360  # Number of rays
var max_lidar_distance = 100.0  # Max distance of each ray
var scan_angle_speed = 2.0  # Scanning speed
var current_angle = 0.0  # Current scanning angle

func _ready():
	width = 2  # Set width for visibility
	default_color = Color(1, 0, 0)  # Set color to red

func _process(delta):
	current_angle += scan_angle_speed * delta  # Update angle
	current_angle = fposmod(current_angle, 360.0)  # Normalize angle

	draw_lidar_rays()  # Call the function to draw rays

func draw_lidar_rays():
	clear_points()  # Clear previous points
	for i in range(num_lidar_rays):
		var angle = current_angle + (i * (360.0 / num_lidar_rays))
		var ray_direction = Vector3(cos(deg2rad(angle)), 0, sin(deg2rad(angle)))
		var start_point = get_parent().global_transform.origin  # Get vehicle's position
		var end_point = start_point + ray_direction * max_lidar_distance  # End point

		add_point(Vector2(start_point.x, start_point.z))  # Add start point
		add_point(Vector2(end_point.x, end_point.z))      # Add end point
