extends Node3D

## Verifies that the converted protagonist GLBs carry a skeleton and usable clips.
## The source pack ships idle, run and jump; there is no walk clip.

const CHARACTER_IDS := [
	"char_protagonist_criminal_male_a",
	"char_protagonist_cyborg_female_a",
	"char_protagonist_skater_female_a",
	"char_protagonist_skater_male_a",
]

const CLIP_KEYS := { "Idle": KEY_1, "Run": KEY_2, "Jump": KEY_3 }

var wrappers: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var info_label: Label
var frames := 0
var screenshot_path := OS.get_environment("CHARACTER_SCREENSHOT")


func _ready() -> void:
	_build_stage()
	_build_characters()
	_build_ui()
	_play("Idle")


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

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.4, 8.5)
	camera.fov = 40.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _build_characters() -> void:
	var x := -3.9
	for asset_id in CHARACTER_IDS:
		var model := KenneyAssets.instance(asset_id)
		if model == null:
			push_error("Cannot instance " + asset_id)
			continue
		model.position = Vector3(x, 0, 0)
		model.rotation_degrees = Vector3(0, 180, 0)
		add_child(model)
		var wrapper := model
		wrappers.append(wrapper)

		var label := Label3D.new()
		label.text = asset_id.replace("char_protagonist_", "")
		label.font_size = 40
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(x, 2.05, 0)
		add_child(label)

		var player := _find_player(wrapper)
		if player == null:
			push_error("No AnimationPlayer in " + asset_id)
		else:
			players.append(player)
		x += 2.6


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


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
	panel.custom_minimum_size = Vector2(620, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	info_label = Label.new()
	info_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.91))
	info_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(info_label)
	info_label.text = _describe()

	var hint := Label.new()
	hint.text = "1 idle   2 run   3 jump      The source pack has no walk clip; Run is its locomotion animation."
	hint.add_theme_color_override("font_color", Color(0.85, 0.92, 0.89))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20, -36)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hint)


func _describe() -> String:
	var lines := PackedStringArray()
	lines.append("Protagonist rig check: 1.8 m, idle + locomotion")
	lines.append("")
	for index in players.size():
		var player := players[index]
		lines.append(CHARACTER_IDS[index].replace("char_protagonist_", ""))
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			var loop := "loop" if animation.loop_mode != Animation.LOOP_NONE else "once"
			lines.append("  %-5s %.2f s  %-4s  %d tracks" % [clip, animation.length, loop, animation.get_track_count()])
		lines.append("  bones %d" % _bone_count(wrappers[index]))
	return "\n".join(lines)


func _bone_count(wrapper: Node3D) -> int:
	var skeleton := _find_first(wrapper, "Skeleton3D")
	return (skeleton as Skeleton3D).get_bone_count() if skeleton is Skeleton3D else 0


func _find_first(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null


func _play(clip: String) -> void:
	for player in players:
		if player.has_animation(clip):
			player.play(clip)


func _process(_delta: float) -> void:
	if screenshot_path != "":
		frames += 1
		if frames == 40:
			get_viewport().get_texture().get_image().save_png(screenshot_path)
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		for clip: String in CLIP_KEYS:
			if CLIP_KEYS[clip] == key:
				_play(clip)
