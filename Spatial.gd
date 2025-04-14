extends Spatial

export (NodePath) var target_path  # La balle
export (Vector3) var offset = Vector3(0, 3, -6)  # Décalage de la caméra
export var lerp_speed = 5.0  # Vitesse de suivi

var target = null

func _ready():
	if target_path:
		target = get_node(target_path)

func _physics_process(delta):
	if not target:
		return
	
	# Suivre la position de la balle SANS sa rotation
	var target_pos = target.global_transform.origin + offset
	global_transform.origin = global_transform.origin.linear_interpolate(target_pos, lerp_speed * delta)
	
	# Toujours regarder vers la balle mais en gardant l’horizon stable
	var look_target = target.global_transform.origin
	look_target.y = global_transform.origin.y  # Empêche de regarder en haut/bas
	look_at(look_target, Vector3.UP)
