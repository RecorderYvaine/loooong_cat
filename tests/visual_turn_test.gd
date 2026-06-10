extends SceneTree

const OUT_DIR = "user://visual_turn_test"
const BG_COLOR = Color(0.2, 0.2, 0.2, 1.0)

var cat: LongCat

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("visual_turn_test"):
		dir.make_dir("visual_turn_test")

	root.size = Vector2i(300, 200)
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(300, 200)
	root.add_child(bg)

	var cat_scene = load("res://src/cat/LongCat.tscn")
	cat = cat_scene.instantiate()
	cat.position = Vector2(40, 110)
	root.add_child(cat)
	await process_frame
	await process_frame

	await walk(Vector2.UP, 28.0)
	await walk(Vector2.RIGHT, 155.0)
	await save_view("right_straight.png")

	await walk(Vector2.DOWN, 70.0)
	await walk(Vector2.LEFT, 95.0)
	await walk(Vector2.DOWN, 35.0)
	await walk(Vector2.RIGHT, 55.0)
	await save_view("multi_turns.png")

	root.remove_child(cat)
	cat.queue_free()
	await process_frame

	cat = cat_scene.instantiate()
	cat.position = Vector2(145, 130)
	root.add_child(cat)
	await process_frame

	await walk(Vector2.UP, 95.0)
	await walk(Vector2.RIGHT, 105.0)
	await walk(Vector2.DOWN, 75.0)
	await walk(Vector2.LEFT, 95.0)
	await save_view("left_finish.png")

	root.remove_child(cat)
	cat.queue_free()
	await process_frame

	cat = cat_scene.instantiate()
	cat.position = Vector2(85, 120)
	root.add_child(cat)
	await process_frame

	await walk(Vector2.UP, 52.0)
	await walk(Vector2.RIGHT, 118.0)
	await save_view("simple_right_turn.png")

	print("Saved visual turn test images to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)

func walk(dir: Vector2, distance: float) -> void:
	var remaining = distance
	while remaining > 0.0:
		var step = min(1.0, remaining)
		cat.move_cat(dir, step)
		cat.update_head_frame(dir)
		cat.update_visuals()
		remaining -= step
		await process_frame

func save_view(file_name: String) -> void:
	await process_frame
	await process_frame
	var image = root.get_texture().get_image()
	image.save_png(OUT_DIR.path_join(file_name))
