# src/level/Button.gd
extends Area2D
class_name LevelButton

signal pressed
signal released
var bodies_on_button: int = 0

func _on_body_entered(body: Node2D) -> void:
    bodies_on_button += 1
    if bodies_on_button == 1:
        pressed.emit()

func _on_body_exited(body: Node2D) -> void:
    bodies_on_button -= 1
    if bodies_on_button == 0:
        released.emit()
