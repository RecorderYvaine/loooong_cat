# src/cat/CatHead.gd
extends Area2D
class_name CatHead

@export var speed: float = 100.0
@export var body_segment_scene: PackedScene
const BODY_WIDTH: float = 64.0
var direction: Vector2 = Vector2.RIGHT
var distance_since_last_segment: float = 0.0
var path_history: Array = []

func _process(delta: float) -> void:
    var step = direction * speed * delta
    position += step
    distance_since_last_segment += step.length()
    if distance_since_last_segment >= BODY_WIDTH:
        spawn_segment()
        distance_since_last_segment = 0.0

func spawn_segment() -> void:
    if body_segment_scene:
        var segment = body_segment_scene.instantiate()
        segment.position = position - (direction * BODY_WIDTH)
        get_parent().add_child(segment)
        path_history.append({"pos": segment.position, "dir": direction, "node": segment})