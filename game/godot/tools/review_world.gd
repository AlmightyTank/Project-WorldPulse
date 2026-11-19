extends SceneTree

const WORLD := "res://scenes/world/World.tscn"


func _initialize() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("World review requires a rendering display")
		quit(1)
		return
	var output := OS.get_environment("WORLD_REVIEW_OUTPUT")
	if output.is_empty():
		output = ProjectSettings.globalize_path("user://world-review")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create review directory: " + output)
		quit(1)
		return
	var start := Time.get_ticks_usec()
	var scene := load(WORLD) as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	if not world.built:
		quit(1)
		return
	var load_ms := (Time.get_ticks_usec() - start) / 1000.0
	await RenderingServer.frame_post_draw
	var first_draw_ms := (Time.get_ticks_usec() - start) / 1000.0
	var camera: WorldCamera = world.camera
	var home := camera.focus
	var failed := not await _test_keyboard(camera)
	var views := [
		["default", home, camera.home_span], ["minimum-plaza", home, camera.min_span],
		["maximum", home, camera.max_span], ["full-map", Vector2.ZERO, 310.0],
		["plaza-day", home, 68.0], ["residential-day", Vector2(-48, -8), 110.0],
		["commercial-day", Vector2(44, 12), 82.0], ["civic-day", Vector2(28, -40), 100.0],
		["greenbelt-day", Vector2(0, 66), 110.0], ["beacon-closeup", home, 46.0],
		["residential-closeup", Vector2(-48, -1), 34.0],
		["market-north-closeup", Vector2(51, -6), 34.0], ["market-south-closeup", Vector2(30, 28), 38.0],
		["building-footprints", home, 160.0], ["district-bounds", Vector2.ZERO, 190.0],
		["road-connections", home, 160.0], ["planning-overlay", home, 160.0],
	]
	var metrics := {"load_and_ready_ms": load_ms, "first_draw_ms": first_draw_ms,
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"road_tiles": world.layout.roads.size(), "views": {}}
	for view: Array in views:
		var id: String = view[0]
		camera.frame_view(view[1], view[2], true)
		world.districts.visible = id == "district-bounds"
		world.connections.visible = id == "road-connections"
		world.get_node("Buildings/BuildingsDebug").visible = false
		if id == "building-footprints":
			_send_key(KEY_F10, true)
			_send_key(KEY_F10, false)
		if id == "planning-overlay":
			for key in [KEY_F5, KEY_F8, KEY_F9]:
				_send_key(key, true)
				_send_key(key, false)
		await create_timer(1.2).timeout
		var fps: Array[int] = []
		for i in 3:
			fps.append(Engine.get_frames_per_second())
			await create_timer(1.02).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image.get_size() != Vector2i(1920, 1080):
			push_error("Expected 1920 x 1080 capture; got %s" % str(image.get_size()))
			failed = true
		if image.save_png(output.path_join(id + ".png")) != OK:
			push_error("Cannot save " + id)
			failed = true
		metrics.views[id] = {"fps_samples": fps,
			"draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"triangles": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
		print(id, " ", metrics.views[id])
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()
	else:
		push_error("Cannot write metrics.json")
		failed = true
	quit(int(failed))


func _test_keyboard(camera: WorldCamera) -> bool:
	var home := camera.focus
	for key in [KEY_D, KEY_E, KEY_EQUAL]:
		_send_key(key, true)
	await create_timer(0.3).timeout
	for key in [KEY_D, KEY_E, KEY_EQUAL]:
		_send_key(key, false)
	var moved := camera.focus.distance_to(home) > 1.0 and camera.size < camera.home_span \
		and not is_equal_approx(camera.yaw, deg_to_rad(camera.home_yaw))
	_send_key(KEY_R, true)
	await process_frame
	_send_key(KEY_R, false)
	await create_timer(0.9).timeout
	var reset := camera.focus.distance_to(home) < 0.05 and absf(camera.size - camera.home_span) < 0.05 \
		and absf(camera.yaw - deg_to_rad(camera.home_yaw)) < 0.001
	if not moved or not reset:
		push_error("World keyboard pan/orbit/zoom/reset failed: %s/%s" % [moved, reset])
	else:
		print("Windowed input pipeline: D pan, E orbit, = zoom and R reset passed")
	return moved and reset


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
