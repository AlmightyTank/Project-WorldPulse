extends Node3D

const TERRAIN := preload("res://scenes/world/Terrain.tscn")

@export_file("*.json") var layout_path := WorldLayout.DEFAULT_PATH
@export_file("*.json") var catalog_path := WorldBuildings.DEFAULT_PATH

var layout: WorldLayout
var buildings: WorldBuildings
var built := false
var _readout: Label
var _refresh_left := 0.0

@onready var camera: WorldCamera = $Camera
@onready var districts: Node3D = $DistrictBounds
@onready var connections: Node3D = $RoadConnections
@onready var buildings_debug: Node3D = $Buildings/BuildingsDebug


func _ready() -> void:
	set_process(false)
	if OS.is_debug_build():
		_build_overlay()
	layout = WorldLayout.read(layout_path)
	if not layout.errors.is_empty():
		push_error("World layout rejected:\n" + "\n".join(layout.errors))
		return
	var bounds := layout.meters(layout.grid)
	var terrain := TERRAIN.instantiate()
	terrain.dimensions_m = bounds.size
	terrain.position = WorldBuilder.at(bounds.get_center(), 0.0)
	$Land.add_child(terrain)
	WorldBuilder.build_reservations($Land, layout)
	if not WorldBuilder.build_roads($Roads, layout):
		return
	buildings = WorldBuildings.read(layout, catalog_path)
	if not buildings.errors.is_empty():
		push_error("Building catalog rejected:\n" + "\n".join(buildings.errors))
		if OS.is_debug_build():
			buildings.build_debug(buildings_debug)
		return
	if not buildings.build($Buildings/Residential, $Buildings/Commercial, $Buildings/Civic):
		return
	buildings.build_sites($Land)
	if not buildings.build_beacon($Landmarks/WorldPulseBeacon):
		return
	camera.configure(layout.meters(layout.grid), layout.meters(layout.plaza).get_center())
	if OS.is_debug_build():
		_build_guides()
		buildings.build_debug(buildings_debug)
	built = true


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("world_debug_overlay", false, true):
		$Overlay.visible = not $Overlay.visible
		set_process($Overlay.visible)
		_refresh_left = 0.0
	elif not built:
		return
	elif event.is_action_pressed("world_debug_grid", false, true):
		$Grid.visible = not $Grid.visible
	elif event.is_action_pressed("world_debug_plots", false, true):
		$Land/ReservedPlots.visible = not $Land/ReservedPlots.visible
	elif event.is_action_pressed("world_debug_districts", false, true):
		districts.visible = not districts.visible
	elif event.is_action_pressed("world_debug_roads", false, true):
		connections.visible = not connections.visible
	elif event.is_action_pressed("world_debug_buildings", false, true):
		buildings_debug.visible = not buildings_debug.visible
	else:
		return
	get_viewport().set_input_as_handled()


func _build_overlay() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192322")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 14)
	panel.add_theme_stylebox_override("panel", style)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 20)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.text = "Reading world layout…"
	panel.add_child(_readout)
	$Overlay.add_child(panel)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 0.25
	if not built:
		_readout.text = "World unavailable\nCheck the Godot log for layout or asset errors."
		return
	var viewport := get_viewport()
	var draws := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var p := camera.global_position
	var counts := "Buildings: %d residential, %d commercial, %d civic" % [
		buildings.district_count("residential_quarter"),
		buildings.district_count("market_street") + buildings.district_count("town_square"),
		buildings.district_count("civic_quarter"),
	]
	_readout.text = "%s\nFocus district: %s\nCamera: %.1f, %.1f, %.1f m\nView span: %.1f m\nRoads: %d tiles, validation passed\n%s (%d valid, %d invalid)\nBeacon: WorldPulse landmark\n%d FPS  |  %d draws  |  %d triangles\n\nF5 Grid   F6 Districts   F7 Links\nF8 Plots   F9 Hide   F10 Buildings" % [
		layout.id, layout.district_at(camera.focus), p.x, p.y, p.z, camera.size,
		layout.roads.size(), counts, buildings.built_count(), buildings.invalid_count(),
		Engine.get_frames_per_second(), draws, triangles,
	]


func _build_guides() -> void:
	var grid_lines := SurfaceTool.new()
	grid_lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds := layout.meters(layout.grid)
	var grid_color := Color("778861")
	for i in layout.grid.size.x + 1:
		var x := bounds.position.x + i * WorldLayout.PITCH
		_line(grid_lines, Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), 0.16, 0.005, grid_color)
	for i in layout.grid.size.y + 1:
		var z := bounds.position.y + i * WorldLayout.PITCH
		_line(grid_lines, Vector2(bounds.position.x, z), Vector2(bounds.end.x, z), 0.16, 0.006, grid_color)
	_finish_guide($Grid, grid_lines)
	var outlines := SurfaceTool.new()
	outlines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for id: String in layout.districts:
		var district: Dictionary = layout.districts[id]
		var rect := layout.meters(district.rect)
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			_line(outlines, corners[i], corners[(i + 1) % 4], 0.52, 0.28, district.color.darkened(0.55))
		var label := Label3D.new()
		label.text = "%s\n%d buildings" % [district.name, buildings.district_count(id)]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 52
		label.pixel_size = 0.13
		label.outline_size = 15
		label.outline_modulate = Color("192322")
		label.position = WorldBuilder.at(rect.get_center(), 6.0)
		districts.add_child(label)
	_finish_guide(districts, outlines)
	var links := SurfaceTool.new()
	links.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in layout.roads:
		for i in [1, 2]:
			if layout.roads[cell].ports & (1 << i):
				_line(links, layout.cell_center(cell), layout.cell_center(cell + WorldLayout.DIRECTIONS[i]), 0.45, 0.29, Color("ffe196"))
	_finish_guide(connections, links)


func _line(surface: SurfaceTool, a: Vector2, b: Vector2, width: float, y: float, color: Color) -> void:
	var normal := (b - a).normalized().orthogonal() * width * 0.5
	for point: Vector2 in [a - normal, a + normal, b + normal, a - normal, b + normal, b - normal]:
		surface.set_color(color)
		surface.add_vertex(WorldBuilder.at(point, y))


func _finish_guide(parent: Node3D, surface: SurfaceTool) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	surface.set_material(material)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
