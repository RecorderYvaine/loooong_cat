extends Area2D
class_name CatBodySegment

enum Type { HORIZONTAL, VERTICAL, CORNER_TL, CORNER_TR, CORNER_BL, CORNER_BR }
var type: int = Type.HORIZONTAL

func set_type(new_type: int) -> void:
    type = new_type
    if has_node("Sprite2D"):
        $Sprite2D.frame = type
