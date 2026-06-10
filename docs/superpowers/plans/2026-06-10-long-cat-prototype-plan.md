# Long Cat Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot 4 prototype where a cat moves in 4 directions, generates body segments behind it, can retract by moving backwards, and interacts with buttons to open doors.

**Architecture:** Godot 4 `Area2D` based architecture. `CatHead` controls movement and spawns `CatBodySegment` instances into the global tree. Signals are used for Button-Door interactions. RayCasts ensure grid-precise collision checking without physics engine slide.

**Tech Stack:** Godot 4.x, GDScript

---

### Task 1: Project Setup

**Files:**
- Create: `project.godot`
- Create: `tests/run_tests.gd`

- [ ] **Step 1: Write test runner**
```gdscript
# tests/run_tests.gd
extends SceneTree

func _init():
    print("Running tests...")
    print("ALL TESTS PASSED")
    quit()
```

- [ ] **Step 2: Run test runner to verify it runs**
Run: `godot --headless -s tests/run_tests.gd`
Expected: Prints "ALL TESTS PASSED" and exits.

- [ ] **Step 3: Write minimal implementation (Project config)**
```ini
; project.godot
[application]
config/name="Long Cat Prototype"
run/main_scene="res://tests/run_tests.gd"
```

- [ ] **Step 4: Run test to verify it passes**
Run: `godot --headless -s tests/run_tests.gd`
Expected: Prints "ALL TESTS PASSED"

- [ ] **Step 5: Commit**
```bash
git add project.godot tests/run_tests.gd
git commit -m "chore: setup godot project and test runner"
```

### Task 2: Implement Cat Body Segment

**Files:**
- Create: `src/cat/CatBodySegment.tscn`
- Create: `src/cat/CatBodySegment.gd`
- Create: `tests/test_body_segment.gd`

- [ ] **Step 1: Write the failing test**
```gdscript
# tests/test_body_segment.gd
extends SceneTree

func _init():
    var segment_scene = load("res://src/cat/CatBodySegment.tscn")
    var segment = segment_scene.instantiate()
    assert(segment.type == 0, "Default type should be 0 (Horizontal)")
    segment.set_type(1)
    assert(segment.type == 1, "Type should update to 1")
    print("test_body_segment passed")
    quit()
```

- [ ] **Step 2: Run test to verify it fails**
Run: `godot --headless -s tests/test_body_segment.gd`
Expected: FAIL (File not found)

- [ ] **Step 3: Write minimal implementation**
```gdscript
# src/cat/CatBodySegment.gd
extends Area2D
class_name CatBodySegment

enum Type { HORIZONTAL, VERTICAL, CORNER_TL, CORNER_TR, CORNER_BL, CORNER_BR }
var type: int = Type.HORIZONTAL

func set_type(new_type: int) -> void:
    type = new_type
    if has_node("Sprite2D"):
        $Sprite2D.frame = type
```
Create a simple `src/cat/CatBodySegment.tscn` containing an `Area2D` root and `CatBodySegment.gd` attached.

- [ ] **Step 4: Run test to verify it passes**
Run: `godot --headless -s tests/test_body_segment.gd`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
mkdir -p src/cat
git add src/cat/CatBodySegment.tscn src/cat/CatBodySegment.gd tests/test_body_segment.gd
git commit -m "feat: implement cat body segment script"
```

### Task 3: Implement Cat Head Core Movement

**Files:**
- Create: `src/cat/CatHead.tscn`
- Create: `src/cat/CatHead.gd`
- Create: `tests/test_cat_head_movement.gd`

- [ ] **Step 1: Write the failing test**
```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**
Run: `godot --headless -s tests/test_cat_head_movement.gd`
Expected: FAIL (File not found)

- [ ] **Step 3: Write minimal implementation**
```gdscript
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
```
Create `src/cat/CatHead.tscn` containing an `Area2D` root and `CatHead.gd` attached.

- [ ] **Step 4: Run test to verify it passes**
Run: `godot --headless -s tests/test_cat_head_movement.gd`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add src/cat/CatHead.tscn src/cat/CatHead.gd tests/test_cat_head_movement.gd
git commit -m "feat: implement basic cat head movement"
```

### Task 4: Implement Cat Head Body Spawning

**Files:**
- Modify: `src/cat/CatHead.gd`
- Create: `tests/test_body_spawning.gd`

- [ ] **Step 1: Write the failing test**
```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**
Run: `godot --headless -s tests/test_body_spawning.gd`
Expected: FAIL (path_history missing)

- [ ] **Step 3: Write minimal implementation**
Modify `src/cat/CatHead.gd` to include spawning logic:
```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**
Run: `godot --headless -s tests/test_body_spawning.gd`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add src/cat/CatHead.gd tests/test_body_spawning.gd
git commit -m "feat: cat head spawns body segments"
```

### Task 5: Implement Level Interactive Elements

**Files:**
- Create: `src/level/Button.gd`
- Create: `src/level/Door.gd`
- Create: `tests/test_interactions.gd`

- [ ] **Step 1: Write the failing test**
```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**
Run: `godot --headless -s tests/test_interactions.gd`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**
```gdscript
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
```
```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**
Run: `godot --headless -s tests/test_interactions.gd`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
mkdir -p src/level
git add src/level/Button.gd src/level/Door.gd tests/test_interactions.gd
git commit -m "feat: implement button and door logic"
```