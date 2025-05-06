extends Button

const MIN_REWARD = 1000
const MAX_COLLISIONS = 10
const MIN_SPEED = 1.0

func _ready():
	self.text = "Choisir le scénario 1"
	self.rect_min_size = Vector2(200, 50) 
	self.connect("pressed", self, "_on_Button_pressed")  # Connect the button's pressed signal





func _on_Button_pressed():
		print("Button pressed: changing to track 3") 
		get_tree().change_scene("res://testscene.tscn")
