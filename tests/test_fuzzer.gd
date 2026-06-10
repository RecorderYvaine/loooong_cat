extends SceneTree

class FuzzCat extends LongCat:
	var mock_input: Vector2 = Vector2.ZERO
	func get_input_dir() -> Vector2:
		return mock_input

func _init():
	print("Starting fuzz test...")
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
	
	print("Running 100,000 frames of random fuzzing...")
	for i in range(100000):
		if i % 7 == 0: # Change input frequently
			cat.mock_input = dirs[randi() % 5]
		cat._process(0.016)
		
	print("Fuzz test completed with no crashes!")
	quit(0)
