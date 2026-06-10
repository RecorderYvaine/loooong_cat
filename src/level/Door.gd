# src/level/Door.gd
extends StaticBody2D
class_name LevelDoor

var is_open: bool = false

func _on_button_pressed() -> void:
    is_open = true
    if has_node("CollisionShape2D"):
        $CollisionShape2D.set_deferred("disabled", true)
    
func _on_button_released() -> void:
    is_open = false
    if has_node("CollisionShape2D"):
        $CollisionShape2D.set_deferred("disabled", false)
