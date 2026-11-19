extends Node3D

## QA benchmark for the imported Kenney library.
## QA_MODE picks the test, QA_OUTPUT writes a JSON result. Measurements are real:
## nothing here is estimated. Run windowed at 1920x1080 for GPU numbers.

const MODE_COMPATIBILITY := "compatibility"
const MODE_NEIGHBORHOOD := "neighborhood"
const MODE_POPULATION := "population"

const BUILDING_IDS := [
	"res_building_type_a", "res_building_type_c", "res_building_type_f",
	"res_building_type_j", "res_building_type_n", "res_building_type_t",
	"com_building_a", "com_building_c", "com_building_e", "com_building_k",
	"com_skyscraper_a", "com_low_detail_building_a",
]
const TREE_IDS := ["tree_default", "tree_detailed", "tree_fat", "tree_pine_tall_a", "tree_simple", "tree_small", "tree_palm"]
const VEHICLE_IDS := ["veh_sedan", "veh_hatchback_sports", "veh_van", "veh_taxi", "veh_police", "veh_suv", "veh_truck", "veh_delivery"]
const CITIZEN_IDS := [
	"char_protagonist_criminal_male_a", "char_protagonist_cyborg_female_a",
	"char_protagonist_skater_female_a", "char_protagonist_skater_male_a",
]

var mode := OS.get_environment("QA_MODE")
var output_path := OS.get_environment("QA_OUTPUT")
var screenshot_path := OS.get_environment("QA_SCREENSHOT")

var samples: Array[float] = []
var warmup_frames := 0
var frames := 0
var elapsed := 0.0
var checks: Array[Dictionary] = []
var sampled_seconds := 0.0
var counted_frames := 0.0
var camera: Camera3D
var instances: Array[Node3D] = []
var citizen_visuals: Array[CharacterVisualState] = []


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_build_environment()
	_build_ground()
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 2000.0
	camera.current = true
	add_child(camera)

	match mode:
		MODE_NEIGHBORHOOD:
			_build_neighborhood()
		MODE_POPULATION:
			_build_population()
		_:
			mode = MODE_COMPATIBILITY
			_build_compatibility()

	_build_hud()


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.56, 0.82)
	sky_material.sky_horizon_color = Color(0.78, 0.84, 0.87)
	sky_material.ground_horizon_color = Color(0.33, 0.40, 0.29)
	sky_material.ground_bottom_color = Color(0.33, 0.40, 0.29)
	environment.sky.sky_material = sky_material
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -36, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 400)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.40, 0.29)
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)


func _build_compatibility() -> void:
	var x := -21.0
	for asset_id in ["res_building_type_f", "com_building_k", "road_straight",
			"road_traffic_light", "veh_sedan", "tree_default", "char_protagonist_skater_male_a",
			"char_mini_female_a"]:
		var node := _place(asset_id, Vector3(x, 0, 0))
		if node != null:
			_check_asset(asset_id, node)
		x += 6.0
	camera.position = Vector3(0, 12, 34)
	camera.look_at(Vector3(0, 3, 0), Vector3.UP)


func _build_neighborhood() -> void:
	# 8 x 8 m road tiles on a 12 m block grid, 20 buildings, 20 trees, 10 vehicles.
	for gx in range(-6, 6):
		_place("road_straight" if gx % 2 == 0 else "road_tile_low", Vector3(gx * 8.0, 0, 0))
	for gz in range(-3, 4):
		if gz != 0:
			_place("road_straight", Vector3(0, 0, gz * 8.0))
	var building_slots := [
		Vector3(-22, 0, -22), Vector3(-22, 0, -10), Vector3(-10, 0, -22),
		Vector3(10, 0, -22), Vector3(22, 0, -22), Vector3(22, 0, -10),
		Vector3(-22, 0, 10), Vector3(-22, 0, 22), Vector3(-10, 0, 22),
		Vector3(10, 0, 22), Vector3(22, 0, 22), Vector3(22, 0, 10),
		Vector3(-34, 0, 0), Vector3(34, 0, 0), Vector3(0, 0, -34),
		Vector3(0, 0, 34), Vector3(-34, 0, 22), Vector3(34, 0, -22),
		Vector3(-34, 0, -22), Vector3(34, 0, 22),
	]
	for index in building_slots.size():
		_place(BUILDING_IDS[index % BUILDING_IDS.size()], building_slots[index])

	var tree_slots := [
		Vector3(-46, 0, -30), Vector3(-40, 0, -16), Vector3(-30, 0, 12),
		Vector3(-14, 0, -30), Vector3(-10, 0, -14), Vector3(-6, 0, 14),
		Vector3(6, 0, -14), Vector3(10, 0, 30), Vector3(14, 0, 12),
		Vector3(30, 0, -12), Vector3(40, 0, 16), Vector3(46, 0, 30),
		Vector3(-46, 0, 30), Vector3(0, 0, -14), Vector3(0, 0, 14),
		Vector3(-16, 0, 30), Vector3(16, 0, -30), Vector3(46, 0, -30),
		Vector3(-40, 0, 40), Vector3(40, 0, 40),
	]
	for index in tree_slots.size():
		_place(TREE_IDS[index % TREE_IDS.size()], tree_slots[index])

	for index in 10:
		var x := -30.0 + (index % 5) * 14.0
		var z := 2.0 if index < 5 else -2.0
		_place(VEHICLE_IDS[index % VEHICLE_IDS.size()], Vector3(x, 0, z), 90.0 if z > 0 else -90.0)

	camera.position = Vector3(0, 46, 88)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)


func _build_population() -> void:
	var index := 0
	for row in 3:
		for column in 10:
			var asset_id: String = CITIZEN_IDS[index % CITIZEN_IDS.size()]
			var position := Vector3(-13.5 + column * 3.0, 0, -4.0 + row * 3.0)
			var citizen := _place(asset_id, position, 180.0)
			if citizen != null:
				var player := KenneyAssets._find_player(citizen)
				var visual := CharacterVisualState.new()
				var walking := visual.bind(player) and visual.play(CharacterVisualState.WALK)
				_add_check(asset_id, "Walk", walking, "native Walk through CharacterVisualState")
				if walking:
					citizen_visuals.append(visual)
			index += 1
	camera.position = Vector3(0, 7.5, 22)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _place(asset_id: String, position: Vector3, yaw_degrees := 0.0) -> Node3D:
	var node := KenneyAssets.instance(asset_id)
	if node == null:
		checks.append({ "asset": asset_id, "check": "instantiate", "ok": false, "detail": "cannot load" })
		return null
	node.position = position
	node.rotation_degrees = Vector3(0, yaw_degrees, 0)
	add_child(node)
	instances.append(node)
	return node


func _check_asset(asset_id: String, node: Node3D) -> void:
	var bounds := _bounds(node)
	var asset := KenneyAssets.find(asset_id)
	_add_check(asset_id, "meshes", _count_meshes(node) > 0, "%d" % _count_meshes(node))
	_add_check(asset_id, "materials", _count_materials(node) > 0, "%d" % _count_materials(node))
	_add_check(asset_id, "grounded", absf(bounds.position.y) < 0.25, "min.y %.3f" % bounds.position.y)
	_add_check(asset_id, "scale", bounds.size.length() > 0.05, "%.2f x %.2f x %.2f m" % [bounds.size.x, bounds.size.y, bounds.size.z])
	_add_check(asset_id, "manifest", not asset.is_empty(), str(asset.get("imported_path", "")))


func _add_check(asset_id: String, check: String, ok: bool, detail: String) -> void:
	checks.append({ "asset": asset_id, "check": check, "ok": ok, "detail": detail })


func _count_meshes(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		total += 1
	for child in node.get_children():
		total += _count_meshes(child)
	return total


func _count_materials(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var materials := (node as MeshInstance3D).mesh.get_surface_count()
		total += materials
	for child in node.get_children():
		total += _count_materials(child)
	return total


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var instance := current as MeshInstance3D
			var box: AABB = instance.global_transform * instance.mesh.get_aabb()
			result = box if not found else result.merge(box)
			found = true
		for child in current.get_children():
			stack.append(child)
	return result


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var label := Label.new()
	label.name = "Hud"
	label.add_theme_color_override("font_color", Color(0.9, 0.96, 0.93))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 18)
	label.position = Vector2(24, 20)
	root.add_child(label)


func _process(delta: float) -> void:
	frames += 1
	elapsed += delta
	if elapsed < 1.0:
		return  # warmup: shaders and instance buffers settle
	if elapsed - sampled_seconds >= 1.0:
		sampled_seconds += 1.0
		samples.append(Engine.get_frames_per_second())
		counted_frames += Engine.get_frames_per_second()
	var hud := get_node_or_null("CanvasLayer/Hud") as Label
	if hud != null:
		hud.text = "%s  FPS %d  draws %d  tris %d  instances %d" % [
			mode, Engine.get_frames_per_second(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			instances.size(),
		]
	# Six measured seconds after a one second warmup.
	if sampled_seconds >= 6.0:
		_finish()


func _finish() -> void:
	if screenshot_path != "":
		get_viewport().get_texture().get_image().save_png(screenshot_path)
	var average := 0.0
	var lowest := 1e9
	var highest := 0.0
	for value in samples:
		average += value
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	if not samples.is_empty():
		average /= samples.size()

	var result := {
		"mode": mode,
		"engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"cpu": OS.get_processor_name(),
		"os": OS.get_name() + " " + OS.get_version(),
		"resolution": "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"instances": instances.size(),
		"frames_sampled": samples.size(),
		"seconds": snappedf(elapsed, 0.01),
		"fps_average": snappedf(average, 0.1),
		"fps_min": snappedf(lowest, 0.1) if not samples.is_empty() else 0.0,
		"fps_max": snappedf(highest, 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"triangles": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"checks": checks,
		"checks_failed": checks.filter(func(c: Dictionary) -> bool: return not c["ok"]).size(),
	}
	if output_path != "":
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "  "))
			file.close()
	print("QA_RESULT ", JSON.stringify(result))
	get_tree().quit()
