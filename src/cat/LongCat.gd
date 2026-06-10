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

var middle_tex = preload("res://assets/cat_middle_body.png")
var turn_tex = preload("res://assets/cat_turn_body.png")

var turns_data: Array[Dictionary] = []

func _ready() -> void:
    # 让初始的 path[0] 也就是身体生长的起点，对齐在底座(BottomBody)的偏左侧
    path.append(Vector2(0, 11))
    path.append(Vector2(0, 0))
    current_dir = Vector2.UP
    
    # 将底座稍微往右偏移，这样轨迹生成时就相当于靠在它的最左边
    bottom_sprite.position = path[0] + Vector2(3, 0)
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
            # 如果越过了上一个拐角，或者离拐角距离小于 2 个像素（微调吸附），就吃掉这个拐角
            if (path[-1] - path[-2]).dot(seg_dir) <= 0 or dist_to_prev < 2.0:
                path.pop_back()
                path[-1] = prev_pos
                current_dir = (path[-1] - path[-2]).normalized()
                
                if turns_data.size() > 0:
                    var last_turn = turns_data.pop_back()
                    if last_turn.node:
                        last_turn.node.queue_free()
        else:
            # 防止缩回超过原点
            if (path[-1] - path[0]).dot(seg_dir) <= 0:
                path[-1] = path[0] + seg_dir * 1.0
    else:
        # 转弯！
        var dist_from_last_corner = head_pos.distance_to(prev_pos)
        if dist_from_last_corner >= MIN_TURN_DIST:
            path.append(head_pos)
            current_dir = input_dir
            path[-1] += input_dir * step
            
            var turn_sprite = Sprite2D.new()
            turn_sprite.texture = turn_tex
            turn_sprite.region_enabled = true
            turn_sprite.region_rect = Rect2(0, 0, 63, 9) # 取63x18图片的上半部分 63x9
            turn_sprite.hframes = 7
            turn_sprite.position = head_pos
            turn_sprite.rotation = input_dir.angle() - (-PI/2) # 旋转拐角贴图方向
            turn_segments.add_child(turn_sprite)
            turns_data.append({"node": turn_sprite})

func update_head_frame(input_dir: Vector2) -> void:
    # 严格按照移动方向切猫头的 1-4 帧 (不旋转猫头节点，只换眼睛方向)
    if input_dir == Vector2.LEFT: head_sprite.frame = 1
    elif input_dir == Vector2.RIGHT: head_sprite.frame = 2
    elif input_dir == Vector2.UP: head_sprite.frame = 3
    elif input_dir == Vector2.DOWN: head_sprite.frame = 4

func update_visuals() -> void:
    # 猫头永远在最前，并且没有任何奇怪的 90 度强行旋转
    head_group.position = path[-1]
    head_group.rotation = 0 
    
    # 调整猫的"上半身(TopBody)"，让它根据移动方向永远接在头部的后方
    top_body.position = -current_dir * 6.5
    top_body.rotation = current_dir.angle() - (-PI/2)
    
    # 渲染中间连续的身体 (MiddleSegments)
    for child in middle_segments.get_children():
        child.queue_free()
        
    for i in range(path.size() - 1):
        var p1 = path[i]
        var p2 = path[i+1]
        
        var dist = p1.distance_to(p2)
        if dist > 0.5:
            var seg = Sprite2D.new()
            seg.texture = middle_tex
            seg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
            seg.region_enabled = true
            # 将 9x1 的像素图通过 region_rect 的高度拉伸，实现无缝平铺
            # dist + 2.0 用于产生微小重叠，防止出现 1 像素的视觉裂缝
            seg.region_rect = Rect2(0, 0, 9, dist + 2.0) 
            seg.position = (p1 + p2) / 2.0
            seg.rotation = (p2 - p1).angle() - (-PI/2)
            middle_segments.add_child(seg)
            
    # 根据距离自动播放转弯处的帧动画
    for i in range(turns_data.size()):
        var t_data = turns_data[i]
        var frame = 0
        if i == turns_data.size() - 1:
            var dist = path[-1].distance_to(t_data.node.position)
            # 距离映射到 6 到 0 帧
            frame = clamp(6 - int((dist / MIN_TURN_DIST) * 7.0), 0, 6)
        t_data.node.frame = frame
