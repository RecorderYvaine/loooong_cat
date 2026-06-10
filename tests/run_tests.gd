extends SceneTree

func _init():
	call_deferred("run")

func run():
	print("Running syntax check on LongCat.gd...")
	var script = load("res://src/cat/LongCat.gd")
	if script == null:
		printerr("FAILED to load LongCat.gd! Syntax error or file missing.")
		quit(1)
		return
		
	print("Syntax check passed.")
	if not await run_turn_visual_state_checks():
		return
	print("ALL TESTS PASSED")
	quit(0)

func run_turn_visual_state_checks() -> bool:
	print("Running turn visual state checks...")
	var cat_scene = load("res://src/cat/LongCat.tscn")
	if cat_scene == null:
		printerr("FAILED to load LongCat.tscn")
		quit(1)
		return false

	var cat: LongCat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	drive_cat(cat, Vector2.UP, 28)
	drive_cat(cat, Vector2.RIGHT, 80)

	if not assert_angle_close(cat.head_group.rotation, PI / 2.0, "Head faces exactly right after a completed right turn"):
		return false

	var found_horizontal_segment = false
	for child in cat.middle_segments.get_children():
		if child.visible and abs(wrapf(child.rotation - (PI / 2.0), -PI, PI)) < 0.001:
			found_horizontal_segment = true
			if not assert_half_pixel(child.position.y, "Horizontal body segment y-position is pixel-centered"):
				return false

	if not found_horizontal_segment:
		printerr("FAILED: expected a visible horizontal body segment")
		quit(1)
		return false

	if cat.turns_data.size() == 0:
		printerr("FAILED: expected turn data. path=", cat.path, " current_dir=", cat.current_dir)
		quit(1)
		return false

	var turn = cat.turns_data[0].node
	if not assert_half_pixel(turn.position.x, "Turn sprite x-position is pixel-centered"):
		return false
	if not assert_half_pixel(turn.position.y, "Turn sprite y-position is pixel-centered"):
		return false

	cat.queue_free()
	await process_frame
	return true

func drive_cat(cat: LongCat, dir: Vector2, pixels: int) -> void:
	for i in range(pixels):
		cat.move_cat(dir, 1.0)
		cat.update_head_frame(dir)
		cat.update_visuals()

func assert_angle_close(actual: float, expected: float, message: String) -> bool:
	var diff = abs(wrapf(actual - expected, -PI, PI))
	if diff > 0.001:
		printerr("FAILED: ", message, ". actual=", actual, " expected=", expected)
		quit(1)
		return false
	return true

func assert_half_pixel(value: float, message: String) -> bool:
	var frac = value - floor(value)
	if abs(frac - 0.5) > 0.001:
		printerr("FAILED: ", message, ". value=", value)
		quit(1)
		return false
	return true
