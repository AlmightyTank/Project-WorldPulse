extends SceneTree

# Run with --headless for checks; omit it and append -- --render for GPU sheets and motion frames.
const Controller = preload("res://scripts/character_visual_state.gd")
const SOURCE := "res://assets/third_party/kenney/animated-characters-protagonists/models/char_protagonist_%s.glb"
const CHARACTERS := ["criminal_male_a", "cyborg_female_a", "skater_female_a", "skater_male_a"]
const VIEWS := [Vector3(5, 1.42, 0), Vector3(0, 1.55, 5), Vector3(3.5, 2.5, 4.5)]
const TILE := Vector2i(200, 240)
const TEST_HZ := 120
const MOTION_HZ := 30
@warning_ignore("integer_division")
const CAPTURE_EVERY := TEST_HZ / MOTION_HZ
const REVIEW_DIR := "user://walk-review"
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var viewport := SubViewport.new()
	viewport.size = TILE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var camera := _stage(stage)
	for character: String in CHARACTERS:
		var model := KenneyAssets.instance("char_protagonist_" + character)
		var fresh := (load(SOURCE % character) as PackedScene).instantiate()
		stage.add_child(model)
		var player := model.get_node("AnimationPlayer") as AnimationPlayer
		var rig := model.get_node("Root/Skeleton3D") as Skeleton3D
		var baseline := fresh.get_node("AnimationPlayer") as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var ctrl := Controller.new()
		if not ctrl.bind(player):
			_check(false, "bind " + character)
			model.free()
			fresh.free()
			continue
		_check(not baseline.has_animation(&"Walk"), "source library isolation")
		_check_transitions(player, ctrl)
		var walk := player.get_animation(&"Walk")
		_check(walk.resource_path == Controller.WALK_PATH and walk.length >= 1.0 and walk.length <= 1.15 and walk.loop_mode == Animation.LOOP_LINEAR, "native Walk at 104–120 steps/min")
		for track in walk.get_track_count():
			var first: Variant = walk.track_get_key_value(track, 0)
			var last: Variant = walk.track_get_key_value(track, walk.track_get_key_count(track) - 1)
			_check(first.is_equal_approx(last), "exact loop seam")
		await _check_motion(player, rig, model, camera, character, render)
		model.position = Vector3.ZERO
		if render:
			var sheet := Image.create(TILE.x * 9, TILE.y * VIEWS.size(), false, Image.FORMAT_RGBA8)
			for view in VIEWS.size():
				camera.position = VIEWS[view]
				camera.look_at(Vector3(0, 0.93, 0), Vector3.UP)
				for sample in range(9):
					player.seek(minf(float(sample) / 8.0, 0.983333) * walk.length, true)
					await process_frame
					await RenderingServer.frame_post_draw
					var image := viewport.get_texture().get_image()
					image.convert(Image.FORMAT_RGBA8)
					sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i(sample, view) * TILE)
			var folder := "user://walk-review"
			DirAccess.make_dir_recursive_absolute(folder)
			var path := "%s/%s.png" % [folder, character]
			_check(sheet.save_png(path) == OK, "save rendered sheet")
			print(ProjectSettings.globalize_path(path))
			await _render_transitions(player, ctrl, model, camera, character)
		model.free()
		fresh.free()
	print("Walk checks: %d passed; %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _check_transitions(player: AnimationPlayer, ctrl: Controller) -> void:
	_check(ctrl.get_state() == &"Idle", "initial Idle")
	_check(not ctrl.play(&"Missing"), "reject unknown state")
	for state: StringName in [&"Walk", &"Run", &"Walk", &"Idle", &"Walk"]:
		var previous := ctrl.get_state()
		_check(ctrl.play(state) and ctrl.get_state() == state, "%s -> %s request" % [previous, state])
		for tick in 24:
			player.advance(1.0 / TEST_HZ)
		_check(player.current_animation == state and player.current_animation_position > 0.1, "%s -> %s playback" % [previous, state])
	for state: StringName in [&"Walk", &"Jump"]:
		ctrl.play(state)
		player.advance(0.20)
		var play_time := player.current_animation_position
		ctrl.play(state)
		player.advance(0.01)
		_check(is_equal_approx(play_time + 0.01, player.current_animation_position), "%s does not restart" % state)
	ctrl.play(&"Run")
	_check(ctrl.get_state() == &"Jump" and player.current_animation == &"Jump", "locomotion waits for landing")
	player.advance(player.get_animation(&"Jump").length)
	player.advance(0.15)
	_check(ctrl.get_state() == &"Run" and player.current_animation == &"Run", "Jump -> queued Run")
	ctrl.play(&"Walk")
	player.advance(0.15)
	ctrl.play(&"Jump")
	player.advance(player.get_animation(&"Jump").length + 0.01)
	player.advance(0.15)
	_check(ctrl.get_state() == &"Walk" and player.current_animation == &"Walk", "Jump -> previous Walk")


func _check_motion(player: AnimationPlayer, rig: Skeleton3D, model: Node3D, camera: Camera3D, character: String, render: bool) -> void:
	var walk := player.get_animation(&"Walk")
	var stance := float(walk.get_meta(&"stance_fraction"))
	var travel := rig.global_basis * Vector3.BACK * float(walk.get_meta(&"reference_speed_rig_units"))
	var speed := travel.length()
	_check(speed >= 1.2 and speed <= 1.5 and travel.dot(Vector3.BACK) > 1.2, "normalized reference speed and +Z heading")
	_check(stance >= 0.58 and stance <= 0.65, "walking stance duration")
	var feet := [rig.find_bone(&"LeftFoot"), rig.find_bone(&"RightFoot")]
	var heel_local: Array[Vector3] = []
	var toe_local: Array[Vector3] = []
	for foot: int in feet:
		var rest := rig.get_bone_global_rest(foot)
		heel_local.append(rest.affine_inverse() * Vector3(rest.origin.x, 0, -0.30))
		toe_local.append(rest.affine_inverse() * Vector3(rest.origin.x, 0, 0.29))
	var previous_contact := [-1, -1]
	var anchors := [Vector3.ZERO, Vector3.ZERO]
	var contact_samples := [0, 0, 0]
	var max_drift := [0.0, 0.0, 0.0]
	var max_contact_height := 0.0
	var min_sole := INF
	var frame_dir := REVIEW_DIR.path_join(character + "-motion")
	if render:
		_check(DirAccess.make_dir_recursive_absolute(frame_dir) == OK, "create motion directory")
		camera.get_viewport().size = Vector2i(640, 280)
		camera.position = Vector3(7.0, 1.38, 0.0)
		camera.look_at(Vector3(0, 1.00, 0), Vector3.UP)
		camera.size = 2.35
	player.stop()
	player.play(&"Walk", 0.0)
	player.advance(0.0)
	var ticks := roundi(3.0 * walk.length * TEST_HZ)
	var start_z := -speed * float(ticks) / (2.0 * TEST_HZ)
	for tick in range(ticks + 1):
		if tick > 0:
			player.advance(1.0 / TEST_HZ)
		model.position = Vector3(0, 0, start_z) + travel * (float(tick) / TEST_HZ)
		for side in 2:
			var foot_pose := rig.global_transform * rig.get_bone_global_pose(feet[side])
			var heel := foot_pose * heel_local[side]
			var toe := foot_pose * toe_local[side]
			var lowest := minf(heel.y, toe.y)
			min_sole = minf(min_sole, lowest)
			var phase := fposmod(player.current_animation_position / walk.length + 0.5 * side, 1.0)
			var contact := -1
			if phase < stance:
				var fraction := phase / stance
				contact = 0 if fraction < 0.22 else (1 if fraction <= 0.68 else 2)
				var sole := heel if contact == 0 else (heel.lerp(toe, 0.5) if contact == 1 else toe)
				if contact != previous_contact[side]:
					anchors[side] = sole
				var anchor: Vector3 = anchors[side]
				var drift := Vector2(sole.x - anchor.x, sole.z - anchor.z).length()
				max_drift[contact] = maxf(max_drift[contact], drift)
				max_contact_height = maxf(max_contact_height, sole.y)
				contact_samples[contact] += 1
			previous_contact[side] = contact
		if render and tick % CAPTURE_EVERY == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			var image := camera.get_viewport().get_texture().get_image()
			_check(image.save_png(frame_dir.path_join("%03d.png" % (tick * MOTION_HZ / float(TEST_HZ)))) == OK, "save motion frame")
	_check(contact_samples.min() > 80, "sampled all stance intervals over three cycles")
	_check(max_drift.max() < 0.0025, "heel, flat and toe no-slip under world-space travel")
	_check(min_sole > -0.0025 and max_contact_height < 0.0025, "sole clearance and stance height")
	print("%s: %.6f m/s, %.3f steps/min; drift heel/flat/toe %.3f/%.3f/%.3f mm, min sole %.3f mm, max contact height %.3f mm" % [character, speed, 120.0 / walk.length, max_drift[0] * 1000, max_drift[1] * 1000, max_drift[2] * 1000, min_sole * 1000, max_contact_height * 1000])
	if render:
		print(ProjectSettings.globalize_path(frame_dir))
		camera.get_viewport().size = TILE
		camera.size = 2.15


func _render_transitions(player: AnimationPlayer, ctrl: Controller, model: Node3D, camera: Camera3D, character: String) -> void:
	var folder := REVIEW_DIR.path_join(character + "-transitions")
	_check(DirAccess.make_dir_recursive_absolute(folder) == OK, "create transition directory")
	camera.get_viewport().size = Vector2i(400, 400)
	camera.position = VIEWS[2]
	camera.look_at(Vector3(0, 0.93, 0), Vector3.UP)
	model.position = Vector3.ZERO
	ctrl.bind(player)
	player.advance(0.2)
	var requests := {15: &"Walk", 45: &"Run", 75: &"Walk", 105: &"Idle", 135: &"Walk", 165: &"Jump", 170: &"Run", 195: &"Walk", 225: &"Jump"}
	for frame in 255:
		if requests.has(frame):
			ctrl.play(requests[frame])
		player.advance(1.0 / MOTION_HZ)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := camera.get_viewport().get_texture().get_image()
		_check(image.save_png(folder.path_join("%03d.png" % frame)) == OK, "save transition frame")
	_check(ctrl.get_state() == &"Walk" and player.current_animation == &"Walk", "rendered Jump returns to Walk")
	print(ProjectSettings.globalize_path(folder))
	camera.get_viewport().size = TILE


func _stage(stage: Node3D) -> Camera3D:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("b5cbc9")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("f4f5f1")
	world.environment.ambient_light_energy = 0.25
	stage.add_child(world)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(30, 30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7b8b71")
	ground.material_override = material
	stage.add_child(ground)
	# Fixed marks at 0.25 m spacing make the foot plants visible against the moving character.
	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.75, 0.001, 0.012)
	var mark_material := StandardMaterial3D.new()
	mark_material.albedo_color = Color("9baf8b")
	mark_mesh.material = mark_material
	for index in range(-12, 13):
		var mark := MeshInstance3D.new()
		mark.mesh = mark_mesh
		mark.position = Vector3(0, 0.001, index * 0.25)
		stage.add_child(mark)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -27, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 18.0
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.15
	camera.current = true
	return camera


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
