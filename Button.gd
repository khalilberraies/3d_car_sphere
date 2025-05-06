extends Button

# Seuils de performance à atteindre
const MIN_REWARD = 1000
const MAX_COLLISIONS = 1000
const MIN_SPEED = 1.0

onready var message_label = $MessageLabel  # Assurez-vous que le nom correspond
onready var message_timer = $MessageTimer  # Assurez-vous que le Timer est présent dans la scène

func _ready():
	self.text = "Choisir le scénario 2"
	self.rect_min_size = Vector2(200, 50)
	message_timer.connect("timeout", self, "_on_Timer_timeout")  # Connecter le signal timeout

func _on_Button_pressed():
	var car_node = get_tree().current_scene.get_node("carTruck") # Nom exact du noeud dans la scène

	if car_node == null:
		show_message("🚨 Car introuvable ! Vérifie le nom exact dans l’arbre des nœuds.")
		return

	# Vérifications
	var reward_ok = car_node.total_reward >= MIN_REWARD
	var collisions_ok = car_node.collision_count <= MAX_COLLISIONS
	var speed_ok = car_node.ball.linear_velocity.length() >= MIN_SPEED

	if reward_ok and collisions_ok and speed_ok:
		get_tree().change_scene("res://Testscen.tscn")
	else:
		var message = "❌ Conditions non remplies :\n"
		if not reward_ok:
			message += "- Récompense trop faible\n"
		if not collisions_ok:
			message += "- Trop de collisions\n"
		if not speed_ok:
			message += "- Vitesse trop faible\n"
		
		show_message(message)

func show_message(message: String):
	message_label.text = message  # Afficher le message dans le Label
	message_timer.start(2)  # Démarrer le timer pour 2 secondes






func _on_MessageTimer_timeout():
	message_label.text = "" 
