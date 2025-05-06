extends Button

func _ready():
	self.text = "Choisir le scénario 3"
	self.rect_min_size = Vector2(200, 50)





func _on_Button3_pressed():
	get_tree().change_scene("res://testscene3.tscn")

