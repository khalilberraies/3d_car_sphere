extends Spatial

onready var hyperparam_label_gamma = $HyperparamGammaLabel
onready var hyperparam_label_alpha = $HyperparamAlphaLabel
onready var hyperparam_label_epsilon = $HyperparamEpsilonLabel
onready var ball_car = $BallCar # Adjust path if necessary

func get_path_direction(position):
	var offset = $track_2/Path.curve.get_closest_offset(position)
	$track_2/Path/PathFollow.offset = offset
	return $track_2/Path/PathFollow.transform.basis.z

func _ready():
	# Debugging: print when the scene is loaded
	print("Loading testscene")

	# Check if necessary nodes exist. This is crucial for robustness.
	if not hyperparam_label_gamma or not hyperparam_label_alpha or not hyperparam_label_epsilon or not ball_car:
		push_error("Missing nodes! Check your scene hierarchy. Ensure you have a BallCar node in your scene.")
		return

	# Set the text of the labels using values from the ball_car node
	hyperparam_label_gamma.text = "gamma: " + str(ball_car.gamma)
	hyperparam_label_alpha.text = "alpha: " + str(ball_car.alpha)
	hyperparam_label_epsilon.text = "epsilon: " + str(ball_car.epsilon)

	# Make the labels visible
	hyperparam_label_gamma.visible = true
	hyperparam_label_alpha.visible = true
	hyperparam_label_epsilon.visible = true

	# Optional debugging line: print the transform of track
	print($track_2["transform"])
