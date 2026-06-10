extends Node2D
class_name LongCat

@export var speed: float = 50.0
const MIN_TURN_DIST: float = 9.0

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

func _ready() -> void:
    path.append(Vector2(0, 0))
    path.append(Vector2(0, -11))
    current_dir = Vector2.UP
    
    bottom_sprite.position = path[0]
    tail_sprite.position = bottom_sprite.position + Vector2(7.5, 0)
    update_visuals()

func _process(delta: float) -> void:
    var raw_input = get_input_dir()
    var is_tap = (raw_input != Vector2.ZERO and prev_raw_input != raw_input)
    prev_raw_input = raw_input
    
    var input_dir = raw_input
    
    # 遇到拐角后的停顿逻辑：要求松开按键或换方向才能继续
    if raw_input == Vector2.ZERO:
        blocked_input_dir = Vector2.ZERO
    elif raw_input == blocked_input_dir:
        input_dir = Vector2.ZERO
    else:
        blocked_input_dir = Vector2.ZERO

    if input_dir != Vector2.ZERO:
        var step = speed * delta
        # 短按时至少走 1 像素，方便微调
        if is_tap:
            step = max(step, 1.0)
            
        move_cat(input_dir, step)
        update_head_frame(input_dir)
    else:
        head_sprite.frame = 0 # Idle

    update_visuals()

func get_input_dir() -> Vector2:
    if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): return Vector2.UP
    if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): return Vector2.DOWN
    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): return Vector2.LEFT
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): return Vector2.RIGHT
    return Vector2.ZERO

func get_allowed_step(start_pos: Vector2, dir: Vector2, requested_step: float) -> float:
    var allowed_step = requested_step
    var check_points = path.size() - 3 
    
    for i in range(check_points):
        var p1 = path[i]
        var p2 = path[i+1]
        var thickness = 8.5 
        
        if dir.x != 0: 
            if p1.x == p2.x: 
                var seg_x = p1.x
                var min_y = min(p1.y, p2.y) - thickness
                var max_y = max(p1.y, p2.y) + thickness
                if start_pos.y >= min_y and start_pos.y <= max_y:
                    if dir.x > 0 and start_pos.x <= seg_x - thickness:
                        allowed_step = min(allowed_step, seg_x - thickness - start_pos.x)
                    elif dir.x < 0 and start_pos.x >= seg_x + thickness:
                        allowed_step = min(allowed_step, start_pos.x - (seg_x + thickness))
            else: 
                var min_x = min(p1.x, p2.x) - thickness
                var max_x = max(p1.x, p2.x) + thickness
                if abs(start_pos.y - p1.y) < thickness:
                    if dir.x > 0 and start_pos.x <= min_x:
                        allowed_step = min(allowed_step, min_x - start_pos.x)
                    elif dir.x < 0 and start_pos.x >= max_x:
                        allowed_step = min(allowed_step, start_pos.x - max_x)
                        
        elif dir.y != 0: 
            if p1.y == p2.y: 
                var seg_y = p1.y
                var min_x = min(p1.x, p2.x) - thickness
                var max_x = max(p1.x, p2.x) + thickness
                if start_pos.x >= min_x and start_pos.x <= max_x:
                    if dir.y > 0 and start_pos.y <= seg_y - thickness:
                        allowed_step = min(allowed_step, seg_y - thickness - start_pos.y)
                    elif dir.y < 0 and start_pos.y >= seg_y + thickness:
                        allowed_step = min(allowed_step, start_pos.y - (seg_y + thickness))
            else: 
                var min_y = min(p1.y, p2.y) - thickness
                var max_y = max(p1.y, p2.y) + thickness
                if abs(start_pos.x - p1.x) < thickness:
                    if dir.y > 0 and start_pos.y <= min_y:
                        allowed_step = min(allowed_step, min_y - start_pos.y)
                    elif dir.y < 0 and start_pos.y >= max_y:
                        allowed_step = min(allowed_step, start_pos.y - max_y)
                        
    return max(0.0, allowed_step)

func move_cat(input_dir: Vector2, step: float) -> void:
    var head_pos = path[-1]
    var prev_pos = path[-2]
    var seg_dir = (head_pos - prev_pos).normalized()
    if seg_dir == Vector2.ZERO: seg_dir = current_dir
    
    if input_dir == seg_dir:
        var allowed = get_allowed_step(path[-1], input_dir, step)
        path[-1] += input_dir * allowed
        current_dir = input_dir
    elif input_dir == -seg_dir:
        var dist_to_prev = path[-1].distance_to(path[-2])
        # 缩小判定范围到 step 内：确保缩回时会播放完整的倒放动画，直到完全重合才消除拐角
        if dist_to_prev <= step:
            if path.size() > 2:
                path.pop_back()
                path[-1] = prev_pos
                current_dir = (path[-1] - path[-2]).normalized()
                
                if turns_data.size() > 0:
                    var last_turn = turns_data.pop_back()
                    if last_turn.node:
                        last_turn.node.queue_free()
                
                # 记录阻挡方向，迫使用户松开按键后才能向新方向延展
                blocked_input_dir = input_dir
            else:
                path[-1] = path[0] + seg_dir * 1.0
        else:
            path[-1] += input_dir * step
    else:
        var dist_from_last_corner = head_pos.distance_to(prev_pos)
        if dist_from_last_corner >= MIN_TURN_DIST:
            var allowed = get_allowed_step(head_pos, input_dir, step)
            if allowed > 0.0:
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
                turn_sprite.position = head_pos
                turn_sprite.rotation = prev_dir.angle() + (PI/2)
                turn_segments.add_child(turn_sprite)
                turns_data.append({"node": turn_sprite})

func update_head_frame(input_dir: Vector2) -> void:
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
    head_group.position = path[-1]
    
    var target_rotation = current_dir.angle() - (-PI/2)
    var current_rot = head_group.rotation
    var rot_diff = wrapf(target_rotation - current_rot, -PI, PI)
    head_group.rotation = current_rot + rot_diff * (20.0 * get_process_delta_time())
    
    top_body.position = -current_dir * 5.5
    top_body.rotation = current_dir.angle() - (-PI/2)
    
    # 修复多余像素和错位：复用现有的节点，不再每帧 queue_free() 整个列表
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
            
            if i == path.size() - 2:
                p2 -= dir * 7.0 
                
            var dist = p1.distance_to(p2)
            if dist > 0.0:
                seg.region_rect = Rect2(0, 0, 9, dist) 
                seg.position = (p1 + p2) / 2.0
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