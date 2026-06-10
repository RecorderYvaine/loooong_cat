# tests/test_cat_head_movement.gd
extends SceneTree

func _init():
    var head_scene = load("res://src/cat/CatHead.tscn")
    var head = head_scene.instantiate()
    head.direction = Vector2.RIGHT
    head.speed = 100
    head._process(1.0)
    assert(head.position.x == 100, "Head should move 100px right")
    print("test_cat_head_movement passed")
    quit()
