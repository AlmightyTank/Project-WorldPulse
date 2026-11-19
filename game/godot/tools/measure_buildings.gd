extends SceneTree

# Measures placed-building wrappers so the catalog uses real bounds, never guesses.
const IDS := [
	"res_building_type_a", "res_building_type_c", "res_building_type_f",
	"res_building_type_j", "res_building_type_n", "res_building_type_t",
	"com_building_a", "com_building_c", "com_building_e", "com_building_k",
	"com_skyscraper_a", "com_low_detail_building_a",
]


func _initialize() -> void:
	await process_frame
	for asset_id: String in IDS:
		var node := KenneyAssets.instance(asset_id)
		if node == null:
			continue
		var box := _bounds(node)
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		var surfaces := 0
		for mesh: Node in meshes:
			surfaces += (mesh as MeshInstance3D).mesh.get_surface_count()
		print("%s scale=%.3f pos=%s size=%s meshes=%d surfaces=%d" % [
			asset_id, node.scale.x, str(box.position), str(box.size), meshes.size(), surfaces,
		])
		node.free()
	quit(0)


func _bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var path := Transform3D.IDENTITY
		var current: Node3D = mesh
		while current != root:
			path = current.transform * path
			current = current.get_parent() as Node3D
		var box: AABB = root.transform * (path * mesh.get_aabb())
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
