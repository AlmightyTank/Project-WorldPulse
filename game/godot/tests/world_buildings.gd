extends SceneTree

const WORLD := preload("res://scenes/world/World.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	await process_frame
	var layout := WorldLayout.read()
	_check(layout.errors.is_empty(), "valid layout for building tests")
	_test_catalog(layout)
	_test_geometry(layout)
	_test_rejections(layout)
	await _test_scene(layout)
	print("World buildings: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func _test_catalog(layout: WorldLayout) -> void:
	var catalog := WorldBuildings.read(layout)
	_check(catalog.errors.is_empty(), "valid catalog: %s" % str(catalog.errors))
	_check(catalog.assets.size() == 12, "twelve measured catalog assets")
	_check(catalog.placements.size() == 48, "forty-eight explicit placements")
	_check(catalog.measured.size() == 12, "all catalog assets measured")
	var ids := {}
	for id: String in catalog.assets:
		_check(not ids.has(id), "unique asset id " + id)
		ids[id] = true
		var asset: Dictionary = catalog.assets[id]
		_check(ResourceLoader.exists("res://" + asset.wrapper, "PackedScene"), "wrapper resolves " + id)
		_check(asset.rotations.size() == 4, "four supported rotations for " + id)
		_check(asset.frontage in ["north", "east", "south", "west", "unknown"], "frontage declared for " + id)
		var box: AABB = catalog.measured[id]
		_check(absf(box.size.x - asset.footprint.x) <= WorldBuildings.TOLERANCE, "measured width " + id)
		_check(absf(box.size.z - asset.footprint.y) <= WorldBuildings.TOLERANCE, "measured depth " + id)
		_check(absf(box.size.y - asset.height) <= WorldBuildings.TOLERANCE, "measured height " + id)
		_check(absf(box.position.y - asset.ground_offset) <= WorldBuildings.TOLERANCE, "measured base " + id)
	_check(catalog.district_count("residential_quarter") == 18, "eighteen residential buildings")
	_check(catalog.district_count("market_street") == 18, "eighteen market buildings")
	_check(catalog.district_count("civic_quarter") == 8, "eight civic buildings")
	_check(catalog.district_count("greenbelt") == 0, "no greenbelt buildings")
	_check(catalog.built_count() == 48 and catalog.invalid_count() == 0, "all placements valid")
	var placement_ids := {}
	for p: Dictionary in catalog.placements:
		_check(not placement_ids.has(p.id), "unique placement id " + p.id)
		placement_ids[p.id] = true
		_check(catalog.assets.has(p.asset_id), "placement asset exists " + p.id)
		_check(layout.districts.has(p.district), "placement district exists " + p.id)
		_check(layout.plots.has(p.plot), "placement plot exists " + p.id)
		_check(layout.plots[p.plot].district == p.district, "plot district matches " + p.id)
		_check(not p.variation.strip_edges().is_empty(), "visual variation recorded " + p.id)
		_check(p.rotation in catalog.assets[p.asset_id].rotations, "placement rotation supported " + p.id)
		_check(catalog.placement_errors.get(p.id, PackedStringArray()).is_empty(), "no placement errors " + p.id)
	_check(catalog.plot_frontage("res_north", "south"), "north homes front shared street")
	_check(catalog.plot_frontage("res_north", "north"), "opposite row has its own street")
	_check(catalog.plot_frontage("res_south", "north"), "south homes front high street")
	_check(catalog.plot_frontage("market_north", "north"), "market north fronts shared civic street")
	_check(catalog.plot_frontage("market_north", "south"), "market fronts high street")
	_check(catalog.plot_frontage("market_south", "north"), "opposing market fronts high street")
	_check(catalog.district_count("town_square") == 4, "four square frontage shops")
	_check(catalog.plot_frontage("civic_west", "north"), "civic west fronts the north road")
	_check(not catalog.plot_frontage("absent_plot", "north"), "unknown plot has no frontage")
	for plot_id: String in ["green_meadow_west", "green_meadow_east", "green_common"]:
		_check(not catalog.placements.any(func(p: Dictionary) -> bool: return p.plot == plot_id),
			"green reserve protected: " + plot_id)
	_check(catalog.placements.any(func(p: Dictionary) -> bool: return p.plot == "civic_west"), "civic west documented")
	_check(catalog.placements.any(func(p: Dictionary) -> bool: return p.plot == "civic_east"), "civic east documented")
	var second := WorldBuildings.read(layout)
	_check(catalog.signature() == second.signature(), "deterministic catalog generation")
	_check(catalog.placements[0].position == second.placements[0].position, "deterministic first position")
	var missing := WorldBuildings.read(layout, "res://data/absent.json")
	_check(not missing.errors.is_empty(), "missing catalog rejected")
	_check(not WorldBuildings.parse(layout, []).errors.is_empty(), "malformed catalog root rejected")


func _test_geometry(layout: WorldLayout) -> void:
	var catalog := WorldBuildings.read(layout)
	var flat := WorldBuildings.footprint_corners(Vector2.ZERO, Vector2(10, 4), 0)
	_check(_bounds(flat).is_equal_approx(Rect2(-5, -2, 10, 4)), "unrotated footprint maths")
	var quarter := WorldBuildings.footprint_corners(Vector2.ZERO, Vector2(10, 4), 90)
	var quarter_bounds := _bounds(quarter)
	_check(is_equal_approx(quarter_bounds.size.x, 4) and is_equal_approx(quarter_bounds.size.y, 10), "rotated footprint swaps axes")
	_check(is_equal_approx(quarter_bounds.position.x, -2) and is_equal_approx(quarter_bounds.position.y, -5), "rotated footprint centered")
	var half := WorldBuildings.footprint_corners(Vector2(2, 3), Vector2(10, 4), 180)
	_check(_bounds(half).position.is_equal_approx(Vector2(-3, 1)), "half turn footprint maths")
	_check(WorldBuildings.obb_overlap(flat, flat, 0.02), "identical footprints overlap")
	_check(not WorldBuildings.obb_overlap(flat, WorldBuildings.footprint_corners(Vector2(10.1, 0), Vector2(10, 4), 0), 0.02), "separated footprints clear")
	_check(WorldBuildings.obb_overlap(flat, WorldBuildings.footprint_corners(Vector2(9.99, 0), Vector2(10, 4), 0), 0.02), "tolerance allows a hairline")
	_check(WorldBuildings.obb_overlap(flat, WorldBuildings.footprint_corners(Vector2(0, 0), Vector2(2, 2), 45), 0.02), "rotated inner footprint overlaps")
	_check(WorldBuildings.facing_of(catalog.assets["res_building_type_a"], 0) == "south", "residential faces south")
	_check(WorldBuildings.facing_of(catalog.assets["res_building_type_a"], 180) == "north", "residential half turn faces north")
	_check(WorldBuildings.facing_of(catalog.assets["com_building_a"], 90) == "west", "commercial quarter turn faces west")
	_check(WorldBuildings.facing_of(catalog.assets["com_building_a"], 270) == "east", "commercial three-quarter turn faces east")
	_check(WorldBuildings.facing_of(catalog.assets["com_low_detail_building_a"], 0) == "unknown", "unknown frontage stays unknown")
	var landmark := layout.cell_center(layout.landmark_cell)
	_check(landmark == Vector2(-4, -4), "landmark cell center")
	_check(catalog.beacon.height_m >= 10.0 and catalog.beacon.base_radius_m <= 4.0, "restrained beacon massing")
	for p: Dictionary in catalog.placements:
		var asset: Dictionary = catalog.assets[p.asset_id]
		var corners := WorldBuildings.footprint_corners(p.position, asset.footprint, p.rotation)
		var plot: Rect2 = layout.meters(layout.plots[p.plot].rect)
		_check(Array(corners).all(func(c: Vector2) -> bool: return _inside(c, plot.grow(0.02))),
			"rotated footprint inside plot " + p.id)
		_check(catalog.plot_frontage(p.plot, WorldBuildings.facing_of(asset, p.rotation)),
			"known frontage meets a road " + p.id)
		var access := catalog.entrance_corridor(p)
		_check(access.has_area(), "individual entrance reaches street " + p.id)
		var facing := WorldBuildings.facing_of(asset, p.rotation)
		var width := access.size.x if facing in ["north", "south"] else access.size.y
		_check(is_equal_approx(width, 2.0), "access corridor width " + p.id)
		for other: Dictionary in catalog.placements:
			if other.id != p.id:
				var obstacle := WorldBuildings.footprint_corners(other.position, catalog.assets[other.asset_id].footprint, other.rotation)
				_check(not WorldBuildings.obb_rect_overlap(obstacle, access, 0.02), "unblocked access " + p.id + " past " + other.id)
		for cell: Vector2i in layout.roads:
			var road := Rect2(layout.origin_m + Vector2(cell) * WorldLayout.PITCH,
				Vector2(WorldLayout.PITCH, WorldLayout.PITCH))
			_check(not WorldBuildings.obb_rect_overlap(corners, road.grow(WorldBuildings.ROAD_CLEARANCE_M), 0.02),
				"sidewalk clearance " + p.id + " at " + str(cell))


func _test_rejections(layout: WorldLayout) -> void:
	var data := JSON.parse_string(FileAccess.get_file_as_string(WorldBuildings.DEFAULT_PATH)) as Dictionary
	_reject(layout, data, "Duplicate building asset id", func(d: Dictionary) -> void:
		d.assets[1].id = d.assets[0].id)
	_reject(layout, data, "unsupported category", func(d: Dictionary) -> void:
		d.assets[0].category = "roads")
	_reject(layout, data, "no project wrapper path", func(d: Dictionary) -> void:
		d.assets[0].wrapper = "wrong.glb")
	_reject(layout, data, "wrapper does not match the manifest path", func(d: Dictionary) -> void:
		d.assets[0].wrapper = d.assets[1].wrapper)
	_reject(layout, data, "measured bounds", func(d: Dictionary) -> void:
		d.assets[0].footprint_m[0] += 0.5)
	_reject(layout, data, "collision size disagrees", func(d: Dictionary) -> void:
		d.assets[0].collision.size_m[0] += 0.5)
	_reject(layout, data, "Duplicate building placement id", func(d: Dictionary) -> void:
		d.placements[1].id = d.placements[0].id)
	_reject(layout, data, "unknown asset id", func(d: Dictionary) -> void:
		d.placements[0].asset_id = "com_missing")
	_reject(layout, data, "unknown district", func(d: Dictionary) -> void:
		d.placements[0].district = "moon")
	_reject(layout, data, "unknown plot", func(d: Dictionary) -> void:
		d.placements[0].plot = "moon")
	_reject(layout, data, "leaves plot", func(d: Dictionary) -> void:
		d.placements[0].position = [-200.0, -16.11])
	_reject(layout, data, "overlaps placement", func(d: Dictionary) -> void:
		d.placements[2].position = d.placements[0].position)
	_reject(layout, data, "overlaps the road", func(d: Dictionary) -> void:
		d.placements[0].position = [-76.0, -4.0])
	_reject(layout, data, "rotation 45 is not supported", func(d: Dictionary) -> void:
		d.placements[0].rotation = 45)
	_reject(layout, data, "entrance access blocked", func(d: Dictionary) -> void:
		d.placements[3].rotation = 180)
	_reject(layout, data, "placement requires an identifiable entrance", func(d: Dictionary) -> void:
		d.placements[0].asset_id = "com_low_detail_building_a"
		d.placements[0].footprint_m = [4, 4])
	var catalog := WorldBuildings.read(layout)
	var entrance: Dictionary = catalog.placements[0]
	var street_cell := Vector2i(8, 8)
	var saved: Dictionary = layout.roads[street_cell]
	layout.roads.erase(street_cell)
	_check(not catalog.entrance_corridor(entrance).has_area(), "entrance needs road at its actual position")
	layout.roads[street_cell] = saved
	var edge := entrance.duplicate(true)
	edge.position.x = -71.5
	_check(not catalog.entrance_corridor(edge).has_area(), "full two-metre corridor must fit inside plot")
	_reject(layout, data, "buildings are not allowed in the greenbelt", func(d: Dictionary) -> void:
		d.placements[4].district = "greenbelt"
		d.placements[4].plot = "green_common"
		d.placements[4].position = [0.0, 80.0])
	_reject(layout, data, "Greenbelt plot green_common must stay open", func(d: Dictionary) -> void:
		d.placements[4].district = "greenbelt"
		d.placements[4].plot = "green_common"
		d.placements[4].position = [0.0, 80.0])
	_reject(layout, data, "Civic plot civic_west has no placement", func(d: Dictionary) -> void:
		d.placements = d.placements.filter(func(p: Dictionary) -> bool: return p.district != "civic_quarter"))
	_reject(layout, data, "Residential plot res_south is unused", func(d: Dictionary) -> void:
		d.placements = d.placements.filter(func(p: Dictionary) -> bool: return p.plot != "res_south"))
	_reject(layout, data, "Beacon base leaves the plaza", func(d: Dictionary) -> void:
		d.beacon.base_radius_m = 25.0)
	_reject(layout, data, "Invalid beacon height_m", func(d: Dictionary) -> void:
		d.beacon.height_m = 0)


func _test_scene(layout: WorldLayout) -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Main.tscn", "startup scene unchanged")
	var world := WORLD.instantiate()
	root.add_child(world)
	_check(world.built, "world with buildings builds")
	if not world.built:
		world.queue_free()
		return
	var catalog: WorldBuildings = world.buildings
	var parents := {
		"residential_quarter": "Buildings/Residential", "market_street": "Buildings/Commercial",
		"civic_quarter": "Buildings/Civic", "town_square": "Buildings/Commercial",
	}
	var roof_variants := {}
	var roof_audits := {}
	for p: Dictionary in catalog.placements:
		var asset: Dictionary = catalog.assets[p.asset_id]
		var parent: Node3D = world.get_node(parents[p.district])
		var building := parent.get_node_or_null(p.id) as Node3D
		_check(building != null, "scene placement " + p.id)
		if building == null:
			continue
		_check(building.position.is_equal_approx(WorldBuilder.at(p.position, WorldBuildings.ground_y(asset))),
			"scene position " + p.id)
		_check(is_equal_approx(building.rotation.y, deg_to_rad(p.rotation)), "scene rotation " + p.id)
		_check(building.get_meta("asset_id") == p.asset_id and building.get_meta("plot") == p.plot,
			"scene metadata " + p.id)
		var model := building.get_node("Model") as Node3D
		_check(model != null and model.scale.is_equal_approx(Vector3.ONE * 8.0), "model scale " + p.id)
		_check(model.position.is_equal_approx(Vector3(asset.model_offset.x, 0.0, asset.model_offset.y)),
			"model pivot centered " + p.id)
		_test_roof(model, p, roof_variants, roof_audits)
		var collision := building.get_node("Collision/Box") as CollisionShape3D
		_check(collision != null and (collision.shape as BoxShape3D).size.is_equal_approx(asset.collision_size),
			"collision size " + p.id)
		_check(building.get_meta("frontage") == WorldBuildings.facing_of(asset, p.rotation), "scene frontage " + p.id)
	_check(roof_variants.size() == 4, "four deterministic roof variants")
	_test_sites(world, catalog)
	_check(world.get_node("Buildings/Residential").get_child_count() == 18, "scene residential count")
	_check(world.get_node("Buildings/Commercial").get_child_count() == 22, "scene commercial count")
	_check(world.get_node("Buildings/Civic").get_child_count() == 8, "scene civic count")
	var landmark := world.get_node("Landmarks/WorldPulseBeacon") as Node3D
	_check(landmark.position.is_equal_approx(WorldBuilder.at(layout.cell_center(layout.landmark_cell), catalog.beacon.ground_m)),
		"beacon on the landmark cell")
	_check(landmark.get_meta("landmark_id") == "worldpulse_beacon", "beacon identity")
	var meshes := landmark.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 5, "five beacon primitives")
	_check(is_equal_approx((landmark.get_node("Plinth").mesh as CylinderMesh).height, 0.45), "beacon raised plinth")
	_check(is_equal_approx((landmark.get_node("Shaft").mesh as CylinderMesh).height, 11.2), "beacon vertical shaft")
	var crown := landmark.get_node("Crown") as MeshInstance3D
	var crown_material := crown.material_override as StandardMaterial3D
	_check(crown_material.emission_enabled and crown_material.emission.is_equal_approx(catalog.beacon.accent_color),
		"cyan beacon crown")
	_check(landmark.get_node("Collision").get_child_count() == 2, "beacon collision proxy")
	var debug := world.get_node("Buildings/BuildingsDebug") as Node3D
	_check(not debug.visible, "building debug hidden")
	_check(debug.get_child_count() == 49, "debug footprints and labels")
	var invalid_label := 0
	for child in debug.get_children():
		if child is Label3D and (child as Label3D).text.begins_with("INVALID"):
			invalid_label += 1
	_check(invalid_label == 0, "no invalid labels in a valid world")
	var camera: WorldCamera = world.camera
	camera.reset_view(true)
	_check(camera.focus.is_equal_approx(Vector2(-4, -4)), "default focus on plaza")
	_check(is_equal_approx(camera.size, 160.0), "tighter broadcast span")
	var beacon_top := landmark.global_position + Vector3(0, catalog.beacon.height_m, 0)
	var beacon_base := landmark.global_position
	_check(camera.is_position_in_frustum(beacon_top) and camera.is_position_in_frustum(beacon_base),
		"beacon inside the default frustum")
	var viewport := Vector2(root.get_visible_rect().size)
	var screen := camera.unproject_position(beacon_top)
	_check(screen.x > 0 and screen.x < viewport.x and screen.y > 0 and screen.y < viewport.y,
		"beacon on screen at default framing")
	for district_id: String in layout.districts:
		var center := layout.meters(layout.districts[district_id].rect).get_center()
		_check(camera.is_position_in_frustum(Vector3(center.x, 1.0, center.y)),
			"district visible at default framing: " + district_id)
	for p: Dictionary in catalog.placements:
		var asset: Dictionary = catalog.assets[p.asset_id]
		var box := AABB(Vector3(-asset.footprint.x * 0.5, 0.0, -asset.footprint.y * 0.5),
			Vector3(asset.footprint.x, asset.height, asset.footprint.y))
		var root_node: Node3D = world.get_node(parents[p.district]).get_node(p.id)
		var world_box: AABB = root_node.transform * box
		for corner in _aabb_corners(world_box):
			_check(camera.is_position_in_frustum(corner), "building corner framed " + p.id)
	camera.frame_view(Vector2(-4, -4), 68.0, true)
	_check(camera.is_position_in_frustum(beacon_top), "beacon inside plaza close-up")
	camera.frame_view(Vector2.ZERO, 310.0, true)
	_check(camera.is_position_in_frustum(beacon_top), "beacon inside full-map view")
	for district_id: String in layout.districts:
		var center := layout.meters(layout.districts[district_id].rect).get_center()
		_check(camera.is_position_in_frustum(Vector3(center.x, 1.0, center.y)),
			"district inside full-map view: " + district_id)
	# Invalid placement highlighting is reachable from a rejected catalog.
	var data := JSON.parse_string(FileAccess.get_file_as_string(WorldBuildings.DEFAULT_PATH)) as Dictionary
	data.placements[2].position = data.placements[0].position
	var rejected := WorldBuildings.parse(layout, data)
	_check(not rejected.errors.is_empty(), "rejected catalog has errors")
	var probe := Node3D.new()
	root.add_child(probe)
	rejected.build_debug(probe)
	var flagged := 0
	for child in probe.get_children():
		if child is Label3D and (child as Label3D).text.begins_with("INVALID"):
			flagged += 1
	_check(flagged >= 2, "invalid placements highlighted")
	probe.queue_free()
	world.queue_free()
	await process_frame


func _test_roof(model: Node3D, p: Dictionary, variants: Dictionary, audits: Dictionary) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var source := part.mesh.surface_get_material(surface) as StandardMaterial3D
			var active := part.get_active_material(surface) as StandardMaterial3D
			if p.district != "residential_quarter":
				_check(active == source, "nonresidential material untouched")
				continue
			_check(active != source and active.albedo_color == source.albedo_color, "roof override without whole-model tint")
			var index := String(p.id).hash() % WorldBuildings.ROOF_PALETTE.size()
			variants[index] = true
			if not audits.has(index):
				var original := source.albedo_texture.get_image()
				var changed := active.albedo_texture.get_image()
				var outside := 0
				var inside := 0
				for y in 512:
					for x in 512:
						if original.get_pixel(x, y) != changed.get_pixel(x, y):
							if WorldBuildings.ROOF_SWATCH.has_point(Vector2i(x, y)): inside += 1
							else: outside += 1
				_check(outside == 0 and inside == 4096, "only roof swatch changes (inside=%d outside=%d)" % [inside, outside])
				_check(source.albedo_texture.resource_path == WorldBuildings.SUBURBAN_ATLAS, "source atlas retained")
				audits[index] = true
			if audits.has(p.asset_id): continue
			var arrays := part.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var roof_count := 0
			for i in range(0, indices.size(), 3):
				var roof_vertices := 0
				for j in 3:
					var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][indices[i+j]] * 512.0
					if WorldBuildings.ROOF_SWATCH.has_point(Vector2i(uv)):
						roof_vertices += 1
						_check(arrays[Mesh.ARRAY_VERTEX][indices[i+j]].y > 0.32, "roof excludes ground shrubs")
				_check(roof_vertices == 0 or roof_vertices == 3, "triangle cannot interpolate across roof and wall atlas regions")
				if roof_vertices == 3: roof_count += 1
			_check(roof_count > 100, "audited roof triangles present " + p.asset_id)
			audits[p.asset_id] = true


func _test_sites(world: Node3D, catalog: WorldBuildings) -> void:
	var sites := world.get_node("Land/BuildingSites")
	var paved: Array[Rect2] = []
	var lawns := 0
	var courts := 0
	for site: MeshInstance3D in sites.get_children():
		var size: Vector3 = site.mesh.size
		var rect := Rect2(Vector2(site.position.x, site.position.z) - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
		var top := site.position.y + size.y * 0.5
		var lawn := String(site.name).begins_with("Lawn_")
		_check(is_equal_approx(top, WorldBuildings.LAWN_TOP if lawn else WorldBuildings.PAVING_TOP), "separate site elevations")
		_check(site.get_child_count() == 0, "site has no blocking collider")
		var contained := false
		for plot: Dictionary in catalog.layout.plots.values():
			if plot.district != "greenbelt" and catalog.layout.meters(plot.rect).grow(0.001).encloses(rect): contained = true
		_check(contained, "site contained in built plot")
		_check(not rect.intersects(catalog.layout.meters(catalog.layout.plaza)), "site outside plaza")
		for cell: Vector2i in catalog.layout.roads:
			_check(not rect.grow(-0.001).intersects(Rect2(catalog.layout.cell_center(cell) - Vector2.ONE * 4, Vector2.ONE * 8)), "site outside roads")
		if lawn:
			lawns += 1
		else:
			for peer in paved: _check(not rect.grow(-0.001).intersects(peer), "no coplanar paving overlap")
			paved.append(rect)
			if String(site.name).begins_with("ServiceCourt_"): courts += 1
			for p: Dictionary in catalog.placements:
				var footprint := _bounds(WorldBuildings.footprint_corners(p.position, catalog.assets[p.asset_id].footprint, p.rotation))
				_check(not rect.grow(-0.001).intersects(footprint), "paving outside building footprint")
	_check(lawns == 18 and courts == 2, "eighteen lawns and two open market courts: %d/%d" % [lawns, courts])
	for p: Dictionary in catalog.placements:
		var corridor := catalog.entrance_corridor(p)
		_check(paved.any(func(rect: Rect2) -> bool: return rect.grow(0.001).encloses(corridor)), "paved entrance " + p.id)


func _reject(layout: WorldLayout, source: Dictionary, message: String, mutate: Callable) -> void:
	var data := source.duplicate(true)
	mutate.call(data)
	var catalog := WorldBuildings.parse(layout, data)
	_check(message in "\n".join(catalog.errors), "rejects " + message)


func _bounds(corners: PackedVector2Array) -> Rect2:
	var rect := Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		rect = rect.expand(corner)
	return rect


func _aabb_corners(box: AABB) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				result.append(Vector3(x, y, z))
	return result


func _inside(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)

