extends Node2D
class_name LongCat

@export var speed: float = 120.0
const MIN_TURN_DIST: float = 16.0

var path: Array[Vector2] = []
var current_dir: Vector2 = Vector2.UP

@onready var head_group = $HeadGroup
@onready var head_sprite = $HeadGroup/HeadSprite
@onready var middle_line = $MiddleLine
@onready var turn_segments = $TurnSegments
@onready var bottom_sprite = $BottomBody

var turn_tex = preload("res://assets/cat_turn_body.png")
var turns_data: Array[Dictionary] = [] 

func _ready() -> void:
    # Initialize path with starting position
    path.append(Vector2.ZERO)
    path.append(Vector2(0, -10)) 
    current_dir = Vector2.UP
    update_visuals()

func _process(delta: float) -> void:
    var input_dir = get_input_dir()
    
    if input_dir != Vector2.ZERO:
        move_cat(input_dir, delta)
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

func move_cat(input_dir: Vector2, delta: float) -> void:
    var head_pos = path[-1]
    var prev_pos = path[-2]
    var seg_dir = (head_pos - prev_pos).normalized()
    if seg_dir == Vector2.ZERO: seg_dir = current_dir
    
    var step = speed * delta
    
    if input_dir == seg_dir:
        # Extend forward
        path[-1] += input_dir * step
        current_dir = input_dir
        # Check if we should absorb a corner when moving forward (if path > 2 and moving away from prev corner)
        # Actually forward means extending the current segment, no corner logic needed.
    elif input_dir == -seg_dir:
        # Retract
        path[-1] += input_dir * step
        
        # Are we retracting past the previous corner?
        if path.size() > 2:
            # (head_pos - prev_pos) dot seg_dir <= 0 means we've crossed prev_pos
            if (path[-1] - path[-2]).dot(seg_dir) <= 0:
                # We reached the corner. Remove it!
                path.pop_back()
                path[-1] = prev_pos
                current_dir = (path[-1] - path[-2]).normalized()
                
                if turns_data.size() > 0:
                    var last_turn = turns_data.pop_back()
                    if last_turn.node:
                        last_turn.node.queue_free()
        else:
            # Prevent retracting past the bottom body
            if (path[-1] - path[0]).dot(seg_dir) <= 0:
                path[-1] = path[0] + seg_dir * 1.0
    else:
        # Turning!
        var dist_from_last_corner = head_pos.distance_to(prev_pos)
        if dist_from_last_corner >= MIN_TURN_DIST:
            # Add corner
            path.append(head_pos)
            current_dir = input_dir
            path[-1] += input_dir * step
            
            # Create Turn Sprite
            var turn_sprite = Sprite2D.new()
            turn_sprite.texture = turn_tex
            turn_sprite.hframes = 7
            turn_sprite.position = head_pos
            turn_sprite.rotation = input_dir.angle() - (PI/2) # adjust rotation as needed
            turn_segments.add_child(turn_sprite)
            turns_data.append({"node": turn_sprite})

func update_head_frame(input_dir: Vector2) -> void:
    var seg_dir = current_dir
    if path.size() > 1:
        seg_dir = (path[-1] - path[-2]).normalized()
        if seg_dir == Vector2.ZERO: seg_dir = current_dir
    
    if input_dir == seg_dir:
        head_sprite.frame = 3 # Forward
    elif input_dir == -seg_dir:
        head_sprite.frame = 4 # Retract
    else:
        if input_dir == Vector2.LEFT: head_sprite.frame = 1
        elif input_dir == Vector2.RIGHT: head_sprite.frame = 2
        elif input_dir == Vector2.UP: head_sprite.frame = 3
        elif input_dir == Vector2.DOWN: head_sprite.frame = 4

func update_visuals() -> void:
    head_group.position = path[-1]
    
    # Update Middle Line
    middle_line.clear_points()
    for p in path:
        middle_line.add_point(p)
        
    # Bottom body position
    bottom_sprite.position = path[0]
    
    # Animate turns based on distance
    for i in range(turns_data.size()):
        var t_data = turns_data[i]
        var frame = 0
        if i == turns_data.size() - 1:
            var dist = path[-1].distance_to(t_data.node.position)
            # Map distance (0 to MIN_TURN_DIST) to frames (6 to 0)
            frame = clamp(6 - int((dist / MIN_TURN_DIST) * 7.0), 0, 6)
        t_data.node.frame = frame
