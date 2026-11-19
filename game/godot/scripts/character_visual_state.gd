class_name CharacterVisualState
extends RefCounted

signal state_changed(state: StringName)

const WALK_PATH := "res://assets/animations/protagonist_walk.tres"
const IDLE := &"Idle"
const WALK := &"Walk"
const RUN := &"Run"
const JUMP := &"Jump"
const BLEND_SECONDS := 0.12

var _player: AnimationPlayer
var _state: StringName = &""
var _locomotion: StringName = IDLE


static func install_walk(player: AnimationPlayer) -> bool:
	if not is_instance_valid(player):
		return false
	if player.has_animation(WALK):
		return true
	var walk := load(WALK_PATH) as Animation
	if walk == null:
		return false
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return false
	for track in walk.get_track_count():
		var target := walk.track_get_path(track)
		var skeleton := animation_root.get_node_or_null(NodePath(target.get_concatenated_names())) as Skeleton3D
		if skeleton == null or skeleton.find_bone(target.get_subname(0)) < 0:
			return false

	# GLB instances share their AnimationLibrary; leave the imported resource untouched.
	var library := AnimationLibrary.new()
	if player.has_animation_library(&""):
		var imported := player.get_animation_library(&"")
		for clip in imported.get_animation_list():
			library.add_animation(clip, imported.get_animation(clip).duplicate())
		player.remove_animation_library(&"")
	library.add_animation(WALK, walk)
	return player.add_animation_library(&"", library) == OK


## Bind one controller to one visual; callers request states rather than playing the player directly.
func bind(player: AnimationPlayer) -> bool:
	if not is_instance_valid(player):
		return false
	for clip in [IDLE, RUN, JUMP]:
		if not player.has_animation(clip):
			return false
	if not install_walk(player):
		return false
	if is_instance_valid(_player) and _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.disconnect(_on_animation_finished)
	_player = player
	_player.animation_finished.connect(_on_animation_finished)
	for clip in [IDLE, WALK, RUN]:
		_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_player.get_animation(JUMP).loop_mode = Animation.LOOP_NONE
	_state = &""
	_locomotion = IDLE
	return play(IDLE)


func get_state() -> StringName:
	return _state


## Jump requests do not restart an active jump. Locomotion requests during it set the landing state.
func play(state: StringName) -> bool:
	if not is_instance_valid(_player) or state not in [IDLE, WALK, RUN, JUMP]:
		return false
	if state != JUMP:
		_locomotion = state
		if _state == JUMP:
			return true
	if _state != state:
		_play_now(state)
	return true


func _play_now(state: StringName) -> void:
	_player.play(state, BLEND_SECONDS)
	_state = state
	state_changed.emit(state)


func _on_animation_finished(clip: StringName) -> void:
	if clip == JUMP and _state == JUMP:
		_play_now(_locomotion)
