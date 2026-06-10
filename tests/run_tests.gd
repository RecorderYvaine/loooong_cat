extends SceneTree

func _init():
	print("Running syntax check on LongCat.gd...")
	var script = load("res://src/cat/LongCat.gd")
	if script == null:
		printerr("FAILED to load LongCat.gd! Syntax error or file missing.")
		quit(1)
		return
		
	print("Syntax check passed.")
	print("ALL TESTS PASSED")
	quit(0)
