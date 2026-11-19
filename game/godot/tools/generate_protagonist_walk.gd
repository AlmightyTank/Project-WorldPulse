extends SceneTree

# From game/godot: godot --headless --script res://tools/generate_protagonist_walk.gd
const SOURCE := "res://assets/third_party/kenney/animated-characters-protagonists/models/char_protagonist_criminal_male_a.glb"
const OUTPUT := "res://assets/animations/protagonist_walk.tres"
const DURATION := 1.04
const SAMPLES := 104
const STANCE := 0.60
const STANCE_TRAVEL := 1.64 # Rig units; approximately 1.26 m/s at 1.8 m character height.
const TRACK_ROOT := "Root/Skeleton3D:"
const FORWARD := Vector3.BACK # The imported feet point toward +Z.

var _rig: Skeleton3D
var _max_reach_error := 0.0


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var model := (load(SOURCE) as PackedScene).instantiate()
	root.add_child(model)
	_rig = model.get_node("Root/Skeleton3D") as Skeleton3D
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	player.stop()
	var walk := Animation.new()
	walk.resource_name = "Walk"
	walk.length = DURATION
	walk.step = DURATION / SAMPLES
	walk.loop_mode = Animation.LOOP_LINEAR
	walk.set_meta(&"provenance", "Original WorldPulse gait; baked from the CC0 Kenney Protagonists rig rest geometry, not sampled from Idle or Run.")
	walk.set_meta(&"stance_fraction", STANCE)
	walk.set_meta(&"reference_speed_rig_units", STANCE_TRAVEL / (STANCE * DURATION))
	var tracks := {}
	# Match the source clip channels, including the non-deforming FBX controls used by blends.
	var idle := player.get_animation(&"Idle")
	for index in idle.get_track_count():
		var path := idle.track_get_path(index)
		var type := idle.track_get_type(index)
		var track := walk.add_track(type)
		walk.track_set_path(track, path)
		tracks[track] = _bone(path.get_subname(0))
	for sample in range(SAMPLES + 1):
		var phase := float(sample % SAMPLES) / SAMPLES
		_rig.reset_bone_poses()
		_pose(phase)
		var time := float(sample) * DURATION / SAMPLES
		for track: int in tracks:
			var index: int = tracks[track]
			if walk.track_get_type(track) == Animation.TYPE_POSITION_3D:
				walk.position_track_insert_key(track, time, _rig.get_bone_pose_position(index))
			else:
				walk.rotation_track_insert_key(track, time, _rig.get_bone_pose_rotation(index).normalized())
	if _max_reach_error > 0.0001:
		push_error("Walk bake refused: ankle targets exceed rig reach by %.5f units" % _max_reach_error)
		model.free()
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var error := ResourceSaver.save(walk, OUTPUT)
	print("Walk bake: ", error_string(error), "; ", walk.get_track_count(), " tracks, ", walk.length, " s")
	model.free()
	quit(0 if error == OK else 1)


func _pose(phase: float) -> void:
	var cycle := TAU * phase
	var pelvis := _bone(&"HipsCtrl")
	# Lower at weight acceptance, then rise over the support foot. No root displacement.
	var offset := Vector3(0.065 * sin(cycle), -0.207 - 0.073 * cos(2.0 * cycle - 0.42), 0.14 * sin(2.0 * cycle + 2.60))
	_rig.set_bone_pose_position(pelvis, _rig.get_bone_rest(pelvis).origin + offset)
	_turn(&"HipsCtrl", Vector3.UP, 0.105 * cos(cycle))
	_turn(&"HipsCtrl", Vector3.BACK, 0.065 * sin(cycle))
	_turn(&"Spine", Vector3.UP, -0.19 * cos(cycle))
	_turn(&"Spine", Vector3.BACK, -0.08 * sin(cycle))
	_turn(&"Spine", Vector3.RIGHT, 0.045)
	_turn(&"Neck", Vector3.UP, 0.065 * cos(cycle))
	_turn(&"Head", Vector3.BACK, 0.028 * sin(cycle))
	_leg("Left", phase)
	_leg("Right", fposmod(phase + 0.5, 1.0))
	_arm("Left", -1.0, cycle)
	_arm("Right", 1.0, cycle)


func _arm(side: String, sign_side: float, cycle: float) -> void:
	var forearm := _bone(side + "ForeArm")
	var hand := _bone(side + "Hand")
	var swing := sign_side * cos(cycle + 0.17)
	# Lower the T-pose arms, then swing opposite each leg. The elbows flex forward.
	_turn(side + "Arm", Vector3.BACK, sign_side * 1.29)
	_turn(side + "Arm", Vector3.RIGHT, -0.29 * swing)
	_turn(side + "ForeArm", Vector3.RIGHT, -0.22 - 0.10 * swing)
	var down := (_rig.get_bone_global_pose(hand).origin - _rig.get_bone_global_pose(forearm).origin).normalized()
	_turn(side + "Arm", down, 0.12 * sign_side)


func _leg(side: String, phase: float) -> void:
	var thigh := _bone(side + "UpLeg")
	var shin := _bone(side + "Leg")
	var ankle := _bone(side + "Foot")
	var foot_rest := _rig.get_bone_global_rest(ankle)
	var stride: float
	var pitch: float
	var lift := 0.0
	if phase < STANCE:
		var contact := phase / STANCE
		stride = lerpf(STANCE_TRAVEL * 0.5, STANCE_TRAVEL * -0.5, contact)
		pitch = lerpf(-0.24, 0.0, smoothstep(0.0, 0.22, contact))
		pitch += 0.42 * smoothstep(0.68, 1.0, contact)
	else:
		var swing := (phase - STANCE) / (1.0 - STANCE)
		# Hermite tangents match the backward stance velocity at toe-off and heel strike.
		var tangent := -STANCE_TRAVEL * (1.0 - STANCE) / STANCE
		stride = lerpf(-STANCE_TRAVEL * 0.5, STANCE_TRAVEL * 0.5, smoothstep(0.0, 1.0, swing))
		stride += swing * (1.0 - swing) * (1.0 - 2.0 * swing) * tangent
		pitch = lerpf(0.42, -0.24, smoothstep(0.0, 0.83, swing))
		lift = 0.235 * pow(sin(PI * swing), 1.55)
	# Roll around the sole, not the ankle. During stance the heel/toe pivot countertracks forward travel.
	var pivot := Vector3(foot_rest.origin.x, 0.0, 0.29 if pitch >= 0.0 else -0.30)
	var roll := Basis(Vector3.RIGHT, pitch)
	var goal := pivot + roll * (foot_rest.origin - pivot) + Vector3(0.0, lift, stride)
	_solve_leg(thigh, shin, ankle, goal)
	_set_global_rotation(ankle, roll * foot_rest.basis)


func _solve_leg(thigh: int, shin: int, ankle: int, goal: Vector3) -> void:
	var hip := _rig.get_bone_global_pose(thigh).origin
	var upper := _rig.get_bone_rest(shin).origin.length()
	var lower := _rig.get_bone_rest(ankle).origin.length()
	var offset := goal - hip
	var axis := offset.normalized()
	var reach := clampf(offset.length(), absf(upper - lower) + 0.001, upper + lower - 0.002)
	var pole := (FORWARD - axis * axis.dot(FORWARD)).normalized()
	# Law of cosines: intersection of the thigh and shin length spheres.
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var knee := hip + axis * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	_max_reach_error = maxf(_max_reach_error, offset.length() - reach)
	_aim_bone(thigh, shin, knee)
	_aim_bone(shin, ankle, hip + axis * reach)


func _aim_bone(index: int, child: int, goal: Vector3) -> void:
	var pose := _rig.get_bone_global_pose(index)
	var initial := (_rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var desired := (goal - pose.origin).normalized()
	_set_global_rotation(index, Basis(Quaternion(initial, desired)) * pose.basis)


func _turn(name: StringName, axis: Vector3, angle: float) -> void:
	var index := _bone(name)
	_set_global_rotation(index, Basis(axis, angle) * _rig.get_bone_global_pose(index).basis)


func _set_global_rotation(index: int, basis: Basis) -> void:
	var parent := _rig.get_bone_parent(index)
	var local := basis if parent < 0 else _rig.get_bone_global_pose(parent).basis.inverse() * basis
	_rig.set_bone_pose_rotation(index, local.orthonormalized().get_rotation_quaternion())


func _bone(name: StringName) -> int:
	return _rig.find_bone(name)
