# tests/test_interactions.gd
extends SceneTree

func _init():
    var btn = load("res://src/level/Button.gd").new()
    var door = load("res://src/level/Door.gd").new()
    btn.pressed.connect(door._on_button_pressed)
    btn.released.connect(door._on_button_released)
    
    assert(door.is_open == false, "Door starts closed")
    btn._on_body_entered(Node2D.new())
    assert(door.is_open == true, "Door opens when button pressed")
    print("test_interactions passed")
    quit()
