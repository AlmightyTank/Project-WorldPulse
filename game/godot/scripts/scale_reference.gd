extends Node3D

## Compares the normalized Kenney categories against a 1.8 m human reference.
## Sizes come from the live instances, so nothing here is a guessed constant.

const LAYOUT := [
	{ "slot": "human", "id": "", "label": "Human 1.8 m" },
	{ "slot": "citizen", "id": "char_protagonist_skater_male_a", "label": "Citizen" },
	{ "slot": "vehicle", "id": "veh_sedan", "label": "Sedan" },
	{ "slot": "residential", "id": "res_building_type_f", "label": "Residential F" },
	{ "slot": "commercial", "id": "com_building_k", "label": "Commercial K" },
	{ "slot": "road", "id": "road_straight", "label": "Road module" },
	{ "slot": "tree", "id": "tree_default", "label": "Tree" },
]

var info_label: Label
var measured: Array[Dictionary] = []
var frames := 0
var screenshot_path := OS.get_environment("SCALE_SCREENSHOT")


func _ready() -> void:
	_build_stage()
	_place_assets()
	_build_ui()


func _build_stage() -> void:
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
	sun.rotation_degrees = Vector3(-50, -32, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 400)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.40, 0.29)
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)

	var metric := MeshInstance3D.new()
	var meter_line := ImmediateMesh.new()
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.9, 0.95, 0.9)
	meter_line.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	for metre in range(-60, 61):
		var height := 1.0 if metre % 5 == 0 else 0.4
		meter_line.surface_add_vertex(Vector3(metre, 0.02, 16))
		meter_line.surface_add_vertex(Vector3(metre, 0.02, 16 - height))
	meter_line.surface_end()
	metric.mesh = meter_line
	add_child(metric)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 26, 76)
	camera.fov = 38.0
	camera.far = 500.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 6, 0), Vector3.UP)


func _place_assets() -> void:
	# Build first, measure each item in the tree, then lay them out with real
	# widths so a 16 m building cannot overlap its neighbour.
	var nodes: Array[Node3D] = []
	var sizes: Array[Vector3] = []
	for entry: Dictionary in LAYOUT:
		var node: Node3D
		if entry["slot"] == "human":
			node = _human_reference()
		else:
			var wrapper := KenneyAsset.new()
			wrapper.asset_id = entry["id"]
			wrapper.add_collision = false
			node = wrapper
		node.position = Vector3.ZERO
		if entry["slot"] in ["citizen", "vehicle"]:
			node.rotation_degrees = Vector3(0, 90, 0)
		add_child(node)
		nodes.append(node)
		sizes.append(_world_size(node))

	var gap := 3.0
	var total := 0.0
	for size: Vector3 in sizes:
		total += maxf(size.x, 1.0) + gap

	var x := -total * 0.5
	for index in LAYOUT.size():
		var entry: Dictionary = LAYOUT[index]
		var node := nodes[index]
		var size := sizes[index]
		var width := maxf(size.x, 1.0)
		x += width * 0.5
		node.position = Vector3(x, 0, 0)
		measured.append({ "label": entry["label"], "size": size, "x": x })

		var label := Label3D.new()
		# Small items get a short caption; their full size stays in the panel so
		# the billboards do not overlap at this camera distance.
		label.text = entry["label"] if size.x < 3.0 else "%s\n%.1f x %.1f x %.1f m" % [entry["label"], size.x, size.y, size.z]
		label.font_size = 44
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 12
		label.outline_modulate = Color(0.05, 0.1, 0.09, 0.9)
		# Alternate label heights so neighbouring captions never overlap.
		var lift := 1.6 if measured.size() % 2 == 1 else 0.0
		label.position = Vector3(x, maxf(size.y + 1.2, 2.4) + lift, 0)
		add_child(label)
		x += width * 0.5 + gap


func _human_reference() -> Node3D:
	var root := Node3D.new()
	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 1.8
	capsule.mesh = mesh
	capsule.position = Vector3(0, 0.9, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.85, 0.55)
	material.roughness = 0.8
	capsule.material_override = material
	root.add_child(capsule)
	return root


func _world_size(node: Node3D) -> Vector3:
	var bounds := AABB()
	var found := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var instance := current as MeshInstance3D
			var box: AABB = instance.global_transform * instance.mesh.get_aabb()
			bounds = box if not found else bounds.merge(box)
			found = true
		for child in current.get_children():
			stack.append(child)
	return bounds.size


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.095, 0.09, 0.94)
	style.border_color = Color(0.35, 0.62, 0.56, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	info_label = Label.new()
	info_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.91))
	info_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(info_label)

	var lines := PackedStringArray()
	lines.append("Scale reference: measured, not assumed")
	lines.append("")
	for record: Dictionary in measured:
		var size: Vector3 = record["size"]
		lines.append("%-20s %5.1f x %5.1f x %5.1f m" % [record["label"], size.x, size.y, size.z])
	lines.append("")
	lines.append("Metre ticks run along the front edge. Road tiles are 8 m modules;")
	lines.append("building and vehicle scale derived from that module, not the reverse.")
	info_label.text = "\n".join(lines)


func _process(_delta: float) -> void:
	if screenshot_path != "":
		frames += 1
		if frames == 40:
			get_viewport().get_texture().get_image().save_png(screenshot_path)
			get_tree().quit()
