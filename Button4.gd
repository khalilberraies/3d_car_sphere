extends Button

func _ready():
	self.text = "Changer les hyperparamètres"
	self.rect_min_size = Vector2(200, 50)
	# Connect the button's pressed signal to the function
	self.connect("pressed", self, "_on_Button2_pressed")


func _on_Button4_pressed():
	get_tree().change_scene("res://log.tscn")
