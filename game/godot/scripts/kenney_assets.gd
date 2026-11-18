class_name KenneyAssets
extends RefCounted

const MANIFEST_PATH := "res://assets/third_party/kenney/manifest.json"

static var _assets: Array = []

static func all() -> Array:
	if _assets.is_empty():
		var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if file == null:
			push_error("Kenney manifest missing: " + MANIFEST_PATH)
			return []
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			_assets = data.get("assets", [])
	return _assets

static func by_category(category: String) -> Array:
	return all().filter(func(a: Dictionary) -> bool: return a.get("category") == category)

static func find(asset_id: String) -> Dictionary:
	for asset in all():
		if asset.get("id") == asset_id:
			return asset
	return {}

static func path_of(asset: Dictionary) -> String:
	return "res://" + str(asset.get("imported_path", ""))


static func instance(asset_id: String) -> Node3D:
	var asset := find(asset_id)
	if asset.is_empty():
		push_error("Unknown Kenney asset: " + asset_id)
		return null
	var packed := load(path_of(asset)) as PackedScene
	if packed == null:
		push_error("Cannot load Kenney asset: " + asset_id)
		return null
	var node := packed.instantiate() as Node3D
	node.scale = Vector3.ONE * float(asset.get("scale", 1.0))
	# Idle and Run are cycles; glTF does not flag them, so loop them here.
	var player := _find_player(node)
	if player != null:
		for clip in ["Idle", "Run"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				player.play(clip)
	return node


static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
