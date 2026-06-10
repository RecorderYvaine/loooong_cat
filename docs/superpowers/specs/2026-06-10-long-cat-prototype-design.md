# Long Cat Game Prototype Design Spec

## 1. Overview
A 2D pixel art puzzle game prototype in Godot 4. The core mechanic revolves around a black cat whose body extends continuously as it moves, acting as an interactive path in the level. The prototype focuses on the core smooth movement, body generation, retraction, and basic environmental interactions (buttons and doors).

## 2. Technical Architecture
- **Engine:** Godot 4.x
- **Language:** GDScript
- **Physics/Collision Approach:** Kinematic manual movement via `Area2D` and precise `RayCast2D` checks, avoiding unpredictable physics sliding. Independent `Node2D`/`Sprite2D` segments for the body.

## 3. Core Components

### 3.1 Cat Head (`CatHead.tscn`)
- **Type:** `Area2D`
- **Responsibility:** Player input, movement execution, collision detection via raycasts, and spawning/removing body segments.
- **Movement Logic:**
  - Moves smoothly at a fixed speed (e.g., 100 px/s).
  - Uses `RayCast2D` nodes to check for walls/obstacles before moving.
  - Maintains a `path_history` array to track the coordinates and directions of movement.
- **Turning Rules:**
  - Can only move Up, Down, Left, Right.
  - Can turn instantly to a new 90-degree direction, generating a "Corner" segment.
  - Must move at least one `BODY_WIDTH` away from the previous turn before turning again.
- **Retraction:**
  - Moving in the exact opposite direction to the current movement path causes the head to traverse backward along `path_history`.
  - Body segments are deleted as the head retracts past their origin points.

### 3.2 Body Segment (`CatBodySegment.tscn`)
- **Type:** `Area2D`
- **Responsibility:** Visual representation of the path and interacting with level elements.
- **Behavior:**
  - Spawned by `CatHead` after moving a distance equal to `BODY_WIDTH`.
  - Contains a `Sprite2D` that updates based on type: Horizontal Straight, Vertical Straight, or one of four Corner variations.
  - Remains stationary once spawned.
  - Collision mask/layer set to `PlayerBody` to interact with triggers (like Buttons) or block NPCs.

### 3.3 Interactive Elements
- **Button (`Button.tscn`):**
  - Type: `Area2D`
  - Detects `body_entered` and `body_exited` specifically for the `PlayerBody` layer.
  - Emits `pressed` and `released` signals.
  - Must remain pressed to keep the associated door open.
- **Door (`Door.tscn`):**
  - Type: `StaticBody2D` with an `AnimatedSprite2D`.
  - Listens to Button signals. Disables its `CollisionShape2D` when opened.

### 3.4 Mini Witch Companion (`WitchCompanion.tscn`)
- **Type:** `Node2D` / `Control`
- **Responsibility:** UI and narrative feedback. Follows the cat and provides dialog bubbles (e.g., tutorial text or complaints when stuck).

## 4. Data Flow & State Management
- `CatHead` emits signals upon moving, turning, or retracting.
- The global Game or Level node manages the instancing of body segments to keep the tree flat and avoid scaling/rotation issues that arise if segments are children of the moving head.

## 5. Scope & Constraints (Prototype)
- Only basic movement, 1 type of button, 1 type of door, and basic static walls.
- Visuals will use placeholder colored squares or basic imported sprites.
- Not included in this spec: advanced mechanisms (water puddles, tape floors, complex enemies, electrical routing).
