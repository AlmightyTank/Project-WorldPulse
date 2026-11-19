class_name WorldBuildings
extends RefCounted

# Catalog-driven building placement. Measured wrapper bounds are the source of truth;
# the JSON mirrors them and validation rejects any drift.

const DEFAULT_PATH := "res://data/building_catalog.json"
const WORLD_GROUND_Y := -0.02
const TOLERANCE := 0.02
const ROAD_CLEARANCE_M := 1.0
const CATEGORY_COLORS := {
	"residential": Color("98bc85"), "commercial": Color("d8a68a"), "civic": Color("a3b8c5"),
}
const DISTRICT_PARENTS := {
	"residential_quarter": "residential", "market_street": "commercial", "civic_quarter": "civic",
	"town_square": "commercial",
}
const FRONTAGE_VECTORS := {
	"north": Vector2i(0, -1), "east": Vector2i(1, 0), "south": Vector2i(0, 1), "west": Vector2i(-1, 0),
}
const VALID_ROTATIONS := [0, 90, 180, 270]
const SUBURBAN_ATLAS := "res://assets/third_party/kenney/city-kit-suburban/models/Textures/colormap.png"
const ROOF_SWATCH := Rect2i(32, 128, 32, 128)
const ROOF_PALETTE := [Color("935e4f"), Color("586478"), Color("797c5b"), Color("77665e")]
const AUDITED_HOUSES := ["res_building_type_a", "res_building_type_c", "res_building_type_f",
	"res_building_type_j", "res_building_type_n", "res_building_type_t"]
const LAWN_TOP := 0.004
const PAVING_TOP := 0.06
const MARKET_COURTS := {
	"market_north": Rect2(49.3, -16.0, 7.0, 13.0),
	"market_south": Rect2(25.0, 16.0, 7.2, 13.5)
}
const SITE_COLORS := {
	"Lawn": Color("8c9c68"), "Approach": Color("bab19b"), "Forecourt": Color("a49d8e"),
	"ServiceCourt": Color("9b9283"),
}

var layout: WorldLayout
var errors := PackedStringArray()
var assets: Dictionary = {}
var placements: Array[Dictionary] = []
var beacon: Dictionary = {}
var placement_errors: Dictionary = {}
var measured: Dictionary = {}
var _roof_textures: Dictionary = {}
var _roof_materials: Dictionary = {}


static func read(world_layout: WorldLayout, path: String = DEFAULT_PATH) -> WorldBuildings:
	var result := WorldBuildings.new()
	result.layout = world_layout
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		result.errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return result
	result._parse(json.data)
	return result


static func parse(world_layout: WorldLayout, data: Variant) -> WorldBuildings:
	var result := WorldBuildings.new()
	result.layout = world_layout
	result._parse(data)
	return result


func _parse(data: Variant) -> void:
	if layout == null or not layout.errors.is_empty():
		errors.append("Building catalog requires a valid world layout")
		return
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("units") != "metres":
		errors.append("Expected schema_version 1 and units metres")
		return
	if not data.get("assets") is Array or not data.get("placements") is Array:
		errors.append("Expected assets and placements arrays")
		return
	_parse_beacon(data.get("beacon"))
	for entry: Variant in data.assets:
		_parse_asset(entry)
	for entry: Variant in data.placements:
		_parse_placement(entry)
	_validate_placements()
	_validate_districts()
	_validate_landmark()
	_collect_placement_errors()


func _parse_beacon(entry: Variant) -> void:
	if not entry is Dictionary:
		errors.append("Missing beacon configuration")
		return
	for key in ["id"]:
		if not _valid_id(entry.get(key)):
			errors.append("Invalid beacon id")
			return
	for key in ["base_radius_m", "height_m", "ground_m", "collision_radius_m"]:
		if not _number(entry.get(key)) or float(entry.get(key)) <= 0.0:
			errors.append("Invalid beacon " + key)
			return
	for key in ["stone_color", "body_color", "accent_color"]:
		if not entry.get(key) is String or not Color.html_is_valid(entry.get(key)):
			errors.append("Invalid beacon " + key)
			return
	beacon = {
		"id": entry.id, "base_radius_m": float(entry.base_radius_m),
		"height_m": float(entry.height_m), "ground_m": float(entry.ground_m),
		"collision_radius_m": float(entry.collision_radius_m),
		"stone_color": Color.html(entry.stone_color), "body_color": Color.html(entry.body_color),
		"accent_color": Color.html(entry.accent_color),
	}


func _parse_asset(entry: Variant) -> void:
	if not entry is Dictionary or not _valid_id(entry.get("id")):
		errors.append("Invalid building asset id: %s" % str(entry))
		return
	var id: String = entry.id
	if assets.has(id):
		errors.append("Duplicate building asset id: " + id)
		return
	if not entry.get("source_pack") is String or entry.source_pack.is_empty():
		errors.append("Asset %s has no source pack" % id)
		return
	if not entry.get("wrapper") is String or not entry.wrapper.begins_with("assets/"):
		errors.append("Asset %s has no project wrapper path" % id)
		return
	if not entry.get("category") in ["residential", "commercial"]:
		errors.append("Asset %s has unsupported category" % id)
		return
	if not _numbers(entry.get("footprint_m"), 2) or entry.footprint_m[0] <= 0.0 \
			or entry.footprint_m[1] <= 0.0:
		errors.append("Asset %s has invalid footprint" % id)
		return
	if not _number(entry.get("height_m")) or float(entry.height_m) <= 0.0:
		errors.append("Asset %s has invalid height" % id)
		return
	if not entry.get("frontage") in FRONTAGE_VECTORS.keys() + ["unknown"]:
		errors.append("Asset %s has invalid frontage" % id)
		return
	if not _number(entry.get("ground_offset_m")):
		errors.append("Asset %s has invalid ground offset" % id)
		return
	if not _rotations(entry.get("rotations")):
		errors.append("Asset %s has unsupported rotations" % id)
		return
	var collision: Variant = entry.get("collision")
	if not collision is Dictionary or collision.get("shape") != "box" \
			or not _numbers(collision.get("size_m"), 3) or not _numbers(collision.get("offset_m"), 3):
		errors.append("Asset %s has invalid collision config" % id)
		return
	assets[id] = {
		"id": id, "source_pack": entry.source_pack, "wrapper": entry.wrapper,
		"category": entry.category,
		"footprint": Vector2(entry.footprint_m[0], entry.footprint_m[1]),
		"height": float(entry.height_m), "frontage": entry.frontage,
		"ground_offset": float(entry.ground_offset_m),
		"rotations": entry.rotations.map(func(value: Variant) -> int: return int(value)),
		"collision_size": Vector3(collision.size_m[0], collision.size_m[1], collision.size_m[2]),
		"collision_offset": Vector3(collision.offset_m[0], collision.offset_m[1], collision.offset_m[2]),
		"future_use": str(entry.get("future_use", "")),
		"model_offset": Vector2.ZERO,
	}
	_validate_asset_source(assets[id])


func _validate_asset_source(asset: Dictionary) -> void:
	var id: String = asset.id
	var manifest := KenneyAssets.find(id)
	if manifest.is_empty():
		errors.append("Asset %s is not in the Kenney manifest" % id)
		return
	if manifest.get("category") != asset.category:
		errors.append("Asset %s category disagrees with the manifest" % id)
	if "res://" + str(manifest.get("imported_path", "")) != "res://" + asset.wrapper:
		errors.append("Asset %s wrapper does not match the manifest path" % id)
	if not ResourceLoader.exists("res://" + asset.wrapper, "PackedScene"):
		errors.append("Asset %s wrapper does not resolve" % id)
		return
	# Measure the real scaled wrapper, including child transforms.
	var node := KenneyAssets.instance(id)
	if node == null:
		errors.append("Asset %s wrapper cannot instantiate" % id)
		return
	var box := AABB()
	var first := true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var path := Transform3D.IDENTITY
		var current: Node3D = mesh
		while current != node:
			path = current.transform * path
			current = current.get_parent() as Node3D
		var world_box: AABB = node.transform * (path * mesh.get_aabb())
		box = world_box if first else box.merge(world_box)
		first = false
	node.free()
	measured[id] = box
	if first:
		errors.append("Asset %s has no measurable mesh" % id)
		return
	# Recenter sub-centimetre source pivots so placement position is the footprint center.
	asset.model_offset = Vector2(-(box.position.x + box.size.x * 0.5), -(box.position.z + box.size.z * 0.5))
	var footprint: Vector2 = asset.footprint
	if absf(box.size.x - footprint.x) > TOLERANCE or absf(box.size.z - footprint.y) > TOLERANCE \
			or absf(box.size.y - asset.height) > TOLERANCE:
		errors.append("Asset %s measured bounds %s disagree with the catalog" % [id, str(box.size)])
	if absf(box.position.y - asset.ground_offset) > TOLERANCE:
		errors.append("Asset %s ground offset disagrees with the measured base" % id)
	if absf(asset.model_offset.x) > 0.2 or absf(asset.model_offset.y) > 0.2:
		errors.append("Asset %s source pivot is more than 0.2 m off center" % id)
	var collision: Vector3 = asset.collision_size
	if absf(collision.x - box.size.x) > TOLERANCE or absf(collision.y - box.size.y) > TOLERANCE \
			or absf(collision.z - box.size.z) > TOLERANCE:
		errors.append("Asset %s collision size disagrees with its measured bounds" % id)
	if absf(asset.collision_offset.y - box.size.y * 0.5) > TOLERANCE:
		errors.append("Asset %s collision offset does not sit on the measured base" % id)


func _parse_placement(entry: Variant) -> void:
	if not entry is Dictionary or not _valid_id(entry.get("id")):
		errors.append("Invalid building placement: %s" % str(entry))
		return
	var id: String = entry.id
	if placements.any(func(p: Dictionary) -> bool: return p.id == id):
		errors.append("Duplicate building placement id: " + id)
		return
	var placement := {
		"id": id, "asset_id": str(entry.get("asset_id", "")),
		"district": str(entry.get("district", "")), "plot": str(entry.get("plot", "")),
		"position": Vector2.ZERO, "rotation": 0, "variation": str(entry.get("variation", "")),
		"notes": str(entry.get("notes", "")),
	}
	var position_ok := _numbers(entry.get("position"), 2)
	if position_ok:
		placement.position = Vector2(entry.position[0], entry.position[1])
	if not _number(entry.get("rotation")) or int(entry.rotation) != entry.rotation:
		errors.append("Placement %s has invalid rotation" % id)
		placement.rotation = -1
	else:
		placement.rotation = int(entry.rotation)
	if not _numbers(entry.get("footprint_m"), 2):
		errors.append("Placement %s has invalid footprint" % id)
	placement["declared_footprint"] = (
		Vector2(entry.footprint_m[0], entry.footprint_m[1]) if _numbers(entry.get("footprint_m"), 2)
		else Vector2.ZERO
	)
	placement["position_ok"] = position_ok
	placements.append(placement)
	var errs := PackedStringArray()
	if not position_ok:
		errs.append("invalid position")
	if not assets.has(placement.asset_id):
		errs.append("unknown asset id " + placement.asset_id)
	if not layout.districts.has(placement.district):
		errs.append("unknown district " + placement.district)
	if not layout.plots.has(placement.plot):
		errs.append("unknown plot " + placement.plot)
	elif layout.plots[placement.plot].district != placement.district:
		errs.append("plot %s belongs to %s" % [placement.plot, layout.plots[placement.plot].district])
	if placement.variation.strip_edges().is_empty():
		errs.append("missing visual variation")
	if not errs.is_empty():
		placement_errors[id] = errs


func _validate_placements() -> void:
	for p: Dictionary in placements:
		var errs: PackedStringArray = placement_errors.get(p.id, PackedStringArray())
		var asset: Dictionary = assets.get(p.asset_id, {})
		if asset.is_empty() or p.rotation < 0 or not p.position_ok:
			placement_errors[p.id] = errs
			continue
		if not layout.plots.has(p.plot):
			placement_errors[p.id] = errs
			continue
		if not p.rotation in asset.rotations:
			errs.append("rotation %d is not supported by %s" % [p.rotation, p.asset_id])
		if p.declared_footprint.distance_to(asset.footprint) > TOLERANCE:
			errs.append("declared footprint disagrees with the catalog asset")
		var corners := footprint_corners(p.position, asset.footprint, p.rotation)
		var plot_rect: Rect2 = layout.meters(layout.plots[p.plot].rect)
		for corner: Vector2 in corners:
			if not _inside(corner, plot_rect.grow(TOLERANCE)):
				errs.append("footprint leaves plot " + p.plot)
				break
		if not _inside(p.position, plot_rect.grow(TOLERANCE)):
			errs.append("center leaves plot " + p.plot)
		var terrain: Rect2 = layout.meters(layout.grid)
		for corner: Vector2 in corners:
			if not _inside(corner, terrain.grow(TOLERANCE)):
				errs.append("footprint leaves the terrain")
				break
		if obb_rect_overlap(corners, layout.meters(layout.plaza), TOLERANCE):
			errs.append("footprint overlaps the plaza")
		if p.district == "greenbelt":
			errs.append("buildings are not allowed in the greenbelt")
		elif obb_rect_overlap(corners, _district_rect("greenbelt"), TOLERANCE):
			errs.append("footprint overlaps the protected greenbelt")
		var road_hit := ""
		var clearance_hit := ""
		for cell: Vector2i in layout.roads:
			var rect := _road_rect(cell)
			if obb_rect_overlap(corners, rect, TOLERANCE):
				road_hit = str(cell)
				break
			if clearance_hit.is_empty() and obb_rect_overlap(corners, rect.grow(ROAD_CLEARANCE_M), TOLERANCE):
				clearance_hit = str(cell)
		if not road_hit.is_empty():
			errs.append("footprint overlaps the road at cell %s" % road_hit)
		elif not clearance_hit.is_empty():
			errs.append("footprint enters the %.1f m sidewalk clearance at cell %s" % [ROAD_CLEARANCE_M, clearance_hit])
		var facing := facing_of(asset, p.rotation)
		if facing == "unknown":
			errs.append("placement requires an identifiable entrance")
		elif not plot_frontage(p.plot, facing):
			errs.append("frontage %s does not meet a road for plot %s" % [facing, p.plot])
		var access := entrance_corridor(p)
		if not access.has_area():
			errs.append("entrance has no direct 2 m access corridor to a street")
		else:
			for other: Dictionary in placements:
				if other.id == p.id or not assets.has(other.asset_id) or other.rotation < 0:
					continue
				var obstacle := footprint_corners(other.position, assets[other.asset_id].footprint, other.rotation)
				if obb_rect_overlap(obstacle, access, TOLERANCE):
					errs.append("entrance access blocked by placement " + other.id)
		if not errs.is_empty():
			placement_errors[p.id] = errs
	for i in placements.size():
		for j in range(i + 1, placements.size()):
			var a: Dictionary = placements[i]
			var b: Dictionary = placements[j]
			var asset_a: Dictionary = assets.get(a.asset_id, {})
			var asset_b: Dictionary = assets.get(b.asset_id, {})
			if asset_a.is_empty() or asset_b.is_empty() or a.rotation < 0 or b.rotation < 0:
				continue
			var corners_a := footprint_corners(a.position, asset_a.footprint, a.rotation)
			var corners_b := footprint_corners(b.position, asset_b.footprint, b.rotation)
			if obb_overlap(corners_a, corners_b, TOLERANCE):
				_add_placement_error(a.id, "footprint overlaps placement " + b.id)
				_add_placement_error(b.id, "footprint overlaps placement " + a.id)


func _validate_districts() -> void:
	for plot_id: String in layout.plots:
		var district: String = layout.plots[plot_id].district
		var used := placements.any(func(p: Dictionary) -> bool: return p.plot == plot_id)
		if district == "greenbelt" and used:
			errors.append("Greenbelt plot %s must stay open" % plot_id)
		if district == "civic_quarter" and not used:
			errors.append("Civic plot %s has no placement or documented reservation" % plot_id)
		if district == "residential_quarter" and not used:
			errors.append("Residential plot %s is unused without a documented reservation" % plot_id)


func _validate_landmark() -> void:
	if beacon.is_empty():
		return
	var center := layout.cell_center(layout.landmark_cell)
	var plaza: Rect2 = layout.meters(layout.plaza)
	var radius: float = beacon.base_radius_m
	var plaza_distance := minf(
		minf(center.x - plaza.position.x, plaza.end.x - center.x),
		minf(center.y - plaza.position.y, plaza.end.y - center.y)
	)
	if plaza_distance - radius < TOLERANCE:
		errors.append("Beacon base leaves the plaza")
	if layout.landmark_cell != layout.plaza.get_center():
		errors.append("Beacon is not on the reserved landmark cell")
	if _circle_rect_distance(center, radius, layout.meters(layout.gathering)) <= TOLERANCE:
		errors.append("Beacon blocks the gathering reservation")
	for p: Dictionary in placements:
		var asset: Dictionary = assets.get(p.asset_id, {})
		if asset.is_empty() or p.rotation < 0:
			continue
		var corners := footprint_corners(p.position, asset.footprint, p.rotation)
		if _circle_polygon_distance(center, radius, corners) <= TOLERANCE:
			_add_placement_error(p.id, "footprint overlaps the beacon")


func build(residential: Node3D, commercial: Node3D, civic: Node3D) -> bool:
	var parents := {
		"residential": residential, "commercial": commercial, "civic": civic,
	}
	for p: Dictionary in placements:
		var errs: PackedStringArray = placement_errors.get(p.id, PackedStringArray())
		if not errs.is_empty():
			continue
		var asset: Dictionary = assets[p.asset_id]
		var parent: Node3D = parents.get(DISTRICT_PARENTS[p.district], null)
		if parent == null:
			continue
		var root := Node3D.new()
		root.name = p.id
		root.position = WorldBuilder.at(p.position, ground_y(asset))
		root.rotation.y = deg_to_rad(p.rotation)
		root.set_meta("placement_id", p.id)
		root.set_meta("asset_id", p.asset_id)
		root.set_meta("district", p.district)
		root.set_meta("plot", p.plot)
		root.set_meta("frontage", facing_of(asset, p.rotation))
		var model := KenneyAssets.instance(p.asset_id)
		if model == null:
			return false
		if p.district == "residential_quarter" and p.asset_id in AUDITED_HOUSES:
			_apply_roof(model, String(p.id).hash() % ROOF_PALETTE.size())
		model.name = "Model"
		model.position = Vector3(asset.model_offset.x, 0.0, asset.model_offset.y)
		root.add_child(model)
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 1
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Box"
		var shape := BoxShape3D.new()
		shape.size = asset.collision_size
		shape_node.shape = shape
		shape_node.position = asset.collision_offset
		body.add_child(shape_node)
		root.add_child(body)
		parent.add_child(root)
	return true


func _apply_roof(model: Node3D, palette_index: int) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var source := part.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture == null or source.albedo_texture.resource_path != SUBURBAN_ATLAS:
				continue
			if not _roof_textures.has(palette_index):
				var image := source.albedo_texture.get_image().duplicate() as Image
				if image == null or image.get_size() != Vector2i(512, 512) or image.has_mipmaps():
					push_error("Unexpected suburban roof atlas layout")
					return
				if image.is_compressed() and image.decompress() != OK:
					push_error("Cannot decode suburban roof atlas")
					return
				var tint: Color = ROOF_PALETTE[palette_index]
				for y in range(ROOF_SWATCH.position.y, ROOF_SWATCH.end.y):
					for x in range(ROOF_SWATCH.position.x, ROOF_SWATCH.end.x):
						var original := image.get_pixel(x, y)
						var shade := original.g / (197.0 / 255.0)
						image.set_pixel(x, y, Color(tint.r * shade, tint.g * shade, tint.b * shade, original.a))
				_roof_textures[palette_index] = ImageTexture.create_from_image(image)
			var key := "%d:%d" % [source.get_instance_id(), palette_index]
			if not _roof_materials.has(key):
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_texture = _roof_textures[palette_index]
				_roof_materials[key] = material
			part.set_surface_override_material(surface, _roof_materials[key])


func build_sites(parent: Node3D) -> void:
	var sites := Node3D.new()
	sites.name = "BuildingSites"
	parent.add_child(sites)
	var footprints := {}
	var access := {}
	for p: Dictionary in placements:
		var corners := footprint_corners(p.position, assets[p.asset_id].footprint, p.rotation)
		var bounds := Rect2(corners[0], Vector2.ZERO)
		for corner in corners:
			bounds = bounds.expand(corner)
		footprints[p.id] = bounds
		access[p.id] = entrance_corridor(p)
	var paving: Array[Rect2] = []
	var lawns: Array[Rect2] = []
	for p: Dictionary in placements:
		var plot := layout.meters(layout.plots[p.plot].rect)
		var path: Rect2 = access[p.id].intersection(plot)
		var kind := "Approach"
		if p.district == "residential_quarter":
			for margin: float in [1.8, 0.9, 0.25, 0.05]:
				var lawn: Rect2 = footprints[p.id].grow(margin).intersection(plot.grow(-0.35))
				if lawn.has_area() and _site_clear(lawn, p.id, footprints, lawns):
					_site_slab(sites, p.id, "Lawn", lawn, LAWN_TOP)
					lawns.append(lawn)
					break
		else:
			var facing := facing_of(assets[p.asset_id], p.rotation)
			var transverse := Vector2(FRONTAGE_VECTORS[facing]).orthogonal().abs()
			var inset := transverse * maxf(0.0, assets[p.asset_id].footprint.x * 0.36 - 1.0)
			var apron := Rect2(path.position - inset, path.size + 2.0 * inset).intersection(plot)
			if _site_clear(apron, p.id, footprints, paving) and _site_clear(apron, p.id, access, []):
				path = apron
				kind = "Forecourt"
		_site_slab(sites, p.id, kind, path, PAVING_TOP)
		paving.append(path)
	for plot_id: String in MARKET_COURTS:
		if not layout.plots.has(plot_id) or layout.plots[plot_id].district != "market_street":
			continue
		var court: Rect2 = MARKET_COURTS[plot_id]
		if layout.meters(layout.plots[plot_id].rect).encloses(court) and _site_clear(court, "", footprints, paving):
			_site_slab(sites, plot_id, "ServiceCourt", court, PAVING_TOP)
			paving.append(court)


static func _site_clear(rect: Rect2, owner: String, obstacles: Dictionary, peers: Array[Rect2]) -> bool:
	for id: String in obstacles:
		if id != owner and rect.intersects(obstacles[id]):
			return false
	for peer in peers:
		if rect.intersects(peer):
			return false
	return true


static func _site_slab(parent: Node3D, id: String, kind: String, rect: Rect2, top: float) -> void:
	WorldBuilder.slab(parent, kind + "_" + id, rect, top, top - WORLD_GROUND_Y + 0.01, SITE_COLORS[kind])


func build_beacon(parent: Node3D) -> bool:
	if beacon.is_empty():
		return false
	for child in parent.get_children():
		child.free()
	parent.position = WorldBuilder.at(layout.cell_center(layout.landmark_cell), beacon.ground_m)
	parent.set_meta("landmark_id", beacon.id)
	parent.set_meta("height_m", beacon.height_m)
	var stone := _material(beacon.stone_color)
	var body := _material(beacon.body_color)
	var accent := _material(beacon.accent_color, true)
	# Raised plinth and step, a tapered shaft, and one cyan crown.
	mesh_part(parent, "Plinth", _cylinder(beacon.base_radius_m, beacon.base_radius_m, 0.45, 12), stone, 0.225)
	mesh_part(parent, "Step", _cylinder(2.6, 2.6, 0.35, 12), stone, 0.625)
	var shaft_height: float = beacon.height_m - 2.8
	mesh_part(parent, "Shaft", _cylinder(0.95, 1.45, shaft_height, 8), body, 0.8 + shaft_height * 0.5)
	mesh_part(parent, "Collar", _cylinder(1.6, 1.6, 0.4, 8), stone, beacon.height_m - 1.8)
	mesh_part(parent, "Crown", _cylinder(0.6, 1.35, 1.6, 8), accent, beacon.height_m - 0.8)
	var collision := StaticBody3D.new()
	collision.name = "Collision"
	collision.collision_layer = 1
	collision.collision_mask = 1
	for entry in [[beacon.collision_radius_m, 0.8, 0.4], [1.6, beacon.height_m - 0.8, (beacon.height_m + 0.8) * 0.5]]:
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = entry[0]
		shape.height = entry[1]
		shape_node.shape = shape
		shape_node.position.y = entry[2]
		collision.add_child(shape_node)
	parent.add_child(collision)
	return true


func build_debug(parent: Node3D) -> void:
	for child in parent.get_children():
		child.free()
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Dictionary in placements:
		var asset: Dictionary = assets.get(p.asset_id, {})
		if asset.is_empty() or p.rotation < 0:
			continue
		var errs: PackedStringArray = placement_errors.get(p.id, PackedStringArray())
		var color: Color = Color("e2574c") if not errs.is_empty() \
			else CATEGORY_COLORS.get(DISTRICT_PARENTS.get(p.district, ""), Color.WHITE)
		var corners := footprint_corners(p.position, asset.footprint, p.rotation)
		for i in 4:
			_debug_line(lines, corners[i], corners[(i + 1) % 4], 0.18, 0.35, color)
		var access := entrance_corridor(p)
		if access.has_area():
			var access_corners := footprint_corners(access.get_center(), access.size, 0)
			for i in 4:
				_debug_line(lines, access_corners[i], access_corners[(i + 1) % 4], 0.12, 0.38, Color("ffe196"))
		var facing := facing_of(asset, p.rotation)
		if facing != "unknown":
			var direction := Vector2(FRONTAGE_VECTORS[facing])
			_debug_line(lines, p.position, p.position + direction * (asset.footprint.y * 0.5 + 2.5),
				0.26, 0.36, color.lightened(0.2))
		var label := Label3D.new()
		label.text = ("INVALID\n" if not errs.is_empty() else "") \
			+ "%s\nplot %s · %s %d°" % [p.id, p.plot, facing, p.rotation]
		label.font_size = 28
		label.pixel_size = 0.07
		label.outline_size = 10
		label.outline_modulate = Color("192322")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = WorldBuilder.at(p.position, asset.height + 1.2)
		parent.add_child(label)
	_add_debug_surface(parent, lines)


func district_count(district_id: String) -> int:
	return placements.filter(func(p: Dictionary) -> bool: return p.district == district_id).size()


func built_count() -> int:
	var total := 0
	for p: Dictionary in placements:
		if placement_errors.get(p.id, PackedStringArray()).is_empty():
			total += 1
	return total


func invalid_count() -> int:
	return placements.size() - built_count()


func signature() -> String:
	var parts := PackedStringArray()
	for p: Dictionary in placements:
		parts.append("%s|%s|%s|%s|%.3f,%.3f|%d|%s" % [
			p.id, p.asset_id, p.district, p.plot, p.position.x, p.position.y, p.rotation, p.variation,
		])
	for asset_id: String in assets:
		parts.append(asset_id)
	return "\n".join(parts)


static func ground_y(asset: Dictionary) -> float:
	return WORLD_GROUND_Y + float(asset.ground_offset)


static func footprint_corners(center: Vector2, size: Vector2, rotation_deg: int) -> PackedVector2Array:
	var angle := deg_to_rad(rotation_deg)
	var axis_x := Vector2(cos(angle), -sin(angle))
	var axis_z := Vector2(sin(angle), cos(angle))
	var half := size * 0.5
	return PackedVector2Array([
		center + axis_x * half.x + axis_z * half.y,
		center - axis_x * half.x + axis_z * half.y,
		center - axis_x * half.x - axis_z * half.y,
		center + axis_x * half.x - axis_z * half.y,
	])


static func facing_of(asset: Dictionary, rotation_deg: int) -> String:
	var frontage: String = asset.get("frontage", "unknown")
	if frontage == "unknown":
		return "unknown"
	var local := Vector2(FRONTAGE_VECTORS[frontage])
	var angle := deg_to_rad(rotation_deg)
	var world := Vector2(local.x * cos(angle) + local.y * sin(angle),
		-local.x * sin(angle) + local.y * cos(angle))
	for name: String in FRONTAGE_VECTORS:
		if Vector2(FRONTAGE_VECTORS[name]).is_equal_approx(world):
			return name
	return "unknown"


# A plot touching a road does not prove a rear entrance can reach it.
# Require a straight 2 m pedestrian corridor from the facade to the plot's street edge.
func entrance_corridor(p: Dictionary) -> Rect2:
	if not assets.has(p.asset_id) or not layout.plots.has(p.plot) or not p.position_ok:
		return Rect2()
	var asset: Dictionary = assets[p.asset_id]
	var facing := facing_of(asset, p.rotation)
	if not FRONTAGE_VECTORS.has(facing):
		return Rect2()
	var direction := Vector2(FRONTAGE_VECTORS[facing])
	var start: Vector2 = p.position + direction * asset.footprint.y * 0.5
	var plot: Rect2 = layout.meters(layout.plots[p.plot].rect)
	var end := start
	match facing:
		"north": end.y = plot.position.y
		"south": end.y = plot.end.y
		"west": end.x = plot.position.x
		"east": end.x = plot.end.x
	if (end - start).dot(direction) <= 0.0:
		return Rect2()
	var side := direction.orthogonal()
	# Check both sides, so an entrance straddling a tile seam is still valid.
	for offset in [-0.99, 0.0, 0.99]:
		var probe: Vector2 = end + direction * 0.01 + side * offset
		var cell := Vector2i(((probe - layout.origin_m) / WorldLayout.PITCH).floor())
		if not layout.roads.has(cell):
			return Rect2()
	var corridor := Rect2(start - side, Vector2.ZERO).expand(start + side)
	corridor = corridor.expand(end - side).expand(end + side)
	return corridor if plot.grow(TOLERANCE).encloses(corridor) else Rect2()


func plot_frontage(plot_id: String, direction: String) -> bool:
	if not layout.plots.has(plot_id) or not FRONTAGE_VECTORS.has(direction):
		return false
	var rect: Rect2i = layout.plots[plot_id].rect
	for cell: Vector2i in layout.roads:
		match direction:
			"north":
				if cell.y == rect.position.y - 1 and cell.x >= rect.position.x and cell.x < rect.end.x:
					return true
			"south":
				if cell.y == rect.end.y and cell.x >= rect.position.x and cell.x < rect.end.x:
					return true
			"west":
				if cell.x == rect.position.x - 1 and cell.y >= rect.position.y and cell.y < rect.end.y:
					return true
			"east":
				if cell.x == rect.end.x and cell.y >= rect.position.y and cell.y < rect.end.y:
					return true
	return false


static func obb_overlap(a: PackedVector2Array, b: PackedVector2Array, tolerance := 0.0) -> bool:
	for polygon in [a, b]:
		for i in polygon.size():
			var edge: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
			if edge.length_squared() < 1e-12:
				continue
			var axis := Vector2(-edge.y, edge.x).normalized()
			var a_span := _project(a, axis)
			var b_span := _project(b, axis)
			if a_span.y <= b_span.x - tolerance or b_span.y <= a_span.x - tolerance:
				return false
	return true


static func obb_rect_overlap(corners: PackedVector2Array, rect: Rect2, tolerance := 0.0) -> bool:
	return obb_overlap(corners, PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	]), tolerance)


static func _project(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var low := polygon[0].dot(axis)
	var high := low
	for point: Vector2 in polygon:
		var value := point.dot(axis)
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


func _add_placement_error(id: String, message: String) -> void:
	if id.is_empty():
		errors.append(message)
		return
	var list: PackedStringArray = placement_errors.get(id, PackedStringArray())
	list.append(message)
	placement_errors[id] = list


func _collect_placement_errors() -> void:
	for id: String in placement_errors:
		for message: String in placement_errors[id]:
			errors.append("Placement %s: %s" % [id, message])


func _district_rect(district_id: String) -> Rect2:
	return layout.meters(layout.districts[district_id].rect) if layout.districts.has(district_id) else Rect2()


func _road_rect(cell: Vector2i) -> Rect2:
	return Rect2(layout.origin_m + Vector2(cell) * WorldLayout.PITCH,
		Vector2(WorldLayout.PITCH, WorldLayout.PITCH))


static func _inside(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y


static func _circle_rect_distance(center: Vector2, radius: float, rect: Rect2) -> float:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_to(closest) - radius


static func _circle_polygon_distance(center: Vector2, radius: float, polygon: PackedVector2Array) -> float:
	var closest := INF
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		closest = minf(closest, _segment_distance(center, a, b))
	return closest - radius


static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() < 1e-12:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.35
	return material


static func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func mesh_part(parent: Node3D, id: String, mesh: Mesh, material: Material, y: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.position.y = y
	instance.material_override = material
	parent.add_child(instance)


static func _add_debug_surface(parent: Node3D, surface: SurfaceTool) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	surface.set_material(material)
	var instance := MeshInstance3D.new()
	instance.name = "Footprints"
	instance.mesh = surface.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _debug_line(surface: SurfaceTool, a: Vector2, b: Vector2, width: float, y: float, color: Color) -> void:
	var normal := (b - a).normalized().orthogonal() * width * 0.5
	for point: Vector2 in [a - normal, a + normal, b + normal, a - normal, b + normal, b - normal]:
		surface.set_color(color)
		surface.add_vertex(WorldBuilder.at(point, y))


static func _valid_id(value: Variant) -> bool:
	return value is String and value.is_valid_ascii_identifier() and value == value.to_lower()


static func _number(value: Variant) -> bool:
	return value is float or value is int


static func _numbers(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item: Variant in value:
		if not _number(item) or absf(item) > 1000000.0:
			return false
	return true


static func _rotations(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	var seen := {}
	for item: Variant in value:
		if not _number(item) or int(item) != item or not int(item) in VALID_ROTATIONS or seen.has(int(item)):
			return false
		seen[int(item)] = true
	return true

