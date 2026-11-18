@tool
class_name KenneyAsset
extends Node3D

## Places one imported Kenney model at its documented world scale.
## The manifest holds the scale; collision is a single box from the scaled AABB.

@export var asset_id := "":
	set(value):
		asset_id = value
		if is_inside_tree():
			_rebuild()
@export var add_collision := true

var asset: Dictionary = {}
var model: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	model = null
	asset = KenneyAssets.find(asset_id)
	if asset.is_empty():
		return
	model = KenneyAssets.instance(asset_id)
	if model == null:
		return
	add_child(model)
	if add_collision and bool(asset.get("collision", false)):
		var bounds := _model_bounds(model)
		if bounds.size.length_squared() > 0.0:
			var body := StaticBody3D.new()
			body.name = "BoxCollision"
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = bounds.size
			shape.shape = box
			shape.position = bounds.get_center()
			body.add_child(shape)
			add_child(body)


func _model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array[Array] = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xform: Transform3D = entry[1]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var box: AABB = xform * (node as MeshInstance3D).mesh.get_aabb()
			result = box if not found else result.merge(box)
			found = true
		for child in node.get_children():
			stack.append([child, xform])
	return result
