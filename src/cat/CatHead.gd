# src/cat/CatHead.gd
extends Area2D
class_name CatHead

@export var speed: float = 100.0
var direction: Vector2 = Vector2.RIGHT
var distance_since_last_segment: float = 0.0

func _process(delta: float) -> void:
    var step = direction * speed * delta
    position += step
    distance_since_last_segment += step.length()
