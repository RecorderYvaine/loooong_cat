# tests/test_body_spawning.gd
extends SceneTree

func _init():
    var root = Node2D.new()
    var head_scene = load("res://src/cat/CatHead.tscn")
    var head = head_scene.instantiate()
    head.body_segment_scene = load("res://src/cat/CatBodySegment.tscn")
    root.add_child(head)
    head.direction = Vector2.RIGHT
    head.speed = 100
    head._process(1.0)
    assert(head.path_history.size() > 0, "Should record history")
    print("test_body_spawning passed")
    quit()