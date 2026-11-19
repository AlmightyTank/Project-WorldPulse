extends SceneTree

const WORLD := preload("res://scenes/world/World.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	await process_frame
	_test_layout()
	_test_road_meshes()
	await _test_scene()
	print("World foundation: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func _test_layout() -> void:
	var layout := WorldLayout.read()
	_check(layout.errors.is_empty(), "valid layout: %s" % str(layout.errors))
	_check(layout.id == "founders_district", "stable world id")
	_check(layout.meters(layout.grid) == Rect2(-128, -128, 256, 256), "world bounds")
	_check(layout.districts.keys() == ["town_square", "residential_quarter", "market_street", "civic_quarter", "greenbelt"], "five stable district ids")
	_check((layout.districts.get("town_square", {}).get("rect", Rect2i()) as Rect2i).encloses(layout.plaza), "plaza belongs to town square")
	_check(layout.meters(layout.plaza) == Rect2(-16, -16, 24, 24), "central plaza footprint")
	_check(layout.plots.size() == 11, "reserved plot count")
	for id: String in ["residential_quarter", "market_street", "civic_quarter", "greenbelt"]:
		_check(layout.plots.values().any(func(p: Dictionary) -> bool: return p.district == id), "reserved land in " + id)
	_check(not layout.roads.is_empty() and layout.roads == WorldLayout.read().roads, "deterministic road tiles")
	_check(WorldLayout.read("res://data/absent.json").errors.size() > 0, "missing layout is rejected")
	_check(WorldLayout.parse([]).errors.size() > 0, "malformed root is rejected")
	var data := JSON.parse_string(FileAccess.get_file_as_string(WorldLayout.DEFAULT_PATH)) as Dictionary
	var bad := data.duplicate(true)
	bad.pitch_m = 10
	_reject(bad, "pitch_m")
	bad = data.duplicate(true)
	bad.districts[1].id = bad.districts[0].id
	_reject(bad, "Duplicate id or overlapping district")
	bad = data.duplicate(true)
	bad.districts[1].rect = bad.districts[0].rect
	_reject(bad, "Duplicate id or overlapping district")
	bad = data.duplicate(true)
	bad.districts[0].rect = [-1, 0, 4, 4]
	_reject(bad, "Invalid district")
	bad = data.duplicate(true)
	bad.plots[0].district = "nonexistent"
	_reject(bad, "out-of-district plot")
	bad = data.duplicate(true)
	bad.plots[0].rect = [3, 12, 2, 3]
	_reject(bad, "out-of-district plot")
	bad = data.duplicate(true)
	bad.plots[1].rect = bad.plots[0].rect
	_reject(bad, "overlapping plot")
	bad = data.duplicate(true)
	bad.plots[0].rect = [6, 14, 1, 1]
	_reject(bad, "Road overlaps plot")
	bad = data.duplicate(true)
	bad.plaza.district = "greenbelt"
	_reject(bad, "Plaza must be inside")
	bad = data.duplicate(true)
	bad.plaza.landmark_cell = [1, 1]
	_reject(bad, "Landmark must occupy")
	bad = data.duplicate(true)
	bad.plaza.gathering_rect = [14, 14, 2, 2]
	_reject(bad, "Gathering space must be inside")
	bad = data.duplicate(true)
	bad.districts.append({"id": "isolated", "name": "Isolated", "rect": [0, 0, 2, 2], "color": "#ffffff"})
	_reject(bad, "District has no road frontage")
	bad = data.duplicate(true)
	bad.plots[0] = {"id": "isolated_market_plot", "district": "market_street", "rect": [21, 15, 1, 1]}
	_reject(bad, "Market plot has no road frontage")
	_check(layout.district_at(Vector2(-4, -4)) == "Town Square", "district at camera focus")
	bad = data.duplicate(true)
	bad.road_segments.append_array([[[13, 13], [16, 13]], [[16, 13], [16, 16]], [[16, 16], [13, 16]], [[13, 16], [13, 13]]])
	_reject(bad, "Road overlaps plaza")
	bad = data.duplicate(true)
	bad.road_segments.append_array([[[1, 1], [3, 1]], [[3, 1], [3, 3]], [[3, 3], [1, 3]], [[1, 3], [1, 1]]])
	_reject(bad, "Disconnected road network")
	bad = data.duplicate(true)
	bad.road_segments.append(data.road_segments[0])
	_reject(bad, "Duplicate road edge")
	bad = data.duplicate(true)
	bad.road_segments.append([[0, 0], [32, 0]])
	_reject(bad, "axis-aligned and in bounds")
	bad = data.duplicate(true)
	bad.road_segments.append([[0, 0], [1, 1]])
	_reject(bad, "axis-aligned and in bounds")
	bad = data.duplicate(true)
	bad.road_segments.append([[0.5, 0], [1, 0]])
	_reject(bad, "grid endpoints")
	bad = data.duplicate(true)
	bad.road_segments.append([[3, 10], [3, 9]])
	_reject(bad, "open end")
	bad = data.duplicate(true)
	bad.road_crossings.append(bad.road_crossings[0])
	_reject(bad, "Crossing must be unique")
	bad = data.duplicate(true)
	bad.road_crossings.append([12, 12])
	_reject(bad, "on a straight road")
	if layout.roads.is_empty():
		return
	var cell: Vector2i = layout.roads.keys()[0]
	var roads := layout.roads.duplicate(true)
	roads[cell].asset_id = "road_fake"
	_check("Invalid road asset reference" in "\n".join(WorldLayout.road_errors(roads)), "unknown road asset rejected")
	roads = layout.roads.duplicate(true)
	roads[cell].turns = 4
	_check("Invalid rotation" in "\n".join(WorldLayout.road_errors(roads)), "invalid quarter turn rejected")
	roads.erase(cell)
	_check("Mismatched road seam" in "\n".join(WorldLayout.road_errors(roads)), "missing neighbor rejected")


func _test_road_meshes() -> void:
	for asset_id: String in WorldLayout.ROAD_MASKS:
		var road := KenneyAssets.instance(asset_id)
		_check(road != null, "loads " + asset_id)
		if road == null:
			continue
		var instances := road.find_children("*", "MeshInstance3D", true, false)
		_check(instances.size() == 1, "one mesh for " + asset_id)
		if instances.size() == 1:
			var node := instances[0] as MeshInstance3D
			var transform_path := road.transform
			var current: Node3D = node
			var mesh_path := Transform3D.IDENTITY
			while current != road:
				mesh_path = current.transform * mesh_path
				current = current.get_parent() as Node3D
			transform_path *= mesh_path
			var box: AABB = transform_path * node.get_aabb()
			_check(box.position.is_equal_approx(Vector3(-4, 0, -4)), "base-center pivot " + asset_id)
			_check(box.size.is_equal_approx(Vector3(8, 0.16, 8)), "scaled extents " + asset_id)
			var edge_mask := 0
			for surface in node.mesh.get_surface_count():
				var material := node.get_active_material(surface) as StandardMaterial3D
				_check(material != null and material.albedo_texture != null and material.albedo_texture.resource_path == KenneyAssets.ROAD_ATLAS, "corrected atlas " + asset_id)
				var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					var p: Vector3 = transform_path * vertex
					if not is_equal_approx(p.y, 0.08):
						continue
					for i in 4:
						var direction := Vector2(WorldLayout.DIRECTIONS[i])
						var xz := Vector2(p.x, p.z)
						if is_equal_approx(xz.dot(direction), 4.0) and absf(xz.dot(direction.orthogonal())) <= 3.201:
							edge_mask |= 1 << i
			_check(edge_mask == WorldLayout.ROAD_MASKS[asset_id], "measured road openings " + asset_id)
		road.free()


func _test_scene() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Main.tscn", "unchanged project startup")
	var world := WORLD.instantiate()
	root.add_child(world)
	_check(world.built, "world starts offline")
	if not world.built:
		world.queue_free()
		return
	var roads := world.get_node("Roads")
	var layout: WorldLayout = world.layout
	_check(roads.get_child_count() == layout.roads.size(), "one instance per tile")
	for cell: Vector2i in layout.roads:
		var road := roads.get_node_or_null("Road_%02d_%02d" % [cell.x, cell.y]) as Node3D
		var tile: Dictionary = layout.roads[cell]
		_check(road != null and road.position == WorldBuilder.at(layout.cell_center(cell), 0.0) \
				and is_equal_approx(road.rotation.y, float(tile.turns) * PI / 2.0) \
				and road.get_meta("asset_id") == tile.asset_id, "tile transform and identity: " + str(cell))
	_check(world.get_node("Land/ReservedPlots").get_child_count() == layout.plots.size(), "reserved plot meshes")
	var ground := world.get_node("Land/Terrain/Ground") as MeshInstance3D
	var collision := world.get_node("Land/Terrain/GroundCollision") as CollisionShape3D
	_check((collision.shape as BoxShape3D).size == Vector3(256, 1, 256), "terrain collision dimensions")
	var plaza := world.get_node("Land/Plaza") as MeshInstance3D
	_check(ground.mesh.size == Vector3(256, 5, 256), "terrain dimensions")
	_check(plaza.mesh.size == Vector3(24, 0.18, 24), "plaza dimensions")
	_check(not world.districts.visible and not world.connections.visible, "guides hidden at startup")
	await _key(KEY_F6)
	_check(world.districts.visible and not world.connections.visible, "F6 district guides only")
	await _key(KEY_F7)
	_check(world.districts.visible and world.connections.visible, "F7 connection guides")
	await _key(KEY_F6)
	await _key(KEY_F7)
	_check(not world.districts.visible and not world.connections.visible, "guides toggle off")
	for pair in [[KEY_F5, "Grid"], [KEY_F8, "Land/ReservedPlots"], [KEY_F9, "Overlay"]]:
		var guide := world.get_node(pair[1])
		_check(not guide.visible, "%s hidden by default" % pair[1])
		await _key(pair[0])
		_check(guide.visible, "%s toggles on" % pair[1])
		if pair[0] == KEY_F9:
			var readout := world.get_node("Overlay").get_child(0).get_child(0) as Label
			_check("Town Square" in readout.text and "validation passed" in readout.text, "live overlay readout")
			_check("Buildings: 18 residential, 22 commercial, 8 civic" in readout.text, "overlay building counts")
		await _key(pair[0])
		_check(not guide.visible, "%s toggles off" % pair[1])
	var building_debug := world.get_node("Buildings/BuildingsDebug") as Node3D
	_check(not building_debug.visible, "building debug hidden by default")
	_check(world.get_node("Buildings/Residential").get_child_count() == 18, "eighteen residential buildings")
	_check(world.get_node("Buildings/Commercial").get_child_count() == 22, "twenty-two commercial buildings")
	_check(world.get_node("Buildings/Civic").get_child_count() == 8, "eight civic buildings")
	_check(world.get_node("Landmarks/WorldPulseBeacon").get_child_count() > 0, "beacon built")
	await _key(KEY_F10)
	_check(building_debug.visible, "F10 building debug toggles on")
	await _key(KEY_F10)
	_check(not building_debug.visible, "F10 building debug toggles off")
	var camera: WorldCamera = world.camera
	_check(root.get_camera_3d() == camera and camera.size == camera.home_span, "active default camera")
	camera.frame_view(Vector2(9999, -9999), 99999, true)
	_check(camera.focus == Vector2(128, -128) and camera.size == camera.max_span, "positive focus and maximum zoom bounds")
	camera.frame_view(Vector2(-9999, 9999), -100, true)
	_check(camera.focus == Vector2(-128, 128) and camera.size == camera.min_span, "negative focus and minimum zoom bounds")
	camera.reset_view(true)
	var home := camera.focus
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await process_frame
	_check(camera.target_span < camera.home_span, "wheel zooms in")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	motion.relative = Vector2(100, -100)
	Input.parse_input_event(motion)
	await process_frame
	_check(camera.target_focus != home, "middle mouse pans")
	motion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	motion.relative = Vector2(100, 0)
	Input.parse_input_event(motion)
	await process_frame
	_check(not is_equal_approx(camera.target_yaw, deg_to_rad(camera.home_yaw)), "right mouse orbits")
	await _key(KEY_R)
	_check(camera.target_focus == home and camera.target_span == camera.home_span and is_equal_approx(camera.target_yaw, deg_to_rad(camera.home_yaw)), "keyboard reset restores targets")
	_check(camera.focus.distance_to(home) > 0.0, "reset eases rather than snapping")
	world.queue_free()
	await process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _reject(data: Dictionary, message: String) -> void:
	_check(message in "\n".join(WorldLayout.parse(data).errors), "rejects " + message)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)

