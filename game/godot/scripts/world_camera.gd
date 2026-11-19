class_name WorldCamera
extends Camera3D

@export var min_span := 30.0
@export var max_span := 398.0
@export var home_span := 160.0
@export var home_yaw := 19.0
@export var tilt := 60.0
@export var smooth_rate := 12.0
@export var pan_speed := 0.75 # View spans per second.
@export var keyboard_turn_speed := 1.0 # Radians per second.
@export var keyboard_zoom_speed := 1.6
@export var wheel_zoom_factor := 0.86
@export var drag_turn_speed := 0.005
@export var rotation_enabled := true

var bounds := Rect2()
var focus := Vector2.ZERO
var target_focus := Vector2.ZERO
var target_span := 0.0
var yaw := 0.0
var target_yaw := 0.0
var _home := Vector2.ZERO
var _configured := false


func configure(world_bounds: Rect2, home_focus: Vector2) -> void:
	bounds = world_bounds
	_home = home_focus
	_configured = true
	projection = PROJECTION_ORTHOGONAL
	reset_view(true)


func reset_view(instant := false) -> void:
	target_yaw = deg_to_rad(home_yaw)
	frame_view(_home, home_span, instant)


func frame_view(center: Vector2, span: float, instant := false) -> void:
	target_span = clampf(span, min_span, max_span)
	target_focus = _bounded(center)
	if instant:
		focus = target_focus
		size = target_span
		yaw = target_yaw
		_place()


func _process(delta: float) -> void:
	if not _configured or not current:
		return
	if get_window().has_focus():
		var pan := Input.get_vector("world_left", "world_right", "world_forward", "world_back")
		var turn := Input.get_axis("world_turn_left", "world_turn_right")
		var zoom := Input.get_axis("world_zoom_in", "world_zoom_out")
		_pan(pan * target_span * pan_speed * delta)
		if rotation_enabled:
			target_yaw = wrapf(target_yaw + turn * keyboard_turn_speed * delta, -PI, PI)
		_zoom(exp(zoom * keyboard_zoom_speed * delta))
	var weight := 1.0 - exp(-smooth_rate * delta)
	focus = _bounded(focus.lerp(target_focus, weight))
	size = lerpf(size, target_span, weight)
	yaw = lerp_angle(yaw, target_yaw, weight)
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if not _configured or not current:
		return
	if event.is_action_pressed("world_reset", false, true):
		reset_view()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(pow(wheel_zoom_factor, event.factor if event.factor > 0.0 else 1.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(pow(1.0 / wheel_zoom_factor, event.factor if event.factor > 0.0 else 1.0))
		else:
			return
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var scale_m := size / maxf(get_viewport().get_visible_rect().size.y, 1.0)
			_pan(-event.relative * scale_m)
		elif rotation_enabled and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			target_yaw = wrapf(target_yaw - event.relative.x * drag_turn_speed, -PI, PI)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _pan(delta: Vector2) -> void:
	if delta != Vector2.ZERO:
		var ground_delta := Vector2(delta.x, delta.y / sin(deg_to_rad(tilt)))
		target_focus = _bounded(target_focus + ground_delta.rotated(-yaw))


func _zoom(factor: float) -> void:
	target_span = clampf(target_span * factor, min_span, max_span)


func _bounded(center: Vector2) -> Vector2:
	return center.clamp(bounds.position, bounds.end)


func _place() -> void:
	var basis_at_focus := Basis.from_euler(Vector3(-deg_to_rad(tilt), yaw, 0.0))
	transform = Transform3D(basis_at_focus, Vector3(focus.x, 0.0, focus.y) + basis_at_focus.z * 330.0)
