extends Spatial

func get_path_direction(position):
	var offset = $track_k2/Path.curve.get_closest_offset(position)
	$track_k2/Path/PathFollow.offset = offset
	return $track_k2/Path/PathFollow.transform.basis.z

func _ready():
	# Debugging: print when the scene is loaded
	print("Loading testscene")
	# Optional debugging line: print the transform of track
	print($track_k2["transform"])
