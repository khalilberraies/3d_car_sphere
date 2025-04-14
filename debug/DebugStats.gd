extends MarginContainer

class Property:
	var num_format = "%4.2f"
	var object
	var property
	var label_ref
	var display

	func _init(o, p, l, d):
		object = o
		property = p
		label_ref = l
		display = d

	func set_string():
		if object == null or not is_instance_valid(object):  # Vérifiez si l'objet est valide
			label_ref.text = "Objet non valide"
			return

		# Vérifiez si l'objet a la méthode avant de l'appeler
		if not object.has_method("get_indexed"):
			label_ref.text = "Méthode 'get_indexed' non trouvée"
			return

		# Accédez à la propriété
		var p = object.get_indexed(property)
		var s = object.name + "/" + property + " : "

		match display:
			"":
				s += str(p)
			"length":
				s += num_format % p.size() if p is Array else num_format % p.length()
			"round":
				match typeof(p):
					TYPE_INT, TYPE_REAL:
						s += num_format % p
					TYPE_VECTOR2, TYPE_VECTOR3:
						s += str(p.round())

		label_ref.text = s

var props = []

func add_property(object, property, display):
	if object == null or not is_instance_valid(object):  # Vérifiez si l'objet est valide
		print("Erreur : L'objet passé est invalide.")
		return

	var l = Label.new()
	l.set("custom_fonts/font", load("res://debug/roboto_16.tres"))
	$Column.add_child(l)
	props.append(Property.new(object, property, l, display))

func remove_property(object, property):
	for prop in props:
		if prop.object == object and prop.property == property:
			props.erase(prop)

func _process(_delta):
	if not visible:
		return
	for prop in props:
		if prop and prop.object and is_instance_valid(prop.object):  # Vérifiez si l'objet est valide
			prop.set_string()
		else:
			print("Propriété invalide dans la liste : ", prop)
