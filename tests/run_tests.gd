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
	if not await run_blocked_turn_checks():
		return
	if not await run_overlap_movement_checks():
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
	if cat.turns_data.size() != 1:
		printerr("FAILED: expected one turn after moving right. turns=", cat.turns_data.size())
		quit(1)
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

	drive_cat(cat, Vector2.DOWN, 40)
	drive_cat(cat, Vector2.LEFT, 40)

	if not assert_angle_close(cat.head_group.rotation, -PI / 2.0, "Head faces exactly left after a completed left turn"):
		return false
	if cat.turns_data.size() < 3:
		printerr("FAILED: expected turn data for right/down/left path. turns=", cat.turns_data.size())
		quit(1)
		return false

	var latest_turn = cat.turns_data[-1].node
	if not assert_half_pixel(latest_turn.position.x, "Latest turn sprite x-position is pixel-centered"):
		return false
	if not assert_half_pixel(latest_turn.position.y, "Latest turn sprite y-position is pixel-centered"):
		return false

	cat.queue_free()
	await process_frame
	return true

func run_blocked_turn_checks() -> bool:
	print("Running blocked turn checks...")
	var cat_scene = load("res://src/cat/LongCat.tscn")
	if cat_scene == null:
		printerr("FAILED to load LongCat.tscn")
		quit(1)
		return false

	var cat: LongCat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(0.5, -40.0),
		Vector2(17.0, -40.0),
		Vector2(17.0, -10.0),
	]
	cat.current_dir = Vector2.DOWN
	cat.turns_data.clear()
	cat.update_visuals()

	var path_before = cat.path.duplicate()
	cat.move_cat(Vector2.LEFT, 1.0)

	if cat.path.size() != path_before.size():
		printerr("FAILED: blocked turn should not append a new path point. path=", cat.path)
		quit(1)
		return false
	if cat.path[-1] != path_before[-1]:
		printerr("FAILED: blocked turn should not move the head. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: blocked turn should preserve current direction. current_dir=", cat.current_dir)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		printerr("FAILED: blocked turn should not create turn data. turns=", cat.turns_data.size())
		quit(1)
		return false
	if cat.blocked_input_dir != Vector2.LEFT:
		printerr("FAILED: blocked turn should mark input as blocked. blocked=", cat.blocked_input_dir)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_overlap_movement_checks() -> bool:
	print("Running overlap movement checks...")
	var cat_scene = load("res://src/cat/LongCat.tscn")
	if cat_scene == null:
		printerr("FAILED to load LongCat.tscn")
		quit(1)
		return false

	var cat: LongCat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(100.5, 0.0),
		Vector2(100.5, 8.0),
		Vector2(50.5, 8.0),
	]
	cat.current_dir = Vector2.LEFT
	cat.turns_data.clear()
	cat.update_visuals()

	var head_before = cat.path[-1]
	cat.move_cat(Vector2.LEFT, 1.0)

	if cat.path[-1] != head_before:
		printerr("FAILED: movement overlapping old body should be blocked. path=", cat.path)
		quit(1)
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
