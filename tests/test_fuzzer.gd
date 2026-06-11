extends SceneTree

class FuzzCat extends LongCat:
	var mock_input: Vector2 = Vector2.ZERO
	func get_input_dir() -> Vector2:
		return mock_input

func _init():
	print("Starting fuzz test...")
	seed(123456)
	var cat_scene = load("res://src/cat/LongCat.tscn")
	if cat_scene == null:
		printerr("Failed to load LongCat.tscn")
		quit(1)
		return
		
	var base_cat = cat_scene.instantiate()
	var cat = FuzzCat.new()
	
	# Extract nodes to map onready vars manually
	cat.head_group = base_cat.get_node("HeadGroup")
	cat.head_sprite = base_cat.get_node("HeadGroup/HeadSprite")
	cat.top_body = base_cat.get_node("HeadGroup/TopBody")
	cat.middle_segments = base_cat.get_node("MiddleSegments")
	cat.turn_segments = base_cat.get_node("TurnSegments")
	cat.bottom_sprite = base_cat.get_node("BottomBody")
	cat.tail_sprite = base_cat.get_node("TailSprite")
	
	for child in base_cat.get_children():
		base_cat.remove_child(child)
		cat.add_child(child)
		
	cat._ready()
	
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.ZERO]
	
	print("Running 4000 frames of random fuzzing...")
	for i in range(4000):
		if i % 2 == 0:
			cat.mock_input = dirs[randi() % dirs.size()]
		if i % 23 == 0:
			cat.mock_input = -cat.current_dir
		if i % 37 == 0:
			cat.mock_input = Vector2.ZERO
		cat._process(0.016)
		if not validate_cat(cat, i):
			quit(1)
			return
		if i % 100 == 0:
			print("Processed frame ", i)
		
	print("Fuzz test completed with no crashes!")
	quit(0)

func validate_cat(cat: LongCat, frame: int) -> bool:
	if cat.path.size() < 2:
		printerr("FAILED fuzz frame ", frame, ": path too short. path=", cat.path)
		return false

	var expected_turns = max(0, cat.path.size() - 2)
	if cat.turns_data.size() != expected_turns:
		printerr("FAILED fuzz frame ", frame, ": turn data count mismatch. expected=", expected_turns, " actual=", cat.turns_data.size(), " path=", cat.path)
		return false

	for i in range(cat.path.size() - 1):
		var seg = cat.path[i + 1] - cat.path[i]
		if seg.length() <= 0.001:
			printerr("FAILED fuzz frame ", frame, ": zero-length segment at ", i, ". path=", cat.path)
			return false
		if abs(seg.x) > 0.001 and abs(seg.y) > 0.001:
			printerr("FAILED fuzz frame ", frame, ": diagonal segment at ", i, ". path=", cat.path)
			return false

	if cat.path.size() > 2 and cat.get_head_segment_length() < cat.MIN_TURN_DIST:
		var prev_dir = (cat.path[-2] - cat.path[-3]).normalized()
		var head_dir = (cat.path[-1] - cat.path[-2]).normalized()
		var is_collinear_reverse = abs(prev_dir.dot(head_dir)) > 0.999
		if not cat.is_active_turn_segment() and not is_collinear_reverse:
			printerr("FAILED fuzz frame ", frame, ": short head segment is neither active turn nor reverse. path=", cat.path, " current_dir=", cat.current_dir)
			return false

	if cat.is_active_turn_segment() and cat.head_sprite.frame == 4:
		printerr("FAILED fuzz frame ", frame, ": active turn should not use flipped reverse head frame. path=", cat.path)
		return false

	return true
