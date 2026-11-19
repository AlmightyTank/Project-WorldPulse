extends SceneTree

# Four-sided contact sheets for catalog frontage review, one strip per asset.
const IDS := [
	"res_building_type_a", "res_building_type_c", "res_building_type_f",
	"res_building_type_j", "res_building_type_n", "res_building_type_t",
	"com_building_a", "com_building_c", "com_building_e", "com_building_k",
	"com_skyscraper_a", "com_low_detail_building_a",
]
const CELL := Vector2i(480, 270)
const DIRECTIONS := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
const NAMES := ["south", "east", "north", "west"]
const SHEET_ROWS := 4


func _initialize() -> void:
	await process_frame
	var output := OS.get_environment("WORLD_REVIEW_OUTPUT")
	if output.is_empty():
		output = ProjectSettings.globalize_path("user://building-review")
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9c4c0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e8f0f7")
	environment.ambient_light_energy = 0.7
	env.environment = environment
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.8
	stage.add_child(sun)
	var ground_asset := BoxMesh.new()
	ground_asset.size = Vector3(120, 0.2, 120)
	var ground := MeshInstance3D.new()
	ground.mesh = ground_asset
	ground.position.y = -0.1
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 300.0
	stage.add_child(camera)
	camera.current = true
	var sheet := Image.create(CELL.x * 4, CELL.y * SHEET_ROWS, false, Image.FORMAT_RGBA8)
	var sheet_row := 0
	var sheet_index := 0
	for i in IDS.size():
		var node := KenneyAssets.instance(IDS[i])
		if node == null:
			continue
		stage.add_child(node)
		var box := _bounds(node)
		var label := Label3D.new()
		label.text = "%s  %.1f x %.1f x %.1f" % [IDS[i], box.size.x, box.size.y, box.size.z]
		label.font_size = 64
		label.pixel_size = 0.02
		label.position = Vector3(0, box.size.y + 1.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stage.add_child(label)
		var span := maxf(box.size.x, box.size.z) * 2.2 + 6.0
		camera.size = span
		for view in 4:
			var direction: Vector3 = DIRECTIONS[view]
			camera.look_at_from_position(direction * 120.0 + Vector3(0, 2.0, 0), Vector3(0, 2.0, 0), Vector3.UP)
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(view * CELL.x, sheet_row * CELL.y))
		node.queue_free()
		label.queue_free()
		sheet_row += 1
		if sheet_row == SHEET_ROWS or i == IDS.size() - 1:
			sheet.save_png(output.path_join("building-sheet-%d.png" % sheet_index))
			print("saved sheet ", sheet_index)
			sheet_index += 1
			sheet_row = 0
			sheet = Image.create(CELL.x * 4, CELL.y * SHEET_ROWS, false, Image.FORMAT_RGBA8)
		print(NAMES[0], "→", NAMES[3], " views: ", IDS[i])
	quit(0)


func _bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var path := Transform3D.IDENTITY
		var current: Node3D = mesh
		while current != root:
			path = current.transform * path
			current = current.get_parent() as Node3D
		var box: AABB = root.transform * (path * mesh.get_aabb())
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

