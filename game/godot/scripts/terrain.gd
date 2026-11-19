extends StaticBody3D

@export var dimensions_m := Vector2(256, 256)
@export var ground_color := Color("86996f")


func _ready() -> void:
	var dimensions := dimensions_m.max(Vector2.ONE)
	WorldBuilder.slab(self, "Ground", Rect2(-dimensions * 0.5, dimensions), -0.02, 5.0, ground_color)
	var collision := CollisionShape3D.new()
	collision.name = "GroundCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(dimensions.x, 1.0, dimensions.y)
	collision.shape = shape
	collision.position.y = -0.52
	add_child(collision)
