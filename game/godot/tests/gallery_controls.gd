extends SceneTree

var failures := 0

func _initialize() -> void:
	await process_frame
	var scene: Node = load("res://scenes/development/AssetGallery.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_key(KEY_C)
	await process_frame
	_check(scene.distance == 36.0, "comparison camera")
	_check(not scene.catalog_sections[0].visible, "comparison hides catalog clutter")
	for key in [KEY_1, KEY_2, KEY_3]:
		_key(key)
		await process_frame
		_check(scene.preset_index == key - KEY_1, "lighting shortcut")
	_check(scene.world_environment.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "night shadow fill")
	var was_visible: bool = scene.grid_root.visible
	_key(KEY_G)
	await process_frame
	_check(scene.grid_root.visible != was_visible, "grid toggle")
	var item: Dictionary = {}
	for candidate: Dictionary in scene.items:
		if candidate.asset.id == "veh_sedan" and candidate.node.is_visible_in_tree():
			item = candidate
			break
	if item.is_empty():
		_check(false, "visible comparison sedan exists")
		quit(1)
		return
	var bounds: AABB = scene._world_bounds(item.wrapper)
	var point: Vector2 = scene.camera.unproject_position(bounds.get_center())
	_mouse(point, true)
	await process_frame
	_mouse(point, false)
	await process_frame
	_check(scene.selection_label.text.contains("veh_sedan"), "comparison vehicle selection")
	var yaw: float = scene.yaw
	_drag(point, false)
	_check(scene.yaw != yaw, "drag orbits")
	var focus: Vector3 = scene.focus
	_drag(point, true)
	_check(not scene.focus.is_equal_approx(focus), "shift-drag pans")
	_mouse(point, true, MOUSE_BUTTON_WHEEL_UP)
	_check(scene.distance < 36.0, "wheel zooms")
	_key(KEY_R)
	await process_frame
	_check(scene.distance == 300.0 and scene.catalog_sections[0].visible, "reset restores catalog")
	print("Gallery input checks: %d failures" % failures)
	quit(1 if failures else 0)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)

func _mouse(point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.shift_pressed = shift
	event.pressed = pressed
	root.push_input(event, true)

func _drag(point: Vector2, shift: bool) -> void:
	_mouse(point, true, MOUSE_BUTTON_LEFT, shift)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 12)
	motion.position = point + motion.relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.shift_pressed = shift
	root.push_input(motion, true)
	_mouse(motion.position, false, MOUSE_BUTTON_LEFT, shift)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
