extends Node3D

## Development gallery for the imported Kenney packs.
## Builds every section from manifest.json so asset names always match the data.

const SECTION_DEFS := [
	{ "title": "Residential", "categories": ["residential"], "position": Vector3(-120, 0, -60) },
	{ "title": "Commercial", "categories": ["commercial"], "position": Vector3(0, 0, -60) },
	{ "title": "Roads and traffic", "categories": ["roads", "traffic"], "position": Vector3(120, 0, -60) },
	{ "title": "Citizens", "categories": ["citizens"], "position": Vector3(-120, 0, 60) },
	{ "title": "Vehicles", "categories": ["vehicles"], "position": Vector3(0, 0, 60) },
	{ "title": "Trees and foliage", "categories": ["nature"], "position": Vector3(120, 0, 60) },
]

const PRESETS := [
	{
		"name": "Day",
		"sun_rotation": Vector3(-48, -38, 0),
		"sun_energy": 0.95,
		"sun_color": Color(1.0, 0.97, 0.9),
		"sky_top": Color(0.25, 0.53, 0.86),
		"sky_horizon": Color(0.72, 0.85, 0.94),
		"ambient": 0.35,
		"exposure": 0.9,
	},
	{
		"name": "Evening",
		"sun_rotation": Vector3(-16, -68, 0),
		"sun_energy": 1.1,
		"sun_color": Color(1.0, 0.68, 0.42),
		"sky_top": Color(0.22, 0.24, 0.42),
		"sky_horizon": Color(0.95, 0.6, 0.42),
		"ambient": 0.65,
		"exposure": 0.95,
	},
	{
		"name": "Night",
		"sun_rotation": Vector3(-34, 130, 0),
		"sun_energy": 0.18,
		"sun_color": Color(0.72, 0.80, 1.0),
		"sky_top": Color(0.10, 0.14, 0.23),
		"sky_horizon": Color(0.28, 0.32, 0.42),
		"ambient": 0.46,
		"ambient_color": Color(0.78, 0.85, 1.0),
		"exposure": 1.15,
	},
]

var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var grid_root: Node3D
var catalog_sections: Array[Node3D] = []
var metrics_label: Label
var selection_label: Label
var preset_label: Label

var focus := Vector3.ZERO
var yaw := -45.0
var elevation := 34.0
var distance := 300.0
var dragging := false
var drag_origin := Vector2.ZERO
var panning := false
var preset_index := 0
var items: Array[Dictionary] = []
var selected: Dictionary = {}
var metrics_timer := 0.0
var screenshot_path := OS.get_environment("GALLERY_SCREENSHOT")
var frame_count := 0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_grid()
	_build_sections()
	_build_comparison()
	_build_ui()
	_apply_preset(OS.get_environment("GALLERY_PRESET").to_int())
	if OS.get_environment("GALLERY_VIEW") == "comparison":
		_focus_comparison()
	else:
		_update_camera()


func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "GalleryCamera"
	camera.fov = 42.0
	camera.far = 3000.0
	camera.current = true
	add_child(camera)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 1800)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.46, 0.28)
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)


func _build_grid() -> void:
	grid_root = Node3D.new()
	grid_root.name = "MetricGrid"
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.16, 0.24, 0.22, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for x in range(-700, 701, 10):
		mesh.surface_add_vertex(Vector3(x, 0.05, -450))
		mesh.surface_add_vertex(Vector3(x, 0.05, 450))
	for z in range(-450, 451, 10):
		mesh.surface_add_vertex(Vector3(-700, 0.05, z))
		mesh.surface_add_vertex(Vector3(700, 0.05, z))
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_root.add_child(instance)
	add_child(grid_root)


func _build_sections() -> void:
	var manifest_assets := KenneyAssets.all()
	for definition: Dictionary in SECTION_DEFS:
		var section: Node3D = Node3D.new()
		section.name = str(definition["title"]).replace(" ", "")
		section.position = definition["position"]
		add_child(section)
		catalog_sections.append(section)

		var heading := Label3D.new()
		heading.text = definition["title"]
		heading.font_size = 72
		heading.pixel_size = 0.02
		heading.modulate = Color(1, 1, 1)
		heading.outline_size = 18
		heading.outline_modulate = Color(0.05, 0.1, 0.09, 0.85)
		heading.position = Vector3(0, 12, -38)
		heading.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		section.add_child(heading)

		var section_assets: Array = []
		for asset: Dictionary in manifest_assets:
			if definition["categories"].has(asset.get("category")):
				section_assets.append(asset)

		var index := 0
		for asset: Dictionary in section_assets:
			var column := index % 4
			var row := int(index / 4.0)
			var holder := Node3D.new()
			holder.name = str(asset["id"])
			holder.position = Vector3((column - 1.5) * 26.0, 0, row * 30.0)
			section.add_child(holder)

			var wrapper := KenneyAsset.new()
			wrapper.asset_id = asset["id"]
			holder.add_child(wrapper)
			_play_idle(wrapper)

			var label := Label3D.new()
			label.text = str(asset["id"])
			label.font_size = 34
			label.pixel_size = 0.03
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.outline_size = 12
			label.outline_modulate = Color(0.05, 0.1, 0.09, 0.9)
			label.position = Vector3(0, 7.5, 0)
			holder.add_child(label)

			items.append({ "node": holder, "asset": asset, "label": label, "wrapper": wrapper })
			index += 1


func _build_comparison() -> void:
	var stage := Node3D.new()
	stage.name = "ScaleComparison"
	add_child(stage)
	for x in [-12.0, -4.0, 4.0, 12.0]:
		_comparison_asset(stage, "road_straight", Vector3(x, 0, 0))
	_comparison_asset(stage, "res_building_type_f", Vector3(-8, 0, -11))
	_comparison_asset(stage, "com_building_k", Vector3(8, 0, -11))
	_comparison_asset(stage, "veh_sedan", Vector3(3, 0.03, 1.5), 90.0)
	_comparison_asset(stage, "tree_default", Vector3(-15, 0, -6), 26.0, 0.8)
	_comparison_asset(stage, "tree_small", Vector3(14, 0, -6), -42.0, 0.95)
	_play_idle(_comparison_asset(stage, "char_protagonist_skater_male_a", Vector3(-6, 0, -4.8), 180.0))


func _comparison_asset(stage: Node3D, id: String, position: Vector3, angle := 0.0, size_factor := 1.0) -> KenneyAsset:
	var asset := KenneyAsset.new()
	asset.asset_id = id
	asset.add_collision = false
	asset.position = position
	asset.rotation_degrees.y = angle
	asset.scale = Vector3.ONE * size_factor
	stage.add_child(asset)
	var label := Label3D.new()
	label.visible = false
	asset.add_child(label)
	items.append({ "node": asset, "asset": KenneyAssets.find(id), "label": label, "wrapper": asset })
	return asset


func _focus_comparison() -> void:
	_set_catalog_visible(false)
	focus = Vector3(0, 2.2, -4.5)
	yaw = 16.0
	elevation = 28.0
	distance = 36.0
	_update_camera()


func _set_catalog_visible(enabled: bool) -> void:
	for section in catalog_sections:
		section.visible = enabled
	metadata_clear()


func _play_idle(wrapper: KenneyAsset) -> void:
	var player := _find_animation_player(wrapper)
	if player != null and player.has_animation("Idle"):
		player.play("Idle")


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	metrics_label = _panel_label(root, Vector2(20, 20), Vector2(360, 118))
	selection_label = _panel_label(root, Vector2(-420, 20), Vector2(400, 250))
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	selection_label.text = "Selection\n\nClick an asset to inspect it."

	preset_label = Label.new()
	preset_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.89))
	preset_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	preset_label.add_theme_constant_override("shadow_offset_x", 1)
	preset_label.add_theme_constant_override("shadow_offset_y", 1)
	preset_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	preset_label.position = Vector2(20, -46)
	preset_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(preset_label)


func _panel_label(parent: Control, position: Vector2, size: Vector2) -> Label:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.095, 0.09, 0.92)
	style.border_color = Color(0.35, 0.62, 0.56, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = position
	panel.size = size
	if position.x < 0:
		panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		panel.position = Vector2(position.x, position.y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.91))
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	return label


func _apply_preset(index: int) -> void:
	preset_index = clampi(index, 0, PRESETS.size() - 1)
	var preset: Dictionary = PRESETS[preset_index]
	var environment := world_environment.environment
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = preset["sky_top"]
	sky_material.sky_horizon_color = preset["sky_horizon"]
	sky_material.ground_horizon_color = preset["sky_horizon"].darkened(0.25)
	sky_material.ground_bottom_color = preset["sky_horizon"].darkened(0.6)
	var has_fill := preset.has("ambient_color")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if has_fill else Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = preset.get("ambient_color", Color.WHITE)
	environment.ambient_light_sky_contribution = 0.0 if has_fill else 1.0
	environment.ambient_light_energy = preset["ambient"]
	environment.tonemap_exposure = preset["exposure"]
	sun.rotation_degrees = preset["sun_rotation"]
	sun.light_energy = preset["sun_energy"]
	sun.light_color = preset["sun_color"]
	if preset_label != null:
		preset_label.text = "Lighting: %s   |   Drag orbit   Shift+drag pan   Wheel zoom   R reset   1 day  2 evening  3 night   G grid   C comparison" % preset["name"]


func _update_camera() -> void:
	var radians := deg_to_rad(elevation)
	var offset := Vector3(
		sin(deg_to_rad(yaw)) * cos(radians),
		sin(radians),
		cos(deg_to_rad(yaw)) * cos(radians)
	) * distance
	camera.position = focus + offset
	camera.look_at(focus, Vector3.UP)


func _process(delta: float) -> void:
	if screenshot_path != "":
		frame_count += 1
		if frame_count == 45:
			get_viewport().get_texture().get_image().save_png(screenshot_path)
			get_tree().quit()
	metrics_timer += delta
	if metrics_timer < 0.25:
		return
	metrics_timer = 0.0
	metrics_label.text = "FPS %d\nDraw calls %d\nTriangles %d\nInstances %d" % [
		Engine.get_frames_per_second(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		items.size(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			distance = clampf(distance * 0.9, 12.0, 900.0)
			_update_camera()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			distance = clampf(distance * 1.1, 12.0, 900.0)
			_update_camera()
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			dragging = button.pressed
			panning = button.button_index == MOUSE_BUTTON_MIDDLE or button.shift_pressed
			drag_origin = button.position
		elif button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			dragging = false
	if event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		if panning:
			var right := camera.global_transform.basis.x
			var forward := Vector3(right.z, 0, -right.x)
			var scale := distance * 0.0016
			focus += (-right * motion.relative.x + forward * motion.relative.y) * scale
		else:
			yaw -= motion.relative.x * 0.3
			elevation = clampf(elevation + motion.relative.y * 0.25, 6.0, 82.0)
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_R:
				_set_catalog_visible(true)
				focus = Vector3.ZERO
				yaw = -45.0
				elevation = 34.0
				distance = 300.0
				_update_camera()
			KEY_1:
				_apply_preset(0)
			KEY_2:
				_apply_preset(1)
			KEY_3:
				_apply_preset(2)
			KEY_G:
				grid_root.visible = not grid_root.visible
			KEY_C:
				_focus_comparison()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		if button.position.distance_to(drag_origin) < 6.0:
			_select_at(button.position)


func _select_at(screen_position: Vector2) -> void:
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var best: Dictionary = {}
	var best_distance := INF
	for item: Dictionary in items:
		var node: Node3D = item["node"]
		if not node.is_visible_in_tree():
			continue
		var bounds := _world_bounds(item["wrapper"])
		var hit: Variant = bounds.intersects_ray(from, direction)
		if hit == null:
			continue
		var hit_distance := from.distance_to(hit as Vector3)
		if hit_distance < best_distance:
			best_distance = hit_distance
			best = item
	if best.is_empty():
		metadata_clear()
		return
	selected = best
	for item: Dictionary in items:
		(item["label"] as Label3D).modulate = Color(1, 1, 1)
	(best["label"] as Label3D).modulate = Color(0.45, 1.0, 0.85)
	var asset: Dictionary = best["asset"]
	var dimensions := _world_bounds(best["wrapper"]).size
	selection_label.text = "%s\n\nPack  %s\nCategory  %s\nWorld scale  %.4fx\nSize  %.1f x %.1f x %.1f m\nCollision  %s\nSource  %s" % [
		asset["id"], asset["pack"], asset["category"], float(asset.get("scale", 1.0)),
		dimensions.x, dimensions.y, dimensions.z,
		"box" if asset.get("collision", false) else "none",
		asset["source_file"],
	]


func metadata_clear() -> void:
	selection_label.text = "Selection\n\nClick an asset to inspect it."


func _world_bounds(wrapper: KenneyAsset) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array[Node] = [wrapper]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var instance := node as MeshInstance3D
			var box: AABB = instance.global_transform * instance.mesh.get_aabb()
			result = box if not found else result.merge(box)
			found = true
		for child in node.get_children():
			stack.append(child)
	return result