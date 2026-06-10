extends SceneTree

func _init():
    var segment_scene = load("res://src/cat/CatBodySegment.tscn")
    var segment = segment_scene.instantiate()
    assert(segment.type == 0, "Default type should be 0 (Horizontal)")
    segment.set_type(1)
    assert(segment.type == 1, "Type should update to 1")
    print("test_body_segment passed")
    quit()
