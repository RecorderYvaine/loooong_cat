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
	if not await run_early_turn_completion_checks():
		return
	if not await run_queued_input_process_checks():
		return
	if not await run_released_turn_exit_checks():
		return
	if not await run_reverse_during_turn_exit_checks():
		return
	if not await run_reverse_after_collision_checks():
		return
	if not await run_reverse_active_turn_checks():
		return
	if not await run_multi_input_checks():
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
	drive_cat(cat, Vector2.RIGHT, 1)

	if cat.head_group.rotation <= 0.0 or cat.head_group.rotation >= PI / 2.0:
		printerr("FAILED: Head should interpolate during an active right turn. rotation=", cat.head_group.rotation)
		quit(1)
		return false
	if cat.top_body.visible:
		printerr("FAILED: upper body should be hidden while turn animation is active")
		quit(1)
		return false

	drive_cat(cat, Vector2.RIGHT, 79)

	if not assert_angle_close(cat.head_group.rotation, PI / 2.0, "Head faces exactly right after a completed right turn"):
		return false
	if not cat.top_body.visible:
		printerr("FAILED: upper body should be visible while moving straight")
		quit(1)
		return false
	if not assert_head_texture_pixel_aligned(cat, "Head texture origin is pixel-aligned after right turn"):
		return false
	if not assert_head_face_on_body_grid(cat, "Head face is aligned to horizontal body after right turn"):
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
	if not assert_head_texture_pixel_aligned(cat, "Head texture origin is pixel-aligned after down turn"):
		return false
	if not assert_head_face_on_body_grid(cat, "Head face is aligned to vertical body after down turn"):
		return false
	drive_cat(cat, Vector2.LEFT, 40)

	if not assert_angle_close(cat.head_group.rotation, -PI / 2.0, "Head faces exactly left after a completed left turn"):
		return false
	if not assert_head_texture_pixel_aligned(cat, "Head texture origin is pixel-aligned after left turn"):
		return false
	if not assert_head_face_on_body_grid(cat, "Head face is aligned to horizontal body after left turn"):
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
		Vector2(-8.5, -40.0),
		Vector2(-4.5, -40.0),
	]
	cat.current_dir = Vector2.RIGHT
	cat.turns_data.clear()
	cat.update_visuals()

	var path_before = cat.path.duplicate()
	cat.move_cat(Vector2.DOWN, 1.0)

	if cat.path.size() != path_before.size():
		printerr("FAILED: blocked turn should not append a new path point. path=", cat.path)
		quit(1)
		return false
	if cat.path[-1] != path_before[-1]:
		printerr("FAILED: blocked turn should not move the head. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.RIGHT:
		printerr("FAILED: blocked turn should preserve current direction. current_dir=", cat.current_dir)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		printerr("FAILED: blocked turn should not create turn data. turns=", cat.turns_data.size())
		quit(1)
		return false
	if cat.turn_segments.get_child_count() != 0:
		printerr("FAILED: blocked turn should not create turn sprites. children=", cat.turn_segments.get_child_count())
		quit(1)
		return false
	if cat.blocked_input_dir != Vector2.DOWN:
		printerr("FAILED: blocked turn should mark input as blocked. blocked=", cat.blocked_input_dir)
		quit(1)
		return false

	cat.queue_free()
	await process_frame

	cat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(0.5, -40.0),
		Vector2(2.5, -40.0),
		Vector2(11.5, -40.0),
	]
	cat.current_dir = Vector2.RIGHT
	cat.turns_data.clear()
	cat.update_visuals()
	cat.move_cat(Vector2.DOWN, cat.TURN_EXIT_ADVANCE)

	if cat.path.size() != 4:
		printerr("FAILED: turn-ready turn should auto-advance before starting. path=", cat.path)
		quit(1)
		return false
	if abs(cat.path[-1].distance_to(cat.path[-2]) - cat.TURN_READY_DIST) > 0.001:
		printerr("FAILED: 11px centered head clearance should advance to turn-ready distance. path=", cat.path)
		quit(1)
		return false

	cat.move_cat(Vector2.DOWN, 1.0)

	if cat.path.size() != 5:
		printerr("FAILED: 11px centered head clearance should allow turn. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: allowed clearance turn should update direction. current_dir=", cat.current_dir)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_early_turn_completion_checks() -> bool:
	print("Running early turn completion checks...")
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
		Vector2(8.5, -40.0),
	]
	cat.current_dir = Vector2.RIGHT
	cat.turns_data.clear()
	cat.update_visuals()

	var path_size_before = cat.path.size()
	cat.move_cat(Vector2.DOWN, 1.0)

	if cat.path.size() != path_size_before:
		printerr("FAILED: early turn should complete the current segment before appending. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.RIGHT:
		printerr("FAILED: early turn completion should preserve current direction. current_dir=", cat.current_dir)
		quit(1)
		return false
	if abs(cat.path[-1].distance_to(cat.path[-2]) - cat.MIN_TURN_DIST) > 0.001:
		printerr("FAILED: early turn should first auto-advance to the minimum turn distance. path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		printerr("FAILED: early turn completion should not create turn data yet. turns=", cat.turns_data.size())
		quit(1)
		return false

	cat.move_cat(Vector2.DOWN, 1.0)

	if cat.path.size() != path_size_before:
		printerr("FAILED: early turn should keep completing the turn exit before appending. path=", cat.path)
		quit(1)
		return false
	if abs(cat.path[-1].distance_to(cat.path[-2]) - (cat.MIN_TURN_DIST + 1.0)) > 0.001:
		printerr("FAILED: early turn should advance through the first exit pixel. path=", cat.path)
		quit(1)
		return false

	cat.move_cat(Vector2.DOWN, 1.0)

	if cat.path.size() != path_size_before:
		printerr("FAILED: early turn should add the full turn exit before appending. path=", cat.path)
		quit(1)
		return false
	if abs(cat.path[-1].distance_to(cat.path[-2]) - cat.TURN_READY_DIST) > 0.001:
		printerr("FAILED: early turn should auto-advance to the turn-ready distance. path=", cat.path)
		quit(1)
		return false

	cat.move_cat(Vector2.DOWN, 1.0)

	if cat.path.size() != path_size_before + 1:
		printerr("FAILED: queued follow-up turn should start immediately after auto-advance. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: queued follow-up turn should update direction. current_dir=", cat.current_dir)
		quit(1)
		return false
	if cat.turns_data.size() != 1:
		printerr("FAILED: queued follow-up turn should create exactly one turn. turns=", cat.turns_data.size())
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_queued_input_process_checks() -> bool:
	print("Running queued input process checks...")
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
		Vector2(8.5, -40.0),
	]
	cat.current_dir = Vector2.RIGHT
	cat.turns_data.clear()
	cat.update_visuals()

	Input.action_press("ui_down")
	cat._process(1.0 / cat.speed)

	if cat.path.size() != 3:
		Input.action_release("ui_down")
		printerr("FAILED: queued input should not append before turn-ready distance. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.RIGHT:
		Input.action_release("ui_down")
		printerr("FAILED: queued input should keep moving in current direction before ready. current_dir=", cat.current_dir)
		quit(1)
		return false

	var safety = 8
	while safety > 0 and cat.path.size() == 3:
		cat._process(1.0 / cat.speed)
		safety -= 1
	Input.action_release("ui_down")

	if cat.path.size() != 4:
		printerr("FAILED: queued input should start the next turn as soon as turn-ready distance is reached. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: queued input should update direction on the same frame. current_dir=", cat.current_dir)
		quit(1)
		return false
	if cat.queued_turn_dir != Vector2.ZERO:
		printerr("FAILED: queued input should be consumed after starting the turn. queued=", cat.queued_turn_dir)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_released_turn_exit_checks() -> bool:
	print("Running released turn exit checks...")
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
	Input.action_press("ui_right")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_right")

	var safety = 32
	while safety > 0 and cat.get_head_segment_length() < cat.TURN_READY_DIST:
		cat._process(1.0 / cat.speed)
		safety -= 1

	if abs(cat.get_head_segment_length() - cat.TURN_READY_DIST) > 0.001:
		printerr("FAILED: released turn should auto-exit past the turn animation. dist=", cat.get_head_segment_length(), " path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.RIGHT:
		printerr("FAILED: released turn should finish facing right. current_dir=", cat.current_dir)
		quit(1)
		return false
	if not cat.top_body.visible:
		printerr("FAILED: upper body should be visible after released turn exits. dist=", cat.get_head_segment_length())
		quit(1)
		return false

	var path_size_before = cat.path.size()
	Input.action_press("ui_down")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_down")

	if cat.path.size() != path_size_before + 1:
		printerr("FAILED: next turn should start immediately after released turn exit. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: next turn after released exit should face down. current_dir=", cat.current_dir)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_reverse_during_turn_exit_checks() -> bool:
	print("Running reverse during turn exit checks...")
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
		Vector2(10.5, -40.0),
	]
	cat.current_dir = Vector2.RIGHT
	cat.turns_data.clear()
	cat.update_visuals()

	Input.action_press("ui_left")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_left")

	if cat.path[-1].x >= 10.5:
		printerr("FAILED: reverse input during turn exit should move backward, not auto-forward. path=", cat.path)
		quit(1)
		return false
	if cat.current_dir != Vector2.RIGHT:
		printerr("FAILED: partial reverse during turn exit should keep segment direction. current_dir=", cat.current_dir)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_reverse_after_collision_checks() -> bool:
	print("Running reverse after collision checks...")
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
		Vector2(100.5, 9.0),
		Vector2(50.5, 9.0),
	]
	cat.current_dir = Vector2.LEFT
	cat.turns_data.clear()
	cat.clear_contact_exit()
	cat.update_visuals()

	Input.action_press("ui_left")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_left")

	var blocked_head = cat.path[-1]
	Input.action_press("ui_right")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_right")

	if cat.path[-1].x <= blocked_head.x:
		printerr("FAILED: reverse after body collision should move away from collision. path=", cat.path)
		quit(1)
		return false

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(0.5, -40.0),
		Vector2(1.0, -40.0),
		Vector2(9.0, -40.0),
	]
	cat.current_dir = Vector2.RIGHT
	cat.turns_data.clear()
	cat.update_visuals()

	if cat.is_active_turn_segment():
		printerr("FAILED: short collinear reverse segment should not be treated as an active turn. path=", cat.path)
		quit(1)
		return false
	if not cat.top_body.visible:
		printerr("FAILED: upper body should stay visible on short collinear reverse segment")
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_reverse_active_turn_checks() -> bool:
	print("Running reverse active turn checks...")
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
	drive_cat(cat, Vector2.RIGHT, 1)

	if not cat.is_active_turn_segment():
		printerr("FAILED: expected active turn before reversing. path=", cat.path)
		quit(1)
		return false

	Input.action_press("ui_left")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_left")

	if cat.is_active_turn_segment():
		printerr("FAILED: reverse should retract the active turn segment. path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		printerr("FAILED: reversing active turn should remove turn data. turns=", cat.turns_data.size())
		quit(1)
		return false
	if cat.blocked_input_dir != Vector2.ZERO:
		printerr("FAILED: reversing active turn should not leave blocked input. blocked=", cat.blocked_input_dir)
		quit(1)
		return false
	if cat.head_sprite.frame == 4:
		printerr("FAILED: active turn reverse should not leave the flipped reverse head frame")
		quit(1)
		return false

	var length_before = cat.get_head_segment_length()
	Input.action_press("ui_down")
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_down")

	if cat.get_head_segment_length() >= length_before:
		printerr("FAILED: after retracting a turn, backing along previous segment should keep working. path=", cat.path)
		quit(1)
		return false

	cat.queue_free()
	await process_frame

	cat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	drive_cat(cat, Vector2.UP, 28)
	drive_cat(cat, Vector2.RIGHT, 12)

	if cat.path.size() != 3:
		printerr("FAILED: expected completed right turn before reverse-release check. path=", cat.path)
		quit(1)
		return false

	Input.action_press("ui_left")
	var safety = 16
	while safety > 0 and not cat.is_active_turn_segment():
		cat._process(1.0 / cat.speed)
		safety -= 1
	Input.action_release("ui_left")

	if not cat.is_active_turn_segment():
		printerr("FAILED: reverse should enter active turn before release. path=", cat.path)
		quit(1)
		return false

	safety = 16
	while safety > 0 and cat.path.size() == 3:
		cat._process(1.0 / cat.speed)
		safety -= 1

	if cat.path.size() != 2:
		printerr("FAILED: released reverse-entered turn should auto-retract and remove the turn. path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		printerr("FAILED: released reverse-entered turn should remove turn data. turns=", cat.turns_data.size())
		quit(1)
		return false

	cat.queue_free()
	await process_frame

	cat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	drive_cat(cat, Vector2.UP, 28)
	drive_cat(cat, Vector2.RIGHT, 12)
	drive_cat(cat, Vector2.UP, 12)

	if cat.path.size() != 4:
		printerr("FAILED: expected two completed turns before reverse input lock check. path=", cat.path)
		quit(1)
		return false

	Input.action_press("ui_down")
	safety = 32
	while safety > 0 and cat.path.size() == 4:
		cat._process(1.0 / cat.speed)
		safety -= 1

	if cat.path.size() != 3:
		Input.action_release("ui_down")
		printerr("FAILED: reverse should retract the latest segment back to the previous turn. path=", cat.path)
		quit(1)
		return false

	var path_after_pop = cat.path.duplicate()
	for i in range(3):
		cat._process(1.0 / cat.speed)

	Input.action_release("ui_down")

	if cat.path != path_after_pop:
		printerr("FAILED: held reverse input should be briefly ignored after popping a turn. before=", path_after_pop, " after=", cat.path)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func run_multi_input_checks() -> bool:
	print("Running multi-input checks...")
	release_all_test_inputs()
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
	drive_cat(cat, Vector2.RIGHT, 20)

	Input.action_press("ui_left")
	Input.action_press("ui_down")
	cat.preferred_input_dir = Vector2.DOWN
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_left")
	Input.action_release("ui_down")

	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: simultaneous inputs should use the latest pressed turn direction when allowed. current_dir=", cat.current_dir, " path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 2:
		printerr("FAILED: simultaneous latest allowed input should create exactly one extra turn. turns=", cat.turns_data.size())
		quit(1)
		return false

	cat.queue_free()
	await process_frame

	cat = cat_scene.instantiate()
	root.add_child(cat)
	await process_frame
	await process_frame

	cat.path = [
		Vector2(0.5, -28.0),
		Vector2(18.5, -28.0),
		Vector2(18.5, -40.0),
		Vector2(9.5, -40.0),
	]
	cat.current_dir = Vector2.LEFT
	cat.turns_data.clear()
	cat.clear_contact_exit()
	cat.update_visuals()
	release_all_test_inputs()

	var head_before = cat.path[-1]
	Input.action_press("ui_down")
	cat.preferred_input_dir = Vector2.DOWN
	cat._process(1.0 / cat.speed)
	Input.action_release("ui_down")

	if cat.current_dir != Vector2.LEFT:
		printerr("FAILED: blocked latest input should preserve previous direction. current_dir=", cat.current_dir)
		quit(1)
		return false
	if cat.path[-1] != head_before:
		printerr("FAILED: blocked latest input without forward held should not move forward. before=", head_before, " path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		printerr("FAILED: blocked latest input should not create a turn. turns=", cat.turns_data.size())
		quit(1)
		return false

	Input.action_press("ui_left")
	Input.action_press("ui_down")
	cat.preferred_input_dir = Vector2.DOWN
	cat._process(1.0 / cat.speed)

	if cat.current_dir != Vector2.LEFT:
		Input.action_release("ui_left")
		Input.action_release("ui_down")
		printerr("FAILED: blocked latest input with forward held should keep current direction. current_dir=", cat.current_dir)
		quit(1)
		return false
	if cat.path[-1].x >= head_before.x:
		Input.action_release("ui_left")
		Input.action_release("ui_down")
		printerr("FAILED: blocked latest input with forward held should continue moving forward. before=", head_before, " path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 0:
		Input.action_release("ui_left")
		Input.action_release("ui_down")
		printerr("FAILED: blocked latest input with forward held should not create a blocked turn. turns=", cat.turns_data.size())
		quit(1)
		return false

	var safety = 32
	while safety > 0 and cat.current_dir == Vector2.LEFT:
		cat._process(1.0 / cat.speed)
		safety -= 1
	Input.action_release("ui_left")
	Input.action_release("ui_down")

	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: held latest turn should start as soon as it becomes available. current_dir=", cat.current_dir, " path=", cat.path)
		quit(1)
		return false
	if cat.turns_data.size() != 1:
		printerr("FAILED: held latest turn should create one turn once available. turns=", cat.turns_data.size())
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	release_all_test_inputs()
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
		Vector2(100.5, 9.0),
		Vector2(50.5, 9.0),
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

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(30.5, 0.0),
		Vector2(30.5, 9.0),
		Vector2(15.5, 9.0),
	]
	cat.current_dir = Vector2.LEFT
	cat.turns_data.clear()
	cat.update_visuals()

	head_before = cat.path[-1]
	cat.move_cat(Vector2.LEFT, 1.0)
	if cat.path[-1] != head_before:
		printerr("FAILED: forward movement into overlapped body should still be blocked. path=", cat.path)
		quit(1)
		return false

	cat.move_cat(Vector2.DOWN, 1.0)
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: turn out of overlapped body should be allowed when exit space is clear. current_dir=", cat.current_dir, " path=", cat.path)
		quit(1)
		return false
	if cat.path.size() != 5:
		printerr("FAILED: turn out of overlapped body should append a turn point. path=", cat.path)
		quit(1)
		return false

	cat.path = [
		Vector2(50.5, 0.0),
		Vector2(50.5, -40.0),
		Vector2(41.5, -40.0),
		Vector2(41.5, -20.0),
	]
	cat.current_dir = Vector2.DOWN
	cat.turns_data.clear()
	cat.clear_contact_exit()
	cat.update_visuals()

	head_before = cat.path[-1]
	cat.move_cat(Vector2.DOWN, 1.0)
	if cat.path[-1] != head_before:
		printerr("FAILED: head resting on body should not keep moving forward into it. path=", cat.path)
		quit(1)
		return false

	cat.move_cat(Vector2.LEFT, 1.0)
	if cat.current_dir != Vector2.LEFT:
		printerr("FAILED: head resting on body should be able to turn left away from the body when side space is clear. current_dir=", cat.current_dir, " path=", cat.path)
		quit(1)
		return false
	if cat.path.size() != 5:
		printerr("FAILED: left turn from body contact should append a turn point. path=", cat.path)
		quit(1)
		return false

	var contact_cases = [
		{
			"name": "horizontal contact below turns down",
			"path": [Vector2(0.5, 0.0), Vector2(30.5, 0.0), Vector2(30.5, 1.0), Vector2(15.5, 1.0)],
			"current": Vector2.LEFT,
			"turn": Vector2.DOWN,
		},
		{
			"name": "horizontal contact above turns up",
			"path": [Vector2(0.5, 0.0), Vector2(30.5, 0.0), Vector2(30.5, -1.0), Vector2(15.5, -1.0)],
			"current": Vector2.LEFT,
			"turn": Vector2.UP,
		},
		{
			"name": "vertical contact left side turns left",
			"path": [Vector2(50.5, 0.0), Vector2(50.5, -40.0), Vector2(41.5, -40.0), Vector2(41.5, -20.0)],
			"current": Vector2.DOWN,
			"turn": Vector2.LEFT,
		},
		{
			"name": "vertical contact right side turns right",
			"path": [Vector2(50.5, 0.0), Vector2(50.5, -40.0), Vector2(59.5, -40.0), Vector2(59.5, -20.0)],
			"current": Vector2.DOWN,
			"turn": Vector2.RIGHT,
		},
		{
			"name": "horizontal edge contact turns left along edge",
			"path": [Vector2(0.5, 0.0), Vector2(30.5, 0.0), Vector2(30.5, 30.0), Vector2(15.5, 30.0), Vector2(15.5, 9.0)],
			"current": Vector2.UP,
			"turn": Vector2.LEFT,
		},
		{
			"name": "horizontal edge contact turns right along edge",
			"path": [Vector2(30.5, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 30.0), Vector2(15.5, 30.0), Vector2(15.5, 9.0)],
			"current": Vector2.UP,
			"turn": Vector2.RIGHT,
		},
	]

	for contact_case in contact_cases:
		cat.path = []
		for point in contact_case.path:
			cat.path.append(point)
		cat.current_dir = contact_case.current
		cat.turns_data.clear()
		cat.clear_contact_exit()
		cat.update_visuals()

		head_before = cat.path[-1]
		cat.move_cat(cat.current_dir, 1.0)
		if cat.path[-1] != head_before:
			printerr("FAILED: ", contact_case.name, " should not keep moving forward into contact. path=", cat.path)
			quit(1)
			return false

		cat.move_cat(contact_case.turn, 1.0)
		if cat.current_dir != contact_case.turn:
			printerr("FAILED: ", contact_case.name, " should allow contact turn. current_dir=", cat.current_dir, " path=", cat.path)
			quit(1)
			return false
		var head_after_turn = cat.path[-1]
		for i in range(12):
			cat.move_cat(contact_case.turn, 1.0)
		if cat.path[-1].distance_to(head_after_turn) < 6.0:
			printerr("FAILED: ", contact_case.name, " should keep moving after contact turn. after_turn=", head_after_turn, " path=", cat.path)
			quit(1)
			return false

		cat.path = []
		for point in contact_case.path:
			cat.path.append(point)
		cat.current_dir = contact_case.current
		cat.turns_data.clear()
		cat.clear_contact_exit()
		cat.update_visuals()
		release_all_test_inputs()

		var turn_action = action_for_dir(contact_case.turn)
		Input.action_press(turn_action)
		cat.preferred_input_dir = contact_case.turn
		cat._process(1.0 / cat.speed)

		if cat.current_dir != contact_case.turn:
			Input.action_release(turn_action)
			printerr("FAILED: ", contact_case.name, " should allow contact turn through input processing. current_dir=", cat.current_dir, " path=", cat.path)
			quit(1)
			return false
		head_after_turn = cat.path[-1]
		for i in range(12):
			cat._process(1.0 / cat.speed)
		Input.action_release(turn_action)
		if cat.path[-1].distance_to(head_after_turn) < 6.0:
			printerr("FAILED: ", contact_case.name, " should keep moving after contact turn through input processing. after_turn=", head_after_turn, " path=", cat.path)
			quit(1)
			return false

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(30.5, 0.0),
		Vector2(30.5, 1.0),
		Vector2(15.5, 1.0),
	]
	cat.current_dir = Vector2.LEFT
	cat.turns_data.clear()
	cat.clear_contact_exit()
	cat.update_visuals()

	head_before = cat.path[-1]
	cat.move_cat(Vector2.LEFT, 1.0)
	if cat.path[-1] != head_before:
		printerr("FAILED: head resting near horizontal body should not keep moving forward into it. path=", cat.path)
		quit(1)
		return false

	cat.move_cat(Vector2.DOWN, 1.0)
	if cat.current_dir != Vector2.DOWN:
		printerr("FAILED: head resting near horizontal body should be able to turn down away from it. current_dir=", cat.current_dir, " path=", cat.path)
		quit(1)
		return false

	cat.path = [
		Vector2(0.5, 0.0),
		Vector2(30.5, 0.0),
		Vector2(30.5, -1.0),
		Vector2(15.5, -1.0),
	]
	cat.current_dir = Vector2.LEFT
	cat.turns_data.clear()
	cat.clear_contact_exit()
	cat.update_visuals()

	cat.move_cat(Vector2.UP, 1.0)
	if cat.current_dir != Vector2.UP:
		printerr("FAILED: head resting near horizontal body should be able to turn up away from it. current_dir=", cat.current_dir, " path=", cat.path)
		quit(1)
		return false

	cat.queue_free()
	await process_frame
	return true

func release_all_test_inputs() -> void:
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_left")
	Input.action_release("ui_right")

func action_for_dir(dir: Vector2) -> StringName:
	if dir == Vector2.UP:
		return &"ui_up"
	if dir == Vector2.DOWN:
		return &"ui_down"
	if dir == Vector2.LEFT:
		return &"ui_left"
	return &"ui_right"

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

func assert_head_texture_pixel_aligned(cat: LongCat, message: String) -> bool:
	var origin = cat.head_group.position + cat.head_sprite.position.rotated(cat.head_group.rotation)
	if abs(origin.x - round(origin.x)) > 0.001 or abs(origin.y - round(origin.y)) > 0.001:
		printerr("FAILED: ", message, ". origin=", origin, " rotation=", cat.head_group.rotation)
		quit(1)
		return false
	return true

func assert_head_face_on_body_grid(cat: LongCat, message: String) -> bool:
	var face = cat.head_group.position + cat.FACE_LOCAL.rotated(cat.head_group.rotation)
	if abs(cat.current_dir.x) > 0.0:
		var frac_y = face.y - floor(face.y)
		if abs(face.x - round(face.x)) > 0.001 or abs(frac_y - 0.5) > 0.001:
			printerr("FAILED: ", message, ". face=", face, " dir=", cat.current_dir)
			quit(1)
			return false
	elif abs(cat.current_dir.y) > 0.0:
		var frac_x = face.x - floor(face.x)
		if abs(frac_x - 0.5) > 0.001 or abs(face.y - round(face.y)) > 0.001:
			printerr("FAILED: ", message, ". face=", face, " dir=", cat.current_dir)
			quit(1)
			return false
	return true
