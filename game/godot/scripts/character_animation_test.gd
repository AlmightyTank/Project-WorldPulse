extends Node3D

## Source Idle/Run/Jump and project-authored Walk, with stage-space foot inspection.
## Capture options use CHARACTER_ prefixes: SCREENSHOT, SUBJECT, STATE, VIEW, SPEED, TIME, GRID, FEET, FRAME.

const CHARACTER_IDS := [
	"char_protagonist_criminal_male_a",
	"char_protagonist_cyborg_female_a",
	"char_protagonist_skater_female_a",
	"char_protagonist_skater_male_a",
]

const STATIC_IDS := ["char_mini_female_a", "char_mini_male_a", "char_mini_worker", "char_mini_robot"]
const VisualState = preload("res://scripts/character_visual_state.gd")
const STATES := [&"Idle", &"Walk", &"Run", &"Jump"]
const VIEWS := ["Lineup", "Front", "3/4", "Side", "Back"]
const VIEW_YAWS := [0.0, 0.0, 45.0, 90.0, 180.0]
const LINEUP_CAMERA := Vector3(0, 3.9, 10.0)
const SPEEDS := [1.0, 0.5, 0.25, 0.0]
const SPEED_LABELS := ["1×", "½×", "¼×", "Pause"]
const FOOT_BONES := [&"LeftFoot", &"RightFoot"]
const FOOT_COLORS := [Color(1.0, 0.80, 0.37), Color(0.45, 0.91, 1.0)]

class Subject:
	var id: String
	var model: Node3D
	var label: Label3D
	var player: AnimationPlayer
	var skeleton: Skeleton3D
	var controller: RefCounted

var subjects: Array[Subject] = []
var selection := 0
var view_index := 0
var speed_index := 0
var camera: Camera3D
var grid: MeshInstance3D
var foot_mesh: ImmediateMesh
var foot_labels: Array[Label3D] = []
var subject_picker: OptionButton
var view_picker: OptionButton
var speed_picker: OptionButton
var grid_toggle: CheckButton
var feet_toggle: CheckButton
var state_buttons: Array[Button] = []
var info_label: Label
var foot_label: Label
var frames := 0
var capture_frame := 40
var screenshot_path := OS.get_environment("CHARACTER_SCREENSHOT")


func _ready() -> void:
	_build_stage()
	_build_characters()
	_build_ui()
	_select_subject(0)
	if not screenshot_path.is_empty():
		_configure_capture()
	if OS.get_environment("CHARACTER_SELF_TEST") == "1":
		_run_self_test.call_deferred()


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.355
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 12)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.46, 0.28)
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.current = true
	add_child(camera)
	_build_debug_meshes()


func _build_debug_meshes() -> void:
	grid = MeshInstance3D.new()
	var grid_mesh := ImmediateMesh.new()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color(0.24, 0.34, 0.21)
	grid.mesh = grid_mesh
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Offset the 1 m reference grid to avoid z-fighting with the existing plane.
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, grid_material)
	for x in range(-15, 16):
		grid_mesh.surface_add_vertex(Vector3(x, 0.006, -6))
		grid_mesh.surface_add_vertex(Vector3(x, 0.006, 6))
	for z in range(-6, 7):
		grid_mesh.surface_add_vertex(Vector3(-15, 0.006, z))
		grid_mesh.surface_add_vertex(Vector3(15, 0.006, z))
	grid_mesh.surface_end()
	grid.hide()
	add_child(grid)

	var lines := MeshInstance3D.new()
	foot_mesh = ImmediateMesh.new()
	lines.mesh = foot_mesh
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.vertex_color_use_as_albedo = true
	ink.no_depth_test = true
	lines.material_override = ink
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)
	for index in FOOT_BONES.size():
		var tag := Label3D.new()
		tag.text = "L" if index == 0 else "R"
		tag.modulate = FOOT_COLORS[index]
		tag.font_size = 32
		tag.pixel_size = 0.003
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.hide()
		add_child(tag)
		foot_labels.append(tag)


func _build_characters() -> void:
	for asset_id: String in CHARACTER_IDS + STATIC_IDS:
		var subject := Subject.new()
		subject.id = asset_id
		subjects.append(subject)
		subject.model = KenneyAssets.instance(asset_id)
		if subject.model == null:
			push_error("Cannot instance " + asset_id)
			continue
		subject.model.rotation_degrees.y = 0.0
		add_child(subject.model)
		subject.skeleton = _find_first(subject.model, "Skeleton3D") as Skeleton3D
		subject.player = _find_first(subject.model, "AnimationPlayer") as AnimationPlayer
		if asset_id in CHARACTER_IDS and subject.player != null:
			subject.controller = VisualState.new()
			if not subject.controller.bind(subject.player):
				push_error("Cannot bind visual state: " + asset_id)
				subject.controller = null
		subject.label = Label3D.new()
		subject.label.font_size = 40
		subject.label.pixel_size = 0.005
		subject.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(subject.label)


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
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 350
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := _add_label(column, "Character animation test")
	title.add_theme_font_size_override("font_size", 24)
	var subject_names := PackedStringArray()
	for subject in subjects:
		subject_names.append(_subject_name(subject.id) + (" (static)" if subject.id in STATIC_IDS else ""))
	subject_picker = _add_picker(column, "Character", subject_names, _select_subject)
	_add_label(column, "Animation state")
	var state_row := HBoxContainer.new()
	column.add_child(state_row)
	var state_group := ButtonGroup.new()
	for index in STATES.size():
		var button := Button.new()
		button.text = "%s [%d]" % [STATES[index], index + 1]
		button.toggle_mode = true
		button.button_group = state_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_play.bind(STATES[index]))
		_add_button(state_row, button)
		state_buttons.append(button)

	view_picker = _add_picker(column, "View [V]", PackedStringArray(VIEWS), _set_view)
	speed_picker = _add_picker(column, "Playback speed [S]", PackedStringArray(SPEED_LABELS), _set_speed)
	grid_toggle = CheckButton.new()
	grid_toggle.text = "1 m grid [G]"
	grid_toggle.toggled.connect(_set_grid)
	_add_button(column, grid_toggle)
	feet_toggle = CheckButton.new()
	feet_toggle.text = "Foot bones [F]"
	_add_button(column, feet_toggle)
	info_label = _add_label(column, "")
	foot_label = _add_label(column, "")
	foot_label.hide()


func _add_label(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.91))
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label


func _add_button(parent: Container, button: BaseButton) -> void:
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)


func _add_picker(parent: Container, title: String, entries: PackedStringArray, action: Callable) -> OptionButton:
	_add_label(parent, title)
	var picker := OptionButton.new()
	picker.accessibility_name = title
	for entry in entries:
		picker.add_item(entry)
	picker.item_selected.connect(action)
	_add_button(parent, picker)
	return picker


func _subject_name(asset_id: String) -> String:
	return asset_id.trim_prefix("char_").trim_prefix("protagonist_").replace("_", " ").capitalize()


func _select_subject(index: int) -> void:
	selection = index
	subject_picker.select(index)
	var subject := subjects[index]
	var static_subject := subject.id in STATIC_IDS
	for index_state in state_buttons.size():
		state_buttons[index_state].disabled = static_subject or subject.controller == null or not subject.player.has_animation(STATES[index_state])
	speed_picker.disabled = static_subject or subject.player == null
	feet_toggle.disabled = static_subject or subject.skeleton == null
	if subject.id in STATIC_IDS and view_index == 0:
		_set_view(1)
	else:
		_apply_view()
	_update_status()


func _set_view(index: int) -> void:
	view_index = index
	view_picker.select(index)
	if index == 0 and subjects[selection].id in STATIC_IDS:
		_select_subject(0)
	else:
		_apply_view()


func _apply_view() -> void:
	for index in subjects.size():
		var subject := subjects[index]
		if subject.model == null:
			continue
		var lineup := view_index == 0 and index < CHARACTER_IDS.size()
		subject.model.visible = lineup or (view_index != 0 and index == selection)
		subject.model.position.x = -3.9 + 2.6 * index if lineup else 0.0
		subject.label.visible = lineup
		subject.label.position = Vector3(subject.model.position.x, 2.05, 0)
		subject.label.text = _subject_name(subject.id)
		subject.label.modulate = Color(0.63, 1.0, 0.88) if index == selection else Color.WHITE
	var target := Vector3(0, 2.5 if view_index == 0 else 1.0, 0)
	camera.position = LINEUP_CAMERA if view_index == 0 else target + Vector3(0, 0.55, 4.15).rotated(Vector3.UP, deg_to_rad(VIEW_YAWS[view_index]))
	camera.look_at(target, Vector3.UP)


func _set_grid(enabled: bool) -> void:
	grid.visible = enabled
	grid_toggle.set_pressed_no_signal(enabled)


func _set_speed(index: int) -> void:
	speed_index = index
	speed_picker.select(index)
	for subject in subjects:
		if subject.player != null:
			subject.player.speed_scale = SPEEDS[index]


func _play(clip: StringName) -> void:
	if subjects[selection].id in STATIC_IDS or subjects[selection].player == null:
		return
	var controller := subjects[selection].controller
	if controller != null:
		controller.play(clip)


func _update_status() -> void:
	var subject := subjects[selection]
	var player := subject.player
	var clip := StringName(player.assigned_animation) if player != null else &""
	for index in state_buttons.size():
		state_buttons[index].set_pressed_no_signal(STATES[index] == clip)
	if subject.model == null:
		info_label.text = "Asset could not load. Check the import log."
	elif subject.id in STATIC_IDS:
		info_label.text = "Static Mini Character.\nThe source has no skeleton or clips."
	elif player == null or not player.has_animation(clip):
		info_label.text = "No playable clip. Check the imported rig."
	else:
		var animation := player.get_animation(clip)
		var loop := "loop" if animation.loop_mode != Animation.LOOP_NONE else "once"
		var bones := subject.skeleton.get_bone_count() if subject.skeleton != null else 0
		info_label.text = "%s  •  %.3f / %.3f s  •  %s\n%d bones  |  Walk is project-authored" % [clip, player.current_animation_position, animation.length, loop, bones]


func _update_feet() -> void:
	foot_mesh.clear_surfaces()
	for tag in foot_labels:
		tag.hide()
	var skeleton := subjects[selection].skeleton
	foot_label.visible = feet_toggle.button_pressed and not feet_toggle.disabled and skeleton != null
	if not foot_label.visible:
		return
	var heights := PackedStringArray()
	for index in FOOT_BONES.size():
		var bone := skeleton.find_bone(FOOT_BONES[index])
		if bone < 0:
			heights.append("%s: unavailable" % foot_labels[index].text)
			continue
		var point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
		var floor_point := Vector3(point.x, 0.012, point.z)
		var tag := foot_labels[index]
		tag.global_position = point + Vector3.UP * (0.07 + index * 0.04)
		tag.show()
		foot_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		foot_mesh.surface_set_color(FOOT_COLORS[index])
		foot_mesh.surface_add_vertex(to_local(point))
		foot_mesh.surface_add_vertex(to_local(floor_point))
		for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD]:
			foot_mesh.surface_add_vertex(to_local(floor_point - axis * 0.065))
			foot_mesh.surface_add_vertex(to_local(floor_point + axis * 0.065))
		foot_mesh.surface_end()
		heights.append("%s %.3f m" % [tag.text, point.y])
	foot_label.text = "Foot bone Y above floor: %s\nCrosshairs are projections, not sole contacts." % "  |  ".join(heights)


func _find_first(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null


func _configure_capture() -> void:
	var asset_id := OS.get_environment("CHARACTER_SUBJECT")
	var view := OS.get_environment("CHARACTER_VIEW").to_lower()
	var clip := OS.get_environment("CHARACTER_STATE").capitalize()
	var speed := OS.get_environment("CHARACTER_SPEED")
	var frame_arg := OS.get_environment("CHARACTER_FRAME")
	var index := (CHARACTER_IDS + STATIC_IDS).find(asset_id)
	if index >= 0:
		_select_subject(index)
	var angle := ["lineup", "front", "3/4", "side", "back"].find(view)
	if angle >= 0:
		_set_view(angle)
	_set_grid(OS.get_environment("CHARACTER_GRID") == "1")
	feet_toggle.set_pressed_no_signal(OS.get_environment("CHARACTER_FEET") == "1")
	if StringName(clip) in STATES:
		_play(StringName(clip))
	else:
		_play(&"Idle")
	if speed.is_valid_float():
		var rate_index := SPEEDS.find(speed.to_float())
		if rate_index >= 0:
			_set_speed(rate_index)
	if frame_arg.is_valid_int():
		capture_frame = clampi(frame_arg.to_int(), 2, 3600)
	if OS.get_environment("CHARACTER_TIME").is_valid_float():
		_set_speed(3)


func _process(_delta: float) -> void:
	_update_status()
	_update_feet()
	if not screenshot_path.is_empty():
		frames += 1
		if frames == capture_frame:
			_capture()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CHARACTER_SCREENSHOT needs a rendering display.")
		get_tree().quit(1)
		return
	var time_arg := OS.get_environment("CHARACTER_TIME")
	if time_arg.is_valid_float():
		_set_speed(3)
		for subject in subjects:
			if subject.player != null and not subject.player.assigned_animation.is_empty():
				var duration := subject.player.get_animation(subject.player.assigned_animation).length
				subject.player.seek(clampf(time_arg.to_float(), 0.0, duration), true)
		_update_status()
		_update_feet()
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(screenshot_path)
	if result != OK:
		push_error("Could not save character screenshot: %s (%s)" % [screenshot_path, error_string(result)])
	get_tree().quit(0 if result == OK else 1)


func _run_self_test() -> void:
	var failures := PackedStringArray()
	for index in subjects.size():
		subject_picker.item_selected.emit(index)
		var subject := subjects[index]
		if selection != index or subject_picker.selected != index:
			failures.append("Selector did not select: " + subject.id)
		if subject.model == null:
			failures.append("Missing model: " + subject.id)
			continue
		if subject.id in STATIC_IDS:
			if state_buttons.any(func(button: Button) -> bool: return not button.disabled) or not speed_picker.disabled or not feet_toggle.disabled:
				failures.append("Static controls must be disabled: " + subject.id)
			if not info_label.text.contains("Static"):
				failures.append("Missing static explanation: " + subject.id)
			var rate_before := speed_index
			var feet_before := feet_toggle.button_pressed
			for key: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_S, KEY_F]:
				_self_test_key(key)
			_update_feet()
			if speed_index != rate_before or feet_toggle.button_pressed != feet_before or foot_label.visible or foot_mesh.get_surface_count() != 0:
				failures.append("Static shortcuts changed animation controls: " + subject.id)
		else:
			for state in STATES.size():
				_self_test_key((KEY_1 + state) as Key)
				if subject.player == null or subject.player.assigned_animation != STATES[state]:
					failures.append("State did not start: %s/%s" % [subject.id, STATES[state]])
			_self_test_key(KEY_F)
			_update_feet()
			if not foot_label.visible or foot_mesh.get_surface_count() != 2:
				failures.append("Missing foot markers: " + subject.id)
			_self_test_key(KEY_F)
			_update_feet()
			if foot_label.visible or foot_mesh.get_surface_count() != 0:
				failures.append("Foot markers did not hide: " + subject.id)
			for step in range(1, SPEEDS.size() + 1):
				_self_test_key(KEY_S)
				var rate := step % SPEEDS.size()
				if speed_picker.selected != rate or subject.player == null or subject.player.speed_scale != SPEEDS[rate]:
					failures.append("Speed did not apply: %s/%s" % [subject.id, SPEED_LABELS[rate]])
	_select_subject(0)
	view_picker.item_selected.emit(0)
	for step in range(1, VIEWS.size() + 1):
		_self_test_key(KEY_V)
		var angle := step % VIEWS.size()
		if view_picker.selected != angle or not camera.transform.is_finite() or not subjects[0].model.visible:
			failures.append("Invalid view: " + VIEWS[angle])
	_self_test_key(KEY_G)
	if not grid.visible or not grid_toggle.button_pressed:
		failures.append("Grid did not show")
	_self_test_key(KEY_G)
	if grid.visible or grid_toggle.button_pressed:
		failures.append("Grid did not hide")
	for failure in failures:
		push_error(failure)
	print("CHARACTER_SELF_TEST: ", "PASS" if failures.is_empty() else "FAIL", " (selector signal, synthetic shortcuts, disabled minis)")
	get_tree().quit(0 if failures.is_empty() else 1)


func _self_test_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1: _play(&"Idle")
		KEY_2: _play(&"Walk")
		KEY_3: _play(&"Run")
		KEY_4: _play(&"Jump")
		KEY_V: _set_view((view_index + 1) % VIEWS.size())
		KEY_S:
			if not speed_picker.disabled:
				_set_speed((speed_index + 1) % SPEEDS.size())
		KEY_G: _set_grid(not grid.visible)
		KEY_F:
			if not feet_toggle.disabled:
				feet_toggle.button_pressed = not feet_toggle.button_pressed
