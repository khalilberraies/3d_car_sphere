extends Spatial

onready var hyperparam_label_gamma = $HyperparamGammaLabel
onready var hyperparam_label_alpha = $HyperparamAlphaLabel
onready var hyperparam_label_epsilon = $HyperparamEpsilonLabel
onready var ball_car = $BallCar  # Adjust path if necessary

func _ready():
	# Check if necessary nodes exist
	if not hyperparam_label_gamma or not hyperparam_label_alpha or not hyperparam_label_epsilon or not ball_car:
		push_error("Hyperparameter labels or BallCar are missing from the scene!")
		return

	# Set the text of the labels using values from the ball_car node
	hyperparam_label_gamma.text = "gamma: " + str(ball_car.gamma)
	hyperparam_label_alpha.text = "alpha: " + str(ball_car.alpha)
	hyperparam_label_epsilon.text = "epsilon: " + str(ball_car.epsilon)

	# Make the labels visible
	hyperparam_label_gamma.visible = true
	hyperparam_label_alpha.visible = true
	hyperparam_label_epsilon.visible = true
