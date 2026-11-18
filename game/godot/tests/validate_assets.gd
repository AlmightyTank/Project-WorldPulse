extends SceneTree

## Headless check that every manifest asset loads in Godot, instantiates with
## meshes, and that the animated characters expose keyed Idle and Run clips.

const MANIFEST := "res://assets/third_party/kenney/manifest.json"
const REQUIRED_CLIPS := ["Idle", "Run"]

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data is not Dictionary:
		_fail("Manifest is not a JSON object.")
		quit(1)
		return

	var assets: Variant = data.get("assets")
	if assets is not Array or assets.is_empty():
		_fail("Manifest must list assets in a nonempty array.")
		quit(1)
		return

	var seen := {}
	for asset: Dictionary in assets:
		var asset_id := str(asset.get("id", ""))
		if asset_id == "":
			_fail("Manifest entry without an id.")
			continue
		if seen.has(asset_id):
			_fail("Duplicate asset id: " + asset_id)
			continue
		seen[asset_id] = true

		var path := "res://" + str(asset.get("imported_path", ""))
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("Cannot load " + asset_id + " from " + path)
			continue

		var node := packed.instantiate()
		root.add_child(node)
		await process_frame
		if _mesh_count(node) == 0:
			_fail(asset_id + " instantiated without meshes")
		if asset.has("animations"):
			_check_animations(asset_id, node, asset["animations"])
		node.queue_free()

	if failures.is_empty():
		print("PASS: %d Kenney assets load and animate." % assets.size())
		quit(0)
	else:
		quit(1)


func _check_animations(asset_id: String, node: Node, expected: Array) -> void:
	var player := _find_player(node)
	if player == null:
		_fail(asset_id + " has no AnimationPlayer")
		return
	for clip: String in REQUIRED_CLIPS:
		if not player.has_animation(clip):
			_fail(asset_id + " is missing clip " + clip)
			continue
		var animation := player.get_animation(clip)
		if animation.length <= 0.0:
			_fail(asset_id + " clip " + clip + " has no duration")
		var keyed := false
		for track in animation.get_track_count():
			if animation.track_get_key_count(track) > 1:
				keyed = true
				break
		if not keyed:
			_fail(asset_id + " clip " + clip + " holds one key per track")
	for listed: String in expected:
		if not player.has_animation(listed):
			_fail(asset_id + " lost expected clip " + listed)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


func _mesh_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _mesh_count(child)
	return total


func _fail(message: String) -> void:
	failures.append(message)
	push_error("FAIL: " + message)
	if failures.size() >= 20:
		quit(1)