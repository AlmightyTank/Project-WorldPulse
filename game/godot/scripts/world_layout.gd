class_name WorldLayout
extends RefCounted

const DEFAULT_PATH := "res://data/founders_district.json"
const PITCH := 8.0
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
# Masks are N/E/S/W, from the measured unrotated mesh edges (north is -Z).
const ROAD_MASKS := {
	"road_straight": 0b1010, "road_crossing": 0b1010, "road_bend": 0b1100,
	"road_intersection": 0b1110, "road_crossroad": 0b1111,
}
const ROAD_SHAPES := ["road_straight", "road_bend", "road_intersection", "road_crossroad"]

var errors := PackedStringArray()
var id: String
var origin_m: Vector2
var grid: Rect2i
var districts: Dictionary = {}
var plots: Dictionary = {}
var plaza: Rect2i
var landmark_cell: Vector2i
var gathering: Rect2i
var roads: Dictionary = {}


static func read(path: String = DEFAULT_PATH) -> WorldLayout:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		var result := WorldLayout.new()
		result.errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return result
	return parse(json.data)


static func parse(data: Variant) -> WorldLayout:
	var layout := WorldLayout.new()
	layout._parse(data)
	return layout


func _parse(data: Variant) -> void:
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("pitch_m") != PITCH:
		errors.append("Expected schema_version 1 and measured pitch_m 8")
		return
	if not _valid_id(data.get("id")) or not _has_name(data):
		errors.append("Invalid layout id or name")
		return
	if not _integers(data.get("origin_m"), 2) or not _integers(data.get("size_cells"), 2):
		errors.append("Expected integer origin_m and size_cells pairs")
		return
	id = data.id
	origin_m = Vector2(_cell(data.origin_m))
	grid = Rect2i(Vector2i.ZERO, _cell(data.size_cells))
	if not grid.has_area() or grid.size.x > 1024 or grid.size.y > 1024:
		errors.append("Invalid grid dimensions (expected 1-1024 cells per axis)")
		return
	for key in ["districts", "plots", "road_segments", "road_crossings"]:
		if not data.get(key) is Array:
			errors.append("Expected array: " + key)
	if not errors.is_empty():
		return
	for entry: Variant in data.districts:
		var rect := _entry_rect(entry)
		if not rect.has_area() or not _has_name(entry) or not entry.get("color") is String \
				or not Color.html_is_valid(entry.color):
			errors.append("Invalid district: %s" % str(entry))
			continue
		if districts.has(entry.id) or _intersects(districts, rect):
			errors.append("Duplicate id or overlapping district: " + entry.id)
			continue
		districts[entry.id] = {"name": entry.name, "rect": rect, "color": Color.html(entry.color)}
	if districts.is_empty():
		errors.append("No districts")
	var plaza_entry: Variant = data.get("plaza")
	plaza = _owned_rect(plaza_entry)
	if not plaza.has_area() or not plaza.has_point(grid.get_center()):
		errors.append("Plaza must be inside its district and cover the central cell")
	else:
		if not _integers(plaza_entry.get("landmark_cell"), 2):
			errors.append("Invalid plaza landmark cell")
		else:
			landmark_cell = _cell(plaza_entry.landmark_cell)
			if not plaza.has_point(landmark_cell) or landmark_cell != plaza.get_center():
				errors.append("Landmark must occupy the plaza center cell")
		gathering = _grid_rect(plaza_entry.get("gathering_rect"))
		if not gathering.has_area() or not plaza.encloses(gathering) or gathering.has_point(landmark_cell):
			errors.append("Gathering space must be inside the plaza and clear of the landmark")
	for entry: Variant in data.plots:
		var rect := _owned_rect(entry)
		if not rect.has_area() or not _valid_id(entry.get("id")):
			errors.append("Invalid or out-of-district plot: %s" % str(entry))
			continue
		if plots.has(entry.id) or _intersects(plots, rect) or rect.intersects(plaza):
			errors.append("Duplicate id or overlapping plot: " + entry.id)
			continue
		plots[entry.id] = {"district": entry.district, "rect": rect}
	_compile_roads(data.road_segments, data.road_crossings)
	var plaza_frontage := _has_frontage(plaza)
	for district_id: String in districts:
		if not _has_frontage(districts[district_id].rect):
			errors.append("District has no road frontage: " + district_id)
	for plot_id: String in plots:
		if plots[plot_id].district == "market_street" and not _has_frontage(plots[plot_id].rect):
			errors.append("Market plot has no road frontage: " + plot_id)
	for cell: Vector2i in roads:
		if plaza.has_point(cell):
			errors.append("Road overlaps plaza: %s" % str(cell))
		for plot_id: String in plots:
			if (plots[plot_id].rect as Rect2i).has_point(cell):
				errors.append("Road overlaps plot %s at %s" % [plot_id, cell])
	if not plaza_frontage:
		errors.append("Plaza must touch a road tile")


func _compile_roads(segments: Array, crossings: Array) -> void:
	var masks := {}
	for segment: Variant in segments:
		if not segment is Array or segment.size() != 2 or not _integers(segment[0], 2) \
				or not _integers(segment[1], 2):
			errors.append("Expected two grid endpoints per road segment")
			continue
		var cell := _cell(segment[0])
		var end := _cell(segment[1])
		var delta := end - cell
		if not grid.has_point(cell) or not grid.has_point(end) or (delta.x == 0) == (delta.y == 0):
			errors.append("Road segment must be nonzero, axis-aligned and in bounds: %s" % [segment])
			continue
		var step := delta.sign()
		var direction := DIRECTIONS.find(step)
		var forward := 1 << direction
		var back := 1 << ((direction + 2) % 4)
		while cell != end:
			var next := cell + step
			if int(masks.get(cell, 0)) & forward:
				errors.append("Duplicate road edge: %s to %s" % [cell, next])
			masks[cell] = int(masks.get(cell, 0)) | forward
			masks[next] = int(masks.get(next, 0)) | back
			cell = next
	var crossed := {}
	for value: Variant in crossings:
		if not _integers(value, 2):
			errors.append("Invalid crossing coordinate")
			continue
		var cell := _cell(value)
		if crossed.has(cell) or not int(masks.get(cell, 0)) in [0b0101, 0b1010]:
			errors.append("Crossing must be unique and on a straight road: %s" % str(cell))
		crossed[cell] = true
	for cell: Vector2i in masks:
		var tile := _tile(masks[cell], crossed.has(cell))
		if tile.is_empty():
			errors.append("No supported road tile for cell %s (open end or bad crossing)" % str(cell))
			continue
		roads[cell] = tile
	errors.append_array(road_errors(roads))


static func _tile(mask: int, crossing: bool) -> Dictionary:
	var candidates := ["road_crossing"] if crossing else ROAD_SHAPES
	for asset_id: String in candidates:
		for turns in 4:
			if rotated_mask(ROAD_MASKS[asset_id], turns) == mask:
				return {"asset_id": asset_id, "turns": turns, "ports": mask}
	return {}


static func rotated_mask(mask: int, turns: int) -> int:
	# Positive Godot Y rotation takes east to north, so the port bits move right.
	return ((mask >> turns) | (mask << (4 - turns))) & 15


static func road_errors(tiles: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if tiles.is_empty():
		return PackedStringArray(["No roads"])
	var checked_assets := {}
	for cell: Vector2i in tiles:
		var tile: Dictionary = tiles[cell]
		var asset_id: String = tile.asset_id
		if not checked_assets.has(asset_id):
			var asset := KenneyAssets.find(asset_id)
			if not ROAD_MASKS.has(asset_id) or asset.get("category") != "roads" \
					or asset.get("scale") != PITCH \
					or not ResourceLoader.exists(KenneyAssets.path_of(asset), "PackedScene"):
				problems.append("Invalid road asset reference: " + asset_id)
			checked_assets[asset_id] = true
		if tile.turns < 0 or tile.turns > 3 or not ROAD_MASKS.has(asset_id) \
				or rotated_mask(ROAD_MASKS[asset_id], tile.turns) != tile.ports:
			problems.append("Invalid rotation or ports: %s" % str(cell))
		for i in 4:
			var other: Dictionary = tiles.get(cell + DIRECTIONS[i], {})
			if (tile.ports & (1 << i) != 0) != (int(other.get("ports", 0)) & (1 << ((i + 2) % 4)) != 0):
				problems.append("Mismatched road seam: %s facing %s" % [cell, DIRECTIONS[i]])
	if not problems.is_empty():
		return problems
	var first: Vector2i = tiles.keys()[0]
	var seen := {first: true}
	var pending: Array[Vector2i] = [first]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for i in 4:
			var next: Vector2i = cell + DIRECTIONS[i]
			if tiles[cell].ports & (1 << i) and not seen.has(next):
				seen[next] = true
				pending.append(next)
	if seen.size() != tiles.size():
		problems.append("Disconnected road network: reached %d of %d tiles" % [seen.size(), tiles.size()])
	return problems


func _has_frontage(rect: Rect2i) -> bool:
	for cell: Vector2i in roads:
		for direction: Vector2i in DIRECTIONS:
			if rect.has_point(cell + direction):
				return true
	return false


func district_at(xz: Vector2) -> String:
	for district: Dictionary in districts.values():
		if meters(district.rect).has_point(xz):
			return district.name
	return "Outside districts"


func cell_center(cell: Vector2i) -> Vector2:
	return origin_m + (Vector2(cell) + Vector2(0.5, 0.5)) * PITCH


func meters(rect: Rect2i) -> Rect2:
	return Rect2(origin_m + Vector2(rect.position) * PITCH, Vector2(rect.size) * PITCH)


func _entry_rect(entry: Variant) -> Rect2i:
	if not entry is Dictionary or not _valid_id(entry.get("id")):
		return Rect2i()
	return _grid_rect(entry.get("rect"))


func _owned_rect(entry: Variant) -> Rect2i:
	if not entry is Dictionary or not entry.get("district") is String or not districts.has(entry.district):
		return Rect2i()
	var rect := _grid_rect(entry.get("rect"))
	return rect if (districts[entry.district].rect as Rect2i).encloses(rect) else Rect2i()


func _grid_rect(value: Variant) -> Rect2i:
	if not _integers(value, 4):
		return Rect2i()
	var rect := Rect2i(value[0], value[1], value[2], value[3])
	return rect if rect.has_area() and grid.encloses(rect) else Rect2i()


static func _intersects(entries: Dictionary, rect: Rect2i) -> bool:
	for entry: Dictionary in entries.values():
		if rect.intersects(entry.rect):
			return true
	return false


static func _cell(values: Array) -> Vector2i:
	return Vector2i(values[0], values[1])


static func _integers(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item: Variant in value:
		if not (item is float or item is int) or absf(item) > 1000000.0 or floorf(item) != item:
			return false
	return true


static func _valid_id(value: Variant) -> bool:
	return value is String and value.is_valid_ascii_identifier() and value == value.to_lower()


static func _has_name(entry: Dictionary) -> bool:
	return entry.get("name") is String and not entry.name.strip_edges().is_empty()
