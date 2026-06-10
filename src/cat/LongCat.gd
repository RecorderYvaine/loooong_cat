extends Node2D
class_name LongCat

@export var speed: float = 40.0
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

func _ready() -> void:
    # 初始的 path[0] 也就是身体生长的起点，直接设在底座(BottomBody)的中心
    path.append(Vector2(0, 0))
    path.append(Vector2(0, -11))
    current_dir = Vector2.UP
    
    bottom_sprite.position = path[0]
    tail_sprite.position = bottom_sprite.position + Vector2(7.5, 0)
    update_visuals()

func _process(delta: float) -> void:
    var input_dir = get_input_dir()
    
    if input_dir != Vector2.ZERO:
        move_cat(input_dir, delta)
        update_head_frame(input_dir)
    else:
        # Idle frame (正面脸)
        head_sprite.frame = 0

    update_visuals()

func get_input_dir() -> Vector2:
    if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): return Vector2.UP
    if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): return Vector2.DOWN
    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): return Vector2.LEFT
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): return Vector2.RIGHT
    return Vector2.ZERO

func get_allowed_step(start_pos: Vector2, dir: Vector2, requested_step: float) -> float:
    var allowed_step = requested_step
    # 不检测最后两段（分别是当前正在伸长的一段，以及它的上一个拐角相连的段，避免一开始就卡住自己）
    var check_points = path.size() - 3 
    
    for i in range(check_points):
        var p1 = path[i]
        var p2 = path[i+1]
        var thickness = 8.5 # 身体粗 9，给 0.5 的容错，半径 4.25+4.25=8.5
        
        if dir.x != 0: 
            if p1.x == p2.x: # 竖向身体
                var seg_x = p1.x
                var min_y = min(p1.y, p2.y) - thickness
                var max_y = max(p1.y, p2.y) + thickness
                if start_pos.y >= min_y and start_pos.y <= max_y:
                    if dir.x > 0 and start_pos.x <= seg_x - thickness:
                        allowed_step = min(allowed_step, seg_x - thickness - start_pos.x)
                    elif dir.x < 0 and start_pos.x >= seg_x + thickness:
                        allowed_step = min(allowed_step, start_pos.x - (seg_x + thickness))
            else: # 横向身体
                var min_x = min(p1.x, p2.x) - thickness
                var max_x = max(p1.x, p2.x) + thickness
                if abs(start_pos.y - p1.y) < thickness:
                    if dir.x > 0 and start_pos.x <= min_x:
                        allowed_step = min(allowed_step, min_x - start_pos.x)
                    elif dir.x < 0 and start_pos.x >= max_x:
                        allowed_step = min(allowed_step, start_pos.x - max_x)
                        
        elif dir.y != 0: 
            if p1.y == p2.y: # 横向身体
                var seg_y = p1.y
                var min_x = min(p1.x, p2.x) - thickness
                var max_x = max(p1.x, p2.x) + thickness
                if start_pos.x >= min_x and start_pos.x <= max_x:
                    if dir.y > 0 and start_pos.y <= seg_y - thickness:
                        allowed_step = min(allowed_step, seg_y - thickness - start_pos.y)
                    elif dir.y < 0 and start_pos.y >= seg_y + thickness:
                        allowed_step = min(allowed_step, start_pos.y - (seg_y + thickness))
            else: # 竖向身体
                var min_y = min(p1.y, p2.y) - thickness
                var max_y = max(p1.y, p2.y) + thickness
                if abs(start_pos.x - p1.x) < thickness:
                    if dir.y > 0 and start_pos.y <= min_y:
                        allowed_step = min(allowed_step, min_y - start_pos.y)
                    elif dir.y < 0 and start_pos.y >= max_y:
                        allowed_step = min(allowed_step, start_pos.y - max_y)
                        
    return max(0.0, allowed_step)

func move_cat(input_dir: Vector2, delta: float) -> void:
    var head_pos = path[-1]
    var prev_pos = path[-2]
    var seg_dir = (head_pos - prev_pos).normalized()
    if seg_dir == Vector2.ZERO: seg_dir = current_dir
    
    var step = speed * delta
    
    if input_dir == seg_dir:
        # 向前伸长
        var allowed = get_allowed_step(path[-1], input_dir, step)
        path[-1] += input_dir * allowed
        current_dir = input_dir
    elif input_dir == -seg_dir:
        # 向后缩回 (无需碰撞检测)
        path[-1] += input_dir * step
        
        # 缩回过弯的吸附逻辑
        if path.size() > 2:
            var dist_to_prev = path[-1].distance_to(path[-2])
            # 把容错像素放大到 6.0，让回退更容易
            if (path[-1] - path[-2]).dot(seg_dir) <= 0 or dist_to_prev < 6.0:
                path.pop_back()
                path[-1] = prev_pos
                current_dir = (path[-1] - path[-2]).normalized()
                
                if turns_data.size() > 0:
                    var last_turn = turns_data.pop_back()
                    if last_turn.node:
                        last_turn.node.queue_free()
        else:
            if (path[-1] - path[0]).dot(seg_dir) <= 0:
                path[-1] = path[0] + seg_dir * 1.0
    else:
        # 转弯！
        var dist_from_last_corner = head_pos.distance_to(prev_pos)
        if dist_from_last_corner >= MIN_TURN_DIST:
            var allowed = get_allowed_step(head_pos, input_dir, step)
            # 只有允许转弯且有移动空间时才真正转弯
            if allowed > 0.0:
                var prev_dir = seg_dir
                var cross = prev_dir.x * input_dir.y - prev_dir.y * input_dir.x
                
                path.append(head_pos)
                current_dir = input_dir
                path[-1] += input_dir * allowed
                
                var turn_sprite = Sprite2D.new()
                turn_sprite.texture = turn_tex
                turn_sprite.region_enabled = true
                # 永远使用下半截 (9 到 18) 的动画帧
                turn_sprite.region_rect = Rect2(0, 9, 63, 9)
                
                # 使用水平翻转来区分顺时针和逆时针
                if cross > 0:
                    turn_sprite.flip_h = false # 顺时针不翻转 (原生图是CW)
                else:
                    turn_sprite.flip_h = true # 逆时针翻转
                    
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
        head_sprite.frame = 3 # 向上看 (相对猫头是往前)
    elif input_dir == -seg_dir:
        head_sprite.frame = 4 # 向下看 (相对猫头是往后)
    else:
        head_sprite.frame = 3

func update_visuals() -> void:
    head_group.position = path[-1]
    
    # 平滑旋转猫头组 (包含头和 TopBody)
    var target_rotation = current_dir.angle() - (-PI/2)
    var current_rot = head_group.rotation
    
    # 防止 -PI 和 PI 导致的 360 度大回旋
    var rot_diff = wrapf(target_rotation - current_rot, -PI, PI)
    head_group.rotation = current_rot + rot_diff * (20.0 * get_process_delta_time())
    
    # 渲染中间连续的身体 (MiddleSegments)
    for child in middle_segments.get_children():
        child.queue_free()
        
    for i in range(path.size() - 1):
        var p1 = path[i]
        var p2 = path[i+1]
        var dir = (p2 - p1).normalized()
        
        # 只在猫头位置做缩进，给 TopBody 留出空间 (TopBody 远端在头部后方 5.5 + 1.5 = 7.0 的位置)
        if i == path.size() - 2:
            p2 -= dir * 7.0 
            
        var dist = p1.distance_to(p2)
        if dist > 0.0:
            var seg = Sprite2D.new()
            seg.texture = middle_tex
            seg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
            seg.region_enabled = true
            seg.region_rect = Rect2(0, 0, 9, dist) 
            seg.position = (p1 + p2) / 2.0
            seg.rotation = dir.angle() - (-PI/2)
            middle_segments.add_child(seg)
            
    # 根据距离自动播放转弯处的帧动画
    for i in range(turns_data.size()):
        var t_data = turns_data[i]
        var frame = 0
        if i == turns_data.size() - 1:
            var dist = path[-1].distance_to(t_data.node.position)
            frame = clamp(6 - int((dist / MIN_TURN_DIST) * 7.0), 0, 6)
        t_data.node.frame = frame
