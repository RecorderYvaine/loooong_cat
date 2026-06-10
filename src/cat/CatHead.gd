# src/cat/CatHead.gd
extends Area2D
class_name CatHead

@export var speed: float = 150.0
@export var body_segment_scene: PackedScene
const BODY_WIDTH: float = 64.0
var direction: Vector2 = Vector2.RIGHT
var distance_since_last_segment: float = 0.0
var path_history: Array = []

func _process(delta: float) -> void:
    handle_input()
    
    var step = direction * speed * delta
    position += step
    distance_since_last_segment += step.length()
    
    if distance_since_last_segment >= BODY_WIDTH:
        spawn_segment()
        distance_since_last_segment -= BODY_WIDTH

func handle_input() -> void:
    # 简单的四个方向控制 (不包含基于身位限制转弯的完整逻辑，用于快速原型测试)
    if Input.is_action_pressed("ui_right") and direction != Vector2.LEFT:
        direction = Vector2.RIGHT
    elif Input.is_action_pressed("ui_left") and direction != Vector2.RIGHT:
        direction = Vector2.LEFT
    elif Input.is_action_pressed("ui_down") and direction != Vector2.UP:
        direction = Vector2.DOWN
    elif Input.is_action_pressed("ui_up") and direction != Vector2.DOWN:
        direction = Vector2.UP

func spawn_segment() -> void:
    if body_segment_scene:
        var segment = body_segment_scene.instantiate()
        # 简单将身体放置在猫头后方
        segment.position = position - (direction * BODY_WIDTH)
        get_parent().add_child(segment)
        path_history.append({"pos": segment.position, "dir": direction, "node": segment})
