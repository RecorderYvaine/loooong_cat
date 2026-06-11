extends Node2D
class_name LongCat

@export var speed: float = 40.0
const MIN_TURN_DIST: float = 9.0
const TURN_CLEARANCE: float = 4.0
const TURN_EXIT_ADVANCE: float = 2.0
const HIDDEN_TOP_BODY_HEAD_GAP: float = 5.0
const BODY_COLLISION_HALF_WIDTH: float = 4.5
const HEAD_COLLISION_HALF_WIDTH: float = 5.5
const COLLISION_CLEARANCE: float = BODY_COLLISION_HALF_WIDTH + HEAD_COLLISION_HALF_WIDTH
const TURN_READY_DIST: float = MIN_TURN_DIST + TURN_EXIT_ADVANCE
const REVERSE_POP_INPUT_LOCK_TIME: float = 0.12

# 以 HeadGroup 节点原点为基准，提取猫脸中心点作为旋转与移动核心
const FACE_LOCAL = Vector2(0.5, -5.5)

var path: Array[Vector2] = []
var current_dir: Vector2 = Vector2.UP

@onready var head_group = $HeadGroup
@onready var head_sprite = $HeadGroup/HeadSprite
@onready var top_body = $HeadGroup/TopBody
@onready var middle_segments = $MiddleSegments
@onready var turn_segments = $TurnSegments
@onready var bottom_sprite = $BottomBody
@onready var tail_sprite = $TailSprite

var middle_tex = preload("res://assets/cat_middle_body.png")
var turn_tex = preload("res://assets/cat_turn_body.png")

var turns_data: Array[Dictionary] = []
var blocked_input_dir: Vector2 = Vector2.ZERO
var prev_raw_input: Vector2 = Vector2.ZERO
var auto_turn_dir: Vector2 = Vector2.ZERO
var queued_turn_dir: Vector2 = Vector2.ZERO
var preferred_input_dir: Vector2 = Vector2.ZERO
var retract_active_turn_on_release: bool = false
var reverse_pop_input_lock_dir: Vector2 = Vector2.ZERO
var reverse_pop_input_lock_time: float = 0.0

func _ready() -> void:
	turn_segments.position = Vector2.ZERO
	middle_segments.position = Vector2.ZERO
	
	# 完全信任编辑器里的排版，BottomBody 的位置是不居中的 (-4, 0)
	# 计算它顶部中心的绝对位置作为路径起点
	var start_point = bottom_sprite.position + Vector2(4.5, 0.0)
	
	path.append(start_point)
	# 初始状态下猫没有中间身子，直接计算脸的绝对位置。
	path.append(start_point + Vector2(0, -8.0))
	current_dir = Vector2.UP
	update_visuals()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		preferred_input_dir = Vector2.UP
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		preferred_input_dir = Vector2.DOWN
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		preferred_input_dir = Vector2.LEFT
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		preferred_input_dir = Vector2.RIGHT

func _process(delta: float) -> void:
	var pressed_dirs = get_pressed_input_dirs()
	var raw_input = get_input_dir()
	raw_input = apply_reverse_pop_input_lock(raw_input, delta)
	
	var in_turn = is_active_turn_segment()
	var head_dist = get_head_segment_length()
			
	if in_turn:
		if raw_input == Vector2.ZERO:
			if retract_active_turn_on_release:
				auto_turn_dir = -current_dir
			else:
				auto_turn_dir = current_dir
		elif raw_input != current_dir and raw_input != -current_dir:
			queued_turn_dir = raw_input
			auto_turn_dir = current_dir
			retract_active_turn_on_release = false
		elif raw_input == current_dir or raw_input == -current_dir:
			auto_turn_dir = raw_input
			retract_active_turn_on_release = raw_input == -current_dir
		elif auto_turn_dir != current_dir and auto_turn_dir != -current_dir:
			auto_turn_dir = current_dir
		raw_input = auto_turn_dir
	else:
		auto_turn_dir = Vector2.ZERO
		retract_active_turn_on_release = false
		if queued_turn_dir != Vector2.ZERO:
			if get_head_segment_length() >= TURN_READY_DIST:
				raw_input = queued_turn_dir
				queued_turn_dir = Vector2.ZERO
			else:
				raw_input = current_dir
		elif raw_input == Vector2.ZERO and path.size() > 2 and head_dist >= MIN_TURN_DIST and head_dist < TURN_READY_DIST:
			raw_input = current_dir
		
	var is_tap = false
	if not in_turn:
		is_tap = (raw_input != Vector2.ZERO and prev_raw_input != raw_input)
	prev_raw_input = raw_input
	
	var input_dir = raw_input
	
	if raw_input == Vector2.ZERO:
		blocked_input_dir = Vector2.ZERO
	elif raw_input != current_dir and raw_input != -current_dir:
		var can_use_raw_input = can_progress_with_input(raw_input, max(speed * delta, 1.0), should_fallback_to_current_dir(raw_input, pressed_dirs))
		if can_use_raw_input:
			blocked_input_dir = Vector2.ZERO
		elif should_fallback_to_current_dir(raw_input, pressed_dirs):
			input_dir = current_dir
		else:
			blocked_input_dir = raw_input
			input_dir = Vector2.ZERO
	elif raw_input == blocked_input_dir:
		if should_fallback_to_current_dir(raw_input, pressed_dirs):
			input_dir = current_dir
		else:
			input_dir = Vector2.ZERO
	else:
		blocked_input_dir = Vector2.ZERO

	if input_dir != Vector2.ZERO:
		var step = speed * delta
		if is_tap:
			step = max(step, 1.0)
			
		move_cat(input_dir, step)
		update_head_frame(input_dir)

		if queued_turn_dir != Vector2.ZERO and input_dir == current_dir and get_head_segment_length() >= TURN_READY_DIST:
			var turn_dir = queued_turn_dir
			queued_turn_dir = Vector2.ZERO
			move_cat(turn_dir, max(step, 1.0))
			update_head_frame(turn_dir)
	else:
		snap_head_to_pixel_grid()
		head_sprite.frame = 0 

	update_visuals()

func get_input_dir() -> Vector2:
	var pressed_dirs = get_pressed_input_dirs()
	return select_preferred_input_dir(pressed_dirs)

func apply_reverse_pop_input_lock(input_dir: Vector2, delta: float) -> Vector2:
	if reverse_pop_input_lock_time <= 0.0:
		return input_dir

	if input_dir != reverse_pop_input_lock_dir:
		reverse_pop_input_lock_time = 0.0
		reverse_pop_input_lock_dir = Vector2.ZERO
		return input_dir

	reverse_pop_input_lock_time -= delta
	if reverse_pop_input_lock_time <= 0.0:
		reverse_pop_input_lock_dir = Vector2.ZERO
		return input_dir
	return Vector2.ZERO

func get_pressed_input_dirs() -> Array[Vector2]:
	var pressed_dirs: Array[Vector2] = []
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		pressed_dirs.append(Vector2.UP)
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		pressed_dirs.append(Vector2.DOWN)
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		pressed_dirs.append(Vector2.LEFT)
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		pressed_dirs.append(Vector2.RIGHT)
	return pressed_dirs

func select_preferred_input_dir(pressed_dirs: Array[Vector2]) -> Vector2:
	if pressed_dirs.is_empty():
		preferred_input_dir = Vector2.ZERO
		return Vector2.ZERO
	if pressed_dirs.size() == 1:
		preferred_input_dir = pressed_dirs[0]
		return pressed_dirs[0]
	if pressed_dirs.has(preferred_input_dir):
		return preferred_input_dir
	return pressed_dirs[0]

func should_fallback_to_current_dir(input_dir: Vector2, pressed_dirs: Array[Vector2]) -> bool:
	return input_dir != Vector2.ZERO and input_dir != current_dir and input_dir != -current_dir and pressed_dirs.has(current_dir)

func can_progress_with_input(input_dir: Vector2, step: float, allow_forward_advance: bool) -> bool:
	if input_dir == Vector2.ZERO or path.size() < 2:
		return false

	var head_pos = path[-1]
	var prev_pos = path[-2]
	var seg_dir = (head_pos - prev_pos).normalized()
	if seg_dir == Vector2.ZERO:
		seg_dir = current_dir

	if input_dir == seg_dir:
		return get_allowed_step(head_pos, input_dir, step) > 0.0
	if input_dir == -seg_dir:
		return true

	var dist_from_last_corner = head_pos.distance_to(prev_pos)
	if allow_forward_advance and dist_from_last_corner < TURN_READY_DIST:
		var advance = min(step, TURN_READY_DIST - dist_from_last_corner)
		if get_allowed_step(head_pos, seg_dir, advance) > 0.0:
			return true

	return can_start_turn(head_pos, input_dir)

func get_allowed_step(start_pos: Vector2, dir: Vector2, requested_step: float) -> float:
	var allowed_step = requested_step
	var check_points = max(0, path.size() - 3)
	
	for i in range(check_points):
		var p1 = path[i]
		var p2 = path[i+1]
		var bounds = get_segment_collision_bounds(p1, p2)
		if is_point_in_bounds(start_pos, bounds):
			if can_move_from_inside_segment_bounds(start_pos, dir, requested_step, p1, p2):
				continue
			allowed_step = 0.0
			continue
		
		if dir.x != 0: 
			if start_pos.y >= bounds.position.y and start_pos.y <= bounds.end.y:
				if dir.x > 0 and start_pos.x < bounds.position.x:
					allowed_step = min(allowed_step, bounds.position.x - start_pos.x)
				elif dir.x < 0 and start_pos.x > bounds.end.x:
					allowed_step = min(allowed_step, start_pos.x - bounds.end.x)
						
		elif dir.y != 0: 
			if start_pos.x >= bounds.position.x and start_pos.x <= bounds.end.x:
				if dir.y > 0 and start_pos.y < bounds.position.y:
					allowed_step = min(allowed_step, bounds.position.y - start_pos.y)
				elif dir.y < 0 and start_pos.y > bounds.end.y:
					allowed_step = min(allowed_step, start_pos.y - bounds.end.y)
						
	return max(0.0, allowed_step)

func get_segment_collision_bounds(p1: Vector2, p2: Vector2) -> Rect2:
	var min_pos = Vector2(min(p1.x, p2.x), min(p1.y, p2.y)) - Vector2(COLLISION_CLEARANCE, COLLISION_CLEARANCE)
	var max_pos = Vector2(max(p1.x, p2.x), max(p1.y, p2.y)) + Vector2(COLLISION_CLEARANCE, COLLISION_CLEARANCE)
	return Rect2(min_pos, max_pos - min_pos)

func is_point_in_bounds(pos: Vector2, bounds: Rect2) -> bool:
	return pos.x >= bounds.position.x and pos.x <= bounds.end.x and pos.y >= bounds.position.y and pos.y <= bounds.end.y

func can_move_from_inside_segment_bounds(start_pos: Vector2, dir: Vector2, step: float, p1: Vector2, p2: Vector2) -> bool:
	var end_pos = start_pos + dir * step
	if is_moving_deeper_into_segment_bounds(start_pos, end_pos, p1, p2):
		return false
	if is_dir_parallel_to_segment(dir, p1, p2):
		return false
	return true

func is_moving_deeper_into_segment_bounds(start_pos: Vector2, end_pos: Vector2, p1: Vector2, p2: Vector2) -> bool:
	return get_distance_from_segment_centerline(end_pos, p1, p2) < get_distance_from_segment_centerline(start_pos, p1, p2) - 0.001

func get_distance_from_segment_centerline(pos: Vector2, p1: Vector2, p2: Vector2) -> float:
	var segment = p2 - p1
	if abs(segment.x) >= abs(segment.y):
		var center_y = (p1.y + p2.y) / 2.0
		return abs(pos.y - center_y)

	var center_x = (p1.x + p2.x) / 2.0
	return abs(pos.x - center_x)

func is_dir_parallel_to_segment(dir: Vector2, p1: Vector2, p2: Vector2) -> bool:
	var segment = p2 - p1
	if abs(segment.x) >= abs(segment.y):
		return abs(dir.x) > 0.0
	return abs(dir.y) > 0.0

func can_start_turn(start_pos: Vector2, dir: Vector2) -> bool:
	var end_pos = start_pos + dir * MIN_TURN_DIST
	var check_points = max(0, path.size() - 3)

	for i in range(check_points):
		var p1 = path[i]
		var p2 = path[i+1]
		var bounds = get_segment_collision_bounds(p1, p2)
		var starts_inside = is_point_in_bounds(start_pos, bounds)
		if starts_inside:
			if not can_move_from_inside_segment_bounds(start_pos, dir, MIN_TURN_DIST, p1, p2):
				return false
			continue

		if dir.x != 0:
			if start_pos.y >= bounds.position.y and start_pos.y <= bounds.end.y:
				if dir.x > 0 and start_pos.x < bounds.position.x and start_pos.x + MIN_TURN_DIST > bounds.position.x:
					return false
				if dir.x < 0 and start_pos.x > bounds.end.x and start_pos.x - MIN_TURN_DIST < bounds.end.x:
					return false
		elif dir.y != 0:
			if start_pos.x >= bounds.position.x and start_pos.x <= bounds.end.x:
				if dir.y > 0 and start_pos.y < bounds.position.y and start_pos.y + MIN_TURN_DIST > bounds.position.y:
					return false
				if dir.y < 0 and start_pos.y > bounds.end.y and start_pos.y - MIN_TURN_DIST < bounds.end.y:
					return false

	return true

func get_head_segment_length() -> float:
	if path.size() < 2:
		return 0.0
	return path[-1].distance_to(path[-2])

func is_active_turn_segment() -> bool:
	if path.size() <= 2:
		return false
	var head_dist = get_head_segment_length()
	if head_dist < 0.0 or head_dist >= MIN_TURN_DIST:
		return false
	var incoming_dir = (path[-2] - path[-3]).normalized()
	var outgoing_dir = (path[-1] - path[-2]).normalized()
	if incoming_dir == Vector2.ZERO or outgoing_dir == Vector2.ZERO:
		return false
	return abs(incoming_dir.dot(outgoing_dir)) < 0.001

func snap_head_to_pixel_grid() -> void:
	if path.size() < 2:
		return
	var seg = path[-1] - path[-2]
	if abs(seg.x) > 0.001 and abs(seg.y) <= 0.001:
		path[-1] = Vector2(round(path[-1].x - 0.5) + 0.5, path[-2].y)
	elif abs(seg.y) > 0.001 and abs(seg.x) <= 0.001:
		path[-1] = Vector2(path[-2].x, round(path[-1].y))

func move_cat(input_dir: Vector2, step: float) -> void:
	var head_pos = path[-1]
	var prev_pos = path[-2]
	var seg_dir = (head_pos - prev_pos).normalized()
	if seg_dir == Vector2.ZERO: seg_dir = current_dir
	
	if input_dir == seg_dir:
		var allowed = get_allowed_step(path[-1], input_dir, step)
		if allowed <= 0.0 and is_active_turn_segment() and can_start_turn(path[-1], input_dir):
			allowed = step
		path[-1] += input_dir * allowed
		current_dir = input_dir
	elif input_dir == -seg_dir:
		if path.size() == 2:
			var dist_to_base = path[-1].distance_to(path[0])
			if dist_to_base - step <= 8.0:
				path[-1] = path[0] + seg_dir * 8.0
				return
			else:
				path[-1] += input_dir * step
		else:
			var dist_to_prev = path[-1].distance_to(path[-2])
			if dist_to_prev <= step + 0.001:
				path.pop_back()
				path[-1] = prev_pos
				current_dir = (path[-1] - path[-2]).normalized()

				if turns_data.size() > 0:
					var last_turn = turns_data.pop_back()
					if last_turn.node:
						last_turn.node.queue_free()

				blocked_input_dir = Vector2.ZERO
				auto_turn_dir = Vector2.ZERO
				queued_turn_dir = Vector2.ZERO
				retract_active_turn_on_release = false
				reverse_pop_input_lock_dir = input_dir
				reverse_pop_input_lock_time = REVERSE_POP_INPUT_LOCK_TIME
			else:
				path[-1] += input_dir * step
				if is_active_turn_segment():
					retract_active_turn_on_release = true
	else:
		var dist_from_last_corner = head_pos.distance_to(prev_pos)
		if dist_from_last_corner < TURN_READY_DIST:
			var advance = min(step, TURN_READY_DIST - dist_from_last_corner)
			var allowed_advance = get_allowed_step(head_pos, seg_dir, advance)
			if allowed_advance > 0.0:
				path[-1] += seg_dir * allowed_advance
				current_dir = seg_dir
				if allowed_advance < advance:
					blocked_input_dir = input_dir
				return

			if not can_start_turn(head_pos, input_dir):
				blocked_input_dir = input_dir
				auto_turn_dir = Vector2.ZERO
				queued_turn_dir = Vector2.ZERO
				return

			blocked_input_dir = Vector2.ZERO

		if not can_start_turn(head_pos, input_dir):
			blocked_input_dir = input_dir
			auto_turn_dir = Vector2.ZERO
			queued_turn_dir = Vector2.ZERO
			return

		var allowed = get_allowed_step(head_pos, input_dir, step)
		if allowed <= 0.0 and can_start_turn(head_pos, input_dir):
			allowed = step
		if allowed > 0.001:
			var prev_dir = seg_dir
			var cross = prev_dir.x * input_dir.y - prev_dir.y * input_dir.x

			path.append(head_pos)
			current_dir = input_dir
			path[-1] += input_dir * allowed

			var turn_sprite = Sprite2D.new()
			turn_sprite.texture = turn_tex
			turn_sprite.region_enabled = true
			turn_sprite.region_rect = Rect2(0, 9, 63, 9)

			if cross > 0:
				turn_sprite.flip_h = false
			else:
				turn_sprite.flip_h = true

			turn_sprite.hframes = 7
			turn_sprite.position = pixel_align_center(head_pos)
			turn_sprite.rotation = prev_dir.angle() + (PI/2)
			turn_segments.add_child(turn_sprite)
			turns_data.append({"node": turn_sprite})
		else:
			blocked_input_dir = input_dir
			auto_turn_dir = Vector2.ZERO
			queued_turn_dir = Vector2.ZERO

func pixel_align_center(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x) + 0.5, floor(pos.y) + 0.5)

func pixel_align_body_segment(pos: Vector2, dir: Vector2) -> Vector2:
	var aligned = pos
	if abs(dir.x) > 0.0:
		aligned.y = floor(aligned.y) + 0.5
	elif abs(dir.y) > 0.0:
		aligned.x = floor(aligned.x) + 0.5
	return aligned

func pixel_align_face_pos(pos: Vector2, dir: Vector2) -> Vector2:
	if abs(dir.x) > 0.0:
		return Vector2(round(pos.x), floor(pos.y) + 0.5)
	if abs(dir.y) > 0.0:
		return Vector2(floor(pos.x) + 0.5, round(pos.y))
	return pos

func get_turn_clearance(progress: float) -> float:
	return round(TURN_CLEARANCE * clamp(progress, 0.0, 1.0))

func update_head_frame(input_dir: Vector2) -> void:
	if is_active_turn_segment():
		head_sprite.frame = 3
		return

	var seg_dir = current_dir
	if path.size() > 1:
		seg_dir = (path[-1] - path[-2]).normalized()
		if seg_dir == Vector2.ZERO: seg_dir = current_dir
		
	if input_dir == seg_dir:
		head_sprite.frame = 3 
	elif input_dir == -seg_dir:
		head_sprite.frame = 4 
	else:
		head_sprite.frame = 3

func update_visuals() -> void:
	var in_turn = is_active_turn_segment()
	var head_dist = 0.0
	var turn_progress = 1.0
	var active_corner_index = -1
	if in_turn:
		head_dist = path[-1].distance_to(path[-2])
		active_corner_index = path.size() - 2
		turn_progress = clamp(head_dist / MIN_TURN_DIST, 0.0, 1.0)

	top_body.visible = not in_turn

	# 转弯时保留猫头插值旋转；直线时只做像素对齐，避免 90 度后半像素采样拉伸纹理。
	var target_rotation = current_dir.angle() - (-PI/2)
	if in_turn:
		var prev_dir = (path[-2] - path[-3]).normalized()
		if prev_dir == Vector2.ZERO: prev_dir = current_dir
		var prev_rot = prev_dir.angle() - (-PI/2)

		var diff = wrapf(target_rotation - prev_rot, -PI, PI)
		head_group.rotation = prev_rot + diff * turn_progress
	else:
		head_group.rotation = target_rotation

	var face_pos = path[-1]
	if not in_turn:
		face_pos = pixel_align_face_pos(path[-1], current_dir)
	head_group.position = face_pos - FACE_LOCAL.rotated(head_group.rotation)

	# 绘制直身子
	var seg_count = path.size() - 1
	var current_children = middle_segments.get_children()

	while current_children.size() < seg_count:
		var seg = Sprite2D.new()
		seg.texture = middle_tex
		seg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		seg.region_enabled = true
		middle_segments.add_child(seg)
		current_children.append(seg)

	for i in range(current_children.size()):
		var seg = current_children[i]
		if i >= seg_count:
			seg.visible = false
		else:
			var p1 = path[i]
			var p2 = path[i+1]
			var dir = (p2 - p1).normalized()
			if dir == Vector2.ZERO:
				seg.visible = false
				continue
				
			if i > 0:
				var start_clearance = TURN_CLEARANCE
				if i == active_corner_index:
					start_clearance = get_turn_clearance(turn_progress)
				p1 += dir * start_clearance
				
			if i == path.size() - 2:
				p2 -= dir * HIDDEN_TOP_BODY_HEAD_GAP
			else:
				var end_clearance = TURN_CLEARANCE
				if i + 1 == active_corner_index:
					end_clearance = get_turn_clearance(turn_progress)
				p2 -= dir * end_clearance
				
			var seg_vec = p2 - p1
			if seg_vec.dot(dir) > 0.0:
				var dist = seg_vec.length()
				seg.region_rect = Rect2(0, 0, 9, dist) 
				seg.position = pixel_align_body_segment((p1 + p2) / 2.0, dir)
				seg.rotation = dir.angle() - (-PI/2)
				seg.visible = true
			else:
				seg.visible = false

	for i in range(turns_data.size()):
		var t_data = turns_data[i]
		var frame = 0
		if i == turns_data.size() - 1:
			var dist = path[-1].distance_to(t_data.node.position)
			frame = clamp(6 - int((dist / MIN_TURN_DIST) * 7.0), 0, 6)
		t_data.node.frame = frame
