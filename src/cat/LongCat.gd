extends Node2D
class_name LongCat

@export var speed: float = 60.0
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

func move_cat(input_dir: Vector2, delta: float) -> void:
    var head_pos = path[-1]
    var prev_pos = path[-2]
    var seg_dir = (head_pos - prev_pos).normalized()
    if seg_dir == Vector2.ZERO: seg_dir = current_dir
    
    var step = speed * delta
    
    if input_dir == seg_dir:
        # 向前伸长
        path[-1] += input_dir * step
        current_dir = input_dir
    elif input_dir == -seg_dir:
        # 向后缩回
        path[-1] += input_dir * step
        
        # 缩回过弯的吸附逻辑
        if path.size() > 2:
            var dist_to_prev = path[-1].distance_to(path[-2])
            if (path[-1] - path[-2]).dot(seg_dir) <= 0 or dist_to_prev < 3.0:
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
            var prev_dir = seg_dir
            var cross = prev_dir.x * input_dir.y - prev_dir.y * input_dir.x
            
            path.append(head_pos)
            current_dir = input_dir
            path[-1] += input_dir * step
            
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
        
        # 严格计算截断以防止露出接缝：
        # 拐角是一个 9x9 的方块，所以前后都要缩进 4.5 像素才刚好碰到拐角的边缘。
        # 对于底座 (path[0])，不需要缩进那么多，因为尾巴和它连在一起。
        if i > 0:
            p1 += dir * 4.5
            
        # 对于猫头所在的最前端 (path.size() - 2)，TopBody 占了 3 个像素高度。
        # 猫头中心偏移 6.5，为了让 TopBody 紧贴 MiddleBody，我们要减去正好留给 TopBody 的空间。
        if i < path.size() - 2:
            p2 -= dir * 4.5
        else:
            p2 -= dir * 8.0 # 给 TopBody 留出空间
            
        var dist = p1.distance_to(p2)
        # 只有距离 > 0 才画，避免出现反向绘制导致错位
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
            # 头离开拐角越远，动画越接近结束（0帧）。
            # dist 从 0 变到 MIN_TURN_DIST 时，frame 从 6 变到 0
            frame = clamp(6 - int((dist / MIN_TURN_DIST) * 7.0), 0, 6)
        t_data.node.frame = frame
